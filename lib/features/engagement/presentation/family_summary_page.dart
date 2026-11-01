import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../profile/application/profile_providers.dart';
import '../../profile/domain/profile.dart';
import '../../profile/domain/user_role.dart';
import 'weekly_summary_card.dart';

/// "My Youth" — the parent's answer to "how did this week actually go?"
///
/// Deliberately the same shape as the youth pastor's dashboard: a card per
/// youth, tapping through to one youth in more detail. CLAUDE.md puts parents
/// first as disciple-makers, so a parent should not have less visibility of
/// their own household than their church does.
///
/// Lives inside the Discipleship shell, so no [Scaffold] of its own.
class FamilySummaryPage extends ConsumerWidget {
  const FamilySummaryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final members = ref.watch(familyMembersProvider);

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(familyMembersProvider),
      child: AsyncValueView(
        value: members,
        onRetry: () => ref.invalidate(familyMembersProvider),
        builder: (all) {
          // The permission role, not the household label: the summary RPC keys
          // off `profiles.role`, so anyone else would only ever return zeros.
          final youth =
              all.where((member) => member.role == UserRole.youth).toList()
                ..sort((a, b) => a.fullName
                    .toLowerCase()
                    .compareTo(b.fullName.toLowerCase()));

          if (youth.isEmpty) {
            return LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: const EmptyState(
                    icon: Icons.family_restroom_outlined,
                    title: 'No youth in your household yet',
                    message: 'Add a youth to your family and their weekly '
                        'summary will show up here.',
                  ),
                ),
              ),
            );
          }

          return ListView.builder(
            padding: feedInsets(context),
            itemCount: youth.length,
            itemBuilder: (context, index) => _YouthSection(youth: youth[index]),
          );
        },
      ),
    );
  }
}

class _YouthSection extends StatelessWidget {
  const _YouthSection({required this.youth});

  final Profile youth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.space5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => context.push(Routes.myYouthDetailFor(youth.id)),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppTheme.space2),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: theme.colorScheme.primaryContainer,
                    child: Text(
                      youth.initials,
                      style: TextStyle(
                        color: theme.colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppTheme.space3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          youth.fullName.isEmpty ? 'Youth' : youth.fullName,
                          style: theme.textTheme.titleMedium,
                        ),
                        Text(
                          'Last 7 days',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppTheme.space2),
          WeeklySummaryCard(profileId: youth.id),
        ],
      ),
    );
  }
}
