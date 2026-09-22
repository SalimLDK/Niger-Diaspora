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
    this.expediteurId = '',
  });

  final String messageId;
  final String texte;
  final String expediteur;
  final DateTime quand;

  /// L'identifiant de l'expéditeur, qui sert de clé d'identité à la `Person`
  /// d'Android — c'est par elle qu'il regroupe les messages consécutifs d'une
  /// même personne sous un seul en-tête.
  ///
  /// Le nom affiché ne peut pas jouer ce rôle : deux membres d'un groupe
  /// peuvent le partager, et surtout il peut MANQUER dans une charge — le
  /// chemin d'arrière-plan retombe alors sur le titre de la bannière, qui en
  /// groupe est le nom DU GROUPE. Un message se serait retrouvé sous un
  /// expéditeur différent au milieu de la pile.
  ///
  /// Vide pour une pile écrite par une version antérieure : on retombe sur le
  /// nom, comme avant.
  final String expediteurId;

  /// La clé d'identité à donner à Android.
  String get cleIdentite => expediteurId.isNotEmpty ? expediteurId : expediteur;

  Map<String, dynamic> versJson() => {
        'i': messageId,
        't': texte,
        'e': expediteur,
        'q': quand.millisecondsSinceEpoch,
        if (expediteurId.isNotEmpty) 'x': expediteurId,
      };

  static MessageEmpile? depuisJson(Object? brut) {
    if (brut is! Map) return null;
    final quand = brut['q'];
    if (quand is! int) return null;
    return MessageEmpile(
      messageId: brut['i']?.toString() ?? '',
      texte: brut['t']?.toString() ?? '',
      expediteur: brut['e']?.toString() ?? '',
      expediteurId: brut['x']?.toString() ?? '',
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
    String expediteurId = '',
    DateTime? quand,
  }) async {
    final nouveau = MessageEmpile(
      messageId: messageId,
      texte: texte,
      expediteur: expediteur,
      expediteurId: expediteurId,
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
      // Retrier AVANT de rogner : sans ça, un message arrivé en retard mais
      // plus ancien que les autres serait gardé, et un plus récent jeté.
      pile.sort((a, b) => a.quand.compareTo(b.quand));
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

  /// Corrige le texte d'un message déjà empilé, et rend la pile.
  ///
  /// Rend `null` si ce message n'est pas dans la pile — il n'y a alors aucune
  /// bannière à corriger, et il ne faut surtout pas en créer une : une édition
  /// ne doit jamais faire réapparaître une conversation qu'on a déjà lue.
  static Future<List<MessageEmpile>?> remplacer({
    required String conversationId,
    required String messageId,
    required String texte,
  }) async {
    if (messageId.isEmpty) return null;
    try {
      final prefs = await SharedPreferences.getInstance();
      final pile = _lireDepuis(prefs, conversationId);
      final i = pile.indexWhere((m) => m.messageId == messageId);
      if (i < 0) return null;
      if (pile[i].texte == texte) return pile;
      final ancien = pile[i];
      pile[i] = MessageEmpile(
        messageId: ancien.messageId,
        texte: texte,
        expediteur: ancien.expediteur,
        expediteurId: ancien.expediteurId,
        // L'heure reste celle de l'ENVOI, pas celle de la correction : la
        // ligne ne doit pas sauter de place dans la conversation parce qu'une
        // faute a été corrigée.
        quand: ancien.quand,
      );
      await prefs.setString(
        cleDe(conversationId),
        jsonEncode([for (final m in pile) m.versJson()]),
      );
      return pile;
    } catch (e) {
      debugPrint('PileMessagesNotifiees: correction impossible ($e)');
      return null;
    }
  }

  /// Retire un message supprimé pour tous (ou expiré) de la pile, et rend ce
  /// qu'il en reste.
  ///
  /// Rend `null` si le message n'y est pas : aucune bannière à toucher. Sans
  /// ce retrait, le texte supprimé restait lisible dans le volet Android — vu
  /// le 2026-09-21 sur SM A515F, « PA6SECRET » encore affiché dans la pile
  /// après « Supprimer pour tous ».
  static Future<List<MessageEmpile>?> retirer({
    required String conversationId,
    required String messageId,
  }) async {
    if (messageId.isEmpty) return null;
    try {
      final prefs = await SharedPreferences.getInstance();
      final pile = _lireDepuis(prefs, conversationId);
      final avant = pile.length;
      pile.removeWhere((m) => m.messageId == messageId);
      if (pile.length == avant) return null;
      if (pile.isEmpty) {
        await vider(conversationId);
      } else {
        await prefs.setString(
          cleDe(conversationId),
          jsonEncode([for (final m in pile) m.versJson()]),
        );
      }
      return pile;
    } catch (e) {
      debugPrint('PileMessagesNotifiees: retrait impossible ($e)');
      return null;
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
      final messages = [
        for (final e in jsonDecode(brut) as List)
          if (MessageEmpile.depuisJson(e) case final m?)
            if (m.quand.isAfter(limite)) m,
      ];
      // Trié par l'heure du SERVEUR, pas par l'ordre d'arrivée : au retour du
      // réseau, plusieurs messages arrivent d'un coup et pas toujours dans
      // l'ordre où ils ont été écrits. Une conversation se lit du plus ancien
      // au plus récent.
      messages.sort((a, b) => a.quand.compareTo(b.quand));
      return messages;
    } catch (_) {
      return [];
    }
  }
}
