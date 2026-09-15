import 'package:diaspo_niger/core/crypto/mls/mls_conversation_service.dart';
import 'package:diaspo_niger/core/crypto/mls/mls_delivery.dart';
import 'package:diaspo_niger/core/crypto/mls/mls_metadonnees.dart';
import 'package:diaspo_niger/core/crypto/mls/mls_gateway.dart';
import 'package:diaspo_niger/core/network/network_info.dart';
import 'package:diaspo_niger/core/services/cache_service.dart';
import 'package:diaspo_niger/features/messages/data/datasources/message_remote_datasource.dart';
import 'package:diaspo_niger/features/messages/data/models/message_model.dart';
import 'package:diaspo_niger/features/messages/data/repositories/message_repository_impl.dart';
import 'package:diaspo_niger/features/messages/domain/entities/message_entity.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ce que ces tests protègent (plan MLS § 6.3)
/// -------------------------------------------
/// **Trois écrans posaient au serveur une question qu'il ne peut pas
/// entendre**, et prenaient sa réponse vide pour une vérité :
///
/// - la **recherche** dans une conversation : son `ilike` porte sur un
///   ciphertext, donc ne trouve jamais rien ;
/// - la liste des **favoris** : l'étoile d'un message chiffré s'écrit bien
///   dans `mls_message_stars` et le fil l'affiche, mais la liste lisait
///   `messages`, où ce message n'a pas de ligne. On étoilait dans le vide ;
/// - la **galerie** : le descripteur d'un média chiffré voyage dans le
///   payload, donc le serveur ne sait même pas que c'en est un.
///
/// Aucune des trois ne levait. Le clair n'existe que sur l'appareil, dans le
/// cache Hive : les trois l'interrogent maintenant, tout en gardant le
/// résultat serveur — au-dessus du séparateur de bascule l'historique est
/// resté en clair, et lui seul le couvre en entier.
///
/// Ce que ces tests empêchent, concrètement : qu'on croie un de ces chemins
/// réparé alors qu'il ignore le cache, qu'il perde l'historique d'avant la
/// bascule, qu'il rende deux fois le même message quand les deux sources le
/// portent, ou qu'il se mette à servir le cache dans une conversation **en
/// clair**, où la pagination serveur fait foi.

MessageModel _m(
  String id,
  String contenu,
  DateTime quand, {
  String type = 'text',
  String? fileUrl,
}) =>
    MessageModel(
      id: id,
      senderId: 'u2',
      senderName: 'Amina',
      content: contenu,
      createdAt: quand,
      type: type,
      fileUrl: fileUrl,
    );

class _SourceAvecHistorique implements MessageRemoteDataSource {
  _SourceAvecHistorique(this.resultats);

  final List<MessageModel> resultats;
  int appels = 0;

  @override
  Future<List<MessageModel>> searchMessagesInConversation({
    required String conversationId,
    required String query,
    int limit = 200,
  }) async {
    appels++;
    return resultats;
  }

  @override
  Future<List<MessageModel>> getStarredMessages({
    required String conversationId,
    required String userId,
    int limit = 100,
  }) async {
    appels++;
    return resultats;
  }

  @override
  Future<List<MessageModel>> getMediaMessages({
    required String conversationId,
    int limit = 50,
    String? beforeMessageId,
  }) async {
    appels++;
    return resultats;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _CacheAvecFil implements CacheService {
  _CacheAvecFil(this.messages);

  final List<MessageModel> messages;

  @override
  List<Map<String, dynamic>> getCachedMessages(
    String conversationId, {
    int? limit,
    String? beforeMessageId,
  }) =>
      [for (final m in messages) m.toJson()];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Reseau implements NetworkInfo {
  @override
  Future<bool> get isConnected async => true;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Le transport, sans réseau : `conversation()` suffit à dire « basculée ».
class _TransportFige extends MlsDelivery {
  _TransportFige(this.mlsSince) : super(ensureAuth: (() async => true));

  final String? mlsSince;

  @override
  Future<Map<String, dynamic>?> conversation(String conversationId) async => {
        'id': conversationId,
        'type': 'individual',
        'participant_ids': const <String>[],
        'mls_since': mlsSince,
      };
}

class _ServiceMuet extends MlsConversationService {
  _ServiceMuet()
      : super(
          userId: 'u1',
          moteur: () => throw StateError('le moteur ne doit pas être demandé'),
          delivery: _TransportFige(null),
          appareil: () => throw StateError('inutile ici'),
        );
}

/// Les métadonnées en ligne, sans Supabase : seules les étoiles comptent ici.
class _MetadonneesFigees extends MlsMetadonnees {
  _MetadonneesFigees(this.etoiles)
      : super(userId: 'u1', ensureAuth: (() async => true));

  final Set<String> etoiles;
  List<String> demandes = const [];

  @override
  Future<MlsMetadonneesLot> pour(Iterable<String> messageIds) async {
    demandes = messageIds.toList();
    return MlsMetadonneesLot(etoiles: etoiles);
  }
}

MlsGateway _passerelle({
  required bool basculee,
  Set<String> etoiles = const {},
}) =>
    MlsGateway(
      userId: 'u1',
      actif: () => false,
      service: _ServiceMuet(),
      delivery: _TransportFige(basculee ? '2026-09-15T00:00:00Z' : null),
      metadonnees: _MetadonneesFigees(etoiles),
    );

MessageRepositoryImpl _depot({
  required _SourceAvecHistorique source,
  required _CacheAvecFil cache,
  MlsGateway? passerelle,
}) =>
    MessageRepositoryImpl(
      remoteDataSource: source,
      networkInfo: _Reseau(),
      cacheService: cache,
      mlsGateway: passerelle,
    );

void main() {
  final t0 = DateTime.utc(2026, 9, 15, 8);

  group('amorçage du fil chiffré', () {
    // Ce que ce groupe protège : un amorçage VIDE ne doit pas verrouiller le
    // fil. `_mlsDuCache` rend `const []` dès que `mlsSince` est nul, et
    // `mlsSince` vient d'une lecture réseau ; au démarrage à froid `enMls`
    // reste vrai par le drapeau de compte pendant que la date manque encore.
    // L'ancien `if (_fil.containsKey(...)) return;` posait alors un fil vide
    // que PLUS AUCUN appel ne pouvait remplir — le fil chiffré restait vide
    // pour toute la vie du processus. Mesuré sur SM A515F le 2026-09-15 :
    // trois messages vivants en base, aucun à l'écran, zéro diagnostic.
    //
    // L'assertion passe par `estMlsMessage`, qui répond depuis l'ensemble des
    // identifiants connus rempli par l'amorçage — sans réveiller le moteur,
    // que cette fixture interdit.
    test('un amorçage vide ne condamne pas le fil', () async {
      final passerelle = _passerelle(basculee: true);
      passerelle.amorcer('c1', const []);
      passerelle.amorcer('c1', [_message('m1', 'bonjour')]);
      expect(
        await passerelle.estMlsMessage('c1', 'm1'),
        isTrue,
        reason: 'le second amorçage doit pouvoir remplir un fil laissé vide',
      );
    });

    test('un amorçage garni n’est pas remplacé par un suivant', () async {
      // L'autre moitié de la règle : une fois le fil garni, un amorçage plus
      // tardif ne doit rien écraser — sinon une lecture concurrente ferait
      // disparaître des messages déjà affichés.
      final passerelle = _passerelle(basculee: true);
      passerelle.amorcer('c1', [_message('m1', 'premier')]);
      passerelle.amorcer('c1', [_message('m2', 'second')]);
      expect(await passerelle.estMlsMessage('c1', 'm1'), isTrue);
    });
  });

  group('recherche dans une conversation basculée', () {
    test('le cache local fournit ce que le serveur ne peut pas lire', () async {
      // Le serveur ne rend rien : le contenu est chiffré chez lui.
      final source = _SourceAvecHistorique([]);
      final cache = _CacheAvecFil([
        _m('mls-1', 'rendez-vous à Niamey', t0),
        _m('mls-2', 'autre chose', t0.add(const Duration(minutes: 1))),
      ]);

      final res = await _depot(
        source: source,
        cache: cache,
        passerelle: _passerelle(basculee: true),
      ).searchMessagesInConversation(conversationId: 'c1', query: 'niamey');

      final trouves = res.getOrElse(() => []);
      expect(trouves.map((m) => m.id), ['mls-1']);
    });

    test("l'historique d'avant la bascule n'est pas perdu", () async {
      // Au-dessus du séparateur, les messages sont restés en clair : seul le
      // serveur les couvre en entier, le cache pouvant être partiel.
      final source = _SourceAvecHistorique([
        _m('legacy-1', 'rendez-vous de mars', t0.subtract(const Duration(days: 30))),
      ]);
      final cache = _CacheAvecFil([_m('mls-1', 'rendez-vous à Niamey', t0)]);

      final res = await _depot(
        source: source,
        cache: cache,
        passerelle: _passerelle(basculee: true),
      ).searchMessagesInConversation(conversationId: 'c1', query: 'rendez-vous');

      final trouves = res.getOrElse(() => []);
      expect(trouves.map((m) => m.id), containsAll(['legacy-1', 'mls-1']));
      // Le plus récent d'abord.
      expect(trouves.first.id, 'mls-1');
    });

    test('un message porté par les deux sources ne sort qu\'une fois', () async {
      final source = _SourceAvecHistorique([_m('x', 'rendez-vous', t0)]);
      final cache = _CacheAvecFil([_m('x', 'rendez-vous', t0)]);

      final res = await _depot(
        source: source,
        cache: cache,
        passerelle: _passerelle(basculee: true),
      ).searchMessagesInConversation(conversationId: 'c1', query: 'rendez');

      expect(res.getOrElse(() => []).length, 1);
    });

    test('la casse est indifférente, comme côté serveur', () async {
      final cache = _CacheAvecFil([_m('mls-1', 'Rendez-Vous à NIAMEY', t0)]);

      final res = await _depot(
        source: _SourceAvecHistorique([]),
        cache: cache,
        passerelle: _passerelle(basculee: true),
      ).searchMessagesInConversation(conversationId: 'c1', query: 'niamey');

      expect(res.getOrElse(() => []).length, 1);
    });
  });

  group('recherche dans une conversation en clair', () {
    test('rien ne change : le serveur reste seul juge', () async {
      // Sans bascule, le cache ne doit pas s'inviter — il est partiel, et
      // ajouterait des résultats que la pagination serveur n'a pas.
      final source = _SourceAvecHistorique([_m('s-1', 'bonjour', t0)]);
      final cache = _CacheAvecFil([_m('cache-seul', 'bonjour aussi', t0)]);

      final res = await _depot(
        source: source,
        cache: cache,
        passerelle: _passerelle(basculee: false),
      ).searchMessagesInConversation(conversationId: 'c1', query: 'bonjour');

      expect(res.getOrElse(() => []).map((m) => m.id), ['s-1']);
      expect(source.appels, 1);
    });

    test('sans passerelle du tout, le comportement est celui d\'avant',
        () async {
      final source = _SourceAvecHistorique([_m('s-1', 'bonjour', t0)]);

      final res = await _depot(
        source: source,
        cache: _CacheAvecFil([_m('cache-seul', 'bonjour aussi', t0)]),
      ).searchMessagesInConversation(conversationId: 'c1', query: 'bonjour');

      expect(res.getOrElse(() => []).map((m) => m.id), ['s-1']);
    });
  });

  group("favoris d'une conversation basculée", () {
    test("l'étoile d'un message chiffré apparaît enfin dans la liste", () async {
      // Le pire des trois : mettre en favori MARCHE (la ligne est écrite, le
      // fil affiche l'étoile), mais la liste lisait `messages`, où le message
      // n'a pas de ligne. On étoilait dans le vide.
      final res = await _depot(
        source: _SourceAvecHistorique([]),
        cache: _CacheAvecFil([
          _m('mls-1', 'à garder', t0),
          _m('mls-2', 'pas gardé', t0),
        ]),
        passerelle: _passerelle(basculee: true, etoiles: {'mls-1'}),
      ).getStarredMessages(conversationId: 'c1', userId: 'u1');

      expect(res.getOrElse(() => []).map((m) => m.id), ['mls-1']);
    });

    test("les favoris d'avant la bascule restent", () async {
      final res = await _depot(
        source: _SourceAvecHistorique([_m('legacy-1', 'ancien', t0)]),
        cache: _CacheAvecFil([_m('mls-1', 'récent', t0)]),
        passerelle: _passerelle(basculee: true, etoiles: {'mls-1'}),
      ).getStarredMessages(conversationId: 'c1', userId: 'u1');

      expect(res.getOrElse(() => []).map((m) => m.id),
          containsAll(['legacy-1', 'mls-1']));
    });

    test("sans bascule, le cache ne s'invite pas", () async {
      final res = await _depot(
        source: _SourceAvecHistorique([_m('legacy-1', 'ancien', t0)]),
        cache: _CacheAvecFil([_m('mls-1', 'récent', t0)]),
        passerelle: _passerelle(basculee: false, etoiles: {'mls-1'}),
      ).getStarredMessages(conversationId: 'c1', userId: 'u1');

      expect(res.getOrElse(() => []).map((m) => m.id), ['legacy-1']);
    });
  });

  group("galerie d'une conversation basculée", () {
    test('les médias chiffrés entrent dans la galerie', () async {
      final res = await _depot(
        source: _SourceAvecHistorique([]),
        cache: _CacheAvecFil([
          _m('img', 'photo', t0, type: 'image', fileUrl: 'https://x/1.enc'),
          _m('txt', 'juste du texte', t0),
        ]),
        passerelle: _passerelle(basculee: true),
      ).getMediaMessages(conversationId: 'c1');

      expect(res.getOrElse(() => []).map((m) => m.id), ['img']);
    });

    test('un média sans URL reste dehors, comme côté serveur', () async {
      final res = await _depot(
        source: _SourceAvecHistorique([]),
        cache: _CacheAvecFil([_m('img', 'photo', t0, type: 'image')]),
        passerelle: _passerelle(basculee: true),
      ).getMediaMessages(conversationId: 'c1');

      expect(res.getOrElse(() => []), isEmpty);
    });
  });
}

MessageEntity _message(String id, String contenu) => MessageEntity(
      id: id,
      senderId: 'u1',
      senderName: 'Sim',
      content: contenu,
      type: MessageType.text,
      status: MessageStatus.sent,
      createdAt: DateTime(2026, 9, 15, 12),
    );
