import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../../../../core/theme/adaptive_colors.dart';
import 'full_screen_image_viewer.dart';

class OptimizedImageBubble extends StatelessWidget {
  final String imageUrl;
  final String? caption;
  final String heroTag;
  final bool isMe;
  final VoidCallback? onTap;

  const OptimizedImageBubble({
    super.key,
    required this.imageUrl,
    this.caption,
    required this.heroTag,
    this.isMe = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap:
          onTap ??
          () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder:
                    (context) => FullScreenImageViewer(
                      imageUrl: imageUrl,
                      heroTag: heroTag,
                    ),
              ),
            );
          },
      child: Hero(
        tag: heroTag,
        child: Container(
          constraints: const BoxConstraints(
            maxWidth: 280,
            maxHeight: 350,
            minWidth: 100,
            minHeight: 100,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft:
                  isMe ? const Radius.circular(16) : const Radius.circular(4),
              bottomRight:
                  isMe ? const Radius.circular(4) : const Radius.circular(16),
            ),
            color: context.surfaceColor,
            boxShadow:
                context.isDarkMode
                    ? null
                    : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft:
                  isMe ? const Radius.circular(16) : const Radius.circular(4),
              bottomRight:
                  isMe ? const Radius.circular(4) : const Radius.circular(16),
            ),
            child: Stack(
              alignment: Alignment.bottomLeft,
              children: [
                CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  placeholder:
                      (context, url) => Shimmer.fromColors(
                        baseColor:
                            context.isDarkMode
                                ? Colors.grey[800]!
                                : Colors.grey[300]!,
                        highlightColor:
                            context.isDarkMode
                                ? Colors.grey[700]!
                                : Colors.grey[100]!,
                        child: Container(
                          width: double.infinity,
                          height: 200,
                          color: context.surfaceColor,
                        ),
                      ),
                  errorWidget:
                      (context, url, error) => Container(
                        width: double.infinity,
                        height: 200,
                        color: context.surfaceColor,
                        child: Center(
                          child: Icon(
                            Icons.broken_image_rounded,
                            color: context.textTertiaryColor,
                            size: 48,
                          ),
                        ),
                      ),
                ),
                if (caption != null && caption!.isNotEmpty)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.7),
                            Colors.transparent,
                          ],
                        ),
                      ),
                      child: Text(
                        caption!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
