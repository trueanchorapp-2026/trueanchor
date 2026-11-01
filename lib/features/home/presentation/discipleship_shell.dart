import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/sub_tab_bar.dart';
import '../../profile/application/profile_providers.dart';
import '../../profile/domain/user_role.dart';

/// Sub-tab navigation within the Discipleship main tab. Renders a
/// [SubTabBar] at the top and the matched child route below.
class DiscipleshipShell extends ConsumerWidget {
  const DiscipleshipShell({
    required this.location,
    required this.child,
    super.key,
  });

  final String location;
  final Widget child;

  static List<SubTab> _tabsFor(UserRole? role) {
    return [
      const SubTab(route: '/discipleship/today', label: 'Today'),
      const SubTab(route: '/discipleship/history', label: 'History'),
      const SubTab(route: '/discipleship/journal', label: 'Journal'),
      if (role != null && role.canUseMessaging)
        const SubTab(route: '/discipleship/messages', label: 'Messages'),
      if (role != null && role.canViewRelationships)
        const SubTab(
            route: '/discipleship/relationships', label: 'Love in Action'),
      if (role != null && role.canViewYouthSummary)
        const SubTab(route: '/discipleship/my-youth', label: 'My Youth'),
      const SubTab(route: '/discipleship/milestones', label: 'Milestones'),
      if (role != null && role.isChurchStaff)
        const SubTab(route: '/discipleship/events', label: 'Events'),
    ];
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentProfileProvider).value;
    final tabs = _tabsFor(profile?.role);

    var selected = tabs.indexWhere((t) => location.startsWith(t.route));
    if (selected < 0) selected = 0;

    return Column(
      children: [
        SubTabBar(
          tabs: tabs,
          selectedIndex: selected,
          onSelected: (tab) => context.go(tab.route),
        ),
        Expanded(child: child),
      ],
    );
  }
}
