import 'dart:async';
import 'dart:io';

import 'package:emoji_picker_flutter/emoji_picker_flutter.dart' as emoji_picker;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/adaptive_colors.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/sheet_handle.dart';

/// Les cinq réactions rapides, dans l'ordre d'affichage.
///
/// Une seule liste pour la feuille d'actions (appui long) et la barre du
/// double tap : il y en avait deux, qui ne proposaient ni les mêmes emojis ni
/// le même ordre, et le double tap posait d'office un cœur.
const List<String> kQuickReactions = [
  '\u{1F44D}', // 👍
  '\u{2764}\u{FE0F}', // ❤️
  '\u{1F602}', // 😂
  '\u{1F64F}', // 🙏
  '\u{1F62E}', // 😮
];

/// Rangée « cinq réactions + » : la même brique dans la feuille d'actions et
/// dans la barre flottante du double tap.
class QuickReactionRow extends StatelessWidget {
  /// Réaction déjà posée par l'utilisateur courant, mise en avant.
  final String? selected;
  final ValueChanged<String> onPick;

  /// Le « + » : ouvre le sélecteur complet.
  final VoidCallback onMore;

  /// `true` dans la barre flottante (largeur au plus juste), `false` dans la
  /// feuille (répartie sur toute la largeur).
  final bool compact;

  const QuickReactionRow({
    super.key,
    required this.onPick,
    required this.onMore,
    this.selected,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final boutons = <Widget>[
      for (final emoji in kQuickReactions)
        _QuickReactionButton(
          emoji: emoji,
          selected: emoji == selected,
          onTap: () => onPick(emoji),
        ),
      _QuickReactionButton(
        icon: Icons.add,
        tooltip: AppLocalizations.of(context)!.moreReactions,
        // Une réaction posée hors des cinq reste visible : c'est le « + »
        // qui la porte.
        selected: selected != null && !kQuickReactions.contains(selected),
        onTap: onMore,
      ),
    ];

    if (!compact) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: boutons,
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < boutons.length; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          boutons[i],
        ],
      ],
    );
  }
}

/// Barre de réactions posée au-dessus de la bulle touchée (double tap).
///
/// Renvoie l'emoji choisi — l'un des cinq, ou n'importe lequel du sélecteur
/// complet ouvert par le « + » — ou `null` si on la ferme sans choisir.
Future<String?> showReactionBar(
  BuildContext context, {
  required Rect anchor,
  String? selected,
}) async {
  unawaited(HapticFeedback.lightImpact());
  final choix = await showGeneralDialog<_ChoixBarre>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.black.withValues(alpha: 0.08),
    transitionDuration: const Duration(milliseconds: 140),
    pageBuilder: (ctx, _, __) => _ReactionBarOverlay(
      anchor: anchor,
      selected: selected,
    ),
    transitionBuilder: (ctx, animation, _, child) {
      final courbe = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutBack,
        reverseCurve: Curves.easeIn,
      );
      return FadeTransition(
        opacity: animation,
        child: ScaleTransition(scale: courbe, child: child),
      );
    },
  );

  if (choix == null) return null;
  if (choix.emoji != null) return choix.emoji;
  if (!context.mounted) return null;
  return showFullReactionPicker(context);
}

/// Sélecteur complet (toutes les catégories, recherche, récents).
Future<String?> showFullReactionPicker(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => const _FullReactionPickerSheet(),
  );
}

/// Résultat interne de la barre : un emoji, ou « ouvrir le sélecteur ».
class _ChoixBarre {
  final String? emoji;
  const _ChoixBarre.emoji(String this.emoji);
  const _ChoixBarre.plus() : emoji = null;
}

class _ReactionBarOverlay extends StatelessWidget {
  final Rect anchor;
  final String? selected;

  const _ReactionBarOverlay({required this.anchor, this.selected});

  /// Cinq pastilles + le « + » (44 dp), cinq espaces de 6, marge intérieure.
  static const double _largeur = 6 * 44 + 5 * 6 + 2 * 8;
  static const double _hauteur = 44 + 2 * 6;
  static const double _ecart = 8;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final ecran = media.size;
    final largeur = _largeur.clamp(0.0, ecran.width - 16).toDouble();

    final gauche = (anchor.center.dx - largeur / 2)
        .clamp(8.0, (ecran.width - largeur - 8).clamp(8.0, double.infinity))
        .toDouble();
    // Au-dessus de la bulle ; en dessous si elle touche le haut de l'écran.
    var haut = anchor.top - _hauteur - _ecart;
    if (haut < media.padding.top + 8) {
      haut = (anchor.bottom + _ecart)
          .clamp(media.padding.top + 8, ecran.height - _hauteur - 8)
          .toDouble();
    }

    return Stack(
      children: [
        Positioned(
          left: gauche,
          top: haut,
          width: largeur,
          child: Material(
            color: context.surfaceColor,
            elevation: 6,
            shadowColor: Colors.black.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(28),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: QuickReactionRow(
                  compact: true,
                  selected: selected,
                  onPick: (emoji) =>
                      Navigator.of(context).pop(_ChoixBarre.emoji(emoji)),
                  onMore: () =>
                      Navigator.of(context).pop(const _ChoixBarre.plus()),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _FullReactionPickerSheet extends StatelessWidget {
  const _FullReactionPickerSheet();

  @override
  Widget build(BuildContext context) {
    final hauteur = MediaQuery.of(context).size.height * 0.5;
    return Container(
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      // Le clavier de la recherche remonte la feuille au lieu de la couvrir.
      padding: EdgeInsets.only(
        top: 10,
        bottom: MediaQuery.of(context).padding.bottom +
            MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SheetHandle(),
          const SizedBox(height: 8),
          SizedBox(
            height: hauteur,
            child: emoji_picker.EmojiPicker(
              onEmojiSelected: (_, emoji) {
                unawaited(HapticFeedback.lightImpact());
                Navigator.of(context).pop(emoji.emoji);
              },
              config: emoji_picker.Config(
                height: hauteur,
                checkPlatformCompatibility: true,
                emojiViewConfig: emoji_picker.EmojiViewConfig(
                  // Le défaut de la bibliothèque est « No Recents », en dur et en
                  // `black26` : anglais, et invisible en thème sombre.
                  noRecents: Text(
                    AppLocalizations.of(context)!.noRecentEmojis,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: context.textTertiaryColor),
                  ),
                  columns: 8,
                  emojiSizeMax: 28 * (Platform.isIOS ? 1.30 : 1.0),
                  backgroundColor: context.surfaceColor,
                ),
                categoryViewConfig: emoji_picker.CategoryViewConfig(
                  backgroundColor: context.surfaceColor,
                  indicatorColor: context.adaptivePrimaryColor,
                  iconColorSelected: context.adaptivePrimaryColor,
                  iconColor: context.textTertiaryColor,
                ),
                // Pas d'effacement ici (on choisit, on n'écrit pas) ; la
                // recherche reste, c'est elle qui rend les milliers d'emojis
                // atteignables.
                bottomActionBarConfig: emoji_picker.BottomActionBarConfig(
                  showBackspaceButton: false,
                  backgroundColor: context.surfaceColor,
                  buttonColor: context.surfaceColor,
                  buttonIconColor: context.textSecondaryColor,
                ),
                searchViewConfig: emoji_picker.SearchViewConfig(
                  backgroundColor: context.surfaceColor,
                  buttonIconColor: context.textSecondaryColor,
                  hintText: AppLocalizations.of(context)!.searchTitle,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Pastille ronde d'une réaction rapide (§27a). Aplat sable au repos, cerclée
/// d'accent quand la réaction est déjà posée.
class _QuickReactionButton extends StatelessWidget {
  final String? emoji;
  final IconData? icon;
  final String? tooltip;
  final bool selected;
  final VoidCallback onTap;

  const _QuickReactionButton({
    this.emoji,
    this.icon,
    this.tooltip,
    this.selected = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bouton = Material(
      color: selected
          ? context.adaptivePrimaryColor.withValues(alpha: 0.14)
          : context.surfaceVariantColor,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: selected
                ? Border.all(color: context.adaptivePrimaryColor, width: 1.6)
                : null,
          ),
          child: icon != null
              ? Icon(icon, size: 20, color: context.textSecondaryColor)
              : Text(emoji!, style: const TextStyle(fontSize: 21)),
        ),
      ),
    );
    return tooltip == null ? bouton : Tooltip(message: tooltip!, child: bouton);
  }
}
