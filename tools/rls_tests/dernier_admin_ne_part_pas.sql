-- Banc : le dernier administrateur ne quitte pas un groupe qui a encore des
-- membres (migration 20261014140000).
--
--   supabase db query --linked -f tools/rls_tests/dernier_admin_ne_part_pas.sql
--
-- Condition : 0 cas en ÉCHEC. Tout est dans un `BEGIN … ROLLBACK`.
--
-- AVANT `db push` : remplacer la ligne seule `-- @@MIGRATION@@` par le contenu
-- de la migration — c'est la répétition. APRÈS, lancé tel quel, le banc prouve
-- l'état vivant.
--
-- Sans la migration, le cas 1 tombe. Les cas 2 à 5 sont les témoins : un
-- membre part, un admin part quand il en reste un autre, le dernier membre
-- part, et une exclusion côté serveur n'est pas concernée.

BEGIN;

SET LOCAL lock_timeout = '5s';

CREATE TEMP TABLE resultat(n int, cas text, attendu text, obtenu text, verdict text);
CREATE TEMP TABLE ctx(k text PRIMARY KEY, v text);
GRANT ALL ON resultat, ctx TO anon, authenticated;

INSERT INTO ctx VALUES
  ('proprio', 'banc-dernier-proprio'),
  ('admin2',  'banc-dernier-admin2'),
  ('membre',  'banc-dernier-membre'),
  ('seul',    'banc-dernier-seul'),
  ('g',       gen_random_uuid()::text),   -- propriétaire + membre
  ('g2',      gen_random_uuid()::text),   -- deux admins + membre
  ('g3',      gen_random_uuid()::text);   -- un seul membre, propriétaire

INSERT INTO public.groups (id, name, creator_id, is_private)
SELECT v::uuid, 'Banc dernier admin ' || k, (SELECT v FROM ctx WHERE k='proprio'), false
  FROM ctx WHERE k IN ('g', 'g2', 'g3');

INSERT INTO public.group_members (group_id, user_id, role)
SELECT (SELECT v FROM ctx WHERE k=x.g)::uuid, (SELECT v FROM ctx WHERE k=x.u), x.r
  FROM (VALUES ('g', 'proprio', 'owner'), ('g', 'membre', 'member'),
               ('g2', 'proprio', 'owner'), ('g2', 'admin2', 'admin'), ('g2', 'membre', 'member'),
               ('g3', 'seul', 'owner')) AS x(g, u, r);

-- @@MIGRATION@@

CREATE FUNCTION pg_temp.etre(p text) RETURNS void LANGUAGE sql AS $$
  SELECT set_config('request.jwt.claims',
    json_build_object('sub', '00000000-0000-0000-0000-0000000000f6',
                      'role', 'authenticated',
                      'app_metadata', json_build_object('firebase_uid',
                        (SELECT v FROM pg_temp.ctx WHERE k = p)))::text, true);
$$;
CREATE FUNCTION pg_temp.est_membre(g text, u text) RETURNS boolean LANGUAGE sql SECURITY DEFINER AS $$
  SELECT EXISTS (SELECT 1 FROM public.group_members
   WHERE group_id = (SELECT v FROM pg_temp.ctx WHERE k = g)::uuid
     AND user_id  = (SELECT v FROM pg_temp.ctx WHERE k = u));
$$;
CREATE FUNCTION pg_temp.partir(qui text, g text) RETURNS text LANGUAGE plpgsql AS $$
BEGIN
  PERFORM pg_temp.etre(qui);
  DELETE FROM public.group_members
   WHERE group_id = (SELECT v FROM pg_temp.ctx WHERE k = g)::uuid
     AND user_id  = (SELECT v FROM pg_temp.ctx WHERE k = qui);
  RETURN 'ACCEPTÉ';
EXCEPTION WHEN OTHERS THEN
  RETURN 'REFUSÉ ' || SQLSTATE;
END;
$$;
CREATE FUNCTION pg_temp.exclure_serveur(g text, u text) RETURNS void LANGUAGE sql SECURITY DEFINER AS $$
  DELETE FROM public.group_members
   WHERE group_id = (SELECT v FROM pg_temp.ctx WHERE k = g)::uuid
     AND user_id  = (SELECT v FROM pg_temp.ctx WHERE k = u);
$$;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA pg_temp TO authenticated;

SET LOCAL ROLE authenticated;

INSERT INTO resultat VALUES (0, 'rôle effectif du banc', 'authenticated', current_user,
  CASE WHEN current_user = 'authenticated' THEN 'OK' ELSE 'ÉCHEC' END);

-- 1. Le seul administrateur part en laissant un membre.
DO $$
DECLARE r text := pg_temp.partir('proprio', 'g');
BEGIN
  INSERT INTO resultat VALUES (1, 'le dernier admin quitte un groupe qui a des membres',
    'REFUSÉ 42501', r, CASE WHEN pg_temp.est_membre('g', 'proprio') THEN 'OK' ELSE 'ÉCHEC' END);
END $$;

-- 2. Témoin : un simple membre part.
DO $$
DECLARE r text := pg_temp.partir('membre', 'g2');
BEGIN
  INSERT INTO resultat VALUES (2, 'témoin : un membre part', 'ACCEPTÉ', r,
    CASE WHEN NOT pg_temp.est_membre('g2', 'membre') THEN 'OK' ELSE 'ÉCHEC' END);
END $$;

-- 3. Témoin : un admin part quand il en reste un autre.
DO $$
DECLARE r text := pg_temp.partir('proprio', 'g2');
BEGIN
  INSERT INTO resultat VALUES (3, 'témoin : un admin part, un autre reste', 'ACCEPTÉ', r,
    CASE WHEN NOT pg_temp.est_membre('g2', 'proprio') THEN 'OK' ELSE 'ÉCHEC' END);
END $$;

-- 4. Témoin : le dernier membre, administrateur, part.
DO $$
DECLARE r text := pg_temp.partir('seul', 'g3');
BEGIN
  INSERT INTO resultat VALUES (4, 'témoin : le dernier membre part', 'ACCEPTÉ', r,
    CASE WHEN NOT pg_temp.est_membre('g3', 'seul') THEN 'OK' ELSE 'ÉCHEC' END);
END $$;

-- 5. Témoin : une suppression côté serveur n'est pas concernée.
DO $$
BEGIN
  PERFORM pg_temp.exclure_serveur('g', 'proprio');
  INSERT INTO resultat VALUES (5, 'témoin : suppression serveur du dernier admin', 'ACCEPTÉ',
    CASE WHEN pg_temp.est_membre('g', 'proprio') THEN 'encore membre' ELSE 'ACCEPTÉ' END,
    CASE WHEN NOT pg_temp.est_membre('g', 'proprio') THEN 'OK' ELSE 'ÉCHEC' END);
EXCEPTION WHEN OTHERS THEN
  INSERT INTO resultat VALUES (5, 'témoin : suppression serveur du dernier admin', 'ACCEPTÉ',
    'REFUSÉ ' || SQLSTATE, 'ÉCHEC');
END $$;

RESET ROLE;

SELECT n, verdict, cas, attendu, obtenu FROM resultat ORDER BY n, cas;

ROLLBACK;
