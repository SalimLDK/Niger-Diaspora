import 'dart:io';

import 'package:diaspo_niger/features/messages/domain/entities/conversation_entity.dart';
import 'package:diaspo_niger/features/messages/presentation/widgets/conversation_picker_sheet.dart';
import 'package:flutter_test/flutter_test.dart';

/// Garde-fou : un seul endroit résout une conversation en « nom + avatar ».
///
/// Trois sélecteurs — partage d'un post, transfert d'un message, contenu reçu
/// d'une autre application — avaient chacun recopié la même tuile
/// `_ConversationTile`, qui allait bien chercher le nom de l'autre
/// participant… mais la recherche, elle, filtrait sur `conversation.name`,
/// **nul pour un 1:1**. Deux conséquences, dans les trois écrans à la fois :
///
/// - taper le nom d'un contact faisait disparaître toutes les discussions
///   privées de la liste des destinations ;
/// - sans recherche, elles s'affichaient toutes sous « Conversation » avec un
///   avatar « ? », indistinguables les unes des autres.
///
/// Partager vers un 1:1 était donc impossible en pratique. La règle :
/// `resolveConversations` résout, `ConversationPickerTile` affiche.
///
/// Limite assumée : ces deux premiers tests lisent la source. Monter ces
/// feuilles en test widget demanderait l10n, GoRouter et la dizaine de
/// providers de la messagerie — coût disproportionné pour verrouiller une
/// convention de structure.
void main() {
  const selecteurs = <String>[
    'lib/features/messages/presentation/widgets/conversation_picker_sheet.dart',
    'lib/features/messages/presentation/widgets/forward_conversation_picker.dart',
    'lib/features/messages/presentation/screens/share_to_conversation_screen.dart',
    'lib/features/feed/presentation/widgets/share_post_sheet.dart',
  ];

  test('tout sélecteur de conversation passe par la résolution partagée', () {
    for (final chemin in selecteurs) {
      final source = File(chemin).readAsStringSync();
      expect(
        source.contains('resolveConversations('),
        isTrue,
        reason:
            '$chemin liste des conversations sans passer par '
            '`resolveConversations` : ses 1:1 seront affichés sous '
            '« Conversation » et introuvables à la recherche.',
      );
    }
  });

  test('aucun écran ne redéclare la tuile de conversation', () {
    // Le nom exact qui a été dupliqué, pas un motif large : `conversation_item`
    // (la ligne de la liste des messages) est une tuile légitime, avec son
    // propre rôle et son propre nom.
    final tuile = RegExp(r'class _ConversationTile\b');
    final coupables = <String>[];

    for (final fichier in Directory('lib/features')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))) {
      if (tuile.hasMatch(fichier.readAsStringSync())) {
        coupables.add(fichier.path);
      }
    }

    expect(
      coupables,
      isEmpty,
      reason:
          'Ces écrans redéclarent une tuile de conversation. Utilisez '
          '`ConversationPickerTile` de conversation_picker_sheet.dart.',
    );
  });

  test('la recherche d\'un sélecteur ne filtre jamais sur le seul nom', () {
    // Les deux écritures exactes qui portaient le défaut. `messages_screen`
    // filtre aussi sur `conv.name`, mais complète avec le nom du participant
    // résolu : il n'est pas dans la liste et n'a pas à l'être.
    final filtreAveugle = RegExp(
      r"conv\.name\?\.toLowerCase\(\)|\(c\.name \?\? ''\)\.toLowerCase\(\)",
    );

    for (final chemin in selecteurs) {
      final source = File(chemin).readAsStringSync();
      expect(
        filtreAveugle.hasMatch(source),
        isFalse,
        reason:
            '$chemin filtre la recherche sur `conversation.name`, nul pour '
            'un 1:1 : toutes les discussions privées disparaîtraient dès la '
            'première lettre tapée.',
      );
    }
  });

  group('ResolvedConversation.matches', () {
    ConversationEntity conversation() => ConversationEntity(
      id: 'c1',
      type: ConversationType.individual,
      participantIds: const ['moi', 'autre'],
      createdAt: DateTime(2026, 1, 1),
      createdBy: 'moi',
    );

    ResolvedConversation resolue(String nom) => ResolvedConversation(
      conversation: conversation(),
      displayName: nom,
    );

    test('une requête vide laisse tout passer', () {
      expect(resolue('Amina Issoufou').matches(''), isTrue);
    });

    test('la casse et la position dans le nom sont indifférentes', () {
      final amina = resolue('Amina Issoufou');
      expect(amina.matches('amina'), isTrue);
      expect(amina.matches('ISSOUFOU'), isTrue);
      expect(amina.matches('na Iss'), isTrue);
    });

    test('un nom qui ne contient pas la requête ne passe pas', () {
      expect(resolue('Amina Issoufou').matches('boubacar'), isFalse);
    });
  });
}
