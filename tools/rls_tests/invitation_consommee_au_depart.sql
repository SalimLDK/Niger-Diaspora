-- Banc : une personne exclue d'un groupe privé n'y revient plus grâce à son
-- ancienne invitation (migration 20261014110000).
--
--   supabase db query --linked -f tools/rls_tests/invitation_consommee_au_depart.sql
--
-- Condition : 0 cas en ÉCHEC. Tout est dans un `BEGIN … ROLLBACK`.
--
-- AVANT `db push` : remplacer la ligne seule `-- @@MIGRATION@@` par le contenu
-- de la migration — c'est la répétition. APRÈS, lancé tel quel, le banc prouve
-- l'état vivant.
--
-- Sans la migration, les cas 3 et 5 tombent : la personne exclue se réinscrit
-- seule, et celle qui est partie aussi (4 et 7 suivent, l'exclu étant déjà
-- rentré au cas 3). Vérifié le 2026-10-14 sur un PostgreSQL 16 local
-- (`has_group_invite` de 20260909201500, porte `group_members_insert_gate` de
-- 20260806210000) : quatre ÉCHEC sans la migration, 0 avec. PAS encore contre la production. Les cas 1, 2, 6 et 7
-- sont les témoins : l'invitation fait toujours entrer (dans l'ordre de
-- l'application, l'adhésion puis le statut), et une nouvelle invitation fait
-- revenir.
--
-- Le banc fabrique son groupe privé, ses membres et ses invitations ; tout
-- est annulé à la fin.

BEGIN;

SET LOCAL lock_timeout = '5s';

CREATE TEMP TABLE resultat(n int, cas text, attendu text, obtenu text, verdict text);
CREATE TEMP TABLE ctx(k text PRIMARY KEY, v text);
GRANT ALL ON resultat, ctx TO anon, authenticated;

INSERT INTO ctx VALUES
  ('proprio', 'banc-invit-proprio'),
  ('exclu',   'banc-invit-exclu'),
  ('partant', 'banc-invit-partant'),
  ('g',       gen_random_uuid()::text);

INSERT INTO public.groups (id, name, creator_id, is_private)
SELECT (SELECT v FROM ctx WHERE k='g')::uuid, 'Banc invitation consommée',
       (SELECT v FROM ctx WHERE k='proprio'), true;

INSERT INTO public.group_members (group_id, user_id, role)
SELECT (SELECT v FROM ctx WHERE k='g')::uuid, (SELECT v FROM ctx WHERE k='proprio'), 'owner';

-- Deux invitations du propriétaire.
INSERT INTO public.group_invites (group_id, inviter_id, invitee_id, status)
SELECT (SELECT v FROM ctx WHERE k='g')::uuid, (SELECT v FROM ctx WHERE k='proprio'), x.u, 'pending'
  FROM (VALUES ((SELECT v FROM ctx WHERE k='exclu')),
               ((SELECT v FROM ctx WHERE k='partant'))) AS x(u);

-- @@MIGRATION@@

CREATE FUNCTION pg_temp.etre(p text) RETURNS void LANGUAGE sql AS $$
  SELECT set_config('request.jwt.claims',
    json_build_object('sub', '00000000-0000-0000-0000-0000000000f4',
                      'role', 'authenticated',
                      'app_metadata', json_build_object('firebase_uid',
                        (SELECT v FROM pg_temp.ctx WHERE k = p)))::text, true);
$$;
CREATE FUNCTION pg_temp.est_membre(u text) RETURNS boolean LANGUAGE sql SECURITY DEFINER AS $$
  SELECT EXISTS (SELECT 1 FROM public.group_members
   WHERE group_id = (SELECT v FROM pg_temp.ctx WHERE k = 'g')::uuid
     AND user_id  = (SELECT v FROM pg_temp.ctx WHERE k = u));
$$;
-- Ce que fait l'administrateur qui exclut, côté serveur : la ligne disparaît.
CREATE FUNCTION pg_temp.exclure(u text) RETURNS void LANGUAGE sql SECURITY DEFINER AS $$
  DELETE FROM public.group_members
   WHERE group_id = (SELECT v FROM pg_temp.ctx WHERE k = 'g')::uuid
     AND user_id  = (SELECT v FROM pg_temp.ctx WHERE k = u);
$$;
CREATE FUNCTION pg_temp.accepter(u text) RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  -- L'ordre de `acceptGroupInvite` : l'adhésion, puis le statut.
  INSERT INTO public.group_members (group_id, user_id, role)
  VALUES ((SELECT v FROM pg_temp.ctx WHERE k = 'g')::uuid, (SELECT v FROM pg_temp.ctx WHERE k = u), 'member');
  UPDATE public.group_invites SET status = 'accepted', responded_at = now()
   WHERE group_id = (SELECT v FROM pg_temp.ctx WHERE k = 'g')::uuid
     AND invitee_id = (SELECT v FROM pg_temp.ctx WHERE k = u);
END;
$$;
CREATE FUNCTION pg_temp.rentrer_seul(u text) RETURNS text LANGUAGE plpgsql AS $$
BEGIN
  INSERT INTO public.group_members (group_id, user_id, role)
  VALUES ((SELECT v FROM pg_temp.ctx WHERE k = 'g')::uuid, (SELECT v FROM pg_temp.ctx WHERE k = u), 'member');
  RETURN 'ACCEPTÉ';
EXCEPTION WHEN OTHERS THEN
  RETURN 'REFUSÉ ' || SQLSTATE;
END;
$$;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA pg_temp TO authenticated;

SET LOCAL ROLE authenticated;

INSERT INTO resultat VALUES (0, 'rôle effectif du banc', 'authenticated', current_user,
  CASE WHEN current_user = 'authenticated' THEN 'OK' ELSE 'ÉCHEC' END);

-- 1-2. Témoins : les deux invités acceptent et entrent.
DO $$
BEGIN
  PERFORM pg_temp.etre('exclu');   PERFORM pg_temp.accepter('exclu');
  PERFORM pg_temp.etre('partant'); PERFORM pg_temp.accepter('partant');
  INSERT INTO resultat VALUES (1, 'témoin : l''invitation fait entrer (exclu)', 'membre',
    CASE WHEN pg_temp.est_membre('exclu') THEN 'membre' ELSE 'absent' END,
    CASE WHEN pg_temp.est_membre('exclu') THEN 'OK' ELSE 'ÉCHEC' END);
  INSERT INTO resultat VALUES (2, 'témoin : l''invitation fait entrer (partant)', 'membre',
    CASE WHEN pg_temp.est_membre('partant') THEN 'membre' ELSE 'absent' END,
    CASE WHEN pg_temp.est_membre('partant') THEN 'OK' ELSE 'ÉCHEC' END);
EXCEPTION WHEN OTHERS THEN
  INSERT INTO resultat VALUES (1, 'témoin : l''invitation fait entrer', 'membre',
    'REFUSÉ ' || SQLSTATE || ' ' || left(SQLERRM, 60), 'ÉCHEC');
END $$;

-- 3. Exclu, il se réinscrit seul.
DO $$
DECLARE r text;
BEGIN
  PERFORM pg_temp.exclure('exclu');
  PERFORM pg_temp.etre('exclu');
  r := pg_temp.rentrer_seul('exclu');
  INSERT INTO resultat VALUES (3, 'l''exclu se réinscrit seul dans le groupe privé',
    'REFUSÉ 42501', r, CASE WHEN pg_temp.est_membre('exclu') THEN 'ÉCHEC' ELSE 'OK' END);
END $$;

-- 4. … même en remettant son invitation à 'pending' (s'il la voit encore).
DO $$
DECLARE r text; n int;
BEGIN
  PERFORM pg_temp.etre('exclu');
  UPDATE public.group_invites SET status = 'pending'
   WHERE group_id = (SELECT v FROM ctx WHERE k='g')::uuid
     AND invitee_id = (SELECT v FROM ctx WHERE k='exclu');
  GET DIAGNOSTICS n = ROW_COUNT;
  r := pg_temp.rentrer_seul('exclu');
  INSERT INTO resultat VALUES (4, 'l''exclu ranime son invitation puis entre',
    'REFUSÉ 42501', n || ' invitation(s) ranimée(s), ' || r,
    CASE WHEN pg_temp.est_membre('exclu') THEN 'ÉCHEC' ELSE 'OK' END);
END $$;

-- 5. Parti de lui-même, il revient seul.
DO $$
DECLARE r text;
BEGIN
  PERFORM pg_temp.etre('partant');
  DELETE FROM public.group_members
   WHERE group_id = (SELECT v FROM ctx WHERE k='g')::uuid
     AND user_id = (SELECT v FROM ctx WHERE k='partant');
  r := pg_temp.rentrer_seul('partant');
  INSERT INTO resultat VALUES (5, 'parti, il revient seul dans le groupe privé',
    'REFUSÉ 42501', r, CASE WHEN pg_temp.est_membre('partant') THEN 'ÉCHEC' ELSE 'OK' END);
END $$;

-- 6. Témoin : le propriétaire réinvite l'exclu (upsert de l'application)…
DO $$
BEGIN
  PERFORM pg_temp.etre('proprio');
  INSERT INTO public.group_invites (group_id, inviter_id, invitee_id, status)
  VALUES ((SELECT v FROM ctx WHERE k='g')::uuid, (SELECT v FROM ctx WHERE k='proprio'),
          (SELECT v FROM ctx WHERE k='exclu'), 'pending')
  ON CONFLICT (group_id, invitee_id) DO UPDATE SET status = 'pending', inviter_id = EXCLUDED.inviter_id;
  INSERT INTO resultat VALUES (6, 'témoin : le propriétaire réinvite', 'ACCEPTÉ', 'ACCEPTÉ', 'OK');
EXCEPTION WHEN OTHERS THEN
  INSERT INTO resultat VALUES (6, 'témoin : le propriétaire réinvite', 'ACCEPTÉ',
    'REFUSÉ ' || SQLSTATE || ' ' || left(SQLERRM, 60), 'ÉCHEC');
END $$;

-- 7. … et cette invitation-là le fait revenir.
DO $$
BEGIN
  PERFORM pg_temp.etre('exclu');
  PERFORM pg_temp.accepter('exclu');
  INSERT INTO resultat VALUES (7, 'témoin : la nouvelle invitation fait revenir', 'membre',
    CASE WHEN pg_temp.est_membre('exclu') THEN 'membre' ELSE 'absent' END,
    CASE WHEN pg_temp.est_membre('exclu') THEN 'OK' ELSE 'ÉCHEC' END);
EXCEPTION WHEN OTHERS THEN
  INSERT INTO resultat VALUES (7, 'témoin : la nouvelle invitation fait revenir', 'membre',
    'REFUSÉ ' || SQLSTATE || ' ' || left(SQLERRM, 60), 'ÉCHEC');
END $$;

RESET ROLE;

SELECT n, verdict, cas, attendu, obtenu FROM resultat ORDER BY n, cas;

ROLLBACK;
