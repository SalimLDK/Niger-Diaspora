-- `create_user_notification` : type en liste fermée, blocage respecté, quota.
--
-- CE QUI ÉTAIT OUVERT. La fonction n'exigeait que deux choses : être connecté,
-- et que le destinataire existe. `p_type`, `p_title`, `p_body` et `p_data`
-- étaient libres, et le destinataire pouvait être n'importe qui. Or
-- `notifications` porte `trg_notify_push`, qui envoie un vrai push à
-- l'insertion : n'importe quel compte pouvait donc faire arriver sur le
-- téléphone de n'importe qui une bannière de son cru, sous le type de son
-- choix — `system` compris, celui que l'app traite comme une annonce de la
-- plateforme et qui décide du canal de notification.
--
-- CE QUE CETTE MIGRATION POSE, ET CE QU'ELLE NE POSE PAS.
--
-- 1. **Type en liste fermée.** Les douze types que le client émet vraiment,
--    relevés dans `lib/` : `createNotification()` et les trois appels directs
--    à la RPC. Tout autre type est refusé — `system`, `message`,
--    `messageMention`, `messageReaction` et les types de groupe compris : ils
--    viennent de DÉCLENCHEURS serveur qui insèrent directement dans
--    `notifications`, sans passer par ici, et ne sont donc pas concernés.
--    Vérifié en base le 2026-09-21 : les types présents hors de cette liste
--    (`cityGroupInvite`, `groupInvite`, `groupJoinRequest`,
--    `groupRequestApproved`, `eventReminder`, `like`) n'ont AUCUN `actor_id`,
--    signature d'une écriture serveur ; `system` en a 36, d'un seul émetteur,
--    le 2026-09-15, et le client n'émet jamais ce type par cette RPC (ses
--    occurrences de `'system'` dans `lib/` désignent un type de MESSAGE de
--    discussion, pas de notification).
--
-- 2. **Le blocage est respecté**, en silence : si le destinataire a bloqué
--    l'appelant, la fonction ne crée rien et rend `NULL`. Silencieusement,
--    parce qu'une erreur apprendrait à l'appelant qu'il est bloqué. L'appelant
--    ignore déjà la valeur rendue.
--
-- 3. **Quota par heure** : 60 notifications par émetteur, et 10 par couple
--    émetteur/destinataire. Large pour un usage normal — la demande d'ami,
--    le commentaire, la commande sont des gestes rares — et assez serré pour
--    qu'une diffusion de masse se heurte au mur.
--
-- ⚠️ CE QUI RESTE OUVERT : `p_title` et `p_body` demeurent du texte libre.
-- Un compte peut donc encore écrire ce qu'il veut dans une bannière — sous un
-- type légitime, et seulement vers quelqu'un qui ne l'a pas bloqué, dans la
-- limite du quota. La vraie fermeture serait de dériver le texte du type et
-- du nom de l'émetteur, côté serveur ; les textes sont aujourd'hui des
-- chaînes françaises en dur dans `lib/` (ex.
-- `friend_repository_impl.dart:37`), donc ce déplacement est faisable, mais
-- c'est un autre chantier — il touche douze sites d'appel.
--
-- L'index sert le quota : sans lui, chaque appel balaie la table, qui grossit.
--
-- Banc : tools/rls_tests/notification_type_et_quota.sql

CREATE INDEX IF NOT EXISTS notifications_acteur_idx
  ON public.notifications ((data->>'actor_id'), created_at DESC);

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
  -- Les douze types que `lib/` émet. Toute addition ici doit venir d'un
  -- appel réel, pas d'une intention.
  c_types_permis constant text[] := ARRAY[
    'friendRequest', 'friendAccepted',
    'eventAttendance',
    'postCommented', 'commentReply',
    'newOrder', 'orderPaid', 'orderShipped', 'orderDelivered', 'orderCancelled',
    'report_resolved',
    'groupCallInvitation'
  ];
  c_quota_par_heure        constant int := 60;
  c_quota_par_couple_heure constant int := 10;

  v_actor TEXT := firebase_uid();
  v_id    UUID;
  v_n     int;
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

  INSERT INTO notifications (user_id, type, title, body, data, is_read)
  VALUES (
    p_user_id,
    p_type,
    p_title,
    p_body,
    COALESCE(p_data, '{}'::jsonb) || jsonb_build_object('actor_id', v_actor),
    FALSE
  )
  RETURNING id INTO v_id;

  RETURN v_id;
END;
$function$;
