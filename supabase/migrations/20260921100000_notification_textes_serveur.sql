-- `create_user_notification` : le serveur rédige le texte, et filtre les données.
--
-- Suite de `20260921032400_notification_type_ferme_et_quota.sql`, qui avait
-- fermé le type, respecté le blocage et posé un quota, en laissant ouvert — et
-- en le disant — le texte libre.
--
-- ═══ CE QUI RESTAIT OUVERT, MESURÉ LE 2026-09-21 ══════════════════════════
--
-- 1. LE TEXTE. `p_title` et `p_body` étaient écrits tels quels dans
--    `notifications`, et `trg_notify_push` en fait une bannière système sous le
--    nom et l'icône de l'app. N'importe quel compte pouvait donc envoyer à
--    n'importe qui (hors blocage, dans le quota) « Votre compte sera suspendu,
--    confirmez vos informations sur … ». Et le NOM de l'émetteur était pris du
--    client : on pouvait signer « Équipe Diaspo Niger ».
--
-- 2. LES DONNÉES, et c'était le plus grave. `p_data` était recopié tel quel.
--    Or `send-push` recopie TOUTES les clés de `data` dans le message FCM
--    APRÈS avoir posé `type`, `title` et `body` (send-push/index.ts, boucle
--    sur `rawData`) : une clé de `p_data` les ÉCRASE. Démontré ce jour, en
--    transaction annulée : `friendRequest` accepté avec
--    `{"type":"incoming_call","callerName":"Service Sécurité",…}`, un push mis
--    en file. Et l'app, recevant `type = incoming_call`, déclenche l'écran
--    d'appel entrant (notification_service.dart:1845 au premier plan, :568 en
--    arrière-plan) avec le `callerName` choisi par l'émetteur. Un faux appel
--    vidéo, depuis n'importe quel compte.
--
-- 3. `report_resolved` — « Un contenu que vous avez publié a été signalé et
--    supprimé » — était émissible par N'IMPORTE QUEL compte. C'est un avis de
--    modération : seul le back-office l'émet (admin_provider.dart:1136).
--
-- 4. LA LISTE DES TYPES ÉTAIT FAUSSE. Elle disait « les douze types que `lib/`
--    émet » ; il y en a quatorze. `_notifyPostAuthor` (feed_provider.dart:899)
--    reçoit son type en PARAMÈTRE — `postLiked`, `postReposted` — et le relevé
--    ne l'a pas vu. Aucun dégât mesuré : 0 « j'aime » sur le post d'autrui en
--    base à ce jour, donc aucune notification refusée. Mais le premier l'aurait
--    été, en silence.
--
-- ═══ CE QUE CETTE MIGRATION POSE ══════════════════════════════════════════
--
-- - LE TEXTE EST RÉDIGÉ ICI, par type — les mêmes phrases que les douze sites
--   d'appel écrivaient en dur. Le nom de l'acteur vient de `users`, jamais du
--   client ; le titre d'un événement, de `events`, et seulement si le
--   destinataire en est l'organisateur. `p_title` et `p_body` restent dans la
--   signature — les builds installés les envoient toujours — mais ne sont plus
--   LUS.
--
-- - LES DONNÉES SONT EN LISTE BLANCHE. Du client, ne passent que des
--   identifiants de cible et deux ou trois scalaires bornés ; aucune clé que
--   `send-push` ou l'app interprètent (`type`, `title`, `body`,
--   `click_action`, `conversationId`…) ne peut plus entrer. Les identités
--   affichées (`senderName`, `callerName`, leurs photos et identifiants) sont
--   posées par le serveur.
--
-- - `report_resolved` exige `is_admin()`.
--
-- - `postLiked` et `postReposted` entrent dans la liste. Les cinq types de
--   commande (`newOrder`, `orderPaid`, `orderShipped`, `orderDelivered`,
--   `orderCancelled`) en SORTENT : la chaîne de paiement est fermée des deux
--   côtés depuis ce matin (20260921034600 et firestore.rules), aucune commande
--   ne peut plus naître, et leur texte cite un produit qui vit dans Firestore,
--   hors d'atteinte d'ici. Ils ne pouvaient plus servir qu'à des
--   notifications falsifiées. Rouvrir la place de marché demandera des
--   notifications émises par le serveur, avec le séquestre.
--
-- - `anon` perd l'exécution (la fonction le refusait déjà, sans identité).
--
-- CE QUI RESTE, et qui n'est pas d'ici : `users.display_name` est choisi par
-- chacun. Un compte qui s'appelle « Service Sécurité » signera ainsi — comme
-- dans toute messagerie. Et `send-push` laisse toujours `data` écraser `type`
-- pour les AUTRES écrivains de `notifications` — des déclencheurs serveur, et
-- la RLS `notifications_own`, qui ne permet d'écrire que pour soi-même.
-- Durcissement à y faire, consigné au suivi.
--
-- Banc : tools/rls_tests/notification_textes_serveur.sql

REVOKE EXECUTE ON FUNCTION public.create_user_notification(text, text, text, text, jsonb)
  FROM anon;

CREATE OR REPLACE FUNCTION public.create_user_notification(
  p_user_id text,
  p_type    text,
  p_title   text,
  p_body    text,
  p_data    jsonb DEFAULT '{}'::jsonb
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  -- Les QUATORZE types que `lib/` émet par cette fonction, relevés le
  -- 2026-09-21 — y compris ceux qu'un site d'appel reçoit en paramètre.
  -- Toute addition ici doit venir d'un appel réel, et porter son texte
  -- ci-dessous.
  c_types_permis constant text[] := ARRAY[
    'friendRequest', 'friendAccepted',
    'eventAttendance',
    'postCommented', 'commentReply', 'postLiked', 'postReposted',
    'groupCallInvitation',
    'report_resolved'
  ];
  -- Les seules clés que le CLIENT peut apporter. Aucune n'est interprétée
  -- par `send-push` ni par l'app comme type, texte ou identité.
  c_cles_client constant text[] := ARRAY[
    'targetId', 'target_id', 'postId', 'eventId',
    'callId', 'callType', 'reportId', 'resolution', 'contentRemoved'
  ];
  c_quota_par_heure        constant int := 60;
  c_quota_par_couple_heure constant int := 10;

  v_actor  text := firebase_uid();
  v_nom    text;
  v_photo  text;
  v_data   jsonb;
  v_cible  text;
  v_titre  text;
  v_corps  text;
  v_evt    text;
  v_video  boolean;
  v_id     uuid;
  v_n      int;
BEGIN
  IF v_actor IS NULL OR v_actor = '' THEN
    RAISE EXCEPTION 'create_user_notification: not authenticated';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM users WHERE id = p_user_id) THEN
    RAISE EXCEPTION 'create_user_notification: recipient % not found', p_user_id;
  END IF;

  IF p_type IS NULL OR NOT (p_type = ANY (c_types_permis)) THEN
    RAISE EXCEPTION 'create_user_notification: type % non autorisé', p_type
      USING ERRCODE = 'check_violation';
  END IF;

  -- Un avis de modération n'émane que du back-office.
  IF p_type = 'report_resolved' AND NOT public.is_admin() THEN
    RAISE EXCEPTION 'create_user_notification: report_resolved réservé aux administrateurs'
      USING ERRCODE = '42501';
  END IF;

  -- Bloqué par le destinataire : on ne crée rien, et on ne le dit pas.
  IF EXISTS (
    SELECT 1 FROM blocked_users
     WHERE blocker_id = p_user_id AND blocked_id = v_actor
  ) THEN
    RETURN NULL;
  END IF;

  SELECT count(*) INTO v_n
    FROM notifications
   WHERE data->>'actor_id' = v_actor
     AND created_at > now() - interval '1 hour';
  IF v_n >= c_quota_par_heure THEN
    RAISE EXCEPTION 'create_user_notification: quota horaire atteint'
      USING ERRCODE = 'check_violation';
  END IF;

  SELECT count(*) INTO v_n
    FROM notifications
   WHERE data->>'actor_id' = v_actor
     AND user_id = p_user_id
     AND created_at > now() - interval '1 hour';
  IF v_n >= c_quota_par_couple_heure THEN
    RAISE EXCEPTION 'create_user_notification: quota horaire atteint pour ce destinataire'
      USING ERRCODE = 'check_violation';
  END IF;

  -- ── Les données : liste blanche, scalaires bornés ────────────────────────
  SELECT coalesce(jsonb_object_agg(e.k, e.v), '{}'::jsonb) INTO v_data
    FROM jsonb_each(CASE WHEN jsonb_typeof(p_data) = 'object' THEN p_data
                         ELSE '{}'::jsonb END) AS e(k, v)
   WHERE e.k = ANY (c_cles_client)
     AND jsonb_typeof(e.v) IN ('string', 'number', 'boolean')
     AND length(e.v #>> '{}') <= 256;

  v_cible := coalesce(v_data->>'targetId', v_data->>'target_id');

  -- ── L'acteur, tel que la base le connaît ─────────────────────────────────
  SELECT left(nullif(btrim(u.display_name), ''), 80), u.avatar_url
    INTO v_nom, v_photo
    FROM users u WHERE u.id = v_actor;
  v_nom := coalesce(v_nom, 'Quelqu''un');

  -- ── Le texte, par type ───────────────────────────────────────────────────
  CASE p_type
    WHEN 'friendRequest' THEN
      v_titre := 'Nouvelle demande d''ami';
      v_corps := v_nom || ' souhaite vous ajouter en ami';
      -- La fiche à ouvrir est celle de l'acteur, pas une cible au choix.
      v_cible := v_actor;
      v_data := v_data || jsonb_build_object(
        'senderId', v_actor, 'senderName', v_nom, 'senderPhotoUrl', v_photo);

    WHEN 'friendAccepted' THEN
      v_titre := 'Demande d''ami acceptée';
      v_corps := v_nom || ' a accepté votre demande d''ami';
      v_cible := v_actor;
      v_data := v_data || jsonb_build_object(
        'receiverId', v_actor, 'receiverName', v_nom, 'receiverPhotoUrl', v_photo);

    WHEN 'eventAttendance' THEN
      -- Le titre n'est cité que si l'événement existe ET appartient au
      -- destinataire : sinon on ne ferait que relayer un texte choisi par
      -- quelqu'un d'autre.
      IF coalesce(v_data->>'eventId', v_cible) ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN
        -- Un titre vide vaut absence : « participera à "" » a été vu au banc,
        -- sur un événement réel.
        SELECT nullif(btrim(ev.title), '') INTO v_evt
          FROM events ev
         WHERE ev.id = coalesce(v_data->>'eventId', v_cible)::uuid
           AND ev.organizer_id = p_user_id;
      END IF;
      v_titre := 'Nouvelle participation';
      v_corps := v_nom || CASE WHEN v_evt IS NOT NULL
                               THEN ' participera à "' || left(v_evt, 120) || '"'
                               ELSE ' participera à votre événement' END;
      v_data := v_data || jsonb_build_object('attendeeId', v_actor, 'attendeeName', v_nom)
                       || CASE WHEN v_evt IS NOT NULL
                               THEN jsonb_build_object('eventTitle', v_evt)
                               ELSE '{}'::jsonb END;

    WHEN 'postCommented' THEN
      v_titre := 'Nouveau commentaire';
      v_corps := v_nom || ' a commenté votre publication';
      v_data := v_data || jsonb_build_object('senderId', v_actor);

    WHEN 'commentReply' THEN
      v_titre := 'Nouvelle réponse';
      v_corps := v_nom || ' a répondu à votre commentaire';
      v_data := v_data || jsonb_build_object('senderId', v_actor);

    WHEN 'postLiked' THEN
      v_titre := 'Nouveau j''aime';
      v_corps := v_nom || ' a aimé votre publication';
      v_data := v_data || jsonb_build_object('senderId', v_actor);

    WHEN 'postReposted' THEN
      v_titre := 'Nouveau repartage';
      v_corps := v_nom || ' a repartagé votre publication';
      v_data := v_data || jsonb_build_object('senderId', v_actor);

    WHEN 'groupCallInvitation' THEN
      v_video := (v_data->>'callType') = 'video';
      -- Ce qui n'est ni « video » ni « audio » repart en « audio ».
      v_data := v_data || jsonb_build_object(
        'callType', CASE WHEN v_video THEN 'video' ELSE 'audio' END,
        'callerId', v_actor, 'callerName', v_nom, 'callerPhotoUrl', coalesce(v_photo, ''));
      v_titre := v_nom;
      v_corps := CASE WHEN v_video
                      THEN 'Vous invite à un appel vidéo de groupe'
                      ELSE 'Vous invite à un appel vocal de groupe' END;

    WHEN 'report_resolved' THEN
      IF (v_data->>'contentRemoved') = 'true' THEN
        v_titre := 'Contenu supprimé';
        v_corps := 'Un contenu que vous avez publié a été signalé et supprimé pour violation de nos règles communautaires.';
      ELSE
        v_titre := 'Signalement traité';
        v_corps := 'Un signalement concernant votre contenu a été examiné. Aucune action n''a été prise.';
      END IF;
  END CASE;

  IF v_cible IS NOT NULL THEN
    v_data := v_data || jsonb_build_object('targetId', v_cible, 'target_id', v_cible);
  END IF;

  INSERT INTO notifications (user_id, type, title, body, data, is_read)
  VALUES (
    p_user_id,
    p_type,
    v_titre,
    v_corps,
    v_data || jsonb_build_object('actor_id', v_actor),
    FALSE
  )
  RETURNING id INTO v_id;

  RETURN v_id;
END;
$function$;
