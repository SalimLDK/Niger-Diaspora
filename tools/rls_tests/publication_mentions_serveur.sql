-- Banc : une publication ne pousse plus de texte libre vers une liste de
-- destinataires choisie (migration 20261014180000).
--
--   supabase db query --linked -f tools/rls_tests/publication_mentions_serveur.sql
--
-- Condition : 0 cas en ÉCHEC. Tout est dans un `BEGIN … ROLLBACK` — les
-- notifications fabriquées ici disparaissent avec lui (aucune n'est
-- poussée : l'envoi push part d'un `INSERT` validé).
--
-- AVANT `db push` : remplacer la ligne seule `-- @@MIGRATION@@` par le contenu
-- de la migration — c'est la répétition. APRÈS, lancé tel quel, le banc prouve
-- l'état vivant.
--
-- Sans la migration, les cas 1 à 5 et 9 tombent. Vérifié le 2026-10-14 sur
-- un PostgreSQL 16 local (déclencheur de 20260912230000) : six ÉCHEC sans la
-- migration, 0 avec. PAS encore contre la production. Les cas 6 à 8 sont les
-- témoins : un groupe dont l'auteur est membre prévient ses membres, une
-- mention prévient la personne citée, et un « groupe pays » de l'écran des
-- mentions prévient les profils visibles de ce pays (le compatriote du banc
-- est daté de demain, pour être dans les 50 premiers en production).

BEGIN;

SET LOCAL lock_timeout = '5s';

CREATE TEMP TABLE resultat(n int, cas text, attendu text, obtenu text, verdict text);
CREATE TEMP TABLE ctx(k text PRIMARY KEY, v text);
GRANT ALL ON resultat, ctx TO anon, authenticated;

INSERT INTO ctx VALUES
  ('auteur',   'banc-pub-auteur'),
  ('abonne',   'banc-pub-abonne'),
  ('etranger', 'banc-pub-etranger'),
  ('membre',   'banc-pub-membre'),
  ('bloqueur', 'banc-pub-bloqueur'),
  ('compatriote', 'banc-pub-compatriote'),
  ('g_sien',   gen_random_uuid()::text),
  ('g_autre',  gen_random_uuid()::text);

INSERT INTO public.users (id, display_name)
SELECT v, 'Vrai ' || k FROM ctx WHERE k IN ('auteur','abonne','etranger','membre','bloqueur')
ON CONFLICT (id) DO NOTHING;
-- Trente comptes à mentionner d'un coup.
INSERT INTO public.users (id, display_name)
SELECT 'banc-pub-foule-' || i, 'Foule ' || i FROM generate_series(1, 30) i
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.users (id, display_name, country_code, is_visible, last_active_at)
SELECT v, 'Vrai compatriote', 'Niger', true, now() + interval '1 day' FROM ctx WHERE k = 'compatriote'
ON CONFLICT (id) DO UPDATE SET country_code = 'Niger', is_visible = true, last_active_at = now() + interval '1 day';

INSERT INTO public.user_follows (follower_id, following_id)
SELECT (SELECT v FROM ctx WHERE k='abonne'), (SELECT v FROM ctx WHERE k='auteur');

INSERT INTO public.blocked_users (blocker_id, blocked_id)
SELECT (SELECT v FROM ctx WHERE k='bloqueur'), (SELECT v FROM ctx WHERE k='auteur');

INSERT INTO public.groups (id, name, creator_id, is_private)
VALUES ((SELECT v FROM ctx WHERE k='g_sien')::uuid,  'Groupe de l''auteur', (SELECT v FROM ctx WHERE k='auteur'), false),
       ((SELECT v FROM ctx WHERE k='g_autre')::uuid, 'Groupe sans l''auteur', (SELECT v FROM ctx WHERE k='membre'), false);
INSERT INTO public.group_members (group_id, user_id, role)
VALUES ((SELECT v FROM ctx WHERE k='g_sien')::uuid,  (SELECT v FROM ctx WHERE k='auteur'), 'owner'),
       ((SELECT v FROM ctx WHERE k='g_sien')::uuid,  (SELECT v FROM ctx WHERE k='membre'), 'member'),
       ((SELECT v FROM ctx WHERE k='g_autre')::uuid, (SELECT v FROM ctx WHERE k='membre'), 'owner'),
       ((SELECT v FROM ctx WHERE k='g_autre')::uuid, (SELECT v FROM ctx WHERE k='abonne'), 'member');

-- @@MIGRATION@@

CREATE FUNCTION pg_temp.etre(p text) RETURNS void LANGUAGE sql AS $$
  SELECT set_config('request.jwt.claims',
    json_build_object('sub', '00000000-0000-0000-0000-0000000000f9',
                      'role', 'authenticated',
                      'app_metadata', json_build_object('firebase_uid',
                        (SELECT v FROM pg_temp.ctx WHERE k = p)))::text, true);
$$;
-- Les notifications d'un destinataire pour UNE publication.
CREATE FUNCTION pg_temp.notifs(u text, post text) RETURNS TABLE(type text, title text, body text)
LANGUAGE sql SECURITY DEFINER AS $$
  SELECT type, title, body FROM public.notifications
   WHERE user_id = COALESCE((SELECT v FROM pg_temp.ctx WHERE k = u), u)
     AND data->>'postId' = post;
$$;
CREATE FUNCTION pg_temp.nb_notifs(post text) RETURNS int LANGUAGE sql SECURITY DEFINER AS $$
  SELECT count(*)::int FROM public.notifications WHERE data->>'postId' = post;
$$;
-- Publie comme l'application (`feed_supabase_datasource.dart:228`).
CREATE FUNCTION pg_temp.publier(champs jsonb) RETURNS text LANGUAGE plpgsql AS $$
DECLARE v_id text := gen_random_uuid()::text;
BEGIN
  PERFORM pg_temp.etre('auteur');
  INSERT INTO public.posts (id, author_id, author_name, content, visibility, mentioned_users, mentioned_groups)
  VALUES (v_id::uuid, (SELECT v FROM pg_temp.ctx WHERE k='auteur'),
          COALESCE(champs->>'author_name', 'Vrai auteur'),
          COALESCE(champs->>'content', 'Bonjour'), 'public',
          COALESCE(champs->'mentioned_users', '[]'::jsonb),
          COALESCE(champs->'mentioned_groups', '[]'::jsonb));
  RETURN v_id;
END;
$$;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA pg_temp TO authenticated;

SET LOCAL ROLE authenticated;

INSERT INTO resultat VALUES (0, 'rôle effectif du banc', 'authenticated', current_user,
  CASE WHEN current_user = 'authenticated' THEN 'OK' ELSE 'ÉCHEC' END);

-- 1. Nom d'auteur inventé : l'abonné lit le nom du profil.
DO $$
DECLARE p text := pg_temp.publier('{"author_name":"Service client Diaspo"}');
        t text;
BEGIN
  SELECT title INTO t FROM pg_temp.notifs('abonne', p) WHERE type = 'new_post';
  INSERT INTO resultat VALUES (1, 'nom d''auteur inventé', 'Vrai auteur', COALESCE(t, '∅'),
    CASE WHEN t = 'Vrai auteur' THEN 'OK' ELSE 'ÉCHEC' END);
END $$;

-- 2. Groupe fabriqué : nom et destinataires écrits dans la publication.
DO $$
DECLARE p text := pg_temp.publier(jsonb_build_object('mentioned_groups', jsonb_build_array(
          jsonb_build_object('id', 'faux', 'name', 'Sécurité Diaspo : vérifiez votre compte sur evil.tld',
                             'memberIds', jsonb_build_array((SELECT v FROM ctx WHERE k='etranger'))))));
        n int;
BEGIN
  SELECT count(*) INTO n FROM pg_temp.notifs('etranger', p);
  INSERT INTO resultat VALUES (2, 'groupe fabriqué : texte et destinataires libres', '0 notification',
    n || ' notification(s)', CASE WHEN n = 0 THEN 'OK' ELSE 'ÉCHEC' END);
END $$;

-- 3. Vrai groupe dont l'auteur n'est pas membre, avec une liste gonflée.
DO $$
DECLARE p text := pg_temp.publier(jsonb_build_object('mentioned_groups', jsonb_build_array(
          jsonb_build_object('id', (SELECT v FROM ctx WHERE k='g_autre'), 'name', 'x',
                             'memberIds', jsonb_build_array((SELECT v FROM ctx WHERE k='etranger'),
                                                            (SELECT v FROM ctx WHERE k='membre'))))));
        n int := pg_temp.nb_notifs(p);
BEGIN
  -- L'abonné reçoit son « new_post », rien d'autre.
  INSERT INTO resultat VALUES (3, 'groupe dont l''auteur n''est pas membre', '1 notification (new_post)',
    n || ' notification(s)', CASE WHEN n = 1 THEN 'OK' ELSE 'ÉCHEC' END);
END $$;

-- 4. Mentionner quelqu'un qui a bloqué l'auteur.
DO $$
DECLARE p text := pg_temp.publier(jsonb_build_object('mentioned_users', jsonb_build_array(
          jsonb_build_object('id', (SELECT v FROM ctx WHERE k='bloqueur'), 'name', 'b'))));
        n int;
BEGIN
  SELECT count(*) INTO n FROM pg_temp.notifs('bloqueur', p);
  INSERT INTO resultat VALUES (4, 'mention d''un compte qui a bloqué l''auteur', '0 notification',
    n || ' notification(s)', CASE WHEN n = 0 THEN 'OK' ELSE 'ÉCHEC' END);
END $$;

-- 5. Trente mentions d'un coup : vingt au plus.
DO $$
DECLARE p text := pg_temp.publier(jsonb_build_object('mentioned_users',
          (SELECT jsonb_agg(jsonb_build_object('id', 'banc-pub-foule-' || i, 'name', 'f'))
             FROM generate_series(1, 30) i)));
        n int := pg_temp.nb_notifs(p) - 1;  -- moins le « new_post » de l'abonné
BEGIN
  INSERT INTO resultat VALUES (5, 'trente mentions d''un coup', '20 notifications',
    n || ' notification(s)', CASE WHEN n = 20 THEN 'OK' ELSE 'ÉCHEC' END);
END $$;

-- 6. Témoin : le groupe de l'auteur prévient ses membres (tel que l'app
--    l'écrit, `memberIds` compris).
DO $$
DECLARE p text := pg_temp.publier(jsonb_build_object('mentioned_groups', jsonb_build_array(
          jsonb_build_object('id', (SELECT v FROM ctx WHERE k='g_sien'), 'name', 'GroupeDeLAuteur',
                             'memberIds', jsonb_build_array((SELECT v FROM ctx WHERE k='membre'))))));
        n int;
BEGIN
  SELECT count(*) INTO n FROM pg_temp.notifs('membre', p) WHERE type = 'group_mention';
  INSERT INTO resultat VALUES (6, 'témoin : le groupe de l''auteur prévient ses membres',
    '1 notification', n || ' notification(s)', CASE WHEN n = 1 THEN 'OK' ELSE 'ÉCHEC' END);
END $$;

-- 7. Témoin : une mention prévient la personne citée.
DO $$
DECLARE p text := pg_temp.publier(jsonb_build_object('mentioned_users', jsonb_build_array(
          jsonb_build_object('id', (SELECT v FROM ctx WHERE k='etranger'), 'name', 'e'))));
        b text;
BEGIN
  SELECT body INTO b FROM pg_temp.notifs('etranger', p) WHERE type = 'mentioned';
  INSERT INTO resultat VALUES (7, 'témoin : la personne mentionnée est prévenue',
    'Vrai auteur vous a mentionné(e)…', COALESCE(b, '∅'),
    CASE WHEN b = 'Vrai auteur vous a mentionné(e) dans une publication' THEN 'OK' ELSE 'ÉCHEC' END);
END $$;

-- 8. Témoin : un « groupe pays » prévient ses profils visibles (tel que
--    l'écran des mentions l'écrit, `memberIds` compris).
DO $$
DECLARE p text := pg_temp.publier(jsonb_build_object('mentioned_groups', jsonb_build_array(
          jsonb_build_object('id', 'country_Niger', 'name', 'AmisNiger',
                             'memberIds', jsonb_build_array((SELECT v FROM ctx WHERE k='compatriote'))))));
        n int;
BEGIN
  SELECT count(*) INTO n FROM pg_temp.notifs('compatriote', p) WHERE type = 'group_mention';
  INSERT INTO resultat VALUES (8, 'témoin : un groupe pays prévient ses compatriotes', '1 notification',
    n || ' notification(s)', CASE WHEN n = 1 THEN 'OK' ELSE 'ÉCHEC' END);
END $$;

-- 9. Un « pays » inventé, avec ses destinataires.
DO $$
DECLARE p text := pg_temp.publier(jsonb_build_object('mentioned_groups', jsonb_build_array(
          jsonb_build_object('id', 'country_evil.tld', 'name', 'Vérifiez votre compte',
                             'memberIds', jsonb_build_array((SELECT v FROM ctx WHERE k='etranger'))))));
        n int;
BEGIN
  SELECT count(*) INTO n FROM pg_temp.notifs('etranger', p) WHERE type = 'group_mention';
  INSERT INTO resultat VALUES (9, 'groupe pays inventé', '0 notification',
    n || ' notification(s)', CASE WHEN n = 0 THEN 'OK' ELSE 'ÉCHEC' END);
END $$;

RESET ROLE;

SELECT n, verdict, cas, attendu, obtenu FROM resultat ORDER BY n, cas;

ROLLBACK;
