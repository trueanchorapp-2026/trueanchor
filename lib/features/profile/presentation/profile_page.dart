import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../auth/application/auth_providers.dart';
import '../../family/application/family_providers.dart';
import '../application/profile_providers.dart';
import '../domain/profile.dart';
import '../domain/user_role.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileState = ref.watch(currentProfileProvider);

    return AsyncValueView(
      value: profileState,
      onRetry: () => ref.read(currentProfileProvider.notifier).refresh(),
      builder: (profile) {
        if (profile == null) {
          return const EmptyState(
            icon: Icons.person_off_outlined,
            title: 'No profile',
            message: 'We could not load your profile.',
          );
        }
        return _ProfileBody(profile: profile);
      },
    );
  }
}

class _ProfileBody extends ConsumerWidget {
  const _ProfileBody({required this.profile});

  final Profile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final family = ref.watch(currentFamilyProvider).value;
    final age = profile.age;
    final isYouth = profile.role == UserRole.youth;

    return ListView(
      padding: const EdgeInsets.all(AppTheme.space4),
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 32,
              backgroundColor: theme.colorScheme.primaryContainer,
              child: Text(
                profile.initials,
                style: theme.textTheme.titleLarge
                    ?.copyWith(color: theme.colorScheme.onPrimaryContainer),
              ),
            ),
            const SizedBox(width: AppTheme.space4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(profile.fullName, style: theme.textTheme.titleLarge),
                  const SizedBox(height: AppTheme.space1),
                  Text(
                    profile.role.label,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: theme.colorScheme.primary),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppTheme.space5),
        Card(
          child: Column(
            children: [
              _InfoRow(label: 'Email', value: profile.email),
              if (profile.phone?.isNotEmpty ?? false)
                _InfoRow(label: 'Phone', value: profile.phone!),
              if (family != null)
                _InfoRow(label: 'Family', value: family.name),
              if (isYouth) ...[
                if (age != null) _InfoRow(label: 'Age', value: '$age'),
                if (profile.grade != null)
                  _InfoRow(label: 'Grade', value: '${profile.grade}'),
                if (profile.gender?.isNotEmpty ?? false)
                  _InfoRow(label: 'Gender', value: profile.gender!),
                _InfoRow(
                  label: 'Baptized',
                  value: profile.baptized
                      ? (profile.baptizedOn != null
                          ? DateFormat.yMMMd().format(profile.baptizedOn!)
                          : 'Yes')
                      : 'Not yet',
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppTheme.space5),
        OutlinedButton.icon(
          onPressed: () => context.push(Routes.editProfile),
          icon: const Icon(Icons.edit_outlined),
          label: const Text('Edit profile'),
        ),
        const SizedBox(height: AppTheme.space3),
        TextButton.icon(
          onPressed: () async {
            final confirmed = await confirmDestructive(
              context,
              title: 'Sign out?',
              message: 'You will need your email and password to sign back in.',
              confirmLabel: 'Sign out',
            );
            if (!confirmed) return;
            await ref.read(authControllerProvider.notifier).signOut();
          },
          icon: const Icon(Icons.logout),
          label: const Text('Sign out'),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.space4,
        vertical: AppTheme.space3,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
          Expanded(child: Text(value, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}
