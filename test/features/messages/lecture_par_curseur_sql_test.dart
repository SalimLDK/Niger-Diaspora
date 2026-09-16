import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Ce que ce banc protège
/// ----------------------
/// La migration `20260916224700` fait deux choses, et aucune ne se voit à
/// l'exécution quand elle régresse.
///
/// **La faille des accusés.** `mark_messages_as_read(p_conversation_id,
/// p_user_id)` et `mark_messages_as_delivered(…)` sont `SECURITY DEFINER` et
/// vérifiaient que `p_user_id` est participant — pas que l'appelant l'est.
/// Tout compte connecté pouvait poser « Lu » au nom d'un membre. Le jour où la
/// garde saute, rien ne casse : c'est précisément le problème.
///
/// **La lecture par curseur.** L'identité ne vient plus d'un paramètre, la
/// borne est un identifiant relu côté serveur, et `unreadCount` est recalculé
/// — pas remis à zéro.
///
/// Le comportement est éprouvé en base par `tools/rls_tests/lecture_par_curseur.sql`
/// (30 cas ; retirer les deux gardes fait tomber les cas 23 et 24). Ce fichier
/// tient le texte, pour qu'une réécriture ultérieure ne les perde pas.
String _lire(String chemin) =>
    File(chemin).readAsStringSync().replaceAll('\r\n', '\n');

/// Le corps d'une fonction, de sa déclaration à la fin de son `$$`.
String _corps(String sql, String signature) {
  final debut = sql.indexOf('CREATE OR REPLACE FUNCTION $signature');
  expect(debut, isNot(-1), reason: '$signature introuvable');
  final ouverture = sql.indexOf(r'AS $$', debut);
  final fin = sql.indexOf(r'$$;', ouverture + 5);
  return sql.substring(debut, fin);
}

void main() {
  const migration =
      'supabase/migrations/20260916224700_lecture_par_curseur_en_clair.sql';
  late String sql;

  setUpAll(() => sql = _lire(migration));

  group('la faille des anciennes RPC est fermée', () {
    for (final fonction in [
      'public.mark_messages_as_read(',
      'public.mark_messages_as_delivered(',
    ]) {
      test('$fonction n\'accuse que pour l\'appelant', () {
        final corps = _corps(sql, fonction);
        expect(
          corps,
          contains('IF p_user_id IS DISTINCT FROM (SELECT public.firebase_uid()) THEN'),
        );
        // `IS DISTINCT FROM`, pas `<>` : avec `<>`, un `firebase_uid()` nul
        // (session sans uid) rend NULL, le IF est faux, et l'appel passe.
        expect(corps, isNot(contains('p_user_id <> (SELECT public.firebase_uid())')));
        expect(corps, contains("USING ERRCODE = '42501'"));

        // La garde passe AVANT toute écriture.
        expect(
          corps.indexOf('IS DISTINCT FROM (SELECT public.firebase_uid())'),
          lessThan(corps.indexOf('UPDATE messages')),
        );
      });
    }
  });

  group('marquer_lus_jusqua', () {
    late String corps;
    setUpAll(() => corps = _corps(sql, 'public.marquer_lus_jusqua('));

    test("l'identité vient de la session, pas d'un paramètre", () {
      expect(corps, contains('v_uid      TEXT := public.firebase_uid();'));
      expect(corps, isNot(contains('p_user_id')));
    });

    test('la borne est un identifiant relu côté serveur, dans les deux magasins', () {
      expect(corps, contains('p_message_id      TEXT'));
      expect(corps, contains('FROM messages m\n   WHERE m.id = p_message_id'));
      expect(corps, contains('FROM mls_messages mm\n       WHERE mm.id = p_message_id::uuid'));
    });

    test('une borne introuvable est une erreur, pas un succès vide', () {
      expect(corps, contains("USING ERRCODE = 'P0002'"));
    });

    test('rien au-delà de la borne', () {
      expect(corps, contains('AND m.created_at <= v_borne'));
    });

    test("l'heure du premier coup d'œil n'est jamais réécrite", () {
      // `||` garde la valeur de DROITE : l'existant doit être à droite.
      expect(
        corps,
        contains("jsonb_build_object(v_uid, v_now)\n                 || CASE WHEN jsonb_typeof(m.data->'readAt') = 'object'"),
      );
    });

    test('unreadCount est recalculé, et écrit seulement s\'il change', () {
      expect(corps, isNot(contains("'unreadCount': 0")));
      expect(corps, contains('SELECT count(*)::INTEGER INTO v_reste'));
      expect(corps, contains("IF v_nouvelle IS DISTINCT FROM COALESCE(v_data, '{}'::jsonb) THEN"));
    });

    test("lastMessageReadBy n'est jamais touché sur une conversation basculée", () {
      expect(corps, contains('IF v_reste = 0 AND v_bascule IS NULL THEN'));
    });

    test('les notifications d\'un message postérieur à la borne restent', () {
      expect(corps, contains('AND m.created_at > v_borne'));
      expect(corps, contains('AND mm.created_at > v_borne'));
    });
  });

  group('repere_de_lecture', () {
    late String corps;
    setUpAll(() => corps = _corps(sql, 'public.repere_de_lecture('));

    test('INVOKER : il ne lit que ce que la RLS laisse voir', () {
      expect(corps, contains('SECURITY INVOKER'));
      expect(corps, isNot(contains('SECURITY DEFINER')));
    });

    test('un non-participant est refusé, pas servi d\'un repère vide', () {
      // Un repère vide se lirait « tout est lu ».
      expect(corps, contains("RAISE EXCEPTION 'repere_de_lecture: pas participant' USING ERRCODE = '42501'"));
    });

    test('les deux magasins, dans une seule instruction', () {
      expect(corps, contains('FROM messages m'));
      expect(corps, contains('FROM mls_messages mm'));
      expect(corps, contains('UNION ALL'));
    });

    test('ce qui compte comme « à lire » est aligné sur mls_unread_counts', () {
      expect(corps, contains("AND mm.kind = 'content'"));
      expect(corps, contains('AND h.message_id IS NULL'));
      expect(corps, contains("AND m.type IS DISTINCT FROM 'system'"));
      expect(corps, contains("AND NOT COALESCE((m.data->'deletedFor') ? v_uid, FALSE)"));
    });
  });

  test('chaque fonction : REVOKE avant GRANT, et rien pour anon', () {
    // Supabase accorde EXECUTE à anon par défaut : un GRANT seul n'enlève rien.
    for (final signature in [
      'public.mark_messages_as_delivered(TEXT, TEXT)',
      'public.mark_messages_as_read(TEXT, TEXT)',
      'public.repere_de_lecture(TEXT)',
      'public.marquer_lus_jusqua(TEXT, TEXT)',
    ]) {
      final revoke = sql.indexOf('REVOKE ALL ON FUNCTION $signature FROM PUBLIC, anon;');
      final grant = sql.indexOf('GRANT EXECUTE ON FUNCTION $signature TO authenticated;');
      expect(revoke, isNot(-1), reason: 'REVOKE manquant : $signature');
      expect(grant, isNot(-1), reason: 'GRANT manquant : $signature');
      expect(revoke, lessThan(grant), reason: signature);
    }
  });
}
