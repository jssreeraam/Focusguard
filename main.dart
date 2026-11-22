import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'state/providers.dart';
import 'ui/common.dart';
import 'ui/home.dart';
import 'ui/insights.dart';
import 'ui/rules.dart';
import 'ui/session.dart';

Future<void> main() async {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
    };
    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    sp = await SharedPreferences.getInstance();
    runApp(const ProviderScope(child: App()));
  }, (error, stack) {
    debugPrint('FocusGuard guarded error: $error');
  });
}

class App extends StatelessWidget {
  const App({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'FocusGuard',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        home: const Root(),
      );
}

class Root extends ConsumerStatefulWidget {
  const Root({super.key});
  @override
  ConsumerState<Root> createState() => _Root();
}

class _Root extends ConsumerState<Root> {
  int tab = 0;

  @override
  Widget build(BuildContext context) {
    final ph = ref.watch(sessionProvider.select((s) => s.phase));
    Widget body;
    switch (ph) {
      case Phase.running:
        body = const SessionScreen(key: ValueKey('s'));
      case Phase.locked:
        body = const LockScreen(key: ValueKey('l'));
      case Phase.summary:
        body = const SummaryScreen(key: ValueKey('m'));
      case Phase.idle:
        body = Scaffold(
          key: const ValueKey('i'),
          body: IndexedStack(
            index: tab,
            children: const [HomeScreen(), InsightsScreen(), RulesScreen()],
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: tab,
            onDestinationSelected: (i) => setState(() => tab = i),
            destinations: const [
              NavigationDestination(icon: Icon(Icons.shield_outlined), label: 'Study'),
              NavigationDestination(icon: Icon(Icons.insights_outlined), label: 'Insights'),
              NavigationDestination(icon: Icon(Icons.gavel_outlined), label: 'Rules'),
            ],
          ),
        );
    }
    return Scaffold(
      backgroundColor: kBg,
      body: PopScope(
        canPop: ph == Phase.idle,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 450),
          child: body,
        ),
      ),
    );
  }
}
