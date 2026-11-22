import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/repo.dart';
import '../domain/models.dart';
import '../state/providers.dart';
import 'common.dart';

class GradeRingPainter extends CustomPainter {
  final double score;
  final Color c;
  GradeRingPainter(this.score, this.c);

  @override
  void paint(Canvas cv, Size s) {
    final r = Rect.fromCircle(center: s.center(Offset.zero), radius: s.width / 2 - 8);
    cv.drawArc(
      r, 0, 2 * pi, false,
      Paint()..style = PaintingStyle.stroke..strokeWidth = 8..color = Colors.white.withOpacity(.14),
    );
    cv.drawArc(
      r, -pi / 2, 2 * pi * score.clamp(0.0, 1.0), false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8
        ..strokeCap = StrokeCap.round
        ..color = c,
    );
  }

  @override
  bool shouldRepaint(GradeRingPainter o) => o.score != score || o.c != c;
}

class SessionScreen extends ConsumerStatefulWidget {
  const SessionScreen({super.key});
  @override
  ConsumerState<SessionScreen> createState() => _S();
}

class _S extends ConsumerState<SessionScreen> with WidgetsBindingObserver {
  bool _dimmed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final ctl = ref.read(sessionProvider.notifier);
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      ctl.pauseCamera();
    } else if (state == AppLifecycleState.resumed) {
      ctl.resumeCamera();
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(sessionProvider);
    final ctl = ref.read(sessionProvider.notifier);
    final col = s.phoneMode ? const Color(0xFF7AE29E) : s.last.color;
    final pct = (s.liveScore * 100).round();

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
                '$pct%',
                style: const TextStyle(
                  fontSize: 46,
                  color: Color(0xFF444455),
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${s.checks.length} GRADED · STEALTH BATTERY MODE',
                style: const TextStyle(color: Color(0xFF333344), letterSpacing: 1.8, fontSize: 11),
              ),
              const SizedBox(height: 4),
              const Text(
                'TAP TO WAKE',
                style: TextStyle(color: Color(0xFF282836), letterSpacing: 2, fontSize: 10),
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
                          s.phoneMode
                              ? 'PHONE STUDY'
                              : (s.calib ? 'CALIBRATING' : 'RANDOM PROCTOR'),
                          style: const TextStyle(
                            color: Color(0xFFFFCE7A),
                            letterSpacing: 3,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${s.subject} · ${s.mode}${s.phoneMode ? '' : ' · ${s.checksPerMin}/min random'}',
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
                    tooltip: 'Stealth Battery Mode',
                    icon: const Icon(Icons.brightness_2_outlined, color: Colors.white60),
                    onPressed: () => setState(() => _dimmed = true),
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
              // Static low-battery 2D Study Girl + Live Focus Grade Ring (no 60fps burn!)
              SizedBox(
                width: 248,
                height: 248,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CustomPaint(
                      size: const Size(248, 248),
                      painter: GradeRingPainter(s.liveScore, col),
                    ),
                    ClipOval(
                      child: SizedBox(
                        width: 204,
                        height: 204,
                        child: Image.asset('assets/study_girl.png', fit: BoxFit.cover),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Text(
                s.phoneMode ? 'LOCKED IN' : '$pct% FOCUS',
                style: const TextStyle(
                  fontSize: 36,
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
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
                  s.phoneMode
                      ? 'DISTRACTION APPS LOCKED'
                      : '${s.last.label.toUpperCase()} · ${s.checks.length} GRADED',
                  style: TextStyle(color: col, fontSize: 11.5, fontWeight: FontWeight.w700, letterSpacing: 1.6),
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
                        'GRADINGS · ${s.checksPerMin} RANDOM CHECKS/MIN (NO TIMER)',
                        style: const TextStyle(color: Colors.white60, fontSize: 10.5, letterSpacing: 1.3, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      Timeline(s.checks.length > 40 ? s.checks.sublist(s.checks.length - 40) : s.checks),
                      const SizedBox(height: 6),
                      Text(
                        ctl.vision.lastInfo,
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                )
              else
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(.08),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Phone-Study Mode active: Distraction apps are locked while you use Marrow / PrepLadder / Anki. Tap Finish & Save when done.',
                    style: TextStyle(color: Colors.white70, fontSize: 12.5),
                  ),
                ),
              BigButton(
                'Finish & Save Study Block',
                () => ctl.finishSession(),
                fill: kAmber,
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
            Text(
              '${s.cooldown}',
              style: const TextStyle(
                fontSize: 110,
                fontWeight: FontWeight.w800,
                color: Color(0xFFFF8A8A),
                decoration: TextDecoration.none,
              ),
            ),
            Text(
              'Cooldown.${p.lockHours > 0 && p.pkgs.isNotEmpty ? ' Selected apps locked for ${p.lockHours}h (anti-tamper active).' : ''}\nSit up. Breathe. Repair your Citadel with a 90%+ focus block.',
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
              const Text(
                'GRADING COMPLETE',
                style: TextStyle(color: kInk, letterSpacing: 2.5, fontWeight: FontWeight.w800),
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
            child: Text(
              '$pct%',
              style: const TextStyle(fontSize: 72, fontWeight: FontWeight.w800, color: kInk),
            ),
          ),
          Center(
            child: Text(
              '${fmtMins(r.focusedSec ~/ 60)} focused · ${r.checks.length} random checks${r.calibration ? ' · calibration' : ''}',
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
