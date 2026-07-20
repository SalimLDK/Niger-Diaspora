import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/adaptive_colors.dart';
import 'package:diaspo_niger/shared/widgets/app_icon.dart';

class LinkPreviewBubble extends StatelessWidget {
  final String? url;
  final String? title;
  final String? description;
  final String? imageUrl;
  final String? siteName;
  final bool isMe;

  const LinkPreviewBubble({
    super.key,
    this.url,
    this.title,
    this.description,
    this.imageUrl,
    this.siteName,
    required this.isMe,
  });

  factory LinkPreviewBubble.fromMap(Map<String, dynamic> data, {required bool isMe}) {
    return LinkPreviewBubble(
      url: data['url'] as String?,
      title: data['title'] as String?,
      description: data['description'] as String?,
      imageUrl: data['imageUrl'] as String?,
      siteName: data['siteName'] as String?,
      isMe: isMe,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (url == null) return const SizedBox.shrink();

    final cardBgColor = isMe
        ? Colors.black.withValues(alpha: 0.20)
        : context.isDarkMode
            ? Colors.white.withValues(alpha: 0.10)
            : Colors.black.withValues(alpha: 0.08);

    final borderColor = isMe
        ? Colors.white.withValues(alpha: 0.15)
        : context.isDarkMode
            ? Colors.white.withValues(alpha: 0.12)
            : Colors.black.withValues(alpha: 0.10);

    return GestureDetector(
      onTap: () => _openUrl(url!),
      child: Container(
        margin: const EdgeInsets.only(top: 6),
        decoration: BoxDecoration(
          color: cardBgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: 0.5),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Preview image with gradient overlay
            if (imageUrl != null && imageUrl!.isNotEmpty)
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 160),
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(11.5),
                        topRight: Radius.circular(11.5),
                      ),
                      child: CachedNetworkImage(
                        imageUrl: imageUrl!,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          height: 120,
                          color: isMe
                              ? Colors.black.withValues(alpha: 0.1)
                              : context.surfaceVariantColor,
                          child: Center(
                            child: AppIcon(AppIcon.image,
                              size: 32,
                              color: isMe
                                  ? AppColors.white.withValues(alpha: 0.4)
                                  : context.textTertiaryColor,
                            ),
                          ),
                        ),
                        errorWidget: (context, url, error) => Container(
                          height: 80,
                          color: isMe
                              ? Colors.black.withValues(alpha: 0.1)
                              : context.surfaceVariantColor,
                          child: Center(
                            child: Icon(
                              Icons.link_off,
                              size: 28,
                              color: isMe
                                  ? AppColors.white.withValues(alpha: 0.4)
                                  : context.textTertiaryColor,
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Gradient overlay at the bottom of the image
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      height: 40,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              cardBgColor.withValues(alpha: 0),
                              cardBgColor,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Divider between image and text
            if (imageUrl != null && imageUrl!.isNotEmpty)
              Divider(
                height: 0.5,
                thickness: 0.5,
                color: borderColor,
              ),

            // Text content
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Title
                  if (title != null && title!.isNotEmpty)
                    Text(
                      title!,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: isMe
                            ? AppColors.white
                            : context.textPrimaryColor,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),

                  // Description
                  if (description != null && description!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      description!,
                      style: TextStyle(
                        fontSize: 13,
                        color: isMe
                            ? AppColors.white.withValues(alpha: 0.8)
                            : context.textSecondaryColor,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],

                  // Site name
                  if (siteName != null && siteName!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.link,
                          size: 14,
                          color: isMe
                              ? AppColors.white.withValues(alpha: 0.6)
                              : context.textTertiaryColor,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            siteName!,
                            style: TextStyle(
                              fontSize: 12,
                              color: isMe
                                  ? AppColors.white.withValues(alpha: 0.6)
                                  : context.textTertiaryColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
