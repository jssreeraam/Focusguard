import 'package:flutter/material.dart';
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
                child: Text(
                  'Apps to lock on failure',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ),
              Expanded(
                child: apps.isEmpty
                    ? const Center(
                        child: Text('No launchable apps returned.', style: TextStyle(color: kMute)),
                      )
                    : ListView(
                        children: [
                          for (final a in apps)
                            CheckboxListTile(
                              value: sel.contains(a['pkg']),
                              title: Text(a['label']!),
                              subtitle: Text(a['pkg']!, style: const TextStyle(fontSize: 11, color: kMute)),
                              onChanged: (v) =>
                                  set(() => v! ? sel.add(a['pkg']!) : sel.remove(a['pkg']!)),
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
          const Text('YOUR RULES', style: TextStyle(color: kAmber, letterSpacing: 4, fontWeight: FontWeight.w700)),
          const SizedBox(height: 18),
          Panel(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Cap('Check interval'),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final v in [15, 30, 60, 120])
                      ChoiceChip(
                        label: Text('${v}s'),
                        selected: p.intervalSec == v,
                        onSelected: (_) => n.set({'iv': v}),
                      )
                  ],
                ),
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'Default is 60s. Shorter is stricter and uses more battery.',
                    style: TextStyle(color: kMute, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          Panel(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Cap('Consequences at zero tokens'),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Reset streak'),
                  value: p.streakReset,
                  onChanged: (v) => n.set({'streakReset': v}),
                ),
                Text('Forced cooldown: ${p.cooldownSec}s'),
                Slider(
                  value: p.cooldownSec.toDouble(),
                  min: 15,
                  max: 600,
                  divisions: 39,
                  onChanged: (v) => n.set({'cooldown': v.round()}),
                ),
                const SizedBox(height: 4),
                const Text('Lock selected apps for'),
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
              ],
            ),
          ),
          Panel(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Cap('Strict Anti-Tamper Vault'),
                _statusRow(
                  acc,
                  'Lock service (Accessibility) is active.',
                  'Enable "FocusGuard Lock" in Accessibility settings.',
                ),
                if (!acc) ...[
                  const SizedBox(height: 8),
                  BigButton('Open Accessibility settings', () => Blocker.openSettings(), ghost: true),
                ],
                const SizedBox(height: 12),
                _statusRow(
                  admin,
                  'Uninstall Guard (Device Admin) is active.',
                  'Enable Uninstall Guard so FocusGuard cannot be deleted.',
                ),
                if (!admin) ...[
                  const SizedBox(height: 8),
                  BigButton('Enable Uninstall Guard', () => Blocker.requestAdmin(), ghost: true),
                ],
                const SizedBox(height: 12),
                _statusRow(
                  batteryOk,
                  'Background protection active (battery unrestricted).',
                  'Allow unrestricted background so OEM killers cannot stop locks.',
                ),
                if (!batteryOk) ...[
                  const SizedBox(height: 8),
                  BigButton('Whitelist background battery', () => Blocker.requestBatteryIgnore(), ghost: true),
                ],
                const SizedBox(height: 10),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Block Settings / Clock / Force-Stop tampering'),
                  subtitle: const Text(
                    'Closes Settings screens for Accessibility, Date & Time, Device Admin, and Uninstall while locked.',
                    style: TextStyle(fontSize: 11.5, color: kMute),
                  ),
                  value: p.strictTamper,
                  onChanged: (v) => n.set({'strictTamper': v}),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Nuclear: Block ALL of Settings while locked'),
                  subtitle: const Text(
                    'Maximum strictness. Settings unlocks automatically when your lock timer ends.',
                    style: TextStyle(fontSize: 11.5, color: kMute),
                  ),
                  value: p.blockAllSettings,
                  onChanged: (v) => n.set({'blockAllSettings': v}),
                ),
              ],
            ),
          ),
          Panel(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Cap('App lockdown targets'),
                Text('${p.pkgs.length} apps selected'),
                const SizedBox(height: 10),
                BigButton('Choose apps', _pick, ghost: true),
                const SizedBox(height: 10),
                BigButton(
                  'Test lock for 2 minutes',
                  () async {
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
                        const SnackBar(content: Text('Selected apps locked for 2 minutes (monotonic timer).')),
                      );
                    }
                  },
                  ghost: true,
                ),
              ],
            ),
          ),
          Panel(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Cap('Baseline & Data'),
                Text(
                  p.baseline == 0
                      ? 'Not calibrated yet.'
                      : 'Baseline ${p.baseline} distractions/day -> pool of ${p.pool} tokens.',
                ),
                const SizedBox(height: 10),
                BigButton('Recalibrate', () => n.recalibrate(), ghost: true),
                const SizedBox(height: 10),
                BigButton(
                  'Delete all session data',
                  () async {
                    await Repo.wipe();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('All local data deleted.')),
                      );
                    }
                  },
                  ghost: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
