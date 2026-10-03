import 'dart:async';
import 'dart:convert';

import 'package:diaspo_niger/core/services/offline_queue_service.dart';
import 'package:diaspo_niger/features/messages/domain/entities/message_entity.dart';
import 'package:diaspo_niger/features/messages/presentation/providers/message_pagination_state.dart';
import 'package:diaspo_niger/features/messages/presentation/providers/message_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// L'échec définitif d'un envoi, et la fenêtre du renvoi automatique.
///
/// **Écran fermé.** L'échec arrive après les nouvelles tentatives — des
/// secondes après le tap. Si l'utilisateur est sorti entre-temps, l'écran
/// (`paginatedMessagesProvider`, autoDispose) n'existe plus. L'ancien code le
/// relisait pour y marquer l'échec : il en recréait une instance vide, le
/// message n'y était pas, et rien ne le mettait de côté. Perdu sans trace.
///
/// **Fenêtre de 24 h.** Un renvoi recrée le message sous un nouvel
/// identifiant, daté de maintenant. S'il échouait encore, l'entrée de file
/// prenait cette date : le battement de 60 s repoussait la fenêtre à chaque
/// essai, et un message écrit il y a trois jours partait à l'improviste.
void main() {
  final refProvider = Provider<Ref>((ref) => ref);
  final t0 = DateTime.utc(2026, 10, 3, 9);

  MessageEntity optimiste({String id = 'temp_1', DateTime? quand}) =>
      MessageEntity(
        id: id,
        senderId: 'u1',
        senderName: 'Moi',
        content: 'à ne pas perdre',
        type: MessageType.text,
        status: MessageStatus.sending,
        createdAt: quand ?? t0,
        readBy: const [],
        readAt: const {},
      );

  group('échec définitif', () {
    test('écran fermé : le message part dans la file, marqué en échec',
        () async {
      final file = _File();
      final conteneur = ProviderContainer(overrides: [
        offlineQueueServiceProvider.overrideWithValue(file),
      ]);
      addTearDown(conteneur.dispose);

      await signalerEnvoiEnEchec(
          conteneur.read(refProvider), 'c1', optimiste());

      expect(file.entrees, hasLength(1));
      final e = file.entrees.single;
      expect(e.id, 'temp_1');
      expect(e.conversationId, 'c1');
      expect(e.content, 'à ne pas perdre');
      expect(e.createdAt, t0);
      expect(jsonDecode(e.messageJson!)['status'], 'failed');
      // Et sans avoir ressuscité un écran vide pour le savoir.
      expect(conteneur.exists(paginatedMessagesProvider('c1')), isFalse);
    });

    test('écran ouvert : la bulle passe en échec, une seule entrée en file',
        () async {
      final file = _File();
      final ecran = _Ecran(file);
      final conteneur = ProviderContainer(overrides: [
        offlineQueueServiceProvider.overrideWithValue(file),
        paginatedMessagesProvider.overrideWith((ref, id) => ecran),
      ]);
      addTearDown(conteneur.dispose);
      conteneur.listen(paginatedMessagesProvider('c1'), (_, __) {});

      await signalerEnvoiEnEchec(
          conteneur.read(refProvider), 'c1', optimiste());

      expect(ecran.marques, ['temp_1:failed']);
      expect(file.entrees.map((e) => e.id), ['temp_1'],
          reason: 'la mise de côté de l\'écran trouve l\'entrée déjà là');
    });

    test('déjà en file : pas de doublon, la file est ouverte avant la question',
        () async {
      final file = _File();
      final conteneur = ProviderContainer(overrides: [
        offlineQueueServiceProvider.overrideWithValue(file),
      ]);
      addTearDown(conteneur.dispose);
      final ref = conteneur.read(refProvider);

      await signalerEnvoiEnEchec(ref, 'c1', optimiste());
      await signalerEnvoiEnEchec(ref, 'c1', optimiste());

      expect(file.entrees, hasLength(1));
      expect(file.ouvertureAvantQuestion, isTrue);
    });
  });

  group('date d\'écriture d\'origine', () {
    test('un renvoi raté garde la date d\'origine, pas celle de l\'essai',
        () async {
      final file = _File();
      final conteneur = ProviderContainer(overrides: [
        offlineQueueServiceProvider.overrideWithValue(file),
      ]);
      addTearDown(conteneur.dispose);
      final ecritLe = t0.subtract(const Duration(hours: 23));

      await signalerEnvoiEnEchec(
        conteneur.read(refProvider),
        'c1',
        optimiste(id: 'temp_2', quand: t0),
        ecritLe: ecritLe,
      );

      expect(file.entrees.single.createdAt, ecritLe);
    });

    test('une entrée posée plus tôt par le délai de l\'écran est corrigée',
        () async {
      final file = _File();
      final conteneur = ProviderContainer(overrides: [
        offlineQueueServiceProvider.overrideWithValue(file),
      ]);
      addTearDown(conteneur.dispose);
      final ref = conteneur.read(refProvider);
      final ecritLe = t0.subtract(const Duration(hours: 23));

      // Le délai de 30 s de l'écran met de côté avec la date de l'essai…
      await mettreDeCoteEnEchec(file, 'c1', optimiste(id: 'temp_3'));
      expect(file.entrees.single.createdAt, t0);
      // …puis l'échec définitif arrive, avec la date d'origine.
      await signalerEnvoiEnEchec(ref, 'c1', optimiste(id: 'temp_3'),
          ecritLe: ecritLe);

      expect(file.entrees, hasLength(1));
      expect(file.entrees.single.createdAt, ecritLe);
    });

    test('une date d\'origine n\'est jamais rajeunie', () async {
      final file = _File();
      final ancienne = t0.subtract(const Duration(hours: 30));
      await mettreDeCoteEnEchec(file, 'c1', optimiste(id: 'temp_4'),
          ecritLe: ancienne);

      await mettreDeCoteEnEchec(file, 'c1', optimiste(id: 'temp_4'),
          ecritLe: t0);

      expect(file.entrees.single.createdAt, ancienne);
    });

    test('le renvoi automatique transmet la date de l\'entrée, et au-delà de '
        '24 h ne renvoie plus', () async {
      final file = _File();
      final envois = _EnvoisQuiEchouent();
      final conteneur = ProviderContainer(overrides: [
        offlineQueueServiceProvider.overrideWithValue(file),
        sendMessageProvider.overrideWith((ref) => envois..ref = ref),
      ]);
      addTearDown(conteneur.dispose);
      final renvoi = RenvoiMessagesEnAttente(conteneur.read(refProvider));

      final ecritLe = DateTime.now().subtract(const Duration(hours: 23));
      await mettreDeCoteEnEchec(file, 'c1', optimiste(id: 'temp_a'),
          ecritLe: ecritLe);

      // Premier battement : renvoi tenté, raté, ré-enregistré sous un nouvel
      // identifiant — mais avec la date d'origine.
      await renvoi.renvoyerCeQuiPeutPartir();
      expect(envois.dates, [ecritLe]);
      expect(file.entrees.map((e) => e.id), ['temp_a_bis']);
      expect(file.entrees.single.createdAt, ecritLe);

      // L'entrée a désormais plus de 24 h : plus de renvoi automatique, et
      // elle reste en file — visible, renvoyable à la main.
      file.vieillir(const Duration(hours: 2));
      await renvoi.renvoyerCeQuiPeutPartir();
      expect(envois.dates, hasLength(1));
      expect(file.entrees, hasLength(1));
    });
  });
}

/// La file, en mémoire. `isInQueue` ne répond qu'une fois ouverte, comme la
/// vraie, dont la boîte Hive est nulle avant `init()`.
class _File extends OfflineQueueService {
  final entrees = <PendingMessage>[];
  bool _ouverte = false;
  bool ouvertureAvantQuestion = true;

  @override
  Future<void> init() async => _ouverte = true;

  @override
  List<PendingMessage> getQueue() => List.of(entrees);

  @override
  bool isInQueue(String messageId) {
    if (!_ouverte) ouvertureAvantQuestion = false;
    return _ouverte && entrees.any((m) => m.id == messageId);
  }

  @override
  Future<void> enqueue(PendingMessage message) async => entrees.add(message);

  @override
  Future<void> dequeue(String messageId) async =>
      entrees.removeWhere((m) => m.id == messageId);

  void vieillir(Duration d) {
    final vieillies = [
      for (final e in entrees)
        PendingMessage(
          id: e.id,
          conversationId: e.conversationId,
          senderId: e.senderId,
          senderName: e.senderName,
          content: e.content,
          type: e.type,
          createdAt: e.createdAt.subtract(d),
          messageJson: e.messageJson,
        ),
    ];
    entrees
      ..clear()
      ..addAll(vieillies);
  }
}

/// L'écran : marque la bulle, et met de côté comme le vrai le fait.
class _Ecran extends StateNotifier<MessagePaginationState>
    implements PaginatedMessagesNotifier {
  _Ecran(this.file) : super(const MessagePaginationState());

  final OfflineQueueService file;
  final marques = <String>[];

  @override
  void updateMessageStatus(String messageId, MessageStatus newStatus) {
    marques.add('$messageId:${newStatus.name}');
    unawaited(mettreDeCoteEnEchec(
      file,
      'c1',
      MessageEntity(
        id: messageId,
        senderId: 'u1',
        senderName: 'Moi',
        content: 'copie de l\'écran',
        type: MessageType.text,
        status: newStatus,
        createdAt: DateTime.utc(2026, 10, 3, 9),
        readBy: const [],
        readAt: const {},
      ),
    ));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Les envois, qui échouent tous — comme le vrai `sendText` en fin de
/// tentatives : l'ancienne entrée est retirée, la nouvelle copie (nouvel id,
/// datée de maintenant) part en échec par [signalerEnvoiEnEchec].
class _EnvoisQuiEchouent extends SendMessageNotifier {
  _EnvoisQuiEchouent() : super(_RefInutile());

  late Ref ref;
  final dates = <DateTime?>[];

  @override
  Future<bool> retryFailedMessage({
    required String conversationId,
    required MessageEntity failedMessage,
    DateTime? ecritLe,
  }) async {
    dates.add(ecritLe);
    await ref.read(offlineQueueServiceProvider).dequeue(failedMessage.id);
    await signalerEnvoiEnEchec(
      ref,
      conversationId,
      failedMessage.copyWith(
        id: '${failedMessage.id}_bis',
        status: MessageStatus.sending,
        createdAt: DateTime.now(),
      ),
      ecritLe: ecritLe,
    );
    return false;
  }
}

class _RefInutile implements Ref {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
