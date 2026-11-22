import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/repo.dart';
import '../domain/models.dart';
import '../services/blocker.dart';
import '../services/vision.dart';

late SharedPreferences sp;
String dayKey(DateTime d) => '${d.year}-${d.month}-${d.day}';
String monthKey(DateTime d) => '${d.year}-${d.month}';

String hashPin(String pin) =>
    sha256.convert(utf8.encode('fg_guardian_salt_v3::$pin')).toString();

final dbVersionProvider = StateProvider<int>((ref) => 0);

class Prefs {
  final Map<String, dynamic> m;
  const Prefs(this.m);

  int get baseline => (m['baseline'] ?? 0) as int;
  int get pool => baseline == 0 ? 0 : max(2, (baseline / 2).ceil());
  int get streak => (m['streak'] ?? 0) as int;
  int get streakShields => (m['streakShields'] ?? 0) as int;
  String get lastStreakDay => (m['lastStreakDay'] ?? '') as String;
  String get tokDay => (m['tokDay'] ?? '') as String;
  int get tokLeft => (m['tokLeft'] ?? 0) as int;
  int get calibDist => (m['calibDist'] ?? 0) as int;
  int get calibSessions => (m['calibSessions'] ?? 0) as int;
  int get checksPerMin => (m['checksPerMin'] ?? 1) as int;
  int get intervalSec => max(10, 60 ~/ max(1, checksPerMin));
  bool get streakReset => (m['streakReset'] ?? true) as bool;
  int get cooldownSec => (m['cooldown'] ?? 60) as int;
  int get lockHours => (m['lockHours'] ?? 24) as int;
  bool get strictTamper => (m['strictTamper'] ?? true) as bool;
  bool get blockAllSettings => (m['blockAllSettings'] ?? false) as bool;
  bool get useRearCam => (m['useRearCam'] ?? true) as bool;
  bool get phoneStudyMode => (m['phoneStudyMode'] ?? false) as bool;
  String get lastSubject => (m['lastSubject'] ?? 'Medicine') as String;
  String get lastMode => (m['lastMode'] ?? 'Reading') as String;
  bool get isDutyDay => (m['isDutyDay'] ?? true) as bool;
  int get dutyGoalMin => (m['dutyGoalMin'] ?? 120) as int;
  int get offGoalMin => (m['offGoalMin'] ?? 420) as int;
  int get dailyGoalMin => isDutyDay ? dutyGoalMin : offGoalMin;
  String get inicetDateIso => (m['inicetDate'] ?? '') as String;
  String get neetDateIso => (m['neetDate'] ?? '') as String;
  String get guardianPinHash => (m['guardianPinHash'] ?? '') as String;
  int get guardianOverrides => (m['guardianOverrides'] ?? 0) as int;
  int get revXpMonth => (m['revXpMonth'] ?? 0) as int;
  String get revXpMonthKey => (m['revXpMonthKey'] ?? '') as String;
  int get citadelCracks => (m['citadelCracks'] ?? 0) as int;
  bool get remindersOn => (m['remindersOn'] ?? true) as bool;
  int get reminderHour => (m['reminderHour'] ?? 8) as int;
  int get reminderMin => (m['reminderMin'] ?? 30) as int;
  List<String> get pkgs => List<String>.from(m['pkgs'] ?? const []);

  DateTime? get inicetDate =>
      inicetDateIso.isEmpty ? null : DateTime.tryParse(inicetDateIso);
  DateTime? get neetDate =>
      neetDateIso.isEmpty ? null : DateTime.tryParse(neetDateIso);
  bool get hasGuardianPin => guardianPinHash.isNotEmpty;

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
    final now = DateTime.now();
    final t = dayKey(now);
    final mk = monthKey(now);
    if (p.tokDay != t) {
      p = p.set({'tokDay': t, 'tokLeft': p.pool, 'calibDist': 0});
    }
    if (p.revXpMonthKey != mk) {
      p = p.set({'revXpMonthKey': mk, 'revXpMonth': 0, 'citadelCracks': 0});
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
    final now = DateTime.now();
    final t = dayKey(now);
    if (state.tokDay != t) {
      set({'tokDay': t, 'tokLeft': state.pool, 'calibDist': 0});
    }
    final mk = monthKey(now);
    if (state.revXpMonthKey != mk) {
      set({'revXpMonthKey': mk, 'revXpMonth': 0, 'citadelCracks': 0});
    }
  }

  void addRevisionXp(int xp) {
    rollover();
    set({'revXpMonth': state.revXpMonth + xp});
  }

  void setGuardianPin(String pin) => set({'guardianPinHash': hashPin(pin)});

  bool verifyGuardianPin(String pin) =>
      state.hasGuardianPin && state.guardianPinHash == hashPin(pin);

  Future<bool> guardianUnlock(String pin) async {
    if (!verifyGuardianPin(pin)) return false;
    await Blocker.clearLock();
    set({'guardianOverrides': state.guardianOverrides + 1});
    return true;
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
  final int tokens, maxTokens, cooldown, lastCost, checksPerMin;
  final List<FocusState> checks;
  final bool calib, phoneMode, brownNoise;
  final String subject, mode, goalNote;
  final int? savedSessionId;
  final SessionRecord? result;

  const SS({
    this.phase = Phase.idle,
    this.tokens = 0,
    this.maxTokens = 0,
    this.cooldown = 0,
    this.lastCost = 0,
    this.checksPerMin = 1,
    this.checks = const [],
    this.calib = false,
    this.phoneMode = false,
    this.brownNoise = false,
    this.subject = 'Medicine',
    this.mode = 'Reading',
    this.goalNote = '',
    this.savedSessionId,
    this.result,
  });

  FocusState get last => checks.isEmpty ? FocusState.study : checks.last;

  double get liveScore {
    if (checks.isEmpty) return 1.0;
    final study = checks.where((c) => c == FocusState.study).length;
    final neutral = checks.where((c) => c == FocusState.neutral).length;
    return (study + 0.5 * neutral) / checks.length;
  }

  SS copy({
    Phase? phase,
    int? tokens,
    int? cooldown,
    int? lastCost,
    bool? brownNoise,
    List<FocusState>? checks,
    int? savedSessionId,
    SessionRecord? result,
  }) =>
      SS(
        phase: phase ?? this.phase,
        tokens: tokens ?? this.tokens,
        maxTokens: maxTokens,
        cooldown: cooldown ?? this.cooldown,
        lastCost: lastCost ?? this.lastCost,
        checksPerMin: checksPerMin,
        checks: checks ?? this.checks,
        calib: calib,
        phoneMode: phoneMode,
        brownNoise: brownNoise ?? this.brownNoise,
        subject: subject,
        mode: mode,
        goalNote: goalNote,
        savedSessionId: savedSessionId ?? this.savedSessionId,
        result: result ?? this.result,
      );
}

class SessionCtl extends Notifier<SS> {
  final vision = VisionService();
  final _rng = Random();
  Timer? _checkTimer;
  Timer? _cooldownTimer;
  bool _busy = false;
  DateTime _start = DateTime.now();
  int _slotIndex = 0;

  @override
  SS build() => const SS();

  Future<bool> start({
    required String subject,
    required String mode,
    required String goalNote,
    required bool phoneMode,
  }) async {
    final pn = ref.read(prefsProvider.notifier);
    pn.rollover();
    pn.set({'lastSubject': subject, 'lastMode': mode, 'phoneStudyMode': phoneMode});
    final pr = ref.read(prefsProvider);
    final calib = pr.baseline == 0;

    if (!phoneMode) {
      try {
        await vision.init(useRear: pr.useRearCam);
      } catch (_) {
        return false;
      }
      await Blocker.setWakelock(true);
    } else if (pr.pkgs.isNotEmpty) {
      await Blocker.setLockDuration(pr.pkgs, const Duration(hours: 2));
    }

    await Blocker.requestNotificationPermission();

    _start = DateTime.now();
    _slotIndex = 0;
    _busy = false;
    _checkTimer?.cancel();
    _cooldownTimer?.cancel();

    state = SS(
      phase: Phase.running,
      tokens: calib ? 0 : pr.tokLeft,
      maxTokens: calib ? 0 : pr.pool,
      checksPerMin: pr.checksPerMin,
      calib: calib,
      phoneMode: phoneMode,
      subject: subject,
      mode: mode,
      goalNote: goalNote.trim(),
    );

    if (!phoneMode) {
      _scheduleNextRandomCheck();
    }
    return true;
  }

  /// Schedules the next check at an unpredictable random second inside the next slot.
  /// Zero 1-second UI ticking -> dramatically lower battery usage!
  void _scheduleNextRandomCheck() {
    if (state.phase != Phase.running) return;
    final slotSec = max(10, 60 ~/ max(1, state.checksPerMin));
    final slotStart = _slotIndex * slotSec;
    final offset = _rng.nextInt(max(1, slotSec - 2)) + 1;
    final targetSec = slotStart + offset;
    _slotIndex++;

    final elapsedSec = DateTime.now().difference(_start).inSeconds;
    final waitSec = max(2, targetSec - elapsedSec);

    _checkTimer?.cancel();
    _checkTimer = Timer(Duration(seconds: waitSec), () async {
      if (state.phase != Phase.running) return;
      if (!_busy) {
        _busy = true;
        try {
          await _check();
        } finally {
          _busy = false;
        }
      }
      if (state.phase == Phase.running) {
        _scheduleNextRandomCheck();
      }
    });
  }

  Future<void> toggleBrownNoise() async {
    final next = !state.brownNoise;
    await Blocker.setBrownNoise(next);
    state = state.copy(brownNoise: next);
  }

  Future<void> pauseCamera() async {
    if (state.phase == Phase.running && !state.phoneMode) {
      await vision.dispose();
    }
  }

  Future<void> resumeCamera() async {
    if (state.phase == Phase.running && !state.phoneMode && vision.cam == null) {
      try {
        await vision.init(useRear: ref.read(prefsProvider).useRearCam);
      } catch (_) {}
    }
  }

  Future<void> _hapticAlert(int cost) async {
    try {
      await HapticFeedback.heavyImpact();
      await Future.delayed(const Duration(milliseconds: 180));
      await HapticFeedback.heavyImpact();
      if (cost >= 2) {
        await Future.delayed(const Duration(milliseconds: 180));
        await HapticFeedback.heavyImpact();
      }
    } catch (_) {}
  }

  Future<void> _check() async {
    final s = await vision.classify();
    if (state.phase != Phase.running) return;
    final cost = s.cost;
    final tok = state.calib ? 0 : max(0, state.tokens - cost);
    state = state.copy(checks: [...state.checks, s], tokens: tok, lastCost: cost);
    if (cost > 0) _hapticAlert(cost);
    if (!state.calib && tok == 0) await _punish();
  }

  SessionRecord _record(bool done) {
    final elapsedMin = max(1, DateTime.now().difference(_start).inSeconds ~/ 60);
    final iv = max(10, 60 ~/ max(1, state.checksPerMin));
    final rawScore = state.phoneMode ? 1.0 : state.liveScore;
    final focusMin = state.phoneMode
        ? elapsedMin
        : (state.checks.where((c) => c == FocusState.study).length * iv) ~/ 60;
    final mult = (done && rawScore >= 0.90) ? 2 : 1;
    final xp = max(0, focusMin * mult);
    return SessionRecord(
      start: _start,
      plannedMin: elapsedMin,
      intervalSec: iv,
      checks: state.checks,
      tokensLost: state.calib ? 0 : state.maxTokens - state.tokens,
      calibration: state.calib,
      completed: done,
      phoneMode: state.phoneMode,
      subject: state.subject,
      mode: state.mode,
      note: state.goalNote,
      xp: xp,
    );
  }

  Future<void> _teardown() async {
    _checkTimer?.cancel();
    _checkTimer = null;
    _cooldownTimer?.cancel();
    _cooldownTimer = null;
    await vision.dispose();
    await Blocker.setWakelock(false);
    await Blocker.setBrownNoise(false);
  }

  Future<void> _punish() async {
    await _teardown();
    final pr = ref.read(prefsProvider);
    final pn = ref.read(prefsProvider.notifier);
    await Repo.save(_record(false));
    ref.read(dbVersionProvider.notifier).state++;
    pn.set({'tokLeft': 0, 'citadelCracks': pr.citadelCracks + 1});
    if (pr.streakReset) {
      if (pr.streakShields > 0) {
        pn.set({'streakShields': pr.streakShields - 1});
      } else {
        pn.set({'streak': 0});
      }
    }
    if (pr.lockHours > 0 && pr.pkgs.isNotEmpty) {
      await Blocker.setLockDuration(pr.pkgs, Duration(hours: pr.lockHours));
    }
    var left = pr.cooldownSec;
    state = state.copy(phase: Phase.locked, cooldown: left, brownNoise: false);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      left--;
      if (left <= 0) {
        t.cancel();
        state = const SS();
      } else {
        state = state.copy(cooldown: left);
      }
    });
  }

  Future<void> finishSession() async {
    await _teardown();
    final rec = _record(true);
    final id = await Repo.save(rec);
    ref.read(dbVersionProvider.notifier).state++;
    final pn = ref.read(prefsProvider.notifier);
    final pr = ref.read(prefsProvider);

    if (rec.score >= 0.90 && pr.citadelCracks > 0) {
      pn.set({'citadelCracks': max(0, pr.citadelCracks - 1)});
    }

    if (state.calib) {
      final dist = rec.checks.where((c) => c.cost > 0).length;
      pn.set({'calibDist': pr.calibDist + dist, 'calibSessions': pr.calibSessions + 1});
    } else {
      pn.set({'tokLeft': state.tokens});
      final today = dayKey(DateTime.now());
      if (pr.lastStreakDay != today) {
        final y = dayKey(DateTime.now().subtract(const Duration(days: 1)));
        final nextStreak = pr.lastStreakDay == y ? pr.streak + 1 : 1;
        final earnedShield = (nextStreak > 0 && nextStreak % 7 == 0 && pr.streakShields < 2)
            ? pr.streakShields + 1
            : pr.streakShields;
        pn.set({
          'streak': nextStreak,
          'lastStreakDay': today,
          'streakShields': earnedShield,
        });
      }
    }

    state = state.copy(
      phase: Phase.summary,
      savedSessionId: id,
      result: rec,
      brownNoise: false,
    );
  }

  void dismiss() => state = const SS();
}

final sessionProvider = NotifierProvider<SessionCtl, SS>(SessionCtl.new);
