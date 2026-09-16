import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../src/rust/api/mls.dart' as rust;
import '../../../src/rust/frb_generated.dart';
import 'mls_chemin_base.dart';
import 'mls_payload_codec.dart';

/// Reconstruit l'aperçu d'un message MLS **dans l'isolate de notification**,
/// sans jamais toucher à l'état qui fait foi (plan MLS § 8).
///
/// Ce que ça remplace : jusqu'ici, Postgres déchiffrait et mettait le vrai
/// texte dans le push. MLS le lui interdit. Le serveur n'envoie plus qu'un
/// repli générique et le ciphertext ; c'est l'appareil qui reconstitue
/// l'aperçu, et lui seul le peut.
///
/// **Le piège que cette classe existe pour éviter.** Déchiffrer consomme une
/// génération du cliquet. Si cet isolate déchiffrait sur la base principale,
/// l'application — qui traite ensuite le même message — ne pourrait plus le
/// lire, et la conversation deviendrait illisible sans qu'aucune erreur ne le
/// dise. Le déchiffrement passe donc par `apercuSansEtat`, qui travaille sur
/// une copie jetable côté Rust. Un seul écrivain de l'état MLS : l'app.
///
/// Trois contraintes de l'isolate background, toutes déjà payées par ce dépôt :
/// - `PreferencesService` n'y est pas initialisé — on passe par
///   `SharedPreferences` directement ;
/// - les `MethodChannel` n'y répondent pas sans liaison explicite, donc
///   `stableDeviceId()` (qui lit le SSAID) est **inutilisable** : l'identifiant
///   est mémorisé à l'inscription et relu ici ;
/// - une exception non rattrapée y fait disparaître la notification **entière**
///   (vécu le 2026-08-13) : tout échoue en silence vers le repli générique.
class MlsNotificationPreview {
  MlsNotificationPreview._();

  /// Clé des préférences où le registre dépose l'identifiant d'appareil.
  static String cleStableId(String userId) => 'mls_stable_device_id_$userId';

  /// Préfixe du cache d'aperçus, relu par l'application au réveil.
  static const _prefixeApercu = 'mls_apercu_';

  /// Au-delà, les plus anciens sont jetés : ce cache contient du texte en
  /// clair, il n'a pas à grossir indéfiniment.
  static const maxApercusCaches = 50;

  /// Vrai quand ce push est un message MLS à déchiffrer localement.
  ///
  /// Le réglage « aperçu des messages » (`users.show_message_preview`) compte
  /// ici autant qu'avant : `send-push` le transmet dans le payload sous
  /// `showMessagePreview`. Sans cette garde il n'aurait plus couvert que le
  /// legacy — un réglage qui cesse silencieusement de s'appliquer est pire
  /// qu'un réglage absent.
  static bool concerne(Map<String, dynamic> data) =>
      data['protocol'] == 'mls' &&
      data['showMessagePreview'] != 'false' &&
      (data['mlsCiphertext'] as String?)?.isNotEmpty == true;

  /// Rend le texte d'aperçu, ou `null` si quoi que ce soit manque ou échoue.
  ///
  /// Ne lève jamais : un aperçu est du confort, et le repli générique du
  /// serveur reste affichable.
  static Future<String?> texte(Map<String, dynamic> data) async {
    if (!concerne(data)) return null;
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('currentUserId');
      if (userId == null || userId.isEmpty) return null;
      final deviceId = prefs.getString(cleStableId(userId));
      if (deviceId == null || deviceId.isEmpty) return null;

      final conversationId = data['conversationId'] as String?;
      final messageId = data['messageId'] as String?;
      final senderDeviceId = data['mlsSenderDeviceId'] as String?;
      final kind = data['mlsKind'] as String? ?? 'content';
      if (conversationId == null || messageId == null || senderDeviceId == null) {
        return null;
      }

      // Même source que `mlsEngineProvider` : le chemin était recopié ici, et
      // deux copies d'une règle de chemin finissent toujours par diverger.
      final chemin = await cheminBaseMls(userId);
      if (!File(chemin).existsSync()) return null;

      await _initRustUneFois();
      final clair = await rust.apercuSansEtat(
        dbPath: chemin,
        userId: userId,
        deviceId: deviceId,
        conversationId: conversationId,
        message: _decoderBase64(data['mlsCiphertext'] as String),
        // Recomposé depuis les colonnes portées par le push, jamais depuis le
        // payload : un ciphertext présenté sous un autre identifiant échoue.
        aad: MlsAad.message(
          conversationId: conversationId,
          messageId: messageId,
          senderDeviceId: senderDeviceId,
          kind: kind,
        ),
      );

      final payload = MlsPayload.decode(Uint8List.fromList(clair));
      final texte = resume(payload);
      if (texte != null) await _cacher(prefs, messageId, texte);
      return texte;
    } catch (e) {
      // Y compris le cas normal « message d'un epoch que cet appareil n'a pas
      // encore traité » : l'app le lira, la notification affiche le repli.
      debugPrint('MlsNotificationPreview: aperçu indisponible ($e)');
      return null;
    }
  }

  /// Aperçu déjà déchiffré pour ce message, s'il a été posé par l'isolate.
  static Future<String?> apercuCache(String messageId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('$_prefixeApercu$messageId');
  }

  /// À appeler à la déconnexion : ce cache porte du texte en clair.
  static Future<void> viderLeCache() async {
    final prefs = await SharedPreferences.getInstance();
    for (final cle in prefs.getKeys().where((k) => k.startsWith(_prefixeApercu)).toList()) {
      await prefs.remove(cle);
    }
  }

  /// `encode(bytea, 'base64')` de Postgres coupe sa sortie tous les 76
  /// caractères, et `base64Decode` refuse les sauts de ligne. Le trigger ne
  /// les émet plus (migration `20260915160000`), mais un push écrit par une
  /// version antérieure peut encore en porter : les retirer coûte une ligne,
  /// et l'aperçu échouait à chaque message sans elle.
  static Uint8List _decoderBase64(String valeur) =>
      base64Decode(valeur.replaceAll('\n', '').replaceAll('\r', ''));

  /// Ce qu'on montre dans la bannière, selon le type de message.
  @visibleForTesting
  static String? resume(MlsPayload payload) {
    switch (payload.type) {
      case 'text':
        final t = payload.texte.trim();
        return t.isEmpty ? null : t;
      case 'image':
        return 'Photo';
      case 'video':
        return 'Vidéo';
      case 'voiceNote':
        return 'Note vocale';
      case 'audio':
        return 'Audio';
      case 'file':
        return 'Fichier';
      case 'location':
        return 'Position';
      case 'sticker':
        return 'Sticker';
      default:
        return null;
    }
  }

  static Future<void> _cacher(SharedPreferences prefs, String messageId, String texte) async {
    final cles = prefs.getKeys().where((k) => k.startsWith(_prefixeApercu)).toList();
    if (cles.length >= maxApercusCaches) {
      cles.sort();
      for (final cle in cles.take(cles.length - maxApercusCaches + 1)) {
        await prefs.remove(cle);
      }
    }
    await prefs.setString('$_prefixeApercu$messageId', texte);
  }

  static Future<void>? _initRust;

  /// `RustLib.init()` une fois **par isolate** : la bibliothèque native est
  /// déjà chargée par le processus, mais chaque isolate a sa propre instance.
  static Future<void> _initRustUneFois() => _initRust ??= RustLib.init();
}
