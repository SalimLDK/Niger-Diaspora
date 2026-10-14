-- Back-office : le bannissement et le badge « vérifié » de `users` cessent
-- d'être en libre-service, les trois tables du panneau reçoivent enfin des
-- policies, et sept tables perdent les droits de table que Supabase pose par
-- défaut.
--
-- Source : docs/deploiement/AUDIT_ADMIN_2026-10-14.md — § 4 (ce que la
-- production a, que les migrations ne définissent pas), § 6.1 (un banni se
-- débannit, un compte se vérifie), § 6.4 (RPC exécutable par `anon`), § 6.6
-- (droits par défaut sur sept tables), § 6.7 (`admin_role` libre à l'INSERT) ;
-- plan de remédiation § 10, point 2.
--
-- ═══ CE QUI ÉTAIT OUVERT ══════════════════════════════════════════════════
-- (mesuré en production le 2026-10-14, en lecture seule, avant d'écrire)
--
-- 1. `users_update_own` (20260803200000:44-50) ne contraint que `id`,
--    `is_admin` et `admin_role` ; `users_guard_admin_flags` ne regarde que ces
--    deux drapeaux. Un `PATCH /rest/v1/users?id=eq.<soi>` qui pose
--    `{"is_banned":false}` ou `{"is_verified":true}` passe : un banni se
--    débannit, n'importe quel compte se décerne le badge. Et `users_insert_own`
--    force `is_admin = FALSE` mais laisse `admin_role` libre à la création :
--    `admin_role = 'superAdmin'` avec `is_admin = false` ouvre le panneau sans
--    pouvoir serveur (§ 2).
-- 2. `users.verified_at` n'existe pas, alors que `verifyProfile` et
--    `revokeVerification` (admin_provider.dart:1667-1719) l'écrivent : PGRST204
--    pendant que l'écran affiche « Profil vérifié ». `is_banned` (boolean NOT
--    NULL DEFAULT false), `ban_reason` (text), `banned_at` (timestamptz),
--    `banned_by` (text) existent, créées hors dépôt.
-- 3. `admin_audit_logs`, `admin_notifications`, `activity_logs` : RLS active,
--    0 policy, et `anon` comme `authenticated` y gardent les 7 verbes de table.
--    Toute insertion est refusée (42501) : l'audit du panneau n'a jamais rien
--    enregistré — 0 ligne dans les trois. De plus `admin_id` et `sent_by` sont
--    de type `uuid`, alors que `users.id` est du texte et que le panneau envoie
--    `FirebaseAuth.currentUser.uid` (28 caractères ; l'un des deux admins en a
--    15) : même avec une policy, l'INSERT tomberait en 22P02 avant la RLS.
-- 4. `get_or_create_official_group(text, text)` : `SECURITY DEFINER`, ACL
--    `{=X/postgres, anon=X, authenticated=X, service_role=X}` — exécutable par
--    `anon`, avec un `DISABLE TRIGGER` sur `groups` à chaque appel.
-- 5. `reports`, `products`, `transactions`, `events`, `groups`, `app_config`,
--    `support_tickets` : `anon` et `authenticated` ont les 7 verbes, TRUNCATE
--    compris (ignore le RLS). Les policies de ces tables sont presque toutes au
--    rôle `public` : `anon` LIT `events` et `groups` aujourd'hui.
--
-- ═══ CE QUE CETTE MIGRATION FAIT ══════════════════════════════════════════
--
-- Dans l'ordre : la colonne (1), la garde de `users` (2), les trois tables du
-- panneau (3), la fonction (4), les sept tables (5), le rechargement du schéma
-- (6). Tout est idempotent : rejouable sans effet le second coup.
--
-- Vérifié dans `lib/` avant d'écrire : aucune lecture de ces tables en `anon`.
-- `reports`, `products` et `app_config` ne sont lus que par le panneau ;
-- `events`, `groups`, `transactions`, `support_tickets` par des datasources qui
-- attendent la session (l'app n'a pas de mode invité ; le site n'appelle que
-- `auth-firebase-exchange`). Les Edge Functions passent par `service_role`.
--
-- Ce qu'elle NE fait PAS (reste du § 10, point 2) : appliquer le ban côté
-- serveur — policy restrictive, refus dans `auth-firebase-exchange`, `disabled`
-- Firebase. Le ban reste appliqué par le client qui s'éjecte lui-même ; il ne
-- peut simplement plus se lever seul. Ni distinguer les rôles admin (§ 6.2).
--
-- Banc : tools/rls_tests/admin_garde_users_et_tables_admin.sql — lancé tel
-- quel il mesure l'état vivant ; avec ce fichier injecté à la place de la ligne
-- `-- @@CIBLE@@` (tools/rls_tests/repeter_cible.py) il répète la migration
-- dans un `BEGIN … ROLLBACK`. Pas de `BEGIN` ici pour cette raison —
-- repeter_cible.py refuse un contrôle de transaction — et parce que `db push`
-- n'en pose pas (20260920213600). L'ordre des instructions est choisi pour
-- qu'un arrêt à mi-chemin ne retire rien à l'app : GRANT avant REVOKE sur la
-- fonction ; sur les tables du panneau, un REVOKE sans GRANT ne ferme qu'un
-- accès qui n'a jamais marché.

SET lock_timeout = '5s';

-- ── 1. La colonne que le panneau écrit ──────────────────────────────────────
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS verified_at timestamptz;

-- Présentes en production, créées hors dépôt (§ 4). Posées ici, aux types
-- mesurés, pour qu'une base reconstruite depuis `supabase/migrations/` porte
-- ce que la garde ci-dessous référence. Sans effet en production.
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS is_banned  boolean NOT NULL DEFAULT false;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS ban_reason text;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS banned_at  timestamptz;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS banned_by  text;

-- ── 2. La garde de `users` ──────────────────────────────────────────────────
-- Modèle : `businesses_garde_privileges` (20260921071500:100-161). SECURITY
-- INVOKER : aucun privilège de plus, la décision est déléguée à `is_admin()`
-- (SECURITY DEFINER). On compare les VALEURS, jamais les colonnes écrites : un
-- client qui renverrait toute sa ligne à l'identique doit passer. L'app
-- n'envoie aujourd'hui aucune de ces colonnes (`ecrireSaLigneUsers` ne porte
-- que le profil) ; le modèle tient si un build futur les renvoie.
--
-- `session_id` n'est PAS gardé : l'app l'écrit elle-même à la connexion.
CREATE OR REPLACE FUNCTION public.users_garde_privileges()
RETURNS trigger
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_caller text;
BEGIN
  -- Chemins de confiance : `postgres` (migrations, déclencheurs, fonctions
  -- SECURITY DEFINER) et `service_role` (Edge Functions). Seul ce qui arrive
  -- par PostgREST sous l'identité d'un compte est filtré ici.
  IF current_user NOT IN ('authenticated', 'anon') THEN
    RETURN NEW;
  END IF;

  -- Pas de session applicative : SQL Editor, amorçage — même sortie que
  -- `guard_admin_flags` (20260803150000).
  v_caller := public.firebase_uid();
  IF v_caller IS NULL THEN
    RETURN NEW;
  END IF;

  -- Le back-office bannit et vérifie sous l'identité de l'administrateur, par
  -- PostgREST. Sans cette sortie, `banUser` et `verifyProfile` tomberaient en
  -- 42501 — la panne d'`orders` du 2026-09-21, rejouée.
  IF public.is_admin() THEN
    RETURN NEW;
  END IF;

  IF TG_OP = 'INSERT' THEN
    -- Un compte naît ni banni, ni vérifié, sans rôle admin. On FORCE au lieu
    -- de lever : `users_insert_own` force déjà `is_admin = FALSE` de la même
    -- façon, et l'INSERT du client (`ecrireSaLigneUsers`) ne porte aucune de
    -- ces colonnes. Les colonnes compagnes suivent — un motif de ban sans ban,
    -- une date de badge sans badge n'ont pas de sens.
    NEW.is_banned   := false;
    NEW.ban_reason  := NULL;
    NEW.banned_at   := NULL;
    NEW.banned_by   := NULL;
    NEW.is_verified := false;
    NEW.verified_at := NULL;
    NEW.admin_role  := NULL;
    RETURN NEW;
  END IF;

  IF NEW.is_banned      IS DISTINCT FROM OLD.is_banned
     OR NEW.ban_reason  IS DISTINCT FROM OLD.ban_reason
     OR NEW.banned_at   IS DISTINCT FROM OLD.banned_at
     OR NEW.banned_by   IS DISTINCT FROM OLD.banned_by
     OR NEW.is_verified IS DISTINCT FROM OLD.is_verified
     OR NEW.verified_at IS DISTINCT FROM OLD.verified_at
  THEN
    RAISE EXCEPTION
      'users : le bannissement et le badge vérifié sont posés par le back-office, pas par le compte (is_banned, ban_reason, banned_at, banned_by, is_verified, verified_at)'
      USING ERRCODE = '42501';
  END IF;

  RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS users_garde_privileges ON public.users;

CREATE TRIGGER users_garde_privileges
  BEFORE INSERT OR UPDATE ON public.users
  FOR EACH ROW EXECUTE FUNCTION public.users_garde_privileges();

-- ── 3. Les trois tables du panneau ──────────────────────────────────────────
-- Aucun CREATE TABLE dans le dépôt (§ 4) : les trois existent en production.
-- Les `IF NOT EXISTS` ci-dessous reproduisent leurs colonnes mesurées (types,
-- défauts, index), à une différence près : `admin_id` et `sent_by` naissent en
-- `text`, le type de `users.id`. Sans effet en production ; une base
-- reconstruite depuis les migrations porte enfin ces tables.
CREATE TABLE IF NOT EXISTS public.admin_audit_logs (
  id          uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  admin_id    text        NOT NULL,
  admin_name  text,
  action      text        NOT NULL,
  target_type text,
  target_id   text,
  details     jsonb       NOT NULL DEFAULT '{}'::jsonb,
  created_at  timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS admin_audit_logs_idx
  ON public.admin_audit_logs (admin_id, created_at DESC);

CREATE TABLE IF NOT EXISTS public.admin_notifications (
  id           uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  sent_by      text        NOT NULL,
  title        text        NOT NULL,
  body         text        NOT NULL,
  target_type  text        NOT NULL DEFAULT 'all',
  target_value text,
  sent_count   integer     NOT NULL DEFAULT 0,
  data         jsonb       NOT NULL DEFAULT '{}'::jsonb,
  created_at   timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.activity_logs (
  id         uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    text,
  type       text        NOT NULL,
  data       jsonb       NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS activity_logs_user_idx
  ON public.activity_logs (user_id, created_at DESC);

ALTER TABLE public.admin_audit_logs    ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.admin_notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.activity_logs       ENABLE ROW LEVEL SECURITY;

-- `admin_id` / `sent_by` : uuid → text (point 3 de l'en-tête). Les deux tables
-- sont vides : rien à convertir. L'index `admin_audit_logs_idx` suit.
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns
              WHERE table_schema = 'public' AND table_name = 'admin_audit_logs'
                AND column_name = 'admin_id' AND data_type = 'uuid') THEN
    ALTER TABLE public.admin_audit_logs
      ALTER COLUMN admin_id TYPE text USING admin_id::text;
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns
              WHERE table_schema = 'public' AND table_name = 'admin_notifications'
                AND column_name = 'sent_by' AND data_type = 'uuid') THEN
    ALTER TABLE public.admin_notifications
      ALTER COLUMN sent_by TYPE text USING sent_by::text;
  END IF;
END $$;

-- Un GRANT ne restreint rien (CLAUDE.md) : REVOKE d'abord, pour `anon` ET
-- `authenticated`, puis les seuls verbes que des policies couvrent. Ni UPDATE
-- ni DELETE côté client : un journal que l'acteur peut réécrire ou effacer
-- n'est pas un journal (§ 10, point 4 — l'écriture par le client reste à
-- remplacer par un déclencheur ou une RPC).

-- admin_audit_logs : l'admin écrit sous son nom, et lit tout.
REVOKE ALL ON public.admin_audit_logs FROM anon;
REVOKE ALL ON public.admin_audit_logs FROM authenticated;
GRANT SELECT, INSERT ON public.admin_audit_logs TO authenticated;

DROP POLICY IF EXISTS admin_audit_logs_insert_admin ON public.admin_audit_logs;
CREATE POLICY admin_audit_logs_insert_admin ON public.admin_audit_logs
  FOR INSERT TO authenticated
  WITH CHECK (public.is_admin() AND admin_id = (SELECT public.firebase_uid()));

DROP POLICY IF EXISTS admin_audit_logs_select_admin ON public.admin_audit_logs;
CREATE POLICY admin_audit_logs_select_admin ON public.admin_audit_logs
  FOR SELECT TO authenticated
  USING (public.is_admin());

-- admin_notifications : même modèle, `sent_by` au lieu d'`admin_id`.
REVOKE ALL ON public.admin_notifications FROM anon;
REVOKE ALL ON public.admin_notifications FROM authenticated;
GRANT SELECT, INSERT ON public.admin_notifications TO authenticated;

DROP POLICY IF EXISTS admin_notifications_insert_admin ON public.admin_notifications;
CREATE POLICY admin_notifications_insert_admin ON public.admin_notifications
  FOR INSERT TO authenticated
  WITH CHECK (public.is_admin() AND sent_by = (SELECT public.firebase_uid()));

DROP POLICY IF EXISTS admin_notifications_select_admin ON public.admin_notifications;
CREATE POLICY admin_notifications_select_admin ON public.admin_notifications
  FOR SELECT TO authenticated
  USING (public.is_admin());

-- activity_logs : lecture de ses propres lignes, ou de toutes pour un admin.
-- Aucun INSERT client — personne n'y écrit aujourd'hui (§ 4), et le jour où
-- quelque chose le fera, ce sera le serveur.
REVOKE ALL ON public.activity_logs FROM anon;
REVOKE ALL ON public.activity_logs FROM authenticated;
GRANT SELECT ON public.activity_logs TO authenticated;

DROP POLICY IF EXISTS activity_logs_select_own_or_admin ON public.activity_logs;
CREATE POLICY activity_logs_select_own_or_admin ON public.activity_logs
  FOR SELECT TO authenticated
  USING (user_id = (SELECT public.firebase_uid()) OR public.is_admin());

-- ── 4. La RPC des groupes officiels ─────────────────────────────────────────
-- L'app l'appelle (group_supabase_datasource.dart:677), connectée. GRANT avant
-- REVOKE : si le fichier s'arrêtait entre les deux, l'app garderait l'appel.
GRANT EXECUTE ON FUNCTION public.get_or_create_official_group(text, text)
  TO authenticated, service_role;
REVOKE ALL ON FUNCTION public.get_or_create_official_group(text, text)
  FROM PUBLIC, anon;

-- ── 5. Sept tables : les droits par défaut, enfin retirés ───────────────────
-- Motif 20260920213600 (`users`) : `anon` perd tout ; `authenticated` perd les
-- trois verbes qu'aucune policy ne retient — TRUNCATE ignore le RLS, REFERENCES
-- et TRIGGER n'ont aucun usage applicatif. Les policies (rôle `public` pour la
-- plupart) ne sont pas touchées : sans droit de table, `anon` ne les atteint
-- plus.
REVOKE ALL ON public.reports         FROM anon;
REVOKE ALL ON public.products        FROM anon;
REVOKE ALL ON public.transactions    FROM anon;
REVOKE ALL ON public.events          FROM anon;
REVOKE ALL ON public.groups          FROM anon;
REVOKE ALL ON public.app_config      FROM anon;
REVOKE ALL ON public.support_tickets FROM anon;

REVOKE TRUNCATE, REFERENCES, TRIGGER ON public.reports         FROM authenticated;
REVOKE TRUNCATE, REFERENCES, TRIGGER ON public.products        FROM authenticated;
REVOKE TRUNCATE, REFERENCES, TRIGGER ON public.transactions    FROM authenticated;
REVOKE TRUNCATE, REFERENCES, TRIGGER ON public.events          FROM authenticated;
REVOKE TRUNCATE, REFERENCES, TRIGGER ON public.groups          FROM authenticated;
REVOKE TRUNCATE, REFERENCES, TRIGGER ON public.app_config      FROM authenticated;
REVOKE TRUNCATE, REFERENCES, TRIGGER ON public.support_tickets FROM authenticated;

-- ── 6. PostgREST relit le schéma (nouvelle colonne, droits) ─────────────────
NOTIFY pgrst, 'reload schema';
