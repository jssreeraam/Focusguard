import 'dart:async';
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
  int len = 50;
  int lockRemMs = 0;
  Timer? _poll;

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

  String _fmtRem(int ms) {
    final totalMin = (ms ~/ 60000).clamp(1, 99999).toInt();
    final h = totalMin ~/ 60;
    final m = totalMin % 60;
    return h > 0 ? '${h}h ${m}m' : '${m}m';
  }

  @override
  Widget build(BuildContext context) {
    final p = ref.watch(prefsProvider);
    final calib = p.baseline == 0;
    final now = DateTime.now();

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
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'FOCUSGUARD',
                    style: TextStyle(color: kAmber, letterSpacing: 4, fontWeight: FontWeight.w700),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'The Digital Study Warden.',
                    style: TextStyle(color: kMute, fontSize: 13),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (lockRemMs > 0)
            Panel(
              Row(
                children: [
                  const Icon(Icons.lock_clock, color: kRed, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'APP LOCKDOWN ACTIVE',
                          style: TextStyle(color: kRed, fontWeight: FontWeight.w700, letterSpacing: 1.5, fontSize: 12),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${_fmtRem(lockRemMs)} remaining · Clock & Settings tamper-locked',
                          style: const TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              borderColor: kRed.withOpacity(.6),
            ),
          Panel(
            FutureBuilder<List<SessionRecord>>(
              future: Repo.since(DateTime(now.year, now.month, now.day)),
              builder: (_, s) {
                final mins = (s.data ?? [])
                        .where((r) => !r.calibration)
                        .fold<int>(0, (a, r) => a + r.focusedSec) ~/
                    60;
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _stat('${p.streak}', 'Streak'),
                    _stat('$mins', 'Focus min today'),
                    _stat(calib ? '-' : '${p.tokLeft}', 'Tokens'),
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
                  const SizedBox(height: 10),
                  Text(
                    'Distractions logged today: ${p.calibDist} · sessions: ${p.calibSessions}',
                    style: const TextStyle(color: kAmber),
                  ),
                  if (p.calibSessions > 0) ...[
                    const SizedBox(height: 12),
                    BigButton(
                      'Lock in my baseline',
                      () => ref.read(prefsProvider.notifier).lockBaseline(),
                      ghost: true,
                    ),
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
                const Cap('Session length'),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final v in [25, 50, 90, 120])
                      ChoiceChip(
                        label: Text('$v min'),
                        selected: len == v,
                        onSelected: (_) => setState(() => len = v),
                      )
                  ],
                ),
              ],
            ),
          ),
          BigButton(
            p.tokLeft == 0 && !calib ? 'No tokens left today' : 'Begin session',
            () async {
              if (p.tokLeft == 0 && !calib) return;
              final ok = await ref.read(sessionProvider.notifier).start(len);
              if (!ok && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Camera permission is required for the on-device proctor.'),
                  ),
                );
              }
            },
          ),
          const SizedBox(height: 10),
          const Text(
            'Prop the phone facing you. Frames are processed locally in memory and discarded immediately.',
            textAlign: TextAlign.center,
            style: TextStyle(color: kMute, fontSize: 12.5),
          ),
        ],
      ),
    );
  }

  Widget _stat(String v, String l) => Column(
        children: [
          Text(v, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700)),
          Text(l.toUpperCase(), style: const TextStyle(fontSize: 10, color: kMute, letterSpacing: 1)),
        ],
      );
}
