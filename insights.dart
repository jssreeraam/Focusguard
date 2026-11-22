import 'package:flutter/material.dart';
import '../data/repo.dart';
import '../domain/models.dart';
import 'common.dart';

class InsightsScreen extends StatelessWidget {
  const InsightsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final from = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 29));
    return SafeArea(
      child: FutureBuilder<List<SessionRecord>>(
        future: Repo.since(from),
        builder: (_, s) {
          final rs = (s.data ?? []).where((r) => !r.calibration).toList();
          final days = List.generate(7, (i) {
            final d = DateTime(now.year, now.month, now.day).subtract(Duration(days: 6 - i));
            final m = rs
                    .where((r) => r.start.year == d.year && r.start.month == d.month && r.start.day == d.day)
                    .fold<int>(0, (a, r) => a + r.focusedSec) ~/
                60;
            return MapEntry(d, m);
          });
          final mx = days.fold<int>(1, (a, e) => e.value > a ? e.value : a);
          final hr = <int, List<double>>{};
          for (final r in rs) {
            for (var i = 0; i < r.checks.length; i++) {
              final h = r.start.add(Duration(seconds: i * r.intervalSec)).hour;
              (hr[h] ??= []).add(
                r.checks[i] == FocusState.study
                    ? 1.0
                    : r.checks[i] == FocusState.neutral
                        ? .5
                        : 0.0,
              );
            }
          }
          final ranked = hr.entries
              .where((e) => e.value.length >= 3)
              .map((e) => MapEntry(e.key, e.value.reduce((a, b) => a + b) / e.value.length))
              .toList()
            ..sort((a, b) => b.value.compareTo(a.value));
          String h(int x) => '${x % 12 == 0 ? 12 : x % 12}${x < 12 ? 'am' : 'pm'}';

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Text('INSIGHTS', style: TextStyle(color: kAmber, letterSpacing: 4, fontWeight: FontWeight.w700)),
              const SizedBox(height: 18),
              Panel(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Cap('Focused minutes · last 7 days'),
                    SizedBox(
                      height: 140,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          for (final e in days)
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Text('${e.value}', style: const TextStyle(fontSize: 11, color: kMute)),
                                  TweenAnimationBuilder<double>(
                                    tween: Tween<double>(begin: 0, end: e.value / mx),
                                    duration: const Duration(milliseconds: 900),
                                    curve: Curves.easeOutCubic,
                                    builder: (_, v, __) => Container(
                                      height: 4 + 90 * v,
                                      margin: const EdgeInsets.symmetric(horizontal: 5),
                                      decoration: BoxDecoration(
                                        color: kAmber,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    ['M', 'T', 'W', 'T', 'F', 'S', 'S'][e.key.weekday - 1],
                                    style: const TextStyle(fontSize: 11, color: kMute),
                                  ),
                                ],
                              ),
                            )
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Panel(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Cap('Your attention pattern'),
                    if (ranked.length < 2)
                      const Text(
                        'Complete a few more sessions and I will show your strongest and weakest hours.',
                        style: TextStyle(color: kMute),
                      )
                    else ...[
                      Text(
                        'Sharpest around ${h(ranked.first.key)}  (${(ranked.first.value * 100).round()}% focus)',
                        style: TextStyle(color: FocusState.study.color, fontSize: 16),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Drifts around ${h(ranked.last.key)}  (${(ranked.last.value * 100).round()}% focus)',
                        style: TextStyle(color: FocusState.distraction.color, fontSize: 16),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Put your hardest subject in the sharp window.',
                        style: TextStyle(color: kMute, fontSize: 13),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
