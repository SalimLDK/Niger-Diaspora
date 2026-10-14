part of 'messages_screen.dart';

// Petits widgets privés de la liste : suggestions, avatars, résultats.

/// Marqueur interne pour la tuile « Mes notes » dans la liste d'entrées.
const String _kSelfNotesMarker = '__self_notes__';

/// Les deux amorces de la fiche 9e — « écrivez à un membre proche » et
/// « rejoignez un groupe de votre ville » — rendues à partir de données
/// réelles, et masquées sans bruit quand ces données n'existent pas.
class _EmptyStateSuggestions extends ConsumerWidget {
  const _EmptyStateSuggestions();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final rows = <Widget>[];

    // Membre proche : on lit l'état déjà chargé (l'accueil le remplit quand
    // la localisation est accordée) sans déclencher de nouvelle demande de
    // permission depuis la messagerie.
    final nearby =
        ref.watch(nearbyProfilesNotifierProvider).valueOrNull ?? const [];
    final me = ref.watch(currentUserProvider).valueOrNull?.id;
    final candidate =
        nearby.where((p) => p.id != me && (p.displayName ?? '').isNotEmpty);
    if (candidate.isNotEmpty) {
      final profile = candidate.first;
      final city = profile.currentCity?.trim();
      rows.add(
        _SuggestionRow(
          leading: _InitialAvatar(name: profile.displayName!),
          title: profile.displayName!,
          subtitle:
              profile.isOnline
                  ? l10n.online
                  : (city != null && city.isNotEmpty ? city : 'À proximité'),
          trailing: Icons.send_rounded,
          // La flèche d'envoi promet d'écrire à cette personne-là : la route
          // ouvre maintenant la discussion, au lieu du sélecteur générique.
          onTap:
              () => context.push(
                '/messages/new?userId=${profile.id}',
                extra: {
                  'recipientName': profile.displayName,
                  'recipientPhotoUrl': profile.photoUrl,
                },
              ),
        ),
      );
    }

    // Groupe de la ville : la ville vient du profil, pas d'une géolocalisation.
    final myCity =
        me == null
            ? null
            : ref
                .watch(profileNotifierProvider(me))
                .valueOrNull
                ?.currentCity
                ?.trim();
    final groups = ref.watch(groupsNotifierProvider).valueOrNull ?? const [];
    final cityGroups =
        (myCity != null && myCity.isNotEmpty)
            ? groups.where(
              (g) =>
                  !g.isPrivate &&
                  ((g.location ?? '').toLowerCase().contains(
                        myCity.toLowerCase(),
                      ) ||
                      (g.country ?? '').toLowerCase().contains(
                        myCity.toLowerCase(),
                      )),
            )
            : const Iterable.empty();
    // Sans ville renseignée, on ne bascule pas sur « un groupe au hasard » :
    // la fiche promet un groupe *de votre ville*.
    if (cityGroups.isNotEmpty) {
      final group = cityGroups.first;
      rows.add(
        _SuggestionRow(
          leading: _GroupBadge(color: context.successColor),
          title: group.name,
          subtitle:
              '${group.memberCount} membres · ${group.isPrivate ? 'privé' : 'public'}',
          trailing: Icons.chevron_right_rounded,
          onTap: () => context.push('/groups/${group.id}'),
        ),
      );
    }

    if (rows.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const SizedBox(height: 8),
            rows[i],
          ],
        ],
      ),
    );
  }
}

class _SuggestionRow extends StatelessWidget {
  final Widget leading;
  final String title;
  final String subtitle;
  final IconData trailing;
  final VoidCallback onTap;

  const _SuggestionRow({
    required this.leading,
    required this.title,
    required this.subtitle,
    required this.trailing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.surfaceColor,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: context.borderColor),
          ),
          child: Row(
            children: [
              leading,
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: context.textPrimaryColor,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: context.textSecondaryColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(trailing, size: 19, color: context.adaptivePrimaryColor),
            ],
          ),
        ),
      ),
    );
  }
}

class _InitialAvatar extends StatelessWidget {
  final String name;

  const _InitialAvatar({required this.name});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: context.adaptivePrimaryColor,
      ),
      alignment: Alignment.center,
      child: Text(
        name.trim()[0].toUpperCase(),
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: context.onPrimaryColor,
        ),
      ),
    );
  }
}

class _GroupBadge extends StatelessWidget {
  final Color color;

  const _GroupBadge({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      alignment: Alignment.center,
      child: const AppIcon(AppIcon.groups, size: 18, color: Colors.white),
    );
  }
}

/// Personne trouvée par la recherche (fiche 9b) : avatar rond 56 et prénom.
class _PersonResult extends StatelessWidget {
  final String name;
  final String? photoUrl;
  final VoidCallback onTap;

  const _PersonResult({
    required this.name,
    required this.photoUrl,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final firstName = name.split(' ').first;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: 64,
        child: Column(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: context.adaptivePrimaryColor,
              ),
              clipBehavior: Clip.antiAlias,
              alignment: Alignment.center,
              child:
                  (photoUrl != null && photoUrl!.isNotEmpty)
                      ? Image.network(
                        photoUrl!,
                        fit: BoxFit.cover,
                        width: 56,
                        height: 56,
                        errorBuilder: (_, __, ___) => _initial(context),
                      )
                      : _initial(context),
            ),
            const SizedBox(height: 6),
            Text(
              firstName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: context.textPrimaryColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _initial(BuildContext context) => Text(
    name[0].toUpperCase(),
    style: TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w700,
      color: context.onPrimaryColor,
    ),
  );
}
