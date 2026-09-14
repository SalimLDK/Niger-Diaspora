import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/adaptive_colors.dart';
import '../../../polls/presentation/providers/poll_provider.dart';
import '../../../polls/presentation/widgets/poll_card.dart';
import 'package:diaspo_niger/l10n/app_localizations.dart';

/// Bulle « sondage » d'une conversation.
///
/// Le message ne transporte que `pollId` : la question, les options et les
/// compteurs sont relus depuis `post_polls` a chaque affichage. Voter ne
/// reecrit donc jamais le message — c'est la carte qui se met a jour.
///
/// **Pourquoi pas `SharedCardPalette`.** Les deux autres cartes posees dans
/// une bulle (post partage, evenement) prennent sur une bulle envoyee un
/// voile sombre translucide, texte blanc. Le sondage garde deliberement un
/// fond opaque : ce n'est pas un apercu qu'on lit, c'est une **surface de
/// controle** — rangees cochables, barres de remplissage, pourcentages,
/// accent violet. Ces elements poses a 12 % d'opacite sur le vert `#009600`
/// d'une bulle envoyee donneraient exactement le defaut de contraste que la
/// palette partagee a ete ecrite pour corriger. Le fond neutre est verifie
/// lisible sur SM A515F, en clair et en sombre (2026-09-14).
///
/// Ce que la carte emprunte quand meme a la bulle : ses **rayons**. Sans eux
/// son coin arrondi a 16 laissait voir le vert dans le coin de queue de la
/// bulle, arrondi a 6.
class PollMessageBubble extends ConsumerWidget {
  final String pollId;

  /// Question au moment de l'envoi : sert de repli tant que le sondage
  /// n'est pas charge, pour ne pas afficher une bulle vide.
  final String fallbackQuestion;

  final String? groupId;

  /// Rayons de la bulle qui porte la carte, pour qu'elle epouse son coin de
  /// queue. Null hors d'une bulle (le fil, par exemple).
  final BorderRadiusGeometry? borderRadius;

  const PollMessageBubble({
    super.key,
    required this.pollId,
    required this.fallbackQuestion,
    this.groupId,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final pollAsync = ref.watch(pollStreamProvider(pollId));

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 320),
      child: pollAsync.when(
        data: (poll) => poll == null
            ? _placeholder(context, l10n.pollDeleted)
            : PollCard(
                poll: poll,
                groupId: groupId,
                borderRadius: borderRadius,
              ),
        loading: () => _placeholder(context, fallbackQuestion),
        error: (_, __) => _placeholder(context, fallbackQuestion),
      ),
    );
  }

  Widget _placeholder(BuildContext context, String text) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: borderRadius == null
          ? context.cardDecoration
          : context.cardDecoration.copyWith(borderRadius: borderRadius),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: context.textSecondaryColor,
        ),
      ),
    );
  }
}
