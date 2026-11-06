import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Repère « cette installation a créé sa base MLS à cette date ».
///
/// **Pourquoi ce repère.** Après une réinstallation, l'ancien historique d'une
/// discussion passée à MLS (les messages gelés, lisibles par le serveur) revenait
/// en haut du fil alors que les messages MLS d'avant l'arrivée de l'appareil
/// sont masqués (`MlsIncoming.avantArrivee`) : un fil à moitié rempli, puis un
/// trou. Une installation neuve repart donc de zéro dans ces discussions.
///
/// **Pourquoi la base MLS et pas l'arrivée dans le groupe.** L'arrivée est
/// aussi posée par un appareil qui reçoit son Welcome plusieurs jours après la
/// bascule sans avoir rien réinstallé : masquer son historique serait une
/// perte. Le fichier de la base, lui, est exclu des sauvegardes
/// (`regles_sauvegarde.xml`) : il n'est absent qu'à la première ouverture d'une
/// installation. C'est le seul signal de « réinstallé » qui ne se trompe pas.
///
/// Une installation qui avait déjà sa base quand ce repère est apparu n'en a
/// pas : rien ne change pour elle.
String cleBaseNeuve(String userId) => 'mls_base_neuve_$userId';

/// Pose le repère. Ne lève jamais : une mémoire ratée laisse l'historique
/// visible, ce qui est l'ancien comportement.
Future<void> marquerBaseNeuve(
  String userId, {
  Future<SharedPreferences> Function()? preferences,
  DateTime? maintenant,
}) async {
  try {
    final prefs = await (preferences ?? SharedPreferences.getInstance)();
    await prefs.setString(
      cleBaseNeuve(userId),
      (maintenant ?? DateTime.now()).toUtc().toIso8601String(),
    );
  } catch (e) {
    debugPrint('MLS: repère de base neuve non posé ($e)');
  }
}

Future<DateTime?> baseNeuveDepuis(
  String userId, {
  Future<SharedPreferences> Function()? preferences,
}) async {
  try {
    final prefs = await (preferences ?? SharedPreferences.getInstance)();
    return DateTime.tryParse(prefs.getString(cleBaseNeuve(userId)) ?? '');
  } catch (e) {
    debugPrint('MLS: repère de base neuve illisible ($e)');
    return null;
  }
}

/// L'ancien historique d'une discussion doit-il rester caché ?
///
/// Oui quand la base de cette installation est née **après** la bascule : elle
/// n'a jamais fait partie de la conversation en clair. Non si la discussion
/// n'est pas passée à MLS, ou si elle a basculé alors que l'installation était
/// déjà là — dans ce cas l'historique a toujours été à elle.
bool legacyDoitEtreMasque({
  required DateTime? baseNeuve,
  required DateTime? mlsSince,
}) => baseNeuve != null && mlsSince != null && baseNeuve.isAfter(mlsSince);
