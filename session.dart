import 'dart:math';
import 'dart:ui' show FontFeature;
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/repo.dart';
import '../domain/models.dart';
import '../state/providers.dart';
import 'common.dart';

class RingPainter extends CustomPainter {
  final double p;
  final Color c;
  RingPainter(this.p, this.c);

  @override
  void paint(Canvas cv, Size s) {
    final r = Rect.fromCircle(center: s.center(Offset.zero), radius: s.width / 2 - 8);
    cv.drawArc(
      r, 0, 2 * pi, false,
      Paint()..style = PaintingStyle.stroke..strokeWidth = 8..color = Colors.white.withOpacity(.16),
    );
    cv.drawArc(
      r, -pi / 2, 2 * pi * p, false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 14
        ..color = c.withOpacity(.30)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    cv.drawArc(
      r, -pi / 2, 2 * pi * p, false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8
        ..strokeCap = StrokeCap.round
        ..color = c,
    );
  }

  @override
  bool shouldRepaint(RingPainter o) => o.p != p || o.c != c;
}

class SessionScreen extends ConsumerStatefulWidget {
  const SessionScreen({super.key});
  @override
  ConsumerState<SessionScreen> createState() => _S();
}

class _S extends ConsumerState<SessionScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _br =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 3400))
        ..repeat(reverse: true);
  bool _dimmed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _br.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final ctl = ref.read(sessionProvider.notifier);
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      ctl.pauseCamera();
    } else if (state == AppLifecycleState.resumed) {
      ctl.resumeCamera().then((_) {
        if (mounted) setState(() {});
      });
    }
  }

  String _mmss(int s) {
    final clamped = max(0, s);
    final h = clamped ~/ 3600;
    final m = (clamped % 3600) ~/ 60;
    final sec = clamped % 60;
    if (h > 0) {
      return '$h:${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(sessionProvider);
    final ctl = ref.read(sessionProvider.notifier);
    final iv = ref.read(prefsProvider).intervalSec;
    final col = s.phoneMode ? const Color(0xFF7AE29E) : s.last.color;
    final cam = ctl.vision.cam;

    if (_dimmed) {
      return GestureDetector(
        onTap: () => setState(() => _dimmed = false),
        child: Container(
          color: Colors.black,
          alignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _mmss(s.total - s.elapsed),
                style: const TextStyle(
                  fontSize: 44,
                  color: Color(0xFF444455),
                  fontWeight: FontWeight.w700,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'STEALTH DIM · TAP TO WAKE',
                style: TextStyle(color: Color(0xFF333344), letterSpacing: 2, fontSize: 11),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF22303C), Color(0xFF1A242F)],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.hardcoreGt
                              ? 'HARDCORE GT'
                              : (s.phoneMode
                                  ? 'PHONE STUDY'
                                  : (s.calib ? 'CALIBRATING' : 'STUDYING')),
                          style: TextStyle(
                            color: s.hardcoreGt ? const Color(0xFFFF7A7A) : const Color(0xFFFFCE7A),
                            letterSpacing: 3,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${s.subject} · ${s.mode}',
                          style: const TextStyle(color: Colors.white70, fontSize: 13),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Offline Brown Noise',
                    icon: Icon(
                      s.brownNoise ? Icons.graphic_eq : Icons.headphones_outlined,
                      color: s.brownNoise ? const Color(0xFFFFCE7A) : Colors.white60,
                    ),
                    onPressed: () => ctl.toggleBrownNoise(),
                  ),
                  IconButton(
                    tooltip: 'Stealth Dim',
                    icon: const Icon(Icons.brightness_2_outlined, color: Colors.white60),
                    onPressed: () => setState(() => _dimmed = true),
                  ),
                  if (!s.phoneMode && cam != null && cam.value.isInitialized && cam.value.previewSize != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: SizedBox(
                        width: 48,
                        height: 64,
                        child: FittedBox(
                          fit: BoxFit.cover,
                          clipBehavior: Clip.hardEdge,
                          child: SizedBox(
                            width: cam.value.previewSize!.height,
                            height: cam.value.previewSize!.width,
                            child: CameraPreview(cam),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              if (s.goalNote.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    'Goal: ${s.goalNote}',
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              const Spacer(),
              // Cozy 2D Illustrated Study Companion + Breathing Ring
              AnimatedBuilder(
                animation: _br,
                builder: (_, __) {
                  final bob = sin(_br.value * pi) * 5.0;
                  return SizedBox(
                    width: 266,
                    height: 266,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 214 + _br.value * 14,
                          height: 214 + _br.value * 14,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFFFC971).withOpacity(.18 + _br.value * .14),
                                blurRadius: 48,
                                spreadRadius: 6,
                              )
                            ],
                          ),
                        ),
                        TweenAnimationBuilder<double>(
                          tween: Tween<double>(end: s.total == 0 ? 0.0 : s.elapsed / s.total),
                          duration: const Duration(seconds: 1),
                          builder: (_, v, __) => CustomPaint(
                            size: const Size(266, 266),
                            painter: RingPainter(v, col),
                          ),
                        ),
                        Transform.translate(
                          offset: Offset(0, -bob),
                          child: ClipOval(
                            child: SizedBox(
                              width: 210,
                              height: 210,
                              child: Image.asset('assets/study_girl.png', fit: BoxFit.cover),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 14),
              Text(
                _mmss(s.total - s.elapsed),
                style: const TextStyle(
                  fontSize: 46,
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: col.withOpacity(.18),
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(color: col),
                ),
                child: Text(
                  s.phoneMode ? 'DISTRACTION APPS LOCKED' : s.last.label.toUpperCase(),
                  style: TextStyle(color: col, fontSize: 11.5, fontWeight: FontWeight.w700, letterSpacing: 1.8),
                ),
              ),
              const Spacer(),
              if (!s.calib && !s.phoneMode) Pips(s.tokens, s.maxTokens),
              const SizedBox(height: 12),
              if (!s.phoneMode)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(.08),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'TIMELINE · NEXT CHECK IN ${iv - (s.elapsed % iv)}S',
                        style: const TextStyle(color: Colors.white60, fontSize: 10.5, letterSpacing: 1.4, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      Timeline(s.checks.length > 40 ? s.checks.sublist(s.checks.length - 40) : s.checks),
                      const SizedBox(height: 6),
                      Text(
                        s.checks.isEmpty ? 'Quietly studying together.' : s.last.message,
                        style: const TextStyle(color: Colors.white70, fontSize: 12.5),
                      ),
                    ],
                  ),
                ),
              BigButton(
                s.hardcoreGt ? 'Abandon Hardcore GT (Triggers Lock!)' : 'End session early',
                () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text('End session?'),
                      content: Text(
                        s.hardcoreGt
                            ? 'Abandoning a 3h Hardcore GT triggers your full app lockdown immediately.'
                            : (ref.read(prefsProvider).streakReset && !s.calib
                                ? 'Your streak will reset (unless protected by a Streak Shield).'
                                : 'This ends the session.'),
                      ),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Keep going')),
                        TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('End')),
                      ],
                    ),
                  );
                  if (ok == true) ctl.abandon();
                },
                ghost: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class LockScreen extends ConsumerWidget {
  const LockScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(sessionProvider);
    final p = ref.watch(prefsProvider);
    return Container(
      color: const Color(0xFF2B181C),
      padding: const EdgeInsets.all(30),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'PENALTY TRIGGERED',
              style: TextStyle(color: Color(0xFFFF8A8A), letterSpacing: 5, fontSize: 13, decoration: TextDecoration.none),
            ),
            TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: .6, end: 1),
              duration: const Duration(milliseconds: 600),
              curve: Curves.elasticOut,
              builder: (_, v, __) => Transform.scale(
                scale: v,
                child: Text(
                  '${s.cooldown}',
                  style: const TextStyle(
                    fontSize: 110,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFFFF8A8A),
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
            ),
            Text(
              'Cooldown.${p.lockHours > 0 && p.pkgs.isNotEmpty ? ' Selected apps locked for ${p.lockHours}h (anti-tamper active).' : ''}
Sit up. Breathe. Repair your Citadel with a 90%+ focus block.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white70,
                height: 1.5,
                fontSize: 15,
                decoration: TextDecoration.none,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SummaryScreen extends ConsumerStatefulWidget {
  const SummaryScreen({super.key});
  @override
  ConsumerState<SummaryScreen> createState() => _SummaryScreenState();
}

class _SummaryScreenState extends ConsumerState<SummaryScreen> {
  late final TextEditingController _noteCtl;
  final _mcqCtl = TextEditingController();
  final _correctCtl = TextEditingController();
  bool _addToSr = true;
  bool _highYield = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final r = ref.read(sessionProvider).result;
    _noteCtl = TextEditingController(text: r?.note ?? '');
  }

  @override
  void dispose() {
    _noteCtl.dispose();
    _mcqCtl.dispose();
    _correctCtl.dispose();
    super.dispose();
  }

  Future<void> _saveAndClose() async {
    if (_saving) return;
    setState(() => _saving = true);
    final ss = ref.read(sessionProvider);
    final r = ss.result;
    final note = _noteCtl.text.trim();
    final mcqs = int.tryParse(_mcqCtl.text.trim()) ?? 0;
    final correct = int.tryParse(_correctCtl.text.trim()) ?? 0;

    if (ss.savedSessionId != null && ss.savedSessionId! > 0) {
      await Repo.updateSessionExtras(
        ss.savedSessionId!,
        note: note,
        mcqs: mcqs,
        correct: correct,
      );
    }
    if (_addToSr && note.isNotEmpty && r != null) {
      await Repo.addRevision(
        subject: r.subject,
        topic: note,
        highYield: _highYield,
      );
    }
    ref.read(dbVersionProvider.notifier).state++;
    ref.read(sessionProvider.notifier).dismiss();
  }

  @override
  Widget build(BuildContext context) {
    final r = ref.watch(sessionProvider).result;
    final p = ref.watch(prefsProvider);
    if (r == null) {
      return SafeArea(
        child: Center(
          child: BigButton('Return Home', () => ref.read(sessionProvider.notifier).dismiss()),
        ),
      );
    }
    final pct = (r.score * 100).round();
    final combo = r.completed && r.score >= 0.90;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                r.completed ? 'SESSION COMPLETE' : 'SESSION ENDED',
                style: const TextStyle(color: kInk, letterSpacing: 2.5, fontWeight: FontWeight.w800),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: combo ? kSage : kButter,
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  '+${r.xp} XP${combo ? ' · 2× COMBO' : ''}',
                  style: const TextStyle(color: kInk, fontSize: 12, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text('${r.subject} · ${r.mode}', style: const TextStyle(color: kMute, fontSize: 14)),
          const SizedBox(height: 12),
          Center(
            child: TweenAnimationBuilder<int>(
              tween: IntTween(begin: 0, end: pct),
              duration: const Duration(milliseconds: 1200),
              curve: Curves.easeOutCubic,
              builder: (_, v, __) => Text(
                '$v%',
                style: const TextStyle(fontSize: 72, fontWeight: FontWeight.w800, color: kInk),
              ),
            ),
          ),
          Center(
            child: Text(
              '${fmtMins(r.focusedSec ~/ 60)} focused${r.calibration ? ' · calibration' : ''}',
              style: const TextStyle(color: kMute),
            ),
          ),
          const SizedBox(height: 16),
          Panel(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Cap('Study log & spaced repetition (+1, +3, +7, +21, +45d)'),
                TextField(
                  controller: _noteCtl,
                  decoration: InputDecoration(
                    hintText: 'Topic studied (e.g., OBG Antepartum Hemorrhage)',
                    hintStyle: const TextStyle(color: kMute, fontSize: 13),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  children: [
                    FilterChip(
                      label: const Text('Add to Revise Queue'),
                      selected: _addToSr,
                      onSelected: (v) => setState(() => _addToSr = v),
                    ),
                    FilterChip(
                      label: const Text('High-Yield ★'),
                      selected: _highYield,
                      onSelected: (v) => setState(() => _highYield = v),
                    ),
                  ],
                ),
              ],
            ),
            color: kLavender,
          ),
          Panel(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Cap('Optional: Log MCQs / Grand Test Score'),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _mcqCtl,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'MCQs solved',
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _correctCtl,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: r.mode == 'Grand Test' ? 'GT Correct /200' : 'Correct',
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            color: kSky,
          ),
          FutureBuilder<List<SessionRecord>>(
            future: Repo.since(DateTime(DateTime.now().year, DateTime.now().month, 1)),
            builder: (_, snap) {
              final monthXp = (snap.data ?? []).fold<int>(0, (a, e) => a + e.xp) + p.revXpMonth;
              return Panel(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Cap('Monthly Citadel Progress'),
                    CitadelWidget(progress: monthXp / 6000.0, cracks: p.citadelCracks, height: 130),
                  ],
                ),
                color: kSage,
              );
            },
          ),
          BigButton(_saving ? 'Saving...' : 'Save & Continue', _saveAndClose),
        ],
      ),
    );
  }
}
