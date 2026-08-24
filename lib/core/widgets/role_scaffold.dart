import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class NavDestination {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  const NavDestination({required this.icon, required this.selectedIcon, required this.label});
}

/// Shared bottom-nav scaffold used by every role shell (§17 Navigation).
/// Wraps a [StatefulNavigationShell] so switching tabs preserves each
/// branch's own navigation stack.
class RoleScaffold extends StatelessWidget {
  final StatefulNavigationShell navigationShell;
  final List<NavDestination> destinations;

  const RoleScaffold({super.key, required this.navigationShell, required this.destinations});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: navigationShell.currentIndex,
        onTap: (index) => navigationShell.goBranch(
          index,
          initialLocation: index == navigationShell.currentIndex,
        ),
        items: [
          for (final d in destinations)
            BottomNavigationBarItem(
              icon: Icon(d.icon),
              activeIcon: Icon(d.selectedIcon),
              label: d.label,
            ),
        ],
      ),
    );
  }
}
