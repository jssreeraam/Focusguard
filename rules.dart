import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/repo.dart';
import '../services/blocker.dart';
import '../state/providers.dart';
import 'common.dart';

class RulesScreen extends ConsumerStatefulWidget {
  const RulesScreen({super.key});
  @override
  ConsumerState<RulesScreen> createState() => _R();
}

class _R extends ConsumerState<RulesScreen> with WidgetsBindingObserver {
  bool acc = false;
  bool admin = false;
  bool batteryOk = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _chk();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed) _chk();
  }

  Future<void> _chk() async {
    final vAcc = await Blocker.enabled();
    final vAdm = await Blocker.isAdminEnabled();
    final vBat = await Blocker.isBatteryIgnored();
    if (mounted) {
      setState(() {
        acc = vAcc;
        admin = vAdm;
        batteryOk = vBat;
      });
    }
  }

  Future<void> _pickExamDate(String key, DateTime? existing) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: (existing != null && !existing.isBefore(now))
          ? existing
          : now.add(const Duration(days: 150)),
      firstDate: now,
      lastDate: DateTime(now.year + 3),
    );
    if (picked != null) {
      ref.read(prefsProvider.notifier).set({key: picked.toIso8601String()});
    }
  }

  Future<void> _pickReminderTime() async {
    final p = ref.read(prefsProvider);
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: p.reminderHour, minute: p.reminderMin),
    );
    if (picked != null) {
      ref.read(prefsProvider.notifier).set({
        'reminderHour': picked.hour,
        'reminderMin': picked.minute,
        'remindersOn': true,
      });
      await Blocker.requestNotificationPermission();
      await Blocker.scheduleDailyReminder(
        on: true,
        hour: picked.hour,
        minute: picked.minute,
        body: "Open your Revise tab and clear today's spaced repetition topics!",
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Daily revision reminder set for ${picked.format(context)}.')),
        );
      }
    }
  }

  Future<void> _setGuardianPin() async {
    final rem = await Blocker.lockRemainingMs();
    if (rem > 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cannot set or change Guardian PIN while a lock is active.')),
        );
      }
      return;
    }
    final ctl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Set Mom/Dad Guardian PIN'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Have Mom or Dad enter a secret 6-digit PIN (stored as a one-way SHA-256 hash). Only they can clear an active lock in an emergency.',
              style: TextStyle(color: kMute, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctl,
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: const InputDecoration(
                labelText: '6-digit PIN',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save PIN')),
        ],
      ),
    );
    if (ok == true && ctl.text.trim().length == 6) {
      ref.read(prefsProvider.notifier).setGuardianPin(ctl.text.trim());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Guardian Emergency PIN saved securely.')),
        );
      }
    } else if (ok == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter exactly 6 digits.')),
      );
    }
  }

  Future<void> _backupDialog() async {
    final json = await Repo.exportJson();
    await Clipboard.setData(ClipboardData(text: json));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Full backup JSON copied to clipboard! Paste into Notes/Drive to keep safe.')),
      );
    }
  }

  Future<void> _restoreDialog() async {
    final ctl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restore Backup JSON'),
        content: TextField(
          controller: ctl,
          maxLines: 5,
          decoration: const InputDecoration(
            hintText: 'Paste your FocusGuard backup JSON here',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Restore')),
        ],
      ),
    );
    if (ok == true && ctl.text.trim().isNotEmpty) {
      try {
        final count = await Repo.importJson(ctl.text.trim());
        ref.read(dbVersionProvider.notifier).state++;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Restored $count records.')),
          );
        }
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Invalid backup JSON.')),
          );
        }
      }
    }
  }

  Future<void> _pick() async {
    final apps = await Blocker.apps();
    if (!mounted) return;
    final sel = {...ref.read(prefsProvider).pkgs};
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: kCard,
      builder: (_) => StatefulBuilder(
        builder: (ctx, set) => SizedBox(
          height: MediaQuery.of(ctx).size.height * .75,
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Apps to lock on failure / Phone-Study',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
              ),
              Expanded(
                child: apps.isEmpty
                    ? const Center(child: Text('No launchable apps returned.', style: TextStyle(color: kMute)))
                    : ListView(
                        children: [
                          for (final a in apps)
                            CheckboxListTile(
                              value: sel.contains(a['pkg']),
                              title: Text(a['label']!),
                              subtitle: Text(a['pkg']!, style: const TextStyle(fontSize: 11, color: kMute)),
                              onChanged: (v) => set(() => v! ? sel.add(a['pkg']!) : sel.remove(a['pkg']!)),
                            )
                        ],
                      ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: BigButton('Save', () {
                  ref.read(prefsProvider.notifier).set({'pkgs': sel.toList()});
                  Navigator.pop(ctx);
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusRow(bool ok, String okText, String warnText) => Row(
        children: [
          Icon(ok ? Icons.check_circle : Icons.warning_amber, color: ok ? kGreen : kAmber, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(ok ? okText : warnText, style: const TextStyle(fontSize: 13))),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final p = ref.watch(prefsProvider);
    final n = ref.read(prefsProvider.notifier);

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text('YOUR RULES', style: TextStyle(color: kInk, letterSpacing: 3, fontWeight: FontWeight.w800)),
          const SizedBox(height: 18),
          Panel(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Cap('NEET PG / INI-CET & Internship goals'),
                const Text('Duty Day goal', style: TextStyle(fontSize: 13)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final m in [60, 90, 120, 180, 240])
                      ChoiceChip(
                        label: Text(fmtMins(m)),
                        selected: p.dutyGoalMin == m,
                        onSelected: (_) => n.set({'dutyGoalMin': m}),
                      )
                  ],
                ),
                const SizedBox(height: 10),
                const Text('Off Day goal', style: TextStyle(fontSize: 13)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final m in [240, 360, 420, 480, 600])
                      ChoiceChip(
                        label: Text(fmtMins(m)),
                        selected: p.offGoalMin == m,
                        onSelected: (_) => n.set({'offGoalMin': m}),
                      )
                  ],
                ),
                const SizedBox(height: 12),
                BigButton(
                  p.inicetDate == null
                      ? 'Set INI-CET exam date'
                      : 'INI-CET: ${p.inicetDate!.day}/${p.inicetDate!.month}/${p.inicetDate!.year}',
                  () => _pickExamDate('inicetDate', p.inicetDate),
                  ghost: true,
                ),
                const SizedBox(height: 8),
                BigButton(
                  p.neetDate == null
                      ? 'Set NEET PG exam date'
                      : 'NEET PG: ${p.neetDate!.day}/${p.neetDate!.month}/${p.neetDate!.year}',
                  () => _pickExamDate('neetDate', p.neetDate),
                  ghost: true,
                ),
              ],
            ),
          ),
          Panel(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Cap('Daily revision notifications'),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Daily Spaced Repetition reminder'),
                  subtitle: Text(
                    'Scheduled for ${p.reminderHour.toString().padLeft(2, '0')}:${p.reminderMin.toString().padLeft(2, '0')}',
                    style: const TextStyle(color: kMute, fontSize: 12),
                  ),
                  value: p.remindersOn,
                  onChanged: (v) async {
                    n.set({'remindersOn': v});
                    await Blocker.requestNotificationPermission();
                    await Blocker.scheduleDailyReminder(
                      on: v,
                      hour: p.reminderHour,
                      minute: p.reminderMin,
                      body: "Open Revise tab and clear today's spaced repetition topics!",
                    );
                  },
                ),
                BigButton('Change reminder time', _pickReminderTime, ghost: true),
              ],
            ),
          ),
          Panel(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Cap('Rear camera random checks/min'),
                const Text('Randomized checks per minute', style: TextStyle(fontSize: 12.5, color: kMute)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    for (final c in [1, 2, 3, 4, 6])
                      ChoiceChip(
                        label: Text('$c/min'),
                        selected: p.checksPerMin == c,
                        onSelected: (_) => n.set({'checksPerMin': c}),
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
                const Cap('Guardian emergency unlock (Mom/Dad PIN)'),
                _statusRow(
                  p.hasGuardianPin,
                  'Guardian 6-digit PIN is set (SHA-256 protected).',
                  'Ask Mom or Dad to set a secret 6-digit emergency unlock PIN.',
                ),
                const SizedBox(height: 10),
                BigButton(p.hasGuardianPin ? 'Change Guardian PIN' : 'Set Guardian PIN', _setGuardianPin, ghost: true),
              ],
            ),
          ),
          Panel(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Cap('Strict Anti-Tamper Vault'),
                _statusRow(acc, 'Lock service (Accessibility) active.', 'Enable "FocusGuard Lock" in Accessibility settings.'),
                if (!acc) ...[
                  const SizedBox(height: 8),
                  BigButton('Open Accessibility settings', () => Blocker.openSettings(), ghost: true),
                ],
                const SizedBox(height: 12),
                _statusRow(admin, 'Uninstall Guard (Device Admin) active.', 'Enable Uninstall Guard so FocusGuard cannot be deleted.'),
                if (!admin) ...[
                  const SizedBox(height: 8),
                  BigButton('Enable Uninstall Guard', () => Blocker.requestAdmin(), ghost: true),
                ],
                const SizedBox(height: 12),
                _statusRow(batteryOk, 'Background protection active.', 'Allow unrestricted background so OEM killers cannot stop locks.'),
                if (!batteryOk) ...[
                  const SizedBox(height: 8),
                  BigButton('Whitelist background battery', () => Blocker.requestBatteryIgnore(), ghost: true),
                ],
                const SizedBox(height: 10),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Block Settings / Clock / Force-Stop tampering'),
                  value: p.strictTamper,
                  onChanged: (v) => n.set({'strictTamper': v}),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Nuclear: Block ALL of Settings while locked'),
                  value: p.blockAllSettings,
                  onChanged: (v) => n.set({'blockAllSettings': v}),
                ),
                const SizedBox(height: 6),
                const Text('Penalty lock duration at zero tokens'),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final h in [0, 1, 6, 24])
                      ChoiceChip(
                        label: Text(h == 0 ? 'Off' : '${h}h'),
                        selected: p.lockHours == h,
                        onSelected: (_) => n.set({'lockHours': h}),
                      )
                  ],
                ),
                const SizedBox(height: 10),
                Text('${p.pkgs.length} distraction apps selected'),
                const SizedBox(height: 8),
                BigButton('Choose apps to lock', _pick, ghost: true),
                const SizedBox(height: 8),
                BigButton('Test lock for 2 minutes', () async {
                  if (p.pkgs.isEmpty) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Pick at least 1 app first.')),
                      );
                    }
                    return;
                  }
                  await Blocker.requestNotificationPermission();
                  await Blocker.setLockDuration(p.pkgs, const Duration(minutes: 2));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Selected apps locked for 2 minutes.')),
                    );
                  }
                }, ghost: true),
              ],
            ),
          ),
          Panel(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Cap('Backup, Baseline & Data'),
                Text(p.baseline == 0
                    ? 'Not calibrated yet.'
                    : 'Baseline ${p.baseline} distractions/day → pool of ${p.pool} tokens.'),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: BigButton('Copy Backup', _backupDialog, ghost: true)),
                    const SizedBox(width: 10),
                    Expanded(child: BigButton('Restore', _restoreDialog, ghost: true)),
                  ],
                ),
                const SizedBox(height: 8),
                BigButton('Recalibrate baseline', () => n.recalibrate(), ghost: true),
                const SizedBox(height: 8),
                BigButton('Delete all local data', () async {
                  await Repo.wipe();
                  ref.read(dbVersionProvider.notifier).state++;
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('All local data deleted.')),
                    );
                  }
                }, ghost: true),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
