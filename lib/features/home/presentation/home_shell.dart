import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../messaging/application/messaging_providers.dart';
import '../../profile/application/profile_providers.dart';
import '../../profile/domain/user_role.dart';

class _Destination {
  const _Destination({
    required this.route,
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });

  final String route;
  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

const _home = _Destination(
  route: '/home',
  label: 'Home',
  icon: Icons.home_outlined,
  selectedIcon: Icons.home,
);
const _discipleship = _Destination(
  route: '/discipleship',
  label: 'Discipleship',
  icon: Icons.menu_book_outlined,
  selectedIcon: Icons.menu_book,
);
const _community = _Destination(
  route: '/community',
  label: 'Community',
  icon: Icons.diversity_3_outlined,
  selectedIcon: Icons.diversity_3,
);
const _profile = _Destination(
  route: '/profile',
  label: 'Profile',
  icon: Icons.person_outline,
  selectedIcon: Icons.person,
);

// Staff-only destinations kept for church admin / app admin who don't use
// the 4-tab layout yet.
const _dashboard = _Destination(
  route: '/dashboard',
  label: 'Dashboard',
  icon: Icons.insights_outlined,
  selectedIcon: Icons.insights,
);
const _church = _Destination(
  route: '/church',
  label: 'Church',
  icon: Icons.church_outlined,
  selectedIcon: Icons.church,
);
const _events = _Destination(
  route: '/discipleship/events',
  label: 'Events',
  icon: Icons.event_outlined,
  selectedIcon: Icons.event,
);

/// Navigation frame for signed-in users. Parents and youth see the 4-tab
/// layout (Home, Discipleship, Community, Profile). Church staff keep their
/// existing navigation for now.
class HomeShell extends ConsumerWidget {
  const HomeShell({required this.child, required this.location, super.key});

  final Widget child;
  final String location;

  List<_Destination> _destinationsFor(UserRole? role) {
    if (role == UserRole.regionalAdmin) {
      return [_home, _community, _profile];
    }
    if (role != null && role.isChurchStaff) {
      return [
        if (role.canViewEngagementDashboard) _dashboard,
        _discipleship,
        _church,
        _events,
        _profile,
      ];
    }
    return [
      _home,
      _discipleship,
      if (role != UserRole.youth) _community,
      _profile,
    ];
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentProfileProvider).value;
    final destinations = _destinationsFor(profile?.role);
    final unread = ref.watch(unreadThreadCountProvider);

    Widget iconFor(_Destination destination, {required bool selected}) {
      final icon =
          Icon(selected ? destination.selectedIcon : destination.icon);
      if (destination.route != '/discipleship' || unread == 0) return icon;
      // Show unread badge on Discipleship since Messages lives inside it.
      if (profile?.role.canUseMessaging != true) return icon;
      return Badge.count(count: unread, child: icon);
    }

    var index =
        destinations.indexWhere((d) => location.startsWith(d.route));
    if (index < 0) index = 0;

    void onSelected(int selected) {
      final route = destinations[selected].route;
      // For Discipleship, go to the default sub-tab.
      final target =
          route == '/discipleship' ? '/discipleship/today' : route;
      if (target != location) context.go(target);
    }

    final title = destinations[index].label;

    final isWide = MediaQuery.sizeOf(context).width >= 760;

    if (isWide) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: index,
              onDestinationSelected: onSelected,
              labelType: NavigationRailLabelType.all,
              destinations: [
                for (final destination in destinations)
                  NavigationRailDestination(
                    icon: iconFor(destination, selected: false),
                    selectedIcon: iconFor(destination, selected: true),
                    label: Text(destination.label),
                  ),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(
              child: Scaffold(
                appBar: AppBar(title: Text(title)),
                body: child,
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: onSelected,
        destinations: [
          for (final destination in destinations)
            NavigationDestination(
              icon: iconFor(destination, selected: false),
              selectedIcon: iconFor(destination, selected: true),
              label: destination.label,
            ),
        ],
      ),
    );
  }
}
