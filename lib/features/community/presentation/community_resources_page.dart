import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import '../application/community_providers.dart';
import 'topic_tag_widgets.dart';

class CommunityResourcesPage extends ConsumerWidget {
  const CommunityResourcesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allResources = ref.watch(parentResourcesProvider);
    final filtered = ref.watch(filteredParentResourcesProvider);
    final filter = ref.watch(resourceFilterProvider);
    final filterNotifier = ref.read(resourceFilterProvider.notifier);
    final insets = feedInsets(context);

    final hasAny = allResources.value?.isNotEmpty ?? false;

    return Column(
      children: [
        if (hasAny)
          Padding(
            padding: EdgeInsets.fromLTRB(
              insets.left,
              AppTheme.space3,
              insets.right,
              0,
            ),
            child: TagFilterBar(
              searchHint: 'Search resources',
              selectedTagIds: filter.tagIds,
              initialText: filter.text,
              isFiltered: filter.isFiltered,
              onToggleTag: filterNotifier.toggleTag,
              onTextChanged: filterNotifier.setText,
              onClear: filterNotifier.clear,
            ),
          ),
        Expanded(
          child: AsyncValueView(
            value: filtered,
            onRetry: () => ref.invalidate(parentResourcesProvider),
            builder: (resources) {
              if (resources.isEmpty) {
                return Center(
                  child: filter.isFiltered
                      ? EmptyState(
                          icon: Icons.search_off,
                          title: 'No matching resources',
                          message: 'Try another topic or search.',
                          action: OutlinedButton(
                            onPressed: filterNotifier.clear,
                            child: const Text('Clear filters'),
                          ),
                        )
                      : const EmptyState(
                          icon: Icons.library_books_outlined,
                          title: 'No resources yet',
                          message: 'Parent resources will appear here once '
                              'available.',
                        ),
                );
              }

              return ListView.separated(
                padding: insets.copyWith(
                  top: AppTheme.space2,
                  bottom: AppTheme.space2,
                ),
                itemCount: resources.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final resource = resources[index];
                  return ListTile(
                    title: Text(resource.title),
                    subtitle: resource.tagIds.isEmpty
                        ? null
                        : Padding(
                            padding:
                                const EdgeInsets.only(top: AppTheme.space1),
                            child: TagChipRow(
                              tagIds: resource.tagIds,
                              onTap: (tagId) {
                                if (!filter.tagIds.contains(tagId)) {
                                  filterNotifier.toggleTag(tagId);
                                }
                              },
                            ),
                          ),
                    trailing: const Icon(Icons.open_in_new, size: 20),
                    onTap: () => launchUrl(
                      Uri.parse(resource.url),
                      mode: LaunchMode.externalApplication,
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
