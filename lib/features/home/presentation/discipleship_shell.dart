import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../profile/application/profile_providers.dart';
import '../../profile/domain/user_role.dart';

class _SubTab {
  const _SubTab({required this.route, required this.label});

  final String route;
  final String label;
}

/// Sub-tab navigation within the Discipleship main tab. Renders a row of
/// filter chips at the top and the matched child route below.
class DiscipleshipShell extends ConsumerWidget {
  const DiscipleshipShell({
    required this.location,
    required this.child,
    super.key,
  });

  final String location;
  final Widget child;

  static List<_SubTab> _tabsFor(UserRole? role) {
    return [
      const _SubTab(route: '/discipleship/today', label: 'Today'),
      const _SubTab(route: '/discipleship/history', label: 'History'),
      if (role != null && role.canUseMessaging)
        const _SubTab(route: '/discipleship/messages', label: 'Messages'),
      const _SubTab(route: '/discipleship/milestones', label: 'Milestones'),
      const _SubTab(route: '/discipleship/events', label: 'Events'),
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
