import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../profile/application/profile_providers.dart';
import '../../profile/domain/user_role.dart';

/// A navigation destination plus the role rule for who sees it.
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

const _journal = _Destination(
  route: Routes.journal,
  label: 'Journal',
  icon: Icons.menu_book_outlined,
  selectedIcon: Icons.menu_book,
);
const _events = _Destination(
  route: Routes.events,
  label: 'Events',
  icon: Icons.event_outlined,
  selectedIcon: Icons.event,
);
const _milestones = _Destination(
  route: Routes.milestones,
  label: 'Milestones',
  icon: Icons.emoji_events_outlined,
  selectedIcon: Icons.emoji_events,
);
const _family = _Destination(
  route: Routes.family,
  label: 'Family',
  icon: Icons.home_outlined,
  selectedIcon: Icons.home,
);
const _church = _Destination(
  route: Routes.church,
  label: 'Church',
  icon: Icons.church_outlined,
  selectedIcon: Icons.church,
);
const _profile = _Destination(
  route: Routes.profile,
  label: 'Profile',
  icon: Icons.person_outline,
  selectedIcon: Icons.person,
);

/// Navigation frame for signed-in users. Which destinations appear is decided
/// by role, per CLAUDE.md's role-based access requirement.
class HomeShell extends ConsumerWidget {
  const HomeShell({required this.child, required this.location, super.key});

  final Widget child;
  final String location;

  List<_Destination> _destinationsFor(UserRole? role) {
    // Church staff have no household and no journal of their own.
    if (role != null && role.isChurchStaff) {
      return const [_church, _events, _milestones, _profile];
    }
    return const [_journal, _events, _milestones, _family, _profile];
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentProfileProvider).value;
    final destinations = _destinationsFor(profile?.role);

    var index = destinations.indexWhere((d) => location.startsWith(d.route));
    if (index < 0) index = 0;

    void onSelected(int selected) {
      final route = destinations[selected].route;
      if (route != location) context.go(route);
    }

    final title = destinations[index].label;

    // Rail on wide viewports, bottom bar on narrow ones.
    final isWide = MediaQuery.sizeOf(context).width >= 760;

    if (isWide) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: index,
              onDestinationSelected: onSelected,
              labelType: NavigationRailLabelType.all,
              leading: const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Icon(Icons.anchor),
              ),
              destinations: [
                for (final destination in destinations)
                  NavigationRailDestination(
                    icon: Icon(destination.icon),
                    selectedIcon: Icon(destination.selectedIcon),
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
              icon: Icon(destination.icon),
              selectedIcon: Icon(destination.selectedIcon),
              label: destination.label,
            ),
        ],
      ),
    );
  }
}
