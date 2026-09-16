import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Un message déjà annoncé, gardé le temps d'en annoncer un suivant.
@immutable
class MessageEmpile {
  const MessageEmpile({
    required this.messageId,
    required this.texte,
    required this.expediteur,
    required this.quand,
  });

  final String messageId;
  final String texte;
  final String expediteur;
  final DateTime quand;

  Map<String, dynamic> versJson() => {
        'i': messageId,
        't': texte,
        'e': expediteur,
        'q': quand.millisecondsSinceEpoch,
      };

  static MessageEmpile? depuisJson(Object? brut) {
    if (brut is! Map) return null;
    final quand = brut['q'];
    if (quand is! int) return null;
    return MessageEmpile(
      messageId: brut['i']?.toString() ?? '',
      texte: brut['t']?.toString() ?? '',
      expediteur: brut['e']?.toString() ?? '',
      quand: DateTime.fromMillisecondsSinceEpoch(quand),
    );
  }
}

/// Les messages déjà annoncés d'une conversation, pour les empiler au lieu de
/// les remplacer.
///
/// **Le défaut que ça corrige.** Quand l'application est en arrière-plan ou
/// fermée — c'est-à-dire quand une notification sert vraiment —, la bannière
/// est construite par `_showFallbackMessageNotification`, qui postait sous le
/// couple `(tag: 'msg_<conversation>', id: 0)`. Android identifie une
/// notification par ce couple : le message suivant **écrasait** le précédent.
/// Cinq messages reçus, un seul lisible, aucun compteur, et rien qui dise que
/// les quatre autres ont existé.
///
/// Le chemin premier plan, lui, savait déjà empiler (`MessagingStyle`,
/// `_activeGroups`) — mais son cache vit dans le singleton, en mémoire, et
/// l'isolate de notification ne le voit pas. D'où ce magasin-ci, en
/// `SharedPreferences` : c'est le seul état que les deux isolates partagent.
///
/// Contraintes de l'isolate d'arrière-plan, déjà payées ailleurs :
/// `PreferencesService` n'y est pas initialisé (on passe par
/// `SharedPreferences` directement) et rien ne doit lever — un échec ici doit
/// dégrader la bannière, jamais la faire disparaître.
class PileMessagesNotifiees {
  PileMessagesNotifiees._();

  /// Au-delà, les plus anciens sortent. Android n'en affiche de toute façon
  /// que quelques-uns, et cette pile contient du texte en clair.
  static const int maxParConversation = 6;

  /// Une pile plus vieille que ça n'a plus de sens : elle ferait réapparaître
  /// des messages d'hier sous un message d'aujourd'hui.
  static const Duration duree = Duration(hours: 24);

  static const String _prefixe = 'notif_pile_';
  static const String _cleIndex = 'notif_pile_conversations';

  static String cleDe(String conversationId) => '$_prefixe$conversationId';

  /// Ajoute [messageId] à la pile de [conversationId] et rend la pile entière,
  /// du plus ancien au plus récent.
  ///
  /// Un message déjà empilé n'est pas ajouté deux fois : le même push peut
  /// arriver en double (réseau coupé puis rétabli, renvoi FCM), et la bannière
  /// afficherait alors la même phrase deux fois.
  static Future<List<MessageEmpile>> empiler({
    required String conversationId,
    required String messageId,
    required String texte,
    required String expediteur,
    DateTime? quand,
  }) async {
    final nouveau = MessageEmpile(
      messageId: messageId,
      texte: texte,
      expediteur: expediteur,
      quand: quand ?? DateTime.now(),
    );
    try {
      final prefs = await SharedPreferences.getInstance();
      final pile = _lireDepuis(prefs, conversationId);
      if (messageId.isNotEmpty &&
          pile.any((m) => m.messageId == messageId)) {
        return pile;
      }
      pile.add(nouveau);
      while (pile.length > maxParConversation) {
        pile.removeAt(0);
      }
      await prefs.setString(
        cleDe(conversationId),
        jsonEncode([for (final m in pile) m.versJson()]),
      );
      final index = prefs.getStringList(_cleIndex) ?? <String>[];
      if (!index.contains(conversationId)) {
        await prefs.setStringList(_cleIndex, [...index, conversationId]);
      }
      return pile;
    } catch (e) {
      debugPrint('PileMessagesNotifiees: empilement impossible ($e)');
      // Dégradé, pas cassé : la bannière affichera ce seul message.
      return [nouveau];
    }
  }

  /// La pile de [conversationId], expirés retirés.
  static Future<List<MessageEmpile>> lire(String conversationId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return _lireDepuis(prefs, conversationId);
    } catch (_) {
      return const [];
    }
  }

  /// À appeler dès que la conversation est vue : ouverture, appui sur la
  /// bannière, marquage lu depuis un autre appareil.
  static Future<void> vider(String conversationId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(cleDe(conversationId));
      final index = prefs.getStringList(_cleIndex) ?? <String>[];
      if (index.contains(conversationId)) {
        await prefs.setStringList(
          _cleIndex,
          index.where((c) => c != conversationId).toList(),
        );
      }
    } catch (e) {
      debugPrint('PileMessagesNotifiees: purge impossible ($e)');
    }
  }

  /// Les conversations qui ont encore des messages annoncés et non vus.
  ///
  /// Sert au résumé Android : sans lui, on ne saurait pas quand le retirer.
  static Future<List<String>> conversationsEnAttente() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final index = prefs.getStringList(_cleIndex) ?? <String>[];
      return [
        for (final c in index)
          if (_lireDepuis(prefs, c).isNotEmpty) c,
      ];
    } catch (_) {
      return const [];
    }
  }

  /// À la déconnexion : cette pile porte du texte en clair.
  static Future<void> viderTout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final cle in prefs.getKeys().where((k) => k.startsWith(_prefixe)).toList()) {
        await prefs.remove(cle);
      }
      await prefs.remove(_cleIndex);
    } catch (e) {
      debugPrint('PileMessagesNotifiees: purge globale impossible ($e)');
    }
  }

  static List<MessageEmpile> _lireDepuis(
    SharedPreferences prefs,
    String conversationId,
  ) {
    final brut = prefs.getString(cleDe(conversationId));
    if (brut == null || brut.isEmpty) return [];
    try {
      final limite = DateTime.now().subtract(duree);
      return [
        for (final e in jsonDecode(brut) as List)
          if (MessageEmpile.depuisJson(e) case final m?)
            if (m.quand.isAfter(limite)) m,
      ];
    } catch (_) {
      return [];
    }
  }
}
