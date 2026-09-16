import 'package:diaspo_niger/features/messages/domain/entities/conversation_entity.dart';
import 'package:diaspo_niger/features/messages/presentation/providers/message_provider.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ce que ces tests protègent
/// --------------------------
/// « Mes notes » était la seule discussion de la liste à faire un aller-retour
/// réseau **avant** d'ouvrir son écran : un spinner sur la tuile à chaque
/// ouverture, là où toutes les autres s'ouvrent d'un `context.push` synchrone.
///
/// Ce prix était celui d'un correctif, pas d'un oubli. Le raccourci d'origine
/// a été retiré le 2026-08-06 parce qu'il lisait le **cache Hive** : une
/// conversation effacée côté serveur y reste, on ouvrait alors un document
/// fantôme, l'écran annonçait « Ce groupe a été supprimé » et tout envoi
/// échouait ensuite (« Non envoyé · Réessayer », constaté sur appareil).
///
/// `conversationSure` rétablit le raccourci **sans** rouvrir ce trou : elle ne
/// fait confiance à la liste que lorsque celle-ci vient du flux Supabase
/// vivant, qui retire une conversation supprimée — jamais à sa copie Hive.
///
/// La régression que ces tests empêchent est silencieuse des deux côtés : la
/// laisser trop stricte ne fait « que » réinstaller le spinner, la laisser
/// trop permissive réinstalle la panne d'envoi de 2026-08-06.
void main() {
  ConversationEntity conv(String id) => ConversationEntity(
    id: id,
    type: ConversationType.individual,
    participantIds: const ['user-moi'],
    createdAt: DateTime(2026),
    createdBy: 'user-moi',
  );

  ConversationEntity? sure({
    required bool listeDepuisReseau,
    ConversationEntity? deLaListe,
    ConversationEntity? deLaDerniereReponse,
  }) => EnsureSelfNotesNotifier.conversationSure(
    listeDepuisReseau: listeDepuisReseau,
    deLaListe: deLaListe,
    deLaDerniereReponse: deLaDerniereReponse,
  );

  group('liste venue du réseau : elle fait foi', () {
    test('elle porte la conversation → ouverture immédiate, aucune requête', () {
      final c = conv('conv-notes');
      expect(sure(listeDepuisReseau: true, deLaListe: c)?.id, 'conv-notes');
    });

    test(
      'elle ne la porte pas → absence constatée, pas ignorance : on interroge',
      () {
        // Le flux vivant retire une conversation supprimée. Son silence est
        // donc une information, et c'est `ensure` qui doit recréer.
        expect(sure(listeDepuisReseau: true, deLaListe: null), isNull);
      },
    );

    test(
      "elle l'emporte sur la dernière réponse mémorisée, qui peut être périmée",
      () {
        // Le cas exact de 2026-08-06, à l'envers : la conversation a été
        // supprimée depuis notre dernière requête. Rendre celle qu'on a
        // mémorisée rouvrirait le document fantôme.
        expect(
          sure(
            listeDepuisReseau: true,
            deLaListe: null,
            deLaDerniereReponse: conv('conv-effacee'),
          ),
          isNull,
        );
      },
    );
  });

  group('liste encore sur sa copie Hive : elle ne prouve rien', () {
    test('cache seul → jamais de raccourci, même si le cache la porte', () {
      // C'est précisément la source qui a coûté la panne : on l'ignore.
      expect(
        sure(listeDepuisReseau: false, deLaListe: conv('conv-fantome')),
        isNull,
      );
    });

    test(
      'sauf réponse du serveur déjà obtenue dans cette session, qui fait foi',
      () {
        // Démarrage à froid puis passage hors ligne : `getOrCreate` a répondu,
        // le notifier n'est pas `autoDispose`, sa réponse vaut pour tout le
        // processus. Mieux que de relancer une requête qui échouera.
        final c = conv('conv-notes');
        expect(
          sure(
            listeDepuisReseau: false,
            deLaListe: conv('conv-du-cache'),
            deLaDerniereReponse: c,
          )?.id,
          'conv-notes',
        );
      },
    );

    test('rien de connu → on interroge le serveur', () {
      expect(sure(listeDepuisReseau: false), isNull);
    });
  });
}
