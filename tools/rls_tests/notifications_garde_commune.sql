-- Banc : réactions chiffrées et invitations ne servent plus à inonder de
-- push, ni à contourner un blocage (migration 20261014190000).
--
--   supabase db query --linked -f tools/rls_tests/notifications_garde_commune.sql
--
-- Condition : 0 cas en ÉCHEC. Tout est dans un `BEGIN … ROLLBACK` — les
-- notifications fabriquées ici disparaissent avec lui (aucune n'est
-- poussée : l'envoi push part d'un `INSERT` validé).
--
-- AVANT `db push` : remplacer la ligne seule `-- @@MIGRATION@@` par le contenu
-- de la migration — c'est la répétition. APRÈS, lancé tel quel, le banc prouve
-- l'état vivant.
--
-- Sans la migration, les cas 1 à 6 tombent. Vérifié le 2026-10-14 sur un
-- PostgreSQL 16 local (déclencheurs de 20260916180000 et 20261014150000) :
-- six ÉCHEC sans la migration, 0 avec. PAS encore contre la production. Les
-- cas 7 à 9 sont les témoins : une vraie réaction prévient, une invitation
-- prévient, et une réinvitation après lecture prévient de nouveau.

BEGIN;

SET LOCAL lock_timeout = '5s';

CREATE TEMP TABLE resultat(n int, cas text, attendu text, obtenu text, verdict text);
CREATE TEMP TABLE ctx(k text PRIMARY KEY, v text);
GRANT ALL ON resultat, ctx TO anon, authenticated;

INSERT INTO ctx VALUES
  ('auteur',   'banc-garde-auteur'),     -- écrit le message
  ('reacteur', 'banc-garde-reacteur'),   -- réagit (et invite)
  ('bloque',   'banc-garde-bloque'),     -- bloqué par l'auteur
  ('conv',     'banc-garde-conv-' || gen_random_uuid()),
  ('dev',      gen_random_uuid()::text),
  ('msg',      gen_random_uuid()::text),
  ('g',        gen_random_uuid()::text);

INSERT INTO public.users (id, display_name)
SELECT v, 'Vrai ' || k FROM ctx WHERE k IN ('auteur', 'reacteur', 'bloque')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.blocked_users (blocker_id, blocked_id)
SELECT (SELECT v FROM ctx WHERE k='auteur'), (SELECT v FROM ctx WHERE k='bloque');

INSERT INTO public.conversations (id, type, participant_ids, created_by, data, mls_since)
SELECT (SELECT v FROM ctx WHERE k='conv'), 'group',
       ARRAY[(SELECT v FROM ctx WHERE k='auteur'), (SELECT v FROM ctx WHERE k='reacteur'),
             (SELECT v FROM ctx WHERE k='bloque')],
       (SELECT v FROM ctx WHERE k='auteur'), '{"name":"Banc garde"}'::jsonb, now() - interval '1 day';

INSERT INTO public.mls_devices (id, user_id, stable_id, name, platform, mls_identity,
                                signature_key, credential)
SELECT (SELECT v FROM ctx WHERE k='dev')::uuid, (SELECT v FROM ctx WHERE k='auteur'),
       'banc-garde', 'Banc', 'android', 'banc-garde-auteur:banc', '\x01'::bytea, '\x01'::bytea;

INSERT INTO public.mls_messages (id, conversation_id, sender_id, sender_device_id, epoch,
                                 kind, content_type, ciphertext)
SELECT (SELECT v FROM ctx WHERE k='msg')::uuid, (SELECT v FROM ctx WHERE k='conv'),
       (SELECT v FROM ctx WHERE k='auteur'), (SELECT v FROM ctx WHERE k='dev')::uuid, 1,
       'content', 'text', '\x01'::bytea;

INSERT INTO public.groups (id, name, creator_id, is_private)
SELECT (SELECT v FROM ctx WHERE k='g')::uuid, 'Banc garde', (SELECT v FROM ctx WHERE k='reacteur'), true;
INSERT INTO public.group_members (group_id, user_id, role)
SELECT (SELECT v FROM ctx WHERE k='g')::uuid, (SELECT v FROM ctx WHERE k='reacteur'), 'owner';

-- @@MIGRATION@@

CREATE FUNCTION pg_temp.etre(p text) RETURNS void LANGUAGE sql AS $$
  SELECT set_config('request.jwt.claims',
    json_build_object('sub', '00000000-0000-0000-0000-0000000000fa',
                      'role', 'authenticated',
                      'app_metadata', json_build_object('firebase_uid',
                        (SELECT v FROM pg_temp.ctx WHERE k = p)))::text, true);
$$;
CREATE FUNCTION pg_temp.nb(u text, t text) RETURNS int LANGUAGE sql SECURITY DEFINER AS $$
  SELECT count(*)::int FROM public.notifications
   WHERE user_id = (SELECT v FROM pg_temp.ctx WHERE k = u) AND type = t;
$$;
-- Le destinataire lit tout : rien n'est plus effacé par le dédoublonnage,
-- chaque notification créée reste comptée — autant de push.
CREATE FUNCTION pg_temp.tout_lire(u text) RETURNS void LANGUAGE sql SECURITY DEFINER AS $$
  UPDATE public.notifications SET is_read = true
   WHERE user_id = (SELECT v FROM pg_temp.ctx WHERE k = u);
$$;
CREATE FUNCTION pg_temp.effacer(u text) RETURNS void LANGUAGE sql SECURITY DEFINER AS $$
  DELETE FROM public.notifications WHERE user_id = (SELECT v FROM pg_temp.ctx WHERE k = u);
$$;
-- Une notification venue d'une source quelconque (fonction serveur).
CREATE FUNCTION pg_temp.notifier(u text, t text, titre text, corps text, donnees jsonb)
RETURNS void LANGUAGE sql SECURITY DEFINER AS $$
  INSERT INTO public.notifications (user_id, type, title, body, data, is_read)
  VALUES ((SELECT v FROM pg_temp.ctx WHERE k = u), t, titre, corps, donnees, false);
$$;
-- (Tout le banc tient dans une transaction : `created_at` y est le même pour
-- toutes les lignes, d'où le filtre par type plutôt qu'un tri.)
CREATE FUNCTION pg_temp.corps_general(u text) RETURNS text LANGUAGE sql SECURITY DEFINER AS $$
  SELECT body FROM public.notifications
   WHERE user_id = (SELECT v FROM pg_temp.ctx WHERE k = u) AND type = 'general' LIMIT 1;
$$;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA pg_temp TO authenticated;

SET LOCAL ROLE authenticated;

INSERT INTO resultat VALUES (0, 'rôle effectif du banc', 'authenticated', current_user,
  CASE WHEN current_user = 'authenticated' THEN 'OK' ELSE 'ÉCHEC' END);

-- 1. Une phrase à la place de l'emoji (réaction chiffrée).
DO $$
DECLARE rejet text := 'ACCEPTÉ';
BEGIN
  PERFORM pg_temp.etre('reacteur');
  BEGIN
    INSERT INTO public.mls_message_reactions (message_id, user_id, emoji)
    VALUES ((SELECT v FROM ctx WHERE k='msg')::uuid, (SELECT v FROM ctx WHERE k='reacteur'),
            'Votre compte sera suspendu : evil.tld');
  EXCEPTION WHEN OTHERS THEN rejet := 'REFUSÉ ' || SQLSTATE;
  END;
  INSERT INTO resultat VALUES (1, 'réaction chiffrée : une phrase pour emoji', 'REFUSÉ 23514', rejet,
    CASE WHEN rejet = 'REFUSÉ 23514' THEN 'OK' ELSE 'ÉCHEC' END);
END $$;

-- 2. … même courte, une adresse.
DO $$
DECLARE rejet text := 'ACCEPTÉ';
BEGIN
  PERFORM pg_temp.etre('reacteur');
  DELETE FROM public.mls_message_reactions
   WHERE message_id = (SELECT v FROM ctx WHERE k='msg')::uuid AND user_id = (SELECT v FROM ctx WHERE k='reacteur');
  BEGIN
    INSERT INTO public.mls_message_reactions (message_id, user_id, emoji)
    VALUES ((SELECT v FROM ctx WHERE k='msg')::uuid, (SELECT v FROM ctx WHERE k='reacteur'), 'evil.tld/x');
  EXCEPTION WHEN OTHERS THEN rejet := 'REFUSÉ ' || SQLSTATE;
  END;
  INSERT INTO resultat VALUES (2, 'réaction chiffrée : une adresse courte pour emoji', 'REFUSÉ 23514', rejet,
    CASE WHEN rejet = 'REFUSÉ 23514' THEN 'OK' ELSE 'ÉCHEC' END);
END $$;

-- 3. Le bloqué réagit : l'auteur n'est pas prévenu.
DO $$
DECLARE n int;
BEGIN
  PERFORM pg_temp.etre('bloque');
  INSERT INTO public.mls_message_reactions (message_id, user_id, emoji)
  VALUES ((SELECT v FROM ctx WHERE k='msg')::uuid, (SELECT v FROM ctx WHERE k='bloque'), '👍');
  n := pg_temp.nb('auteur', 'messageReaction');
  INSERT INTO resultat VALUES (3, 'réaction d''un compte bloqué', '0 notification',
    n || ' notification(s)', CASE WHEN n = 0 THEN 'OK' ELSE 'ÉCHEC' END);
END $$;

-- 4. La boucle : 40 changements d'emoji, chacun lu aussitôt.
DO $$
DECLARE n int; i int; e text[] := ARRAY['👍','❤️','😂','😮'];
BEGIN
  PERFORM pg_temp.etre('reacteur');
  -- (Sans la migration, le cas 1 a posé sa réaction : on repart de zéro.)
  DELETE FROM public.mls_message_reactions
   WHERE message_id = (SELECT v FROM ctx WHERE k='msg')::uuid AND user_id = (SELECT v FROM ctx WHERE k='reacteur');
  INSERT INTO public.mls_message_reactions (message_id, user_id, emoji)
  VALUES ((SELECT v FROM ctx WHERE k='msg')::uuid, (SELECT v FROM ctx WHERE k='reacteur'), '😢');
  PERFORM pg_temp.tout_lire('auteur');
  FOR i IN 1..40 LOOP
    UPDATE public.mls_message_reactions SET emoji = e[1 + i % 4]
     WHERE message_id = (SELECT v FROM ctx WHERE k='msg')::uuid
       AND user_id = (SELECT v FROM ctx WHERE k='reacteur');
    PERFORM pg_temp.tout_lire('auteur');
  END LOOP;
  n := pg_temp.nb('auteur', 'messageReaction');
  INSERT INTO resultat VALUES (4, 'réaction en boucle (41 écritures)', '30 notifications au plus',
    n || ' notification(s)', CASE WHEN n <= 30 THEN 'OK' ELSE 'ÉCHEC' END);
END $$;

-- 5. Une invitation remise « en attente » en boucle.
DO $$
DECLARE n int; i int;
BEGIN
  PERFORM pg_temp.effacer('auteur');
  PERFORM pg_temp.etre('reacteur');
  INSERT INTO public.group_invites (group_id, inviter_id, invitee_id, status)
  VALUES ((SELECT v FROM ctx WHERE k='g')::uuid, (SELECT v FROM ctx WHERE k='reacteur'),
          (SELECT v FROM ctx WHERE k='auteur'), 'pending');
  FOR i IN 1..5 LOOP
    UPDATE public.group_invites SET status = 'cancelled'
     WHERE group_id = (SELECT v FROM ctx WHERE k='g')::uuid AND invitee_id = (SELECT v FROM ctx WHERE k='auteur');
    UPDATE public.group_invites SET status = 'pending'
     WHERE group_id = (SELECT v FROM ctx WHERE k='g')::uuid AND invitee_id = (SELECT v FROM ctx WHERE k='auteur');
  END LOOP;
  n := pg_temp.nb('auteur', 'groupInvite');
  INSERT INTO resultat VALUES (5, 'invitation remise en attente en boucle', '1 notification',
    n || ' notification(s)', CASE WHEN n = 1 THEN 'OK' ELSE 'ÉCHEC' END);
END $$;

-- 6. Un titre démesuré, d'où qu'il vienne : borné.
DO $$
DECLARE b text;
BEGIN
  PERFORM pg_temp.notifier('auteur', 'general', repeat('T', 5000), repeat('C', 5000), '{}'::jsonb);
  b := pg_temp.corps_general('auteur');
  INSERT INTO resultat VALUES (6, 'corps de 5000 caractères', '300 au plus',
    length(b)::text, CASE WHEN length(b) <= 300 THEN 'OK' ELSE 'ÉCHEC' END);
END $$;

-- 7. Témoin : une vraie réaction, par quelqu'un d'autre, prévient.
DO $$
DECLARE n int;
BEGIN
  PERFORM pg_temp.effacer('auteur');
  PERFORM pg_temp.etre('reacteur');
  DELETE FROM public.mls_message_reactions
   WHERE message_id = (SELECT v FROM ctx WHERE k='msg')::uuid AND user_id = (SELECT v FROM ctx WHERE k='reacteur');
  PERFORM pg_temp.notifier('auteur', 'messageReaction', 'Banc', 'Vrai témoin a réagi 🎉',
    jsonb_build_object('actor_id', 'banc-garde-temoin', 'emoji', '🎉', 'messageId', 'x'));
  n := pg_temp.nb('auteur', 'messageReaction');
  INSERT INTO resultat VALUES (7, 'témoin : une réaction ordinaire prévient', '1 notification',
    n || ' notification(s)', CASE WHEN n = 1 THEN 'OK' ELSE 'ÉCHEC' END);
END $$;

-- 8. Témoin : une invitation ordinaire prévient.
DO $$
DECLARE n int;
BEGIN
  PERFORM pg_temp.etre('reacteur');
  INSERT INTO public.group_invites (group_id, inviter_id, invitee_id, status)
  VALUES ((SELECT v FROM ctx WHERE k='g')::uuid, (SELECT v FROM ctx WHERE k='reacteur'),
          (SELECT v FROM ctx WHERE k='bloque'), 'pending');
  n := pg_temp.nb('bloque', 'groupInvite');
  INSERT INTO resultat VALUES (8, 'témoin : une invitation prévient', '1 notification',
    n || ' notification(s)', CASE WHEN n = 1 THEN 'OK' ELSE 'ÉCHEC' END);
END $$;

-- 9. Témoin : lue, l'invitation peut être renouvelée.
DO $$
DECLARE n int;
BEGIN
  PERFORM pg_temp.tout_lire('bloque');
  PERFORM pg_temp.etre('reacteur');
  UPDATE public.group_invites SET status = 'cancelled'
   WHERE group_id = (SELECT v FROM ctx WHERE k='g')::uuid AND invitee_id = (SELECT v FROM ctx WHERE k='bloque');
  UPDATE public.group_invites SET status = 'pending'
   WHERE group_id = (SELECT v FROM ctx WHERE k='g')::uuid AND invitee_id = (SELECT v FROM ctx WHERE k='bloque');
  n := pg_temp.nb('bloque', 'groupInvite');
  INSERT INTO resultat VALUES (9, 'témoin : après lecture, une réinvitation prévient', '2 notifications',
    n || ' notification(s)', CASE WHEN n = 2 THEN 'OK' ELSE 'ÉCHEC' END);
END $$;

RESET ROLE;

SELECT n, verdict, cas, attendu, obtenu FROM resultat ORDER BY n, cas;

ROLLBACK;
