import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Le flux des nouveaux messages ne compare plus deux horloges.
///
/// `created_at` venait du téléphone de l'expéditeur ; le flux du destinataire
/// jetait tout INSERT antérieur au dernier message chargé. Une horloge en
/// retard de deux minutes : le message n'apparaissait pas en direct, puis
/// reparaissait au rechargement, rangé dans le passé. Et le premier
/// abonnement ne rattrapait rien : un message écrit entre la lecture initiale
/// et l'arrivée sur le canal n'était livré par personne.
///
/// Le canal temps réel est un websocket : ce banc tient la structure, la
/// migration 20261004090000 tient la date (tools/rls_tests/), et le reste se
/// vérifie sur appareil (TESTS_APPAREIL_A_FAIRE.md, § 2).
void main() {
  String corpsDe(String fichier, String debut, String fin) {
    final source = File(fichier).readAsStringSync();
    final i = source.indexOf(debut);
    expect(i, isNot(-1), reason: debut);
    final j = source.indexOf(fin, i + debut.length);
    expect(j, isNot(-1), reason: fin);
    return source.substring(i, j);
  }

  String flux() => corpsDe(
        'lib/features/messages/data/datasources/message_supabase_datasource.dart',
        'Stream<List<MessageModel>> getNewMessagesStream(',
        'Stream<void> mlsNouveauxMessages(',
      );

  test('le temps réel ne filtre plus sur la date', () {
    expect(flux(), isNot(contains('isAfter(afterTimestamp)')));
  });

  test('rattrapage dès le premier abonnement', () {
    expect(flux(), contains('desLePremier: true'));
  });

  test('une ligne n\'est livrée — donc déchiffrée — qu\'une fois', () {
    // Rattrapage et temps réel peuvent rapporter la même ligne : la
    // déchiffrer deux fois échoue (Signal a consommé sa clé).
    expect('livres.add('.allMatches(flux()).length, 2);
  });

  test('l\'écho d\'un sticker se rapproche à l\'horloge locale', () {
    final ecoute = corpsDe(
      'lib/features/messages/presentation/providers/message_provider.dart',
      'void _listenForNewMessages(',
      'void _listenForMessageUpdates(',
    );
    expect(ecoute, isNot(contains('.difference(newMessage.createdAt)')),
        reason: 'date du serveur contre date du téléphone');
    expect(ecoute, contains('maintenant'));
  });

  test('la borne d\'une discussion vide n\'est plus l\'horloge du téléphone',
      () {
    final source = File(
      'lib/features/messages/presentation/providers/message_provider.dart',
    ).readAsStringSync();
    expect(
      source,
      isNot(contains(
          ': DateTime.now().subtract(const Duration(seconds: 10));')),
    );
  });
}
