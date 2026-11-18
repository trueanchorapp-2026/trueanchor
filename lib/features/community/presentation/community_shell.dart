import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/sub_tab_bar.dart';
import '../../profile/application/profile_providers.dart';
import '../../profile/domain/user_role.dart';
import '../application/community_providers.dart';
import 'join_community_page.dart';

class CommunityShell extends ConsumerWidget {
  const CommunityShell({
    required this.location,
    required this.child,
    super.key,
  });

  final String location;
  final Widget child;

  /// Manage leads for the roles that have it — it is the whole reason a
  /// regional admin opens this tab, so it should never start off-screen.
  static List<SubTab> _tabsFor(UserRole? role) {
    return [
      if (role != null && role.canManageRegions)
        const SubTab(route: '/community/manage', label: 'Manage'),
      const SubTab(route: '/community/news', label: 'News'),
      const SubTab(route: '/community/discussions', label: 'Discussions'),
      const SubTab(route: '/community/events', label: 'Events'),
      const SubTab(route: '/community/resources', label: 'Parent Hub'),
    ];
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentProfileProvider).value;
    final membership = ref.watch(myMembershipProvider);

    // Regional admins skip the membership gate — they manage, not join.
    final needsMembership =
        profile != null && !profile.role.canManageRegions;

    if (needsMembership) {
      final hasMembership = membership.value != null;
      if (membership.isLoading) {
        return const Center(child: CircularProgressIndicator());
      }
      if (!hasMembership) return const JoinCommunityPage();
    }

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
