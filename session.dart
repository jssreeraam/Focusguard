import 'dart:math';
import 'dart:ui' show FontFeature;
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
      Paint()..style = PaintingStyle.stroke..strokeWidth = 8..color = kLine,
    );
    cv.drawArc(
      r, -pi / 2, 2 * pi * p, false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 14
        ..color = c.withOpacity(.25)
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
      AnimationController(vsync: this, duration: const Duration(milliseconds: 2600))
        ..repeat(reverse: true);

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
    return '${(clamped ~/ 60).toString().padLeft(2, '0')}:${(clamped % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(sessionProvider);
    final ctl = ref.read(sessionProvider.notifier);
    final iv = ref.read(prefsProvider).intervalSec;
    final col = s.last.color;
    final cam = ctl.vision.cam;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                Text(
                  s.calib ? 'CALIBRATING' : 'FOCUS',
                  style: const TextStyle(color: kAmber, letterSpacing: 4, fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                if (cam != null && cam.value.isInitialized && cam.value.previewSize != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      width: 54,
                      height: 72,
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
            const Spacer(),
            TweenAnimationBuilder<Color?>(
              tween: ColorTween(end: col),
              duration: const Duration(milliseconds: 600),
              builder: (_, color, __) {
                final c = color ?? col;
                return TweenAnimationBuilder<double>(
                  key: ValueKey(s.checks.length),
                  tween: Tween<double>(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 1200),
                  builder: (_, t, __) {
                    final shake = s.lastCost > 0 ? sin(t * pi * 7) * (1 - t) * 12 : 0.0;
                    return Transform.translate(
                      offset: Offset(shake, 0),
                      child: SizedBox(
                        width: 280,
                        height: 280,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            AnimatedBuilder(
                              animation: _br,
                              builder: (_, __) => Container(
                                width: 180 + _br.value * 28,
                                height: 180 + _br.value * 28,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: c.withOpacity(.25 + _br.value * .2),
                                      blurRadius: 60,
                                      spreadRadius: 10,
                                    )
                                  ],
                                ),
                              ),
                            ),
                            TweenAnimationBuilder<double>(
                              tween: Tween<double>(end: s.total == 0 ? 0.0 : s.elapsed / s.total),
                              duration: const Duration(seconds: 1),
                              builder: (_, v, __) => CustomPaint(
                                size: const Size(280, 280),
                                painter: RingPainter(v, c),
                              ),
                            ),
                            Positioned(
                              top: 25 + 230 * t,
                              left: 40,
                              right: 40,
                              child: Opacity(
                                opacity: max(0.0, sin(t * pi)),
                                child: Container(
                                  height: 2,
                                  decoration: const BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [Colors.transparent, kAmber, Colors.transparent],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _mmss(s.total - s.elapsed),
                                  style: const TextStyle(
                                    fontSize: 56,
                                    fontWeight: FontWeight.w700,
                                    fontFeatures: [FontFeature.tabularFigures()],
                                  ),
                                ),
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 500),
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(99),
                                    border: Border.all(color: c),
                                  ),
                                  child: Text(
                                    s.last.label.toUpperCase(),
                                    style: TextStyle(color: c, fontSize: 12, letterSpacing: 2),
                                  ),
                                ),
                              ],
                            )
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
            const Spacer(),
            if (!s.calib) Pips(s.tokens, s.maxTokens),
            const SizedBox(height: 14),
            Panel(
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Cap('Timeline · next check in ${iv - (s.elapsed % iv)}s'),
                  Timeline(s.checks.length > 40 ? s.checks.sublist(s.checks.length - 40) : s.checks),
                  const SizedBox(height: 8),
                  Text(
                    s.checks.isEmpty ? 'Eyes on the desk.' : s.last.message,
                    style: const TextStyle(color: kMute, fontSize: 13),
                  ),
                ],
              ),
            ),
            BigButton(
              'Abandon session',
              () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('Abandon?'),
                    content: Text(
                      ref.read(prefsProvider).streakReset && !s.calib
                          ? 'Your streak will reset.'
                          : 'This ends the session.',
                    ),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Keep going')),
                      TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Abandon')),
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
      color: const Color(0xFF120508),
      padding: const EdgeInsets.all(30),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'TOKENS EXHAUSTED',
              style: TextStyle(color: kRed, letterSpacing: 5, fontSize: 13, decoration: TextDecoration.none),
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
                    color: kRed,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
            ),
            Text(
              'Cooldown.${p.streakReset ? ' Streak reset.' : ''}${p.lockHours > 0 && p.pkgs.isNotEmpty ? ' Selected apps locked for ${p.lockHours}h (anti-tamper active).' : ''}
Sit up. Breathe. Earn it back tomorrow.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFFC9A0A6),
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

class SummaryScreen extends ConsumerWidget {
  const SummaryScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = ref.watch(sessionProvider).result;
    if (r == null) {
      return SafeArea(
        child: Center(
          child: BigButton('Return Home', () => ref.read(sessionProvider.notifier).dismiss()),
        ),
      );
    }
    final pct = (r.score * 100).round();
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            r.completed ? 'SESSION COMPLETE' : 'SESSION ENDED',
            style: const TextStyle(color: kAmber, letterSpacing: 4, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 20),
          Center(
            child: TweenAnimationBuilder<int>(
              tween: IntTween(begin: 0, end: pct),
              duration: const Duration(milliseconds: 1400),
              curve: Curves.easeOutCubic,
              builder: (_, v, __) => Text(
                '$v%',
                style: const TextStyle(fontSize: 84, fontWeight: FontWeight.w800, color: kAmber),
              ),
            ),
          ),
          Center(
            child: Text(
              '${r.focusedSec ~/ 60} focused minutes${r.calibration ? ' · calibration' : ''}',
              style: const TextStyle(color: kMute),
            ),
          ),
          const SizedBox(height: 20),
          Panel(
            Column(
              children: [
                Timeline(r.checks),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _s('${r.count(FocusState.study)}', 'Study', FocusState.study.color),
                    _s('${r.count(FocusState.neutral)}', 'Neutral', FocusState.neutral.color),
                    _s('${r.count(FocusState.distraction)}', 'Distracted', FocusState.distraction.color),
                    _s('${r.count(FocusState.absent)}', 'Absent', FocusState.absent.color),
                  ],
                ),
              ],
            ),
          ),
          BigButton('Done', () => ref.read(sessionProvider.notifier).dismiss()),
        ],
      ),
    );
  }

  Widget _s(String v, String l, Color c) => Column(
        children: [
          Text(v, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: c)),
          Text(l.toUpperCase(), style: const TextStyle(fontSize: 9, color: kMute, letterSpacing: 1)),
        ],
      );
}
