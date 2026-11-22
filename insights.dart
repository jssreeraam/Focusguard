import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/repo.dart';
import '../domain/models.dart';
import '../state/providers.dart';
import 'common.dart';

class InsightsScreen extends ConsumerWidget {
  const InsightsScreen({super.key});

  String _dayLabel(DateTime d, DateTime today) {
    final diff = today.difference(DateTime(d.year, d.month, d.day)).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    const wdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return '${wdays[d.weekday - 1]}, ${d.day} ${months[d.month - 1]}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(dbVersionProvider);
    final prefs = ref.watch(prefsProvider);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final from30 = today.subtract(const Duration(days: 29));
    final monthStart = DateTime(now.year, now.month, 1);

    return SafeArea(
      child: FutureBuilder<List<SessionRecord>>(
        future: Repo.allSessions(),
        builder: (_, snap) {
          final allEver = snap.data ?? const <SessionRecord>[];
          final last30 = allEver.where((r) => !r.start.isBefore(from30)).toList();
          final thisMonth = allEver.where((r) => !r.start.isBefore(monthStart)).toList();
          final todayRecs = last30
              .where((r) =>
                  r.start.year == today.year &&
                  r.start.month == today.month &&
                  r.start.day == today.day)
              .toList();

          final totalHoursEver = allEver.fold<int>(0, (a, r) => a + r.focusedSec) ~/ 3600;
          final monthXp = thisMonth.fold<int>(0, (a, r) => a + r.xp) + prefs.revXpMonth;
          final todayMin = todayRecs.fold<int>(0, (a, r) => a + r.focusedSec) ~/ 60;
          final todayMcqs = todayRecs.fold<int>(0, (a, r) => a + r.mcqs);
          final totalMcqsEver = allEver.fold<int>(0, (a, r) => a + r.mcqs);
          final todayScore = todayRecs.isEmpty
              ? 0
              : (todayRecs.fold<double>(0, (a, r) => a + r.score) / todayRecs.length * 100).round();

          // 24-hour today study strip
          final activeHoursToday = <int>{};
          for (final r in todayRecs) {
            final end = r.start.add(Duration(minutes: (r.focusedSec ~/ 60).clamp(1, 360)));
            for (var h = r.start.hour; h <= end.hour && h < 24; h++) {
              activeHoursToday.add(h);
            }
          }

          // 30-day YPT heatmap
          final heatmap = List.generate(30, (i) {
            final d = today.subtract(Duration(days: 29 - i));
            final m = last30
                    .where((r) => r.start.year == d.year && r.start.month == d.month && r.start.day == d.day)
                    .fold<int>(0, (a, r) => a + r.focusedSec) ~/
                60;
            return MapEntry(d, m);
          });

          // Last 7 days bars
          final days7 = heatmap.sublist(23);
          final mx = days7.fold<int>(1, (a, e) => e.value > a ? e.value : a);

          // 19-Subject coverage & Neglected Subject Radar
          final subSec30 = <String, int>{};
          final lastTouched = <String, DateTime>{};
          final modeSec = <String, int>{};
          for (final r in allEver) {
            if (!lastTouched.containsKey(r.subject) || r.start.isAfter(lastTouched[r.subject]!)) {
              lastTouched[r.subject] = r.start;
            }
          }
          for (final r in last30) {
            subSec30[r.subject] = (subSec30[r.subject] ?? 0) + r.focusedSec;
            modeSec[r.mode] = (modeSec[r.mode] ?? 0) + r.focusedSec;
          }
          final subjects = subSec30.entries.where((e) => e.value > 0).toList()
            ..sort((a, b) => b.value.compareTo(a.value));
          final topSubSec = subjects.isEmpty ? 1 : subjects.first.value;

          final neglected = kNeetSubjects
              .where((s) => s != 'General')
              .map((s) {
                final dt = lastTouched[s];
                final days = dt == null ? 999 : today.difference(DateTime(dt.year, dt.month, dt.day)).inDays;
                return MapEntry(s, days);
              })
              .toList()
            ..sort((a, b) => b.value.compareTo(a.value));

          // Grand Test score trend
          final gts = allEver.where((r) => r.mode == 'Grand Test' && r.correct > 0).take(6).toList().reversed.toList();

          // Milestone Badges
          final badges = <Map<String, dynamic>>[
            {'name': '100% Focus', 'ok': allEver.any((r) => r.completed && r.score >= 0.99)},
            {'name': '3h GT Survivor', 'ok': allEver.any((r) => r.completed && r.plannedMin >= 180)},
            {'name': '500 MCQs', 'ok': totalMcqsEver >= 500},
            {'name': '19/19 Subjects', 'ok': lastTouched.keys.where((k) => k != 'General').length >= 19},
            {'name': '30d Streak', 'ok': prefs.streak >= 30},
            {'name': 'Citadel 100%', 'ok': monthXp >= 6000},
          ];

          // Day-by-day study log (last 14 active days)
          final dailyLog = <Map<String, dynamic>>[];
          for (var i = 0; i < 14; i++) {
            final d = today.subtract(Duration(days: i));
            final recs = last30
                .where((r) => r.start.year == d.year && r.start.month == d.month && r.start.day == d.day)
                .toList();
            if (recs.isEmpty) continue;
            final mins = recs.fold<int>(0, (a, r) => a + r.focusedSec) ~/ 60;
            final mcqs = recs.fold<int>(0, (a, r) => a + r.mcqs);
            final avgScore = (recs.fold<double>(0, (a, r) => a + r.score) / recs.length * 100).round();
            final subs = recs.map((r) => r.subject).toSet().toList();
            final notes = recs.map((r) => r.note).where((n) => n.isNotEmpty).toList();
            dailyLog.add({
              'date': d,
              'mins': mins,
              'mcqs': mcqs,
              'score': avgScore,
              'subjects': subs,
              'notes': notes,
            });
          }

          // Hourly attention pattern
          final hr = <int, List<double>>{};
          for (final r in last30) {
            for (var i = 0; i < r.checks.length; i++) {
              final h = r.start.add(Duration(seconds: i * r.intervalSec)).hour;
              (hr[h] ??= []).add(
                r.checks[i] == FocusState.study ? 1.0 : r.checks[i] == FocusState.neutral ? .5 : 0.0,
              );
            }
          }
          final ranked = hr.entries
              .where((e) => e.value.length >= 3)
              .map((e) => MapEntry(e.key, e.value.reduce((a, b) => a + b) / e.value.length))
              .toList()
            ..sort((a, b) => b.value.compareTo(a.value));
          String hFmt(int x) => '${x % 12 == 0 ? 12 : x % 12}${x < 12 ? 'am' : 'pm'}';

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('STATS & CITADEL',
                      style: TextStyle(color: kInk, letterSpacing: 2.5, fontWeight: FontWeight.w800)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: kAmber.withOpacity(.16),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      aspirantRank(totalHoursEver),
                      style: const TextStyle(color: kAmber, fontSize: 10.5, fontWeight: FontWeight.w700, letterSpacing: 1),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Panel(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Cap('Monthly Citadel · $monthXp / 6000 XP'),
                    CitadelWidget(progress: monthXp / 6000.0, cracks: prefs.citadelCracks),
                  ],
                ),
              ),
              Panel(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Cap('Today snapshot'),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _kpi(fmtMins(todayMin), 'Today', kAmber),
                        _kpi('$todayScore%', 'Focus', kGreen),
                        _kpi('$todayMcqs', 'MCQs', kBlue),
                        _kpi('${prefs.streak}d', 'Streak', Colors.white),
                      ],
                    ),
                    const SizedBox(height: 14),
                    const Text('24-HOUR STUDY TIMELINE (TODAY)',
                        style: TextStyle(fontSize: 10, letterSpacing: 1.2, color: kMute)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        for (var h = 0; h < 24; h++)
                          Expanded(
                            child: Container(
                              height: 14,
                              margin: const EdgeInsets.symmetric(horizontal: 1),
                              decoration: BoxDecoration(
                                color: activeHoursToday.contains(h) ? kAmber : kBg,
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('12a', style: TextStyle(fontSize: 9, color: kMute)),
                        Text('6a', style: TextStyle(fontSize: 9, color: kMute)),
                        Text('12p', style: TextStyle(fontSize: 9, color: kMute)),
                        Text('6p', style: TextStyle(fontSize: 9, color: kMute)),
                        Text('11p', style: TextStyle(fontSize: 9, color: kMute)),
                      ],
                    ),
                  ],
                ),
              ),
              Panel(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Cap('30-day consistency heatmap (YPT-style)'),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 10,
                        mainAxisSpacing: 6,
                        crossAxisSpacing: 6,
                      ),
                      itemCount: heatmap.length,
                      itemBuilder: (_, idx) {
                        final mins = heatmap[idx].value;
                        final ratio = prefs.dailyGoalMin <= 0 ? 0.0 : (mins / prefs.dailyGoalMin).clamp(0.0, 1.0);
                        final col = mins == 0
                            ? kBg
                            : ratio >= 1.0
                                ? kGreen
                                : kAmber.withOpacity(0.28 + 0.72 * ratio);
                        return Container(
                          decoration: BoxDecoration(
                            color: col,
                            borderRadius: BorderRadius.circular(5),
                            border: Border.all(color: kLine),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              Panel(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Cap('Last 7 days'),
                    SizedBox(
                      height: 140,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          for (final e in days7)
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Text(e.value == 0 ? '0' : fmtMins(e.value),
                                      style: const TextStyle(fontSize: 10, color: kMute),
                                      overflow: TextOverflow.ellipsis),
                                  const SizedBox(height: 3),
                                  TweenAnimationBuilder<double>(
                                    tween: Tween<double>(begin: 0, end: e.value / mx),
                                    duration: const Duration(milliseconds: 800),
                                    builder: (_, v, __) => Container(
                                      height: 4 + 84 * v,
                                      margin: const EdgeInsets.symmetric(horizontal: 5),
                                      decoration: BoxDecoration(
                                        color: e.value >= prefs.dailyGoalMin ? kGreen : kAmber,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(['M', 'T', 'W', 'T', 'F', 'S', 'S'][e.key.weekday - 1],
                                      style: const TextStyle(fontSize: 11, color: kMute)),
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
                    const Cap('Neglected subject radar (19 NEET PG subjects)'),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final e in neglected.take(6))
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: kBg,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: e.value >= 14 ? kRed.withOpacity(.6) : kLine),
                            ),
                            child: Text(
                              '${e.key} · ${e.value >= 999 ? 'Untouched' : '${e.value}d ago'}',
                              style: TextStyle(
                                fontSize: 12,
                                color: e.value >= 14 ? kRed : kInk,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              if (gts.isNotEmpty)
                Panel(
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Cap('Grand Test score trend (/200)'),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          for (final g in gts)
                            Column(
                              children: [
                                Text('${g.correct}',
                                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: kGreen)),
                                Text('${g.start.day}/${g.start.month}',
                                    style: const TextStyle(fontSize: 10, color: kMute)),
                              ],
                            )
                        ],
                      ),
                    ],
                  ),
                ),
              Panel(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Cap('Milestone badges'),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final b in badges)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: (b['ok'] as bool) ? kAmber.withOpacity(.18) : kBg,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: (b['ok'] as bool) ? kAmber : kLine),
                            ),
                            child: Text(
                              '${(b['ok'] as bool) ? '★ ' : '○ '}${b['name']}',
                              style: TextStyle(
                                fontSize: 12,
                                color: (b['ok'] as bool) ? kAmber : kMute,
                                fontWeight: (b['ok'] as bool) ? FontWeight.w700 : FontWeight.w400,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              Panel(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Cap('Subjects studied · last 30 days'),
                    if (subjects.isEmpty)
                      const Text('Finish your first session to see your subject breakdown.',
                          style: TextStyle(color: kMute))
                    else
                      for (final e in subjects)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(e.key, style: const TextStyle(fontWeight: FontWeight.w600)),
                                  Text(fmtMins(e.value ~/ 60),
                                      style: const TextStyle(color: kAmber, fontSize: 13)),
                                ],
                              ),
                              const SizedBox(height: 4),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(99),
                                child: LinearProgressIndicator(
                                  value: (e.value / topSubSec).clamp(0.05, 1.0),
                                  minHeight: 6,
                                  backgroundColor: kLine,
                                  color: kAmber,
                                ),
                              ),
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
                    const Cap('Day-by-day study log'),
                    if (dailyLog.isEmpty)
                      const Text('No sessions recorded yet.', style: TextStyle(color: kMute))
                    else
                      for (final row in dailyLog)
                        Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: kBg,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: kLine),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(_dayLabel(row['date'] as DateTime, today),
                                      style: const TextStyle(fontWeight: FontWeight.w700)),
                                  Text(
                                    '${fmtMins(row['mins'] as int)} · ${row['score']}%${(row['mcqs'] as int) > 0 ? ' · ${row['mcqs']} Qs' : ''}',
                                    style: const TextStyle(color: kGreen, fontWeight: FontWeight.w600, fontSize: 12.5),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text((row['subjects'] as List<String>).join(', '),
                                  style: const TextStyle(color: kAmber, fontSize: 12)),
                              if ((row['notes'] as List<String>).isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text((row['notes'] as List<String>).take(3).join(' · '),
                                    style: const TextStyle(color: kMute, fontSize: 11.5)),
                              ],
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
                    const Cap('Your attention pattern & honesty'),
                    if (ranked.length < 2)
                      const Text('Complete a few more camera sessions to map your sharpest and weakest hours.',
                          style: TextStyle(color: kMute))
                    else ...[
                      Text('Sharpest around ${hFmt(ranked.first.key)} (${(ranked.first.value * 100).round()}%)',
                          style: TextStyle(color: FocusState.study.color, fontSize: 15)),
                      const SizedBox(height: 4),
                      Text('Drifts around ${hFmt(ranked.last.key)} (${(ranked.last.value * 100).round()}%)',
                          style: TextStyle(color: FocusState.distraction.color, fontSize: 15)),
                    ],
                    if (prefs.guardianOverrides > 0) ...[
                      const SizedBox(height: 8),
                      Text('Guardian emergency unlocks used: ${prefs.guardianOverrides}',
                          style: const TextStyle(color: kMute, fontSize: 12)),
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

  Widget _kpi(String v, String l, Color c) => Column(
        children: [
          Text(v, style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: c)),
          const SizedBox(height: 2),
          Text(l.toUpperCase(), style: const TextStyle(fontSize: 9.5, color: kMute, letterSpacing: 1)),
        ],
      );
}
