import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Ce que ce banc protège
/// ----------------------
/// `mark_messages_as_read` ne filtrait que sur `readBy`. Pour chaque message
/// pas encore lu, il **ajoutait** le lecteur à `deliveredTo` sans regarder s'il
/// y était, et **réécrivait** `deliveredAt`. Or un message reçu par
/// notification est presque toujours déjà livré quand on le lit.
///
/// Mesuré en production le 2026-09-16 : 84 messages avec des doublons, et 424
/// heures de livraison strictement égales à l'heure de lecture — aucune
/// antérieure. Ces heures-là sont perdues pour de bon.
///
/// Le comportement est éprouvé en base par `tools/rls_tests/accuses_sans_doublon.sql`
/// (8 cas ; les corps d'avant en font tomber 4). Ce fichier tient le texte de
/// la migration contre une réécriture qui reviendrait à l'ajout aveugle.
String _lire(String chemin) =>
    File(chemin).readAsStringSync().replaceAll('\r\n', '\n');

String _corps(String sql, String signature) {
  final debut = sql.indexOf('CREATE OR REPLACE FUNCTION $signature');
  expect(debut, isNot(-1), reason: '$signature introuvable');
  final ouverture = sql.indexOf(r'AS $$', debut);
  return sql.substring(debut, sql.indexOf(r'$$;', ouverture + 5));
}

void main() {
  const migration =
      'supabase/migrations/20260916235300_accuses_sans_doublon_ni_ecrasement.sql';
  late String sql;
  setUpAll(() => sql = _lire(migration));

  group('mark_messages_as_read', () {
    late String corps;
    setUpAll(() => corps = _corps(sql, 'public.mark_messages_as_read('));

    test('la garde d\'identité de 20260916224700 est toujours là', () {
      expect(corps, contains('IF p_user_id IS DISTINCT FROM (SELECT public.firebase_uid()) THEN'));
    });

    test('n\'ajoute à deliveredTo que si le lecteur n\'y est pas', () {
      expect(corps, contains("AND (m.data->'deliveredTo') ? p_user_id\n                  THEN m.data->'deliveredTo'"));
      // L'ajout aveugle d'origine.
      expect(corps, isNot(contains("(data->'deliveredTo') || to_jsonb(p_user_id)")));
    });

    test('une heure de livraison ou de lecture déjà posée gagne', () {
      // `||` garde la valeur de DROITE : l'existant doit y être.
      expect(
        corps,
        contains("jsonb_build_object(p_user_id, v_now)\n              || CASE WHEN jsonb_typeof(m.data->'deliveredAt') = 'object'"),
      );
      expect(
        corps,
        contains("jsonb_build_object(p_user_id, v_now)\n          || CASE WHEN jsonb_typeof(m.data->'readAt') = 'object'"),
      );
      expect(corps, isNot(contains('ARRAY[p_user_id],\n                to_jsonb(v_now)')));
    });
  });

  group('mark_messages_as_delivered', () {
    late String corps;
    setUpAll(() => corps = _corps(sql, 'public.mark_messages_as_delivered('));

    test('garde d\'identité, et même règle d\'écriture', () {
      expect(corps, contains('IF p_user_id IS DISTINCT FROM (SELECT public.firebase_uid()) THEN'));
      expect(
        corps,
        contains("jsonb_build_object(p_user_id, v_now)\n          || CASE WHEN jsonb_typeof(m.data->'deliveredAt') = 'object'"),
      );
      expect(corps, contains("AND NOT COALESCE((m.data->'deliveredTo') ? p_user_id, FALSE);"));
    });
  });

  test('la réparation garde chacun une fois, à sa première place', () {
    expect(sql, contains('WITH ORDINALITY AS t(e, pos)'));
    expect(sql, contains('SELECT t.e, min(t.pos) AS premier'));
    expect(sql, contains('jsonb_agg(u.e ORDER BY u.premier)'));
  });

  test('REVOKE avant GRANT, et rien pour anon', () {
    for (final signature in [
      'public.mark_messages_as_read(TEXT, TEXT)',
      'public.mark_messages_as_delivered(TEXT, TEXT)',
    ]) {
      final revoke = sql.indexOf('REVOKE ALL ON FUNCTION $signature FROM PUBLIC, anon;');
      final grant = sql.indexOf('GRANT EXECUTE ON FUNCTION $signature TO authenticated;');
      expect(revoke, isNot(-1), reason: signature);
      expect(revoke, lessThan(grant), reason: signature);
    }
  });
}
