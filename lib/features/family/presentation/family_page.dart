import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../profile/application/profile_providers.dart';
import '../../profile/domain/family_role.dart';
import '../../profile/domain/profile.dart';
import '../application/family_providers.dart';

class FamilyPage extends ConsumerWidget {
  const FamilyPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentProfileProvider).value;

    // Church staff have no household of their own; the router sends them to
    // the church view instead, and their nav bar never offers this page.
    if (profile != null && profile.role.isChurchStaff) {
      return const EmptyState(
        icon: Icons.church_outlined,
        title: 'No household',
        message: 'Your account belongs to the church, not to a family.',
      );
    }

    final familyState = ref.watch(currentFamilyProvider);
    final membersState = ref.watch(sortedFamilyMembersProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(currentFamilyProvider);
        ref.invalidate(familyMembersProvider);
        await ref.read(familyMembersProvider.future);
      },
      child: AsyncValueView(
        value: familyState,
        onRetry: () => ref.invalidate(currentFamilyProvider),
        builder: (family) {
          if (family == null) {
            return const EmptyState(
              icon: Icons.home_outlined,
              title: 'No family yet',
              message: 'Your household has not been set up.',
            );
          }

          return ListView(
            padding: const EdgeInsets.all(AppTheme.space4),
            children: [
              Text(family.name, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: AppTheme.space4),
              _JoinCodeCard(code: family.joinCode),
              const SizedBox(height: AppTheme.space5),
              Text(
                'Members',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: AppTheme.space2),
              membersState.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(AppTheme.space5),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (error, _) => ErrorView(message: '$error'),
                data: (members) => Column(
                  children: [
                    for (final member in members)
                      _MemberTile(
                        member: member,
                        isHead: family.isHeadOfHousehold(member.id),
                        isSelf: member.id == profile?.id,
                        // Only the head decides who is an adult here. The RPC
                        // enforces this too; hiding the menu just keeps the
                        // option out of everyone else's way.
                        canAssignRoles:
                            profile != null &&
                            family.isHeadOfHousehold(profile.id),
                        // Any adult in the household may maintain a youth's
                        // details; profiles_update_family_youth says the same.
                        canEditDetails: profile != null &&
                            profile.isHouseholdAdult &&
                            !member.isHouseholdAdult,
                        onAssign: (role) => _assignRole(
                          context,
                          ref,
                          member: member,
                          role: role,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

Future<void> _assignRole(
  BuildContext context,
  WidgetRef ref, {
  required Profile member,
  required FamilyRole role,
}) async {
  final wasAdult = member.isHouseholdAdult;

  // Crossing the adult/youth line changes what the app will show this person,
  // so it is not a silent relabel.
  if (wasAdult != role.isAdult) {
    final confirmed = await confirmDestructive(
      context,
      title: 'Change what ${member.firstName} can see?',
      message: role.isAdult
          ? '${member.firstName} will be treated as an adult and will be able '
              'to see journal entries your youth share with parents.'
          : '${member.firstName} will be treated as youth and will lose access '
              'to entries shared with parents.',
      confirmLabel: 'Change role',
    );
    if (!confirmed) return;
  }

  final ok = await ref
      .read(familyRoleControllerProvider.notifier)
      .assign(member.id, role);

  if (!context.mounted) return;
  if (ok) {
    showAppSnack(context, '${member.firstName} is now ${role.label}.');
  } else {
    final error = ref.read(familyRoleControllerProvider).error;
    showAppSnack(context, '$error', isError: true);
  }
}

class _JoinCodeCard extends StatelessWidget {
  const _JoinCodeCard({required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.space4),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Family code', style: theme.textTheme.labelLarge),
                  const SizedBox(height: AppTheme.space1),
                  Text(
                    code,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      letterSpacing: 4,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppTheme.space1),
                  Text(
                    'Share this so your family can join.',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            IconButton.filledTonal(
              tooltip: 'Copy code',
              icon: const Icon(Icons.copy),
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: code));
                if (context.mounted) {
                  showAppSnack(context, 'Family code copied.');
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// What the overflow menu on a member tile can do. A sealed type keeps the
/// two unrelated actions — relabelling someone, and editing their details — in
/// one menu without collapsing them into a single loosely-typed value.
sealed class _MemberAction {
  const _MemberAction();
}

class _EditDetails extends _MemberAction {
  const _EditDetails();
}

class _AssignRole extends _MemberAction {
  const _AssignRole(this.role);

  final FamilyRole role;
}

class _MemberTile extends StatelessWidget {
  const _MemberTile({
    required this.member,
    required this.isHead,
    required this.isSelf,
    required this.canAssignRoles,
    required this.canEditDetails,
    required this.onAssign,
  });

  final Profile member;
  final bool isHead;
  final bool isSelf;
  final bool canAssignRoles;
  final bool canEditDetails;
  final ValueChanged<FamilyRole> onAssign;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final age = member.age;
    final details = <String>[
      member.householdLabel,
      if (age != null) 'age $age',
      if (member.grade != null) 'grade ${member.grade}',
    ];

    // Church staff who share a household keep their church role; a head of
    // household must not be able to edit it (the RPC refuses too).
    final canRelabel = canAssignRoles && !member.role.isChurchStaff;
    final hasMenu = canRelabel || canEditDetails;

    return Card(
      margin: const EdgeInsets.only(bottom: AppTheme.space2),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.primaryContainer,
          child: Text(
            member.initials,
            style: TextStyle(color: theme.colorScheme.onPrimaryContainer),
          ),
        ),
        title: Row(
          children: [
            Flexible(child: Text(member.fullName)),
            if (isSelf) ...[
              const SizedBox(width: AppTheme.space2),
              const AppChip(label:'You'),
            ],
            if (isHead) ...[
              const SizedBox(width: AppTheme.space2),
              const AppChip(label:'Head'),
            ],
          ],
        ),
        subtitle: Text(details.join(' · ')),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (member.baptized)
              Tooltip(
                message: 'Baptized',
                child: Icon(Icons.water_drop,
                    size: 20, color: theme.colorScheme.primary),
              ),
            if (hasMenu)
              PopupMenuButton<_MemberAction>(
                tooltip: 'Member actions',
                icon: const Icon(Icons.more_vert),
                onSelected: (action) => switch (action) {
                  _EditDetails() =>
                    context.push(Routes.editMemberFor(member.id)),
                  _AssignRole(:final role) => onAssign(role),
                },
                itemBuilder: (context) => [
                  if (canEditDetails)
                    const PopupMenuItem(
                      value: _EditDetails(),
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined, size: 18),
                          SizedBox(width: AppTheme.space2),
                          Text('Edit details'),
                        ],
                      ),
                    ),
                  if (canEditDetails && canRelabel)
                    const PopupMenuDivider(),
                  if (canRelabel)
                    for (final role
                        in FamilyRole.assignableFor(memberIsHead: isHead))
                      PopupMenuItem(
                        value: _AssignRole(role),
                        enabled: role != member.familyRole,
                        child: Row(
                          children: [
                            Icon(
                              role == member.familyRole
                                  ? Icons.check
                                  : Icons.person_outline,
                              size: 18,
                            ),
                            const SizedBox(width: AppTheme.space2),
                            Text(role.label),
                          ],
                        ),
                      ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

