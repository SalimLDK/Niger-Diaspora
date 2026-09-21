-- Banc : le texte et les données des notifications entre comptes sont posés
-- par le serveur (migration 20260921100000).
--
--   supabase db query --linked -f tools/rls_tests/notification_textes_serveur.sql
--
-- Condition : 0 cas en ÉCHEC. Tout est dans un `BEGIN … ROLLBACK`.
--
-- AVANT `db push` : remplacer la ligne seule `-- @@MIGRATION@@` par le contenu
-- de la migration — c'est la répétition. APRÈS, lancé tel quel, le banc prouve
-- l'état vivant.
--
-- ⚠️ CE BANC CRÉE DES NOTIFICATIONS, donc met des pushs en file : chaque
-- insertion dans `notifications` déclenche `trg_notify_push`, qui passe par
-- `net.http_post`. C'est TRANSACTIONNEL — le `ROLLBACK` final annule la file
-- (mesuré le 2026-09-21 : voir « Banc et pg_net » dans la mémoire du projet).
-- Les destinataires sont des profils d'essai sans jeton push, sauf pour le cas
-- de l'événement, qui vise son vrai organisateur — annulé comme le reste.

BEGIN;

SET LOCAL lock_timeout = '5s';

CREATE TEMP TABLE resultat(n int, cas text, attendu text, obtenu text, verdict text);
CREATE TEMP TABLE ctx(k text PRIMARY KEY, v text);
GRANT ALL ON resultat, ctx TO anon, authenticated;

INSERT INTO ctx SELECT 'admin', id FROM public.users WHERE is_admin LIMIT 1;
INSERT INTO ctx SELECT 'evt', id::text FROM public.events
 WHERE organizer_id IS NOT NULL ORDER BY created_at DESC LIMIT 1;
INSERT INTO ctx SELECT 'evt_orga', organizer_id FROM public.events
 WHERE id::text = (SELECT v FROM ctx WHERE k = 'evt');

-- @@MIGRATION@@

INSERT INTO public.users (id, display_name, avatar_url) VALUES
  ('banc-nt-a', 'Alice Banc', 'https://exemple.invalid/a.png'),
  ('banc-nt-b', 'Bob Banc',   NULL);

-- Toutes les notifications créées ci-dessous, pour les relire sous `postgres`
-- (la RLS ne les montre qu'à leur destinataire).
CREATE TEMP TABLE crees(n int, id uuid);
GRANT ALL ON crees TO authenticated;

-- ═══ 1. Catalogue ══════════════════════════════════════════════════════════
INSERT INTO resultat
SELECT 1, 'anon ne peut plus exécuter la fonction', 'non',
       CASE WHEN has_function_privilege('anon',
         'public.create_user_notification(text,text,text,text,jsonb)', 'EXECUTE')
            THEN 'oui' ELSE 'non' END,
       CASE WHEN has_function_privilege('anon',
         'public.create_user_notification(text,text,text,text,jsonb)', 'EXECUTE')
            THEN 'ÉCHEC' ELSE 'OK' END;

-- ═══ 2. Alice, compte ordinaire ════════════════════════════════════════════
SELECT set_config('request.jwt.claims',
  jsonb_build_object('role', 'authenticated', 'app_metadata',
    jsonb_build_object('firebase_uid', 'banc-nt-a'))::text, true);
SET LOCAL ROLE authenticated;

-- LE TROU DU TEXTE ET CELUI DES DONNÉES, en un seul appel : un titre
-- d'hameçonnage, et un `type` glissé dans `p_data` pour que `send-push`
-- l'écrive par-dessus le vrai et que l'app ouvre l'écran d'appel entrant.
DO $$
BEGIN
  INSERT INTO crees SELECT 2, public.create_user_notification(
    'banc-nt-b', 'friendRequest',
    'Votre compte sera suspendu', 'Confirmez vos informations sur http://exemple.invalid',
    '{"type":"incoming_call","title":"x","body":"y","callId":"c","callerId":"faux",
      "callerName":"Service Sécurité","senderName":"Équipe Diaspo Niger",
      "click_action":"x","conversationId":"x","targetId":"autre-fiche"}'::jsonb);
EXCEPTION WHEN OTHERS THEN
  INSERT INTO resultat VALUES (2, 'appel falsifié', '-', 'REFUSÉ ' || SQLSTATE || ' ' || SQLERRM, 'ÉCHEC');
END $$;

-- La participation à l'événement d'un TIERS : le titre ne doit pas être cité.
DO $$
BEGIN
  INSERT INTO crees SELECT 3, public.create_user_notification(
    'banc-nt-b', 'eventAttendance', 'x', 'y',
    jsonb_build_object('eventId', coalesce((SELECT v FROM ctx WHERE k = 'evt'),
                                           '00000000-0000-0000-0000-000000000000')));
EXCEPTION WHEN OTHERS THEN
  INSERT INTO resultat VALUES (3, 'événement d''un tiers', '-', 'REFUSÉ ' || SQLSTATE, 'ÉCHEC');
END $$;

-- La participation à l'événement DU destinataire : le titre est cité, lu en base.
DO $$
BEGIN
  IF (SELECT v FROM ctx WHERE k = 'evt') IS NOT NULL THEN
    INSERT INTO crees SELECT 4, public.create_user_notification(
      (SELECT v FROM ctx WHERE k = 'evt_orga'), 'eventAttendance', 'x', 'y',
      jsonb_build_object('eventId', (SELECT v FROM ctx WHERE k = 'evt'),
                         'eventTitle', 'Titre falsifié'));
  END IF;
EXCEPTION WHEN OTHERS THEN
  INSERT INTO resultat VALUES (4, 'événement du destinataire', '-', 'REFUSÉ ' || SQLSTATE, 'ÉCHEC');
END $$;

-- Un appel vidéo de groupe légitime, et un `callType` inventé.
DO $$
BEGIN
  INSERT INTO crees SELECT 5, public.create_user_notification(
    'banc-nt-b', 'groupCallInvitation', 'x', 'y',
    '{"callId":"appel-1","callType":"video","targetId":"appel-1"}'::jsonb);
  INSERT INTO crees SELECT 6, public.create_user_notification(
    'banc-nt-b', 'groupCallInvitation', 'x', 'y',
    '{"callId":"appel-2","callType":"incoming_call","targetId":"appel-2"}'::jsonb);
EXCEPTION WHEN OTHERS THEN
  INSERT INTO resultat VALUES (5, 'appel de groupe', '-', 'REFUSÉ ' || SQLSTATE, 'ÉCHEC');
END $$;

-- Le « j'aime » : le relevé du 2026-09-21 l'avait oublié.
DO $$
BEGIN
  INSERT INTO crees SELECT 7, public.create_user_notification(
    'banc-nt-b', 'postLiked', 'x', 'y',
    '{"postId":"p-1","targetId":"p-1"}'::jsonb);
  INSERT INTO resultat VALUES (7, 'postLiked est accepté', 'accepté', 'accepté', 'OK');
EXCEPTION WHEN OTHERS THEN
  INSERT INTO resultat VALUES (7, 'postLiked est accepté', 'accepté', 'REFUSÉ ' || SQLSTATE, 'ÉCHEC');
END $$;

-- Une commande, alors qu'aucune ne peut plus naître.
DO $$
BEGIN
  PERFORM public.create_user_notification('banc-nt-b', 'newOrder', 'x', 'y', '{}'::jsonb);
  INSERT INTO resultat VALUES (8, 'newOrder est refusé (chaîne de paiement fermée)',
    'refusé 23514', 'ACCEPTÉ', 'ÉCHEC');
EXCEPTION WHEN check_violation THEN
  INSERT INTO resultat VALUES (8, 'newOrder est refusé (chaîne de paiement fermée)',
    'refusé 23514', 'refusé 23514', 'OK');
END $$;

-- Un faux avis de modération.
DO $$
BEGIN
  PERFORM public.create_user_notification('banc-nt-b', 'report_resolved',
    'Contenu supprimé', 'x', '{"contentRemoved":true}'::jsonb);
  INSERT INTO resultat VALUES (9, 'report_resolved par un compte ordinaire',
    'refusé 42501', 'ACCEPTÉ', 'ÉCHEC');
EXCEPTION WHEN insufficient_privilege THEN
  INSERT INTO resultat VALUES (9, 'report_resolved par un compte ordinaire',
    'refusé 42501', 'refusé 42501', 'OK');
END $$;

RESET ROLE;

-- ═══ 3. Le back-office ═════════════════════════════════════════════════════
SELECT set_config('request.jwt.claims',
  jsonb_build_object('role', 'authenticated', 'app_metadata',
    jsonb_build_object('firebase_uid',
      coalesce((SELECT v FROM ctx WHERE k = 'admin'), 'aucun-admin')))::text, true);
SET LOCAL ROLE authenticated;

DO $$
BEGIN
  INSERT INTO crees SELECT 10, public.create_user_notification(
    'banc-nt-b', 'report_resolved', 'x', 'y',
    '{"reportId":"r-1","contentRemoved":true,"targetId":"r-1"}'::jsonb);
EXCEPTION WHEN OTHERS THEN
  INSERT INTO resultat VALUES (10, 'admin : report_resolved', '-', 'REFUSÉ ' || SQLSTATE, 'ÉCHEC');
END $$;

RESET ROLE;

-- ═══ 4. Ce qui a été écrit, relu sous le rôle propriétaire ═════════════════
INSERT INTO resultat
SELECT 2, 'LE TEXTE — le titre d''hameçonnage est remplacé par celui du serveur',
       'Nouvelle demande d''ami · Alice Banc souhaite vous ajouter en ami',
       n.title || ' · ' || n.body,
       CASE WHEN n.title = 'Nouvelle demande d''ami'
             AND n.body = 'Alice Banc souhaite vous ajouter en ami' THEN 'OK' ELSE 'ÉCHEC' END
  FROM crees c JOIN public.notifications n ON n.id = c.id WHERE c.n = 2;

INSERT INTO resultat
SELECT 21, 'LES DONNÉES — ni type, ni title, ni body, ni click_action, ni conversationId',
       '(aucune)',
       coalesce((SELECT string_agg(k, ',' ORDER BY k)
                   FROM jsonb_object_keys(n.data) k
                  WHERE k IN ('type','title','body','click_action','conversationId','callerId','callerName')),
                '(aucune)'),
       CASE WHEN NOT (n.data ?| ARRAY['type','title','body','click_action','conversationId',
                                      'callerId','callerName'])
            THEN 'OK' ELSE 'ÉCHEC' END
  FROM crees c JOIN public.notifications n ON n.id = c.id WHERE c.n = 2;

INSERT INTO resultat
SELECT 22, 'L''IDENTITÉ — senderName et la fiche ouverte viennent de la base',
       'Alice Banc · banc-nt-a',
       coalesce(n.data->>'senderName', '∅') || ' · ' || coalesce(n.data->>'targetId', '∅'),
       CASE WHEN n.data->>'senderName' = 'Alice Banc'
             AND n.data->>'targetId' = 'banc-nt-a' THEN 'OK' ELSE 'ÉCHEC' END
  FROM crees c JOIN public.notifications n ON n.id = c.id WHERE c.n = 2;

INSERT INTO resultat
SELECT 3, 'événement d''un tiers : son titre n''est pas cité', 'Alice Banc participera à votre événement',
       n.body,
       CASE WHEN n.body = 'Alice Banc participera à votre événement' THEN 'OK' ELSE 'ÉCHEC' END
  FROM crees c JOIN public.notifications n ON n.id = c.id WHERE c.n = 3;

INSERT INTO resultat
SELECT 4, 'événement du destinataire : titre lu EN BASE, pas celui envoyé',
       'titre réel, jamais « Titre falsifié »',
       n.body,
       -- Titre réel s'il n'est pas vide, texte générique sinon — jamais
       -- « à "" » (vu sur un événement réel au titre vide), jamais le titre
       -- envoyé par le client.
       CASE WHEN (n.body LIKE 'Alice Banc participera à "_%"'
                  OR n.body = 'Alice Banc participera à votre événement')
             AND n.body NOT LIKE '%Titre falsifié%'
             AND n.data->>'eventTitle' IS DISTINCT FROM 'Titre falsifié' THEN 'OK' ELSE 'ÉCHEC' END
  FROM crees c JOIN public.notifications n ON n.id = c.id WHERE c.n = 4;

INSERT INTO resultat
SELECT 5, 'appel vidéo : titre = nom en base, callType gardé',
       'Alice Banc · vidéo · video',
       n.title || ' · ' || n.body || ' · ' || coalesce(n.data->>'callType', '∅'),
       CASE WHEN n.title = 'Alice Banc' AND n.body LIKE '%vidéo%'
             AND n.data->>'callType' = 'video' AND n.data->>'callerName' = 'Alice Banc'
            THEN 'OK' ELSE 'ÉCHEC' END
  FROM crees c JOIN public.notifications n ON n.id = c.id WHERE c.n = 5;

INSERT INTO resultat
SELECT 6, 'callType inventé : ramené à « audio »', 'audio', coalesce(n.data->>'callType', '∅'),
       CASE WHEN n.data->>'callType' = 'audio' THEN 'OK' ELSE 'ÉCHEC' END
  FROM crees c JOIN public.notifications n ON n.id = c.id WHERE c.n = 6;

INSERT INTO resultat
SELECT 10, 'admin : report_resolved, texte du serveur', 'Contenu supprimé', n.title,
       CASE WHEN n.title = 'Contenu supprimé' THEN 'OK' ELSE 'ÉCHEC' END
  FROM crees c JOIN public.notifications n ON n.id = c.id WHERE c.n = 10;

-- Le push est bien parti en file, et l'annulation le retirera.
INSERT INTO resultat
SELECT 11, 'MESURE — pushs mis en file (annulés par le ROLLBACK)', '-',
       count(*)::text, 'MESURE'
  FROM net.http_request_queue;

-- ═══ Rapport ═══════════════════════════════════════════════════════════════
SELECT n, verdict, cas, attendu, obtenu FROM resultat ORDER BY n;

ROLLBACK;
