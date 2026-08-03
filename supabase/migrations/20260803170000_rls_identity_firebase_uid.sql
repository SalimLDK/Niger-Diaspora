-- =============================================================================
-- Réparer l'identité utilisée par les policies RLS.
--
-- Constat mesuré sur la base de production (docs/ops/diagnostic_rls_identite.sql) :
--
--     lignes_users ................. 1247
--     identifiants_qui_coincident ..... 0
--
-- current_user_id() renvoie auth.jwt() ->> 'sub', c'est-à-dire l'identifiant
-- interne Supabase Auth. Les colonnes de propriété (user_id, host_id, id…)
-- contiennent, elles, des Firebase UID : l'échange de jeton écrit
-- `id: firebaseUid` dans public.users (auth-firebase-exchange). Les deux ne
-- coïncident sur AUCUNE des 1247 lignes. Toute policy comparant
-- current_user_id() à l'une de ces colonnes n'accorde donc jamais rien.
--
-- C'est le bug corrigé pour is_admin() en 20260803034145, et pour les
-- conversations / messages / posts en 20260526170000 et 20260715120000 — mais
-- jamais généralisé au reste du schéma. 48 policies sur 27 tables étaient
-- restées en arrière, dont 21 tables réellement interrogées par l'app.
--
-- Ce que ça cassait : tout ce qui est « à moi ». Les policies avec une branche
-- publique survivaient à moitié (un profil public restait lisible, un profil
-- privé devenait invisible même à son propriétaire) ; celles de pure propriété
-- refusaient tout — modifier son profil, s'abonner à un podcast, suivre
-- quelqu'un, publier une story, ouvrir un ticket, consulter ses transactions.
-- Le silence s'explique par le code applicatif, qui avale ces échecs dans des
-- `catch (e) { debugPrint(...) }`.
--
-- Sécurité de la bascule, vérifiée avant écriture : les 1247 comptes portent
-- le claim app_metadata.firebase_uid, donc firebase_uid() résout pour 100 %
-- d'entre eux. Migrer vers cette fonction ne verrouille personne dehors.
-- (La table de secours auth_mappings est vide, sans conséquence ici.)
--
-- Forme : (SELECT firebase_uid()) et non firebase_uid() nu, comme en
-- 20260715120000 — le sous-SELECT est évalué une fois par requête au lieu
-- d'une fois par ligne.
--
-- La logique fonctionnelle de chaque policy est STRICTEMENT inchangée : seule
-- la fonction d'identité est remplacée. Chaque bloc est repris textuellement
-- de sa dernière définition dans les migrations, pour éviter toute
-- réinterprétation. Idempotent : DROP avant chaque CREATE.
-- =============================================================================

-- ── USERS ───────────────────────────────────────────────────────
DROP POLICY IF EXISTS "users_select" ON users;
CREATE POLICY "users_select" ON users FOR SELECT
  USING (NOT is_private OR is_admin() OR (SELECT firebase_uid()) = id);

DROP POLICY IF EXISTS "users_insert_own" ON users;
CREATE POLICY "users_insert_own" ON users FOR INSERT
  WITH CHECK ((SELECT firebase_uid()) = id AND is_admin = FALSE);

DROP POLICY IF EXISTS "users_update_own" ON users;
CREATE POLICY "users_update_own" ON users FOR UPDATE
  USING ((SELECT firebase_uid()) = id)
  WITH CHECK (
    (SELECT firebase_uid()) = id
    AND is_admin = (SELECT u.is_admin FROM users u WHERE u.id = (SELECT firebase_uid()))
    AND (admin_role IS NOT DISTINCT FROM (SELECT u.admin_role FROM users u WHERE u.id = (SELECT firebase_uid())))
  );


-- ── BLOCKED USERS ───────────────────────────────────────────────
DROP POLICY IF EXISTS "blocked_users_own" ON blocked_users;
CREATE POLICY "blocked_users_own" ON blocked_users FOR ALL
  USING ((SELECT firebase_uid()) = blocker_id);


-- ── RECIPIENTS ──────────────────────────────────────────────────
DROP POLICY IF EXISTS "recipients_own" ON recipients;
CREATE POLICY "recipients_own" ON recipients FOR ALL
  USING ((SELECT firebase_uid()) = user_id);


-- ── TRANSACTIONS ────────────────────────────────────────────────
DROP POLICY IF EXISTS "transactions_select_own" ON transactions;
CREATE POLICY "transactions_select_own" ON transactions FOR SELECT
  USING ((SELECT firebase_uid()) = sender_id);

DROP POLICY IF EXISTS "transactions_insert_own" ON transactions;
CREATE POLICY "transactions_insert_own" ON transactions FOR INSERT
  WITH CHECK ((SELECT firebase_uid()) = sender_id);


-- ── BUSINESSES ──────────────────────────────────────────────────
DROP POLICY IF EXISTS "businesses_select_active" ON businesses;
CREATE POLICY "businesses_select_active" ON businesses FOR SELECT
  USING (is_active = TRUE OR (SELECT firebase_uid()) = owner_id OR is_admin());

DROP POLICY IF EXISTS "businesses_insert_own" ON businesses;
CREATE POLICY "businesses_insert_own" ON businesses FOR INSERT
  WITH CHECK ((SELECT firebase_uid()) = owner_id);

DROP POLICY IF EXISTS "businesses_update_owner" ON businesses;
CREATE POLICY "businesses_update_owner" ON businesses FOR UPDATE
  USING ((SELECT firebase_uid()) = owner_id OR is_admin());

DROP POLICY IF EXISTS "businesses_delete_owner" ON businesses;
CREATE POLICY "businesses_delete_owner" ON businesses FOR DELETE
  USING ((SELECT firebase_uid()) = owner_id OR is_admin());


-- ── PRODUCTS ────────────────────────────────────────────────────
DROP POLICY IF EXISTS "products_select" ON products;
CREATE POLICY "products_select" ON products FOR SELECT
  USING (is_available = TRUE OR (SELECT firebase_uid()) = seller_id);

DROP POLICY IF EXISTS "products_manage_own" ON products;
CREATE POLICY "products_manage_own" ON products FOR ALL
  USING ((SELECT firebase_uid()) = seller_id);


-- ── ORDERS ──────────────────────────────────────────────────────
DROP POLICY IF EXISTS "orders_select_parties" ON orders;
CREATE POLICY "orders_select_parties" ON orders FOR SELECT
  USING ((SELECT firebase_uid()) = buyer_id OR (SELECT firebase_uid()) = seller_id);

DROP POLICY IF EXISTS "orders_insert_buyer" ON orders;
CREATE POLICY "orders_insert_buyer" ON orders FOR INSERT
  WITH CHECK ((SELECT firebase_uid()) = buyer_id);

DROP POLICY IF EXISTS "orders_update_parties" ON orders;
CREATE POLICY "orders_update_parties" ON orders FOR UPDATE
  USING ((SELECT firebase_uid()) = buyer_id OR (SELECT firebase_uid()) = seller_id);


-- ── ESCROW TRANSACTIONS ─────────────────────────────────────────
DROP POLICY IF EXISTS "escrow_select_parties" ON escrow_transactions;
CREATE POLICY "escrow_select_parties" ON escrow_transactions FOR SELECT
  USING ((SELECT firebase_uid()) = buyer_id OR (SELECT firebase_uid()) = seller_id);


-- ── FRIEND REQUESTS ─────────────────────────────────────────────
DROP POLICY IF EXISTS "friend_requests_parties" ON friend_requests;
CREATE POLICY "friend_requests_parties" ON friend_requests FOR ALL
  USING ((SELECT firebase_uid()) = sender_id OR (SELECT firebase_uid()) = receiver_id);


-- ── FRIENDS ─────────────────────────────────────────────────────
DROP POLICY IF EXISTS "friends_own" ON friends;
CREATE POLICY "friends_own" ON friends FOR ALL USING ((SELECT firebase_uid()) = user_id);

DROP POLICY IF EXISTS "friends_select_other" ON friends;
CREATE POLICY "friends_select_other" ON friends FOR SELECT
  USING ((SELECT firebase_uid()) = friend_id);


-- ── GROUP MEMBERS ───────────────────────────────────────────────
DROP POLICY IF EXISTS "group_members_select" ON group_members;
CREATE POLICY "group_members_select" ON group_members FOR SELECT
  USING ((SELECT firebase_uid()) = user_id OR EXISTS (
    SELECT 1 FROM groups g WHERE g.id = group_id AND NOT g.is_private
  ));

DROP POLICY IF EXISTS "group_members_own" ON group_members;
CREATE POLICY "group_members_own" ON group_members FOR ALL USING ((SELECT firebase_uid()) = user_id);


-- ── GROUPS ──────────────────────────────────────────────────────
DROP POLICY IF EXISTS "groups_select_public" ON groups;
CREATE POLICY "groups_select_public" ON groups FOR SELECT
  USING (NOT is_private OR (SELECT firebase_uid()) = creator_id OR EXISTS (
    SELECT 1 FROM group_members gm WHERE gm.group_id = id AND gm.user_id = (SELECT firebase_uid())
  ));

DROP POLICY IF EXISTS "groups_update_admin" ON groups;
CREATE POLICY "groups_update_admin" ON groups FOR UPDATE
  USING (EXISTS (
    SELECT 1 FROM group_members gm
    WHERE gm.group_id = id AND gm.user_id = (SELECT firebase_uid()) AND gm.role IN ('admin','owner')
  ));


-- ── POST BOOKMARKS ──────────────────────────────────────────────
DROP POLICY IF EXISTS "post_bookmarks_own" ON post_bookmarks;
CREATE POLICY "post_bookmarks_own" ON post_bookmarks FOR ALL
  USING ((SELECT firebase_uid()) = user_id);


-- ── USER FOLLOWS ────────────────────────────────────────────────
DROP POLICY IF EXISTS "user_follows_own" ON user_follows;
CREATE POLICY "user_follows_own" ON user_follows FOR ALL
  USING ((SELECT firebase_uid()) = follower_id);

DROP POLICY IF EXISTS "user_follows_select" ON user_follows;
CREATE POLICY "user_follows_select" ON user_follows FOR SELECT
  USING ((SELECT firebase_uid()) = following_id);


-- ── EVENTS ──────────────────────────────────────────────────────
DROP POLICY IF EXISTS "events_select" ON events;
CREATE POLICY "events_select" ON events FOR SELECT
  USING (status != 'draft' OR (SELECT firebase_uid()) = organizer_id);

DROP POLICY IF EXISTS "events_manage_own" ON events;
CREATE POLICY "events_manage_own" ON events FOR ALL
  USING ((SELECT firebase_uid()) = organizer_id);


-- ── EVENT ATTENDEES ─────────────────────────────────────────────
DROP POLICY IF EXISTS "event_attendees_own" ON event_attendees;
CREATE POLICY "event_attendees_own" ON event_attendees FOR ALL
  USING ((SELECT firebase_uid()) = user_id);


-- ── ROOM TICKETS ────────────────────────────────────────────────
DROP POLICY IF EXISTS "room_tickets_own" ON room_tickets;
CREATE POLICY "room_tickets_own" ON room_tickets FOR SELECT
  USING ((SELECT firebase_uid()) = user_id);

DROP POLICY IF EXISTS "room_tickets_insert_own" ON room_tickets;
CREATE POLICY "room_tickets_insert_own" ON room_tickets FOR INSERT
  WITH CHECK ((SELECT firebase_uid()) = user_id);


-- ── TIPS ────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "tips_parties" ON tips;
CREATE POLICY "tips_parties" ON tips FOR SELECT
  USING ((SELECT firebase_uid()) = sender_id OR (SELECT firebase_uid()) = recipient_id);

DROP POLICY IF EXISTS "tips_insert_own" ON tips;
CREATE POLICY "tips_insert_own" ON tips FOR INSERT
  WITH CHECK ((SELECT firebase_uid()) = sender_id);


-- ── CREATOR PROFILES ────────────────────────────────────────────
DROP POLICY IF EXISTS "creator_profiles_own" ON creator_profiles;
CREATE POLICY "creator_profiles_own" ON creator_profiles FOR ALL
  USING ((SELECT firebase_uid()) = user_id);


-- ── PODCASTS ────────────────────────────────────────────────────
DROP POLICY IF EXISTS "podcasts_select" ON podcasts;
CREATE POLICY "podcasts_select" ON podcasts FOR SELECT
  USING (status = 'active' OR (SELECT firebase_uid()) = host_id);

DROP POLICY IF EXISTS "podcasts_manage_own" ON podcasts;
CREATE POLICY "podcasts_manage_own" ON podcasts FOR ALL
  USING ((SELECT firebase_uid()) = host_id);


-- ── PODCAST EPISODES ────────────────────────────────────────────
DROP POLICY IF EXISTS "podcast_episodes_select" ON podcast_episodes;
CREATE POLICY "podcast_episodes_select" ON podcast_episodes FOR SELECT
  USING (status = 'published' OR EXISTS (
    SELECT 1 FROM podcasts p WHERE p.id = podcast_id AND p.host_id = (SELECT firebase_uid())
  ));

DROP POLICY IF EXISTS "podcast_episodes_manage" ON podcast_episodes;
CREATE POLICY "podcast_episodes_manage" ON podcast_episodes FOR ALL
  USING (EXISTS (
    SELECT 1 FROM podcasts p WHERE p.id = podcast_id AND p.host_id = (SELECT firebase_uid())
  ));


-- ── PODCAST SUBSCRIPTIONS ───────────────────────────────────────
DROP POLICY IF EXISTS "podcast_subscriptions_own" ON podcast_subscriptions;
CREATE POLICY "podcast_subscriptions_own" ON podcast_subscriptions FOR ALL
  USING ((SELECT firebase_uid()) = user_id);


-- ── REPORTS ─────────────────────────────────────────────────────
DROP POLICY IF EXISTS "reports_insert_own" ON reports;
CREATE POLICY "reports_insert_own" ON reports FOR INSERT
  WITH CHECK ((SELECT firebase_uid()) = reporter_id);

DROP POLICY IF EXISTS "reports_select_own" ON reports;
CREATE POLICY "reports_select_own" ON reports FOR SELECT
  USING ((SELECT firebase_uid()) = reporter_id OR is_admin());


-- ── SUPPORT TICKETS ─────────────────────────────────────────────
DROP POLICY IF EXISTS "support_tickets_own" ON support_tickets;
CREATE POLICY "support_tickets_own" ON support_tickets FOR ALL
  USING ((SELECT firebase_uid()) = user_id);


-- ── STORIES ─────────────────────────────────────────────────────
DROP POLICY IF EXISTS "stories_manage_own" ON stories;
CREATE POLICY "stories_manage_own" ON stories FOR ALL
  USING ((SELECT firebase_uid()) = author_id);


-- ── STORY VIEWS ─────────────────────────────────────────────────
DROP POLICY IF EXISTS "story_views_select" ON story_views;
CREATE POLICY "story_views_select" ON story_views FOR SELECT
  USING (
    (SELECT firebase_uid()) = viewer_id
    OR EXISTS (
      SELECT 1 FROM stories s
      WHERE s.id = story_views.story_id AND s.author_id = (SELECT firebase_uid())
    )
  );

DROP POLICY IF EXISTS "story_views_insert_own" ON story_views;
CREATE POLICY "story_views_insert_own" ON story_views FOR INSERT
  WITH CHECK ((SELECT firebase_uid()) = viewer_id);


-- ── STORY REACTIONS ─────────────────────────────────────────────
DROP POLICY IF EXISTS "story_reactions_select" ON story_reactions;
CREATE POLICY "story_reactions_select" ON story_reactions FOR SELECT
  USING (
    (SELECT firebase_uid()) = user_id
    OR EXISTS (
      SELECT 1 FROM stories s
      WHERE s.id = story_reactions.story_id AND s.author_id = (SELECT firebase_uid())
    )
  );

DROP POLICY IF EXISTS "story_reactions_manage_own" ON story_reactions;
CREATE POLICY "story_reactions_manage_own" ON story_reactions FOR ALL
  USING ((SELECT firebase_uid()) = user_id)
  WITH CHECK ((SELECT firebase_uid()) = user_id);

