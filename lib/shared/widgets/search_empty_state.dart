import 'package:flutter/material.dart';

import '../../core/theme/adaptive_colors.dart';
import '../../l10n/app_localizations.dart';

/// État « aucun résultat » partagé par les écrans de recherche.
///
/// Les écrans affichaient jusqu'ici une icône barrée et la requête, sans dire
/// quoi faire ensuite. Ce widget ajoute les pistes de reformulation et une
/// sortie concrète (créer le contenu manquant, élargir la recherche).
class SearchEmptyState extends StatelessWidget {
  /// Requête saisie, réaffichée telle quelle.
  final String query;

  /// Action principale proposée quand la recherche ne donne rien
  /// (« Créer un groupe », « Vendre un article »…).
  final String? primaryActionLabel;
  final VoidCallback? onPrimaryAction;

  /// Proposé seulement si des filtres sont réellement actifs.
  final VoidCallback? onClearFilters;

  const SearchEmptyState({
    super.key,
    required this.query,
    this.primaryActionLabel,
    this.onPrimaryAction,
    this.onClearFilters,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 64,
            color: context.textTertiaryColor.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 16),
          Text(
            l10n.searchNoResultsFor(query),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: context.textPrimaryColor,
            ),
          ),
          const SizedBox(height: 24),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              l10n.searchTipsTitle,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
                color: context.textTertiaryColor,
              ),
            ),
          ),
          const SizedBox(height: 8),
          _Tip(text: l10n.searchTipSpelling),
          _Tip(text: l10n.searchTipFewerWords),
          if (onClearFilters != null) _Tip(text: l10n.searchTipRemoveFilters),
          const SizedBox(height: 24),
          if (onPrimaryAction != null && primaryActionLabel != null)
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: onPrimaryAction,
                child: Text(primaryActionLabel!),
              ),
            ),
          if (onClearFilters != null) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: onClearFilters,
                child: Text(l10n.searchClearFilters),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Tip extends StatelessWidget {
  final String text;

  const _Tip({required this.text});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('· ', style: TextStyle(color: context.textTertiaryColor)),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 13,
                  color: context.textSecondaryColor,
                ),
              ),
            ),
          ],
        ),
      );
}
