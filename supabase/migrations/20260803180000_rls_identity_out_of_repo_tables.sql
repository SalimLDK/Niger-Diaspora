-- =============================================================================
-- Réparer l'identité des policies RLS restées hors du dépôt.
--
-- Suite de 20260803170000, qui n'avait pu traiter que les policies déclarées
-- dans les migrations. Le contrôle post-application a montré que la base de
-- production porte 125 policies là où le dépôt n'en déclare que 62 : 17 tables
-- ont été créées par un autre canal, et leurs 34 policies comparent toujours
-- current_user_id() (identifiant Supabase Auth) à des colonnes contenant des
-- Firebase UID.
--
-- Contrôle décisif avant écriture : sur ces 17 tables, RLS est ACTIF et
-- AUCUNE policy saine n'existe — il n'y a donc aucun recours, les policies
-- permissives étant cumulatives. Les opérations concernées sont réellement
-- refusées en production :
--
--   e2ee_devices, e2ee_user_keys, e2ee_one_time_prekeys,
--   e2ee_sender_key_distributions .... enregistrement d'appareil et
--                                      publication des clés du protocole
--   post_reactions, post_reposts,
--   post_comment_likes, post_polls,
--   post_poll_votes .................. engagement du fil
--   group_pinned_items ............... épinglage en conversation
--   heritage_collections,
--   heritage_recordings,
--   heritage_user_data ............... bibliothèque du patrimoine
--   user_preferences, muted_users,
--   content_reports, events .......... préférences, sourdines, signalements
--
-- Ces définitions ne figurant dans aucun fichier, elles sont reprises
-- TEXTUELLEMENT depuis pg_policies de la base de production (permissive,
-- rôles, commande, USING, WITH CHECK), et seule la fonction d'identité est
-- substituée. Aucune n'a été réécrite à la main.
--
-- Chaque bloc est gardé par un test d'existence de table : sur une base neuve
-- reconstruite depuis les seules migrations, ces tables n'existent pas et la
-- migration passe sans échouer.
-- =============================================================================

DO $mig$
BEGIN
  IF to_regclass('public.content_reports') IS NULL THEN RETURN; END IF;
  EXECUTE $sql$DROP POLICY IF EXISTS "Admins can manage all reports" ON content_reports$sql$;
  EXECUTE $sql$
CREATE POLICY "Admins can manage all reports" ON content_reports
  AS PERMISSIVE
  FOR ALL
  TO public
  USING (((SELECT firebase_uid()) IN ( SELECT users.id
   FROM users
  WHERE (users.is_admin = true))))
$sql$;
  EXECUTE $sql$DROP POLICY IF EXISTS "Users can create their own reports" ON content_reports$sql$;
  EXECUTE $sql$
CREATE POLICY "Users can create their own reports" ON content_reports
  AS PERMISSIVE
  FOR INSERT
  TO public
  WITH CHECK (((SELECT firebase_uid()) = reporter_id))
$sql$;
  EXECUTE $sql$DROP POLICY IF EXISTS "Users can view their own reports" ON content_reports$sql$;
  EXECUTE $sql$
CREATE POLICY "Users can view their own reports" ON content_reports
  AS PERMISSIVE
  FOR SELECT
  TO public
  USING (((SELECT firebase_uid()) = reporter_id))
$sql$;
END $mig$;

DO $mig$
BEGIN
  IF to_regclass('public.e2ee_devices') IS NULL THEN RETURN; END IF;
  EXECUTE $sql$DROP POLICY IF EXISTS "e2ee_devices: write own devices" ON e2ee_devices$sql$;
  EXECUTE $sql$
CREATE POLICY "e2ee_devices: write own devices" ON e2ee_devices
  AS PERMISSIVE
  FOR ALL
  TO authenticated
  USING ((user_id = (SELECT firebase_uid())))
  WITH CHECK ((user_id = (SELECT firebase_uid())))
$sql$;
END $mig$;

DO $mig$
BEGIN
  IF to_regclass('public.e2ee_one_time_prekeys') IS NULL THEN RETURN; END IF;
  EXECUTE $sql$DROP POLICY IF EXISTS "e2ee_one_time_prekeys: owner insert" ON e2ee_one_time_prekeys$sql$;
  EXECUTE $sql$
CREATE POLICY "e2ee_one_time_prekeys: owner insert" ON e2ee_one_time_prekeys
  AS PERMISSIVE
  FOR INSERT
  TO authenticated
  WITH CHECK ((user_id = (SELECT firebase_uid())))
$sql$;
END $mig$;

DO $mig$
BEGIN
  IF to_regclass('public.e2ee_sender_key_distributions') IS NULL THEN RETURN; END IF;
  EXECUTE $sql$DROP POLICY IF EXISTS "e2ee_skd: recipient delete" ON e2ee_sender_key_distributions$sql$;
  EXECUTE $sql$
CREATE POLICY "e2ee_skd: recipient delete" ON e2ee_sender_key_distributions
  AS PERMISSIVE
  FOR DELETE
  TO authenticated
  USING ((recipient_id = (SELECT firebase_uid())))
$sql$;
  EXECUTE $sql$DROP POLICY IF EXISTS "e2ee_skd: recipient read" ON e2ee_sender_key_distributions$sql$;
  EXECUTE $sql$
CREATE POLICY "e2ee_skd: recipient read" ON e2ee_sender_key_distributions
  AS PERMISSIVE
  FOR SELECT
  TO authenticated
  USING ((recipient_id = (SELECT firebase_uid())))
$sql$;
  EXECUTE $sql$DROP POLICY IF EXISTS "e2ee_skd: sender insert" ON e2ee_sender_key_distributions$sql$;
  EXECUTE $sql$
CREATE POLICY "e2ee_skd: sender insert" ON e2ee_sender_key_distributions
  AS PERMISSIVE
  FOR INSERT
  TO authenticated
  WITH CHECK ((sender_id = (SELECT firebase_uid())))
$sql$;
END $mig$;

DO $mig$
BEGIN
  IF to_regclass('public.e2ee_user_keys') IS NULL THEN RETURN; END IF;
  EXECUTE $sql$DROP POLICY IF EXISTS "e2ee_user_keys: write own row" ON e2ee_user_keys$sql$;
  EXECUTE $sql$
CREATE POLICY "e2ee_user_keys: write own row" ON e2ee_user_keys
  AS PERMISSIVE
  FOR ALL
  TO authenticated
  USING ((user_id = (SELECT firebase_uid())))
  WITH CHECK ((user_id = (SELECT firebase_uid())))
$sql$;
END $mig$;

DO $mig$
BEGIN
  IF to_regclass('public.events') IS NULL THEN RETURN; END IF;
  EXECUTE $sql$DROP POLICY IF EXISTS "events_select_conversation_participants" ON events$sql$;
  EXECUTE $sql$
CREATE POLICY "events_select_conversation_participants" ON events
  AS PERMISSIVE
  FOR SELECT
  TO public
  USING (((conversation_id IS NOT NULL) AND (EXISTS ( SELECT 1
   FROM conversations c
  WHERE ((c.id = events.conversation_id) AND (c.participant_ids @> ARRAY[(SELECT firebase_uid())]))))))
$sql$;
END $mig$;

DO $mig$
BEGIN
  IF to_regclass('public.group_pinned_items') IS NULL THEN RETURN; END IF;
  EXECUTE $sql$DROP POLICY IF EXISTS "Conversation participants can pin items" ON group_pinned_items$sql$;
  EXECUTE $sql$
CREATE POLICY "Conversation participants can pin items" ON group_pinned_items
  AS PERMISSIVE
  FOR INSERT
  TO public
  WITH CHECK (((conversation_id IS NOT NULL) AND ((SELECT firebase_uid()) = pinned_by) AND (EXISTS ( SELECT 1
   FROM conversations c
  WHERE ((c.id = group_pinned_items.conversation_id) AND (c.participant_ids @> ARRAY[(SELECT firebase_uid())]))))))
$sql$;
  EXECUTE $sql$DROP POLICY IF EXISTS "Conversation participants can unpin items" ON group_pinned_items$sql$;
  EXECUTE $sql$
CREATE POLICY "Conversation participants can unpin items" ON group_pinned_items
  AS PERMISSIVE
  FOR DELETE
  TO public
  USING (((conversation_id IS NOT NULL) AND (EXISTS ( SELECT 1
   FROM conversations c
  WHERE ((c.id = group_pinned_items.conversation_id) AND (c.participant_ids @> ARRAY[(SELECT firebase_uid())]))))))
$sql$;
  EXECUTE $sql$DROP POLICY IF EXISTS "Conversation participants can view pinned items" ON group_pinned_items$sql$;
  EXECUTE $sql$
CREATE POLICY "Conversation participants can view pinned items" ON group_pinned_items
  AS PERMISSIVE
  FOR SELECT
  TO public
  USING (((conversation_id IS NOT NULL) AND (EXISTS ( SELECT 1
   FROM conversations c
  WHERE ((c.id = group_pinned_items.conversation_id) AND (c.participant_ids @> ARRAY[(SELECT firebase_uid())]))))))
$sql$;
  EXECUTE $sql$DROP POLICY IF EXISTS "Group members can view pinned items" ON group_pinned_items$sql$;
  EXECUTE $sql$
CREATE POLICY "Group members can view pinned items" ON group_pinned_items
  AS PERMISSIVE
  FOR SELECT
  TO public
  USING ((EXISTS ( SELECT 1
   FROM group_members gm
  WHERE ((gm.group_id = group_pinned_items.group_id) AND (gm.user_id = (SELECT firebase_uid()))))))
$sql$;
  EXECUTE $sql$DROP POLICY IF EXISTS "Members with pin permission can pin items" ON group_pinned_items$sql$;
  EXECUTE $sql$
CREATE POLICY "Members with pin permission can pin items" ON group_pinned_items
  AS PERMISSIVE
  FOR INSERT
  TO public
  WITH CHECK ((((SELECT firebase_uid()) = pinned_by) AND (EXISTS ( SELECT 1
   FROM (group_members gm
     JOIN groups g ON ((g.id = gm.group_id)))
  WHERE ((gm.group_id = group_pinned_items.group_id) AND (gm.user_id = (SELECT firebase_uid())) AND (((g.permissions ->> 'who_can_pin'::text) = 'all_members'::text) OR (gm.role = ANY (ARRAY['owner'::text, 'admin'::text, 'moderator'::text]))))))))
$sql$;
  EXECUTE $sql$DROP POLICY IF EXISTS "Members with pin permission can unpin items" ON group_pinned_items$sql$;
  EXECUTE $sql$
CREATE POLICY "Members with pin permission can unpin items" ON group_pinned_items
  AS PERMISSIVE
  FOR DELETE
  TO public
  USING ((EXISTS ( SELECT 1
   FROM (group_members gm
     JOIN groups g ON ((g.id = gm.group_id)))
  WHERE ((gm.group_id = group_pinned_items.group_id) AND (gm.user_id = (SELECT firebase_uid())) AND (((g.permissions ->> 'who_can_pin'::text) = 'all_members'::text) OR (gm.role = ANY (ARRAY['owner'::text, 'admin'::text, 'moderator'::text])))))))
$sql$;
END $mig$;

DO $mig$
BEGIN
  IF to_regclass('public.heritage_collections') IS NULL THEN RETURN; END IF;
  EXECUTE $sql$DROP POLICY IF EXISTS "heritage_collections_manage_own" ON heritage_collections$sql$;
  EXECUTE $sql$
CREATE POLICY "heritage_collections_manage_own" ON heritage_collections
  AS PERMISSIVE
  FOR ALL
  TO public
  USING (((SELECT firebase_uid()) = "creatorId"))
  WITH CHECK (((SELECT firebase_uid()) = "creatorId"))
$sql$;
  EXECUTE $sql$DROP POLICY IF EXISTS "heritage_collections_select" ON heritage_collections$sql$;
  EXECUTE $sql$
CREATE POLICY "heritage_collections_select" ON heritage_collections
  AS PERMISSIVE
  FOR SELECT
  TO public
  USING ((("isPublic" = true) OR ((SELECT firebase_uid()) = "creatorId")))
$sql$;
END $mig$;

DO $mig$
BEGIN
  IF to_regclass('public.heritage_recordings') IS NULL THEN RETURN; END IF;
  EXECUTE $sql$DROP POLICY IF EXISTS "heritage_recordings_manage_own" ON heritage_recordings$sql$;
  EXECUTE $sql$
CREATE POLICY "heritage_recordings_manage_own" ON heritage_recordings
  AS PERMISSIVE
  FOR ALL
  TO public
  USING (((SELECT firebase_uid()) = "contributorId"))
  WITH CHECK (((SELECT firebase_uid()) = "contributorId"))
$sql$;
  EXECUTE $sql$DROP POLICY IF EXISTS "heritage_recordings_select" ON heritage_recordings$sql$;
  EXECUTE $sql$
CREATE POLICY "heritage_recordings_select" ON heritage_recordings
  AS PERMISSIVE
  FOR SELECT
  TO public
  USING (((status = 'approved'::text) OR ((SELECT firebase_uid()) = "contributorId")))
$sql$;
END $mig$;

DO $mig$
BEGIN
  IF to_regclass('public.heritage_user_data') IS NULL THEN RETURN; END IF;
  EXECUTE $sql$DROP POLICY IF EXISTS "heritage_user_data_own" ON heritage_user_data$sql$;
  EXECUTE $sql$
CREATE POLICY "heritage_user_data_own" ON heritage_user_data
  AS PERMISSIVE
  FOR ALL
  TO public
  USING (((SELECT firebase_uid()) = "userId"))
  WITH CHECK (((SELECT firebase_uid()) = "userId"))
$sql$;
END $mig$;

DO $mig$
BEGIN
  IF to_regclass('public.muted_users') IS NULL THEN RETURN; END IF;
  EXECUTE $sql$DROP POLICY IF EXISTS "Users can manage their own mutes" ON muted_users$sql$;
  EXECUTE $sql$
CREATE POLICY "Users can manage their own mutes" ON muted_users
  AS PERMISSIVE
  FOR ALL
  TO public
  USING (((SELECT firebase_uid()) = user_id))
  WITH CHECK (((SELECT firebase_uid()) = user_id))
$sql$;
END $mig$;

DO $mig$
BEGIN
  IF to_regclass('public.post_comment_likes') IS NULL THEN RETURN; END IF;
  EXECUTE $sql$DROP POLICY IF EXISTS "post_comment_likes_own" ON post_comment_likes$sql$;
  EXECUTE $sql$
CREATE POLICY "post_comment_likes_own" ON post_comment_likes
  AS PERMISSIVE
  FOR ALL
  TO public
  USING (((SELECT firebase_uid()) = user_id))
$sql$;
END $mig$;

DO $mig$
BEGIN
  IF to_regclass('public.post_poll_votes') IS NULL THEN RETURN; END IF;
  EXECUTE $sql$DROP POLICY IF EXISTS "Users can retract their own vote" ON post_poll_votes$sql$;
  EXECUTE $sql$
CREATE POLICY "Users can retract their own vote" ON post_poll_votes
  AS PERMISSIVE
  FOR DELETE
  TO public
  USING (((SELECT firebase_uid()) = user_id))
$sql$;
  EXECUTE $sql$DROP POLICY IF EXISTS "Users can view their own votes" ON post_poll_votes$sql$;
  EXECUTE $sql$
CREATE POLICY "Users can view their own votes" ON post_poll_votes
  AS PERMISSIVE
  FOR SELECT
  TO public
  USING (((SELECT firebase_uid()) = user_id))
$sql$;
  EXECUTE $sql$DROP POLICY IF EXISTS "Users can vote once per poll" ON post_poll_votes$sql$;
  EXECUTE $sql$
CREATE POLICY "Users can vote once per poll" ON post_poll_votes
  AS PERMISSIVE
  FOR INSERT
  TO public
  WITH CHECK ((((SELECT firebase_uid()) = user_id) AND (EXISTS ( SELECT 1
   FROM post_polls p
  WHERE ((p.id = post_poll_votes.poll_id) AND ((p.post_id IS NOT NULL) OR (EXISTS ( SELECT 1
           FROM group_members gm
          WHERE ((gm.group_id = p.group_id) AND (gm.user_id = (SELECT firebase_uid())))))))))))
$sql$;
END $mig$;

DO $mig$
BEGIN
  IF to_regclass('public.post_polls') IS NULL THEN RETURN; END IF;
  EXECUTE $sql$DROP POLICY IF EXISTS "Group members can create polls per group permissions" ON post_polls$sql$;
  EXECUTE $sql$
CREATE POLICY "Group members can create polls per group permissions" ON post_polls
  AS PERMISSIVE
  FOR INSERT
  TO public
  WITH CHECK (((group_id IS NOT NULL) AND ((SELECT firebase_uid()) = created_by) AND (EXISTS ( SELECT 1
   FROM (group_members gm
     JOIN groups g ON ((g.id = gm.group_id)))
  WHERE ((gm.group_id = post_polls.group_id) AND (gm.user_id = (SELECT firebase_uid())) AND (((g.permissions ->> 'who_can_post_polls'::text) = 'all_members'::text) OR (gm.role = ANY (ARRAY['owner'::text, 'admin'::text, 'moderator'::text]))))))))
$sql$;
  EXECUTE $sql$DROP POLICY IF EXISTS "Group poll creators and admins can delete" ON post_polls$sql$;
  EXECUTE $sql$
CREATE POLICY "Group poll creators and admins can delete" ON post_polls
  AS PERMISSIVE
  FOR DELETE
  TO public
  USING (((group_id IS NOT NULL) AND (((SELECT firebase_uid()) = created_by) OR (EXISTS ( SELECT 1
   FROM group_members gm
  WHERE ((gm.group_id = post_polls.group_id) AND (gm.user_id = (SELECT firebase_uid())) AND (gm.role = ANY (ARRAY['owner'::text, 'admin'::text]))))))))
$sql$;
  EXECUTE $sql$DROP POLICY IF EXISTS "Group polls are readable by group members" ON post_polls$sql$;
  EXECUTE $sql$
CREATE POLICY "Group polls are readable by group members" ON post_polls
  AS PERMISSIVE
  FOR SELECT
  TO public
  USING (((group_id IS NOT NULL) AND (EXISTS ( SELECT 1
   FROM group_members gm
  WHERE ((gm.group_id = post_polls.group_id) AND (gm.user_id = (SELECT firebase_uid())))))))
$sql$;
  EXECUTE $sql$DROP POLICY IF EXISTS "Poll authors can manage their polls" ON post_polls$sql$;
  EXECUTE $sql$
CREATE POLICY "Poll authors can manage their polls" ON post_polls
  AS PERMISSIVE
  FOR ALL
  TO public
  USING (((SELECT firebase_uid()) = ( SELECT posts.author_id
   FROM posts
  WHERE (posts.id = post_polls.post_id))))
$sql$;
END $mig$;

DO $mig$
BEGIN
  IF to_regclass('public.post_reactions') IS NULL THEN RETURN; END IF;
  EXECUTE $sql$DROP POLICY IF EXISTS "Users can manage their own reactions" ON post_reactions$sql$;
  EXECUTE $sql$
CREATE POLICY "Users can manage their own reactions" ON post_reactions
  AS PERMISSIVE
  FOR ALL
  TO public
  USING (((SELECT firebase_uid()) = user_id))
  WITH CHECK (((SELECT firebase_uid()) = user_id))
$sql$;
END $mig$;

DO $mig$
BEGIN
  IF to_regclass('public.post_reposts') IS NULL THEN RETURN; END IF;
  EXECUTE $sql$DROP POLICY IF EXISTS "post_reposts_delete_own" ON post_reposts$sql$;
  EXECUTE $sql$
CREATE POLICY "post_reposts_delete_own" ON post_reposts
  AS PERMISSIVE
  FOR DELETE
  TO public
  USING (((SELECT firebase_uid()) = user_id))
$sql$;
  EXECUTE $sql$DROP POLICY IF EXISTS "post_reposts_insert_own" ON post_reposts$sql$;
  EXECUTE $sql$
CREATE POLICY "post_reposts_insert_own" ON post_reposts
  AS PERMISSIVE
  FOR INSERT
  TO public
  WITH CHECK (((SELECT firebase_uid()) = user_id))
$sql$;
END $mig$;

DO $mig$
BEGIN
  IF to_regclass('public.user_preferences') IS NULL THEN RETURN; END IF;
  EXECUTE $sql$DROP POLICY IF EXISTS "Users own their preferences" ON user_preferences$sql$;
  EXECUTE $sql$
CREATE POLICY "Users own their preferences" ON user_preferences
  AS PERMISSIVE
  FOR ALL
  TO public
  USING (((SELECT firebase_uid()) = user_id))
  WITH CHECK (((SELECT firebase_uid()) = user_id))
$sql$;
END $mig$;
