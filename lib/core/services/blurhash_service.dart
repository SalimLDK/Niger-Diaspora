import 'dart:io';

import 'package:blurhash_dart/blurhash_dart.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;
import 'package:video_thumbnail/video_thumbnail.dart';

/// Provider for the blurhash service
final blurhashServiceProvider = Provider<BlurhashService>((ref) {
  return BlurhashService();
});

/// Service for generating and decoding blurhash placeholders
class BlurhashService {
  /// Generate a blurhash from an image file
  /// Returns null if generation fails
  Future<String?> generateFromImage(File imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();
      return await compute(_generateBlurhashFromBytes, bytes);
    } catch (e) {
      debugPrint('BlurhashService: Error generating blurhash from image: $e');
      return null;
    }
  }

  /// Generate a blurhash from a video file (uses first frame)
  /// Returns null if generation fails
  Future<String?> generateFromVideo(File videoFile) async {
    try {
      // Get thumbnail from video
      final thumbnailBytes = await VideoThumbnail.thumbnailData(
        video: videoFile.path,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 128,
        quality: 50,
      );

      if (thumbnailBytes == null) {
        debugPrint('BlurhashService: Could not generate video thumbnail');
        return null;
      }

      return await compute(_generateBlurhashFromBytes, thumbnailBytes);
    } catch (e) {
      debugPrint('BlurhashService: Error generating blurhash from video: $e');
      return null;
    }
  }

  /// Generate a blurhash from image bytes (for already loaded images)
  Future<String?> generateFromBytes(Uint8List bytes) async {
    try {
      return await compute(_generateBlurhashFromBytes, bytes);
    } catch (e) {
      debugPrint('BlurhashService: Error generating blurhash from bytes: $e');
      return null;
    }
  }

  /// Decode a blurhash to an Image widget
  /// Returns a placeholder widget if decoding fails
  static Widget decodeToWidget({
    required String? blurhash,
    required double width,
    required double height,
    BoxFit fit = BoxFit.cover,
  }) {
    if (blurhash == null || blurhash.isEmpty) {
      return Container(
        width: width,
        height: height,
        color: Colors.grey.shade300,
      );
    }

    try {
      final blurImage = BlurHash.decode(blurhash);
      final image = blurImage.toImage(35, 20);

      return Image.memory(
        Uint8List.fromList(img.encodeJpg(image)),
        width: width,
        height: height,
        fit: fit,
        gaplessPlayback: true,
      );
    } catch (e) {
      debugPrint('BlurhashService: Error decoding blurhash: $e');
      return Container(
        width: width,
        height: height,
        color: Colors.grey.shade300,
      );
    }
  }
}

/// Isolate function to generate blurhash from bytes
String? _generateBlurhashFromBytes(Uint8List bytes) {
  try {
    // Decode the image
    final image = img.decodeImage(bytes);
    if (image == null) return null;

    // Resize for faster processing (blurhash doesn't need high resolution)
    final resized = img.copyResize(image, width: 32);

    // Generate blurhash with 4x3 components (good balance of detail vs size)
    final blurhash = BlurHash.encode(resized, numCompX: 4, numCompY: 3);
    return blurhash.hash;
  } catch (e) {
    return null;
  }
}
