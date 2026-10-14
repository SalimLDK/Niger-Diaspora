-- Banc : les notifications de demande d'adhésion et d'invitation portent les
-- noms du serveur, et une demande ne se répète pas en boucle (migration
-- 20261014150000).
--
--   supabase db query --linked -f tools/rls_tests/notifications_de_groupe_noms_serveur.sql
--
-- Condition : 0 cas en ÉCHEC. Tout est dans un `BEGIN … ROLLBACK` — les
-- notifications fabriquées ici disparaissent avec lui (aucune n'est
-- poussée : l'envoi push part d'un `INSERT` validé).
--
-- AVANT `db push` : remplacer la ligne seule `-- @@MIGRATION@@` par le contenu
-- de la migration — c'est la répétition. APRÈS, lancé tel quel, le banc prouve
-- l'état vivant.
--
-- Sans la migration, les cas 1 à 4 tombent (le 4 par le surplus du 2 : trois
-- notifications pour un aller-retour). Vérifié le 2026-10-14 sur un
-- PostgreSQL 16 local (déclencheurs de 20260909223000) : quatre ÉCHEC sans la
-- migration, 0 avec. Le cas 4 est le témoin : une nouvelle demande, après
-- lecture de la précédente, prévient de nouveau.

BEGIN;

SET LOCAL lock_timeout = '5s';

CREATE TEMP TABLE resultat(n int, cas text, attendu text, obtenu text, verdict text);
CREATE TEMP TABLE ctx(k text PRIMARY KEY, v text);
GRANT ALL ON resultat, ctx TO anon, authenticated;

INSERT INTO ctx VALUES
  ('proprio',   'banc-notif-proprio'),
  ('demandeur', 'banc-notif-demandeur'),
  ('g',         gen_random_uuid()::text);

INSERT INTO public.users (id, display_name)
SELECT v, 'Vrai ' || k FROM ctx WHERE k IN ('proprio', 'demandeur')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.groups (id, name, creator_id, is_private)
SELECT (SELECT v FROM ctx WHERE k='g')::uuid, 'Vrai groupe banc',
       (SELECT v FROM ctx WHERE k='proprio'), true;

INSERT INTO public.group_members (group_id, user_id, role)
SELECT (SELECT v FROM ctx WHERE k='g')::uuid, (SELECT v FROM ctx WHERE k='proprio'), 'owner';

-- @@MIGRATION@@

CREATE FUNCTION pg_temp.etre(p text) RETURNS void LANGUAGE sql AS $$
  SELECT set_config('request.jwt.claims',
    json_build_object('sub', '00000000-0000-0000-0000-0000000000f7',
                      'role', 'authenticated',
                      'app_metadata', json_build_object('firebase_uid',
                        (SELECT v FROM pg_temp.ctx WHERE k = p)))::text, true);
$$;
CREATE FUNCTION pg_temp.notifs(u text, t text) RETURNS TABLE(body text) LANGUAGE sql SECURITY DEFINER AS $$
  SELECT body FROM public.notifications
   WHERE user_id = (SELECT v FROM pg_temp.ctx WHERE k = u) AND type = t
   ORDER BY created_at;
$$;
CREATE FUNCTION pg_temp.tout_lire(u text) RETURNS void LANGUAGE sql SECURITY DEFINER AS $$
  UPDATE public.notifications SET is_read = true
   WHERE user_id = (SELECT v FROM pg_temp.ctx WHERE k = u);
$$;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA pg_temp TO authenticated;

SET LOCAL ROLE authenticated;

INSERT INTO resultat VALUES (0, 'rôle effectif du banc', 'authenticated', current_user,
  CASE WHEN current_user = 'authenticated' THEN 'OK' ELSE 'ÉCHEC' END);

-- 1. Une demande aux noms inventés : l'admin lit les vrais noms.
DO $$
DECLARE b text;
BEGIN
  PERFORM pg_temp.etre('demandeur');
  INSERT INTO public.group_requests (group_id, group_name, requester_id, requester_name, status)
  VALUES ((SELECT v FROM ctx WHERE k='g')::uuid, 'Vérifiez votre compte',
          (SELECT v FROM ctx WHERE k='demandeur'), 'Service client', 'pending');
  SELECT string_agg(body, ' | ') INTO b FROM pg_temp.notifs('proprio', 'groupJoinRequest');
  INSERT INTO resultat VALUES (1, 'demande : le texte porte les noms du serveur',
    'Vrai demandeur … Vrai groupe banc', COALESCE(b, '∅'),
    CASE WHEN b LIKE 'Vrai demandeur demande à rejoindre « Vrai groupe banc »' THEN 'OK' ELSE 'ÉCHEC' END);
END $$;

-- 2. Le demandeur fait aller-retour son statut : pas de nouvelle notification.
DO $$
DECLARE n int;
BEGIN
  PERFORM pg_temp.etre('demandeur');
  UPDATE public.group_requests SET status = 'cancelled'
   WHERE requester_id = (SELECT v FROM ctx WHERE k='demandeur');
  UPDATE public.group_requests SET status = 'pending'
   WHERE requester_id = (SELECT v FROM ctx WHERE k='demandeur');
  UPDATE public.group_requests SET status = 'cancelled'
   WHERE requester_id = (SELECT v FROM ctx WHERE k='demandeur');
  UPDATE public.group_requests SET status = 'pending'
   WHERE requester_id = (SELECT v FROM ctx WHERE k='demandeur');
  SELECT count(*) INTO n FROM pg_temp.notifs('proprio', 'groupJoinRequest');
  INSERT INTO resultat VALUES (2, 'demande : le statut en boucle ne renotifie pas',
    '1 notification', n || ' notification(s)', CASE WHEN n = 1 THEN 'OK' ELSE 'ÉCHEC' END);
END $$;

-- 3. Une invitation aux noms inventés (par l'admin) : l'invité lit les vrais.
DO $$
DECLARE b text;
BEGIN
  PERFORM pg_temp.etre('proprio');
  INSERT INTO public.group_invites (group_id, group_name, inviter_id, inviter_name, invitee_id, status)
  VALUES ((SELECT v FROM ctx WHERE k='g')::uuid, 'Groupe officiel du ministère',
          (SELECT v FROM ctx WHERE k='proprio'), 'Le ministre',
          (SELECT v FROM ctx WHERE k='demandeur'), 'pending');
  SELECT string_agg(body, ' | ') INTO b FROM pg_temp.notifs('demandeur', 'groupInvite');
  INSERT INTO resultat VALUES (3, 'invitation : le texte porte les noms du serveur',
    'Vrai proprio … Vrai groupe banc', COALESCE(b, '∅'),
    CASE WHEN b LIKE 'Vrai proprio vous invite à rejoindre « Vrai groupe banc »' THEN 'OK' ELSE 'ÉCHEC' END);
END $$;

-- 4. Témoin : la notification lue, une nouvelle demande prévient de nouveau.
DO $$
DECLARE n int;
BEGIN
  PERFORM pg_temp.tout_lire('proprio');
  PERFORM pg_temp.etre('demandeur');
  UPDATE public.group_requests SET status = 'cancelled'
   WHERE requester_id = (SELECT v FROM ctx WHERE k='demandeur');
  UPDATE public.group_requests SET status = 'pending'
   WHERE requester_id = (SELECT v FROM ctx WHERE k='demandeur');
  SELECT count(*) INTO n FROM pg_temp.notifs('proprio', 'groupJoinRequest');
  INSERT INTO resultat VALUES (4, 'témoin : après lecture, une nouvelle demande prévient',
    '2 notifications', n || ' notification(s)', CASE WHEN n = 2 THEN 'OK' ELSE 'ÉCHEC' END);
END $$;

RESET ROLE;

SELECT n, verdict, cas, attendu, obtenu FROM resultat ORDER BY n, cas;

ROLLBACK;
