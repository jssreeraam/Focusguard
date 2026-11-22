import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/repo.dart';
import '../domain/models.dart';
import '../state/providers.dart';
import 'common.dart';

class ReviseScreen extends ConsumerStatefulWidget {
  const ReviseScreen({super.key});
  @override
  ConsumerState<ReviseScreen> createState() => _ReviseScreenState();
}

class _ReviseScreenState extends ConsumerState<ReviseScreen> {
  Future<void> _addManual() async {
    String sub = ref.read(prefsProvider).lastSubject;
    final topicCtl = TextEditingController();
    bool hy = false;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          title: const Text('Add Revision Pearl'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: kNeetSubjects.contains(sub) ? sub : 'General',
                items: [
                  for (final s in kNeetSubjects)
                    DropdownMenuItem(value: s, child: Text(s))
                ],
                onChanged: (v) => set(() => sub = v ?? 'General'),
                decoration: const InputDecoration(labelText: 'Subject'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: topicCtl,
                decoration: const InputDecoration(
                  labelText: 'Topic / Clinical Pearl',
                  hintText: 'e.g., Drugs of choice in Arrhythmias',
                ),
              ),
              const SizedBox(height: 8),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Pin as High-Yield ★'),
                value: hy,
                onChanged: (v) => set(() => hy = v ?? false),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Add')),
          ],
        ),
      ),
    );
    if (ok == true && topicCtl.text.trim().isNotEmpty) {
      await Repo.addRevision(subject: sub, topic: topicCtl.text.trim(), highYield: hy);
      ref.read(dbVersionProvider.notifier).state++;
    }
  }

  String _dueText(DateTime due) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(due.year, due.month, due.day);
    final diff = d.difference(today).inDays;
    if (diff < 0) return '${-diff}d overdue';
    if (diff == 0) return 'Due today';
    if (diff == 1) return 'Tomorrow';
    return 'In ${diff}d';
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(dbVersionProvider);
    return SafeArea(
      child: FutureBuilder<List<RevisionItem>>(
        future: Repo.allRevisions(),
        builder: (_, snap) {
          final all = snap.data ?? const <RevisionItem>[];
          final due = all.where((r) => r.isDueToday).toList();
          final upcoming = all.where((r) => !r.isDueToday && !r.isMastered).toList();
          final mastered = all.where((r) => r.isMastered).toList();

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'SPACED REVISION',
                    style: TextStyle(color: kInk, letterSpacing: 2.5, fontWeight: FontWeight.w800),
                  ),
                  TextButton.icon(
                    onPressed: _addManual,
                    icon: const Icon(Icons.add_circle_outline, size: 18),
                    label: const Text('Add Pearl'),
                  ),
                ],
              ),
              const Text(
                'Intervals: +1d → +3d → +7d → +21d → +45d → Mastered',
                style: TextStyle(color: kMute, fontSize: 12),
              ),
              const SizedBox(height: 16),
              if (due.isEmpty && all.isNotEmpty)
                Panel(
                  const Row(
                    children: [
                      Icon(Icons.verified, color: kGreen, size: 30),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'ALL REVISIONS CLEARED',
                              style: TextStyle(color: kGreen, fontWeight: FontWeight.w700, letterSpacing: 1.5, fontSize: 12),
                            ),
                            Text(
                              'Zero backlog today. Your Citadel XP is climbing.',
                              style: TextStyle(color: kInk, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  borderColor: kGreen.withOpacity(.55),
                ),
              Panel(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Cap('Due today · ${due.length}'),
                    if (due.isEmpty)
                      Text(
                        all.isEmpty
                            ? 'Log a topic after any study block (or tap Add Pearl) to start your spaced repetition engine.'
                            : 'Nothing due right now. Enjoy the clean slate!',
                        style: const TextStyle(color: kMute, fontSize: 13),
                      )
                    else
                      for (final item in due)
                        Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: kBg,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: item.highYield ? kAmber.withOpacity(.7) : kLine),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    '${item.highYield ? '★ ' : ''}${item.subject.toUpperCase()}',
                                    style: TextStyle(
                                      color: item.highYield ? kAmber : kBlue,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    '${item.stageLabel} · ${_dueText(item.due)}',
                                    style: const TextStyle(color: kMute, fontSize: 11),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(item.topic, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: () async {
                                        await Repo.resetRevision(item);
                                        ref.read(dbVersionProvider.notifier).state++;
                                      },
                                      child: const Text('Forgot (+1d)', style: TextStyle(color: kRed)),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: FilledButton(
                                      onPressed: () async {
                                        HapticFeedback.mediumImpact();
                                        await Repo.markRevisionDone(item);
                                        ref.read(prefsProvider.notifier).addRevisionXp(30);
                                        ref.read(dbVersionProvider.notifier).state++;
                                      },
                                      child: const Text('Ticked Done (+30 XP)'),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                  ],
                ),
              ),
              if (upcoming.isNotEmpty)
                Panel(
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Cap('Upcoming · ${upcoming.length}'),
                      for (final item in upcoming.take(15))
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          title: Text('${item.highYield ? '★ ' : ''}${item.topic}'),
                          subtitle: Text('${item.subject} · ${item.stageLabel}', style: const TextStyle(color: kMute)),
                          trailing: Text(_dueText(item.due), style: const TextStyle(color: kAmber, fontSize: 12)),
                          onLongPress: () async {
                            if (item.id != null) {
                              await Repo.deleteRevision(item.id!);
                              ref.read(dbVersionProvider.notifier).state++;
                            }
                          },
                        ),
                    ],
                  ),
                ),
              if (mastered.isNotEmpty)
                Panel(
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Cap('Mastered vault · ${mastered.length}'),
                      for (final item in mastered.take(10))
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          leading: const Icon(Icons.workspace_premium, color: kGreen, size: 18),
                          title: Text(item.topic),
                          subtitle: Text(item.subject, style: const TextStyle(color: kMute)),
                        ),
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
