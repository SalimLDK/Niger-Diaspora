import 'package:diaspo_niger/core/utils/mention_handle.dart';
import 'package:diaspo_niger/features/feed/domain/entities/post_entity.dart';
import 'package:flutter_test/flutter_test.dart';

/// Mentionner quelqu'un dans un groupe passait par son **nom affiché complet**
/// (`@Ibrahim Yacouba Maïdaoua`) : un jeton à espaces, que la détection ne
/// savait pas relire — elle abandonne dès qu'une espace apparaît, donc seul le
/// premier mot était cherchable. On écrit désormais un pseudo, comme dans le
/// fil : la poignée publique quand elle existe, sinon le pseudo dérivé du nom.
void main() {
  group('mentionTokenFor', () {
    test('la poignée publique gagne quand elle existe', () {
      expect(
        mentionTokenFor(
          handle: 'ibrahim_ym',
          displayName: 'Ibrahim Yacouba Maïdaoua',
        ),
        'ibrahim_ym',
      );
    });

    test('sans poignée, le pseudo dérivé du nom — accents conservés', () {
      expect(
        mentionTokenFor(handle: null, displayName: 'Ibrahim Yacouba Maïdaoua'),
        'IbrahimYacoubaMaïdaoua',
      );
      // 9 comptes sur 11 n'avaient pas de poignée au 2026-08-23 : ce repli
      // n'est pas un cas limite, c'est le cas courant.
      expect(mentionTokenFor(handle: '', displayName: 'Aïcha'), 'Aïcha');
      expect(mentionTokenFor(handle: '   ', displayName: 'Aïcha'), 'Aïcha');
    });

    test('le jeton ne contient jamais d\'espace', () {
      final token = mentionTokenFor(
        handle: null,
        displayName: 'Ibrahim Yacouba Maïdaoua',
      );
      expect(token.contains(' '), isFalse);
    });
  });

  group('foldForMentionSearch', () {
    test('replie les accents au lieu de les supprimer', () {
      // `legacyMentionHandle` SUPPRIME (`Maïdaoua` → `Madaoua`) : sur ce
      // chemin-là, `mai` ne trouverait rien.
      expect(foldForMentionSearch('Maïdaoua'), 'maidaoua');
      expect(foldForMentionSearch('Boubé'), 'boube');
      expect(foldForMentionSearch('Çà et Là'), 'ca et la');
    });

    test('couvre les lettres haoussa / zarma / peul', () {
      expect(foldForMentionSearch('Ɓoubacar'), 'boubacar');
      expect(foldForMentionSearch('Ŋaɗo'), 'nado');
    });

    test('laisse intact ce qui n\'a pas de repli', () {
      expect(foldForMentionSearch('李明'), '李明');
      expect(foldForMentionSearch('user_42'), 'user_42');
    });
  });

  group('mentionQueryMatches', () {
    const displayName = 'Ibrahim Yacouba Maïdaoua';
    const token = 'IbrahimYacoubaMaïdaoua';

    test('début du pseudo', () {
      expect(
        mentionQueryMatches(query: 'Ibra', token: token, displayName: displayName),
        isTrue,
      );
    });

    test('début de n\'importe quel mot du nom', () {
      // C'est le cas qui manquait : le filtre ne regardait que le début du nom
      // complet, donc `@Mai` ne proposait personne.
      expect(
        mentionQueryMatches(query: 'Mai', token: token, displayName: displayName),
        isTrue,
      );
      expect(
        mentionQueryMatches(
          query: 'yacouba',
          token: token,
          displayName: displayName,
        ),
        isTrue,
      );
    });

    test('sans accent au clavier — `mai` doit trouver `Maïdaoua`', () {
      expect(
        mentionQueryMatches(query: 'maï', token: token, displayName: displayName),
        isTrue,
      );
      expect(
        mentionQueryMatches(query: 'mai', token: token, displayName: displayName),
        isTrue,
      );
    });

    test('la poignée est cherchable telle quelle', () {
      expect(
        mentionQueryMatches(
          query: 'ibr',
          token: 'ibrahim_ym',
          displayName: displayName,
        ),
        isTrue,
      );
    });

    test('une saisie vide propose tout le monde', () {
      expect(
        mentionQueryMatches(query: '', token: token, displayName: displayName),
        isTrue,
      );
    });

    test('ne propose pas n\'importe qui', () {
      expect(
        mentionQueryMatches(query: 'zzz', token: token, displayName: displayName),
        isFalse,
      );
      // Un fragment au milieu d'un mot n'est pas un début de mot.
      expect(
        mentionQueryMatches(query: 'daoua', token: token, displayName: displayName),
        isFalse,
      );
    });
  });

  group('MentionCandidate', () {
    test('expose le jeton à écrire', () {
      const avecPoignee = MentionCandidate(
        id: 'u1',
        displayName: 'Ibrahim Yacouba Maïdaoua',
        handle: 'ibrahim_ym',
      );
      const sansPoignee = MentionCandidate(
        id: 'u2',
        displayName: 'Ibrahim Yacouba Maïdaoua',
      );
      expect(avecPoignee.mentionToken, 'ibrahim_ym');
      expect(sansPoignee.mentionToken, 'IbrahimYacoubaMaïdaoua');
    });
  });

  group('résolution du profil depuis une bulle', () {
    test('les mentions déjà envoyées restent reconnues', () {
      // Les messages d'avant ce correctif ont enregistré le NOM AFFICHÉ dans
      // `mentionedUsers[].name`, avec ses espaces. Le rapprochement se fait sur
      // ce qui est stocké, donc ils continuent de fonctionner tels quels.
      expect(
        mentionHandleMatches(
          'Ibrahim Yacouba Maïdaoua',
          'Ibrahim Yacouba Maïdaoua',
        ),
        isTrue,
      );
      // Et un message récent porte le pseudo.
      expect(mentionHandleMatches('ibrahim_ym', 'ibrahim_ym'), isTrue);
    });
  });
}
