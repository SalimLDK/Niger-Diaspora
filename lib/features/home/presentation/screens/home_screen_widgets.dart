part of 'home_screen.dart';

// ── Refonte 8a : ligne de contexte, bloc « Aujourd'hui », grille services ────

const _homeLocation = Color(0xFF9F3E0A);
const _homeGreen = Color(0xFF0DB02B);
const _homeOrange = Color(0xFF9F3E0A);
const _homeBadgeRed = Color(0xFFC23E2D);

/// Date courte d'un événement (« 2 août »). Le mois vient d'`intl`, pas
/// d'une table française codée en dur : il suit la locale courante.
String _eventDateLabel(DateTime date, String locale) {
  return DateFormat('d MMM', locale).format(date);
}

/// Ligne « Paris, France · 318 membres · 12 groupes » qui remplace les trois
/// cartes de stats. La ville reste toujours lisible ; le reste s'ellipse.
class _ContextLine extends StatelessWidget {
  final String? city;
  final String? country;
  final int? members;
  final int? groups;

  const _ContextLine({this.city, this.country, this.members, this.groups});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final place = [
      city,
      country,
    ].where((e) => e != null && e.trim().isNotEmpty).join(', ');

    final parts = <String>[];
    if (members != null) {
      parts.add('${formatCount(members!)} ${l10n.membersLabel.toLowerCase()}');
    }
    if (groups != null) {
      parts.add('${formatCount(groups!)} ${l10n.groupsTitle.toLowerCase()}');
    }
    // La puce d'ouverture ne sert qu'à séparer du lieu : sans lieu, elle
    // s'affichait seule en tête (« · 0 membres · 0 groupes »), vu sur
    // appareil au premier lancement d'un compte sans ville.
    final compte = parts.join(' · ');
    final trailing =
        parts.isEmpty ? '' : (place.isEmpty ? compte : '· $compte');

    if (place.isEmpty && trailing.isEmpty) return const SizedBox.shrink();

    return Row(
      children: [
        const Icon(Icons.location_on, size: 15, color: _homeLocation),
        const SizedBox(width: 6),
        if (place.isNotEmpty)
          Text(
            place,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: context.textPrimaryColor,
            ),
          ),
        if (place.isNotEmpty && trailing.isNotEmpty) const SizedBox(width: 6),
        if (trailing.isNotEmpty)
          Expanded(
            child: Text(
              trailing,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13, color: context.textTertiaryColor),
            ),
          ),
      ],
    );
  }
}

/// Bloc « Aujourd'hui » : jusqu'à trois lignes actionnables (messages non lus,
/// prochain événement, membres proches). Masqué si aucune ligne ne s'applique.
class _TodayCard extends StatelessWidget {
  final int unread;
  final EventEntity? nextEvent;
  final int? nearbyCount;

  const _TodayCard({
    required this.unread,
    required this.nextEvent,
    required this.nearbyCount,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    final rows = <Widget>[];
    if (unread > 0) {
      rows.add(
        _TodayRow(
          bg: _homeGreen.withValues(alpha: 0.12),
          iconColor: _homeGreen,
          icon: Icons.chat_bubble_outline_rounded,
          title: l10n.messagesUnreadTitle,
          trailing: _CountBadge(count: unread, color: _homeBadgeRed),
          onTap: () => context.go('/messages'),
        ),
      );
    }
    if (nextEvent != null) {
      final e = nextEvent!;
      final date = _eventDateLabel(e.startDate, l10n.localeName);
      final subtitle = e.location.trim().isEmpty
          ? date
          : '$date · ${e.location}';
      rows.add(
        _TodayRow(
          bg: _homeOrange.withValues(alpha: 0.12),
          iconColor: _homeOrange,
          icon: Icons.event_rounded,
          title: e.title,
          subtitle: subtitle,
          trailing: _PillButton(
            label: l10n.participate,
            onTap: () => context.push('/events/${e.id}', extra: e),
          ),
          onTap: () => context.push('/events/${e.id}', extra: e),
        ),
      );
    }
    if (nearbyCount != null && nearbyCount! > 0) {
      rows.add(
        _TodayRow(
          bg: context.adaptivePrimaryColor.withValues(alpha: 0.10),
          iconColor: context.adaptivePrimaryColor,
          icon: Icons.people_alt_outlined,
          title: l10n.membersNearby,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _CountBadge(
                count: nearbyCount!,
                color: context.textTertiaryColor,
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: context.textTertiaryColor,
              ),
            ],
          ),
          onTap: () => context.go('/map'),
        ),
      );
    }

    if (rows.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.todayTitle.toUpperCase(),
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 10.5,
              letterSpacing: 1.05,
              fontWeight: FontWeight.w700,
              color: context.textTertiaryColor,
            ),
          ),
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) Divider(height: 1, color: context.borderColor),
            rows[i],
          ],
        ],
      ),
    );
  }
}

class _TodayRow extends StatelessWidget {
  final Color bg;
  final Color iconColor;
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback onTap;

  const _TodayRow({
    required this.bg,
    required this.iconColor,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon, size: 18, color: iconColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: context.textPrimaryColor,
                    ),
                  ),
                  if (subtitle != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: context.textSecondaryColor,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 8),
              trailing!,
            ],
          ],
        ),
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  final int count;
  final Color color;

  const _CountBadge({required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 22),
      height: 22,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 7),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(11),
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _PillButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _PillButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: _homeOrange,
          borderRadius: BorderRadius.circular(11),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

/// Grille des services (remplace le carrousel horizontal). Chaque tuile est
/// conditionnée par son feature flag ; le Fil est toujours présent. La grille
/// passe à 3 colonnes quand il y a peu de services (évite le vide à droite),
/// et reste à 4 dès qu'il y en a assez.
class _ServicesGrid extends ConsumerWidget {
  const _ServicesGrid();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final items = <_ServiceTile>[
      _ServiceTile(
        icon: Icons.dynamic_feed_rounded,
        label: l10n.homeServiceFeed,
        color: context.adaptivePrimaryColor,
        onTap: () => context.push('/feed'),
      ),
      if (ref.watch(isMoneyTransferEnabledProvider))
        _ServiceTile(
          icon: Icons.send_rounded,
          label: l10n.serviceTransfer,
          color: context.adaptivePrimaryColor,
          onTap: () => context.push('/transfers'),
        ),
      if (ref.watch(isMarketplaceEnabledProvider))
        _ServiceTile(
          icon: Icons.storefront_rounded,
          label: l10n.serviceMarketplace,
          color: context.adaptiveSecondaryColor,
          onTap: () => context.push('/marketplace'),
        ),
      // Annuaire et ambassades : toujours présents, comme le Fil (décision
      // produit 2026-08-19 — plus de flag).
      _ServiceTile(
        icon: Icons.business_rounded,
        label: l10n.homeDirectory,
        color: Theme.of(context).colorScheme.onPrimaryContainer,
        onTap: () => context.push('/businesses'),
      ),
      _ServiceTile(
        icon: Icons.account_balance,
        label: l10n.embassies,
        color: context.adaptiveSecondaryColor,
        onTap: () => context.push('/embassies'),
      ),
      // Salons audio et Podcasts n'avaient aucun point d'entrée dans l'app :
      // les écrans et les routes existaient, mais rien n'y menait — seuls des
      // liens internes à ces deux modules référençaient leurs routes.
      if (ref.watch(isAudioRoomsEnabledProvider))
        _ServiceTile(
          icon: Icons.podcasts_rounded,
          label: 'Salons',
          color: context.adaptivePrimaryColor,
          onTap: () => context.push('/audio-rooms'),
        ),
      if (ref.watch(isPodcastsEnabledProvider))
        _ServiceTile(
          icon: Icons.mic_rounded,
          label: l10n.podcasts,
          color: context.adaptiveSecondaryColor,
          onTap: () => context.push('/podcasts'),
        ),
    ];

    // 4 colonnes dès qu'il y a assez de tuiles, sinon 3 (peu de services).
    final columns = items.length >= 4 ? 4 : 3;
    const spacing = 12.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final tileWidth =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: 16,
          children: [
            for (final tile in items)
              SizedBox(width: tileWidth, child: tile),
          ],
        );
      },
    );
  }
}

class _ServiceTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ServiceTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Carte blanche carrée à bord léger (remplace la pastille teintée).
          // AspectRatio garantit un carré et une hauteur bornée (plus de vide
          // fantôme du GridView).
          AspectRatio(
            aspectRatio: 1,
            child: Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: context.surfaceColor,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: context.borderColor),
                boxShadow: context.isDarkMode
                    ? null
                    : [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
              ),
              child: Icon(icon, size: 32, color: color),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            maxLines: 1,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: context.textSecondaryColor,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Refonte accueil : section « Autour de vous » (avatars circulaires) ───────

/// État vide « position active, personne autour » (maquette 1b/CAS 1) : on
/// explique la cause, on rassure (position active), et on propose deux issues
/// (élargir le rayon, inviter un proche) plutôt qu'un libellé muet.
class _NearbyEmptyCard extends StatelessWidget {
  final double radiusKm;
  final String? city;
  final bool canWiden;
  final VoidCallback onWiden;
  final VoidCallback onInvite;

  const _NearbyEmptyCard({
    required this.radiusKm,
    required this.city,
    required this.canWiden,
    required this.onWiden,
    required this.onInvite,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final hasCity = city != null && city!.trim().isNotEmpty;
    final subtitle = hasCity
        ? "Aucun membre ne partage sa position autour de ${city!.trim()} pour l'instant."
        : "Aucun membre ne partage sa position autour de vous pour l'instant.";

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: context.surfaceVariantColor,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  Icons.people_alt_outlined,
                  size: 20,
                  color: context.textSecondaryColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.homeNobodyWithin(radiusKm.round()),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: context.textPrimaryColor,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.3,
                        color: context.textSecondaryColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Réassurance : la position de l'utilisateur est bien active.
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: context.successColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.check_circle_outline,
                    size: 18, color: context.successColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.homeLocationActiveNote,
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.3,
                      color: context.successColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              if (canWiden) ...[
                Expanded(
                  child: _HomeActionButton(
                    label: l10n.homeWidenRadius,
                    filled: true,
                    onTap: onWiden,
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: _HomeActionButton(
                  label: l10n.homeInviteRelative,
                  filled: false,
                  onTap: onInvite,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// État « position coupée » (maquette 1b/CAS 2) : rappelle la réciprocité du
/// partage, rassure sur la confidentialité, et propose d'activer la position.
class _NoPositionCard extends StatelessWidget {
  final VoidCallback onActivate;

  const _NoPositionCard({required this.onActivate});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _homeOrange.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(Icons.location_off_outlined,
                    size: 20, color: _homeOrange),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.homeNotOnMapTitle,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: context.textPrimaryColor,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      l10n.homeNotOnMapBody,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.3,
                        color: context.textSecondaryColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _CheckLine(text: 'Position approximative, jamais l\'adresse exacte'),
          const SizedBox(height: 8),
          _CheckLine(text: l10n.locationGuarantee2),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: _HomeActionButton(
              label: l10n.homeEnableLocation,
              filled: true,
              onTap: onActivate,
            ),
          ),
        ],
      ),
    );
  }
}

class _CheckLine extends StatelessWidget {
  final String text;
  const _CheckLine({required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.check_rounded, size: 16, color: context.successColor),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 12.5,
              height: 1.3,
              color: context.textSecondaryColor,
            ),
          ),
        ),
      ],
    );
  }
}

/// Bouton d'action des cartes d'état vide : plein (orange) ou contour.
class _HomeActionButton extends StatelessWidget {
  final String label;
  final bool filled;
  final VoidCallback onTap;

  const _HomeActionButton({
    required this.label,
    required this.filled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 44,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: filled ? _homeOrange : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: filled
              ? null
              : Border.all(color: context.borderStrongColor),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            color: filled ? Colors.white : context.textPrimaryColor,
          ),
        ),
      ),
    );
  }
}

/// Bandeau hors-ligne (maquette 2d) : explique que le contenu vient du cache
/// et propose de réessayer ou de continuer hors ligne. Rouge adouci (#F87171).
class _OfflineBanner extends StatelessWidget {
  final VoidCallback onRetry;
  final VoidCallback onDismiss;

  const _OfflineBanner({required this.onRetry, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    const softRed = Color(0xFFF87171);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: softRed.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(Icons.cloud_off_rounded,
                    size: 20, color: softRed),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.homeOfflineTitle,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: softRed,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      l10n.homeOfflineBody,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.3,
                        color: context.textSecondaryColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _HomeActionButton(
                  label: l10n.retry,
                  filled: true,
                  onTap: onRetry,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _HomeActionButton(
                  label: 'Lire hors ligne',
                  filled: false,
                  onTap: onDismiss,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Premier lancement (maquette 8a) : complétion de profil + onboarding ──────

/// Résultat du calcul de complétude du profil.
class _ProfileCompletion {
  final int filled;
  final int total;
  final String ctaLabel;
  final String message;

  const _ProfileCompletion({
    required this.filled,
    required this.total,
    required this.ctaLabel,
    required this.message,
  });
}

/// Carte « Complétez votre profil » : progression X/5, message contextuel et
/// action vers le champ manquant (maquette 8a).
class _ProfileCompletionCard extends StatelessWidget {
  final int filled;
  final int total;
  final String ctaLabel;
  final String message;
  final VoidCallback onTap;

  const _ProfileCompletionCard({
    required this.filled,
    required this.total,
    required this.ctaLabel,
    required this.message,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l10n.homeCompleteProfile,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: context.textPrimaryColor,
                ),
              ),
              Text(
                '$filled/$total',
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: _homeOrange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: total == 0 ? 0 : filled / total,
              minHeight: 6,
              backgroundColor: context.surfaceVariantColor,
              valueColor: const AlwaysStoppedAnimation<Color>(_homeOrange),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            message,
            style: TextStyle(
              fontSize: 13,
              height: 1.35,
              color: context.textSecondaryColor,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: _HomeActionButton(
              label: ctaLabel,
              filled: true,
              onTap: onTap,
            ),
          ),
        ],
      ),
    );
  }
}

/// Carte « Pour commencer » : raccourcis d'onboarding (retrouver ses proches,
/// rejoindre un groupe, activer la carte). Réutilise les lignes du bloc
/// « Aujourd'hui » (maquette 8a).
///
/// Chaque ligne est masquée dès que son action est réellement accomplie
/// (conversation individuelle démarrée, groupe rejoint, position active) —
/// pas seulement tant que le PROFIL est incomplet, sinon un utilisateur ayant
/// déjà rejoint 5 groupes se voyait quand même suggérer de le faire.
class _PourCommencerCard extends StatelessWidget {
  final bool hasConnection;
  final bool hasJoinedGroup;
  final bool hasActivatedMap;
  final int groupsCount;
  final VoidCallback onFindFriends;
  final VoidCallback onJoinGroup;
  final VoidCallback onActivateMap;

  const _PourCommencerCard({
    required this.hasConnection,
    required this.hasJoinedGroup,
    required this.hasActivatedMap,
    required this.groupsCount,
    required this.onFindFriends,
    required this.onJoinGroup,
    required this.onActivateMap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    Widget chevron() => Icon(
          Icons.chevron_right_rounded,
          size: 20,
          color: context.textTertiaryColor,
        );

    final groupSubtitle = groupsCount > 0
        ? l10n.homeGroupsToDiscover(groupsCount)
        : l10n.homeFindYourCommunity;

    final rows = <Widget>[
      if (!hasConnection)
        _TodayRow(
          bg: context.successColor.withValues(alpha: 0.12),
          iconColor: context.successColor,
          icon: Icons.person_add_alt_1_outlined,
          title: l10n.homeFindRelatives,
          subtitle: l10n.homeFindRelativesSub,
          trailing: chevron(),
          onTap: onFindFriends,
        ),
      if (!hasJoinedGroup)
        _TodayRow(
          bg: _homeOrange.withValues(alpha: 0.12),
          iconColor: _homeOrange,
          icon: Icons.groups_outlined,
          title: l10n.homeJoinGroup,
          subtitle: groupSubtitle,
          trailing: chevron(),
          onTap: onJoinGroup,
        ),
      if (!hasActivatedMap)
        _TodayRow(
          bg: context.adaptivePrimaryColor.withValues(alpha: 0.10),
          iconColor: context.adaptivePrimaryColor,
          icon: Icons.map_outlined,
          title: l10n.homeEnableMemberMap,
          subtitle: l10n.homeEnableMemberMapSub,
          trailing: chevron(),
          onTap: onActivateMap,
        ),
    ];

    if (rows.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.homeGettingStarted,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 10.5,
              letterSpacing: 1.05,
              fontWeight: FontWeight.w700,
              color: context.textTertiaryColor,
            ),
          ),
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) Divider(height: 1, color: context.borderColor),
            rows[i],
          ],
        ],
      ),
    );
  }
}

/// État vide des Événements « rien à venir » (maquette 1c/CAS 2) : invite à
/// lancer la première rencontre avec des raccourcis par catégorie.
class _EventsEmptyCard extends StatelessWidget {
  final String? city;
  const _EventsEmptyCard({required this.city});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final hasCity = city != null && city!.trim().isNotEmpty;
    final subtitle = hasCity
        ? l10n.homeFirstMeetupCity(city!.trim())
        : l10n.homeFirstMeetup;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 22, 16, 16),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.borderColor),
      ),
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _homeOrange.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.event_available_outlined,
                size: 26, color: _homeOrange),
          ),
          const SizedBox(height: 14),
          Text(
            l10n.homeStartFirstMeetup,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: context.textPrimaryColor,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              height: 1.35,
              color: context.textSecondaryColor,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              _EventChip(
                  label: l10n.eventCategorySocial,
                  category: EventCategory.social),
              _EventChip(
                  label: l10n.homeEventChipPaperwork,
                  category: EventCategory.educational),
              _EventChip(
                  label: l10n.eventCategorySport,
                  category: EventCategory.sports),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: _HomeActionButton(
              label: l10n.createEvent,
              filled: true,
              onTap: () => context.push('/events/create'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Puce-raccourci de création d'événement pré-catégorisé.
class _EventChip extends StatelessWidget {
  final String label;
  final EventCategory category;
  const _EventChip({required this.label, required this.category});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/events/create', extra: category),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: context.surfaceVariantColor,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: context.textSecondaryColor,
          ),
        ),
      ),
    );
  }
}

/// État « rien en présentiel, mais en ligne oui » (maquette 1c/CAS 1) : affiche
/// les événements en ligne accessibles + actions « Voir en ligne » / « Créer ».
class _EventsOnlineOnlyCard extends StatelessWidget {
  final List<EventEntity> events;
  final String? city;
  final String Function(EventEntity) subtitleOf;

  const _EventsOnlineOnlyCard({
    required this.events,
    required this.city,
    required this.subtitleOf,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final hasCity = city != null && city!.trim().isNotEmpty;
    final first = events.first;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: context.surfaceVariantColor,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(Icons.event_busy_outlined,
                    size: 20, color: context.textSecondaryColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasCity
                          ? l10n.homeNoEventInCity(city!.trim())
                          : l10n.homeNoInPersonEvent,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: context.textPrimaryColor,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      l10n.homeOnlineWorkshopNote,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.3,
                        color: context.textSecondaryColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (final e in events.take(2))
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: GestureDetector(
                onTap: () => context.push('/events/${e.id}', extra: e),
                child: HomeEventCard(
                  title: e.title,
                  date: e.startDate,
                  subtitle: subtitleOf(e),
                  isOnline: true,
                ),
              ),
            ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: _HomeActionButton(
                  // « Voir en ligne » pouvait se lire « consulter sur le
                  // web » : le libellé nomme les événements.
                  label: AppLocalizations.of(context)!.homeSeeOnlineEvents,
                  filled: false,
                  onTap: () =>
                      context.push('/events/${first.id}', extra: first),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _HomeActionButton(
                  label: AppLocalizations.of(context)!.homeCreateEvent,
                  filled: true,
                  onTap: () => context.push('/events/create'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// État « plus rien à venir, mais un passé » (maquette 1c/CAS 3) : rappelle le
/// dernier événement et propose de s'abonner au prochain.
class _EventsPastCard extends StatelessWidget {
  final EventEntity event;
  final String subtitle;

  const _EventsPastCard({
    required this.event,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final n = event.attendeeIds.length;
    final hasPhotos = event.recapPhotoUrls.isNotEmpty;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: context.surfaceVariantColor,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(Icons.history_rounded,
                    size: 20, color: context.textSecondaryColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.homeNothingPlanned,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: context.textPrimaryColor,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      n > 0
                          ? l10n.homeLastEventGathered(n)
                          : l10n.homeReviveCommunity,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.3,
                        color: context.textSecondaryColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () => context.push(
              hasPhotos ? '/events/${event.id}/recap' : '/events/${event.id}',
              extra: event,
            ),
            child: HomeEventCard(
              title: event.title,
              date: event.startDate,
              subtitle: subtitle,
              past: true,
              trailing: hasPhotos
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.photo_library_outlined,
                            size: 14, color: context.adaptivePrimaryColor),
                        const SizedBox(width: 4),
                        Text(
                          l10n.photos,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: context.adaptivePrimaryColor,
                          ),
                        ),
                      ],
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 6),
          Divider(height: 1, color: context.borderColor),
          const _NotifyNextToggle(),
        ],
      ),
    );
  }
}

/// Bascule « M'avertir du prochain ».
///
/// Elle (dés)abonnait à un topic FCM que **personne n'alimente** : ni les
/// Cloud Functions, ni send-push qui ne vise que des tokens. Et elle gardait
/// sa propre copie `bool` dans les SharedPreferences, une quatrième source
/// pour un réglage qui en avait déjà trop.
///
/// Elle délègue désormais au propriétaire du réglage,
/// `NotificationPreferencesNotifier.setLocalEventsEnabled`, qui écrit la
/// préférence locale **et** la colonne serveur `users.notify_local_events`.
/// C'est cette colonne que lit `users_near_point`, donc le RPC qui choisit les
/// destinataires de `notifyLocalEventCreated` : la bascule commande enfin
/// quelque chose.
///
/// Aucun champ `bool` local ici : l'état vient du provider (cf. `CLAUDE.md`).
class _NotifyNextToggle extends ConsumerWidget {
  const _NotifyNextToggle();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final enabled = ref.watch(
      notificationPreferencesNotifierProvider.select((p) => p.localEventsEnabled),
    );
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          Icon(Icons.notifications_active_outlined,
              size: 18, color: context.textSecondaryColor),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              l10n.homeNotifyNext,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: context.textPrimaryColor,
              ),
            ),
          ),
          Switch.adaptive(
            value: enabled,
            onChanged: (v) => ref
                .read(notificationPreferencesNotifierProvider.notifier)
                .setLocalEventsEnabled(v),
            activeThumbColor: _homeGreen,
          ),
        ],
      ),
    );
  }
}

/// Palette d'avatars (orange, vert, sarcelle, brique, violet) alignée sur la
/// maquette. La couleur est stable pour un même profil via son id.
const _avatarPalette = <Color>[
  Color(0xFF9F3E0A), // orange
  Color(0xFF0DB02B), // vert
  Color(0xFF2A7F7B), // sarcelle
  Color(0xFFC23E2D), // brique
  Color(0xFF7A5AA8), // violet
];

Color _avatarColor(String seed) =>
    _avatarPalette[seed.hashCode.abs() % _avatarPalette.length];

String _avatarInitials(String name) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) return '?';
  final parts = trimmed.split(RegExp(r'\s+'));
  if (parts.length >= 2 && parts[0].isNotEmpty && parts[1].isNotEmpty) {
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }
  return trimmed[0].toUpperCase();
}

/// Avatar circulaire d'un membre proche : cercle coloré (photo ou initiales),
/// prénom, puis distance formatée.
class _NearbyAvatar extends StatelessWidget {
  final String name;
  final String? photoUrl;
  final String? distance;
  final Color color;
  final VoidCallback onTap;

  const _NearbyAvatar({
    required this.name,
    required this.photoUrl,
    required this.distance,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 68,
        child: Column(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              clipBehavior: Clip.antiAlias,
              alignment: Alignment.center,
              child: photoUrl != null
                  ? CachedNetworkImage(
                      imageUrl: photoUrl!,
                      fit: BoxFit.cover,
                      width: 60,
                      height: 60,
                      placeholder: (_, __) => _initials(),
                      errorWidget: (_, __, ___) => _initials(),
                    )
                  : _initials(),
            ),
            const SizedBox(height: 8),
            Text(
              name.split(' ').first,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.2,
                fontWeight: FontWeight.w600,
                color: context.textPrimaryColor,
              ),
            ),
            if (distance != null)
              Text(
                distance!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  height: 1.2,
                  color: context.textTertiaryColor,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _initials() => Text(
        _avatarInitials(name),
        style: const TextStyle(
          color: AppColors.white,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      );
}

/// Pastille finale « +N / Voir tout » de la rangée d'avatars.
class _SeeAllAvatar extends StatelessWidget {
  final int count;
  final String label;
  final VoidCallback onTap;

  const _SeeAllAvatar({
    required this.count,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 68,
        child: Column(
          children: [
            Container(
              width: 60,
              height: 60,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: context.surfaceVariantColor,
                shape: BoxShape.circle,
              ),
              child: Text(
                '+$count',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: context.textSecondaryColor,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: context.textSecondaryColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Placeholder de chargement d'un avatar proche.
/// Rangée de squelettes affichée pendant la recherche des membres proches
/// (maquette 1b/CAS 3 : « jamais de texte vide avant la fin du chargement »).
///
/// Sert aussi bien au premier chargement qu'à une recherche demandée
/// explicitement, comme l'élargissement du rayon à 200 km.
class NearbyLoadingRow extends StatelessWidget {
  const NearbyLoadingRow({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 120,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: 4,
        separatorBuilder: (_, __) => const SizedBox(width: 16),
        itemBuilder: (_, __) => const _NearbyAvatarLoading(),
      ),
    );
  }
}

class _NearbyAvatarLoading extends StatelessWidget {
  const _NearbyAvatarLoading();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 68,
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: context.surfaceVariantColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(height: 8),
          // Barre « prénom ».
          Container(
            width: 48,
            height: 10,
            decoration: BoxDecoration(
              color: context.surfaceVariantColor,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 5),
          // Barre « distance » (plus courte).
          Container(
            width: 30,
            height: 9,
            decoration: BoxDecoration(
              color: context.surfaceVariantColor.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ],
      ),
    );
  }
}
