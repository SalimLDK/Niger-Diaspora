import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:diaspo_niger/core/crypto/mls/mls_gateway.dart';
import 'package:diaspo_niger/core/network/network_info.dart';
import 'package:diaspo_niger/core/services/cache_service.dart';
import 'package:diaspo_niger/features/messages/data/datasources/message_remote_datasource.dart';
import 'package:diaspo_niger/features/messages/data/models/conversation_model.dart';
import 'package:diaspo_niger/features/messages/data/repositories/message_repository_impl.dart';
import 'package:diaspo_niger/features/messages/domain/entities/message_entity.dart';

/// « Message chiffré » qui ne s'en va pas — signalé sur Pixel 10 Pro XL le
/// 2026-09-16, dans deux cas : une discussion jamais ouverte sur l'appareil,
/// et un message reçu pendant que la liste est à l'écran.
///
/// Le clair d'un message chiffré n'existe que sur l'appareil : la liste le
/// reconstitue depuis le cache du fil. Quand le cache ne l'a pas encore,
/// `_rattraperMlsEnArrierePlan` le déchiffre en tâche de fond et le met en
/// cache — mais **rien ne redemandait la liste après coup**. Le texte était
/// donc sur l'appareil, prêt, et la tuile continuait d'afficher « Message
/// chiffré » jusqu'à un tirer-pour-rafraîchir, l'ouverture de la discussion,
/// ou le message suivant.
///
/// Deux garanties, une par bout :
/// - le rattrapage n'est **replanifié** que si quelque chose a bougé
///   (`rattrapageADeclencher`) — sinon chaque émission de la liste paierait
///   une requête, et un fil qui échoue tournerait en boucle ;
/// - une fois le déchiffrement en cache, la liste **rejoue**.

final _quand = DateTime.utc(2026, 9, 16, 5, 27, 40);

MessageEntity _message(String contenu) => MessageEntity(
  id: 'm1',
  senderId: 'autre',
  senderName: 'Sim A',
  content: contenu,
  type: MessageType.text,
  createdAt: _quand,
);

ConversationModel _conversation() => ConversationModel(
  id: 'c1',
  createdBy: 'moi',
  participantIds: const ['moi', 'autre'],
  // Une conversation basculée : le serveur n'a jamais le clair, donc pas
  // d'aperçu — seulement la date.
  lastMessage: null,
  lastMessageAt: _quand,
  lastMessageType: MessageType.text,
);

class _Source implements MessageRemoteDataSource {
  @override
  Stream<List<ConversationModel>> getConversations(String userId) =>
      Stream<List<ConversationModel>>.value([_conversation()]);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Cache implements CacheService {
  final Map<String, List<Map<String, dynamic>>> parConversation = {};

  @override
  Future<void> cacheConversations(
    List<Map<String, dynamic>> conversations,
  ) async {}

  @override
  Future<void> cacheMessages(
    String conversationId,
    List<Map<String, dynamic>> messages,
  ) async {
    parConversation[conversationId] = messages;
  }

  @override
  List<Map<String, dynamic>> getCachedMessages(
    String conversationId, {
    int? limit,
    String? beforeMessageId,
  }) => parConversation[conversationId] ?? const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Passerelle implements MlsGateway {
  _Passerelle(this.fil, {this.lenteur = Duration.zero});

  /// Ce que le déchiffrement rendrait. Vide = rien à rattraper.
  final List<MessageEntity> fil;

  /// Durée d'un déchiffrement (réseau + MLS).
  final Duration lenteur;
  int appelsMessages = 0;

  @override
  bool get actif => true;

  @override
  bool get aDesConversationsBasculees => true;

  @override
  Future<void> amorcerBascules(Iterable<String> conversationIds) async {}

  @override
  Future<Map<String, String>> apercusDejaDechiffres(
    Iterable<String> conversationIds,
  ) async => const {};

  @override
  Future<List<String>> conversationsARattraper(
    Iterable<String> conversationIds, {
    int maximum = 3,
  }) async => fil.isEmpty ? const [] : [...conversationIds];

  @override
  Future<List<MessageEntity>> messages(String conversationId) async {
    appelsMessages++;
    if (lenteur > Duration.zero) await Future<void>.delayed(lenteur);
    return fil;
  }

  /// Ce que la vue `mls_unread_counts` rendrait.
  Map<String, ({int nonLus, int mentions})> compteurs = const {};

  @override
  Future<Map<String, ({int nonLus, int mentions})>> nonLus() async => compteurs;

  final lectures = StreamController<void>.broadcast();

  @override
  Stream<void> get lecturesAvancees => lectures.stream;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Une liste qui bouge : chaque message reçu la fait réémettre, avec sa date.
class _SourceVivante implements MessageRemoteDataSource {
  final _flux = StreamController<List<ConversationModel>>.broadcast();
  DateTime? dernierQuand;
  String dernierTexte = '';

  void emettre(DateTime quand, String texte) {
    dernierQuand = quand;
    dernierTexte = texte;
    _flux.add([
      ConversationModel(
        id: 'c1',
        createdBy: 'moi',
        participantIds: const ['moi', 'autre'],
        lastMessage: null,
        lastMessageAt: quand,
        lastMessageType: MessageType.text,
      ),
    ]);
  }

  @override
  Stream<List<ConversationModel>> getConversations(String userId) =>
      _flux.stream;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Déchiffre toujours le dernier message que la source a annoncé.
class _PasserelleVivante extends _Passerelle {
  _PasserelleVivante(this.source) : super(const []);

  final _SourceVivante source;

  @override
  Future<List<String>> conversationsARattraper(
    Iterable<String> conversationIds, {
    int maximum = 3,
  }) async => [...conversationIds];

  @override
  Future<List<MessageEntity>> messages(String conversationId) async {
    appelsMessages++;
    return [
      MessageEntity(
        id: 'm$appelsMessages',
        senderId: 'autre',
        senderName: 'Sim A',
        content: source.dernierTexte,
        type: MessageType.text,
        createdAt: source.dernierQuand!,
      ),
    ];
  }
}

class _Reseau implements NetworkInfo {
  @override
  Future<bool> get isConnected async => true;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<List<String>> _apercusEmis(
  MessageRepositoryImpl depot, {
  Duration pendant = const Duration(milliseconds: 400),
}) async {
  final vus = <String>[];
  final sub = depot.getConversations('moi').listen((e) {
    e.fold((_) {}, (liste) => vus.add(liste.single.lastMessage ?? ''));
  });
  await Future<void>.delayed(pendant);
  await sub.cancel();
  return vus;
}

void main() {
  group('replanifier un rattrapage', () {
    test('une date jamais tentée le déclenche', () {
      expect(
        MessageRepositoryImpl.rattrapageADeclencher(
          candidats: {'c1': _quand},
          dejaTente: const {},
        ),
        isTrue,
      );
    });

    test('la même date, déjà tentée, ne le redéclenche pas', () {
      // C'est ce qui empêche un fil qui refuse de se déchiffrer d'être
      // redemandé à chaque émission de la liste.
      expect(
        MessageRepositoryImpl.rattrapageADeclencher(
          candidats: {'c1': _quand},
          dejaTente: {'c1': _quand},
        ),
        isFalse,
      );
    });

    test('un message plus récent rouvre la tentative', () {
      expect(
        MessageRepositoryImpl.rattrapageADeclencher(
          candidats: {'c1': _quand.add(const Duration(minutes: 1))},
          dejaTente: {'c1': _quand},
        ),
        isTrue,
      );
    });

    test('plus rien en attente : rien à faire', () {
      expect(
        MessageRepositoryImpl.rattrapageADeclencher(
          candidats: const {},
          dejaTente: {'c1': _quand},
        ),
        isFalse,
      );
    });
  });

  group('la liste rejoue après le rattrapage', () {
    test('la tuile sort directement avec son texte, sans passer par '
        '« Message chiffré »', () async {
      // 2026-09-21, SM A515F : la liste émettait avant de déchiffrer, et la
      // tuile d'un message reçu affichait « Message chiffré » ~2 s. Elle
      // attend désormais le déchiffrement (borné).
      final passerelle = _Passerelle(
        [_message('Bonjour')],
        lenteur: const Duration(milliseconds: 100),
      );
      final depot = MessageRepositoryImpl(
        remoteDataSource: _Source(),
        networkInfo: _Reseau(),
        cacheService: _Cache(),
        mlsGateway: passerelle,
      );

      final vus = await _apercusEmis(depot);

      expect(vus, ['Bonjour'],
          reason: 'une seule émission, déjà déchiffrée — pas de rejeu en '
              'double');
      expect(passerelle.appelsMessages, 1);
    });

    test('un déchiffrement trop lent ne fige pas la liste : elle sort, '
        'puis rejoue', () async {
      final passerelle = _Passerelle(
        [_message('Bonjour')],
        lenteur: const Duration(milliseconds: 300),
      );
      final depot = MessageRepositoryImpl(
        remoteDataSource: _Source(),
        networkInfo: _Reseau(),
        cacheService: _Cache(),
        mlsGateway: passerelle,
      )..attenteDechiffrementMax = const Duration(milliseconds: 100);

      final vus = await _apercusEmis(
        depot,
        pendant: const Duration(milliseconds: 600),
      );

      expect(vus.first, isEmpty,
          reason: 'au-delà de l\'attente, la liste sort sans le texte');
      expect(vus.last, 'Bonjour',
          reason: 'la passe abandonnée doit quand même faire rejouer');
      expect(passerelle.appelsMessages, 1);
    });

    test('un message reçu pendant le plancher est rattrapé à la fin, pas '
        'abandonné', () async {
      // Signalé le 2026-09-21 : les premiers messages d'un échange restaient
      // « Message chiffré » dans la liste. Le second arrivait moins de 5 s
      // après le premier, le rattrapage rendait la main sans rien reporter,
      // et la liste immobile n'émettait plus rien pour le relancer.
      final second = _quand.add(const Duration(seconds: 2));
      final source = _SourceVivante();
      final passerelle = _PasserelleVivante(source);
      final depot = MessageRepositoryImpl(
        remoteDataSource: source,
        networkInfo: _Reseau(),
        cacheService: _Cache(),
        mlsGateway: passerelle,
      )..espacementRattrapage = const Duration(milliseconds: 300);

      final vus = <String>[];
      final sub = depot.getConversations('moi').listen((e) {
        e.fold((_) {}, (liste) => vus.add(liste.single.lastMessage ?? ''));
      });
      source.emettre(_quand, 'Salut');
      await Future<void>.delayed(const Duration(milliseconds: 50));
      source.emettre(second, 'Ça va ?');
      await Future<void>.delayed(const Duration(milliseconds: 150));
      expect(
        vus.last,
        isEmpty,
        reason: 'encore dans le plancher : pas de deuxième passe',
      );
      await Future<void>.delayed(const Duration(milliseconds: 400));
      await sub.cancel();

      expect(
        vus.last,
        'Ça va ?',
        reason: 'la passe reportée doit déchiffrer le second message',
      );
      expect(passerelle.appelsMessages, 2);
    });

    test('une lecture chiffrée fait retomber la pastille sans attendre le '
        'serveur', () async {
      // 2026-09-21, SM A515F : « Testeurs » gardait 1 non lu en sortant de
      // la discussion, 0 en base. Lire un message chiffré n'écrit que dans
      // `mls_message_receipts` : la ligne `conversations` ne bouge pas, et
      // la liste ne se rejouait jamais.
      final passerelle = _Passerelle(const [])
        ..compteurs = {'c1': (nonLus: 2, mentions: 0)};
      final depot = MessageRepositoryImpl(
        remoteDataSource: _Source(),
        networkInfo: _Reseau(),
        cacheService: _Cache(),
        mlsGateway: passerelle,
      );

      final pastilles = <int>[];
      final sub = depot.getConversations('moi').listen((e) {
        e.fold((_) {}, (l) => pastilles.add(l.single.unreadCount['moi'] ?? 0));
      });
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(pastilles, [2]);

      passerelle.compteurs = {'c1': (nonLus: 0, mentions: 0)};
      passerelle.lectures.add(null);
      await Future<void>.delayed(const Duration(milliseconds: 500));
      await sub.cancel();

      expect(pastilles.last, 0,
          reason: "sans rejeu, la pastille reste sur l'ancien compte");
    });

    test('rien à rattraper : une seule émission, aucun rejeu', () async {
      final passerelle = _Passerelle(const []);
      final depot = MessageRepositoryImpl(
        remoteDataSource: _Source(),
        networkInfo: _Reseau(),
        cacheService: _Cache(),
        mlsGateway: passerelle,
      );

      final vus = await _apercusEmis(depot);

      expect(vus, hasLength(1));
      expect(passerelle.appelsMessages, 0);
    });
  });
}
