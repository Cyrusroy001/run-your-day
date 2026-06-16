import 'package:flutter/material.dart';
import '../theme/app_palette.dart';
import 'today_screen.dart';
import 'timeline_screen.dart';
import 'week_screen.dart';

/// ketchup v1.1 shell (ADR-022 §2): Today · Timeline · Week. Each tab
/// rebuilds on entry (no IndexedStack) so cross-tab writes — Pick, adjust,
/// re-plan — are always re-read; all state lives in the stores.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Scaffold(
      body: switch (_tab) {
        1 => const TimelineScreen(key: ValueKey('tab-timeline')),
        2 => const WeekScreen(key: ValueKey('tab-week')),
        _ => const TodayScreen(key: ValueKey('tab-today')),
      },
      bottomNavigationBar: NavigationBar(
        backgroundColor: c.raise,
        indicatorColor: c.vineDim,
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.wb_sunny_outlined),
              selectedIcon: Icon(Icons.wb_sunny), label: 'Today'),
          NavigationDestination(icon: Icon(Icons.spa_outlined),
              selectedIcon: Icon(Icons.spa), label: 'Timeline'),
          NavigationDestination(icon: Icon(Icons.yard_outlined),
              selectedIcon: Icon(Icons.yard), label: 'Week'),
        ],
      ),
    );
  }
}
