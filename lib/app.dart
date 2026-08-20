import 'package:flutter/material.dart';

import '../features/daily/view/daily_snapshot_screen.dart';
import '../features/dashboard/view/dashboard_screen.dart';
import '../features/history/view/history_screen.dart';
import '../features/register/view/register_holding_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  static const _pages = [
    DashboardScreen(),
    RegisterHoldingScreen(),
    HistoryScreen(),
    DailySnapshotScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (index) {
          setState(() {
            _index = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.pie_chart_outline),
            selectedIcon: Icon(Icons.pie_chart),
            label: 'ダッシュボード',
          ),
          NavigationDestination(
            icon: Icon(Icons.add_box_outlined),
            selectedIcon: Icon(Icons.add_box),
            label: '登録',
          ),
          NavigationDestination(
            icon: Icon(Icons.history),
            selectedIcon: Icon(Icons.history),
            label: '履歴',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month),
            label: '日次記録',
          ),
        ],
      ),
    );
  }
}
