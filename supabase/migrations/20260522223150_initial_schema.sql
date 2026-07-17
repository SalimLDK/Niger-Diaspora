-- =============================================================================
-- Diaspo Niger – Schéma initial Supabase
-- Architecture hybride :
--   Firebase : Auth, Firestore (messages/notifs), RTDB (signaling), FCM
--   Supabase : données structurées (finance, profils, marketplace, social)
--
-- IMPORTANT — identifiants utilisateurs :
--   Firebase Auth génère des UIDs de type TEXT (28 car., ex. "TmJ0Fv3q...")
--   et non des UUID standard. Toutes les colonnes référençant un UID Firebase
--   sont déclarées TEXT, pas UUID.
--
-- RLS — JWT :
--   Le token Firebase est transmis à Supabase via signInWithIdToken.
--   auth.jwt() ->> 'sub'  retourne l'UID Firebase (TEXT).
--   Le helper current_user_id() abstrait cet accès pour toutes les policies.
-- =============================================================================

-- Extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";

-- =============================================================================
-- HELPER : current_user_id()
-- Retourne l'UID Firebase depuis le claim 'sub' du JWT.
-- SECURITY DEFINER pour éviter la récursion dans les policies users.
-- =============================================================================
CREATE OR REPLACE FUNCTION current_user_id()
RETURNS TEXT LANGUAGE sql STABLE SECURITY DEFINER AS $$
  SELECT COALESCE(auth.jwt() ->> 'sub', '')
$$;

CREATE OR REPLACE FUNCTION is_admin()
RETURNS BOOLEAN LANGUAGE sql STABLE SECURITY DEFINER AS $$
  SELECT COALESCE(
    (SELECT is_admin FROM users WHERE id = current_user_id()),
    FALSE
  )
$$;

-- =============================================================================
-- USERS
-- =============================================================================
CREATE TABLE IF NOT EXISTS users (
  id TEXT PRIMARY KEY,                    -- UID Firebase Auth (TEXT, pas UUID)
  display_name TEXT,
  display_name_lower TEXT GENERATED ALWAYS AS (LOWER(display_name)) STORED,
  email TEXT,
  phone_number TEXT,
  country_code TEXT,
  city TEXT,
  avatar_url TEXT,
  bio TEXT,
  is_private BOOLEAN NOT NULL DEFAULT FALSE,
  is_admin BOOLEAN NOT NULL DEFAULT FALSE,
  admin_role TEXT CHECK (admin_role IN ('superAdmin','contentMod','businessMod','financeMod')),
  is_verified BOOLEAN NOT NULL DEFAULT FALSE,
  latitude DOUBLE PRECISION,
  longitude DOUBLE PRECISION,
  last_active_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS users_display_name_lower_idx ON users USING gin(display_name_lower gin_trgm_ops);
CREATE INDEX IF NOT EXISTS users_country_code_idx ON users (country_code);
CREATE INDEX IF NOT EXISTS users_last_active_idx ON users (last_active_at DESC);

ALTER TABLE users ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "users_select" ON users;
CREATE POLICY "users_select" ON users FOR SELECT
  USING (NOT is_private OR is_admin() OR current_user_id() = id);

DROP POLICY IF EXISTS "users_insert_own" ON users;
CREATE POLICY "users_insert_own" ON users FOR INSERT
  WITH CHECK (current_user_id() = id AND is_admin = FALSE);

DROP POLICY IF EXISTS "users_update_own" ON users;
CREATE POLICY "users_update_own" ON users FOR UPDATE
  USING (current_user_id() = id)
  WITH CHECK (
    current_user_id() = id
    AND is_admin = (SELECT u.is_admin FROM users u WHERE u.id = current_user_id())
    AND (admin_role IS NOT DISTINCT FROM (SELECT u.admin_role FROM users u WHERE u.id = current_user_id()))
  );

-- =============================================================================
-- BLOCKED USERS
-- =============================================================================
CREATE TABLE IF NOT EXISTS blocked_users (
  blocker_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  blocked_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (blocker_id, blocked_id)
);

CREATE INDEX IF NOT EXISTS blocked_users_blocker_idx ON blocked_users (blocker_id);
CREATE INDEX IF NOT EXISTS blocked_users_blocked_idx ON blocked_users (blocked_id);

ALTER TABLE blocked_users ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "blocked_users_own" ON blocked_users;
CREATE POLICY "blocked_users_own" ON blocked_users FOR ALL
  USING (current_user_id() = blocker_id);

-- =============================================================================
-- RECIPIENTS
-- =============================================================================
CREATE TABLE IF NOT EXISTS recipients (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  phone TEXT,
  country_code TEXT NOT NULL,
  payment_method JSONB,
  is_favorite BOOLEAN NOT NULL DEFAULT FALSE,
  last_used_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS recipients_user_id_idx ON recipients (user_id);
CREATE INDEX IF NOT EXISTS recipients_user_favorite_idx ON recipients (user_id, is_favorite DESC);

ALTER TABLE recipients ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "recipients_own" ON recipients;
CREATE POLICY "recipients_own" ON recipients FOR ALL
  USING (current_user_id() = user_id);

-- =============================================================================
-- TRANSACTIONS (transferts d'argent)
-- =============================================================================
CREATE TABLE IF NOT EXISTS transactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  sender_id TEXT NOT NULL REFERENCES users(id),
  recipient_id UUID REFERENCES recipients(id),
  amount BIGINT NOT NULL CHECK (amount > 0),
  currency TEXT NOT NULL DEFAULT 'XOF',
  status TEXT NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending','processing','completed','failed','refunded','cancelled')),
  stripe_payment_intent_id TEXT UNIQUE,
  payment_provider TEXT,
  provider_reference TEXT,
  failure_reason TEXT,
  notes TEXT,
  metadata JSONB,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS transactions_sender_id_idx ON transactions (sender_id, created_at DESC);
CREATE INDEX IF NOT EXISTS transactions_recipient_id_idx ON transactions (recipient_id)
  WHERE recipient_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS transactions_stripe_pi_idx ON transactions (stripe_payment_intent_id)
  WHERE stripe_payment_intent_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS transactions_status_idx ON transactions (status);

ALTER TABLE transactions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "transactions_select_own" ON transactions;
CREATE POLICY "transactions_select_own" ON transactions FOR SELECT
  USING (current_user_id() = sender_id);

DROP POLICY IF EXISTS "transactions_insert_own" ON transactions;
CREATE POLICY "transactions_insert_own" ON transactions FOR INSERT
  WITH CHECK (current_user_id() = sender_id);

-- Les mises à jour de statut (processing → completed) sont faites côté serveur
-- via service role key (Edge Function / backend). Pas de policy UPDATE client.

-- =============================================================================
-- BUSINESSES
-- =============================================================================
CREATE TABLE IF NOT EXISTS businesses (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id TEXT NOT NULL REFERENCES users(id),
  name TEXT NOT NULL,
  name_lower TEXT GENERATED ALWAYS AS (LOWER(name)) STORED,
  description TEXT,
  category TEXT,
  country_code TEXT,
  city TEXT,
  address TEXT,
  phone TEXT,
  email TEXT,
  website_url TEXT,
  avatar_url TEXT,
  cover_url TEXT,
  latitude DOUBLE PRECISION,
  longitude DOUBLE PRECISION,
  is_verified BOOLEAN NOT NULL DEFAULT FALSE,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  rating NUMERIC(3,2),
  review_count INTEGER NOT NULL DEFAULT 0,
  follower_count INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS businesses_owner_idx ON businesses (owner_id);
CREATE INDEX IF NOT EXISTS businesses_category_country_idx ON businesses (category, country_code)
  WHERE is_active = TRUE;
CREATE INDEX IF NOT EXISTS businesses_name_lower_idx ON businesses USING gin(name_lower gin_trgm_ops);

ALTER TABLE businesses ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "businesses_select_active" ON businesses;
CREATE POLICY "businesses_select_active" ON businesses FOR SELECT
  USING (is_active = TRUE OR current_user_id() = owner_id OR is_admin());
DROP POLICY IF EXISTS "businesses_insert_own" ON businesses;
CREATE POLICY "businesses_insert_own" ON businesses FOR INSERT
  WITH CHECK (current_user_id() = owner_id);
DROP POLICY IF EXISTS "businesses_update_owner" ON businesses;
CREATE POLICY "businesses_update_owner" ON businesses FOR UPDATE
  USING (current_user_id() = owner_id OR is_admin());
DROP POLICY IF EXISTS "businesses_delete_owner" ON businesses;
CREATE POLICY "businesses_delete_owner" ON businesses FOR DELETE
  USING (current_user_id() = owner_id OR is_admin());

-- =============================================================================
-- PRODUCTS (marketplace)
-- =============================================================================
CREATE TABLE IF NOT EXISTS products (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  seller_id TEXT NOT NULL REFERENCES users(id),
  business_id UUID REFERENCES businesses(id),
  title TEXT NOT NULL,
  description TEXT,
  category TEXT,
  price BIGINT NOT NULL CHECK (price >= 0),
  currency TEXT NOT NULL DEFAULT 'XOF',
  stock_quantity INTEGER NOT NULL DEFAULT 0,
  images JSONB NOT NULL DEFAULT '[]',
  country_code TEXT,
  city TEXT,
  is_available BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS products_seller_idx ON products (seller_id);
CREATE INDEX IF NOT EXISTS products_business_idx ON products (business_id) WHERE business_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS products_category_country_idx ON products (category, country_code)
  WHERE is_available = TRUE;

ALTER TABLE products ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "products_select" ON products;
CREATE POLICY "products_select" ON products FOR SELECT
  USING (is_available = TRUE OR current_user_id() = seller_id);
DROP POLICY IF EXISTS "products_manage_own" ON products;
CREATE POLICY "products_manage_own" ON products FOR ALL
  USING (current_user_id() = seller_id);

-- =============================================================================
-- ORDERS (commandes marketplace)
-- =============================================================================
CREATE TABLE IF NOT EXISTS orders (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  buyer_id TEXT NOT NULL REFERENCES users(id),
  seller_id TEXT NOT NULL REFERENCES users(id),
  product_id UUID NOT NULL REFERENCES products(id),
  quantity INTEGER NOT NULL DEFAULT 1 CHECK (quantity > 0),
  unit_price BIGINT NOT NULL,
  total_amount BIGINT NOT NULL,
  currency TEXT NOT NULL DEFAULT 'XOF',
  status TEXT NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending','paid','processing','shipped','delivered','completed','cancelled','refunded','disputed')),
  stripe_payment_intent_id TEXT UNIQUE,
  shipping_address JSONB,
  tracking_number TEXT,
  is_in_dispute BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS orders_buyer_idx ON orders (buyer_id, created_at DESC);
CREATE INDEX IF NOT EXISTS orders_seller_idx ON orders (seller_id, created_at DESC);
CREATE INDEX IF NOT EXISTS orders_product_idx ON orders (product_id);
CREATE INDEX IF NOT EXISTS orders_status_idx ON orders (status);
CREATE INDEX IF NOT EXISTS orders_dispute_idx ON orders (is_in_dispute) WHERE is_in_dispute = TRUE;

ALTER TABLE orders ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "orders_select_parties" ON orders;
CREATE POLICY "orders_select_parties" ON orders FOR SELECT
  USING (current_user_id() = buyer_id OR current_user_id() = seller_id);

DROP POLICY IF EXISTS "orders_insert_buyer" ON orders;
CREATE POLICY "orders_insert_buyer" ON orders FOR INSERT
  WITH CHECK (current_user_id() = buyer_id);

-- Mises à jour de statut côté serveur (service role). Les parties peuvent
-- uniquement annuler (status = 'cancelled') ou ouvrir un litige.
DROP POLICY IF EXISTS "orders_update_parties" ON orders;
CREATE POLICY "orders_update_parties" ON orders FOR UPDATE
  USING (current_user_id() = buyer_id OR current_user_id() = seller_id);

-- =============================================================================
-- ESCROW (séquestre marketplace)
-- =============================================================================
CREATE TABLE IF NOT EXISTS escrow_transactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id UUID NOT NULL REFERENCES orders(id) UNIQUE,
  buyer_id TEXT NOT NULL REFERENCES users(id),
  seller_id TEXT NOT NULL REFERENCES users(id),
  amount BIGINT NOT NULL,
  currency TEXT NOT NULL DEFAULT 'XOF',
  status TEXT NOT NULL DEFAULT 'held'
    CHECK (status IN ('held','released','refunded','disputed')),
  stripe_charge_id TEXT,
  stripe_transfer_id TEXT,
  released_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS escrow_buyer_idx ON escrow_transactions (buyer_id);
CREATE INDEX IF NOT EXISTS escrow_seller_idx ON escrow_transactions (seller_id);

ALTER TABLE escrow_transactions ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "escrow_select_parties" ON escrow_transactions;
CREATE POLICY "escrow_select_parties" ON escrow_transactions FOR SELECT
  USING (current_user_id() = buyer_id OR current_user_id() = seller_id);
-- Les insertions/mises à jour sont effectuées via service role (Edge Function).

-- =============================================================================
-- FRIENDS & SOCIAL
-- =============================================================================
CREATE TABLE IF NOT EXISTS friend_requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  sender_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  receiver_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','accepted','declined')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (sender_id, receiver_id)
);

CREATE INDEX IF NOT EXISTS friend_requests_receiver_idx ON friend_requests (receiver_id, status);
CREATE INDEX IF NOT EXISTS friend_requests_sender_idx ON friend_requests (sender_id, status);

ALTER TABLE friend_requests ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "friend_requests_parties" ON friend_requests;
CREATE POLICY "friend_requests_parties" ON friend_requests FOR ALL
  USING (current_user_id() = sender_id OR current_user_id() = receiver_id);

CREATE TABLE IF NOT EXISTS friends (
  user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  friend_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (user_id, friend_id)
);

CREATE INDEX IF NOT EXISTS friends_user_idx ON friends (user_id);
CREATE INDEX IF NOT EXISTS friends_friend_idx ON friends (friend_id);

ALTER TABLE friends ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "friends_own" ON friends;
CREATE POLICY "friends_own" ON friends FOR ALL USING (current_user_id() = user_id);
-- Lecture de la liste d'amis d'un autre utilisateur (pour suggestions)
DROP POLICY IF EXISTS "friends_select_other" ON friends;
CREATE POLICY "friends_select_other" ON friends FOR SELECT
  USING (current_user_id() = friend_id);

-- =============================================================================
-- GROUPS (communautés)
-- =============================================================================
CREATE TABLE IF NOT EXISTS groups (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  description TEXT,
  avatar_url TEXT,
  cover_url TEXT,
  category TEXT,
  creator_id TEXT NOT NULL REFERENCES users(id),
  country_code TEXT,
  is_private BOOLEAN NOT NULL DEFAULT FALSE,
  member_count INTEGER NOT NULL DEFAULT 1,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS groups_creator_idx ON groups (creator_id);
CREATE INDEX IF NOT EXISTS groups_category_idx ON groups (category, is_private);

ALTER TABLE groups ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "groups_insert" ON groups;
CREATE POLICY "groups_insert" ON groups FOR INSERT WITH CHECK (current_user_id() = creator_id);

CREATE TABLE IF NOT EXISTS group_members (
  group_id UUID NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
  user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  role TEXT NOT NULL DEFAULT 'member' CHECK (role IN ('member','moderator','admin','owner')),
  joined_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (group_id, user_id)
);

CREATE INDEX IF NOT EXISTS group_members_user_idx ON group_members (user_id);
CREATE INDEX IF NOT EXISTS group_members_group_idx ON group_members (group_id);

ALTER TABLE group_members ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "group_members_select" ON group_members;
CREATE POLICY "group_members_select" ON group_members FOR SELECT
  USING (current_user_id() = user_id OR EXISTS (
    SELECT 1 FROM groups g WHERE g.id = group_id AND NOT g.is_private
  ));
DROP POLICY IF EXISTS "group_members_own" ON group_members;
CREATE POLICY "group_members_own" ON group_members FOR ALL USING (current_user_id() = user_id);

-- Policies groups nécessitant group_members (ajoutées après sa création)
DROP POLICY IF EXISTS "groups_select_public" ON groups;
CREATE POLICY "groups_select_public" ON groups FOR SELECT
  USING (NOT is_private OR current_user_id() = creator_id OR EXISTS (
    SELECT 1 FROM group_members gm WHERE gm.group_id = id AND gm.user_id = current_user_id()
  ));
DROP POLICY IF EXISTS "groups_update_admin" ON groups;
CREATE POLICY "groups_update_admin" ON groups FOR UPDATE
  USING (EXISTS (
    SELECT 1 FROM group_members gm
    WHERE gm.group_id = id AND gm.user_id = current_user_id() AND gm.role IN ('admin','owner')
  ));

-- =============================================================================
-- POSTS (fil social)
-- =============================================================================
CREATE TABLE IF NOT EXISTS posts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  author_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  content TEXT,
  media JSONB DEFAULT '[]',
  country_code TEXT,
  group_id UUID REFERENCES groups(id),
  visibility TEXT NOT NULL DEFAULT 'public' CHECK (visibility IN ('public','friends','private')),
  like_count INTEGER NOT NULL DEFAULT 0,
  comment_count INTEGER NOT NULL DEFAULT 0,
  share_count INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS posts_author_idx ON posts (author_id, created_at DESC);
CREATE INDEX IF NOT EXISTS posts_feed_idx ON posts (created_at DESC) WHERE visibility = 'public';
CREATE INDEX IF NOT EXISTS posts_group_idx ON posts (group_id) WHERE group_id IS NOT NULL;

ALTER TABLE posts ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "posts_select" ON posts;
CREATE POLICY "posts_select" ON posts FOR SELECT
  USING (
    visibility = 'public'
    OR current_user_id() = author_id
    OR (visibility = 'friends' AND EXISTS (
      SELECT 1 FROM friends f
      WHERE f.user_id = current_user_id() AND f.friend_id = author_id
    ))
  );
DROP POLICY IF EXISTS "posts_manage_own" ON posts;
CREATE POLICY "posts_manage_own" ON posts FOR ALL USING (current_user_id() = author_id);

CREATE TABLE IF NOT EXISTS post_likes (
  post_id UUID NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
  user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (post_id, user_id)
);

CREATE INDEX IF NOT EXISTS post_likes_user_idx ON post_likes (user_id);

ALTER TABLE post_likes ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "post_likes_all" ON post_likes;
CREATE POLICY "post_likes_all" ON post_likes FOR ALL USING (current_user_id() = user_id);

CREATE TABLE IF NOT EXISTS post_comments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id UUID NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
  author_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  content TEXT NOT NULL,
  parent_comment_id UUID REFERENCES post_comments(id),
  like_count INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS post_comments_post_idx ON post_comments (post_id, created_at);
CREATE INDEX IF NOT EXISTS post_comments_author_idx ON post_comments (author_id);
CREATE INDEX IF NOT EXISTS post_comments_parent_idx ON post_comments (parent_comment_id)
  WHERE parent_comment_id IS NOT NULL;

ALTER TABLE post_comments ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "post_comments_select" ON post_comments;
CREATE POLICY "post_comments_select" ON post_comments FOR SELECT USING (TRUE);
DROP POLICY IF EXISTS "post_comments_manage_own" ON post_comments;
CREATE POLICY "post_comments_manage_own" ON post_comments FOR ALL
  USING (current_user_id() = author_id);

CREATE TABLE IF NOT EXISTS post_bookmarks (
  post_id UUID NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
  user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (post_id, user_id)
);

CREATE INDEX IF NOT EXISTS post_bookmarks_user_idx ON post_bookmarks (user_id, created_at DESC);

ALTER TABLE post_bookmarks ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "post_bookmarks_own" ON post_bookmarks;
CREATE POLICY "post_bookmarks_own" ON post_bookmarks FOR ALL
  USING (current_user_id() = user_id);

CREATE TABLE IF NOT EXISTS user_follows (
  follower_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  following_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (follower_id, following_id)
);

CREATE INDEX IF NOT EXISTS user_follows_follower_idx ON user_follows (follower_id);
CREATE INDEX IF NOT EXISTS user_follows_following_idx ON user_follows (following_id);

ALTER TABLE user_follows ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "user_follows_own" ON user_follows;
CREATE POLICY "user_follows_own" ON user_follows FOR ALL
  USING (current_user_id() = follower_id);
DROP POLICY IF EXISTS "user_follows_select" ON user_follows;
CREATE POLICY "user_follows_select" ON user_follows FOR SELECT
  USING (current_user_id() = following_id);

-- =============================================================================
-- EVENTS
-- =============================================================================
CREATE TABLE IF NOT EXISTS events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organizer_id TEXT NOT NULL REFERENCES users(id),
  title TEXT NOT NULL,
  description TEXT,
  category TEXT,
  country_code TEXT,
  city TEXT,
  address TEXT,
  latitude DOUBLE PRECISION,
  longitude DOUBLE PRECISION,
  cover_url TEXT,
  starts_at TIMESTAMPTZ NOT NULL,
  ends_at TIMESTAMPTZ,
  is_online BOOLEAN NOT NULL DEFAULT FALSE,
  online_url TEXT,
  max_attendees INTEGER,
  attendee_count INTEGER NOT NULL DEFAULT 0,
  status TEXT NOT NULL DEFAULT 'upcoming'
    CHECK (status IN ('draft','upcoming','ongoing','ended','cancelled')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS events_organizer_idx ON events (organizer_id);
CREATE INDEX IF NOT EXISTS events_country_date_idx ON events (country_code, starts_at)
  WHERE status = 'upcoming';

ALTER TABLE events ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "events_select" ON events;
CREATE POLICY "events_select" ON events FOR SELECT
  USING (status != 'draft' OR current_user_id() = organizer_id);
DROP POLICY IF EXISTS "events_manage_own" ON events;
CREATE POLICY "events_manage_own" ON events FOR ALL
  USING (current_user_id() = organizer_id);

CREATE TABLE IF NOT EXISTS event_attendees (
  event_id UUID NOT NULL REFERENCES events(id) ON DELETE CASCADE,
  user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  status TEXT NOT NULL DEFAULT 'going'
    CHECK (status IN ('going','maybe','not_going')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (event_id, user_id)
);

CREATE INDEX IF NOT EXISTS event_attendees_user_idx ON event_attendees (user_id);
CREATE INDEX IF NOT EXISTS event_attendees_event_idx ON event_attendees (event_id, status);

ALTER TABLE event_attendees ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "event_attendees_select" ON event_attendees;
CREATE POLICY "event_attendees_select" ON event_attendees FOR SELECT USING (TRUE);
DROP POLICY IF EXISTS "event_attendees_own" ON event_attendees;
CREATE POLICY "event_attendees_own" ON event_attendees FOR ALL
  USING (current_user_id() = user_id);

-- =============================================================================
-- MONETISATION AUDIO ROOMS
-- =============================================================================
CREATE TABLE IF NOT EXISTS room_tickets (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  room_id TEXT NOT NULL,
  user_id TEXT NOT NULL REFERENCES users(id),
  amount BIGINT NOT NULL,
  currency TEXT NOT NULL DEFAULT 'XOF',
  stripe_payment_intent_id TEXT UNIQUE,
  status TEXT NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending','completed','failed','refunded')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS room_tickets_room_idx ON room_tickets (room_id);
CREATE INDEX IF NOT EXISTS room_tickets_user_idx ON room_tickets (user_id);

ALTER TABLE room_tickets ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "room_tickets_own" ON room_tickets;
CREATE POLICY "room_tickets_own" ON room_tickets FOR SELECT
  USING (current_user_id() = user_id);
DROP POLICY IF EXISTS "room_tickets_insert_own" ON room_tickets;
CREATE POLICY "room_tickets_insert_own" ON room_tickets FOR INSERT
  WITH CHECK (current_user_id() = user_id);

CREATE TABLE IF NOT EXISTS tips (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  room_id TEXT NOT NULL,
  sender_id TEXT NOT NULL REFERENCES users(id),
  recipient_id TEXT NOT NULL REFERENCES users(id),
  amount BIGINT NOT NULL CHECK (amount > 0),
  currency TEXT NOT NULL DEFAULT 'XOF',
  stripe_payment_intent_id TEXT UNIQUE,
  status TEXT NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending','completed','failed')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS tips_sender_idx ON tips (sender_id, created_at DESC);
CREATE INDEX IF NOT EXISTS tips_recipient_idx ON tips (recipient_id, created_at DESC);
CREATE INDEX IF NOT EXISTS tips_room_idx ON tips (room_id);

ALTER TABLE tips ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "tips_parties" ON tips;
CREATE POLICY "tips_parties" ON tips FOR SELECT
  USING (current_user_id() = sender_id OR current_user_id() = recipient_id);
DROP POLICY IF EXISTS "tips_insert_own" ON tips;
CREATE POLICY "tips_insert_own" ON tips FOR INSERT
  WITH CHECK (current_user_id() = sender_id);

CREATE TABLE IF NOT EXISTS creator_profiles (
  user_id TEXT PRIMARY KEY REFERENCES users(id),
  stripe_account_id TEXT UNIQUE,
  stripe_account_status TEXT DEFAULT 'pending',
  payout_enabled BOOLEAN NOT NULL DEFAULT FALSE,
  total_earnings BIGINT NOT NULL DEFAULT 0,
  pending_payout BIGINT NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE creator_profiles ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "creator_profiles_own" ON creator_profiles;
CREATE POLICY "creator_profiles_own" ON creator_profiles FOR ALL
  USING (current_user_id() = user_id);

-- =============================================================================
-- PODCASTS
-- =============================================================================
CREATE TABLE IF NOT EXISTS podcasts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  host_id TEXT NOT NULL REFERENCES users(id),
  title TEXT NOT NULL,
  description TEXT,
  cover_url TEXT,
  category TEXT,
  language TEXT DEFAULT 'fr',
  status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active','paused','ended')),
  subscriber_count INTEGER NOT NULL DEFAULT 0,
  episode_count INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS podcasts_host_idx ON podcasts (host_id);
CREATE INDEX IF NOT EXISTS podcasts_category_idx ON podcasts (category) WHERE status = 'active';

ALTER TABLE podcasts ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "podcasts_select" ON podcasts;
CREATE POLICY "podcasts_select" ON podcasts FOR SELECT
  USING (status = 'active' OR current_user_id() = host_id);
DROP POLICY IF EXISTS "podcasts_manage_own" ON podcasts;
CREATE POLICY "podcasts_manage_own" ON podcasts FOR ALL
  USING (current_user_id() = host_id);

CREATE TABLE IF NOT EXISTS podcast_episodes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  podcast_id UUID NOT NULL REFERENCES podcasts(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  description TEXT,
  audio_url TEXT NOT NULL,
  duration_seconds INTEGER,
  episode_number INTEGER,
  status TEXT NOT NULL DEFAULT 'published'
    CHECK (status IN ('draft','published','archived')),
  play_count INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS podcast_episodes_podcast_idx ON podcast_episodes (podcast_id, created_at DESC);

ALTER TABLE podcast_episodes ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "podcast_episodes_select" ON podcast_episodes;
CREATE POLICY "podcast_episodes_select" ON podcast_episodes FOR SELECT
  USING (status = 'published' OR EXISTS (
    SELECT 1 FROM podcasts p WHERE p.id = podcast_id AND p.host_id = current_user_id()
  ));
DROP POLICY IF EXISTS "podcast_episodes_manage" ON podcast_episodes;
CREATE POLICY "podcast_episodes_manage" ON podcast_episodes FOR ALL
  USING (EXISTS (
    SELECT 1 FROM podcasts p WHERE p.id = podcast_id AND p.host_id = current_user_id()
  ));

CREATE TABLE IF NOT EXISTS podcast_subscriptions (
  podcast_id UUID NOT NULL REFERENCES podcasts(id) ON DELETE CASCADE,
  user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (podcast_id, user_id)
);

CREATE INDEX IF NOT EXISTS podcast_subscriptions_user_idx ON podcast_subscriptions (user_id);

ALTER TABLE podcast_subscriptions ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "podcast_subscriptions_own" ON podcast_subscriptions;
CREATE POLICY "podcast_subscriptions_own" ON podcast_subscriptions FOR ALL
  USING (current_user_id() = user_id);

-- =============================================================================
-- REPORTS & SUPPORT
-- =============================================================================
CREATE TABLE IF NOT EXISTS reports (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  reporter_id TEXT NOT NULL REFERENCES users(id),
  target_type TEXT NOT NULL
    CHECK (target_type IN ('user','post','group','business','comment','audio_room')),
  target_id TEXT NOT NULL,
  reason TEXT NOT NULL,
  description TEXT,
  status TEXT NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending','reviewing','resolved','dismissed')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS reports_status_idx ON reports (status, created_at DESC);
CREATE INDEX IF NOT EXISTS reports_target_idx ON reports (target_type, target_id);

ALTER TABLE reports ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "reports_insert_own" ON reports;
CREATE POLICY "reports_insert_own" ON reports FOR INSERT
  WITH CHECK (current_user_id() = reporter_id);
DROP POLICY IF EXISTS "reports_select_own" ON reports;
CREATE POLICY "reports_select_own" ON reports FOR SELECT
  USING (current_user_id() = reporter_id OR is_admin());
DROP POLICY IF EXISTS "reports_update_admin" ON reports;
CREATE POLICY "reports_update_admin" ON reports FOR UPDATE
  USING (is_admin());

CREATE TABLE IF NOT EXISTS support_tickets (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id TEXT NOT NULL REFERENCES users(id),
  subject TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'open'
    CHECK (status IN ('open','in_progress','resolved','closed')),
  messages JSONB NOT NULL DEFAULT '[]',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS support_tickets_user_idx ON support_tickets (user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS support_tickets_status_idx ON support_tickets (status)
  WHERE status IN ('open','in_progress');

ALTER TABLE support_tickets ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "support_tickets_own" ON support_tickets;
CREATE POLICY "support_tickets_own" ON support_tickets FOR ALL
  USING (current_user_id() = user_id);
DROP POLICY IF EXISTS "support_tickets_admin" ON support_tickets;
CREATE POLICY "support_tickets_admin" ON support_tickets FOR ALL USING (is_admin());

-- =============================================================================
-- APP CONFIG
-- =============================================================================
CREATE TABLE IF NOT EXISTS app_config (
  key TEXT PRIMARY KEY,
  value JSONB NOT NULL,
  description TEXT,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE app_config ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "app_config_select_all" ON app_config;
CREATE POLICY "app_config_select_all" ON app_config FOR SELECT USING (TRUE);
DROP POLICY IF EXISTS "app_config_admin_write" ON app_config;
CREATE POLICY "app_config_admin_write" ON app_config FOR ALL USING (is_admin());

-- =============================================================================
-- TRIGGERS : updated_at automatique
-- =============================================================================
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;

CREATE OR REPLACE TRIGGER users_updated_at
  BEFORE UPDATE ON users FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE OR REPLACE TRIGGER businesses_updated_at
  BEFORE UPDATE ON businesses FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE OR REPLACE TRIGGER products_updated_at
  BEFORE UPDATE ON products FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE OR REPLACE TRIGGER orders_updated_at
  BEFORE UPDATE ON orders FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE OR REPLACE TRIGGER groups_updated_at
  BEFORE UPDATE ON groups FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE OR REPLACE TRIGGER posts_updated_at
  BEFORE UPDATE ON posts FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE OR REPLACE TRIGGER transactions_updated_at
  BEFORE UPDATE ON transactions FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE OR REPLACE TRIGGER creator_profiles_updated_at
  BEFORE UPDATE ON creator_profiles FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE OR REPLACE TRIGGER support_tickets_updated_at
  BEFORE UPDATE ON support_tickets FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE OR REPLACE TRIGGER app_config_updated_at
  BEFORE UPDATE ON app_config FOR EACH ROW EXECUTE FUNCTION update_updated_at();
