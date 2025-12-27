import 'package:flutter/material.dart';
import '../../../../core/theme/adaptive_colors.dart';

class HomeEmptyStateCard extends StatelessWidget {
  final IconData icon;
  final String message;
  final String? subtitle;

  const HomeEmptyStateCard({
    super.key,
    required this.icon,
    required this.message,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      decoration: context.cardDecoration,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.surfaceVariantColor,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, size: 32, color: context.textTertiaryColor),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: context.textSecondaryColor,
            ),
            textAlign: TextAlign.center,
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(
              subtitle!,
              style: TextStyle(fontSize: 13, color: context.textTertiaryColor),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}
