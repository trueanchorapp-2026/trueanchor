import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../messaging/application/messaging_providers.dart';
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

const _today = _Destination(
  route: Routes.today,
  label: 'Today',
  icon: Icons.wb_sunny_outlined,
  selectedIcon: Icons.wb_sunny,
);
const _journal = _Destination(
  route: Routes.journal,
  label: 'Journal',
  icon: Icons.menu_book_outlined,
  selectedIcon: Icons.menu_book,
);
const _dashboard = _Destination(
  route: Routes.dashboard,
  label: 'Dashboard',
  icon: Icons.insights_outlined,
  selectedIcon: Icons.insights,
);
const _messages = _Destination(
  route: Routes.messages,
  label: 'Messages',
  icon: Icons.forum_outlined,
  selectedIcon: Icons.forum,
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
    // Church staff have no household and no journal of their own, but they
    // read the same daily devotional everyone else does. A youth pastor gets
    // Messages; a church admin does not — mirrors `open_thread()`, which
    // refuses their role outright.
    if (role != null && role.isChurchStaff) {
      return [
        // The dashboard comes first for a youth pastor because it is their
        // home screen: the youth who need them, before anything else.
        if (role.canViewEngagementDashboard) _dashboard,
        _today,
        _church,
        if (role.canUseMessaging) _messages,
        _events,
        _milestones,
        _profile,
      ];
    }
    return const [
      _today,
      _journal,
      _messages,
      _events,
      _milestones,
      _family,
      _profile,
    ];
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentProfileProvider).value;
    final destinations = _destinationsFor(profile?.role);
    final unread = ref.watch(unreadThreadCountProvider);

    /// The Messages tab is the only one that carries a count, so the badge is
    /// applied here rather than added to every [_Destination].
    Widget iconFor(_Destination destination, {required bool selected}) {
      final icon =
          Icon(selected ? destination.selectedIcon : destination.icon);
      if (destination.route != Routes.messages || unread == 0) return icon;
      return Badge.count(count: unread, child: icon);
    }

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
