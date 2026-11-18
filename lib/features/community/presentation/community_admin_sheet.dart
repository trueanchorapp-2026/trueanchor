import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import '../application/community_providers.dart';
import '../domain/community.dart';
import '../domain/community_membership.dart';

/// Regional admin: choose which adult(s) manage [community]. Each member
/// family can have one admin; picking another adult in that family moves
/// the role to them.
Future<void> showCommunityAdminSheet(
  BuildContext context,
  Community community,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _AdminSheet(community: community),
  );
}

class _AdminSheet extends ConsumerStatefulWidget {
  const _AdminSheet({required this.community});

  final Community community;

  @override
  ConsumerState<_AdminSheet> createState() => _AdminSheetState();
}

class _AdminSheetState extends ConsumerState<_AdminSheet> {
  String? _busyUserId;

  Future<void> _toggle(CommunityAdminCandidate candidate) async {
    final revoking = candidate.isAdmin;
    if (revoking) {
      final confirmed = await confirmDestructive(
        context,
        title: 'Remove ${candidate.displayName} as admin?',
        message: 'They will no longer be able to post news or resources, '
            'or manage events, for ${widget.community.name}.',
      );
      if (!confirmed) return;
    }
    setState(() => _busyUserId = candidate.userId);
    try {
      await ref
          .read(communityAdminCandidatesProvider(widget.community.id).notifier)
          .setAdmin(
            membershipId: candidate.membershipId,
            userId: revoking ? null : candidate.userId,
          );
      if (mounted) {
        showAppSnack(
          context,
          revoking
              ? '${candidate.displayName} is no longer an admin.'
              : '${candidate.displayName} is now a community admin.',
        );
      }
    } catch (e) {
      if (mounted) showAppSnack(context, '$e', isError: true);
    } finally {
      if (mounted) setState(() => _busyUserId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final candidates =
        ref.watch(communityAdminCandidatesProvider(widget.community.id));

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppTheme.space5),
              child: Text(
                'Admins for ${widget.community.name}',
                style: theme.textTheme.titleMedium,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppTheme.space5,
                AppTheme.space1,
                AppTheme.space5,
                AppTheme.space3,
              ),
              child: Text(
                'Admins post news and Parent Hub resources and manage '
                'events. One adult per member family.',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
            Flexible(
              child: candidates.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(AppTheme.space5),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => Padding(
                  padding: const EdgeInsets.all(AppTheme.space5),
                  child: Text('Could not load members: $e'),
                ),
                data: (list) {
                  if (list.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(AppTheme.space5),
                      child: Text('No families have joined yet.'),
                    );
                  }
                  final groups = groupCandidatesByFamily(list);
                  return ListView(
                    shrinkWrap: true,
                    children: [
                      for (final group in groups) ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(
                            AppTheme.space5,
                            AppTheme.space3,
                            AppTheme.space5,
                            0,
                          ),
                          child: Text(
                            group.familyName,
                            style: theme.textTheme.labelLarge,
                          ),
                        ),
                        for (final c in group.adults)
                          ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: AppTheme.space5,
                            ),
                            title: Text(c.displayName),
                            trailing: _busyUserId == c.userId
                                ? const SizedBox.square(
                                    dimension: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : c.isAdmin
                                    ? const Chip(label: Text('Admin'))
                                    : null,
                            subtitle: c.isAdmin ? null : const Text('Tap to make admin'),
                            onTap: _busyUserId == null ? () => _toggle(c) : null,
                          ),
                      ],
                      const SizedBox(height: AppTheme.space4),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
