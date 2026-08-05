import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../domain/entities/embassy_entity.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:diaspo_niger/l10n/app_localizations.dart';

class EmbassyListItem extends StatelessWidget {
  final EmbassyEntity embassy;

  const EmbassyListItem({super.key, required this.embassy});

  Future<void> _makePhoneCall(String phoneNumber) async {
    final uri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _openMap(double? lat, double? lng) async {
    if (lat == null || lng == null) return;
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: () => context.push('/embassies/${embassy.id}', extra: embassy),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Embassy Image/Icon
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer.withValues(
                        alpha: 0.3,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child:
                        embassy.imageUrl != null
                            ? ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: CachedNetworkImage(
                                imageUrl: embassy.imageUrl!,
                                fit: BoxFit.cover,
                                placeholder:
                                    (context, url) => Center(
                                      child: SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: theme.colorScheme.primary,
                                        ),
                                      ),
                                    ),
                                errorWidget:
                                    (context, url, error) => Icon(
                                      Icons.account_balance,
                                      color: theme.colorScheme.primary,
                                      size: 28,
                                    ),
                              ),
                            )
                            : Icon(
                              Icons.account_balance,
                              color: theme.colorScheme.primary,
                              size: 28,
                            ),
                  ),
                  const SizedBox(width: 12),

                  // Embassy Details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                embassy.name,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: theme.colorScheme.onSurface,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            // État « temporairement fermé » (§17a/13b) : on
                            // n'affiche que l'exception, pas de calcul
                            // « ouvert maintenant » (format horaires non
                            // garanti côté back, cf. embassy_detail_screen).
                            if (embassy.isTemporarilyClosed)
                              Container(
                                margin: const EdgeInsets.only(left: 6),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFFC23E2D,
                                  ).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  l10n.closedStatus,
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFFC23E2D),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.location_on_outlined,
                              size: 14,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                '${embassy.city}, ${embassy.country}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Chevron
                  Icon(
                    Icons.chevron_right,
                    color: theme.colorScheme.onSurfaceVariant,
                    size: 20,
                  ),
                ],
              ),

              // Quick Actions
              if (embassy.phone != null || embassy.latitude != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Row(
                    children: [
                      if (embassy.phone != null) ...[
                        Expanded(
                          child: _QuickActionButton(
                            icon: Icons.phone_outlined,
                            label: l10n.callAction,
                            onPressed: () => _makePhoneCall(embassy.phone!),
                            theme: theme,
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      if (embassy.latitude != null &&
                          embassy.longitude != null) ...[
                        Expanded(
                          child: _QuickActionButton(
                            icon: Icons.directions_outlined,
                            label: l10n.itinerary,
                            onPressed:
                                () => _openMap(
                                  embassy.latitude,
                                  embassy.longitude,
                                ),
                            theme: theme,
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Expanded(
                        child: _QuickActionButton(
                          icon: Icons.info_outline,
                          label: l10n.embassyDetails,
                          onPressed:
                              () => context.push(
                                '/embassies/${embassy.id}',
                                extra: embassy,
                              ),
                          theme: theme,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final ThemeData theme;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: theme.colorScheme.onSecondaryContainer),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSecondaryContainer,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
