import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:diaspo_niger/core/services/cache_service.dart';
import 'package:diaspo_niger/features/messages/data/models/message_model.dart';
import 'package:diaspo_niger/features/messages/domain/entities/message_entity.dart';
import 'package:diaspo_niger/features/messages/presentation/widgets/message_bubble.dart';
import 'package:diaspo_niger/l10n/app_localizations.dart';

/// Les notices de gestion d'un groupe — « X a retiré Y du groupe », « X a nommé
/// Y admin », « X a retiré le rôle d'admin à Y » — sont écrites par le serveur
/// (RPC `exclure_du_groupe`, `nommer_admin_du_groupe`,
/// `retirer_admin_du_groupe`), et seulement hors MLS.
///
/// Le serveur envoie les **identités** dans `data.evenement`, pas la phrase.
/// C'est la leçon du séparateur de bascule : sa phrase française en dur était
/// servie telle quelle à un compte en anglais. Ce fichier verrouille les deux
/// moitiés — le modèle remonte l'évènement jusqu'à l'entité, et la bulle
/// compose la phrase dans la langue courante, à la bonne personne.
///
/// `data.content` porte quand même une phrase française : c'est le repli des
/// versions installées de l'app qui ignorent `evenement`. Le dernier test
/// vérifie que ce repli fonctionne, et qu'il n'est **pas** préféré au texte
/// localisé.
Future<void> _pump(
  WidgetTester tester,
  MessageEntity message, {
  Locale locale = const Locale('fr'),
  String currentUserId = 'lecteur',
}) async {
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        locale: locale,
        theme: ThemeData.light(),
        home: Scaffold(
          body: MessageBubble(
            message: message,
            isMe: false,
            currentUserId: currentUserId,
            skipAnimation: true,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

/// Une ligne `messages` telle que la RPC l'écrit, passée par le chemin réel du
/// datasource : `MessageModel.fromJson({...data, id, senderId, type, ...})`.
MessageEntity notice(
  String type, {
  String acteurId = 'admin',
  String acteurNom = 'Nasara',
  String cibleId = 'cible',
  String cibleNom = 'Hocine',
  String? content,
}) => MessageModel.fromJson({
  'content': content ?? 'phrase de repli',
  'senderName': '',
  'evenement': {
    'type': type,
    'acteurId': acteurId,
    'acteurNom': acteurNom,
    'cibleId': cibleId,
    'cibleNom': cibleNom,
  },
  'id': 'a3f1c2d4-0000-4000-8000-000000000009',
  'senderId': 'system',
  'type': 'system',
  'createdAt': '2026-09-17T01:32:00.000Z',
}).toEntity();

void main() {
  group('le modèle remonte `data.evenement`', () {
    test('jusqu\'à l\'entité, et la bulle le reconnaît comme système', () {
      final message = notice('membre_retire');

      expect(message.isSystem, isTrue);
      expect(message.estSeparateurMls, isFalse);
      expect(message.noticeDeGroupe, {
        'type': 'membre_retire',
        'acteurId': 'admin',
        'acteurNom': 'Nasara',
        'cibleId': 'cible',
        'cibleNom': 'Hocine',
      });
    });

    test('un message ordinaire ne porte aucune notice', () {
      final message = MessageModel.fromJson({
        'id': 'a3f1c2d4-0000-4000-8000-000000000001',
        'senderId': 'aicha',
        'senderName': 'Aïcha',
        'content': 'Salut',
        'type': 'text',
        'createdAt': '2026-09-17T01:32:00.000Z',
      }).toEntity();

      expect(message.noticeDeGroupe, isNull);
    });

    test('recopier le message ne perd pas la notice', () {
      final modele = MessageModel.fromEntity(notice('admin_nomme'));

      expect(modele.evenement?['type'], 'admin_nomme');
      expect(modele.copyWith(content: 'autre').evenement?['type'], 'admin_nomme');
    });
  });

  group('la phrase est composée à l\'affichage', () {
    testWidgets('exclusion vue par un tiers', (tester) async {
      await _pump(tester, notice('membre_retire'));

      expect(find.text('Nasara a retiré Hocine du groupe'), findsOne);
    });

    testWidgets('exclusion vue par celui qui a exclu', (tester) async {
      // « Vous a retiré Hocine » n'est pas du français : la voix « par vous »
      // est une phrase à part, pas un « Vous » injecté dans la précédente.
      await _pump(
        tester,
        notice('membre_retire', acteurId: 'lecteur'),
        currentUserId: 'lecteur',
      );

      expect(find.text('Vous avez retiré Hocine du groupe'), findsOne);
    });

    testWidgets('promotion vue par la personne nommée', (tester) async {
      await _pump(
        tester,
        notice('admin_nomme', cibleId: 'lecteur'),
        currentUserId: 'lecteur',
      );

      // Pas « vous a nommé admin » : « vous » placé avant le verbe impose
      // l'accord (« nommée » pour une lectrice), que la phrase ignore.
      expect(find.text("Nasara vous a confié le rôle d'admin"), findsOne);
    });

    testWidgets('promotion vue par un tiers', (tester) async {
      await _pump(tester, notice('admin_nomme'));

      expect(find.text('Nasara a nommé Hocine admin'), findsOne);
    });

    testWidgets('rétrogradation vue par la personne rétrogradée', (
      tester,
    ) async {
      await _pump(
        tester,
        notice('admin_retire', cibleId: 'lecteur'),
        currentUserId: 'lecteur',
      );

      expect(find.text('Nasara vous a retiré le rôle d\'admin'), findsOne);
    });

    testWidgets('rétrogradation vue par celui qui a rétrogradé', (
      tester,
    ) async {
      await _pump(
        tester,
        notice('admin_retire', acteurId: 'lecteur'),
        currentUserId: 'lecteur',
      );

      expect(find.text('Vous avez retiré le rôle d\'admin à Hocine'), findsOne);
    });

    testWidgets('en anglais, la notice est en anglais', (tester) async {
      // Le défaut d'origine du séparateur MLS : la phrase française servie
      // telle quelle. `content` en porte une, et ne doit pas gagner.
      await _pump(
        tester,
        notice(
          'membre_retire',
          content: 'Nasara a retiré Hocine du groupe',
        ),
        locale: const Locale('en'),
      );

      expect(find.text('Nasara removed Hocine from the group'), findsOne);
      expect(find.textContaining('retiré'), findsNothing);
    });

    testWidgets('un nom manquant ne laisse pas un trou dans la phrase', (
      tester,
    ) async {
      // `users.display_name` est nullable, et la RPC laisse alors `cibleNom`
      // vide plutôt que d'inventer un nom.
      await _pump(tester, notice('admin_nomme', cibleNom: '   '));

      expect(find.text('Nasara a nommé Inconnu admin'), findsOne);
    });

    testWidgets(
      'un type inconnu retombe sur le texte du serveur au lieu de disparaître',
      (tester) async {
        // Une notice posée par une migration plus récente que l'app installée.
        await _pump(
          tester,
          notice('groupe_renomme', content: 'Le groupe a été renommé'),
        );

        expect(find.text('Le groupe a été renommé'), findsOne);
      },
    );

    testWidgets('les notices déjà en base, sans `evenement`, s\'affichent', (
      tester,
    ) async {
      await _pump(
        tester,
        MessageModel.fromJson({
          'id': 'sys-1',
          'senderId': 'system',
          'senderName': '',
          'content': 'Aïcha a rejoint le groupe',
          'type': 'system',
          'createdAt': '2026-09-17T01:32:00.000Z',
        }).toEntity(),
      );

      expect(find.text('Aïcha a rejoint le groupe'), findsOne);
    });
  });

  // À l'ouverture d'une discussion, le fil s'affiche d'abord DEPUIS LE CACHE
  // (`_loadCacheSync`), écrit par `MessageModel.toJson()`. `evenement` n'y
  // figurait pas : la notice relue du cache retombait sur `content`, en
  // français et à la troisième personne — « Nasara a retiré Hocine » sous les
  // yeux de Nasara, et en français pour un compte anglais. Le réseau corrigeait
  // ensuite ; hors ligne, jamais.
  group('relue du cache local', () {
    const conversation = 'c9d0e1f2-0000-4000-8000-000000000042';
    late Directory dossier;

    setUpAll(() async {
      dossier = Directory.systemTemp.createTempSync('notices_cache_test');
      Hive.init(dossier.path);
      await CacheService.instance.initialize();
    });

    tearDownAll(() async {
      await Hive.close();
      dossier.deleteSync(recursive: true);
    });

    /// Le chemin réel : écriture par `cacheMessages(… toJson())`, relecture par
    /// `getCachedMessages` puis `MessageModel.fromJson(m).toEntity()`, comme
    /// `MessageRepositoryImpl.getCachedMessages`.
    Future<MessageEntity> allerRetourParLeCache(MessageEntity message) async {
      await CacheService.instance.cacheMessages(conversation, [
        MessageModel.fromEntity(message).toJson(),
      ]);
      final relus = CacheService.instance.getCachedMessages(conversation);
      return MessageModel.fromJson(
        relus.singleWhere((m) => m['id'] == message.id),
      ).toEntity();
    }

    test('la notice garde son évènement', () async {
      final relue = await allerRetourParLeCache(
        notice('admin_retire', cibleId: 'lecteur'),
      );

      expect(relue.noticeDeGroupe, {
        'type': 'admin_retire',
        'acteurId': 'admin',
        'acteurNom': 'Nasara',
        'cibleId': 'lecteur',
        'cibleNom': 'Hocine',
      });
    });

    testWidgets('et la bulle dit toujours « Vous », dans la langue du lecteur', (
      tester,
    ) async {
      final relue = (await tester.runAsync(
        () => allerRetourParLeCache(
          notice(
            'membre_retire',
            acteurId: 'lecteur',
            content: 'Nasara a retiré Hocine du groupe',
          ),
        ),
      ))!;

      await _pump(tester, relue, currentUserId: 'lecteur');
      expect(find.text('Vous avez retiré Hocine du groupe'), findsOne);
      expect(find.text('Nasara a retiré Hocine du groupe'), findsNothing);

      await _pump(
        tester,
        relue,
        currentUserId: 'lecteur',
        locale: const Locale('en'),
      );
      expect(find.text('You removed Hocine from the group'), findsOne);
    });
  });
}
