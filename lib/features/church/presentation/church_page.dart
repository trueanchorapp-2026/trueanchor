import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../profile/application/profile_providers.dart';
import '../../profile/domain/profile.dart';
import '../../profile/domain/user_role.dart';
import '../application/church_providers.dart';
import '../domain/church.dart';
import '../domain/church_overview.dart';
import 'issue_invite_sheet.dart';

/// What a youth pastor or church admin sees instead of a household: the
/// congregation's families, and the codes that let people join.
class ChurchPage extends ConsumerWidget {
  const ChurchPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overviewState = ref.watch(churchOverviewProvider);
    final role = ref.watch(currentProfileProvider).value?.role;
    // Issuing a code is a church-admin power; the RLS policy is the real gate,
    // this just avoids showing a button that would always be refused.
    final canIssueInvites =
        role == UserRole.churchAdmin || role == UserRole.appAdmin;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(churchOverviewProvider);
          ref.invalidate(churchInvitesProvider);
          await ref.read(churchOverviewProvider.future);
        },
        child: AsyncValueView(
          value: overviewState,
          onRetry: () => ref.invalidate(churchOverviewProvider),
          builder: (overview) {
            if (overview == null) {
              return const EmptyState(
                icon: Icons.church_outlined,
                title: 'No church to show',
                message: 'This view is for youth pastors and church admins.',
              );
            }

            return ListView(
              padding: const EdgeInsets.all(AppTheme.space4),
              children: [
                _ChurchHeader(overview: overview),
                const SizedBox(height: AppTheme.space5),
                _InvitesSection(canIssue: canIssueInvites),
                const SizedBox(height: AppTheme.space5),
                _SectionHeading(
                  title: 'Families',
                  trailing: '${overview.householdCount}',
                ),
                const SizedBox(height: AppTheme.space2),
                if (overview.families.isEmpty)
                  const _InfoCard(
                    icon: Icons.home_outlined,
                    message: 'No families have been set up yet. Share a parent '
                        'code to get the first household started.',
                  )
                else
                  for (final family in overview.families)
                    _FamilyCard(summary: family),
                if (overview.unassigned.isNotEmpty) ...[
                  const SizedBox(height: AppTheme.space5),
                  _SectionHeading(
                    title: 'Not in a family yet',
                    trailing: '${overview.unassigned.length}',
                  ),
                  const SizedBox(height: AppTheme.space2),
                  const _InfoCard(
                    icon: Icons.info_outline,
                    message: 'These people signed up but have not created or '
                        'joined a household.',
                  ),
                  for (final person in overview.unassigned)
                    _PersonTile(person: person),
                ],
                if (overview.staff.isNotEmpty) ...[
                  const SizedBox(height: AppTheme.space5),
                  _SectionHeading(
                    title: 'Church staff',
                    trailing: '${overview.staff.length}',
                  ),
                  const SizedBox(height: AppTheme.space2),
                  for (final person in overview.staff)
                    _PersonTile(person: person),
                ],
                const SizedBox(height: AppTheme.space6),
              ],
            );
          },
        ),
      ),
      floatingActionButton: canIssueInvites
          ? FloatingActionButton.extended(
              onPressed: () => showIssueInviteSheet(context),
              icon: const Icon(Icons.add),
              label: const Text('New code'),
            )
          : null,
    );
  }
}

class _ChurchHeader extends StatelessWidget {
  const _ChurchHeader({required this.overview});

  final ChurchOverview overview;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final church = overview.church;

    return Card(
      color: theme.colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.space4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              church.name,
              style: theme.textTheme.headlineSmall?.copyWith(
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
            if (church.location.isNotEmpty) ...[
              const SizedBox(height: AppTheme.space1),
              Text(
                church.location,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
            ],
            const SizedBox(height: AppTheme.space4),
            Wrap(
              spacing: AppTheme.space5,
              runSpacing: AppTheme.space3,
              children: [
                _Stat(label: 'Families', value: overview.householdCount),
                _Stat(label: 'Parents', value: overview.parentCount),
                _Stat(label: 'Youth', value: overview.youthCount),
                _Stat(label: 'People', value: overview.peopleCount),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onContainer = theme.colorScheme.onPrimaryContainer;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$value',
          style: theme.textTheme.headlineSmall?.copyWith(
            color: onContainer,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(color: onContainer),
        ),
      ],
    );
  }
}

class _InvitesSection extends ConsumerWidget {
  const _InvitesSection({required this.canIssue});

  final bool canIssue;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invitesState = ref.watch(churchInvitesProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionHeading(title: 'Invite codes'),
        const SizedBox(height: AppTheme.space1),
        Text(
          'A code decides which church someone joins and in what role. Treat '
          'it like a key.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: AppTheme.space3),
        invitesState.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(AppTheme.space5),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, _) => ErrorView(
            message: '$error',
            onRetry: () => ref.invalidate(churchInvitesProvider),
          ),
          data: (invites) {
            if (invites.isEmpty) {
              return _InfoCard(
                icon: Icons.key_outlined,
                message: canIssue
                    ? 'No codes yet. Create one so people can join.'
                    : 'No codes yet. A church admin can create one.',
              );
            }
            final now = DateTime.now();
            return Column(
              children: [
                for (final invite in invites)
                  _InviteTile(invite: invite, now: now),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _InviteTile extends StatelessWidget {
  const _InviteTile({required this.invite, required this.now});

  final ChurchInvite invite;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final usable = invite.isUsableAt(now);

    return Card(
      margin: const EdgeInsets.only(bottom: AppTheme.space2),
      child: ListTile(
        leading: Icon(
          usable ? Icons.key : Icons.key_off_outlined,
          color: usable ? theme.colorScheme.primary : theme.colorScheme.outline,
        ),
        title: Text(
          invite.code,
          style: theme.textTheme.titleMedium?.copyWith(
            letterSpacing: 2,
            fontWeight: FontWeight.w700,
            color: usable ? null : theme.colorScheme.outline,
          ),
        ),
        subtitle: Text(
          '${invite.role.label} · ${invite.statusLabelAt(now)}',
        ),
        trailing: usable
            ? IconButton(
                tooltip: 'Copy code',
                icon: const Icon(Icons.copy),
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: invite.code));
                  if (context.mounted) {
                    showAppSnack(context, 'Code copied.');
                  }
                },
              )
            : null,
      ),
    );
  }
}

class _FamilyCard extends StatelessWidget {
  const _FamilyCard({required this.summary});

  final FamilySummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final head = summary.headOfHousehold;

    final counts = <String>[
      '${summary.parents.length} '
          '${summary.parents.length == 1 ? 'parent' : 'parents'}',
      '${summary.youth.length} youth',
    ];

    return Card(
      margin: const EdgeInsets.only(bottom: AppTheme.space2),
      child: ExpansionTile(
        shape: const Border(),
        collapsedShape: const Border(),
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.secondaryContainer,
          child: Icon(
            Icons.home_outlined,
            color: theme.colorScheme.onSecondaryContainer,
          ),
        ),
        title: Text(summary.family.name),
        subtitle: Text(counts.join(' · ')),
        trailing: summary.hasNoYouth
            ? Tooltip(
                message: 'No youth in this household',
                child: Icon(
                  Icons.info_outline,
                  size: 20,
                  color: theme.colorScheme.outline,
                ),
              )
            : null,
        childrenPadding: const EdgeInsets.only(bottom: AppTheme.space2),
        children: [
          if (summary.members.isEmpty)
            const Padding(
              padding: EdgeInsets.all(AppTheme.space4),
              child: Text('Nobody in this household yet.'),
            )
          else
            for (final member in summary.members)
              _PersonTile(
                person: member,
                isHead: head != null && head.id == member.id,
                dense: true,
              ),
        ],
      ),
    );
  }
}

class _PersonTile extends StatelessWidget {
  const _PersonTile({
    required this.person,
    this.isHead = false,
    this.dense = false,
  });

  final Profile person;
  final bool isHead;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final age = person.age;
    final details = <String>[
      person.role.label,
      if (age != null) 'age $age',
      if (person.grade != null) 'grade ${person.grade}',
      if (isHead) 'head of household',
    ];

    final tile = ListTile(
      dense: dense,
      leading: CircleAvatar(
        radius: dense ? 16 : 20,
        backgroundColor: theme.colorScheme.surfaceContainerHighest,
        child: Text(
          person.initials,
          style: theme.textTheme.labelMedium,
        ),
      ),
      title: Text(person.fullName),
      subtitle: Text(details.join(' · ')),
      trailing: person.baptized
          ? Tooltip(
              message: 'Baptized',
              child: Icon(
                Icons.water_drop,
                size: 20,
                color: theme.colorScheme.primary,
              ),
            )
          : null,
    );

    if (dense) return tile;
    return Card(
      margin: const EdgeInsets.only(bottom: AppTheme.space2),
      child: tile,
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title, this.trailing});

  final String title;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: theme.textTheme.titleMedium),
        if (trailing != null)
          Text(
            trailing!,
            style: theme.textTheme.titleMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
      ],
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: AppTheme.space2),
      color: theme.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.space4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: AppTheme.space3),
            Expanded(
              child: Text(
                message,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
