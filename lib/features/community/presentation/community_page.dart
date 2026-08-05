import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/app_widgets.dart';
import '../application/community_providers.dart';
import 'join_community_page.dart';

class CommunityPage extends ConsumerWidget {
  const CommunityPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membership = ref.watch(myMembershipProvider);

    return AsyncValueView(
      value: membership,
      onRetry: () => ref.invalidate(myMembershipProvider),
      builder: (m) {
        if (m == null) return const JoinCommunityPage();
        return const SizedBox.shrink();
      },
    );
  }
}
