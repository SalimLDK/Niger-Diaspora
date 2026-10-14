-- Banc : un compte ne s'approprie plus le jeton push d'un autre (migration
-- 20261014170000).
--
--   supabase db query --linked -f tools/rls_tests/jeton_push_un_seul_compte.sql
--
-- Condition : 0 cas en ÉCHEC. Tout est dans un `BEGIN … ROLLBACK`.
--
-- AVANT `db push` : remplacer la ligne seule `-- @@MIGRATION@@` par le contenu
-- de la migration — c'est la répétition. APRÈS, lancé tel quel, le banc prouve
-- l'état vivant.
--
-- Sans la migration, les cas 1 à 4 tombent : l'attaquant se rattache le jeton
-- FCM de la victime par la RPC comme par écriture directe, et son jeton VoIP ;
-- le doublon d'avant reste en place. Vérifié le 2026-10-14 sur un
-- PostgreSQL 16 local : quatre ÉCHEC sans la migration, 0 avec. PAS encore
-- contre la production. Les cas 5 à 7 sont les témoins : chacun enregistre
-- ses propres jetons, un jeton retiré à la déconnexion passe au compte
-- suivant, et le retrait d'un jeton mort par le serveur marche toujours.

BEGIN;

SET LOCAL lock_timeout = '5s';

CREATE TEMP TABLE resultat(n int, cas text, attendu text, obtenu text, verdict text);
CREATE TEMP TABLE ctx(k text PRIMARY KEY, v text);
GRANT ALL ON resultat, ctx TO anon, authenticated;

INSERT INTO ctx VALUES
  ('victime',   'banc-jeton-victime'),
  ('attaquant', 'banc-jeton-attaquant'),
  ('suivant',   'banc-jeton-suivant'),
  ('doublon1',  'banc-jeton-doublon1'),
  ('doublon2',  'banc-jeton-doublon2'),
  ('T',         'banc-jeton-T-' || gen_random_uuid()),
  ('D',         'banc-jeton-D-' || gen_random_uuid()),
  ('V',         'banc-voip-' || gen_random_uuid());

INSERT INTO public.users (id, display_name, fcm_tokens, voip_token)
SELECT (SELECT v FROM ctx WHERE k = x.k), x.k, x.jetons, x.voip
  FROM (VALUES ('victime',   jsonb_build_array((SELECT v FROM ctx WHERE k='T')), (SELECT v FROM ctx WHERE k='V')),
               ('attaquant', '[]'::jsonb, NULL),
               ('suivant',   '[]'::jsonb, NULL),
               ('doublon1',  jsonb_build_array((SELECT v FROM ctx WHERE k='D')), NULL),
               ('doublon2',  jsonb_build_array((SELECT v FROM ctx WHERE k='D')), NULL)) AS x(k, jetons, voip);

-- @@MIGRATION@@

CREATE FUNCTION pg_temp.etre(p text) RETURNS void LANGUAGE sql AS $$
  SELECT set_config('request.jwt.claims',
    json_build_object('sub', '00000000-0000-0000-0000-0000000000f8',
                      'role', 'authenticated',
                      'app_metadata', json_build_object('firebase_uid',
                        (SELECT v FROM pg_temp.ctx WHERE k = p)))::text, true);
$$;
CREATE FUNCTION pg_temp.jetons(u text) RETURNS jsonb LANGUAGE sql SECURITY DEFINER AS $$
  SELECT fcm_tokens FROM public.users WHERE id = (SELECT v FROM pg_temp.ctx WHERE k = u);
$$;
CREATE FUNCTION pg_temp.voip(u text) RETURNS text LANGUAGE sql SECURITY DEFINER AS $$
  SELECT voip_token FROM public.users WHERE id = (SELECT v FROM pg_temp.ctx WHERE k = u);
$$;
CREATE FUNCTION pg_temp.a(u text, j text) RETURNS boolean LANGUAGE sql AS $$
  SELECT COALESCE(pg_temp.jetons(u) @> jsonb_build_array((SELECT v FROM pg_temp.ctx WHERE k = j)), false);
$$;
CREATE FUNCTION pg_temp.ajouter(qui text, j text) RETURNS text LANGUAGE plpgsql AS $$
BEGIN
  PERFORM pg_temp.etre(qui);
  PERFORM public.ajouter_jeton_push((SELECT v FROM pg_temp.ctx WHERE k = j));
  RETURN 'ACCEPTÉ';
EXCEPTION WHEN OTHERS THEN
  RETURN 'REFUSÉ ' || SQLSTATE;
END;
$$;
-- Le retrait d'un jeton mort, comme `send-push` (service, hors RLS).
CREATE FUNCTION pg_temp.retirer_mort(u text, j text) RETURNS void LANGUAGE sql SECURITY DEFINER AS $$
  UPDATE public.users SET fcm_tokens = fcm_tokens - (SELECT v FROM pg_temp.ctx WHERE k = j)
   WHERE id = (SELECT v FROM pg_temp.ctx WHERE k = u);
$$;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA pg_temp TO authenticated;

SET LOCAL ROLE authenticated;

INSERT INTO resultat VALUES (0, 'rôle effectif du banc', 'authenticated', current_user,
  CASE WHEN current_user = 'authenticated' THEN 'OK' ELSE 'ÉCHEC' END);

-- 1. L'attaquant prend le jeton de la victime par la RPC.
DO $$
DECLARE r text := pg_temp.ajouter('attaquant', 'T');
BEGIN
  INSERT INTO resultat VALUES (1, 'RPC : se rattacher le jeton d''autrui',
    'REFUSÉ 23505, jeton absent', r || ', ' || CASE WHEN pg_temp.a('attaquant', 'T') THEN 'jeton PRIS' ELSE 'jeton absent' END,
    CASE WHEN r = 'REFUSÉ 23505' AND NOT pg_temp.a('attaquant', 'T') THEN 'OK' ELSE 'ÉCHEC' END);
END $$;

-- 2. … par écriture directe de sa ligne.
DO $$
DECLARE rejet text := 'ACCEPTÉ';
BEGIN
  PERFORM pg_temp.etre('attaquant');
  BEGIN
    UPDATE public.users SET fcm_tokens = jsonb_build_array((SELECT v FROM ctx WHERE k='T'))
     WHERE id = (SELECT v FROM ctx WHERE k='attaquant');
  EXCEPTION WHEN OTHERS THEN rejet := 'REFUSÉ ' || SQLSTATE;
  END;
  INSERT INTO resultat VALUES (2, 'écriture directe : se rattacher le jeton d''autrui',
    'jeton absent', rejet || ', ' || CASE WHEN pg_temp.a('attaquant', 'T') THEN 'jeton PRIS' ELSE 'jeton absent' END,
    CASE WHEN NOT pg_temp.a('attaquant', 'T') AND pg_temp.a('victime', 'T') THEN 'OK' ELSE 'ÉCHEC' END);
END $$;

-- 3. … et le jeton VoIP (appel CallKit).
DO $$
DECLARE rejet text := 'ACCEPTÉ';
BEGIN
  PERFORM pg_temp.etre('attaquant');
  BEGIN
    UPDATE public.users SET voip_token = (SELECT v FROM ctx WHERE k='V')
     WHERE id = (SELECT v FROM ctx WHERE k='attaquant');
  EXCEPTION WHEN OTHERS THEN rejet := 'REFUSÉ ' || SQLSTATE;
  END;
  INSERT INTO resultat VALUES (3, 'écriture directe : se rattacher le jeton VoIP d''autrui',
    'voip ∅', rejet || ', voip ' || COALESCE(CASE WHEN pg_temp.voip('attaquant') = (SELECT v FROM ctx WHERE k='V') THEN 'PRIS' END, '∅'),
    CASE WHEN pg_temp.voip('attaquant') IS NULL
          AND pg_temp.voip('victime') = (SELECT v FROM ctx WHERE k='V') THEN 'OK' ELSE 'ÉCHEC' END);
END $$;

-- 4. Le doublon d'avant la migration a disparu des deux comptes.
INSERT INTO resultat VALUES (4, 'doublon existant retiré des deux comptes', 'absent, absent',
  CASE WHEN pg_temp.a('doublon1', 'D') THEN 'présent' ELSE 'absent' END || ', ' ||
  CASE WHEN pg_temp.a('doublon2', 'D') THEN 'présent' ELSE 'absent' END,
  CASE WHEN NOT pg_temp.a('doublon1', 'D') AND NOT pg_temp.a('doublon2', 'D') THEN 'OK' ELSE 'ÉCHEC' END);

-- 5. Témoin : la victime réenregistre son jeton (idempotent), le doublon1
--    reprend le sien en premier.
DO $$
DECLARE r1 text := pg_temp.ajouter('victime', 'T');
        r2 text := pg_temp.ajouter('doublon1', 'D');
BEGIN
  INSERT INTO resultat VALUES (5, 'témoin : chacun enregistre son propre jeton', 'ACCEPTÉ, ACCEPTÉ',
    r1 || ', ' || r2,
    CASE WHEN r1 = 'ACCEPTÉ' AND r2 = 'ACCEPTÉ' AND pg_temp.a('victime', 'T') AND pg_temp.a('doublon1', 'D')
         THEN 'OK' ELSE 'ÉCHEC' END);
END $$;

-- 6. Témoin : retiré à la déconnexion, le jeton passe au compte suivant.
DO $$
DECLARE r text;
BEGIN
  PERFORM pg_temp.etre('victime');
  PERFORM public.retirer_jeton_push((SELECT v FROM ctx WHERE k='T'));
  r := pg_temp.ajouter('suivant', 'T');
  INSERT INTO resultat VALUES (6, 'témoin : après déconnexion, le compte suivant le prend', 'ACCEPTÉ',
    r, CASE WHEN r = 'ACCEPTÉ' AND pg_temp.a('suivant', 'T') THEN 'OK' ELSE 'ÉCHEC' END);
END $$;

-- 7. Témoin : le serveur retire un jeton mort.
DO $$
BEGIN
  PERFORM pg_temp.retirer_mort('suivant', 'T');
  INSERT INTO resultat VALUES (7, 'témoin : retrait d''un jeton mort', 'absent',
    CASE WHEN pg_temp.a('suivant', 'T') THEN 'présent' ELSE 'absent' END,
    CASE WHEN pg_temp.a('suivant', 'T') THEN 'ÉCHEC' ELSE 'OK' END);
END $$;

RESET ROLE;

SELECT n, verdict, cas, attendu, obtenu FROM resultat ORDER BY n, cas;

ROLLBACK;
