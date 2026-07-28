import 'package:flutter/material.dart';

/// `TextEditingController` qui colore en direct les `#hashtags` et `@mentions`
/// saisis dans le champ (§13). Purement visuel : la logique de mentions de
/// `MentionTextField` ne lit que `.text`/`.selection`, donc ce contrôleur s'y
/// substitue sans effet de bord.
///
/// Les couleurs sont réglées depuis le thème (`FeedTokens.hashtagColor`) par
/// l'écran hôte, à chaque `build`. Comme le champ repeint après le `build` de
/// l'hôte, la couleur mise à jour est prise en compte immédiatement — pas
/// besoin de `notifyListeners`.
class HashtagHighlightingController extends TextEditingController {
  HashtagHighlightingController({super.text});

  /// Couleur des `#hashtags` (et `@mentions`). `null` = rendu par défaut.
  Color? highlightColor;

  static final _tokenPattern = RegExp(r'[#@]\w+');

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final color = highlightColor;
    final base = style ?? const TextStyle();

    // Pas de couleur définie, ou saisie IME en cours (composition) : on laisse
    // le rendu standard (préserve le souligné de composition).
    if (color == null ||
        (withComposing &&
            value.composing.isValid &&
            !value.composing.isCollapsed)) {
      return super.buildTextSpan(
        context: context,
        style: style,
        withComposing: withComposing,
      );
    }

    final tokenStyle =
        base.copyWith(color: color, fontWeight: FontWeight.w600);
    final spans = <TextSpan>[];
    var last = 0;
    for (final m in _tokenPattern.allMatches(text)) {
      if (m.start > last) {
        spans.add(TextSpan(text: text.substring(last, m.start), style: base));
      }
      spans.add(TextSpan(text: m.group(0), style: tokenStyle));
      last = m.end;
    }
    if (last < text.length) {
      spans.add(TextSpan(text: text.substring(last), style: base));
    }
    return TextSpan(style: base, children: spans);
  }
}
