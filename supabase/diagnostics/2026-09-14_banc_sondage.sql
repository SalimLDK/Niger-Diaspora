-- Banc du sondage : rejoue un vote réel, en transaction annulée (2026-09-14)
--
-- Ce que `flutter test` ne peut pas couvrir : ce que la base accepte ou refuse
-- vraiment, sous le rôle que PostgREST utilise pour le trafic applicatif.
-- Écrit avec la migration `20260914160000` (`cast_poll_vote`,
-- `poll_option_voters`, `post_poll_votes_pas_apres_la_fin`), rejoué après son
-- application : 20 mesures, identiques avant et après.
--
-- Comment le jouer, depuis la racine du dépôt :
--
--   { echo BEGIN; cat supabase/diagnostics/2026-09-14_banc_sondage.sql; --     echo ROLLBACK; } > /tmp/banc.sql
--   supabase db query --linked -o csv -f /tmp/banc.sql
--
-- Pour valider une migration AVANT de la pousser, intercaler son fichier
-- entre le `BEGIN` et ce banc.
--
-- Deux pièges, tous deux déjà payés :
--
--   1. `db query --linked` se connecte en `postgres`, qui a `BYPASSRLS` : sans
--      `SET LOCAL ROLE authenticated`, tout essai de RLS est un faux positif.
--      D'où les `set_config('role', …, TRUE)` dans chaque bloc, et le
--      `RESET ROLE` entre eux.
--   2. Un refus attendu doit être attrapé par un `EXCEPTION WHEN OTHERS`,
--      sinon il emporte toute la transaction et le banc s'arrête là.
--
-- Les identités sont celles de la base de test. Si le groupe ou les comptes
-- changent, ajuster les cinq constantes en tête des fixtures.
--
-- Le `ROLLBACK` final n'est pas dans ce fichier : c'est l'appelant qui
-- l'ajoute, pour qu'on ne puisse pas le jouer par mégarde sans lui.

-- Banc du sondage : rejoue le parcours reel d'un vote, en transaction annulee.
-- Groupe b21e8f5a… : A = auteur, B = membre votant, C = autre membre,
-- D = non membre.

CREATE TEMP TABLE _r(n INT, etape TEXT, resultat TEXT) ON COMMIT DROP;
GRANT ALL ON _r TO authenticated, anon;

INSERT INTO _r VALUES (0, 'RLS active sur post_poll_votes',
  (SELECT relrowsecurity::TEXT FROM pg_class WHERE relname = 'post_poll_votes'));

-- Fixtures (posees en postgres, hors RLS) ------------------------------------
INSERT INTO post_polls (id, group_id, created_by, question, allow_multiple, ends_at) VALUES
  ('11111111-1111-1111-1111-111111111111', 'b21e8f5a-faca-4c89-9ef3-650234187161', 'czk5UoUclLOFmbRtUIZ5XYLYKo52', 'Banc : choix unique',   FALSE, NULL),
  ('22222222-2222-2222-2222-222222222222', 'b21e8f5a-faca-4c89-9ef3-650234187161', 'czk5UoUclLOFmbRtUIZ5XYLYKo52', 'Banc : choix multiple', TRUE,  NULL),
  ('33333333-3333-3333-3333-333333333333', 'b21e8f5a-faca-4c89-9ef3-650234187161', 'czk5UoUclLOFmbRtUIZ5XYLYKo52', 'Banc : termine',        FALSE, NOW() - INTERVAL '1 day');

UPDATE post_polls SET is_anonymous = TRUE
 WHERE id = '11111111-1111-1111-1111-111111111111';

INSERT INTO post_poll_options (id, poll_id, label, position) VALUES
  ('aaaaaaaa-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111', 'Oui',       0),
  ('aaaaaaaa-0000-0000-0000-000000000002', '11111111-1111-1111-1111-111111111111', 'Non',       1),
  ('cccccccc-0000-0000-0000-000000000001', '22222222-2222-2222-2222-222222222222', 'Riz',       0),
  ('cccccccc-0000-0000-0000-000000000002', '22222222-2222-2222-2222-222222222222', 'Mil',       1),
  ('eeeeeeee-0000-0000-0000-000000000001', '33333333-3333-3333-3333-333333333333', 'Trop tard', 0);

-- 1. Un membre vote --------------------------------------------------------
DO $b$
BEGIN
  PERFORM set_config('role', 'authenticated', TRUE);
  PERFORM set_config('request.jwt.claims', '{"app_metadata":{"firebase_uid":"mzi52ZtZlWWQnRoEI5Dr3bN3dtF2"}}', TRUE);
  BEGIN
    PERFORM public.cast_poll_vote('11111111-1111-1111-1111-111111111111'::UUID,
                                  ARRAY['aaaaaaaa-0000-0000-0000-000000000001'::UUID]);
    INSERT INTO _r VALUES (1, 'B vote « Oui » (choix unique)', 'ACCEPTE');
  EXCEPTION WHEN OTHERS THEN
    INSERT INTO _r VALUES (1, 'B vote « Oui » (choix unique)', 'REFUSE : ' || SQLERRM);
  END;
END $b$;
RESET ROLE;

INSERT INTO _r
SELECT 2, 'compteurs apres le 1er vote',
       'Oui=' || (SELECT vote_count FROM post_poll_options WHERE id = 'aaaaaaaa-0000-0000-0000-000000000001')
     || ' Non=' || (SELECT vote_count FROM post_poll_options WHERE id = 'aaaaaaaa-0000-0000-0000-000000000002')
     || ' total=' || (SELECT total_votes FROM post_polls WHERE id = '11111111-1111-1111-1111-111111111111');

-- 3. Il change d'avis ------------------------------------------------------
DO $b$
BEGIN
  PERFORM set_config('role', 'authenticated', TRUE);
  PERFORM set_config('request.jwt.claims', '{"app_metadata":{"firebase_uid":"mzi52ZtZlWWQnRoEI5Dr3bN3dtF2"}}', TRUE);
  BEGIN
    PERFORM public.cast_poll_vote('11111111-1111-1111-1111-111111111111'::UUID,
                                  ARRAY['aaaaaaaa-0000-0000-0000-000000000002'::UUID]);
    INSERT INTO _r VALUES (3, 'B change pour « Non »', 'ACCEPTE');
  EXCEPTION WHEN OTHERS THEN
    INSERT INTO _r VALUES (3, 'B change pour « Non »', 'REFUSE : ' || SQLERRM);
  END;
END $b$;
RESET ROLE;

INSERT INTO _r
SELECT 4, 'compteurs apres le changement (l ancien doit retomber a 0)',
       'Oui=' || (SELECT vote_count FROM post_poll_options WHERE id = 'aaaaaaaa-0000-0000-0000-000000000001')
     || ' Non=' || (SELECT vote_count FROM post_poll_options WHERE id = 'aaaaaaaa-0000-0000-0000-000000000002')
     || ' total=' || (SELECT total_votes FROM post_polls WHERE id = '11111111-1111-1111-1111-111111111111');

-- 5. Deux reponses dans un sondage a choix unique ---------------------------
DO $b$
BEGIN
  PERFORM set_config('role', 'authenticated', TRUE);
  PERFORM set_config('request.jwt.claims', '{"app_metadata":{"firebase_uid":"mzi52ZtZlWWQnRoEI5Dr3bN3dtF2"}}', TRUE);
  BEGIN
    PERFORM public.cast_poll_vote('11111111-1111-1111-1111-111111111111'::UUID,
                                  ARRAY['aaaaaaaa-0000-0000-0000-000000000001'::UUID,
                                        'aaaaaaaa-0000-0000-0000-000000000002'::UUID]);
    INSERT INTO _r VALUES (5, 'B coche deux reponses en choix unique', 'ACCEPTE (anormal)');
  EXCEPTION WHEN OTHERS THEN
    INSERT INTO _r VALUES (5, 'B coche deux reponses en choix unique', 'REFUSE : ' || SQLERRM);
  END;
END $b$;
RESET ROLE;

-- 6. Une option qui appartient a un autre sondage ---------------------------
DO $b$
BEGIN
  PERFORM set_config('role', 'authenticated', TRUE);
  PERFORM set_config('request.jwt.claims', '{"app_metadata":{"firebase_uid":"mzi52ZtZlWWQnRoEI5Dr3bN3dtF2"}}', TRUE);
  BEGIN
    PERFORM public.cast_poll_vote('11111111-1111-1111-1111-111111111111'::UUID,
                                  ARRAY['cccccccc-0000-0000-0000-000000000001'::UUID]);
    INSERT INTO _r VALUES (6, 'B vote une option d un autre sondage', 'ACCEPTE (anormal)');
  EXCEPTION WHEN OTHERS THEN
    INSERT INTO _r VALUES (6, 'B vote une option d un autre sondage', 'REFUSE : ' || SQLERRM);
  END;
END $b$;
RESET ROLE;

-- 7. Un sondage termine -----------------------------------------------------
DO $b$
BEGIN
  PERFORM set_config('role', 'authenticated', TRUE);
  PERFORM set_config('request.jwt.claims', '{"app_metadata":{"firebase_uid":"mzi52ZtZlWWQnRoEI5Dr3bN3dtF2"}}', TRUE);
  BEGIN
    PERFORM public.cast_poll_vote('33333333-3333-3333-3333-333333333333'::UUID,
                                  ARRAY['eeeeeeee-0000-0000-0000-000000000001'::UUID]);
    INSERT INTO _r VALUES (7, 'B vote dans un sondage termine', 'ACCEPTE (anormal)');
  EXCEPTION WHEN OTHERS THEN
    INSERT INTO _r VALUES (7, 'B vote dans un sondage termine', 'REFUSE : ' || SQLERRM);
  END;
END $b$;
RESET ROLE;

-- 8. Quelqu'un qui n'est pas du groupe --------------------------------------
DO $b$
BEGIN
  PERFORM set_config('role', 'authenticated', TRUE);
  PERFORM set_config('request.jwt.claims', '{"app_metadata":{"firebase_uid":"8PxHSfjROxWWLD2XTXXPNqakoPA2"}}', TRUE);
  BEGIN
    PERFORM public.cast_poll_vote('11111111-1111-1111-1111-111111111111'::UUID,
                                  ARRAY['aaaaaaaa-0000-0000-0000-000000000001'::UUID]);
    INSERT INTO _r VALUES (8, 'D (hors du groupe) vote', 'ACCEPTE (anormal)');
  EXCEPTION WHEN OTHERS THEN
    INSERT INTO _r VALUES (8, 'D (hors du groupe) vote', 'REFUSE : ' || SQLERRM);
  END;
END $b$;
RESET ROLE;

-- 9. Un anonyme -------------------------------------------------------------
DO $b$
BEGIN
  PERFORM set_config('role', 'anon', TRUE);
  PERFORM set_config('request.jwt.claims', '', TRUE);
  BEGIN
    PERFORM public.cast_poll_vote('11111111-1111-1111-1111-111111111111'::UUID,
                                  ARRAY['aaaaaaaa-0000-0000-0000-000000000001'::UUID]);
    INSERT INTO _r VALUES (9, 'anon vote', 'ACCEPTE (anormal)');
  EXCEPTION WHEN OTHERS THEN
    INSERT INTO _r VALUES (9, 'anon vote', 'REFUSE : ' || SQLERRM);
  END;
END $b$;
RESET ROLE;

-- 10. Retrait du vote (tableau vide) ----------------------------------------
DO $b$
BEGIN
  PERFORM set_config('role', 'authenticated', TRUE);
  PERFORM set_config('request.jwt.claims', '{"app_metadata":{"firebase_uid":"mzi52ZtZlWWQnRoEI5Dr3bN3dtF2"}}', TRUE);
  BEGIN
    PERFORM public.cast_poll_vote('11111111-1111-1111-1111-111111111111'::UUID, ARRAY[]::UUID[]);
    INSERT INTO _r VALUES (10, 'B retire son vote', 'ACCEPTE');
  EXCEPTION WHEN OTHERS THEN
    INSERT INTO _r VALUES (10, 'B retire son vote', 'REFUSE : ' || SQLERRM);
  END;
END $b$;
RESET ROLE;

INSERT INTO _r
SELECT 11, 'compteurs apres le retrait',
       'Oui=' || (SELECT vote_count FROM post_poll_options WHERE id = 'aaaaaaaa-0000-0000-0000-000000000001')
     || ' Non=' || (SELECT vote_count FROM post_poll_options WHERE id = 'aaaaaaaa-0000-0000-0000-000000000002')
     || ' total=' || (SELECT total_votes FROM post_polls WHERE id = '11111111-1111-1111-1111-111111111111');

-- 12. Choix multiple, avec un doublon dans la demande ------------------------
DO $b$
BEGIN
  PERFORM set_config('role', 'authenticated', TRUE);
  PERFORM set_config('request.jwt.claims', '{"app_metadata":{"firebase_uid":"mzi52ZtZlWWQnRoEI5Dr3bN3dtF2"}}', TRUE);
  BEGIN
    PERFORM public.cast_poll_vote('22222222-2222-2222-2222-222222222222'::UUID,
                                  ARRAY['cccccccc-0000-0000-0000-000000000001'::UUID,
                                        'cccccccc-0000-0000-0000-000000000001'::UUID,
                                        'cccccccc-0000-0000-0000-000000000002'::UUID]);
    INSERT INTO _r VALUES (12, 'B coche Riz, Riz, Mil (choix multiple)', 'ACCEPTE');
  EXCEPTION WHEN OTHERS THEN
    INSERT INTO _r VALUES (12, 'B coche Riz, Riz, Mil (choix multiple)', 'REFUSE : ' || SQLERRM);
  END;
END $b$;
RESET ROLE;

INSERT INTO _r
SELECT 13, 'compteurs du choix multiple (doublon compte une fois)',
       'Riz=' || (SELECT vote_count FROM post_poll_options WHERE id = 'cccccccc-0000-0000-0000-000000000001')
     || ' Mil=' || (SELECT vote_count FROM post_poll_options WHERE id = 'cccccccc-0000-0000-0000-000000000002')
     || ' total=' || (SELECT total_votes FROM post_polls WHERE id = '22222222-2222-2222-2222-222222222222');

-- 14. L'auteur lit les votants ----------------------------------------------
DO $b$
DECLARE n INT;
BEGIN
  PERFORM set_config('role', 'authenticated', TRUE);
  PERFORM set_config('request.jwt.claims', '{"app_metadata":{"firebase_uid":"czk5UoUclLOFmbRtUIZ5XYLYKo52"}}', TRUE);
  BEGIN
    SELECT COUNT(*) INTO n FROM public.poll_option_voters('22222222-2222-2222-2222-222222222222'::UUID);
    INSERT INTO _r VALUES (14, 'A (auteur) lit les votants', n || ' ligne(s)');
  EXCEPTION WHEN OTHERS THEN
    INSERT INTO _r VALUES (14, 'A (auteur) lit les votants', 'REFUSE : ' || SQLERRM);
  END;
END $b$;
RESET ROLE;

-- 15. Un autre membre lit les votants ---------------------------------------
DO $b$
DECLARE n INT;
BEGIN
  PERFORM set_config('role', 'authenticated', TRUE);
  PERFORM set_config('request.jwt.claims', '{"app_metadata":{"firebase_uid":"I54Ixk7LrcXGxQMP9BbZrjUxewC3"}}', TRUE);
  BEGIN
    SELECT COUNT(*) INTO n FROM public.poll_option_voters('22222222-2222-2222-2222-222222222222'::UUID);
    INSERT INTO _r VALUES (15, 'C (membre, pas auteur) lit les votants d un sondage NON anonyme', n || ' ligne(s)');
  EXCEPTION WHEN OTHERS THEN
    INSERT INTO _r VALUES (15, 'C (membre, pas auteur) lit les votants', 'REFUSE : ' || SQLERRM);
  END;
END $b$;
RESET ROLE;

-- 15b. Sondage ANONYME : personne, pas meme son auteur ----------------------
DO $b$
DECLARE n INT;
BEGIN
  PERFORM set_config('role', 'authenticated', TRUE);
  PERFORM set_config('request.jwt.claims', '{"app_metadata":{"firebase_uid":"czk5UoUclLOFmbRtUIZ5XYLYKo52"}}', TRUE);
  BEGIN
    SELECT COUNT(*) INTO n FROM public.poll_option_voters('11111111-1111-1111-1111-111111111111'::UUID);
    INSERT INTO _r VALUES (151, 'A (auteur) lit les votants d un sondage ANONYME', n || ' ligne(s)');
  EXCEPTION WHEN OTHERS THEN
    INSERT INTO _r VALUES (151, 'A (auteur) lit les votants d un sondage ANONYME', 'REFUSE : ' || SQLERRM);
  END;
END $b$;
RESET ROLE;

-- 15c. Anonymat par defaut : faux ------------------------------------------
INSERT INTO _r
SELECT 152, 'sondages existants anonymes apres migration',
       COUNT(*) FILTER (WHERE is_anonymous) || ' sur ' || COUNT(*)
  FROM post_polls
 WHERE id NOT IN ('11111111-1111-1111-1111-111111111111',
                  '22222222-2222-2222-2222-222222222222',
                  '33333333-3333-3333-3333-333333333333');

-- 16. Ecriture directe dans un sondage OUVERT (non-regression) ---------------
DO $b$
BEGIN
  PERFORM set_config('role', 'authenticated', TRUE);
  PERFORM set_config('request.jwt.claims', '{"app_metadata":{"firebase_uid":"I54Ixk7LrcXGxQMP9BbZrjUxewC3"}}', TRUE);
  BEGIN
    INSERT INTO post_poll_votes (poll_id, option_id, user_id)
    VALUES ('11111111-1111-1111-1111-111111111111',
            'aaaaaaaa-0000-0000-0000-000000000001',
            'I54Ixk7LrcXGxQMP9BbZrjUxewC3');
    INSERT INTO _r VALUES (16, 'C ecrit son vote en direct, sondage ouvert', 'ACCEPTE');
  EXCEPTION WHEN OTHERS THEN
    INSERT INTO _r VALUES (16, 'C ecrit son vote en direct, sondage ouvert', 'REFUSE : ' || SQLERRM);
  END;
END $b$;
RESET ROLE;

-- 17. Ecriture directe dans un sondage TERMINE ------------------------------
DO $b$
BEGIN
  PERFORM set_config('role', 'authenticated', TRUE);
  PERFORM set_config('request.jwt.claims', '{"app_metadata":{"firebase_uid":"I54Ixk7LrcXGxQMP9BbZrjUxewC3"}}', TRUE);
  BEGIN
    INSERT INTO post_poll_votes (poll_id, option_id, user_id)
    VALUES ('33333333-3333-3333-3333-333333333333',
            'eeeeeeee-0000-0000-0000-000000000001',
            'I54Ixk7LrcXGxQMP9BbZrjUxewC3');
    INSERT INTO _r VALUES (17, 'C ecrit son vote en direct, sondage termine', 'ACCEPTE (anormal)');
  EXCEPTION WHEN OTHERS THEN
    INSERT INTO _r VALUES (17, 'C ecrit son vote en direct, sondage termine', 'REFUSE : ' || SQLERRM);
  END;
END $b$;
RESET ROLE;

-- 18. Les 3 sondages reels de production restent lisibles par leurs membres --
INSERT INTO _r
SELECT 18, 'sondages en base (hors fixtures du banc)',
       COUNT(*) || ' sondage(s), ' || SUM(total_votes) || ' vote(s)'
  FROM post_polls
 WHERE id NOT IN ('11111111-1111-1111-1111-111111111111',
                  '22222222-2222-2222-2222-222222222222',
                  '33333333-3333-3333-3333-333333333333');

SELECT n, etape, resultat FROM _r ORDER BY n;
