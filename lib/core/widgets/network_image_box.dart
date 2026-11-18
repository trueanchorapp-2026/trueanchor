import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// A rounded, fixed-aspect network image with a quiet placeholder while it
/// loads and a broken-image tile if it fails — so a slow phone connection
/// shows a calm box rather than a jumping layout or a red error.
class NetworkImageBox extends StatelessWidget {
  const NetworkImageBox({
    required this.url,
    this.aspectRatio = 16 / 9,
    this.semanticLabel,
    super.key,
  });

  final String url;

  /// Crops to this ratio. Null shows the whole image at its natural shape —
  /// for a detail view, where cropping would hide part of the photo.
  final double? aspectRatio;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    Widget placeholder(IconData? icon) {
      final box = ColoredBox(
        color: scheme.surfaceContainerHigh,
        child: icon == null
            ? null
            : Center(child: Icon(icon, color: scheme.onSurfaceVariant)),
      );
      // Without a ratio the box has no height of its own.
      return aspectRatio == null
          ? SizedBox(height: 200, width: double.infinity, child: box)
          : box;
    }

    final image = Image.network(
      url,
      width: double.infinity,
      fit: BoxFit.cover,
      semanticLabel: semanticLabel,
      loadingBuilder: (context, child, progress) =>
          progress == null ? child : placeholder(null),
      errorBuilder: (context, error, stack) =>
          placeholder(Icons.broken_image_outlined),
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      child: aspectRatio == null
          ? image
          : AspectRatio(aspectRatio: aspectRatio!, child: image),
    );
  }
}
