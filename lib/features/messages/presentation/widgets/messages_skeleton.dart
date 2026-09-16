import 'package:flutter/material.dart';
import 'package:diaspo_niger/l10n/app_localizations.dart';

import '../../../../core/theme/adaptive_colors.dart';
import '../../../../shared/widgets/shimmer_loading.dart';

/// Squelettes de chargement de la messagerie.
///
/// Ils remplacent les deux attentes de la messagerie : le tourniquet centré de
/// la liste des discussions, et l'écran **entièrement vide** du fil pendant la
/// première page de messages (`isLoadingInitial` renvoyait un
/// `SizedBox.shrink()`, donc rien du tout sous l'en-tête).
///
/// Chaque bloc reprend la géométrie de ce qui va s'afficher — avatar 50 au
/// rayon 17, filets entre les lignes, marges de bulle 16/64, rayons 18/6 —
/// pour que le contenu ne saute pas quand il arrive.
///
/// Un seul [ShimmerLoading] enveloppe chaque liste : les blocs sont de simples
/// conteneurs opaques, le balayage les traverse d'un bloc. Un
/// [ShimmerLoading] par ligne ferait tourner autant de contrôleurs
/// d'animation, chacun sur sa propre phase (même parti pris que
/// `PostCardSkeleton`).

/// Squelette de la liste des discussions (`MessagesScreen`).
///
/// Reprend les marges de la vraie liste — `ListView` en `fromLTRB(20, 0, 20,
/// …)`, intertitre de période, lignes « à plat » séparées d'un filet — pour
/// que la liste réelle se pose exactement là où le squelette l'annonçait.
class ConversationListSkeleton extends StatelessWidget {
  final int itemCount;

  const ConversationListSkeleton({super.key, this.itemCount = 9});

  /// Largeurs de nom et de dernier message, variées pour que la liste ne
  /// ressemble pas à un peigne. Fixes (et non tirées au hasard) : un rebuild
  /// ne doit pas faire changer les longueurs sous les yeux.
  static const _nameWidths = <double>[132, 96, 148, 112, 128, 88, 140];
  static const _previewFactors = <double>[0.62, 0.44, 0.78, 0.54, 0.70, 0.40, 0.66];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    final children = <Widget>[
      // Intertitre de période (« CETTE SEMAINE ») : mêmes marges que
      // `DesignSectionLabel`, et la hauteur de son libellé 10.5.
      Padding(
        padding: const EdgeInsets.fromLTRB(0, 18, 0, 10),
        // `Align` obligatoire, pas décoratif : un enfant direct de `ListView`
        // reçoit des contraintes de largeur **serrées**, qui écrasent le
        // `width:` du conteneur. Sans lui, l'intertitre s'étirait sur toute
        // la largeur au lieu des 96 demandés.
        child: Align(
          alignment: Alignment.centerLeft,
          child: _block(context, width: 96, height: 11, radius: 3),
        ),
      ),
    ];

    for (var i = 0; i < itemCount; i++) {
      if (i > 0) {
        children.add(
          Divider(height: 1, thickness: 1, color: context.dividerColor),
        );
      }
      children.add(
        _SkeletonConversationRow(
          nameWidth: _nameWidths[i % _nameWidths.length],
          previewFactor: _previewFactors[i % _previewFactors.length],
        ),
      );
    }

    // Le lecteur d'écran annonce « Chargement… » une fois, au lieu d'égrener
    // une vingtaine de rectangles sans nom.
    return Semantics(
      label: l10n.loading,
      container: true,
      child: ExcludeSemantics(
        child: ShimmerLoading(
          baseColor: _repos(context),
          highlightColor: _balayage(context),
          child: ListView(
            // Le squelette n'a rien à faire défiler, et le laisser rebondir
            // donnerait l'impression d'une liste déjà arrivée.
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              20,
              0,
              20,
              10 + MediaQuery.of(context).padding.bottom,
            ),
            children: children,
          ),
        ),
      ),
    );
  }
}

/// Une ligne de discussion : avatar 50 au rayon 17, nom, heure, aperçu —
/// la géométrie « à plat » de [ConversationItem] (`flat: true`).
class _SkeletonConversationRow extends StatelessWidget {
  final double nameWidth;
  final double previewFactor;

  const _SkeletonConversationRow({
    required this.nameWidth,
    required this.previewFactor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
      child: Row(
        children: [
          _block(context, width: 50, height: 50, radius: 17),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _block(context, width: nameWidth, height: 14),
                    const Spacer(),
                    // L'horodatage, calé à droite comme dans la vraie ligne.
                    _block(context, width: 34, height: 10),
                  ],
                ),
                const SizedBox(height: 10),
                FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: previewFactor,
                  child: _block(context, height: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Squelette du fil d'une discussion (`ConversationScreen`).
///
/// La liste réelle est `reverse: true` : le squelette l'est aussi, sinon les
/// bulles se collent en haut de l'écran et tout remonte d'un coup à
/// l'arrivée des messages.
class ConversationThreadSkeleton extends StatelessWidget {
  /// Un fil de groupe réserve une colonne d'avatar à gauche des messages
  /// reçus : sans elle, les bulles se décaleraient de 28 px vers la droite
  /// à l'arrivée des vrais messages — exactement le saut qu'un squelette
  /// existe pour éviter.
  final bool isGroup;

  const ConversationThreadSkeleton({super.key, this.isGroup = false});

  /// Bulles du plus récent au plus ancien (ordre de la liste inversée) :
  /// `(de moi ?, largeur relative, nombre de lignes)`. Assez nombreuses pour
  /// remplir un grand écran ; le surplus est simplement rogné en haut.
  static const _bubbles = <(bool, double, int)>[
    (true, 0.38, 1),
    (false, 0.55, 2),
    (true, 0.72, 3),
    (false, 0.42, 1),
    (true, 0.50, 1),
    (false, 0.64, 2),
    (true, 0.46, 1),
    (false, 0.58, 2),
    (true, 0.66, 2),
    (false, 0.36, 1),
    (true, 0.44, 1),
    (false, 0.70, 3),
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Semantics(
      label: l10n.loading,
      container: true,
      child: ExcludeSemantics(
        child: ShimmerLoading(
          baseColor: _repos(context),
          highlightColor: _balayage(context),
          child: ListView.builder(
            reverse: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.only(top: 16, bottom: 16),
            itemCount: _bubbles.length,
            itemBuilder: (context, index) {
              final (isMe, widthFactor, lines) = _bubbles[index];
              return _SkeletonBubble(
                isMe: isMe,
                isGroup: isGroup,
                widthFactor: widthFactor,
                lines: lines,
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Une bulle vide, aux marges et aux rayons de [MessageBubble] : 64 du côté
/// opposé à l'expéditeur, 16 du sien, et le coin bas de la queue rabattu à 6.
class _SkeletonBubble extends StatelessWidget {
  final bool isMe;
  final bool isGroup;
  final double widthFactor;
  final int lines;

  const _SkeletonBubble({
    required this.isMe,
    required this.isGroup,
    required this.widthFactor,
    required this.lines,
  });

  @override
  Widget build(BuildContext context) {
    // Padding interne de la bulle (10 en haut, 8 en bas) + une ligne de texte
    // à ~19, ce qui redonne la hauteur d'une bulle réelle d'autant de lignes.
    final height = 18.0 + lines * 19.0;

    // Reçu dans un groupe : `MessageBubble` descend à 8 à gauche et pose une
    // colonne d'avatar (rayon 14, puis 8 de gouttière) devant la bulle.
    final avecAvatar = isGroup && !isMe;

    final bulle = FractionallySizedBox(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      widthFactor: widthFactor,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: context.surfaceVariantColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isMe ? 18 : 6),
            bottomRight: Radius.circular(isMe ? 6 : 18),
          ),
        ),
      ),
    );

    return Padding(
      padding: EdgeInsets.only(
        left: isMe ? 64 : (avecAvatar ? 8 : 16),
        right: isMe ? 16 : 64,
        top: 4,
        bottom: 4,
      ),
      child:
          avecAvatar
              ? Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8, bottom: 2),
                    child: _block(context, width: 28, height: 28, radius: 14),
                  ),
                  Expanded(child: bulle),
                ],
              )
              : bulle,
    );
  }
}

/// Couleur au repos des blocs, et couleur du balayage qui les traverse.
///
/// Les défauts de [ShimmerLoading] (`surfaceContainerHighest` à 50 %
/// d'alpha, balayé vers `surface`) donnaient des blocs quasi invisibles sur
/// le fond crème `#FAF7F2` : le rendu ne se lisait pas comme une liste en
/// attente, mais comme un écran vide. On prend les deux jetons de la palette
/// qui encadrent ce fond, le plus sombre au repos, le plus clair en balayage
/// — et l'ordre s'inverse en sombre, où c'est `borderStrong` qui est le plus
/// clair des deux.
Color _repos(BuildContext context) =>
    context.isDarkMode ? context.surfaceVariantColor : context.borderStrongColor;

Color _balayage(BuildContext context) =>
    context.isDarkMode ? context.borderStrongColor : context.surfaceVariantColor;

/// Bloc plein du squelette. Opaque et sans animation propre : c'est le
/// [ShimmerLoading] du parent qui le traverse (`BlendMode.srcATop` ne peint
/// que les pixels déjà opaques).
Widget _block(
  BuildContext context, {
  double? width,
  required double height,
  double radius = 4,
}) {
  return Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      color: context.surfaceVariantColor,
      borderRadius: BorderRadius.circular(radius),
    ),
  );
}
