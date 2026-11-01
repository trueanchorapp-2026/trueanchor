import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import '../application/community_providers.dart';

class CommunityResourcesPage extends ConsumerWidget {
  const CommunityResourcesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resourcesState = ref.watch(parentResourcesProvider);

    return AsyncValueView(
      value: resourcesState,
      builder: (resources) {
        if (resources.isEmpty) {
          return const Center(
            child: EmptyState(
              icon: Icons.library_books_outlined,
              title: 'No resources yet',
              message: 'Parent resources will appear here once available.',
            ),
          );
        }

        return ListView.separated(
          padding: feedInsets(context).copyWith(
            top: AppTheme.space2,
            bottom: AppTheme.space2,
          ),
          itemCount: resources.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final resource = resources[index];
            return ListTile(
              title: Text(resource.title),
              trailing: const Icon(Icons.open_in_new, size: 20),
              onTap: () => launchUrl(
                Uri.parse(resource.url),
                mode: LaunchMode.externalApplication,
              ),
            );
          },
        );
      },
    );
  }
}
