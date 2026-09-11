import 'package:flutter/services.dart';

/// Réclame au natif une route de lien profond qu'il n'a pas pu remettre.
///
/// `MainActivity` pousse les routes par le canal `diaspo_niger/deep_link`,
/// mais une poussée n'aboutit que si l'écoute Dart est déjà branchée. Or une
/// activité peut se rattacher à un moteur dont le Dart démarre encore — créé
/// par `AudioService`, sans intent, un instant plus tôt. Le natif garde alors
/// la route (réponse `notImplemented`), et c'est à nous de la réclamer une
/// fois l'écoute en place.
///
/// Sans natif (iOS, tests), le canal lève [MissingPluginException] : rien à
/// réclamer, et surtout rien à propager — on est appelé au montage du routeur.
Future<void> reprendreLienEnAttente(
  MethodChannel canal,
  void Function(String route) aller,
) async {
  final String? route;
  try {
    route = await canal.invokeMethod<String>('takePendingLink');
  } on MissingPluginException {
    return;
  } on PlatformException {
    return;
  }
  if (route == null || route.isEmpty) return;
  aller(route);
}
