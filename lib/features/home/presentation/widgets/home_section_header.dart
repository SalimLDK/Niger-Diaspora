import 'package:flutter/material.dart';
import '../../../../core/theme/adaptive_colors.dart';

class HomeSectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback onSeeAll;
  final String seeAllText;

  const HomeSectionHeader({
    super.key,
    required this.title,
    required this.onSeeAll,
    required this.seeAllText,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: context.textPrimaryColor,
          ),
        ),
        GestureDetector(
          onTap: onSeeAll,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: context.primaryBackgroundColor,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  seeAllText,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: context.adaptivePrimaryColor,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 12,
                  color: context.adaptivePrimaryColor,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
