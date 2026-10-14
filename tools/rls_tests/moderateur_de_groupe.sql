-- Banc : nommer un modérateur pose `group_members.role = 'moderator'`, que
-- lit le serveur (migration 20261014130000).
--
--   supabase db query --linked -f tools/rls_tests/moderateur_de_groupe.sql
--
-- Condition : 0 cas en ÉCHEC. Tout est dans un `BEGIN … ROLLBACK`.
--
-- AVANT `db push` : remplacer la ligne seule `-- @@MIGRATION@@` par le contenu
-- de la migration — c'est la répétition. APRÈS, lancé tel quel, le banc prouve
-- l'état vivant.
--
-- Sans la migration, la RPC n'existe pas : les cas 1 à 4 et 6 tombent.
-- Vérifié le 2026-10-14 sur un PostgreSQL 16 local (garde
-- `guard_group_members_role` de 20260917010000) : cinq ÉCHEC sans la
-- migration, 0 avec. PAS encore contre la production. Le cas 5 est le témoin
-- de la garde existante : le rôle ne change toujours pas par écriture
-- directe.

BEGIN;

SET LOCAL lock_timeout = '5s';

CREATE TEMP TABLE resultat(n int, cas text, attendu text, obtenu text, verdict text);
CREATE TEMP TABLE ctx(k text PRIMARY KEY, v text);
GRANT ALL ON resultat, ctx TO anon, authenticated;

INSERT INTO ctx VALUES
  ('proprio', 'banc-modo-proprio'),
  ('admin',   'banc-modo-admin'),
  ('membre',  'banc-modo-membre'),
  ('ancien',  'banc-modo-ancien'),   -- nommé par l'ancien chemin
  ('g',       gen_random_uuid()::text);

INSERT INTO public.groups (id, name, creator_id, is_private, moderator_ids)
SELECT (SELECT v FROM ctx WHERE k='g')::uuid, 'Banc modérateur',
       (SELECT v FROM ctx WHERE k='proprio'), false,
       ARRAY[(SELECT v FROM ctx WHERE k='ancien')];

INSERT INTO public.group_members (group_id, user_id, role)
SELECT (SELECT v FROM ctx WHERE k='g')::uuid, x.u, x.r
  FROM (VALUES ((SELECT v FROM ctx WHERE k='proprio'), 'owner'),
               ((SELECT v FROM ctx WHERE k='admin'),   'admin'),
               ((SELECT v FROM ctx WHERE k='membre'),  'member'),
               ((SELECT v FROM ctx WHERE k='ancien'),  'member')) AS x(u, r);

-- @@MIGRATION@@

CREATE FUNCTION pg_temp.etre(p text) RETURNS void LANGUAGE sql AS $$
  SELECT set_config('request.jwt.claims',
    json_build_object('sub', '00000000-0000-0000-0000-0000000000f5',
                      'role', 'authenticated',
                      'app_metadata', json_build_object('firebase_uid',
                        (SELECT v FROM pg_temp.ctx WHERE k = p)))::text, true);
$$;
CREATE FUNCTION pg_temp.role_de(u text) RETURNS text LANGUAGE sql SECURITY DEFINER AS $$
  SELECT role FROM public.group_members
   WHERE group_id = (SELECT v FROM pg_temp.ctx WHERE k = 'g')::uuid
     AND user_id  = (SELECT v FROM pg_temp.ctx WHERE k = u);
$$;
CREATE FUNCTION pg_temp.liste_modos() RETURNS text[] LANGUAGE sql SECURITY DEFINER AS $$
  SELECT moderator_ids FROM public.groups WHERE id = (SELECT v FROM pg_temp.ctx WHERE k = 'g')::uuid;
$$;
CREATE FUNCTION pg_temp.basculer(qui text, cible text, oui boolean) RETURNS text LANGUAGE plpgsql AS $$
BEGIN
  PERFORM pg_temp.etre(qui);
  EXECUTE 'SELECT public.basculer_moderateur_du_groupe($1, $2, $3)'
    USING (SELECT v FROM pg_temp.ctx WHERE k = 'g')::uuid,
          (SELECT v FROM pg_temp.ctx WHERE k = cible), oui;
  RETURN 'ACCEPTÉ';
EXCEPTION WHEN OTHERS THEN
  RETURN 'REFUSÉ ' || SQLSTATE;
END;
$$;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA pg_temp TO authenticated;

SET LOCAL ROLE authenticated;

INSERT INTO resultat VALUES (0, 'rôle effectif du banc', 'authenticated', current_user,
  CASE WHEN current_user = 'authenticated' THEN 'OK' ELSE 'ÉCHEC' END);

-- 1. L'admin nomme un membre modérateur : le rôle ET la liste.
DO $$
DECLARE r text := pg_temp.basculer('admin', 'membre', true);
BEGIN
  INSERT INTO resultat VALUES (1, 'l''admin nomme un modérateur',
    'role=moderator, dans moderator_ids',
    r || ', role=' || COALESCE(pg_temp.role_de('membre'), '∅')
      || ', liste=' || array_to_string(pg_temp.liste_modos(), ','),
    CASE WHEN pg_temp.role_de('membre') = 'moderator'
          AND pg_temp.liste_modos() @> ARRAY[(SELECT v FROM ctx WHERE k='membre')]
         THEN 'OK' ELSE 'ÉCHEC' END);
END $$;

-- 2. Un simple membre ne nomme personne.
DO $$
DECLARE r text := pg_temp.basculer('ancien', 'admin', true);
BEGIN
  INSERT INTO resultat VALUES (2, 'un membre nomme un modérateur', 'REFUSÉ 42501', r,
    CASE WHEN r = 'REFUSÉ 42501' THEN 'OK' ELSE 'ÉCHEC' END);
END $$;

-- 3. On ne rétrograde pas le propriétaire en passant par là.
DO $$
DECLARE r text := pg_temp.basculer('admin', 'proprio', false);
BEGIN
  INSERT INTO resultat VALUES (3, 'l''admin touche au rôle du propriétaire', 'REFUSÉ 22023',
    r || ', role=' || COALESCE(pg_temp.role_de('proprio'), '∅'),
    CASE WHEN r = 'REFUSÉ 22023' AND pg_temp.role_de('proprio') = 'owner' THEN 'OK' ELSE 'ÉCHEC' END);
END $$;

-- 4. L'admin retire le modérateur : rôle et liste reviennent.
DO $$
DECLARE r text := pg_temp.basculer('admin', 'membre', false);
BEGIN
  INSERT INTO resultat VALUES (4, 'l''admin retire un modérateur',
    'role=member, hors de moderator_ids',
    r || ', role=' || COALESCE(pg_temp.role_de('membre'), '∅'),
    CASE WHEN pg_temp.role_de('membre') = 'member'
          AND NOT (pg_temp.liste_modos() @> ARRAY[(SELECT v FROM ctx WHERE k='membre')])
          AND r = 'ACCEPTÉ'
         THEN 'OK' ELSE 'ÉCHEC' END);
END $$;

-- 5. Témoin : le rôle ne change toujours pas par écriture directe.
DO $$
DECLARE rejet text := 'ACCEPTÉ';
BEGIN
  PERFORM pg_temp.etre('membre');
  BEGIN
    UPDATE public.group_members SET role = 'moderator'
     WHERE group_id = (SELECT v FROM ctx WHERE k='g')::uuid
       AND user_id = (SELECT v FROM ctx WHERE k='membre');
  EXCEPTION WHEN OTHERS THEN rejet := 'REFUSÉ ' || SQLSTATE;
  END;
  INSERT INTO resultat VALUES (5, 'témoin : se nommer soi-même par écriture directe',
    'refusé, role=member', rejet || ', role=' || COALESCE(pg_temp.role_de('membre'), '∅'),
    CASE WHEN pg_temp.role_de('membre') = 'member' THEN 'OK' ELSE 'ÉCHEC' END);
END $$;

-- 6. Rattrapage : le modérateur nommé par l'ancien chemin a son rôle.
INSERT INTO resultat VALUES (6, 'rattrapage : moderator_ids d''avant devient un rôle',
  'role=moderator', 'role=' || COALESCE(pg_temp.role_de('ancien'), '∅'),
  CASE WHEN pg_temp.role_de('ancien') = 'moderator' THEN 'OK' ELSE 'ÉCHEC' END);

RESET ROLE;

SELECT n, verdict, cas, attendu, obtenu FROM resultat ORDER BY n, cas;

ROLLBACK;
