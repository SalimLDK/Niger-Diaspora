-- La purge laissait les appartenances de groupes qui n'existent plus.
--
-- TROUVÉ PAR LA RÉPÉTITION SUR UN COMPTE RÉEL (2026-09-19)
-- `tools/rls_tests/suppression_compte_donnees_reelles.sql`, lancé par Salim sur
-- le compte le plus chargé de la base (poids 347, hors compte plateforme), a
-- fait aller la purge au bout — `ok: true`, vingt compteurs renseignés — et n'a
-- listé qu'UNE table qui contenait encore l'uid, hors la pierre tombale :
-- `group_members`, 10 lignes avant, 7 après.
--
-- La table contient exactement 7 lignes sans groupe parent, dans toute la base
-- (mesuré en lecture seule le même jour) : ce sont celles-là. `group_members`
-- n'a aucune clé étrangère vers `groups`, si bien qu'un groupe supprimé — ou
-- hérité de Firestore — laisse ses appartenances. La boucle de la purge part de
-- `groups` : elle ne voit que les appartenances dont le groupe existe.
--
-- POURQUOI LE BANC FICTIF NE L'AVAIT PAS TROUVÉ
-- Ses groupes existent tous. Une donnée réelle a des orphelines que personne
-- n'avait fabriquées : c'est exactement ce que cette répétition devait mesurer.
-- Le banc a maintenant l'appartenance orpheline (cas 50) ; il ÉCHOUE sans ce
-- correctif et passe avec.
--
-- CORRECTIF
-- Un `DELETE` par uid, après la boucle. Le corps de `private.purge_account`
-- est repris TEL QUE DÉPLOYÉ (`pg_get_functiondef` le 2026-09-19 : identique,
-- octet pour octet, à celui de 20260918224100 — `complete_account_deletion`
-- a changé depuis, appelle `private.purge_finances` puis cette fonction, mais
-- celle-ci n'a pas bougé). Seuls ajouts : cette instruction et son compteur
-- `appartenances_orphelines` dans le résumé.
--
-- ⚠️ REMPLACER UNE FONCTION EFFACE CE QU'UN AUTRE REMPLACEMENT A AJOUTÉ. Un
-- test (suppression_compte_purge_test.dart) lit la DERNIÈRE définition de
-- `private.purge_account` : une migration ultérieure qui la reprendrait d'une
-- copie plus ancienne, sans cette instruction, le ferait échouer.

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

  -- Appartenances SANS groupe. `group_members` n'a AUCUNE clé étrangère vers
  -- `groups` : un groupe dissous, ou hérité de Firestore, laisse ses lignes.
  -- La boucle ci-dessus ne voit que les appartenances dont le groupe existe ;
  -- celles-ci gardaient l'uid pour toujours. Un DELETE par uid, après elle :
  -- les vraies appartenances sont déjà parties, il ne reste que les orphelines.
  v_c := v_c || jsonb_build_object('appartenances_orphelines',
      private.purge_delete('public.group_members', p_uid, 'user_id'));

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

-- `CREATE OR REPLACE` conserve les droits ; on les redit pour que la migration
-- se lise seule (un GRANT n'enlève rien : voir 20260918224100).
REVOKE ALL ON FUNCTION private.purge_account(text) FROM PUBLIC, anon, authenticated;
