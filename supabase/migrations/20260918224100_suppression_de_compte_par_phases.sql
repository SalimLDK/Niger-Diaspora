-- Suppression de compte : demande, désactivation, délai de grâce, purge.
--
-- CE QUE FAISAIT « SUPPRIMER MON COMPTE » (mesuré en production le 2026-09-18)
-- `AuthRemoteDataSource.deleteAccount()` écrivait `from('users').delete()` :
-- RLS actif, droit DELETE accordé, AUCUNE policy DELETE — donc 0 ligne, sans
-- erreur, et aucune cascade. Il vidait ensuite `groups.member_ids` (vide
-- partout ; l'appartenance vit dans `group_members`) et supprimait les
-- conversations à ≤ 2 participants… seulement celles dont la personne était
-- `created_by`. Seul le compte Firebase disparaissait. Le dialogue promettait
-- « toutes vos données supprimées définitivement ».
--
-- CE QUE LE CATALOGUE MONTRAIT DE PLUS
--   · une vingtaine de tables portent un identifiant d'utilisateur SANS clé
--     étrangère (messages, mls_messages, group_members, friends, notifications,
--     e2ee_*, mls_devices…) : même un DELETE sur `users` qui marcherait les
--     laisserait ;
--   · `auth.users` garde l'adresse e-mail (107 lignes) et `auth_mappings` le
--     lien ; l'échange Firebase→Supabase retrouve l'utilisateur PAR E-MAIL, si
--     bien qu'une réinscription se rattachait à l'ancienne ligne ;
--   · `mls_messages.sender_device_id` et `mls_commits.sender_device_id` sont
--     NO ACTION : un appareil cité ne se supprime pas ;
--   · `businesses.owner_id` et `business_boosts.user_id` sont NO ACTION ;
--   · le garde `conversations_guard_admin_fields` s'appuie sur
--     `firebase_uid()` pour reconnaître un départ volontaire.
--
-- MODÈLE : ACTIVE → PENDING (30 jours) → DELETING → COMPLETED
--   1. `request_account_deletion()`  — appelée par le client, identité par
--      `firebase_uid()`. Désactive tout de suite (profil masqué, publications
--      masquées, notifications arrêtées, commerces dépubliés, sessions
--      Supabase révoquées) et pose `execute_at = now() + 30 jours`.
--   2. `cancel_account_deletion()`   — tant que rien n'a démarré.
--   3. `claim_due_account_deletions()` puis `complete_account_deletion()` —
--      service_role seulement. La Cloud Function planifiée
--      `finalizeAccountDeletions` supprime le compte Firebase (ce qui déclenche
--      `cleanupUserData` : Firestore, RTDB, Storage) PUIS appelle `complete`.
--      Firebase d'abord : une fois le compte Firebase supprimé, plus rien ne
--      peut ressusciter la ligne `users` par un nouvel échange de jeton.
--   La partie SQL d'une purge est UNE transaction (`private.purge_account`) :
--   un compte n'est jamais à moitié effacé. Elle est idempotente ; un échec
--   est consigné dans `last_error` et retenté au passage suivant.
--
-- DÉCISIONS DE SALIM (2026-09-18)
--   · conversations à deux : supprimées entièrement (chez l'autre aussi) ;
--     groupes : messages en clair ANONYMISÉS (« Compte supprimé »), messages
--     MLS « supprimés pour tous » (le serveur ne peut pas réécrire un
--     ciphertext) ;
--   · événements créés : supprimés ; commerces possédés : supprimés ;
--   · groupes : on les quitte tous ; un groupe qui garde des membres passe au
--     plus ancien admin (à défaut au plus ancien membre) ; dernier membre =
--     groupe dissous, comme `delete_group`.
--
-- CE QUE LA PURGE NE PEUT PAS FAIRE, ET LE DIT
--   · MLS : le serveur ne détient aucune clé, il ne peut pas émettre le commit
--     « Remove ». L'appareil supprimé reste une feuille dans l'arbre des
--     groupes jusqu'à ce qu'un membre commite. Sa ligne `mls_devices` est
--     conservée en pierre tombale révoquée (NO ACTION oblige), sans nom ni
--     identité ; la credential MLS, elle, contient l'uid — c'est le protocole.
--   · Fichiers : Firebase Storage, pas Supabase — `cleanupUserData`.
--   · Sauvegardes Supabase : les lignes purgées y survivent jusqu'à leur
--     expiration. `account_deletion_requests` (sans contenu) sert de pierre
--     tombale : après TOUTE restauration, rejouer `private.purge_account(uid)`
--     pour chaque ligne `completed`.
--   · HISTORIQUE FINANCIER : `orders`, `escrow_transactions`, `transactions`,
--     `tips`, `room_tickets`, `card_credit_requests`, `debit_requests` sont
--     vides aujourd'hui et la fonctionnalité est éteinte. Plutôt que d'effacer
--     ou de garder en silence, la demande est REFUSÉE (et la purge s'arrête en
--     `blocked`) tant qu'une ligne existe. Quand ces tables se rempliront :
--     décider la durée de conservation légale et anonymiser au lieu de refuser.
--
-- COLONNES D'UTILISATEUR VOLONTAIREMENT NON TRAITÉES (tables vides le
-- 2026-09-18 ; la liste ne doit que rétrécir — voir
-- test/features/profile/suppression_compte_purge_test.dart) :
--   admin_audit_logs.target_id, content_reports.target_id, reminders.target_id,
--   reports.reporter_id/reported_user_id/target_id, sticker_packs.creator_id,
--   heritage_collections.creatorId, podcasts.host_id,
--   embassy_employees.linked_user_id, business_reviews.helpful_by_user_ids,
--   audio_rooms.* (tableaux d'uid).
-- Et un effet de cascade à connaître : `content_reports.reporter_id`,
-- `post_polls.created_by` et `group_pinned_items.pinned_by` sont des clés
-- étrangères ON DELETE CASCADE vers `users` — les signalements émis et les
-- sondages créés partent avec le compte (les épingles sont d'abord
-- réattribuées au nouveau propriétaire du groupe).
--
-- POUR RELANCER UN COMPTE `blocked` une fois l'obstacle levé :
--   UPDATE public.account_deletion_requests
--      SET status = 'pending', last_error = NULL WHERE user_id = '<uid>';

-- ── 1. La demande ───────────────────────────────────────────────────────────
--
-- Pas de clé étrangère vers `users` : la ligne `users` disparaît à la purge, la
-- demande reste (pierre tombale, sans contenu : un uid, des dates, des
-- compteurs).

CREATE TABLE IF NOT EXISTS public.account_deletion_requests (
  user_id       text PRIMARY KEY,
  status        text NOT NULL DEFAULT 'pending'
                CHECK (status IN ('pending', 'cancelled', 'deleting', 'blocked', 'completed')),
  requested_at  timestamptz NOT NULL DEFAULT now(),
  execute_at    timestamptz NOT NULL,
  cancelled_at  timestamptz,
  started_at    timestamptz,
  completed_at  timestamptz,
  attempts      integer NOT NULL DEFAULT 0,
  last_error    text,
  -- Ce qu'il faut remettre à l'annulation (drapeaux de visibilité, commerces
  -- qui étaient actifs). Jamais de contenu.
  restore       jsonb NOT NULL DEFAULT '{}'::jsonb,
  -- Compteurs de la purge, par famille. Jamais de contenu.
  summary       jsonb
);

CREATE INDEX IF NOT EXISTS account_deletion_requests_a_traiter_idx
  ON public.account_deletion_requests (execute_at)
  WHERE status IN ('pending', 'deleting');

ALTER TABLE public.account_deletion_requests ENABLE ROW LEVEL SECURITY;

-- Un GRANT n'enlève rien sous Supabase : révoquer d'abord, pour les deux rôles.
REVOKE ALL ON TABLE public.account_deletion_requests FROM PUBLIC, anon, authenticated;
-- Colonnes seulement : `last_error`, `restore` et `summary` restent internes.
-- Conséquence côté client : `.select('status,execute_at,…')`, jamais `*`
-- (un `select *` échouerait en 42501 sur les colonnes non accordées).
GRANT SELECT (user_id, status, requested_at, execute_at, cancelled_at)
  ON public.account_deletion_requests TO authenticated;

DROP POLICY IF EXISTS account_deletion_requests_own_select ON public.account_deletion_requests;
CREATE POLICY account_deletion_requests_own_select ON public.account_deletion_requests
  AS PERMISSIVE FOR SELECT TO authenticated
  USING (user_id = (SELECT public.firebase_uid()));

COMMENT ON TABLE public.account_deletion_requests IS
  'Demandes de suppression de compte (pending → deleting → completed, ou cancelled/blocked). Écrite par les seules RPC ; la ligne completed reste comme pierre tombale sans contenu.';

-- ── 2. Deux briques d'écriture pour la purge ────────────────────────────────

-- Retire un uid d'un tableau JSON (readBy, adminIds…). Un non-tableau revient
-- tel quel : on ne casse jamais une forme qu'on ne connaît pas.
CREATE OR REPLACE FUNCTION private.json_sans_uid(p_arr jsonb, p_uid text)
RETURNS jsonb
LANGUAGE sql
IMMUTABLE
SET search_path = pg_catalog
AS $function$
  SELECT CASE
    WHEN jsonb_typeof(p_arr) = 'array' THEN COALESCE(
      (SELECT jsonb_agg(v) FROM jsonb_array_elements(p_arr) AS v WHERE v <> to_jsonb(p_uid)),
      '[]'::jsonb)
    ELSE p_arr
  END
$function$;

-- DELETE générique d'une table sur une ou plusieurs colonnes d'identifiant.
-- `regclass` valide l'existence de la table à l'appel (une faute de frappe
-- lève au lieu de passer) ; les colonnes sont citées par %I ; la comparaison
-- se fait en texte pour couvrir aussi bien les colonnes text que uuid.
CREATE OR REPLACE FUNCTION private.purge_delete(p_table regclass, p_uid text, VARIADIC p_cols text[])
RETURNS integer
LANGUAGE plpgsql
SET search_path = public, pg_temp
AS $function$
DECLARE
  v_n integer;
BEGIN
  EXECUTE format(
    'DELETE FROM %s WHERE %s',
    p_table,
    (SELECT string_agg(format('%I::text = $1', c), ' OR ') FROM unnest(p_cols) AS c)
  ) USING p_uid;
  GET DIAGNOSTICS v_n = ROW_COUNT;
  RETURN v_n;
END;
$function$;

REVOKE ALL ON FUNCTION private.json_sans_uid(jsonb, text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION private.purge_delete(regclass, text, text[]) FROM PUBLIC, anon, authenticated;

-- ── 3. Ce qui interdit une suppression ──────────────────────────────────────
--
-- NULL = rien ne s'y oppose. Relue à l'échéance : la situation change en 30
-- jours.

CREATE OR REPLACE FUNCTION private.suppression_bloquee_pour(p_uid text)
RETURNS text
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $function$
BEGIN
  -- Le compte plateforme porte les groupes officiels : le supprimer les
  -- orphelinerait tous (un seul compte en a créé 12 sur 15).
  IF EXISTS (SELECT 1 FROM public.groups g WHERE g.creator_id = p_uid AND g.is_official) THEN
    RETURN 'compte_plateforme';
  END IF;

  -- Historique financier : voir l'en-tête. Refuser plutôt que décider seul.
  IF EXISTS (SELECT 1 FROM public.orders WHERE buyer_id = p_uid OR seller_id = p_uid)
     OR EXISTS (SELECT 1 FROM public.escrow_transactions WHERE buyer_id = p_uid OR seller_id = p_uid)
     OR EXISTS (SELECT 1 FROM public.transactions WHERE sender_id = p_uid OR recipient_id = p_uid)
     OR EXISTS (SELECT 1 FROM public.tips WHERE sender_id = p_uid OR recipient_id = p_uid)
     OR EXISTS (SELECT 1 FROM public.room_tickets WHERE user_id = p_uid)
     OR EXISTS (SELECT 1 FROM public.card_credit_requests WHERE user_id = p_uid)
     OR EXISTS (SELECT 1 FROM public.debit_requests WHERE user_id = p_uid)
  THEN
    RETURN 'obligations_financieres';
  END IF;

  RETURN NULL;
END;
$function$;

REVOKE ALL ON FUNCTION private.suppression_bloquee_pour(text) FROM PUBLIC, anon, authenticated;

-- ── 4. Demander, annuler ────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.request_account_deletion()
RETURNS timestamptz
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $function$
DECLARE
  v_uid     text := public.firebase_uid();
  -- Le SEUL endroit où vit la durée. Le client affiche `execute_at`, il ne la
  -- recalcule pas.
  v_grace   constant interval := interval '30 days';
  v_status  text;
  v_execute timestamptz;
  v_blocage text;
  v_restore jsonb;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Utilisateur non authentifié' USING ERRCODE = '42501';
  END IF;

  SELECT r.status, r.execute_at INTO v_status, v_execute
    FROM public.account_deletion_requests r
   WHERE r.user_id = v_uid
     FOR UPDATE;

  -- Idempotente : une demande en cours rend sa date, sans la repousser.
  IF v_status = 'pending' THEN
    RETURN v_execute;
  END IF;
  IF v_status IN ('deleting', 'blocked', 'completed') THEN
    RAISE EXCEPTION 'suppression_deja_engagee' USING ERRCODE = 'P0001';
  END IF;

  v_blocage := private.suppression_bloquee_pour(v_uid);
  IF v_blocage IS NOT NULL THEN
    RAISE EXCEPTION '%', v_blocage USING ERRCODE = 'P0001';
  END IF;

  SELECT jsonb_build_object(
           'is_private', u.is_private,
           'is_visible', u.is_visible,
           'show_online_status', u.show_online_status)
    INTO v_restore
    FROM public.users u
   WHERE u.id = v_uid;

  v_restore := COALESCE(v_restore, '{}'::jsonb) || jsonb_build_object(
    'businesses_actives',
    COALESCE((SELECT jsonb_agg(b.id) FROM public.businesses b
               WHERE b.owner_id = v_uid AND b.is_active), '[]'::jsonb));

  v_execute := now() + v_grace;

  INSERT INTO public.account_deletion_requests AS r (user_id, status, execute_at, restore)
  VALUES (v_uid, 'pending', v_execute, v_restore)
  ON CONFLICT (user_id) DO UPDATE
     SET status = 'pending', requested_at = now(), execute_at = EXCLUDED.execute_at,
         cancelled_at = NULL, started_at = NULL, attempts = 0, last_error = NULL,
         restore = EXCLUDED.restore;

  -- Désactivation immédiate. Les publications et les stories se masquent par
  -- `private.peut_voir_*_pour` (section 6), qui lisent la demande.
  UPDATE public.users
     SET is_private = true, is_visible = false, is_online = false,
         fcm_tokens = '[]'::jsonb
   WHERE id = v_uid;

  UPDATE public.businesses SET is_active = false
   WHERE owner_id = v_uid AND is_active;

  -- Révoque les sessions Supabase de tous les appareils : au prochain jeton,
  -- ils repassent par l'échange Firebase et tombent sur l'écran d'annulation.
  DELETE FROM auth.sessions
   WHERE user_id IN (SELECT am.supabase_id FROM public.auth_mappings am WHERE am.firebase_uid = v_uid);

  RETURN v_execute;
END;
$function$;

CREATE OR REPLACE FUNCTION public.cancel_account_deletion()
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $function$
DECLARE
  v_uid     text := public.firebase_uid();
  v_status  text;
  v_restore jsonb;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Utilisateur non authentifié' USING ERRCODE = '42501';
  END IF;

  SELECT r.status, r.restore INTO v_status, v_restore
    FROM public.account_deletion_requests r
   WHERE r.user_id = v_uid
     FOR UPDATE;

  -- `blocked` s'annule aussi : la personne n'a pas à porter un obstacle
  -- qu'elle ne voit pas. `deleting` non : la purge est engagée.
  IF v_status IS NULL OR v_status NOT IN ('pending', 'blocked') THEN
    RAISE EXCEPTION 'aucune_suppression_a_annuler' USING ERRCODE = 'P0001';
  END IF;

  UPDATE public.users u
     SET is_private = COALESCE((v_restore->>'is_private')::boolean, u.is_private),
         is_visible = COALESCE((v_restore->>'is_visible')::boolean, u.is_visible),
         show_online_status = COALESCE((v_restore->>'show_online_status')::boolean, u.show_online_status)
   WHERE u.id = v_uid;

  UPDATE public.businesses b SET is_active = true
   WHERE b.owner_id = v_uid
     AND b.id::text IN (SELECT jsonb_array_elements_text(COALESCE(v_restore->'businesses_actives', '[]'::jsonb)));

  UPDATE public.account_deletion_requests
     SET status = 'cancelled', cancelled_at = now(), last_error = NULL
   WHERE user_id = v_uid;

  RETURN true;
END;
$function$;

-- ── 5. La purge ─────────────────────────────────────────────────────────────
--
-- Appelée par `complete_account_deletion` seulement. Une transaction, des
-- instructions idempotentes : rejouée sur un compte déjà purgé, elle ne fait
-- rien et ne lève rien.

CREATE OR REPLACE FUNCTION private.purge_account(p_uid text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $function$
DECLARE
  v_gone    constant text := 'compte_supprime';
  v_nom     constant text := 'Compte supprimé';
  v_prev    text := current_setting('request.jwt.claims', true);
  v_c       jsonb := '{}'::jsonb;
  v_n       integer;
  v_g       record;
  v_restants integer;
  v_succ    text;
  v_devices uuid[];
BEGIN
  IF p_uid IS NULL OR p_uid = '' THEN
    RAISE EXCEPTION 'purge_account : uid manquant' USING ERRCODE = '22023';
  END IF;

  -- Se met « dans la peau » du compte pour la durée de la transaction :
  -- `conversations_guard_admin_fields` reconnaît un départ volontaire par
  -- `firebase_uid()`. Sans cela, l'appelant est service_role (uid NULL) et le
  -- garde ne passe que par un hasard de logique à trois valeurs.
  PERFORM set_config(
    'request.jwt.claims',
    jsonb_build_object('role', 'authenticated',
                       'app_metadata', jsonb_build_object('firebase_uid', p_uid))::text,
    true);

  -- ── Conversations à deux : supprimées entièrement (cascade : messages,
  --    mls_messages, mls_commits, mls_welcomes, conversation_devices, sondages,
  --    événements rattachés). Les notes personnelles (1 participant) en sont.
  WITH d AS (
    DELETE FROM public.conversations c
     WHERE c.type = 'individual' AND c.participant_ids @> ARRAY[p_uid]
     RETURNING 1)
  SELECT count(*) INTO v_n FROM d;
  v_c := v_c || jsonb_build_object('conversations_individuelles', v_n);

  -- ── Groupes : quitter, transmettre, ou dissoudre le dernier.
  v_n := 0;
  FOR v_g IN
    SELECT g.id, g.is_official, (g.creator_id = p_uid) AS est_createur
      FROM public.groups g
     WHERE g.creator_id = p_uid
        OR EXISTS (SELECT 1 FROM public.group_members gm
                    WHERE gm.group_id = g.id AND gm.user_id = p_uid)
  LOOP
    SELECT count(*) INTO v_restants
      FROM public.group_members gm
     WHERE gm.group_id = v_g.id AND gm.user_id <> p_uid;

    IF v_restants = 0 AND NOT v_g.is_official THEN
      -- Comme `delete_group` : la conversation, l'appartenance, le groupe.
      DELETE FROM public.conversations WHERE group_id = v_g.id::text;
      DELETE FROM public.group_members WHERE group_id = v_g.id;
      DELETE FROM public.groups WHERE id = v_g.id;
      v_c := v_c || jsonb_build_object('groupes_dissous',
                                       COALESCE((v_c->>'groupes_dissous')::int, 0) + 1);
    ELSE
      IF v_g.est_createur AND NOT v_g.is_official THEN
        -- Successeur : un autre owner s'il y en a, sinon le plus ancien admin,
        -- sinon le plus ancien membre.
        SELECT gm.user_id INTO v_succ
          FROM public.group_members gm
         WHERE gm.group_id = v_g.id AND gm.user_id <> p_uid
         ORDER BY (gm.role = 'owner') DESC, (gm.role = 'admin') DESC,
                  gm.joined_at ASC, gm.user_id ASC
         LIMIT 1;

        UPDATE public.group_members SET role = 'owner'
         WHERE group_id = v_g.id AND user_id = v_succ AND role <> 'owner';

        UPDATE public.groups
           SET creator_id = v_succ,
               creator_name = COALESCE(
                 (SELECT NULLIF(u.display_name, '') FROM public.users u WHERE u.id = v_succ),
                 v_nom)
         WHERE id = v_g.id;

        -- Il doit aussi pouvoir administrer la conversation. AVANT le départ :
        -- le garde exige encore que l'appelant y soit administrateur.
        UPDATE public.conversations c
           SET data = jsonb_set(COALESCE(c.data, '{}'::jsonb), '{adminIds}',
                                COALESCE(c.data->'adminIds', '[]'::jsonb) || to_jsonb(v_succ))
         WHERE c.group_id = v_g.id::text
           AND NOT (COALESCE(c.data->'adminIds', '[]'::jsonb) ? v_succ);

        -- Les épingles (FK ON DELETE CASCADE vers users) survivent au départ.
        UPDATE public.group_pinned_items SET pinned_by = v_succ
         WHERE group_id = v_g.id AND pinned_by = p_uid;

        v_c := v_c || jsonb_build_object('groupes_transmis',
                                         COALESCE((v_c->>'groupes_transmis')::int, 0) + 1);
      END IF;

      DELETE FROM public.group_members WHERE group_id = v_g.id AND user_id = p_uid;
    END IF;
    v_n := v_n + 1;
  END LOOP;
  v_c := v_c || jsonb_build_object('groupes_quittes', v_n);

  v_c := v_c || jsonb_build_object('invitations_et_demandes',
      private.purge_delete('public.group_invites', p_uid, 'inviter_id', 'invitee_id')
    + private.purge_delete('public.group_requests', p_uid, 'requester_id')
    + private.purge_delete('public.departs_groupe_officiel', p_uid, 'user_id'));
  UPDATE public.group_requests SET processed_by = NULL WHERE processed_by = p_uid;

  -- ── Conversations de groupe restantes : sortir la personne des listes.
  --    `created_by` passe au nouveau propriétaire du groupe, à défaut au
  --    premier participant restant : la policy DELETE en dépend.
  UPDATE public.conversations c
     SET participant_ids = array_remove(c.participant_ids, p_uid),
         created_by = CASE
           WHEN c.created_by = p_uid THEN COALESCE(
             (SELECT g.creator_id FROM public.groups g WHERE g.id::text = c.group_id),
             (array_remove(c.participant_ids, p_uid))[1],
             v_gone)
           ELSE c.created_by END,
         last_message_sender_id = CASE
           WHEN c.last_message_sender_id = p_uid THEN v_gone ELSE c.last_message_sender_id END,
         data = CASE WHEN c.data IS NULL THEN NULL ELSE
           (c.data
             #- ARRAY['unreadCount', p_uid]
             #- ARRAY['unreadMentions', p_uid]
             #- ARRAY['mutedBy', p_uid])
           || CASE WHEN c.data ? 'adminIds'
                   THEN jsonb_build_object('adminIds', private.json_sans_uid(c.data->'adminIds', p_uid))
                   ELSE '{}'::jsonb END
           || CASE WHEN c.data ? 'lastMessageReadBy'
                   THEN jsonb_build_object('lastMessageReadBy', private.json_sans_uid(c.data->'lastMessageReadBy', p_uid))
                   ELSE '{}'::jsonb END
           || CASE WHEN c.data ? 'lastMessageDeliveredTo'
                   THEN jsonb_build_object('lastMessageDeliveredTo', private.json_sans_uid(c.data->'lastMessageDeliveredTo', p_uid))
                   ELSE '{}'::jsonb END
           || CASE WHEN c.data->>'lastMessageSenderId' = p_uid
                   THEN jsonb_build_object('lastMessageSenderId', v_gone)
                   ELSE '{}'::jsonb END
         END
   WHERE c.participant_ids @> ARRAY[p_uid]
      OR c.created_by = p_uid
      OR c.last_message_sender_id = p_uid;
  GET DIAGNOSTICS v_n = ROW_COUNT;
  v_c := v_c || jsonb_build_object('conversations_de_groupe_nettoyees', v_n);

  -- ── Messages en clair. Les siens dans les groupes : anonymisés (le texte
  --    reste, le nom, la photo, l'historique d'édition et l'uid partent).
  --    `editedAt` n'est PAS touché : `notifier_edition_message` s'en sert
  --    pour décider d'une notification.
  UPDATE public.messages m
     SET data = jsonb_set(
           (COALESCE(m.data, '{}'::jsonb) - 'senderPhotoUrl' - 'editHistory'),
           '{senderName}', to_jsonb(v_nom))
           || CASE WHEN m.data->>'callerId' = p_uid THEN jsonb_build_object('callerId', v_gone) ELSE '{}'::jsonb END
           || CASE WHEN m.data->>'calleeId' = p_uid THEN jsonb_build_object('calleeId', v_gone) ELSE '{}'::jsonb END,
         sender_id = v_gone
   WHERE m.sender_id = p_uid;
  GET DIAGNOSTICS v_n = ROW_COUNT;
  v_c := v_c || jsonb_build_object('messages_anonymises', v_n);

  -- Les citations de ses messages, dans les messages des autres.
  UPDATE public.messages m
     SET data = jsonb_set(
           jsonb_set(m.data, '{replyToMessageData,senderId}', to_jsonb(v_gone)),
           '{replyToMessageData,senderName}', to_jsonb(v_nom))
   WHERE m.data->'replyToMessageData'->>'senderId' = p_uid;

  -- Ses traces sur les messages des autres : lu par, remis à, réactions…
  UPDATE public.messages m
     SET data = (m.data
                  #- ARRAY['reactions', p_uid]
                  #- ARRAY['readAt', p_uid]
                  #- ARRAY['deliveredAt', p_uid])
           || CASE WHEN m.data->'readBy' ? p_uid
                   THEN jsonb_build_object('readBy', private.json_sans_uid(m.data->'readBy', p_uid)) ELSE '{}'::jsonb END
           || CASE WHEN m.data->'deliveredTo' ? p_uid
                   THEN jsonb_build_object('deliveredTo', private.json_sans_uid(m.data->'deliveredTo', p_uid)) ELSE '{}'::jsonb END
           || CASE WHEN m.data->'deletedFor' ? p_uid
                   THEN jsonb_build_object('deletedFor', private.json_sans_uid(m.data->'deletedFor', p_uid)) ELSE '{}'::jsonb END
           || CASE WHEN m.data->'starredBy' ? p_uid
                   THEN jsonb_build_object('starredBy', private.json_sans_uid(m.data->'starredBy', p_uid)) ELSE '{}'::jsonb END
           || CASE WHEN m.data->'reportedBy' ? p_uid
                   THEN jsonb_build_object('reportedBy', private.json_sans_uid(m.data->'reportedBy', p_uid)) ELSE '{}'::jsonb END
   WHERE (m.data->'readBy' ? p_uid) OR (m.data->'deliveredTo' ? p_uid)
      OR (m.data->'deletedFor' ? p_uid) OR (m.data->'starredBy' ? p_uid)
      OR (m.data->'reportedBy' ? p_uid) OR (m.data->'reactions' ? p_uid)
      OR (m.data->'readAt' ? p_uid) OR (m.data->'deliveredAt' ? p_uid);

  -- ── MLS. Ses messages de groupe : « supprimer pour tous » (comme
  --    `mls_supprimer_pour_tous`) — on vide le ciphertext, la ligne reste pour
  --    ne pas orpheliner les réponses (`reply_to_id` est NO ACTION).
  UPDATE public.mls_messages
     SET is_deleted = true, deleted_at = COALESCE(deleted_at, now()),
         ciphertext = '\x'::bytea, sender_id = v_gone
   WHERE sender_id = p_uid;
  GET DIAGNOSTICS v_n = ROW_COUNT;
  v_c := v_c || jsonb_build_object('messages_mls_vides', v_n);

  v_c := v_c || jsonb_build_object('traces_mls',
      private.purge_delete('public.mls_message_receipts', p_uid, 'user_id')
    + private.purge_delete('public.mls_message_reactions', p_uid, 'user_id')
    + private.purge_delete('public.mls_message_stars', p_uid, 'user_id')
    + private.purge_delete('public.mls_message_hidden', p_uid, 'user_id')
    + private.purge_delete('public.mls_message_mentions', p_uid, 'user_id')
    + private.purge_delete('public.mls_diagnostics', p_uid, 'user_id'));

  -- Appareils : ce que personne ne cite se supprime (cascade : paquets de
  -- clés, welcomes, conversation_devices). Un appareil cité par un commit ou
  -- un message (NO ACTION) reste en pierre tombale révoquée, sans identité.
  SELECT COALESCE(array_agg(d.id), ARRAY[]::uuid[]) INTO v_devices
    FROM public.mls_devices d WHERE d.user_id = p_uid;

  DELETE FROM public.mls_key_packages WHERE device_id = ANY (v_devices);
  DELETE FROM public.mls_welcomes WHERE recipient_device_id = ANY (v_devices);
  DELETE FROM public.conversation_devices WHERE device_id = ANY (v_devices);

  DELETE FROM public.mls_devices d
   WHERE d.id = ANY (v_devices)
     AND NOT EXISTS (SELECT 1 FROM public.mls_commits c WHERE c.sender_device_id = d.id)
     AND NOT EXISTS (SELECT 1 FROM public.mls_messages m WHERE m.sender_device_id = d.id);

  UPDATE public.mls_devices
     SET revoked_at = COALESCE(revoked_at, now()),
         user_id = v_gone || ':' || id::text,
         mls_identity = v_gone || ':' || id::text,
         stable_id = id::text,
         name = 'Appareil supprimé'
   WHERE id = ANY (v_devices);
  v_c := v_c || jsonb_build_object('appareils_mls', COALESCE(array_length(v_devices, 1), 0));

  -- ── Événements créés : supprimés (cascade : participants, audience).
  v_c := v_c || jsonb_build_object('evenements',
      private.purge_delete('public.events', p_uid, 'organizer_id'));
  v_c := v_c || jsonb_build_object('participations',
      private.purge_delete('public.event_attendees', p_uid, 'user_id'));

  -- ── Commerces possédés : supprimés, boosts d'abord (NO ACTION).
  DELETE FROM public.business_boosts
   WHERE user_id = p_uid
      OR business_id IN (SELECT b.id FROM public.businesses b WHERE b.owner_id = p_uid);
  DELETE FROM public.business_posts
   WHERE business_id IN (SELECT b.id FROM public.businesses b WHERE b.owner_id = p_uid);
  DELETE FROM public.business_reviews
   WHERE user_id = p_uid
      OR business_id IN (SELECT b.id FROM public.businesses b WHERE b.owner_id = p_uid);
  DELETE FROM public.products
   WHERE seller_id = p_uid
      OR business_id IN (SELECT b.id FROM public.businesses b WHERE b.owner_id = p_uid);
  v_c := v_c || jsonb_build_object('commerces',
      private.purge_delete('public.businesses', p_uid, 'owner_id'));

  -- ── Graphe social et contenus publiés sur les publications des autres.
  v_c := v_c || jsonb_build_object('graphe_social',
      private.purge_delete('public.friends', p_uid, 'user_id', 'friend_id')
    + private.purge_delete('public.friend_requests', p_uid, 'sender_id', 'receiver_id')
    + private.purge_delete('public.user_follows', p_uid, 'follower_id', 'following_id'));
  v_c := v_c || jsonb_build_object('commentaires_et_likes',
      private.purge_delete('public.post_comments', p_uid, 'author_id')
    + private.purge_delete('public.post_likes', p_uid, 'user_id'));

  -- ── Notifications reçues, et celles que la personne a déclenchées chez les
  --    autres (le nom et la photo y sont recopiés dans `data`).
  WITH d AS (
    DELETE FROM public.notifications n
     WHERE n.user_id = p_uid
        OR n.data->>'actor_id' = p_uid
        OR n.data->>'senderId' = p_uid
        OR n.data->>'sender_id' = p_uid
        OR n.data->>'attendeeId' = p_uid
        OR n.data->>'receiverId' = p_uid
     RETURNING 1)
  SELECT count(*) INTO v_n FROM d;
  v_c := v_c || jsonb_build_object('notifications', v_n);

  -- ── Clés, appareils Signal/E2EE, données strictement personnelles.
  v_c := v_c || jsonb_build_object('cles_e2ee',
      private.purge_delete('public.e2ee_devices', p_uid, 'user_id')
    + private.purge_delete('public.e2ee_key_transfers', p_uid, 'user_id')
    + private.purge_delete('public.e2ee_one_time_prekeys', p_uid, 'user_id')
    + private.purge_delete('public.e2ee_user_keys', p_uid, 'user_id')
    + private.purge_delete('public.e2ee_sender_key_distributions', p_uid, 'sender_id', 'recipient_id'));

  v_c := v_c || jsonb_build_object('donnees_personnelles',
      private.purge_delete('public.recipients', p_uid, 'user_id')
    + private.purge_delete('public.payment_accounts', p_uid, 'user_id')
    + private.purge_delete('public.notification_preferences', p_uid, 'user_id')
    + private.purge_delete('public.recent_searches', p_uid, 'user_id')
    + private.purge_delete('public.reminders', p_uid, 'user_id')
    + private.purge_delete('public.support_tickets', p_uid, 'user_id')
    + private.purge_delete('public.administrative_requests', p_uid, 'user_id')
    + private.purge_delete('public.creator_profiles', p_uid, 'user_id')
    + private.purge_delete('public.legal_acceptances', p_uid, 'user_id')
    + private.purge_delete('public.podcast_subscriptions', p_uid, 'user_id')
    + private.purge_delete('public.podcast_user_data', p_uid, 'user_id')
    + private.purge_delete('public.user_favorite_stickers', p_uid, 'user_id')
    + private.purge_delete('public.user_recent_stickers', p_uid, 'user_id')
    + private.purge_delete('public.user_sticker_packs', p_uid, 'user_id')
    + private.purge_delete('public.embassy_messages', p_uid, 'user_id')
    + private.purge_delete('public.activity_logs', p_uid, 'user_id'));

  -- ── Identité Supabase : l'e-mail vit dans auth.users. Supprimer la ligne
  --    (identities, sessions, jetons en cascade) sinon une réinscription avec
  --    la même adresse se rattacherait à l'ancienne.
  DELETE FROM auth.users
   WHERE id IN (SELECT am.supabase_id FROM public.auth_mappings am WHERE am.firebase_uid = p_uid);
  GET DIAGNOSTICS v_n = ROW_COUNT;
  v_c := v_c || jsonb_build_object('auth_users', v_n,
    'auth_mappings', private.purge_delete('public.auth_mappings', p_uid, 'firebase_uid'));

  -- ── Le profil, en dernier : la cascade emporte publications, stories,
  --    réactions, favoris, blocages, sourdines, préférences, salons animés…
  v_c := v_c || jsonb_build_object('profil', private.purge_delete('public.users', p_uid, 'id'));

  PERFORM set_config('request.jwt.claims', COALESCE(v_prev, ''), true);
  RETURN v_c;
END;
$function$;

REVOKE ALL ON FUNCTION private.purge_account(text) FROM PUBLIC, anon, authenticated;

-- ── 6. Publications et stories masquées pendant le délai ────────────────────
--
-- Les publications publiques se voient par `private.peut_voir_publication_pour`
-- et les stories par `private.peut_voir_story_pour`. On ajoute, EN TÊTE, la
-- clause « auteur en cours de suppression, hors l'auteur lui-même ». Corps
-- repris de la production (2026-09-18), rien d'autre ne change. Un test
-- (suppression_compte_purge_test.dart) vérifie que la DERNIÈRE définition de
-- chacune garde cette clause : un futur CREATE OR REPLACE qui la perdrait
-- rendrait les publications d'un compte désactivé de nouveau visibles.

CREATE OR REPLACE FUNCTION private.peut_voir_publication_pour(p_author text, p_visibility text, p_viewer text)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
  SELECT CASE
    WHEN p_viewer IS DISTINCT FROM p_author AND EXISTS (
      SELECT 1 FROM public.account_deletion_requests r
       WHERE r.user_id = p_author AND r.status IN ('pending', 'deleting', 'blocked')
    ) THEN FALSE
    WHEN COALESCE(p_visibility, 'public') = 'public' THEN TRUE
    WHEN p_viewer IS NULL OR p_viewer = '' THEN FALSE
    WHEN p_viewer = p_author THEN TRUE
    WHEN p_visibility = 'friends' THEN private.est_ami_de(p_author, p_viewer)
    WHEN p_visibility = 'followers' THEN
      private.est_ami_de(p_author, p_viewer)
      OR private.est_abonne_de(p_author, p_viewer)
    ELSE FALSE
  END;
$function$;

CREATE OR REPLACE FUNCTION private.peut_voir_story_pour(p_author text, p_audience text, p_viewer text)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
  SELECT CASE
    WHEN p_viewer IS NULL OR p_viewer = '' THEN FALSE
    WHEN p_viewer = p_author THEN TRUE
    WHEN EXISTS (
      SELECT 1 FROM public.account_deletion_requests r
       WHERE r.user_id = p_author AND r.status IN ('pending', 'deleting', 'blocked')
    ) THEN FALSE
    -- La liste « masqué » prime sur tout, y compris sur l'audience publique.
    WHEN EXISTS (
      SELECT 1 FROM story_audience_members m
      WHERE m.owner_id = p_author AND m.member_id = p_viewer AND m.list = 'hidden'
    ) THEN FALSE
    WHEN EXISTS (
      SELECT 1 FROM blocked_users b
      WHERE (b.blocker_id = p_author AND b.blocked_id = p_viewer)
         OR (b.blocker_id = p_viewer AND b.blocked_id = p_author)
    ) THEN FALSE
    WHEN COALESCE(p_audience, 'public') = 'public' THEN TRUE
    WHEN p_audience = 'friends' THEN private.est_ami_de(p_author, p_viewer)
    WHEN p_audience = 'followers' THEN
      private.est_ami_de(p_author, p_viewer)
      OR private.est_abonne_de(p_author, p_viewer)
    WHEN p_audience = 'close' THEN EXISTS (
      SELECT 1 FROM story_audience_members m
      WHERE m.owner_id = p_author AND m.member_id = p_viewer AND m.list = 'close'
    )
    ELSE FALSE
  END;
$function$;

-- ── 7. Les deux entrées de l'orchestrateur (service_role seulement) ─────────

-- Réclame les comptes échus. Un compte dont la situation interdit maintenant
-- la suppression passe en `blocked` au lieu d'être réclamé : il faut le savoir
-- AVANT que la Cloud Function supprime le compte Firebase.
CREATE OR REPLACE FUNCTION public.claim_due_account_deletions(p_limit integer DEFAULT 20)
RETURNS TABLE (uid text)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $function$
BEGIN
  UPDATE public.account_deletion_requests r
     SET status = 'blocked', last_error = b.motif
    FROM (SELECT r2.user_id, private.suppression_bloquee_pour(r2.user_id) AS motif
            FROM public.account_deletion_requests r2
           WHERE r2.status = 'pending' AND r2.execute_at <= now()) b
   WHERE r.user_id = b.user_id AND b.motif IS NOT NULL;

  RETURN QUERY
  WITH due AS (
    SELECT r.user_id
      FROM public.account_deletion_requests r
     WHERE (r.status = 'pending' AND r.execute_at <= now())
        -- Reprise d'une purge restée en route (échec ou fonction interrompue) :
        -- au plus toutes les 30 minutes, au plus 10 fois.
        OR (r.status = 'deleting' AND r.started_at < now() - interval '30 minutes'
            AND r.attempts < 10)
     ORDER BY r.execute_at
     LIMIT GREATEST(p_limit, 1)
       FOR UPDATE SKIP LOCKED)
  UPDATE public.account_deletion_requests r
     SET status = 'deleting', started_at = now(), attempts = r.attempts + 1
    FROM due
   WHERE r.user_id = due.user_id
  RETURNING r.user_id;
END;
$function$;

-- Purge un compte réclamé. Rend {ok, …} au lieu de lever : une exception
-- annulerait aussi l'enregistrement de `last_error`, et la Cloud Function
-- ne saurait pas pourquoi.
CREATE OR REPLACE FUNCTION public.complete_account_deletion(p_uid text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $function$
DECLARE
  v_status  text;
  v_summary jsonb;
BEGIN
  SELECT r.status, r.summary INTO v_status, v_summary
    FROM public.account_deletion_requests r
   WHERE r.user_id = p_uid
     FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'error', 'aucune_demande');
  END IF;
  -- Idempotente : déjà faite, on le redit.
  IF v_status = 'completed' THEN
    RETURN jsonb_build_object('ok', true, 'deja_fait', true, 'summary', v_summary);
  END IF;
  IF v_status <> 'deleting' THEN
    RETURN jsonb_build_object('ok', false, 'error', 'demande_non_reclamee', 'status', v_status);
  END IF;

  BEGIN
    v_summary := private.purge_account(p_uid);
  EXCEPTION WHEN OTHERS THEN
    -- Le bloc entier est annulé : rien n'est resté à moitié effacé.
    UPDATE public.account_deletion_requests
       SET last_error = left(SQLSTATE || ' ' || SQLERRM, 500)
     WHERE user_id = p_uid;
    RETURN jsonb_build_object('ok', false, 'error', left(SQLSTATE || ' ' || SQLERRM, 500));
  END;

  UPDATE public.account_deletion_requests
     SET status = 'completed', completed_at = now(), last_error = NULL,
         summary = v_summary, restore = '{}'::jsonb
   WHERE user_id = p_uid;

  RETURN jsonb_build_object('ok', true, 'summary', v_summary);
END;
$function$;

-- ── 8. Droits ───────────────────────────────────────────────────────────────
--
-- Supabase accorde EXECUTE nommément à anon, authenticated et service_role sur
-- toute fonction neuve de `public` : révoquer PUBLIC ne les touche pas.

REVOKE ALL ON FUNCTION public.request_account_deletion() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.request_account_deletion() TO authenticated;

REVOKE ALL ON FUNCTION public.cancel_account_deletion() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.cancel_account_deletion() TO authenticated;

REVOKE ALL ON FUNCTION public.claim_due_account_deletions(integer) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.claim_due_account_deletions(integer) TO service_role;

REVOKE ALL ON FUNCTION public.complete_account_deletion(text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.complete_account_deletion(text) TO service_role;

COMMENT ON FUNCTION public.request_account_deletion() IS
  'Demande la suppression du compte appelant : désactivation immédiate, purge dans 30 jours. Rend la date d''exécution. Idempotente.';
COMMENT ON FUNCTION public.cancel_account_deletion() IS
  'Annule une suppression pending/blocked et remet la visibilité d''avant.';
COMMENT ON FUNCTION public.claim_due_account_deletions(integer) IS
  'service_role : réclame les comptes échus (ou une purge restée en route). Les comptes bloqués passent en blocked.';
COMMENT ON FUNCTION public.complete_account_deletion(text) IS
  'service_role : purge un compte réclamé, en une transaction. Rend {ok, summary|error}. Idempotente.';

NOTIFY pgrst, 'reload schema';
