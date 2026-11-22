import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/repo.dart';
import '../domain/models.dart';
import '../services/blocker.dart';
import '../state/providers.dart';
import 'common.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});
  @override
  ConsumerState<HomeScreen> createState() => _H();
}

class _H extends ConsumerState<HomeScreen> with WidgetsBindingObserver {
  int lockRemMs = 0;
  Timer? _poll;
  final _goalCtl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshLock();
    _poll = Timer.periodic(const Duration(seconds: 15), (_) => _refreshLock());
  }

  @override
  void dispose() {
    _poll?.cancel();
    _goalCtl.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshLock();
  }

  Future<void> _refreshLock() async {
    final rem = await Blocker.lockRemainingMs();
    if (mounted) setState(() => lockRemMs = rem);
  }

  String _fmtRem(int ms) => fmtMins((ms ~/ 60000).clamp(1, 99999).toInt());

  Future<void> _pickSubject(String current) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: kCard,
      builder: (ctx) => SizedBox(
        height: MediaQuery.of(ctx).size.height * .72,
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Select NEET PG / INI-CET Subject',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            ),
            Expanded(
              child: ListView(
                children: [
                  for (final sub in kNeetSubjects)
                    ListTile(
                      title: Text(sub),
                      trailing: sub == current
                          ? const Icon(Icons.check_circle, color: kAmber)
                          : null,
                      onTap: () {
                        ref.read(prefsProvider.notifier).set({'lastSubject': sub});
                        Navigator.pop(ctx);
                      },
                    )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _quickStrictLock() async {
    final p = ref.read(prefsProvider);
    if (p.pkgs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pick distraction apps in Rules tab first.')),
      );
      return;
    }
    final hours = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: kCard,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Quick Strict Lock (No Camera)',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text('Immediately locks ${p.pkgs.length} selected apps with clock & Settings anti-tamper.',
                style: const TextStyle(color: kMute, fontSize: 13)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final h in [1, 2, 4, 8, 12, 24])
                  ActionChip(
                    label: Text('${h}h lock'),
                    onPressed: () => Navigator.pop(ctx, h),
                  ),
              ],
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
    if (hours != null) {
      await Blocker.requestNotificationPermission();
      await Blocker.setLockDuration(p.pkgs, Duration(hours: hours));
      await _refreshLock();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Strict lock active for ${hours}h.')),
        );
      }
    }
  }

  Future<void> _guardianUnlockDialog() async {
    final p = ref.read(prefsProvider);
    if (!p.hasGuardianPin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No Guardian PIN set. Ask Mom/Dad to set one in Rules when unlocked.')),
      );
      return;
    }
    final ctl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Guardian Emergency Unlock'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Hand your phone to Mom or Dad to enter their 6-digit PIN.',
                style: TextStyle(color: kMute, fontSize: 13)),
            const SizedBox(height: 12),
            TextField(
              controller: ctl,
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: const InputDecoration(
                labelText: '6-digit Guardian PIN',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Unlock')),
        ],
      ),
    );
    if (ok == true) {
      final unlocked = await ref.read(prefsProvider.notifier).guardianUnlock(ctl.text.trim());
      await _refreshLock();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(unlocked
                ? 'Guardian override accepted. Lock cleared.'
                : 'Wrong Guardian PIN. Lock stays active.'),
          ),
        );
      }
    }
  }

  Future<void> _framingPreview(bool useRear) async {
    CameraController? preview;
    try {
      final cams = await availableCameras();
      if (cams.isEmpty) return;
      final target = useRear ? CameraLensDirection.back : CameraLensDirection.front;
      final sel = cams.firstWhere((c) => c.lensDirection == target, orElse: () => cams.first);
      preview = CameraController(sel, ResolutionPreset.medium, enableAudio: false);
      await preview.initialize();
      try {
        await preview.setFlashMode(FlashMode.off);
      } catch (_) {}
      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(useRear ? 'Back Camera Framing' : 'Front Camera Framing'),
          content: AspectRatio(
            aspectRatio: 3 / 4,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: CameraPreview(preview!),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Looks good')),
          ],
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Grant camera permission to preview framing.')),
        );
      }
    } finally {
      try {
        await preview?.dispose();
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = ref.watch(prefsProvider);
    ref.watch(dbVersionProvider);
    final calib = p.baseline == 0;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final iniDays = p.inicetDate?.difference(today).inDays;
    final neetDays = p.neetDate?.difference(today).inDays;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.asset('assets/icon.png', width: 42, height: 42),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'FOCUSGUARD',
                      style: TextStyle(color: kInk, fontSize: 18, letterSpacing: 3, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'The Digital Study Warden',
                      style: TextStyle(color: kMute, fontSize: 13.5, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              InkWell(
                borderRadius: BorderRadius.circular(99),
                onTap: () => ref.read(prefsProvider.notifier).set({'isDutyDay': !p.isDutyDay}),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: p.isDutyDay ? kSage : kButter,
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(color: p.isDutyDay ? kLine : kAmber),
                  ),
                  child: Text(
                    p.isDutyDay ? 'Duty Day' : 'Off Day',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: kInk,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if ((iniDays != null && iniDays >= 0) || (neetDays != null && neetDays >= 0))
            Panel(
              Row(
                children: [
                  if (iniDays != null && iniDays >= 0)
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('INI-CET DEADLINE',
                              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, letterSpacing: 1.4, color: kMute)),
                          const SizedBox(height: 4),
                          Text('$iniDays DAYS',
                              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: kInk, height: 1.05)),
                        ],
                      ),
                    ),
                  if ((iniDays != null && iniDays >= 0) && (neetDays != null && neetDays >= 0))
                    Container(width: 1.5, height: 44, margin: const EdgeInsets.symmetric(horizontal: 14), color: kLine),
                  if (neetDays != null && neetDays >= 0)
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('NEET PG DEADLINE',
                              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, letterSpacing: 1.4, color: kMute)),
                          const SizedBox(height: 4),
                          Text('$neetDays DAYS',
                              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: kAmber, height: 1.05)),
                        ],
                      ),
                    ),
                ],
              ),
              color: kButter,
            ),
          if (lockRemMs > 0)
            Panel(
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.lock_clock, color: kRed, size: 26),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'APP LOCKDOWN ACTIVE',
                              style: TextStyle(color: kRed, fontWeight: FontWeight.w700, letterSpacing: 1.5, fontSize: 12),
                            ),
                            Text(
                              '${_fmtRem(lockRemMs)} left · Clock & Settings tamper-locked',
                              style: const TextStyle(color: kInk, fontSize: 12.5),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  BigButton('Guardian Emergency Unlock (Mom/Dad PIN)', _guardianUnlockDialog, ghost: true),
                ],
              ),
              borderColor: kRed.withOpacity(.6),
            ),
          Panel(
            FutureBuilder<List<SessionRecord>>(
              future: Repo.since(today),
              builder: (_, s) {
                final mins = (s.data ?? []).fold<int>(0, (a, r) => a + r.focusedSec) ~/ 60;
                final goal = p.dailyGoalMin;
                final pct = goal <= 0 ? 0.0 : (mins / goal).clamp(0.0, 1.0);
                return Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _stat('${p.streak}${p.streakShields > 0 ? ' 🛡${p.streakShields}' : ''}', 'Streak'),
                        _stat(fmtMins(mins), 'Today'),
                        _stat(calib ? '-' : '${p.tokLeft}', 'Tokens'),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${p.isDutyDay ? 'Duty' : 'Off'} goal: ${fmtMins(mins)} / ${fmtMins(goal)}',
                          style: const TextStyle(fontSize: 13.5, color: kMute),
                        ),
                        Text(
                          '${(pct * 100).round()}%',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: pct >= 1.0 ? kGreen : kAmber,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: LinearProgressIndicator(
                        value: pct,
                        minHeight: 7,
                        backgroundColor: kLine,
                        color: pct >= 1.0 ? kGreen : kAmber,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          if (calib)
            Panel(
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Cap('Calibration day'),
                  const Text(
                    'Study normally. No penalties today. I count your natural distractions to set your baseline, then your daily pool becomes 50% of it.',
                  ),
                  const SizedBox(height: 8),
                  Text('Distractions logged: ${p.calibDist} · sessions: ${p.calibSessions}',
                      style: const TextStyle(color: kAmber)),
                  if (p.calibSessions > 0) ...[
                    const SizedBox(height: 10),
                    BigButton('Lock in my baseline',
                        () => ref.read(prefsProvider.notifier).lockBaseline(), ghost: true),
                  ],
                ],
              ),
            )
          else
            Panel(
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Cap("Today's tokens · ${p.tokLeft}/${p.pool}"),
                  Pips(p.tokLeft, p.pool),
                ],
              ),
            ),
          Panel(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Cap('Study setup', color: kInk),
                Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        label: const Text('Rear Cam Proctor'),
                        selected: !p.phoneStudyMode,
                        onSelected: (_) => ref.read(prefsProvider.notifier).set({'phoneStudyMode': false}),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ChoiceChip(
                        label: const Text('Phone Study (Marrow)'),
                        selected: p.phoneStudyMode,
                        onSelected: (_) => ref.read(prefsProvider.notifier).set({'phoneStudyMode': true}),
                      ),
                    ),
                  ],
                ),
                if (!p.phoneStudyMode) ...[
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () => _framingPreview(true),
                      icon: const Icon(Icons.crop_free, size: 18),
                      label: const Text('Check Rear Camera Framing', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => _pickSubject(p.lastSubject),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: kBg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: kLine),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.menu_book_outlined, color: kAmber, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(p.lastSubject,
                              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                        ),
                        const Text('19 Subjects', style: TextStyle(color: kAmber, fontSize: 12)),
                        const Icon(Icons.chevron_right, color: kAmber, size: 18),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    for (final m in kStudyModes)
                      ChoiceChip(
                        label: Text(m),
                        selected: p.lastMode == m,
                        onSelected: (_) => ref.read(prefsProvider.notifier).set({'lastMode': m}),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _goalCtl,
                  decoration: InputDecoration(
                    hintText: 'Goal / Topic (auto-saved to Spaced Repetition)',
                    hintStyle: const TextStyle(color: kMute, fontSize: 13),
                    filled: true,
                    fillColor: kBg,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: kLine),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: kLine),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                const Text('Random checks per minute (anti-cheat)',
                    style: TextStyle(fontSize: 13.5, color: kMute, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    for (final c in [1, 2, 3, 4, 6])
                      ChoiceChip(
                        label: Text('$c/min'),
                        selected: p.checksPerMin == c,
                        onSelected: (_) => ref.read(prefsProvider.notifier).set({'checksPerMin': c}),
                      )
                  ],
                ),
              ],
            ),
          ),
          BigButton(
            p.tokLeft == 0 && !calib && !p.phoneStudyMode
                ? 'No tokens left today'
                : 'Begin ${p.lastSubject} (${p.checksPerMin}/min random)',
            () async {
              if (p.tokLeft == 0 && !calib && !p.phoneStudyMode) return;
              final ok = await ref.read(sessionProvider.notifier).start(
                    subject: p.lastSubject,
                    mode: p.lastMode,
                    goalNote: _goalCtl.text,
                    phoneMode: p.phoneStudyMode,
                  );
              if (ok) {
                _goalCtl.clear();
              } else if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Camera permission is required for the proctor.')),
                );
              }
            },
          ),
          const SizedBox(height: 10),
          BigButton('Quick Strict Lock (Lock Apps Now)', _quickStrictLock, ghost: true),
        ],
      ),
    );
  }

  Widget _stat(String v, String l) => Column(
        children: [
          Text(v, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
          Text(l.toUpperCase(), style: const TextStyle(fontSize: 11.5, color: kMute, fontWeight: FontWeight.w700, letterSpacing: 1)),
        ],
      );
}
