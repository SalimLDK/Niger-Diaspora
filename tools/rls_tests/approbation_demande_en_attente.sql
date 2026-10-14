-- Banc : seule une demande d'adhésion en attente s'approuve (migration
-- 20261014160000).
--
--   supabase db query --linked -f tools/rls_tests/approbation_demande_en_attente.sql
--
-- Condition : 0 cas en ÉCHEC. Tout est dans un `BEGIN … ROLLBACK`.
--
-- AVANT `db push` : remplacer la ligne seule `-- @@MIGRATION@@` par le contenu
-- de la migration — c'est la répétition. APRÈS, lancé tel quel, le banc prouve
-- l'état vivant.
--
-- Sans la migration, le cas 1 tombe : approuver une demande annulée fait
-- entrer la personne. Les cas 2 et 3 sont les témoins : une demande en
-- attente s'approuve, et l'approuver deux fois n'est pas une erreur.

BEGIN;

SET LOCAL lock_timeout = '5s';

CREATE TEMP TABLE resultat(n int, cas text, attendu text, obtenu text, verdict text);
CREATE TEMP TABLE ctx(k text PRIMARY KEY, v text);
GRANT ALL ON resultat, ctx TO anon, authenticated;

INSERT INTO ctx VALUES
  ('proprio',  'banc-approb-proprio'),
  ('annule',   'banc-approb-annule'),
  ('attente',  'banc-approb-attente'),
  ('g',        gen_random_uuid()::text),
  ('d_annule', gen_random_uuid()::text),
  ('d_attente', gen_random_uuid()::text);

INSERT INTO public.groups (id, name, creator_id, is_private)
SELECT (SELECT v FROM ctx WHERE k='g')::uuid, 'Banc approbation',
       (SELECT v FROM ctx WHERE k='proprio'), true;

INSERT INTO public.group_members (group_id, user_id, role)
SELECT (SELECT v FROM ctx WHERE k='g')::uuid, (SELECT v FROM ctx WHERE k='proprio'), 'owner';

INSERT INTO public.group_requests (id, group_id, requester_id, status)
SELECT (SELECT v FROM ctx WHERE k=x.d)::uuid, (SELECT v FROM ctx WHERE k='g')::uuid,
       (SELECT v FROM ctx WHERE k=x.u), x.s
  FROM (VALUES ('d_annule', 'annule', 'cancelled'),
               ('d_attente', 'attente', 'pending')) AS x(d, u, s);

-- @@MIGRATION@@

CREATE FUNCTION pg_temp.etre(p text) RETURNS void LANGUAGE sql AS $$
  SELECT set_config('request.jwt.claims',
    json_build_object('sub', '00000000-0000-0000-0000-0000000000f8',
                      'role', 'authenticated',
                      'app_metadata', json_build_object('firebase_uid',
                        (SELECT v FROM pg_temp.ctx WHERE k = p)))::text, true);
$$;
CREATE FUNCTION pg_temp.est_membre(u text) RETURNS boolean LANGUAGE sql SECURITY DEFINER AS $$
  SELECT EXISTS (SELECT 1 FROM public.group_members
   WHERE group_id = (SELECT v FROM pg_temp.ctx WHERE k = 'g')::uuid
     AND user_id  = (SELECT v FROM pg_temp.ctx WHERE k = u));
$$;
CREATE FUNCTION pg_temp.approuver(d text) RETURNS text LANGUAGE plpgsql AS $$
BEGIN
  PERFORM pg_temp.etre('proprio');
  PERFORM public.approve_group_request((SELECT v FROM pg_temp.ctx WHERE k = d)::uuid);
  RETURN 'ACCEPTÉ';
EXCEPTION WHEN OTHERS THEN
  RETURN 'REFUSÉ ' || SQLSTATE;
END;
$$;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA pg_temp TO authenticated;

SET LOCAL ROLE authenticated;

INSERT INTO resultat VALUES (0, 'rôle effectif du banc', 'authenticated', current_user,
  CASE WHEN current_user = 'authenticated' THEN 'OK' ELSE 'ÉCHEC' END);

DO $$
DECLARE r text := pg_temp.approuver('d_annule');
BEGIN
  INSERT INTO resultat VALUES (1, 'approuver une demande annulée', 'REFUSÉ 22023, pas membre',
    r || CASE WHEN pg_temp.est_membre('annule') THEN ', membre' ELSE ', pas membre' END,
    CASE WHEN NOT pg_temp.est_membre('annule') THEN 'OK' ELSE 'ÉCHEC' END);
END $$;

DO $$
DECLARE r text := pg_temp.approuver('d_attente');
BEGIN
  INSERT INTO resultat VALUES (2, 'témoin : approuver une demande en attente', 'ACCEPTÉ, membre',
    r || CASE WHEN pg_temp.est_membre('attente') THEN ', membre' ELSE ', pas membre' END,
    CASE WHEN r = 'ACCEPTÉ' AND pg_temp.est_membre('attente') THEN 'OK' ELSE 'ÉCHEC' END);
END $$;

DO $$
DECLARE r text := pg_temp.approuver('d_attente');
BEGIN
  INSERT INTO resultat VALUES (3, 'témoin : approuver deux fois', 'ACCEPTÉ', r,
    CASE WHEN r = 'ACCEPTÉ' THEN 'OK' ELSE 'ÉCHEC' END);
END $$;

RESET ROLE;

SELECT n, verdict, cas, attendu, obtenu FROM resultat ORDER BY n, cas;

ROLLBACK;
