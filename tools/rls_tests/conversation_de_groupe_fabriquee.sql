-- Banc : une conversation rattachée à un groupe ne se fabrique plus côté
-- client, et `data.adminIds` ne vaut plus que sur la conversation de type
-- 'group' (migration 20261014090000).
--
--   supabase db query --linked -f tools/rls_tests/conversation_de_groupe_fabriquee.sql
--
-- Condition : 0 cas en ÉCHEC. Tout est dans un `BEGIN … ROLLBACK`.
--
-- AVANT `db push` : remplacer la ligne seule `-- @@MIGRATION@@` par le contenu
-- de la migration — c'est la répétition. APRÈS, lancé tel quel, le banc prouve
-- l'état vivant.
--
-- Un banc qui ne sait pas échouer ne prouve rien : sans la migration, les cas
-- 1, 2, 3, 4, 7, 8 et 11 tombent — l'attaque complète réussit (cas 3 : une
-- conversation fabriquée par un compte étranger au groupe fait passer celui-ci
-- de 4 membres à 2, propriétaire compris). Vérifié le 2026-10-14 sur un PostgreSQL 16 local (rôles, `firebase_
-- uid()`, `conversations` et ses policies de 20260715120000, les fonctions de
-- 20260909234500, 20260917013200 et 20261003120000) : sept ÉCHEC sans la
-- migration, 0 avec. PAS encore contre la production — c'est le premier
-- lancement `--linked` qui le dira. Les cas 5, 6, 9 et 10 sont les témoins :
-- un 1:1 se crée toujours, un membre ouvre toujours la discussion de son
-- groupe, le propriétaire exclut toujours, un groupe hérité garde son chemin.
--
-- Le banc fabrique ses deux groupes, ses membres et ses conversations ; rien
-- de réel n'est touché, et tout est annulé à la fin.

BEGIN;

SET LOCAL lock_timeout = '5s';

CREATE TEMP TABLE resultat(n int, cas text, attendu text, obtenu text, verdict text);
CREATE TEMP TABLE ctx(k text PRIMARY KEY, v text);
GRANT ALL ON resultat, ctx TO anon, authenticated;

INSERT INTO ctx VALUES
  ('proprio',   'banc-fabrique-proprio'),
  ('membre',    'banc-fabrique-membre'),
  ('victime',   'banc-fabrique-victime'),
  ('admin',     'banc-fabrique-admin'),
  ('intrus',    'banc-fabrique-intrus'),
  ('g',         gen_random_uuid()::text),   -- groupe avec sa discussion
  ('g2',        gen_random_uuid()::text),   -- groupe sans discussion
  ('conv_c',    'banc-fabrique-c-'  || gen_random_uuid()::text),
  ('conv_f',    'banc-fabrique-f-'  || gen_random_uuid()::text),
  ('conv_new',  'banc-fabrique-n-'  || gen_random_uuid()::text),
  ('conv_m',    'banc-fabrique-m-'  || gen_random_uuid()::text);

CREATE TEMP VIEW c AS SELECT k, v FROM ctx;
GRANT SELECT ON c TO anon, authenticated;

INSERT INTO public.groups (id, name, creator_id, is_private)
SELECT v::uuid, 'Banc fabrique ' || k, (SELECT v FROM ctx WHERE k='proprio'), true
  FROM ctx WHERE k IN ('g', 'g2');

-- G : propriétaire, admin, membre, victime. G2 : propriétaire, membre, victime.
INSERT INTO public.group_members (group_id, user_id, role)
SELECT (SELECT v FROM ctx WHERE k='g')::uuid, x.u, x.r
  FROM (VALUES ((SELECT v FROM ctx WHERE k='proprio'), 'owner'),
               ((SELECT v FROM ctx WHERE k='admin'),   'admin'),
               ((SELECT v FROM ctx WHERE k='membre'),  'member'),
               ((SELECT v FROM ctx WHERE k='victime'), 'member')) AS x(u, r);
INSERT INTO public.group_members (group_id, user_id, role)
SELECT (SELECT v FROM ctx WHERE k='g2')::uuid, x.u, x.r
  FROM (VALUES ((SELECT v FROM ctx WHERE k='proprio'), 'owner'),
               ((SELECT v FROM ctx WHERE k='membre'),  'member'),
               ((SELECT v FROM ctx WHERE k='victime'), 'member')) AS x(u, r);

-- La discussion canonique de G, posée par le serveur.
INSERT INTO public.conversations (id, type, group_id, participant_ids, created_by, data)
SELECT (SELECT v FROM ctx WHERE k='conv_c'), 'group', (SELECT v FROM ctx WHERE k='g'),
       ARRAY[(SELECT v FROM ctx WHERE k='proprio'), (SELECT v FROM ctx WHERE k='admin'),
             (SELECT v FROM ctx WHERE k='membre'),  (SELECT v FROM ctx WHERE k='victime')],
       (SELECT v FROM ctx WHERE k='proprio'),
       jsonb_build_object('adminIds', jsonb_build_array((SELECT v FROM ctx WHERE k='proprio')));

-- Une conversation FABRIQUÉE avant la migration (insérée ici par le serveur,
-- comme si elle datait d'avant) : type 'individual', rattachée à G, l'intrus
-- s'y dit admin.
INSERT INTO public.conversations (id, type, group_id, participant_ids, created_by, data)
SELECT (SELECT v FROM ctx WHERE k='conv_f'), 'individual', (SELECT v FROM ctx WHERE k='g'),
       ARRAY[(SELECT v FROM ctx WHERE k='intrus'), (SELECT v FROM ctx WHERE k='proprio'),
             (SELECT v FROM ctx WHERE k='membre')],
       (SELECT v FROM ctx WHERE k='intrus'),
       jsonb_build_object('adminIds', jsonb_build_array((SELECT v FROM ctx WHERE k='intrus')));

-- @@MIGRATION@@

CREATE FUNCTION pg_temp.etre(p text) RETURNS void LANGUAGE sql AS $$
  SELECT set_config('request.jwt.claims',
    json_build_object('sub', '00000000-0000-0000-0000-0000000000f2',
                      'role', 'authenticated',
                      'app_metadata', json_build_object('firebase_uid',
                        (SELECT v FROM pg_temp.ctx WHERE k = p)))::text, true);
$$;
CREATE FUNCTION pg_temp.membres_de(p text) RETURNS int LANGUAGE sql SECURITY DEFINER AS $$
  SELECT count(*)::int FROM public.group_members
   WHERE group_id = (SELECT v FROM pg_temp.ctx WHERE k = p)::uuid;
$$;
CREATE FUNCTION pg_temp.est_membre(g text, u text) RETURNS boolean LANGUAGE sql SECURITY DEFINER AS $$
  SELECT EXISTS (SELECT 1 FROM public.group_members
   WHERE group_id = (SELECT v FROM pg_temp.ctx WHERE k = g)::uuid
     AND user_id  = (SELECT v FROM pg_temp.ctx WHERE k = u));
$$;
CREATE FUNCTION pg_temp.ligne(p text) RETURNS public.conversations LANGUAGE sql SECURITY DEFINER AS $$
  SELECT * FROM public.conversations WHERE id = (SELECT v FROM pg_temp.ctx WHERE k = p);
$$;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA pg_temp TO authenticated;

SET LOCAL ROLE authenticated;

INSERT INTO resultat VALUES (0, 'rôle effectif du banc', 'authenticated', current_user,
  CASE WHEN current_user = 'authenticated' THEN 'OK' ELSE 'ÉCHEC' END);

-- 1. L'attaque, premier temps : un étranger à G fabrique une conversation
--    'individual' rattachée à G, où il se dit admin.
DO $$
BEGIN
  PERFORM pg_temp.etre('intrus');
  INSERT INTO public.conversations (id, type, group_id, participant_ids, created_by, data)
  VALUES ((SELECT v FROM c WHERE k='conv_new'), 'individual', (SELECT v FROM c WHERE k='g'),
          ARRAY[(SELECT v FROM c WHERE k='intrus'), (SELECT v FROM c WHERE k='proprio'),
                (SELECT v FROM c WHERE k='victime')],
          (SELECT v FROM c WHERE k='intrus'),
          jsonb_build_object('adminIds', jsonb_build_array((SELECT v FROM c WHERE k='intrus'))));
  INSERT INTO resultat VALUES (1, 'un étranger fabrique une conversation rattachée au groupe',
    'REFUSÉ 42501', 'ACCEPTÉ', 'ÉCHEC');
EXCEPTION WHEN OTHERS THEN
  INSERT INTO resultat VALUES (1, 'un étranger fabrique une conversation rattachée au groupe',
    'REFUSÉ 42501', 'REFUSÉ ' || SQLSTATE,
    CASE WHEN SQLSTATE = '42501' THEN 'OK' ELSE 'ÉCHEC' END);
END $$;

-- 2. Variante : un étranger ouvre LA discussion d'un groupe qui n'en a pas.
DO $$
BEGIN
  PERFORM pg_temp.etre('intrus');
  INSERT INTO public.conversations (id, type, group_id, participant_ids, created_by, data)
  VALUES ((SELECT v FROM c WHERE k='conv_new') || '-2', 'group', (SELECT v FROM c WHERE k='g2'),
          ARRAY[(SELECT v FROM c WHERE k='intrus')], (SELECT v FROM c WHERE k='intrus'), '{}'::jsonb);
  INSERT INTO resultat VALUES (2, 'un étranger ouvre la discussion d''un groupe',
    'REFUSÉ 42501', 'ACCEPTÉ', 'ÉCHEC');
EXCEPTION WHEN OTHERS THEN
  INSERT INTO resultat VALUES (2, 'un étranger ouvre la discussion d''un groupe',
    'REFUSÉ 42501', 'REFUSÉ ' || SQLSTATE,
    CASE WHEN SQLSTATE = '42501' THEN 'OK' ELSE 'ÉCHEC' END);
END $$;

-- 3. L'attaque, second temps, sur une conversation fabriquée AVANT la
--    migration : vider les participants pour vider le groupe.
DO $$
DECLARE avant int := pg_temp.membres_de('g'); apres int; rejet text := '';
BEGIN
  PERFORM pg_temp.etre('intrus');
  BEGIN
    UPDATE public.conversations SET participant_ids = ARRAY[(SELECT v FROM c WHERE k='intrus')]
     WHERE id = (SELECT v FROM c WHERE k='conv_f');
  EXCEPTION WHEN OTHERS THEN rejet := ' (REFUSÉ ' || SQLSTATE || ')';
  END;
  apres := pg_temp.membres_de('g');
  INSERT INTO resultat VALUES (3, 'conversation fabriquée : retirer les participants vide le groupe ?',
    avant || ' membres restent', apres || ' membres' || rejet,
    CASE WHEN apres = avant THEN 'OK' ELSE 'ÉCHEC' END);
END $$;

-- 4. Même conversation fabriquée : exclure par la RPC.
DO $$
BEGIN
  PERFORM pg_temp.etre('intrus');
  PERFORM public.exclure_du_groupe((SELECT v FROM c WHERE k='conv_f'), (SELECT v FROM c WHERE k='membre'));
  INSERT INTO resultat VALUES (4, 'conversation fabriquée : exclure_du_groupe',
    'REFUSÉ 42501', 'ACCEPTÉ', 'ÉCHEC');
EXCEPTION WHEN OTHERS THEN
  INSERT INTO resultat VALUES (4, 'conversation fabriquée : exclure_du_groupe',
    'REFUSÉ 42501', 'REFUSÉ ' || SQLSTATE,
    CASE WHEN SQLSTATE = '42501' THEN 'OK' ELSE 'ÉCHEC' END);
END $$;

-- 5. Témoin : un 1:1 sans groupe se crée toujours.
DO $$
BEGIN
  PERFORM pg_temp.etre('intrus');
  INSERT INTO public.conversations (id, type, participant_ids, created_by, data)
  VALUES ((SELECT v FROM c WHERE k='conv_new') || '-1a1', 'individual',
          ARRAY[(SELECT v FROM c WHERE k='intrus'), (SELECT v FROM c WHERE k='membre')],
          (SELECT v FROM c WHERE k='intrus'), '{}'::jsonb);
  INSERT INTO resultat VALUES (5, 'témoin : un 1:1 se crée', 'ACCEPTÉ', 'ACCEPTÉ', 'OK');
EXCEPTION WHEN OTHERS THEN
  INSERT INTO resultat VALUES (5, 'témoin : un 1:1 se crée', 'ACCEPTÉ',
    'REFUSÉ ' || SQLSTATE || ' ' || left(SQLERRM, 60), 'ÉCHEC');
END $$;

-- 6. Témoin : un simple membre ouvre la discussion de son groupe (comme
--    `createGroupConversation`, qui le met dans adminIds).
DO $$
BEGIN
  PERFORM pg_temp.etre('membre');
  INSERT INTO public.conversations (id, type, group_id, participant_ids, created_by, data)
  VALUES ((SELECT v FROM c WHERE k='conv_m'), 'group', (SELECT v FROM c WHERE k='g2'),
          ARRAY[(SELECT v FROM c WHERE k='intrus'), (SELECT v FROM c WHERE k='membre'),
                (SELECT v FROM c WHERE k='proprio'), (SELECT v FROM c WHERE k='victime')],
          (SELECT v FROM c WHERE k='membre'),
          jsonb_build_object('adminIds', jsonb_build_array((SELECT v FROM c WHERE k='membre'))));
  INSERT INTO resultat VALUES (6, 'témoin : un membre ouvre la discussion de son groupe',
    'ACCEPTÉ', 'ACCEPTÉ', 'OK');
EXCEPTION WHEN OTHERS THEN
  INSERT INTO resultat VALUES (6, 'témoin : un membre ouvre la discussion de son groupe',
    'ACCEPTÉ', 'REFUSÉ ' || SQLSTATE || ' ' || left(SQLERRM, 60), 'ÉCHEC');
END $$;

-- 7. … mais ni l'étranger qu'il y glisse, ni son titre d'admin n'y entrent.
DO $$
DECLARE r public.conversations := pg_temp.ligne('conv_m');
BEGIN
  INSERT INTO resultat VALUES (7, 'discussion ouverte : participants ramenés aux membres, adminIds aux admins',
    'sans l''intrus, adminIds = []',
    'participants=' || COALESCE(array_to_string(r.participant_ids, ','), '∅')
      || ' adminIds=' || COALESCE((r.data->'adminIds')::text, '∅'),
    CASE WHEN r.id IS NOT NULL
          AND NOT (r.participant_ids @> ARRAY[(SELECT v FROM c WHERE k='intrus')])
          AND COALESCE(jsonb_array_length(r.data->'adminIds'), 0) = 0
         THEN 'OK' ELSE 'ÉCHEC' END);
END $$;

-- 8. Ce membre ne peut donc pas exclure par cette discussion.
DO $$
BEGIN
  PERFORM pg_temp.etre('membre');
  PERFORM public.exclure_du_groupe((SELECT v FROM c WHERE k='conv_m'), (SELECT v FROM c WHERE k='victime'));
  INSERT INTO resultat VALUES (8, 'le membre qui a ouvert la discussion exclut',
    'REFUSÉ 42501', 'ACCEPTÉ', 'ÉCHEC');
EXCEPTION WHEN OTHERS THEN
  INSERT INTO resultat VALUES (8, 'le membre qui a ouvert la discussion exclut',
    'REFUSÉ 42501', 'REFUSÉ ' || SQLSTATE,
    CASE WHEN SQLSTATE = '42501' THEN 'OK' ELSE 'ÉCHEC' END);
END $$;

-- 9. Témoin : le propriétaire exclut toujours par la discussion canonique.
DO $$
BEGIN
  PERFORM pg_temp.etre('proprio');
  PERFORM public.exclure_du_groupe((SELECT v FROM c WHERE k='conv_c'), (SELECT v FROM c WHERE k='victime'));
  INSERT INTO resultat VALUES (9, 'témoin : le propriétaire exclut',
    'victime sortie du groupe',
    CASE WHEN pg_temp.est_membre('g', 'victime') THEN 'victime encore membre' ELSE 'victime sortie' END,
    CASE WHEN pg_temp.est_membre('g', 'victime') THEN 'ÉCHEC' ELSE 'OK' END);
EXCEPTION WHEN OTHERS THEN
  INSERT INTO resultat VALUES (9, 'témoin : le propriétaire exclut', 'victime sortie du groupe',
    'REFUSÉ ' || SQLSTATE || ' ' || left(SQLERRM, 60), 'ÉCHEC');
END $$;

-- 10. Témoin : groupe hérité de Firestore (id non UUID) — seul le type compte.
DO $$
BEGIN
  PERFORM pg_temp.etre('intrus');
  INSERT INTO public.conversations (id, type, group_id, participant_ids, created_by, data)
  VALUES ((SELECT v FROM c WHERE k='conv_new') || '-h', 'group', 'banc-heritage-' || gen_random_uuid(),
          ARRAY[(SELECT v FROM c WHERE k='intrus')], (SELECT v FROM c WHERE k='intrus'), '{}'::jsonb);
  INSERT INTO resultat VALUES (10, 'témoin : discussion d''un groupe hérité', 'ACCEPTÉ', 'ACCEPTÉ', 'OK');
EXCEPTION WHEN OTHERS THEN
  INSERT INTO resultat VALUES (10, 'témoin : discussion d''un groupe hérité', 'ACCEPTÉ',
    'REFUSÉ ' || SQLSTATE || ' ' || left(SQLERRM, 60), 'ÉCHEC');
END $$;

-- 11. Filet : un admin retire le propriétaire des participants — la
--     synchronisation ne supprime pas sa ligne de propriétaire.
DO $$
DECLARE rejet text := '';
BEGIN
  PERFORM pg_temp.etre('admin');
  BEGIN
    UPDATE public.conversations
       SET participant_ids = array_remove(participant_ids, (SELECT v FROM c WHERE k='proprio'))
     WHERE id = (SELECT v FROM c WHERE k='conv_c');
  EXCEPTION WHEN OTHERS THEN rejet := ' (REFUSÉ ' || SQLSTATE || ')';
  END;
  INSERT INTO resultat VALUES (11, 'filet : le propriétaire reste membre du groupe',
    'propriétaire membre',
    CASE WHEN pg_temp.est_membre('g', 'proprio') THEN 'propriétaire membre' ELSE 'propriétaire SUPPRIMÉ' END || rejet,
    CASE WHEN pg_temp.est_membre('g', 'proprio') THEN 'OK' ELSE 'ÉCHEC' END);
END $$;

RESET ROLE;

SELECT n, verdict, cas, attendu, obtenu FROM resultat ORDER BY n, cas;

ROLLBACK;
