// Le panneau et `signalement_transition` doivent parler des mêmes motifs : un
// code que la base ne connaît pas revient en 22023, et l'administrateur voit
// un refus pour une décision pourtant « valide » à l'écran.
import 'dart:io';

import 'package:diaspo_niger/features/admin/domain/constants/moderation_signalements.dart';
import 'package:diaspo_niger/features/admin/presentation/providers/admin_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

List<String> _motifsDeLaMigration(String sql, String statut) {
  final m = RegExp(
    "WHEN '$statut'\\s+THEN ARRAY\\[([^\\]]*)\\]",
  ).firstMatch(sql);
  expect(m, isNotNull, reason: 'motifs de « $statut » introuvables en SQL');
  return RegExp(r"'([a-z_]+)'")
      .allMatches(m!.group(1)!)
      .map((x) => x.group(1)!)
      .toList();
}

void main() {
  final sql = File(
    'supabase/migrations/20261017100000_moderation_signalements_workflow.sql',
  ).readAsStringSync();

  test('les motifs du panneau sont ceux de la base', () {
    expect(motifsClassementSansSuite, _motifsDeLaMigration(sql, 'dismissed'));
    expect(motifsDecisionAvecAction, _motifsDeLaMigration(sql, 'resolved'));
  });

  test('« En attente » réunit les trois statuts non décidés', () {
    expect(statutsSignalementEnAttente,
        containsAll(['pending', 'reviewing', 'escalated']));
    expect(statutsSignalementDecides, ['resolved', 'dismissed']);
    // Aucun statut dans les deux onglets : un dossier est à un seul endroit.
    expect(
      statutsSignalementEnAttente.toSet().intersection(
            statutsSignalementDecides.toSet(),
          ),
      isEmpty,
    );
  });

  test('un refus de la base se dit en clair', () {
    String msg(String code, [String m = 'brut']) =>
        messageTransitionSignalement(PostgrestException(message: m, code: code));

    expect(msg('55000'), contains('Rechargez'));
    expect(msg('P0002'), contains('introuvable'));
    expect(msg('42501', 'signalement : dossier attribué à un autre modérateur'),
        contains('attribué'));
    expect(msg('22023', 'signalement : motif normalisé requis (a, b)'),
        contains('motif'));
    // Un code inconnu ne se déguise pas en succès.
    expect(msg('XX000'), contains('non enregistrée'));
  });
}
