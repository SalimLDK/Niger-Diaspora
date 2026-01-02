import 'package:flutter/material.dart';

class StarRatingInput extends StatelessWidget {
  final int rating;
  final ValueChanged<int> onRatingChanged;
  final double size;
  final Color activeColor;
  final Color inactiveColor;
  final bool readOnly;

  const StarRatingInput({
    super.key,
    required this.rating,
    required this.onRatingChanged,
    this.size = 40,
    this.activeColor = Colors.amber,
    this.inactiveColor = Colors.grey,
    this.readOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        final starNumber = index + 1;
        return GestureDetector(
          onTap: readOnly ? null : () => onRatingChanged(starNumber),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Icon(
              starNumber <= rating ? Icons.star : Icons.star_border,
              size: size,
              color: starNumber <= rating ? activeColor : inactiveColor,
            ),
          ),
        );
      }),
    );
  }
}

/// Widget pour afficher une note en lecture seule (plus petit)
class StarRatingDisplay extends StatelessWidget {
  final double rating;
  final double size;
  final Color activeColor;
  final Color inactiveColor;
  final bool showValue;
  final int? reviewCount;

  const StarRatingDisplay({
    super.key,
    required this.rating,
    this.size = 18,
    this.activeColor = Colors.amber,
    this.inactiveColor = Colors.grey,
    this.showValue = true,
    this.reviewCount,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ...List.generate(5, (index) {
          final starNumber = index + 1;
          // Support demi-etoiles
          if (rating >= starNumber) {
            return Icon(Icons.star, size: size, color: activeColor);
          } else if (rating >= starNumber - 0.5) {
            return Icon(Icons.star_half, size: size, color: activeColor);
          } else {
            return Icon(Icons.star_border, size: size, color: inactiveColor);
          }
        }),
        if (showValue) ...[
          const SizedBox(width: 8),
          Text(
            rating.toStringAsFixed(1),
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          if (reviewCount != null) ...[
            Text(
              ' ($reviewCount)',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ],
        ],
      ],
    );
  }
}
