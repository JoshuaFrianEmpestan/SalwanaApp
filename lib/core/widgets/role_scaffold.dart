import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../utils/breakpoints.dart';

class NavDestination {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  const NavDestination({required this.icon, required this.selectedIcon, required this.label});
}

/// Shared adaptive-nav scaffold used by every role shell (§17 Navigation).
/// Wraps a [StatefulNavigationShell] so switching tabs preserves each
/// branch's own navigation stack. Below the tablet breakpoint this renders
/// a bottom navigation bar (thumb reach on phones); at/above it, a side
/// [NavigationRail] (better use of horizontal space on tablets/desktop).
class RoleScaffold extends StatelessWidget {
  final StatefulNavigationShell navigationShell;
  final List<NavDestination> destinations;

  const RoleScaffold({super.key, required this.navigationShell, required this.destinations});

  void _onSelect(int index) => navigationShell.goBranch(
        index,
        initialLocation: index == navigationShell.currentIndex,
      );

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= Breakpoints.tablet;
        if (!isWide) {
          return Scaffold(
            body: navigationShell,
            bottomNavigationBar: BottomNavigationBar(
              currentIndex: navigationShell.currentIndex,
              onTap: _onSelect,
              items: [
                for (final d in destinations)
                  BottomNavigationBarItem(icon: Icon(d.icon), activeIcon: Icon(d.selectedIcon), label: d.label),
              ],
            ),
          );
        }

        return Scaffold(
          body: Row(
            children: [
              NavigationRail(
                selectedIndex: navigationShell.currentIndex,
                onDestinationSelected: _onSelect,
                labelType: NavigationRailLabelType.all,
                extended: constraints.maxWidth >= Breakpoints.desktop,
                destinations: [
                  for (final d in destinations)
                    NavigationRailDestination(icon: Icon(d.icon), selectedIcon: Icon(d.selectedIcon), label: Text(d.label)),
                ],
              ),
              const VerticalDivider(width: 1),
              Expanded(child: navigationShell),
            ],
          ),
        );
      },
    );
  }
}
