import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:diaspo_niger/features/messages/domain/entities/conversation_entity.dart';
import 'package:diaspo_niger/features/messages/presentation/widgets/conversation_item.dart';
import 'package:diaspo_niger/features/messages/presentation/widgets/messages_skeleton.dart';
import 'package:diaspo_niger/features/profile/domain/entities/profile_entity.dart';
import 'package:diaspo_niger/features/profile/presentation/providers/profile_provider.dart';
import 'package:diaspo_niger/l10n/app_localizations.dart';

/// Ce que la liste des discussions montrait pendant qu'elle chargeait.
///
/// Mesuré le 2026-09-15 sur Pixel 10 Pro XL, rafale de captures pendant un
/// démarrage à froid ouvert directement sur `/messages` :
///
/// | | t≈0 | t≈0,8 s | t≈3,2 s |
/// |---|---|---|---|
/// | Nom | **Utilisateur** | Sim A | Sim A |
/// | Aperçu | **Message chiffré** | **Message chiffré** | Vous: good |
///
/// Deux causes sans rapport, et aucune des deux n'est un « chargement » que
/// l'écran connaissait :
///
/// 1. `l10n.user` (« Utilisateur ») est le repli du nom quand le flux de
///    profil n'a encore rien émis. Au démarrage il n'a rien émis pour
///    personne, donc **toutes** les lignes à tête-à-tête l'affichaient, avec
///    l'initiale « U » dans l'avatar.
/// 2. « Message chiffré » venait d'ailleurs : `getCachedConversations()` — la
///    première émission, celle qui s'affiche — ne reconstruisait pas l'aperçu
///    depuis le cache local déchiffré, alors que le chemin réseau le fait
///    (`_completerAvecMls`). L'appareil avait le texte sous la main et
///    affichait un libellé générique en attendant le réseau.
const _autre = 'autre-utilisateur';

ConversationEntity _conversation() => ConversationEntity(
      id: 'c1',
      type: ConversationType.individual,
      participantIds: const ['moi', _autre],
      createdBy: 'moi',
      createdAt: DateTime.utc(2026, 9, 1),
      lastMessage: 'Tu as les papiers ?',
      lastMessageAt: DateTime.utc(2026, 9, 15, 18),
    );

ProfileEntity _profil() => ProfileEntity(
      id: _autre,
      email: 'aicha@example.com',
      displayName: 'Aïcha Moussa',
      createdAt: DateTime.utc(2026, 9, 1),
    );

Future<void> _pump(
  WidgetTester tester, {
  required Stream<ProfileEntity?> profil,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        userStreamProvider(_autre).overrideWith((ref) => profil),
      ],
      child: MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('fr'),
        theme: ThemeData.light(),
        home: Scaffold(
          body: ConversationItem(
            conversation: _conversation(),
            currentUserId: 'moi',
            flat: true,
            onTap: () {},
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  group('« Utilisateur » ne s\'affiche plus pendant la lecture du profil', () {
    testWidgets('profil en cours de lecture : un bloc d\'attente', (
      tester,
    ) async {
      // Un contrôleur qui n'émet ni ne ferme : le flux reste en `loading`,
      // exactement l'état du démarrage à froid.
      final jamais = StreamController<ProfileEntity?>();
      addTearDown(jamais.close);

      await _pump(tester, profil: jamais.stream);

      expect(find.text('Utilisateur'), findsNothing);
      expect(find.byType(SkeletonBlock), findsWidgets);
      // L'heure et l'aperçu, eux, sont connus : ils restent affichés.
      expect(find.text('Tu as les papiers ?'), findsOne);
    });

    testWidgets('profil arrivé : le vrai nom, plus de bloc', (tester) async {
      await _pump(tester, profil: Stream.value(_profil()));
      await tester.pump();

      expect(find.text('Aïcha Moussa'), findsOne);
      expect(find.byType(SkeletonBlock), findsNothing);
    });

    testWidgets('lecture terminée sans profil : « Utilisateur » revient', (
      tester,
    ) async {
      // Compte supprimé, identifiant inconnu : « Utilisateur » est alors la
      // réponse honnête. Sans cette distinction, la ligne resterait grise à
      // vie — c'est pourquoi la garde porte sur `isLoading`, pas sur « profil
      // nul ».
      await _pump(tester, profil: Stream<ProfileEntity?>.value(null));
      await tester.pump();

      expect(find.text('Utilisateur'), findsOne);
      expect(find.byType(SkeletonBlock), findsNothing);
    });
  });

  group('l\'aperçu chiffré est reconstruit dès l\'émission du cache', () {
    // Le comportement de `apercuDepuisCache` est déjà tenu par
    // `apercu_message_supprime_test.dart`. Ce qui manquait, et qui se voyait
    // à l'écran, c'est qu'il ne soit **pas appelé** sur le chemin du cache.
    test('getCachedConversations applique la reconstruction', () {
      final source = File(
        'lib/features/messages/data/repositories/message_repository_impl.dart',
      ).readAsStringSync().replaceAll('\r\n', '\n');

      final debut = source.indexOf(
        'Either<Failure, List<ConversationEntity>> getCachedConversations() {',
      );
      expect(debut, isNot(-1), reason: 'méthode introuvable');

      final fin = source.indexOf('\n  }', debut);
      final corps = source.substring(debut, fin);

      expect(
        corps,
        contains('_apercuDepuisLeCache('),
        reason: 'le cache réafficherait « Message chiffré » au démarrage',
      );
    });
  });
}
