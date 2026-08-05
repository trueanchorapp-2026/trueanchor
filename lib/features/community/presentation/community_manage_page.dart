import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import '../application/community_providers.dart';
import '../domain/community.dart';
import '../domain/region.dart';

class CommunityManagePage extends ConsumerWidget {
  const CommunityManagePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final regions = ref.watch(regionListProvider);

    return RefreshIndicator(
      onRefresh: () => ref.read(regionListProvider.notifier).refresh(),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppTheme.space5),
        child: Center(
          child: ConstrainedBox(
            constraints:
                const BoxConstraints(maxWidth: AppTheme.maxContentWidth),
            child: AsyncValueView<List<Region>>(
              value: regions,
              onRetry: () =>
                  ref.read(regionListProvider.notifier).refresh(),
              builder: (regionList) => _ManageContent(regions: regionList),
            ),
          ),
        ),
      ),
    );
  }
}

class _ManageContent extends ConsumerStatefulWidget {
  const _ManageContent({required this.regions});

  final List<Region> regions;

  @override
  ConsumerState<_ManageContent> createState() => _ManageContentState();
}

class _ManageContentState extends ConsumerState<_ManageContent> {
  String? _expandedRegionId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text('Regions & Communities',
                  style: theme.textTheme.headlineSmall),
            ),
            FilledButton.tonalIcon(
              onPressed: () => _showCreateRegionDialog(context),
              icon: const Icon(Icons.add),
              label: const Text('Region'),
            ),
          ],
        ),
        const SizedBox(height: AppTheme.space4),
        if (widget.regions.isEmpty)
          const EmptyState(
            icon: Icons.map_outlined,
            title: 'No regions',
            message: 'Create a region to get started.',
          )
        else
          for (final region in widget.regions) ...[
            _RegionTile(
              region: region,
              expanded: _expandedRegionId == region.id,
              onToggle: () => setState(() {
                _expandedRegionId =
                    _expandedRegionId == region.id ? null : region.id;
              }),
            ),
            const SizedBox(height: AppTheme.space3),
          ],
      ],
    );
  }

  Future<void> _showCreateRegionDialog(BuildContext context) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New region'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Region name',
            hintText: 'e.g. Broward County',
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, controller.text),
              child: const Text('Create')),
        ],
      ),
    );
    controller.dispose();

    if (name == null || name.trim().isEmpty) return;
    try {
      await ref.read(regionListProvider.notifier).add(name: name);
      if (mounted) showAppSnack(context, 'Region created.');
    } catch (e) {
      if (mounted) showAppSnack(context, '$e', isError: true);
    }
  }
}

class _RegionTile extends ConsumerWidget {
  const _RegionTile({
    required this.region,
    required this.expanded,
    required this.onToggle,
  });

  final Region region;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Card(
      child: Column(
        children: [
          ListTile(
            leading: Icon(Icons.map_outlined,
                color: theme.colorScheme.primary),
            title: Text(region.name, style: theme.textTheme.titleMedium),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _deleteRegion(context, ref),
                  tooltip: 'Delete region',
                ),
                Icon(expanded
                    ? Icons.expand_less
                    : Icons.expand_more),
              ],
            ),
            onTap: onToggle,
          ),
          if (expanded) _CommunitiesSection(regionId: region.id),
        ],
      ),
    );
  }

  Future<void> _deleteRegion(BuildContext context, WidgetRef ref) async {
    final confirmed = await confirmDestructive(
      context,
      title: 'Delete "${region.name}"?',
      message: 'All communities in this region will also be deleted.',
    );
    if (confirmed) {
      try {
        await ref.read(regionListProvider.notifier).remove(region.id);
        if (context.mounted) showAppSnack(context, 'Region deleted.');
      } catch (e) {
        if (context.mounted) showAppSnack(context, '$e', isError: true);
      }
    }
  }
}

class _CommunitiesSection extends ConsumerWidget {
  const _CommunitiesSection({required this.regionId});

  final String regionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final communities = ref.watch(communitiesByRegionProvider(regionId));
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppTheme.space4, 0, AppTheme.space4, AppTheme.space4),
      child: communities.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(AppTheme.space4),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (_, _) => const Text('Could not load communities.'),
        data: (list) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Divider(),
            for (final community in list)
              ListTile(
                dense: true,
                title: Text(community.name),
                subtitle: community.locationDisplay.isNotEmpty
                    ? Text(community.locationDisplay)
                    : null,
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20),
                  onPressed: () =>
                      _deleteCommunity(context, ref, community),
                ),
              ),
            const SizedBox(height: AppTheme.space2),
            FilledButton.tonalIcon(
              onPressed: () =>
                  _showCreateCommunityDialog(context, ref),
              icon: const Icon(Icons.add),
              label: const Text('Add community'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showCreateCommunityDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final nameCtrl = TextEditingController();
    final cityCtrl = TextEditingController();
    final result = await showDialog<(String, String)?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New community'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Community name',
                hintText: 'e.g. Coral Springs',
              ),
            ),
            const SizedBox(height: AppTheme.space3),
            TextField(
              controller: cityCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'City (optional)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () =>
                  Navigator.pop(ctx, (nameCtrl.text, cityCtrl.text)),
              child: const Text('Create')),
        ],
      ),
    );
    nameCtrl.dispose();
    cityCtrl.dispose();

    if (result == null || result.$1.trim().isEmpty) return;
    try {
      await ref.read(communityListProvider.notifier).add(
            regionId: regionId,
            name: result.$1,
            city: result.$2,
          );
      ref.invalidate(communitiesByRegionProvider(regionId));
      if (context.mounted) showAppSnack(context, 'Community created.');
    } catch (e) {
      if (context.mounted) showAppSnack(context, '$e', isError: true);
    }
  }

  Future<void> _deleteCommunity(
    BuildContext context,
    WidgetRef ref,
    Community community,
  ) async {
    final confirmed = await confirmDestructive(
      context,
      title: 'Delete "${community.name}"?',
      message: 'All memberships, news, discussions, and events in this '
          'community will also be deleted.',
    );
    if (confirmed) {
      try {
        await ref
            .read(communityListProvider.notifier)
            .remove(community.id);
        ref.invalidate(communitiesByRegionProvider(regionId));
        if (context.mounted) showAppSnack(context, 'Community deleted.');
      } catch (e) {
        if (context.mounted) showAppSnack(context, '$e', isError: true);
      }
    }
  }
}
