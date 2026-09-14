import 'package:flutter/material.dart';

import 'adaptive_colors.dart';

/// Une teinte d'accent déclinée pour les deux thèmes.
///
/// Le motif visé est toujours le même : une icône posée en pleine teinte sur
/// un aplat de cette **même** teinte à 10–15 % (tuiles de service, tuiles du
/// panneau « + » de la discussion). Une couleur foncée y disparaît deux fois
/// en nocturne, sur l'aplat comme sur la surface — d'où la paire plutôt
/// qu'une valeur unique. Les rôles que le guide de style décline déjà
/// (`info`/`infoDark`…) sont repris tels quels ; ceux qu'il laisse en valeur
/// unique sont éclaircis ici quand le contraste l'exige, jamais ailleurs.
@immutable
class TintedAccent {
  const TintedAccent({required this.light, required this.dark});

  /// Même valeur dans les deux thèmes — le cas de l'or, que le guide donne
  /// déjà assez clair pour le nocturne.
  const TintedAccent.unique(Color value) : light = value, dark = value;

  final Color light;
  final Color dark;

  Color of(BuildContext context) => context.isDarkMode ? dark : light;
}
