import 'package:flutter/foundation.dart';

import '../../../features/messages/domain/entities/message_entity.dart';
import 'mls_conversation_service.dart';
import 'mls_delivery.dart';
import 'mls_message_mapper.dart';
import 'mls_payload_codec.dart';

/// Le point d'entrée unique de MLS pour la couche messages (plan MLS § 7.3).
///
/// Tout le reste de l'application ignore MLS : le repository lui demande
/// « cette conversation est-elle chiffrée ? », « donne-moi ses messages »,
/// « envoie celui-ci », et rien d'autre. C'est ce qui permet de brancher la
/// coexistence en une vingtaine de lignes au lieu d'essaimer des conditions
/// dans 81 fichiers.
///
/// **La règle du repli, et sa seule exception.** Une fois la conversation
/// basculée (`mls_since` posé), il n'existe aucun chemin de retour : le
/// serveur refuse d'écrire en clair dans `messages`, et un envoi MLS qui
/// échoue doit échouer visiblement. C'est ce repli muet qui a laissé le
/// chantier Signal envoyer en clair pendant des semaines pendant que tout
/// paraissait marcher. **Avant** la bascule, en revanche, rien n'est engagé :
/// un échec peut encore emprunter le chemin d'aujourd'hui, et ça se lit en
/// base — `mls_since` est resté nul.
class MlsGateway {
  MlsGateway({
    required this.userId,
    required bool Function() actif,
    required MlsConversationService service,
    required MlsDelivery delivery,
    Future<String?> Function(String userId)? nomDe,
  })  : _actif = actif,
        _service = service,
        _delivery = delivery,
        _nomDe = nomDe;

  final String userId;
  final bool Function() _actif;
  final MlsConversationService _service;
  final MlsDelivery _delivery;
  final Future<String?> Function(String userId)? _nomDe;

  /// `mls_since` par conversation, pour ne pas le redemander à chaque
  /// pagination. Une conversation ne se débascule jamais : une valeur non
  /// nulle est définitive, donc sûre à retenir.
  final Map<String, DateTime?> _bascule = {};
  final Map<String, String> _noms = {};

  /// Le drapeau est lu à chaque appel, pas au démarrage : l'ouvrir ne doit
  /// pas demander de relancer l'application.
  bool get actif => _actif();

  /// Date de bascule de la conversation, `null` si elle est encore en clair.
  Future<DateTime?> mlsSince(String conversationId) async {
    if (_bascule[conversationId] != null) return _bascule[conversationId];
    final row = await _delivery.conversation(conversationId);
    final brut = row?['mls_since'] as String?;
    final date = brut == null ? null : DateTime.tryParse(brut);
    _bascule[conversationId] = date;
    return date;
  }

  /// Vrai quand les messages de cette conversation passent par MLS.
  ///
  /// Une conversation **déjà basculée** reste lue par MLS même si le drapeau
  /// est refermé : sinon, refermer le drapeau rendrait illisibles des
  /// messages déjà envoyés.
  Future<bool> enMls(String conversationId) async {
    if (await mlsSince(conversationId) != null) return true;
    return actif;
  }

  /// Les messages MLS de la conversation, prêts pour l'écran.
  Future<List<MessageEntity>> messages(String conversationId) async {
    final entrants = await _service.catchUp(conversationId);
    final sortie = <MessageEntity>[];
    for (final e in entrants) {
      sortie.add(MlsMessageMapper.depuisEntrant(
        e,
        senderName: await _nom(e.row.senderId),
        currentUserId: userId,
      ));
    }
    return sortie;
  }

  /// Envoie un message texte. Lève si la conversation est basculée et que
  /// MLS échoue — c'est voulu (cf. la règle du repli ci-dessus).
  Future<MessageEntity> envoyerTexte({
    required String conversationId,
    required String texte,
    required String senderName,
    String? senderPhotoUrl,
    String? replyToId,
    Map<String, dynamic>? replyToMessageData,
  }) async {
    await _service.ensureGroup(conversationId);
    await _service.reconcileMembership(conversationId);
    _bascule.remove(conversationId); // la bascule vient peut-être d'avoir lieu

    final payload = MlsPayload(
      id: '',
      type: 'text',
      sentAt: DateTime.now().millisecondsSinceEpoch,
      body: {'content': texte},
      replyTo: replyToMessageData == null && replyToId == null
          ? null
          : {'id': replyToId, ...?replyToMessageData},
    );
    final row = await _service.send(
      conversationId,
      payload,
      contentType: MlsMessageMapper.contentType('text'),
    );
    return MlsMessageMapper.depuisPayload(
      MlsPayload(
        id: row.id,
        type: payload.type,
        sentAt: payload.sentAt,
        body: payload.body,
        replyTo: payload.replyTo,
      ),
      row: row,
      senderName: senderName,
      senderPhotoUrl: senderPhotoUrl,
      currentUserId: userId,
    );
  }

  /// Un envoi peut-il encore emprunter le chemin d'aujourd'hui ?
  ///
  /// Seulement si rien n'est engagé. Une fois `mls_since` posé, la réponse
  /// est non, définitivement — et le serveur la ferait respecter de toute
  /// façon.
  Future<bool> repliLegacyPossible(String conversationId) async =>
      await mlsSince(conversationId) == null;

  Future<String> _nom(String id) async {
    if (id == userId) return '';
    final connu = _noms[id];
    if (connu != null) return connu;
    try {
      final nom = await _nomDe?.call(id);
      if (nom != null && nom.isNotEmpty) {
        _noms[id] = nom;
        return nom;
      }
    } catch (e) {
      debugPrint('MlsGateway: nom introuvable pour $id ($e)');
    }
    return '';
  }

  @visibleForTesting
  void oublierBascule(String conversationId) => _bascule.remove(conversationId);
}
