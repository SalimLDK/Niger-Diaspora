// Vu sur Pixel 10 Pro XL le 2026-09-22 (build Play 1.2.2+26) : discussion
// chiffrée ouverte par lien profond avec 10 et 13 non-lus → écran posé en
// bas, aucun séparateur, et tous les non-lus marqués lus à la même
// milliseconde, y compris ceux jamais affichés. Voir TESTS_APPAREIL_A_FAIRE.md,
// « Ouvrir une discussion lit ce qui est à l'écran, tout de suite ».
//
// Cause : `_filVaJusquAuBout` tenait le fil pour complet quand la liste des
// discussions n'avait rien annoncé (lien profond, notification) ; le fil du
// cache, sans les nouveaux messages chiffrés, décidait donc du placement.
import 'dart:io';

import 'package:diaspo_niger/features/messages/data/datasources/lecture_serveur.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Échéance du fil donnée par le repère serveur', () {
    final premier = DateTime.utc(2026, 9, 22, 6, 10, 21);
    final dernier = DateTime.utc(2026, 9, 22, 6, 12, 11);

    test('le plus récent des non-lus', () {
      final repere = RepereDeLecture(
        premierNonLuId: 'pr1',
        premierNonLuA: premier,
        nonLus: 10,
        dernierNonLuId: 'pr10',
        dernierNonLuA: dernier,
      );
      expect(repere.echeanceDuFil, dernier);
    });

    test('à défaut (migration absente), le premier', () {
      final repere = RepereDeLecture(
        premierNonLuId: 'pr1',
        premierNonLuA: premier,
        nonLus: 10,
      );
      expect(repere.echeanceDuFil, premier);
    });

    test('rien à lire : pas d\'échéance', () {
      expect(const RepereDeLecture().echeanceDuFil, isNull);
      expect(
        RepereDeLecture(premierNonLuId: 'x', premierNonLuA: premier)
            .echeanceDuFil,
        isNull,
        reason: 'un message désigné avec un compte nul ne pose rien',
      );
    });
  });

  group('Branchement dans l\'écran de conversation', () {
    final src = File(
      'lib/features/messages/presentation/screens/conversation_screen.dart',
    ).readAsStringSync();

    String corps(String signature, String fin) {
      final debut = src.indexOf(signature);
      expect(debut, isNot(-1), reason: signature);
      return src.substring(debut, src.indexOf(fin, debut));
    }

    test('le relevé serveur pose l\'échéance quand la liste n\'a rien dit', () {
      final releve = corps(
        'Future<void> _releverCurseur() async {',
        'Future<void> _releverCurseurMls() async {',
      );
      expect(releve, contains('_dernierMessageAnnonce ??= repere.echeanceDuFil'));
    });

    test('le repli MLS aussi, sur le premier non-lu', () {
      final repli = corps(
        'Future<void> _releverCurseurMls() async {',
        'static const _fenetreRecompteNonLus',
      );
      expect(repli, contains('_dernierMessageAnnonce ??= premier.quand'));
    });

    test('la liste garde la priorité : l\'échéance ne l\'écrase pas', () {
      // `??=` et pas `=` : l'annonce de la liste, quand elle existe, décrit le
      // dernier message tout court, pas seulement le dernier non-lu.
      expect(src, isNot(contains('_dernierMessageAnnonce = repere.')));
      expect(src, isNot(contains('_dernierMessageAnnonce = premier.')));
    });
  });
}
