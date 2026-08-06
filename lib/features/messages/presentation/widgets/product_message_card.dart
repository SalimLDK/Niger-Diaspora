import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/adaptive_colors.dart';
import '../../../../shared/widgets/price_text.dart';
import 'package:diaspo_niger/l10n/app_localizations.dart';

/// Widget to display a product attachment in a message bubble
/// Tapping on it navigates to the product detail screen
class ProductMessageCard extends StatelessWidget {
  final Map<String, dynamic> productData;
  final bool isMe;

  const ProductMessageCard({
    super.key,
    required this.productData,
    required this.isMe,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final productId = productData['id'] as String?;
    final title = productData['title'] as String? ?? l10n.reportTypeProduct;
    final price = (productData['price'] as num?)?.toDouble() ?? 0.0;
    final currency = productData['currency'] as String? ?? 'XOF';
    final imageUrl = productData['imageUrl'] as String?;

    return GestureDetector(
      onTap: () {
        if (productId != null) {
          context.push('/marketplace/$productId');
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color:
              isMe
                  ? Colors.white.withValues(alpha: 0.15)
                  : context.isDarkMode
                  ? Colors.black.withValues(alpha: 0.2)
                  : Colors.black.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color:
                isMe
                    ? Colors.white.withValues(alpha: 0.2)
                    : context.adaptivePrimaryColor.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Product image
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(11),
                bottomLeft: Radius.circular(11),
              ),
              child: SizedBox(
                width: 80,
                height: 80,
                child:
                    imageUrl != null && imageUrl.isNotEmpty
                        ? CachedNetworkImage(
                          imageUrl: imageUrl,
                          fit: BoxFit.cover,
                          placeholder:
                              (_, __) => Container(
                                color: context.surfaceVariantColor,
                                child: Icon(
                                  Icons.shopping_bag_outlined,
                                  color: context.textTertiaryColor,
                                ),
                              ),
                          errorWidget:
                              (_, __, ___) => Container(
                                color: context.surfaceVariantColor,
                                child: Icon(
                                  Icons.shopping_bag_outlined,
                                  color: context.textTertiaryColor,
                                ),
                              ),
                        )
                        : Container(
                          color: context.surfaceVariantColor,
                          child: Icon(
                            Icons.shopping_bag_outlined,
                            color: context.textTertiaryColor,
                          ),
                        ),
              ),
            ),
            // Product info
            Flexible(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Product label
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.storefront,
                          size: 12,
                          color:
                              isMe
                                  ? Colors.white.withValues(alpha: 0.7)
                                  : context.adaptivePrimaryColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          l10n.reportTypeProduct,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color:
                                isMe
                                    ? Colors.white.withValues(alpha: 0.7)
                                    : context.adaptivePrimaryColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    // Title
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isMe ? Colors.white : context.textPrimaryColor,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    // Price
                    PriceText(
                      amount: price,
                      currency: currency,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color:
                            isMe
                                ? Colors.white.withValues(alpha: 0.9)
                                : context.adaptivePrimaryColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Arrow indicator
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Icon(
                Icons.chevron_right,
                size: 20,
                color:
                    isMe
                        ? Colors.white.withValues(alpha: 0.5)
                        : context.textTertiaryColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
