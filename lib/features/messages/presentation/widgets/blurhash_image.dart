import 'dart:typed_data';

import 'package:blurhash_dart/blurhash_dart.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

/// Widget that displays a blurhash placeholder
/// Used while images/videos are loading
class BlurhashImage extends StatefulWidget {
  final String blurhash;
  final double? width;
  final double? height;
  final BoxFit fit;

  const BlurhashImage({
    super.key,
    required this.blurhash,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
  });

  @override
  State<BlurhashImage> createState() => _BlurhashImageState();
}

class _BlurhashImageState extends State<BlurhashImage> {
  Uint8List? _decodedImage;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _decodeBlurhash();
  }

  @override
  void didUpdateWidget(BlurhashImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.blurhash != widget.blurhash) {
      _decodeBlurhash();
    }
  }

  void _decodeBlurhash() {
    try {
      final blurImage = BlurHash.decode(widget.blurhash);
      final image = blurImage.toImage(35, 20);
      final bytes = Uint8List.fromList(img.encodeBmp(image));

      if (mounted) {
        setState(() {
          _decodedImage = bytes;
          _hasError = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError || _decodedImage == null) {
      return Container(
        width: widget.width,
        height: widget.height,
        color: Colors.grey.shade300,
      );
    }

    return Image.memory(
      _decodedImage!,
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      gaplessPlayback: true,
    );
  }
}
