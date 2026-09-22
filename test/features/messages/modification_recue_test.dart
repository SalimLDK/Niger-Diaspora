import 'package:flutter_test/flutter_test.dart';

import 'package:diaspo_niger/core/services/e2ee/undecryptable_placeholders.dart';
import 'package:diaspo_niger/features/messages/domain/entities/message_entity.dart';
import 'package:diaspo_niger/features/messages/presentation/providers/modification_recue.dart';

/// Une modification de texte reçue par le flux des mises à jour n'atteignait
/// pas la discussion ouverte : l'écran ne reprenait que les métadonnées de la
/// ligne brute. Elle est maintenant relue déchiffrée, une fois par version.
final _envoi = DateTime.utc(2026, 9, 21, 10);
final _v1 = DateTime.utc(2026, 9, 21, 10, 5);
final _v2 = DateTime.utc(2026, 9, 21, 10, 7);

MessageEntity _message(
  String contenu, {
  DateTime? editedAt,
  String senderId = 'autre',
}) => MessageEntity(
  id: 'm1',
  senderId: senderId,
  senderName: 'Sim A',
  content: contenu,
  type: MessageType.text,
  createdAt: _envoi,
  editedAt: editedAt,
);

void main() {
  group('modificationPlusRecente', () {
    test('aucune date reçue : pas une modification', () {
      expect(modificationPlusRecente(affichee: null, recue: null), isFalse);
      expect(modificationPlusRecente(affichee: _v1, recue: null), isFalse);
    });

    test('première modification d\'un message jamais modifié', () {
      expect(modificationPlusRecente(affichee: null, recue: _v1), isTrue);
    });

    test('même version : un accusé de lecture ne relance rien', () {
      expect(modificationPlusRecente(affichee: _v1, recue: _v1), isFalse);
    });

    test('version plus récente, et fuseaux mêlés', () {
      expect(modificationPlusRecente(affichee: _v1, recue: _v2), isTrue);
      // L'optimiste pose une date locale, le serveur une date UTC : c'est
      // l'instant qui compte.
      expect(
        modificationPlusRecente(affichee: _v2.toLocal(), recue: _v1),
        isFalse,
      );
    });
  });

  group('fusionnerLigneBrute', () {
    // La ligne brute : contenu chiffré au repos, annexes réduites au blob.
    MessageEntity brut({
      bool supprime = false,
      DateTime? editedAt,
    }) => MessageEntity(
      id: 'm1',
      senderId: 'autre',
      senderName: 'Sim A',
      content: supprime ? '' : 'v1:Q0hJRkZSRQ==',
      type: MessageType.text,
      createdAt: _envoi,
      readBy: const ['autre', 'moi'],
      editedAt: editedAt,
      deletedForEveryone: supprime,
    );

    final affiche = MessageEntity(
      id: 'm1',
      senderId: 'autre',
      senderName: 'Sim A',
      content: 'regarde ce post',
      type: MessageType.text,
      createdAt: _envoi,
      fileUrl: 'https://exemple.test/photo.jpg',
      postData: const {'postId': 'p1', 'content': 'extrait'},
      linkPreviewData: const {'url': 'https://exemple.test'},
    );

    test('accusé de lecture : métadonnées de la ligne, contenu de l\'écran', () {
      final resultat = fusionnerLigneBrute(affiche: affiche, brut: brut());
      expect(resultat.readBy, ['autre', 'moi']);
      expect(resultat.content, 'regarde ce post');
      expect(resultat.fileUrl, affiche.fileUrl);
      expect(resultat.postData, affiche.postData);
      expect(resultat.linkPreviewData, affiche.linkPreviewData);
    });

    test('la date de modification n\'avance pas sans le texte', () {
      final resultat = fusionnerLigneBrute(
        affiche: affiche,
        brut: brut(editedAt: _v1),
      );
      expect(resultat.editedAt, isNull);
      expect(resultat.content, 'regarde ce post');
    });

    test('supprimé pour tout le monde : rien de l\'écran ne survit', () {
      final resultat = fusionnerLigneBrute(
        affiche: affiche,
        brut: brut(supprime: true),
      );
      expect(resultat.deletedForEveryone, isTrue);
      // Avant : la pierre tombale s'affichait, mais texte, carte et fichier
      // restaient dans l'état de l'écran.
      expect(resultat.content, isEmpty);
      expect(resultat.fileUrl, isNull);
      expect(resultat.postData, isNull);
      expect(resultat.linkPreviewData, isNull);
      expect(resultat.readBy, ['autre', 'moi']);
    });
  });

  group('suppression MLS : sansContenuSupprime', () {
    // Ce que rend `MlsGateway._avecMetadonnees` pour un message supprimé :
    // le drapeau recollé sur l'entité DÉCHIFFRÉE, tout le reste intact.
    final supprimeMls = MessageEntity(
      id: 'mls-1',
      senderId: 'autre',
      senderName: 'Sim A',
      content: 'PA6SECRET',
      type: MessageType.image,
      createdAt: _envoi,
      localFilePath: '/data/user/0/cache/photo_dechiffree.jpg',
      fileUrl: 'https://exemple.test/blob',
      fileName: 'vacances.jpg',
      thumbnailUrl: 'https://exemple.test/vignette',
      replyToId: 'mls-0',
      replyToMessageData: const {'content': 'cité'},
      linkPreviewData: const {'url': 'https://exemple.test'},
      editedAt: _v1,
      readBy: const ['autre', 'moi'],
      reactions: const {'moi': '👍'},
      clientMessageId: 'cid-1',
      deletedForEveryone: true,
    );
    final vivant = _message('toujours là');

    test('le clair, le fichier, les cartes et la citation partent', () {
      final [coquille] = sansContenuSupprime([supprimeMls]);
      expect(coquille.content, isEmpty);
      expect(coquille.localFilePath, isNull);
      expect(coquille.fileUrl, isNull);
      expect(coquille.fileName, isNull);
      expect(coquille.thumbnailUrl, isNull);
      expect(coquille.replyToId, isNull);
      expect(coquille.replyToMessageData, isNull);
      expect(coquille.linkPreviewData, isNull);
      expect(coquille.editedAt, isNull);
      expect(coquille.reactions, isEmpty);
    });

    test('ce qui fait la bulle et le dédoublonnage reste', () {
      final [coquille] = sansContenuSupprime([supprimeMls]);
      expect(coquille.id, 'mls-1');
      expect(coquille.senderId, 'autre');
      expect(coquille.createdAt, _envoi);
      expect(coquille.type, MessageType.image);
      expect(coquille.deletedForEveryone, isTrue);
      expect(coquille.readBy, ['autre', 'moi']);
      // L'écho d'une suppression est rapproché par `clientMessageId`.
      expect(coquille.clientMessageId, 'cid-1');
    });

    test('les autres messages ne sont pas touchés', () {
      final resultat = sansContenuSupprime([vivant, supprimeMls]);
      expect(resultat.first, same(vivant));
    });

    test('aucune suppression : la liste elle-même, sans copie', () {
      final liste = [vivant];
      expect(sansContenuSupprime(liste), same(liste));
    });

    test('idempotent : vider une coquille ne change rien', () {
      final une = sansContenuSupprime([supprimeMls]);
      expect(sansContenuSupprime(une), une);
    });
  });

  group('appliquerModificationRelue', () {
    test('une relecture revenue après la suppression ne ressuscite rien', () {
      final tombe = MessageEntity(
        id: 'm1',
        senderId: 'autre',
        senderName: 'Sim A',
        content: '',
        type: MessageType.text,
        createdAt: _envoi,
        deletedForEveryone: true,
      );
      expect(
        appliquerModificationRelue(
          affiche: tombe,
          relu: _message('bonsoir', editedAt: _v1),
          estAMoi: false,
        ),
        same(tombe),
      );
      final affiche = _message('bonjour');
      expect(
        appliquerModificationRelue(
          affiche: affiche,
          relu: tombe.copyWith(editedAt: _v1),
          estAMoi: false,
        ),
        same(affiche),
      );
    });

    test('le nouveau texte et sa date remplacent l\'ancien', () {
      final resultat = appliquerModificationRelue(
        affiche: _message('bonjour'),
        relu: _message('bonsoir', editedAt: _v1),
        estAMoi: false,
      );
      expect(resultat.content, 'bonsoir');
      expect(resultat.editedAt, _v1);
    });

    test('une relecture plus ancienne que l\'affiché ne recule pas', () {
      final affiche = _message('troisième', editedAt: _v2);
      final resultat = appliquerModificationRelue(
        affiche: affiche,
        relu: _message('deuxième', editedAt: _v1),
        estAMoi: false,
      );
      expect(resultat, same(affiche));
    });

    for (final illisible in kUndecryptablePlaceholders) {
      test('destinataire, « $illisible » : texte et date inchangés', () {
        final affiche = _message('bonjour');
        final resultat = appliquerModificationRelue(
          affiche: affiche,
          relu: _message(illisible, editedAt: _v1),
          estAMoi: false,
        );
        // La date n'avance pas : une session rétablie retentera.
        expect(resultat, same(affiche));
      });

      test('auteur, « $illisible » : texte gardé, date adoptée', () {
        // L'optimiste a déjà posé le texte clair ; l'auteur ne peut pas
        // déchiffrer son propre message.
        final resultat = appliquerModificationRelue(
          affiche: _message('bonsoir', editedAt: _envoi, senderId: 'moi'),
          relu: _message(illisible, editedAt: _v1, senderId: 'moi'),
          estAMoi: true,
        );
        expect(resultat.content, 'bonsoir');
        expect(resultat.editedAt, _v1);
      });
    }
  });
}
