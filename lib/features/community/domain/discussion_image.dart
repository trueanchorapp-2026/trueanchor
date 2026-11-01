import 'dart:typed_data';

/// An image the author has picked but not yet uploaded.
class PendingImage {
  const PendingImage({required this.fileName, required this.bytes});

  final String fileName;
  final Uint8List bytes;
}

/// Rules shared by images on discussion posts and replies.
abstract final class DiscussionImages {
  /// Mirrors the `cardinality(image_urls) <= 5` checks in 0029.
  static const maxPerEntry = 5;

  /// Image types the `discussion-images` bucket accepts (see 0028).
  static const contentTypes = {
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
    'png': 'image/png',
    'gif': 'image/gif',
    'webp': 'image/webp',
  };

  /// The content type to upload [fileName] as. Unknown extensions fall back
  /// to JPEG, which is what the picker re-encodes to when it compresses.
  static String contentTypeFor(String fileName) {
    final dot = fileName.lastIndexOf('.');
    final extension =
        dot == -1 ? '' : fileName.substring(dot + 1).toLowerCase();
    return contentTypes[extension] ?? 'image/jpeg';
  }

  /// [fileName] reduced to characters that are safe in a storage path.
  static String safeFileName(String fileName) {
    final cleaned = fileName.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    return cleaned.isEmpty ? 'image' : cleaned;
  }

  /// Reads the `image_urls` array column; tolerates it being absent or null.
  static List<String> urlsFromJson(Object? value) =>
      value is List ? value.whereType<String>().toList() : const [];
}
