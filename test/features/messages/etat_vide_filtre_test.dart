import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Un filtre qui ne ramène rien n'est pas une messagerie vide (§9e).
///
/// `_buildConversationList` branchait sur `filtered.isEmpty` — la liste
/// **après** application de la puce de filtre — et rendait alors
/// `_buildEmptyState`, c'est-à-dire la fiche 9e : « Aucune conversation »,
/// « Commencez à discuter avec les membres de la diaspora », le bouton
/// « Nouvelle conversation » et la ligne sur le chiffrement.
///
/// Sur la puce « Non lus » d'un compte dont tout est lu, les trois phrases
/// étaient fausses et l'action proposée ne répondait pas au problème : il n'y
/// avait rien à commencer, il fallait revenir à « Tous ». Idem pour « Groupes »
/// sur un compte sans conversation de groupe.
///
/// Les libellés justes existaient déjà dans les deux `.arb` — `noUnreadMessages`,
/// `noGroupConversations`, `showAllConversations` — mais **aucun n'était
/// référencé nulle part dans `lib/`**. La branche avait été prévue puis
/// oubliée ; c'est ce que le dernier cas de ce fichier verrouille.
///
/// Limite assumée, comme `reglages_sans_doublon_test.dart` : ce test lit la
/// source. Monter `MessagesScreen` exigerait l10n, GoRouter, une session
/// Supabase et une dizaine de providers, et `_buildConversationList` est de
/// toute façon privée.
void main() {
  final ecran = File(
    'lib/features/messages/presentation/screens/messages_screen.dart',
  );
  late String source;

  setUpAll(() {
    expect(ecran.existsSync(), isTrue, reason: 'écran introuvable');
    source = ecran.readAsStringSync();
  });

  test('un filtre sans résultat a son propre état vide', () {
    expect(
      source,
      contains('Widget _buildFilteredEmptyState('),
      reason: 'l\'état vide propre au filtre doit exister',
    );
    expect(source, contains('_buildFilteredEmptyState('));
  });

  test('la garde du filtre passe AVANT la fiche 9e', () {
    // C'est l'ordre qui porte le correctif : `_buildEmptyState` reste la
    // bonne réponse pour une messagerie réellement vide, mais il ne doit plus
    // être atteignable tant qu'une puce restrictive est active.
    final garde = source.indexOf('_filter == _MessagesFilter.unread ||');
    final fiche9e = source.indexOf('if (!showSelfNotesTile) return _buildEmptyState(context);');

    expect(garde, isNot(-1), reason: 'la garde sur le filtre a disparu');
    expect(fiche9e, isNot(-1), reason: 'la fiche 9e a disparu');
    expect(
      garde,
      lessThan(fiche9e),
      reason: 'la fiche 9e serait rendue sur un filtre restrictif',
    );
  });

  test('les deux filtres restrictifs sont couverts', () {
    expect(source, contains('_filter == _MessagesFilter.unread'));
    expect(source, contains('_filter == _MessagesFilter.groups'));
  });

  test('régression : les trois libellés ne sont plus morts', () {
    for (final cle in const [
      'noUnreadMessages',
      'noGroupConversations',
      'showAllConversations',
    ]) {
      expect(
        source,
        contains('l10n.$cle'),
        reason: '`$cle` existait dans les .arb sans être câblée',
      );
    }
  });

  test('les libellés existent dans les DEUX langues', () {
    for (final langue in const ['fr', 'en']) {
      final arb = File('lib/l10n/app_$langue.arb').readAsStringSync();
      for (final cle in const [
        'noUnreadMessages',
        'noGroupConversations',
        'showAllConversations',
      ]) {
        expect(
          arb,
          contains('"$cle"'),
          reason: '`$cle` manque dans app_$langue.arb',
        );
      }
    }
  });

  test('la sortie vers « Tous » est offerte', () {
    // Sans elle, l'écran dit ce qui manque sans dire comment en sortir : la
    // puce active se lit mal une fois la liste vide.
    expect(source, contains('setState(() => _filter = _MessagesFilter.all)'));
  });
}
