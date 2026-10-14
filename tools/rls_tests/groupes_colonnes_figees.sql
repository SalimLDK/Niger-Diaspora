-- Banc : `id`, `creator_id`, `member_count`, `created_at` et `ville_id` d'un
-- groupe ne se réécrivent plus depuis le client (migration 20261014100000).
--
--   supabase db query --linked -f tools/rls_tests/groupes_colonnes_figees.sql
--
-- Condition : 0 cas en ÉCHEC. Tout est dans un `BEGIN … ROLLBACK`.
--
-- AVANT `db push` : remplacer la ligne seule `-- @@MIGRATION@@` par le contenu
-- de la migration — c'est la répétition. APRÈS, lancé tel quel, le banc prouve
-- l'état vivant.
--
-- Sans la migration, les cas 1, 2 et 3 tombent : un administrateur promu se
-- fait créateur (puis `delete_group` le laisserait tout effacer), et falsifie
-- le compteur et la ville. Vérifié le 2026-10-14 sur un PostgreSQL 16 local
-- (policy `groups_update_admin` de 20260813234500, compteur de
-- 20260913030000) : trois ÉCHEC sans la migration, 0 avec. PAS encore contre
-- la production. Les cas 4 et 5 sont les témoins : l'admin modifie toujours
-- son groupe, et une adhésion fait toujours monter le compteur (écrit par une
-- fonction SECURITY DEFINER, non concernée).
--
-- Le banc fabrique son groupe et ses membres ; tout est annulé à la fin.

BEGIN;

SET LOCAL lock_timeout = '5s';

CREATE TEMP TABLE resultat(n int, cas text, attendu text, obtenu text, verdict text);
CREATE TEMP TABLE ctx(k text PRIMARY KEY, v text);
GRANT ALL ON resultat, ctx TO anon, authenticated;

INSERT INTO ctx VALUES
  ('proprio', 'banc-figes-proprio'),
  ('admin',   'banc-figes-admin'),
  ('nouveau', 'banc-figes-nouveau'),
  ('g',       gen_random_uuid()::text);

INSERT INTO public.groups (id, name, creator_id, is_private)
SELECT (SELECT v FROM ctx WHERE k='g')::uuid, 'Banc colonnes figées',
       (SELECT v FROM ctx WHERE k='proprio'), false;

INSERT INTO public.group_members (group_id, user_id, role)
SELECT (SELECT v FROM ctx WHERE k='g')::uuid, x.u, x.r
  FROM (VALUES ((SELECT v FROM ctx WHERE k='proprio'), 'owner'),
               ((SELECT v FROM ctx WHERE k='admin'),   'admin')) AS x(u, r);

-- @@MIGRATION@@

CREATE FUNCTION pg_temp.etre(p text) RETURNS void LANGUAGE sql AS $$
  SELECT set_config('request.jwt.claims',
    json_build_object('sub', '00000000-0000-0000-0000-0000000000f3',
                      'role', 'authenticated',
                      'app_metadata', json_build_object('firebase_uid',
                        (SELECT v FROM pg_temp.ctx WHERE k = p)))::text, true);
$$;
CREATE FUNCTION pg_temp.groupe() RETURNS public.groups LANGUAGE sql SECURITY DEFINER AS $$
  SELECT * FROM public.groups WHERE id = (SELECT v FROM pg_temp.ctx WHERE k = 'g')::uuid;
$$;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA pg_temp TO authenticated;

SET LOCAL ROLE authenticated;

INSERT INTO resultat VALUES (0, 'rôle effectif du banc', 'authenticated', current_user,
  CASE WHEN current_user = 'authenticated' THEN 'OK' ELSE 'ÉCHEC' END);

-- 1. Un admin promu se fait créateur.
DO $$
DECLARE rejet text := '';
BEGIN
  PERFORM pg_temp.etre('admin');
  BEGIN
    UPDATE public.groups SET creator_id = (SELECT v FROM ctx WHERE k='admin')
     WHERE id = (SELECT v FROM ctx WHERE k='g')::uuid;
  EXCEPTION WHEN OTHERS THEN rejet := 'REFUSÉ ' || SQLSTATE;
  END;
  INSERT INTO resultat VALUES (1, 'un admin promu se fait créateur',
    'créateur inchangé', COALESCE(NULLIF(rejet, ''), 'créateur = ' || (pg_temp.groupe()).creator_id),
    CASE WHEN (pg_temp.groupe()).creator_id = (SELECT v FROM ctx WHERE k='proprio') THEN 'OK' ELSE 'ÉCHEC' END);
END $$;

-- 2. Il falsifie le compteur de membres.
DO $$
DECLARE avant int := (pg_temp.groupe()).member_count; rejet text := '';
BEGIN
  PERFORM pg_temp.etre('admin');
  BEGIN
    UPDATE public.groups SET member_count = 50000
     WHERE id = (SELECT v FROM ctx WHERE k='g')::uuid;
  EXCEPTION WHEN OTHERS THEN rejet := 'REFUSÉ ' || SQLSTATE;
  END;
  INSERT INTO resultat VALUES (2, 'un admin falsifie member_count',
    'compteur inchangé (' || avant || ')',
    COALESCE(NULLIF(rejet, ''), 'compteur = ' || (pg_temp.groupe()).member_count),
    CASE WHEN (pg_temp.groupe()).member_count = avant THEN 'OK' ELSE 'ÉCHEC' END);
END $$;

-- 3. Il rattache son groupe à une ville (ville_id = 1, sans clé étrangère
--    vérifiée ici : le refus doit tomber avant).
DO $$
DECLARE rejet text := '';
BEGIN
  PERFORM pg_temp.etre('admin');
  BEGIN
    UPDATE public.groups SET ville_id = 1
     WHERE id = (SELECT v FROM ctx WHERE k='g')::uuid;
  EXCEPTION WHEN OTHERS THEN rejet := 'REFUSÉ ' || SQLSTATE;
  END;
  INSERT INTO resultat VALUES (3, 'un admin réécrit ville_id',
    'REFUSÉ 42501', COALESCE(NULLIF(rejet, ''), 'ville_id = ' || COALESCE((pg_temp.groupe()).ville_id::text, '∅')),
    CASE WHEN rejet = 'REFUSÉ 42501' THEN 'OK' ELSE 'ÉCHEC' END);
END $$;

-- 4. Témoin : l'admin modifie toujours ce que l'écran d'édition écrit.
DO $$
DECLARE n int;
BEGIN
  PERFORM pg_temp.etre('admin');
  UPDATE public.groups SET name = 'Banc renommé', description = 'banc', is_private = true
   WHERE id = (SELECT v FROM ctx WHERE k='g')::uuid;
  GET DIAGNOSTICS n = ROW_COUNT;
  INSERT INTO resultat VALUES (4, 'témoin : l''admin modifie son groupe', '1 ligne',
    n || ' ligne(s)', CASE WHEN n = 1 THEN 'OK' ELSE 'ÉCHEC' END);
EXCEPTION WHEN OTHERS THEN
  INSERT INTO resultat VALUES (4, 'témoin : l''admin modifie son groupe', '1 ligne',
    'REFUSÉ ' || SQLSTATE || ' ' || left(SQLERRM, 60), 'ÉCHEC');
END $$;

-- 5. Témoin : une adhésion fait monter le compteur (fonction serveur).
DO $$
DECLARE avant int := (pg_temp.groupe()).member_count;
BEGIN
  PERFORM pg_temp.etre('nouveau');
  INSERT INTO public.group_members (group_id, user_id, role)
  VALUES ((SELECT v FROM ctx WHERE k='g')::uuid, (SELECT v FROM ctx WHERE k='nouveau'), 'member');
  INSERT INTO resultat VALUES (5, 'témoin : une adhésion fait monter le compteur',
    (avant + 1)::text, (pg_temp.groupe()).member_count::text,
    CASE WHEN (pg_temp.groupe()).member_count = avant + 1 THEN 'OK' ELSE 'ÉCHEC' END);
EXCEPTION WHEN OTHERS THEN
  INSERT INTO resultat VALUES (5, 'témoin : une adhésion fait monter le compteur',
    (avant + 1)::text, 'REFUSÉ ' || SQLSTATE || ' ' || left(SQLERRM, 60), 'ÉCHEC');
END $$;

RESET ROLE;

SELECT n, verdict, cas, attendu, obtenu FROM resultat ORDER BY n, cas;

ROLLBACK;
