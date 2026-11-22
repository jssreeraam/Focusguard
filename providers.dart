import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../data/repo.dart';
import '../domain/models.dart';
import '../services/blocker.dart';
import '../services/vision.dart';

late SharedPreferences sp;
String dayKey(DateTime d) => '${d.year}-${d.month}-${d.day}';

class Prefs {
  final Map<String, dynamic> m;
  const Prefs(this.m);

  int get baseline => (m['baseline'] ?? 0) as int;
  int get pool => baseline == 0 ? 0 : max(2, (baseline / 2).ceil());
  int get streak => (m['streak'] ?? 0) as int;
  String get lastStreakDay => (m['lastStreakDay'] ?? '') as String;
  String get tokDay => (m['tokDay'] ?? '') as String;
  int get tokLeft => (m['tokLeft'] ?? 0) as int;
  int get calibDist => (m['calibDist'] ?? 0) as int;
  int get calibSessions => (m['calibSessions'] ?? 0) as int;
  int get intervalSec => (m['iv'] ?? 60) as int;
  bool get streakReset => (m['streakReset'] ?? true) as bool;
  int get cooldownSec => (m['cooldown'] ?? 60) as int;
  int get lockHours => (m['lockHours'] ?? 24) as int;
  bool get strictTamper => (m['strictTamper'] ?? true) as bool;
  bool get blockAllSettings => (m['blockAllSettings'] ?? false) as bool;
  List<String> get pkgs => List<String>.from(m['pkgs'] ?? const []);

  Prefs set(Map<String, dynamic> kv) => Prefs({...m, ...kv});
}

class PrefsNotifier extends Notifier<Prefs> {
  @override
  Prefs build() {
    final raw = sp.getString('prefs');
    Map<String, dynamic> decoded = {};
    if (raw != null) {
      try {
        decoded = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      } catch (_) {}
    }
    var p = Prefs(decoded);
    final t = dayKey(DateTime.now());
    if (p.tokDay != t) {
      p = p.set({'tokDay': t, 'tokLeft': p.pool, 'calibDist': 0});
    }
    Blocker.setAntiTamper(
      strict: p.strictTamper,
      blockAllSettings: p.blockAllSettings,
    );
    return p;
  }

  void set(Map<String, dynamic> kv) {
    state = state.set(kv);
    sp.setString('prefs', jsonEncode(state.m));
    if (kv.containsKey('strictTamper') || kv.containsKey('blockAllSettings')) {
      Blocker.setAntiTamper(
        strict: state.strictTamper,
        blockAllSettings: state.blockAllSettings,
      );
    }
  }

  void rollover() {
    final t = dayKey(DateTime.now());
    if (state.tokDay != t) {
      set({'tokDay': t, 'tokLeft': state.pool, 'calibDist': 0});
    }
  }

  void lockBaseline() {
    final b = max(4, state.calibDist);
    set({'baseline': b});
    set({'tokLeft': state.pool});
  }

  void recalibrate() => set({'baseline': 0, 'calibDist': 0, 'calibSessions': 0});
}

final prefsProvider = NotifierProvider<PrefsNotifier, Prefs>(PrefsNotifier.new);

enum Phase { idle, running, summary, locked }

class SS {
  final Phase phase;
  final int total, elapsed, tokens, maxTokens, cooldown, lastCost;
  final List<FocusState> checks;
  final bool calib;
  final SessionRecord? result;

  const SS({
    this.phase = Phase.idle,
    this.total = 0,
    this.elapsed = 0,
    this.tokens = 0,
    this.maxTokens = 0,
    this.cooldown = 0,
    this.lastCost = 0,
    this.checks = const [],
    this.calib = false,
    this.result,
  });

  FocusState get last => checks.isEmpty ? FocusState.study : checks.last;

  SS copy({
    Phase? phase,
    int? elapsed,
    int? tokens,
    int? cooldown,
    int? lastCost,
    List<FocusState>? checks,
    SessionRecord? result,
  }) =>
      SS(
        phase: phase ?? this.phase,
        total: total,
        elapsed: elapsed ?? this.elapsed,
        tokens: tokens ?? this.tokens,
        maxTokens: maxTokens,
        cooldown: cooldown ?? this.cooldown,
        lastCost: lastCost ?? this.lastCost,
        checks: checks ?? this.checks,
        calib: calib,
        result: result ?? this.result,
      );
}

class SessionCtl extends Notifier<SS> {
  final vision = VisionService();
  Timer? _t;
  bool _busy = false;
  DateTime _start = DateTime.now();

  @override
  SS build() => const SS();

  Future<bool> start(int min) async {
    final pn = ref.read(prefsProvider.notifier);
    pn.rollover();
    final pr = ref.read(prefsProvider);
    final calib = pr.baseline == 0;
    try {
      await vision.init();
    } catch (_) {
      return false;
    }
    try {
      await WakelockPlus.enable();
    } catch (_) {}
    await Blocker.requestNotificationPermission();
    _start = DateTime.now();
    _busy = false;
    _t?.cancel();
    state = SS(
      phase: Phase.running,
      total: min * 60,
      tokens: calib ? 0 : pr.tokLeft,
      maxTokens: calib ? 0 : pr.pool,
      calib: calib,
    );
    _t = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    return true;
  }

  Future<void> pauseCamera() async {
    if (state.phase == Phase.running) {
      await vision.dispose();
    }
  }

  Future<void> resumeCamera() async {
    if (state.phase == Phase.running && vision.cam == null) {
      try {
        await vision.init();
      } catch (_) {}
    }
  }

  Future<void> _tick() async {
    if (state.phase != Phase.running) return;
    final e = state.elapsed + 1;
    state = state.copy(elapsed: e);
    final iv = ref.read(prefsProvider).intervalSec;
    if (e % iv == 0 && !_busy) {
      _busy = true;
      try {
        await _check();
      } finally {
        _busy = false;
      }
    }
    if (state.phase == Phase.running && e >= state.total) {
      await _finish(true);
    }
  }

  Future<void> _check() async {
    final s = await vision.classify();
    if (state.phase != Phase.running) return;
    final cost = s.cost;
    final tok = state.calib ? 0 : max(0, state.tokens - cost);
    state = state.copy(checks: [...state.checks, s], tokens: tok, lastCost: cost);
    if (cost > 0) HapticFeedback.heavyImpact();
    if (!state.calib && tok == 0) await _punish();
  }

  SessionRecord _record(bool done) => SessionRecord(
        start: _start,
        plannedMin: state.total ~/ 60,
        intervalSec: ref.read(prefsProvider).intervalSec,
        checks: state.checks,
        tokensLost: state.calib ? 0 : state.maxTokens - state.tokens,
        calibration: state.calib,
        completed: done,
      );

  Future<void> _teardown() async {
    _t?.cancel();
    _t = null;
    await vision.dispose();
    try {
      await WakelockPlus.disable();
    } catch (_) {}
  }

  Future<void> _punish() async {
    await _teardown();
    final pr = ref.read(prefsProvider);
    final pn = ref.read(prefsProvider.notifier);
    await Repo.save(_record(false));
    pn.set({'tokLeft': 0});
    if (pr.streakReset) pn.set({'streak': 0});
    if (pr.lockHours > 0 && pr.pkgs.isNotEmpty) {
      await Blocker.setLockDuration(pr.pkgs, Duration(hours: pr.lockHours));
    }
    var left = pr.cooldownSec;
    state = state.copy(phase: Phase.locked, cooldown: left);
    _t = Timer.periodic(const Duration(seconds: 1), (t) {
      left--;
      if (left <= 0) {
        t.cancel();
        state = const SS();
      } else {
        state = state.copy(cooldown: left);
      }
    });
  }

  Future<void> _finish(bool done) async {
    await _teardown();
    final rec = _record(done);
    await Repo.save(rec);
    final pn = ref.read(prefsProvider.notifier);
    final pr = ref.read(prefsProvider);
    if (state.calib) {
      final dist = rec.checks.where((c) => c.cost > 0).length;
      pn.set({'calibDist': pr.calibDist + dist, 'calibSessions': pr.calibSessions + 1});
    } else {
      pn.set({'tokLeft': state.tokens});
      final today = dayKey(DateTime.now());
      if (done && pr.lastStreakDay != today) {
        final y = dayKey(DateTime.now().subtract(const Duration(days: 1)));
        pn.set({'streak': pr.lastStreakDay == y ? pr.streak + 1 : 1, 'lastStreakDay': today});
      } else if (!done && pr.streakReset) {
        pn.set({'streak': 0});
      }
    }
    state = state.copy(phase: Phase.summary, result: rec);
  }

  Future<void> abandon() => _finish(false);
  void dismiss() => state = const SS();
}

final sessionProvider = NotifierProvider<SessionCtl, SS>(SessionCtl.new);
