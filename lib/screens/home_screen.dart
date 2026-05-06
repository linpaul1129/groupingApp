import 'package:flutter/material.dart';

import '../repositories/player_repository.dart';
import '../utils/breakpoints.dart';
import 'match_screen.dart';
import 'player_management_screen.dart';
import 'session_setup_screen.dart';

/// 自適應導覽：手機底部 NavigationBar、平板側邊 NavigationRail、寬螢幕固定 NavigationDrawer。
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.repository});

  final PlayerRepository repository;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 2; // 預設停在「比賽」頁

  static const _items = <_NavItem>[
    _NavItem(
      label: '玩家',
      icon: Icons.group_outlined,
      selectedIcon: Icons.group,
    ),
    _NavItem(
      label: '活動設定',
      icon: Icons.event_outlined,
      selectedIcon: Icons.event,
    ),
    _NavItem(
      label: '比賽',
      icon: Icons.sports_tennis_outlined,
      selectedIcon: Icons.sports_tennis,
    ),
  ];

  void _select(int i) => setState(() => _index = i);

  @override
  Widget build(BuildContext context) {
    final screens = [
      PlayerManagementScreen(repository: widget.repository),
      SessionSetupScreen(repository: widget.repository),
      MatchScreen(repository: widget.repository),
    ];
    final stack = IndexedStack(index: _index, children: screens);

    if (AppBreakpoints.isPhone(context)) {
      return Scaffold(
        body: stack,
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: _select,
          destinations: [
            for (final it in _items)
              NavigationDestination(
                icon: Icon(it.icon),
                selectedIcon: Icon(it.selectedIcon),
                label: it.label,
              ),
          ],
        ),
      );
    }

    if (AppBreakpoints.isTablet(context)) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: _index,
              onDestinationSelected: _select,
              labelType: NavigationRailLabelType.all,
              destinations: [
                for (final it in _items)
                  NavigationRailDestination(
                    icon: Icon(it.icon),
                    selectedIcon: Icon(it.selectedIcon),
                    label: Text(it.label),
                  ),
              ],
            ),
            const VerticalDivider(width: 1, thickness: 1),
            Expanded(child: stack),
          ],
        ),
      );
    }

    // wide：固定展開的 NavigationDrawer（限寬 200px）。
    return Scaffold(
      body: Row(
        children: [
          SizedBox(
            width: 200,
            child: NavigationDrawer(
              selectedIndex: _index,
              onDestinationSelected: _select,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Text(
                    '羽球分組',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
                for (final it in _items)
                  NavigationDrawerDestination(
                    icon: Icon(it.icon),
                    selectedIcon: Icon(it.selectedIcon),
                    label: Text(it.label),
                  ),
              ],
            ),
          ),
          const VerticalDivider(width: 1, thickness: 1),
          Expanded(child: stack),
        ],
      ),
    );
  }
}

class _NavItem {
  const _NavItem({
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}
