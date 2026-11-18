import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/network_image_box.dart';
import '../domain/discussion_image.dart';

/// Opens the gallery for up to [remaining] images. Returns an empty list if
/// the user cancels; never returns more than [remaining], since the web
/// picker ignores its limit.
Future<List<PendingImage>> pickDiscussionImages(int remaining) async {
  if (remaining <= 0) return const [];
  final picked = await ImagePicker().pickMultiImage(
    maxWidth: 1920,
    maxHeight: 1080,
    imageQuality: 80,
    limit: remaining,
  );
  return [
    for (final file in picked.take(remaining))
      PendingImage(fileName: file.name, bytes: await file.readAsBytes()),
  ];
}

/// Picked-but-unsent images as a row of removable thumbnails.
class PendingImageStrip extends StatelessWidget {
  const PendingImageStrip({
    required this.images,
    required this.onRemove,
    this.enabled = true,
    this.size = 88,
    super.key,
  });

  final List<PendingImage> images;
  final ValueChanged<int> onRemove;
  final bool enabled;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: size,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: images.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppTheme.space2),
        itemBuilder: (context, index) => Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
              child: Image.memory(
                images[index].bytes,
                width: size,
                height: size,
                fit: BoxFit.cover,
              ),
            ),
            Positioned(
              top: 2,
              right: 2,
              child: IconButton.filled(
                tooltip: 'Remove image',
                visualDensity: VisualDensity.compact,
                iconSize: 16,
                onPressed: enabled ? () => onRemove(index) : null,
                icon: const Icon(Icons.close),
                style: IconButton.styleFrom(
                  backgroundColor: scheme.scrim.withValues(alpha: 0.55),
                  foregroundColor: scheme.onPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Uploaded images on a post or reply. Tapping one opens it full screen.
class DiscussionImageGallery extends StatelessWidget {
  const DiscussionImageGallery({required this.urls, super.key})
    : thumbnailSize = null;

  /// A row of small square thumbnails, for replies.
  const DiscussionImageGallery.thumbnails({
    required this.urls,
    this.thumbnailSize = 96,
    super.key,
  });

  final List<String> urls;

  /// Null shows each image full width at its natural shape.
  final double? thumbnailSize;

  @override
  Widget build(BuildContext context) {
    final size = thumbnailSize;
    if (size == null) {
      return Column(
        children: [
          for (final (index, url) in urls.indexed) ...[
            if (index > 0) const SizedBox(height: AppTheme.space2),
            _Tappable(
              url: url,
              child: NetworkImageBox(url: url, aspectRatio: null),
            ),
          ],
        ],
      );
    }
    return Wrap(
      spacing: AppTheme.space2,
      runSpacing: AppTheme.space2,
      children: [
        for (final url in urls)
          _Tappable(
            url: url,
            child: SizedBox.square(
              dimension: size,
              child: NetworkImageBox(url: url, aspectRatio: 1),
            ),
          ),
      ],
    );
  }
}

/// The first image of a post, with a "+N" badge when there are more — for
/// list cards, where a full gallery would crowd the feed.
class DiscussionImagePreview extends StatelessWidget {
  const DiscussionImagePreview({required this.urls, super.key});

  final List<String> urls;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final extra = urls.length - 1;
    return Stack(
      children: [
        NetworkImageBox(url: urls.first),
        if (extra > 0)
          Positioned(
            right: AppTheme.space2,
            bottom: AppTheme.space2,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: theme.colorScheme.scrim.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.space2,
                  vertical: AppTheme.space1,
                ),
                child: Text(
                  '+$extra',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.onPrimary,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _Tappable extends StatelessWidget {
  const _Tappable({required this.url, required this.child});

  final String url;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => showDialog<void>(
        context: context,
        builder: (context) => Dialog.fullscreen(
          backgroundColor: Colors.black,
          child: Stack(
            children: [
              Center(child: InteractiveViewer(child: Image.network(url))),
              Positioned(
                top: AppTheme.space2,
                right: AppTheme.space2,
                child: SafeArea(
                  child: IconButton(
                    tooltip: 'Close',
                    color: Colors.white,
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      child: MouseRegion(cursor: SystemMouseCursors.click, child: child),
    );
  }
}
