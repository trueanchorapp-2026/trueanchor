import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../profile/application/profile_providers.dart';
import '../../profile/domain/user_role.dart';
import '../application/community_providers.dart';
import 'join_community_page.dart';

class _SubTab {
  const _SubTab({required this.route, required this.label});

  final String route;
  final String label;
}

class CommunityShell extends ConsumerWidget {
  const CommunityShell({
    required this.location,
    required this.child,
    super.key,
  });

  final String location;
  final Widget child;

  static List<_SubTab> _tabsFor(UserRole? role) {
    return [
      const _SubTab(route: '/community/news', label: 'News'),
      const _SubTab(route: '/community/discussions', label: 'Discussions'),
      const _SubTab(route: '/community/events', label: 'Events'),
      const _SubTab(route: '/community/resources', label: 'Resources'),
      if (role != null && role.canManageRegions)
        const _SubTab(route: '/community/manage', label: 'Manage'),
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
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              for (var i = 0; i < tabs.length; i++)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(tabs[i].label),
                    selected: i == selected,
                    onSelected: (_) => context.go(tabs[i].route),
                    showCheckmark: false,
                  ),
                ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(child: child),
      ],
    );
  }
}
