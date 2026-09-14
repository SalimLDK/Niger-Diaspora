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
/// unique reçoivent ici la variante que le contraste exige — un teal éclairci
/// pour le nocturne, un or assombri pour le clair — et nulle part ailleurs.
@immutable
class TintedAccent {
  const TintedAccent({required this.light, required this.dark});

  final Color light;
  final Color dark;

  Color of(BuildContext context) => context.isDarkMode ? dark : light;
}
