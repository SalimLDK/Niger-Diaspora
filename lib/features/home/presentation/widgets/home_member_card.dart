import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/adaptive_colors.dart';
import '../../../profile/presentation/widgets/online_status_indicator.dart';

class HomeMemberCard extends StatelessWidget {
  final String userId;
  final String name;
  final String location;
  final String badge;
  final String? photoUrl;

  const HomeMemberCard({
    super.key,
    required this.userId,
    required this.name,
    required this.location,
    required this.badge,
    this.photoUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 150,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(24),
        border:
            context.isDarkMode
                ? Border.all(color: context.borderColor, width: 1)
                : null,
        boxShadow:
            context.isDarkMode
                ? null
                : [
                  BoxShadow(
                    color: context.adaptivePrimaryColor.withValues(alpha: 0.08),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
      ),
      child: Column(
        children: [
          Stack(
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  gradient: context.adaptivePrimaryGradient,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: context.adaptivePrimaryColor.withValues(
                        alpha: 0.3,
                      ),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child:
                    photoUrl != null
                        ? ClipOval(
                          child: CachedNetworkImage(
                            imageUrl: photoUrl!,
                            fit: BoxFit.cover,
                            width: 72,
                            height: 72,
                            placeholder:
                                (_, __) => const Icon(
                                  Icons.person,
                                  color: AppColors.white,
                                  size: 36,
                                ),
                            errorWidget:
                                (_, __, ___) => const Icon(
                                  Icons.person,
                                  color: AppColors.white,
                                  size: 36,
                                ),
                          ),
                        )
                        : const Icon(
                          Icons.person,
                          color: AppColors.white,
                          size: 36,
                        ),
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: context.surfaceColor,
                    shape: BoxShape.circle,
                  ),
                  child: OnlineStatusIndicator(
                    userId: userId,
                    showText: false,
                    dotSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            name,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: context.textPrimaryColor,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          if (location.isNotEmpty)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.location_on,
                  size: 13,
                  color: context.adaptiveSecondaryColor,
                ),
                const SizedBox(width: 3),
                Flexible(
                  child: Text(
                    location,
                    style: TextStyle(
                      fontSize: 12,
                      color: context.textSecondaryColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          const Spacer(),
          if (badge.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: context.primaryBackgroundColor,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                badge,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: context.adaptivePrimaryColor,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
    );
  }
}

class HomeMemberCardLoading extends StatelessWidget {
  const HomeMemberCardLoading({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 140,
      padding: const EdgeInsets.all(16),
      decoration: context.cardDecoration,
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: context.surfaceVariantColor,
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: 80,
            height: 14,
            decoration: BoxDecoration(
              color: context.surfaceVariantColor,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: 60,
            height: 10,
            decoration: BoxDecoration(
              color: context.surfaceVariantColor,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ],
      ),
    );
  }
}
