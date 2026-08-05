import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import '../application/community_providers.dart';
import '../domain/community.dart';
import '../domain/region.dart';

class JoinCommunityPage extends ConsumerStatefulWidget {
  const JoinCommunityPage({super.key});

  @override
  ConsumerState<JoinCommunityPage> createState() => _JoinCommunityPageState();
}

class _JoinCommunityPageState extends ConsumerState<JoinCommunityPage> {
  String? _selectedRegionId;
  bool _joining = false;

  Future<void> _join(Community community) async {
    setState(() => _joining = true);
    try {
      await ref
          .read(communityRepositoryProvider)
          .joinCommunity(community.id);
      ref.invalidate(myMembershipProvider);
      ref.invalidate(myCommunityProvider);
      if (mounted) {
        showAppSnack(context, 'Joined ${community.name}!');
      }
    } catch (e) {
      if (mounted) {
        showAppSnack(context, '$e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _joining = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final regions = ref.watch(regionListProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.space5),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppTheme.maxContentWidth),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Join a Community',
                  style: theme.textTheme.headlineSmall),
              const SizedBox(height: AppTheme.space2),
              Text(
                'Communities connect families across churches for outward '
                'impact. Select your region and community to get started.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppTheme.space5),
              AsyncValueView<List<Region>>(
                value: regions,
                onRetry: () =>
                    ref.read(regionListProvider.notifier).refresh(),
                builder: (regionList) {
                  if (regionList.isEmpty) {
                    return const EmptyState(
                      icon: Icons.map_outlined,
                      title: 'No regions yet',
                      message:
                          'No regions have been created. Ask your regional '
                          'admin to set one up.',
                    );
                  }
                  return _buildRegionPicker(regionList);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRegionPicker(List<Region> regions) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<String>(
          initialValue: _selectedRegionId,
          decoration: const InputDecoration(labelText: 'Select your region'),
          items: regions
              .map((r) => DropdownMenuItem(value: r.id, child: Text(r.name)))
              .toList(),
          onChanged: (value) => setState(() => _selectedRegionId = value),
        ),
        if (_selectedRegionId != null) ...[
          const SizedBox(height: AppTheme.space5),
          Text('Communities', style: theme.textTheme.titleMedium),
          const SizedBox(height: AppTheme.space3),
          _CommunityPicker(
            regionId: _selectedRegionId!,
            joining: _joining,
            onJoin: _join,
          ),
        ],
      ],
    );
  }
}

class _CommunityPicker extends ConsumerWidget {
  const _CommunityPicker({
    required this.regionId,
    required this.joining,
    required this.onJoin,
  });

  final String regionId;
  final bool joining;
  final ValueChanged<Community> onJoin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final communities = ref.watch(communitiesByRegionProvider(regionId));

    return AsyncValueView<List<Community>>(
      value: communities,
      onRetry: () => ref.invalidate(communitiesByRegionProvider(regionId)),
      builder: (list) {
        if (list.isEmpty) {
          return const EmptyState(
            icon: Icons.location_city_outlined,
            title: 'No communities yet',
            message: 'No communities have been created in this region yet.',
          );
        }
        return Column(
          children: [
            for (final community in list)
              Card(
                margin: const EdgeInsets.only(bottom: AppTheme.space3),
                child: ListTile(
                  title: Text(community.name),
                  subtitle: community.locationDisplay.isNotEmpty
                      ? Text(community.locationDisplay)
                      : null,
                  trailing: FilledButton.tonal(
                    onPressed: joining ? null : () => onJoin(community),
                    child: joining
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Join'),
                  ),
                  leading: CircleAvatar(
                    backgroundColor: theme.colorScheme.primaryContainer,
                    child: Icon(Icons.location_city,
                        color: theme.colorScheme.onPrimaryContainer),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
