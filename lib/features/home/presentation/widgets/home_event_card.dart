import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/adaptive_colors.dart';

class HomeEventCard extends StatelessWidget {
  final String title;

  /// Date de début : sert à afficher le pavé jour + mois (refonte accueil).
  final DateTime date;

  /// Ligne de contexte « Paris 18e · 14 h · 62 participants ».
  final String subtitle;

  /// Événement en ligne : ajoute un badge « EN LIGNE » (maquette 1c/CAS 1).
  final bool isOnline;

  /// Événement passé : pavé date grisé et titre atténué (maquette 1c/CAS 3).
  final bool past;

  /// Widget de fin personnalisé (ex. « Photos ») ; sinon un chevron.
  final Widget? trailing;

  const HomeEventCard({
    super.key,
    required this.title,
    required this.date,
    required this.subtitle,
    this.isOnline = false,
    this.past = false,
    this.trailing,
  });

  static const _months = [
    'JAN',
    'FÉV',
    'MAR',
    'AVR',
    'MAI',
    'JUIN',
    'JUIL',
    'AOÛT',
    'SEP',
    'OCT',
    'NOV',
    'DÉC',
  ];

  @override
  Widget build(BuildContext context) {
    // Passé : pavé date grisé ; sinon accent primaire.
    final Color boxText =
        past ? context.textTertiaryColor : context.adaptivePrimaryColor;
    final Color boxBg = past
        ? context.surfaceVariantColor
        : (context.isDarkMode
            ? context.adaptivePrimaryColor.withValues(alpha: 0.16)
            : AppColors.primaryLighter);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: context.cardDecoration,
      child: Row(
        children: [
          // Pavé date : « 02 / AOÛT ».
          Container(
            width: 56,
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: boxBg,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  date.day.toString().padLeft(2, '0'),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    height: 1,
                    color: boxText,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _months[date.month - 1],
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: boxText,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: past
                              ? context.textSecondaryColor
                              : context.textPrimaryColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isOnline) ...[
                      const SizedBox(width: 8),
                      const _OnlineBadge(),
                    ],
                  ],
                ),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: context.textSecondaryColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          trailing ??
              Icon(
                Icons.chevron_right_rounded,
                size: 22,
                color: context.textTertiaryColor,
              ),
        ],
      ),
    );
  }
}

/// Petit badge « EN LIGNE » (bleu) pour les événements en ligne.
class _OnlineBadge extends StatelessWidget {
  const _OnlineBadge();

  @override
  Widget build(BuildContext context) {
    final color = context.infoColor;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        'EN LIGNE',
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
          color: color,
        ),
      ),
    );
  }
}

class HomeEventCardLoading extends StatelessWidget {
  const HomeEventCardLoading({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: context.cardDecoration,
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: context.surfaceVariantColor,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  height: 14,
                  decoration: BoxDecoration(
                    color: context.surfaceVariantColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: 120,
                  height: 10,
                  decoration: BoxDecoration(
                    color: context.surfaceVariantColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
