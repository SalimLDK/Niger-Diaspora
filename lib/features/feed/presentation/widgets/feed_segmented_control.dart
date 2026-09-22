import 'package:flutter/material.dart';

import '../theme/feed_tokens.dart';

class FeedSegment<T> {
  final T value;

  /// Builds the segment's leading icon for the given (state-dependent) color.
  final Widget Function(Color color) icon;
  final String label;

  const FeedSegment({
    required this.value,
    required this.icon,
    required this.label,
  });
}

/// Pill segmented control matching the mockups' `.seg`/`.seg-opt`: an
/// outlined rounded container whose active segment is either outlined
/// (Nocturne) or filled (Organic), per `tokens.segmentActive*`.
class FeedSegmentedControl<T> extends StatelessWidget {
  final List<FeedSegment<T>> segments;
  final T selected;
  final ValueChanged<T> onChanged;
  final FeedTokens tokens;

  /// Segments de largeur égale occupant toute la largeur disponible
  /// (refonte tour 4 : `Expanded` au lieu d'un groupe compact à gauche).
  final bool fullWidth;

  const FeedSegmentedControl({
    super.key,
    required this.segments,
    required this.selected,
    required this.onChanged,
    required this.tokens,
    this.fullWidth = false,
  });

  /// À trois segments ou plus, l'icône est sacrifiée au profit du libellé.
  /// Sur un écran de 360 dp, « Abonnements » se tronquait en « Abonnem… » :
  /// icône (16) + écart (6) + les marges laissaient 62 dp au texte, qui en
  /// demande ~75. Sans l'icône il en reste 84, et le mot tient en entier.
  /// Un onglet illisible coûte plus cher qu'un pictogramme absent.
  bool get _showIcons => segments.length < 3;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(tokens.radiusMd),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: tokens.divider),
          borderRadius: BorderRadius.circular(tokens.radiusMd),
        ),
        child: Row(
          mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
          children: [
            for (var i = 0; i < segments.length; i++) ...[
              if (i > 0) Container(width: 1, height: 32, color: tokens.divider),
              if (fullWidth)
                Expanded(
                  child: _SegmentOption<T>(
                    segment: segments[i],
                    isActive: segments[i].value == selected,
                    tokens: tokens,
                    fill: true,
                    showIcon: _showIcons,
                    onTap: () => onChanged(segments[i].value),
                  ),
                )
              else
                _SegmentOption<T>(
                  segment: segments[i],
                  isActive: segments[i].value == selected,
                  tokens: tokens,
                  showIcon: _showIcons,
                  onTap: () => onChanged(segments[i].value),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Réduction à appliquer pour qu'un libellé de largeur [naturelle] tienne
/// dans [disponible] : `1` s'il tient tel quel, un facteur entre [minimum] et
/// 1 s'il tient une fois réduit, `null` s'il ne tiendrait qu'illisible — la
/// troncature reprend alors la main.
@visibleForTesting
double? reductionPourTenir(
  double naturelle,
  double disponible, {
  double minimum = 0.8,
}) {
  if (naturelle <= disponible) return 1;
  if (naturelle <= 0 || disponible <= 0) return null;
  final facteur = disponible / naturelle;
  return facteur >= minimum ? facteur : null;
}

/// Le libellé d'un segment : **réduit** pour tenir plutôt que tronqué.
///
/// Le plafond d'échelle à 1,15 ne suffisait pas. Vu sur Pixel 10 Pro XL le
/// 2026-09-22 (police 1,3 **et texte en gras**, build Play 1.2.2+26) :
/// l'onglet s'affichait encore « Abonneme… ». Le gras d'accessibilité
/// d'Android (`MediaQuery.boldTextOf`) élargit chaque lettre et échappe au
/// plafond, qui ne borne que la taille. Trois onglets de même largeur ne
/// laissaient plus assez de place au mot.
///
/// Désormais le libellé est mesuré tel qu'il sera dessiné — gras compris —
/// et réduit jusqu'à 80 % s'il le faut. Au-delà, il serait illisible : on
/// garde alors les points de suspension.
class _LibelleAjuste extends StatelessWidget {
  const _LibelleAjuste({required this.texte, required this.style});

  final String texte;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final gras = MediaQuery.boldTextOf(context);
    final dessine = gras
        ? style.merge(const TextStyle(fontWeight: FontWeight.bold))
        : style;
    final tronque = Text(
      texte,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: style,
    );
    return LayoutBuilder(
      builder: (context, contraintes) {
        if (!contraintes.hasBoundedWidth) return tronque;
        final mesure = TextPainter(
          text: TextSpan(text: texte, style: dessine),
          maxLines: 1,
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
        )..layout();
        final reduction = reductionPourTenir(mesure.width, contraintes.maxWidth);
        mesure.dispose();
        if (reduction == null || reduction == 1) return tronque;
        return FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(texte, maxLines: 1, style: style),
        );
      },
    );
  }
}

class _SegmentOption<T> extends StatelessWidget {
  final FeedSegment<T> segment;
  final bool isActive;
  final FeedTokens tokens;
  final VoidCallback onTap;

  /// Occupe toute la largeur du segment (mode `fullWidth` : contenu centré).
  final bool fill;

  /// Affiche le pictogramme de tête. Faux dès trois segments : le libellé
  /// passe avant (voir `FeedSegmentedControl._showIcons`).
  final bool showIcon;

  const _SegmentOption({
    required this.segment,
    required this.isActive,
    required this.tokens,
    required this.showIcon,
    required this.onTap,
    this.fill = false,
  });

  @override
  Widget build(BuildContext context) {
    final fg = isActive ? tokens.segmentActiveFg : tokens.mutedText;
    return InkWell(
      onTap: onTap,
      child: Container(
        width: fill ? double.infinity : null,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? tokens.segmentActiveBg : Colors.transparent,
          border:
              isActive && tokens.segmentActiveBorder != null
                  // 1.5 px : la fiche 6a décrit l'onglet actif du fil nocturne
                  // comme « un contour 1.5px » — à 1 px il se confondait avec
                  // le filet du conteneur.
                  ? Border.all(color: tokens.segmentActiveBorder!, width: 1.5)
                  : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment:
              fill ? MainAxisAlignment.center : MainAxisAlignment.start,
          children: [
            if (showIcon) ...[
              SizedBox(width: 16, height: 16, child: segment.icon(fg)),
              const SizedBox(width: 6),
            ],
            // Souple et tronquable : un libellé un peu long (« Abonnements »)
            // débordait du segment, avec le bandeau jaune et noir par-dessus.
            // Le `Row` est en `MainAxisSize.min`, donc rien ne le contraignait.
            Flexible(
              // Échelle de police bornée à 1,15 pour ce seul libellé :
              // à font_scale 1.3 (Pixel), « Abonnements » se tronquait en
              // « Abonnem… » alors que le reste de l'écran grandit normalement.
              child: MediaQuery.withClampedTextScaling(
                maxScaleFactor: 1.15,
                child: _LibelleAjuste(
                  texte: segment.label,
                  style: TextStyle(
                    fontSize: 13,
                    color: fg,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
