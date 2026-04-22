import 'package:flutter/material.dart';

import '../repositories/player_repository.dart';
import 'match_screen.dart';
import 'player_management_screen.dart';
import 'session_setup_screen.dart';

/// 底部導覽：玩家管理 / 活動設定 / 比賽。
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.repository});

  final PlayerRepository repository;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 2; // 預設停在「比賽」頁

  @override
  Widget build(BuildContext context) {
    final screens = [
      PlayerManagementScreen(repository: widget.repository),
      SessionSetupScreen(repository: widget.repository),
      MatchScreen(repository: widget.repository),
    ];
    return Scaffold(
      body: IndexedStack(index: _index, children: screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.group_outlined),
            selectedIcon: Icon(Icons.group),
            label: '玩家',
          ),
          NavigationDestination(
            icon: Icon(Icons.event_outlined),
            selectedIcon: Icon(Icons.event),
            label: '活動設定',
          ),
          NavigationDestination(
            icon: Icon(Icons.sports_tennis_outlined),
            selectedIcon: Icon(Icons.sports_tennis),
            label: '比賽',
          ),
        ],
      ),
    );
  }
}
