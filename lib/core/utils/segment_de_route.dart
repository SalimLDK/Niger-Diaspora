import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// Un identifiant venu d'une notification, s'il peut servir de segment de
/// route — sinon `null`.
///
/// Les identifiants d'une notification (`targetId`, `eventId`, `postId`…)
/// viennent de `data`, que le serveur recopie. Sans contrôle, un
/// `eventId = "x/edit"` ouvrait l'écran de MODIFICATION d'un événement, et un
/// `?` ou un `#` greffait des paramètres à la route (audit des notifications
/// du 2026-10-14). Un identifiant Firebase, un UUID ou un identifiant de
/// conversation ne contiennent que lettres, chiffres, `-` et `_`.
String? segmentDeRoute(String? id) {
  if (id == null) return null;
  return RegExp(r'^[A-Za-z0-9_-]{1,128}$').hasMatch(id) ? id : null;
}

/// Pousse `base/id` si [id] est un segment de route sûr, et ne fait rien
/// sinon. Pour les écrans de la liste des notifications.
void pousserVersCible(BuildContext context, String base, String? id) {
  final segment = segmentDeRoute(id);
  if (segment == null) return;
  unawaited(context.push('$base/$segment'));
}
