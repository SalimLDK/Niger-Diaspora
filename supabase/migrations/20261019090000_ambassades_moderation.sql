-- Ambassades et consulats : vérification sourcée, suspension motivée,
-- historique, et plus de bascule de statut par écriture directe.
--
-- Référentiel d'administration § 9 et spécification d'interfaces § 14.
--
-- ═══ CE QUI EXISTAIT ═══════════════════════════════════════════════════════
--
-- Le panneau vérifiait, refusait, suspendait et réactivait une ambassade par
-- `UPDATE embassies` (policy `is_super_admin()`), sans source, sans motif
-- conservé, sans la moindre trace : AUCUNE ligne d'audit n'était écrite par
-- ces quatre gestes. Le motif de refus saisi dans la boîte de dialogue était
-- envoyé tel quel, y compris vide. Une suspension ne disait ni pourquoi ni
-- depuis quand. Et `anon` comme `authenticated` portaient TRUNCATE,
-- REFERENCES et TRIGGER sur la table : TRUNCATE ignore le RLS (PostgREST ne
-- l'expose pas, ce n'est pas une porte ouverte aujourd'hui ; elle le devient
-- au premier `security invoker` qui tronque).
-- Au 2026-10-19 : 32 ambassades, toutes vérifiées, toutes avec une adresse
-- de source, aucune suspendue. Cette migration n'en touche aucune.
--
-- ═══ CE QUE CETTE MIGRATION POSE ═══════════════════════════════════════════
--
-- • `suspended_at` et `suspended_reason` : une suspension dit pourquoi et
--   depuis quand.
-- • `embassy_history` : un déclencheur consigne tout changement de nom, de
--   localisation, de contact, de statut, de source ou de fermeture, avec
--   ancien / nouveau, auteur, rôle et motif ; une suppression laisse un
--   instantané. Ajout seul, comme les autres journaux.
-- • Quatre RPC — vérifier (adresse de source https ET éditeur obligatoires :
--   « une information non sourcée ne se présente pas comme vérifiée »),
--   refuser (motif), suspendre (motif), réactiver (motif) — qui verrouillent
--   la ligne, refusent un passage incohérent (55000) et écrivent l'audit dans
--   la même transaction.
-- • Un déclencheur de garde : un administrateur qui écrirait `is_verified`,
--   `verified_at`, `is_suspended`, `rejection_reason` ou les colonnes de
--   suspension par PostgREST est refusé (42501), super-administrateur
--   compris. Une ambassade ne naît pas déjà vérifiée ni suspendue.
-- • `consular.embassies.verify` et `consular.embassies.suspend` : mappées à
--   AUCUN rôle — comme aujourd'hui, seul le super-administrateur écrit
--   cette table. Le catalogue le dit enfin.
-- • TRUNCATE, REFERENCES, TRIGGER retirés à `anon` et `authenticated`.
-- • La policy de suppression directe est retirée : aucun écran ne supprime une
--   ambassade, et l'effacer détruirait la ligne sans motif. Un retrait passe
--   par la suspension.
--
-- ═══ CE QU'ELLE NE FAIT PAS ═════════════════════════════════════════════════
--
-- • Les champs de contact et de localisation restent modifiables en direct par
--   le super-administrateur (l'écran de création l'exige) ; le déclencheur
--   d'historique les consigne mais ne les motive pas.
-- • Pas de relecture périodique des sources : `source_checked_at` est posé,
--   rien ne signale encore une source ancienne ou injoignable.
--
-- Banc : tools/rls_tests/ambassades_moderation.sql.

SET lock_timeout = '5s';

-- ── 1. Colonnes de suspension ───────────────────────────────────────────────
ALTER TABLE public.embassies
  ADD COLUMN IF NOT EXISTS suspended_at     timestamptz,
  ADD COLUMN IF NOT EXISTS suspended_reason text;

-- ── 2. Permissions ──────────────────────────────────────────────────────────
INSERT INTO public.admin_permissions (key, module, description, legacy_key) VALUES
  ('consular.embassies.verify',  'consular', 'Vérifier ou refuser une ambassade (source obligatoire)', NULL),
  ('consular.embassies.suspend', 'consular', 'Suspendre ou réactiver une ambassade (motif obligatoire)', NULL)
ON CONFLICT (key) DO NOTHING;
-- Volontairement aucun INSERT dans admin_role_permissions (voir l'en-tête).

-- ── 3. L'historique ─────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.embassy_history (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  embassy_id    uuid NOT NULL,         -- pas de FK : l'historique survit à la suppression
  embassy_name  text,
  kind          text NOT NULL CHECK (kind IN ('created', 'changed', 'deleted')),
  actor_id      text,
  actor_role    text NOT NULL CHECK (actor_role IN ('admin', 'system')),
  changes       jsonb NOT NULL,
  reason        text,
  occurred_at   timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS embassy_history_embassy_idx
  ON public.embassy_history (embassy_id, occurred_at DESC);

ALTER TABLE public.embassy_history ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.embassy_history FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.embassy_history TO authenticated;
DROP POLICY IF EXISTS embassy_history_select ON public.embassy_history;
CREATE POLICY embassy_history_select ON public.embassy_history
  FOR SELECT TO authenticated
  USING (public.admin_has_permission('consular.view'));

CREATE OR REPLACE FUNCTION public.embassy_history_append_only()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public, pg_temp
AS $$
BEGIN
  RAISE EXCEPTION 'embassy_history est en ajout seul (% refusé)', TG_OP
    USING ERRCODE = '42501';
END $$;

DROP TRIGGER IF EXISTS embassy_history_no_rewrite ON public.embassy_history;
CREATE TRIGGER embassy_history_no_rewrite
  BEFORE UPDATE OR DELETE ON public.embassy_history
  FOR EACH ROW EXECUTE FUNCTION public.embassy_history_append_only();

CREATE OR REPLACE FUNCTION public.embassies_record_history()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_uid     text := (SELECT public.firebase_uid());
  v_role    text := CASE WHEN v_uid IS NULL AND current_setting('app.embassy_rpc', true) IS DISTINCT FROM 'on'
                         THEN 'system' ELSE 'admin' END;
  v_reason  text := nullif(current_setting('app.embassy_reason', true), '');
  v_changes jsonb := '{}'::jsonb;
  c         text;
  v_old     jsonb;
  v_new     jsonb;
  v_suivies constant text[] := ARRAY['name', 'country', 'city', 'address', 'phone', 'email',
    'website', 'type', 'latitude', 'longitude', 'is_verified', 'is_suspended',
    'suspended_reason', 'rejection_reason', 'is_temporarily_closed', 'closure_message',
    'reopen_date', 'source', 'source_url', 'source_checked_at', 'position_uncertain'];
BEGIN
  IF TG_OP = 'INSERT' THEN
    INSERT INTO public.embassy_history (embassy_id, embassy_name, kind, actor_id, actor_role, changes, reason)
    VALUES (NEW.id, NEW.name, 'created', v_uid, v_role,
            jsonb_build_object('name', NEW.name, 'country', NEW.country, 'city', NEW.city), v_reason);
    RETURN NEW;
  END IF;

  IF TG_OP = 'DELETE' THEN
    INSERT INTO public.embassy_history (embassy_id, embassy_name, kind, actor_id, actor_role, changes, reason)
    VALUES (OLD.id, OLD.name, 'deleted', v_uid, v_role,
            jsonb_build_object('name', OLD.name, 'country', OLD.country, 'city', OLD.city,
                               'is_verified', OLD.is_verified), v_reason);
    RETURN OLD;
  END IF;

  v_old := to_jsonb(OLD);
  v_new := to_jsonb(NEW);
  FOREACH c IN ARRAY v_suivies LOOP
    IF v_old -> c IS DISTINCT FROM v_new -> c THEN
      v_changes := v_changes || jsonb_build_object(
        c, jsonb_build_object('from', v_old -> c, 'to', v_new -> c));
    END IF;
  END LOOP;
  IF v_changes <> '{}'::jsonb THEN
    INSERT INTO public.embassy_history (embassy_id, embassy_name, kind, actor_id, actor_role, changes, reason)
    VALUES (NEW.id, NEW.name, 'changed', v_uid, v_role, v_changes, v_reason);
  END IF;
  RETURN NEW;
END $$;

REVOKE ALL ON FUNCTION public.embassies_record_history() FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS trg_embassies_record_history_iu ON public.embassies;
CREATE TRIGGER trg_embassies_record_history_iu
  AFTER INSERT OR UPDATE ON public.embassies
  FOR EACH ROW EXECUTE FUNCTION public.embassies_record_history();
DROP TRIGGER IF EXISTS trg_embassies_record_history_del ON public.embassies;
CREATE TRIGGER trg_embassies_record_history_del
  BEFORE DELETE ON public.embassies
  FOR EACH ROW EXECUTE FUNCTION public.embassies_record_history();

-- ── 4. Garde : le statut ne se pose que par les RPC ─────────────────────────
-- Les chemins de confiance (`current_user NOT IN ('authenticated','anon')` :
-- migrations, SECURITY DEFINER, service_role) passent ; seul ce qui arrive par
-- PostgREST sous l'identité d'un compte est filtré — super-administrateur
-- compris.
CREATE OR REPLACE FUNCTION public.embassies_garde_statut()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public, pg_temp
AS $$
BEGIN
  IF current_user NOT IN ('authenticated', 'anon') THEN
    RETURN NEW;
  END IF;

  IF TG_OP = 'INSERT' THEN
    IF coalesce(NEW.is_verified, false) OR coalesce(NEW.is_suspended, false)
       OR NEW.verified_at IS NOT NULL OR NEW.rejection_reason IS NOT NULL
       OR NEW.suspended_at IS NOT NULL OR NEW.suspended_reason IS NOT NULL THEN
      RAISE EXCEPTION 'embassies : une ambassade ne naît ni vérifiée, ni refusée, ni suspendue'
        USING ERRCODE = '42501';
    END IF;
    RETURN NEW;
  END IF;

  IF NEW.is_verified      IS DISTINCT FROM OLD.is_verified
     OR NEW.verified_at      IS DISTINCT FROM OLD.verified_at
     OR NEW.is_suspended     IS DISTINCT FROM OLD.is_suspended
     OR NEW.rejection_reason IS DISTINCT FROM OLD.rejection_reason
     OR NEW.suspended_at     IS DISTINCT FROM OLD.suspended_at
     OR NEW.suspended_reason IS DISTINCT FROM OLD.suspended_reason THEN
    RAISE EXCEPTION 'embassies : vérification et suspension se posent par les fonctions d''administration, pas par la fiche'
      USING ERRCODE = '42501';
  END IF;
  RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS embassies_garde_statut ON public.embassies;
CREATE TRIGGER embassies_garde_statut
  BEFORE INSERT OR UPDATE ON public.embassies
  FOR EACH ROW EXECUTE FUNCTION public.embassies_garde_statut();

-- ── 5. Droits ───────────────────────────────────────────────────────────────
REVOKE TRUNCATE, REFERENCES, TRIGGER ON public.embassies FROM PUBLIC, anon, authenticated;
DROP POLICY IF EXISTS embassies_delete_admin ON public.embassies;

-- ── 6. Les RPC ──────────────────────────────────────────────────────────────
DROP FUNCTION IF EXISTS public.embassy_admin_verify(uuid, text, text);

CREATE FUNCTION public.embassy_admin_verify(
  p_id         uuid,
  p_source_url text,
  p_source     text
) RETURNS text
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller text := (SELECT public.firebase_uid());
  e        public.embassies%ROWTYPE;
BEGIN
  IF v_caller IS NULL OR NOT public.is_admin() THEN
    RAISE EXCEPTION 'ambassade : réservé aux administrateurs' USING ERRCODE = '42501';
  END IF;
  PERFORM public.admin_require_permission('consular.embassies.verify');

  IF p_source_url IS NULL OR p_source_url !~ '^https://[^\s]{4,}$' THEN
    RAISE EXCEPTION 'ambassade : adresse de la source requise (https://…)' USING ERRCODE = '22023';
  END IF;
  IF p_source IS NULL OR length(btrim(p_source)) < 3 OR length(p_source) > 200 THEN
    RAISE EXCEPTION 'ambassade : éditeur de la source requis (3 à 200 caractères)' USING ERRCODE = '22023';
  END IF;

  SELECT * INTO e FROM public.embassies WHERE id = p_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'ambassade : introuvable' USING ERRCODE = 'P0002';
  END IF;
  IF e.is_verified THEN
    RAISE EXCEPTION 'ambassade : déjà vérifiée' USING ERRCODE = '55000';
  END IF;

  PERFORM set_config('app.embassy_rpc', 'on', true);
  PERFORM set_config('app.embassy_reason', btrim(p_source), true);
  UPDATE public.embassies SET
    is_verified = true, verified_at = now(), rejection_reason = NULL,
    source_url = p_source_url, source = btrim(p_source), source_checked_at = now()
   WHERE id = p_id;
  PERFORM set_config('app.embassy_rpc', 'off', true);
  PERFORM set_config('app.embassy_reason', '', true);

  PERFORM public.write_admin_audit(
    'EMBASSY_VERIFIED', 'embassy', p_id::text, 'success', NULL, p_id::text, '{}'::jsonb);
  RETURN 'verified';
END $$;

DROP FUNCTION IF EXISTS public.embassy_admin_reject(uuid, text);

CREATE FUNCTION public.embassy_admin_reject(p_id uuid, p_reason text) RETURNS text
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller text := (SELECT public.firebase_uid());
  e        public.embassies%ROWTYPE;
BEGIN
  IF v_caller IS NULL OR NOT public.is_admin() THEN
    RAISE EXCEPTION 'ambassade : réservé aux administrateurs' USING ERRCODE = '42501';
  END IF;
  PERFORM public.admin_require_permission('consular.embassies.verify');

  IF p_reason IS NULL OR length(btrim(p_reason)) < 5 OR length(p_reason) > 1000 THEN
    RAISE EXCEPTION 'ambassade : motif requis (5 à 1000 caractères)' USING ERRCODE = '22023';
  END IF;

  SELECT * INTO e FROM public.embassies WHERE id = p_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'ambassade : introuvable' USING ERRCODE = 'P0002';
  END IF;
  IF NOT e.is_verified AND e.rejection_reason IS NOT NULL THEN
    RAISE EXCEPTION 'ambassade : déjà refusée' USING ERRCODE = '55000';
  END IF;

  PERFORM set_config('app.embassy_rpc', 'on', true);
  PERFORM set_config('app.embassy_reason', btrim(p_reason), true);
  UPDATE public.embassies SET
    is_verified = false, verified_at = NULL, rejection_reason = btrim(p_reason)
   WHERE id = p_id;
  PERFORM set_config('app.embassy_rpc', 'off', true);
  PERFORM set_config('app.embassy_reason', '', true);

  PERFORM public.write_admin_audit(
    'EMBASSY_REJECTED', 'embassy', p_id::text, 'success', NULL, p_id::text,
    jsonb_build_object('was_verified', e.is_verified));
  RETURN 'rejected';
END $$;

DROP FUNCTION IF EXISTS public.embassy_admin_suspend(uuid, text);

CREATE FUNCTION public.embassy_admin_suspend(p_id uuid, p_reason text) RETURNS text
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller text := (SELECT public.firebase_uid());
  e        public.embassies%ROWTYPE;
BEGIN
  IF v_caller IS NULL OR NOT public.is_admin() THEN
    RAISE EXCEPTION 'ambassade : réservé aux administrateurs' USING ERRCODE = '42501';
  END IF;
  PERFORM public.admin_require_permission('consular.embassies.suspend');

  IF p_reason IS NULL OR length(btrim(p_reason)) < 5 OR length(p_reason) > 1000 THEN
    RAISE EXCEPTION 'ambassade : motif requis (5 à 1000 caractères)' USING ERRCODE = '22023';
  END IF;

  SELECT * INTO e FROM public.embassies WHERE id = p_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'ambassade : introuvable' USING ERRCODE = 'P0002';
  END IF;
  IF e.is_suspended THEN
    RAISE EXCEPTION 'ambassade : déjà suspendue' USING ERRCODE = '55000';
  END IF;

  PERFORM set_config('app.embassy_rpc', 'on', true);
  PERFORM set_config('app.embassy_reason', btrim(p_reason), true);
  UPDATE public.embassies SET
    is_suspended = true, suspended_at = now(), suspended_reason = btrim(p_reason)
   WHERE id = p_id;
  PERFORM set_config('app.embassy_rpc', 'off', true);
  PERFORM set_config('app.embassy_reason', '', true);

  PERFORM public.write_admin_audit(
    'EMBASSY_SUSPENDED', 'embassy', p_id::text, 'success', NULL, p_id::text, '{}'::jsonb);
  RETURN 'suspended';
END $$;

DROP FUNCTION IF EXISTS public.embassy_admin_unsuspend(uuid, text);

CREATE FUNCTION public.embassy_admin_unsuspend(p_id uuid, p_reason text) RETURNS text
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller text := (SELECT public.firebase_uid());
  e        public.embassies%ROWTYPE;
BEGIN
  IF v_caller IS NULL OR NOT public.is_admin() THEN
    RAISE EXCEPTION 'ambassade : réservé aux administrateurs' USING ERRCODE = '42501';
  END IF;
  PERFORM public.admin_require_permission('consular.embassies.suspend');

  IF p_reason IS NULL OR length(btrim(p_reason)) < 5 OR length(p_reason) > 1000 THEN
    RAISE EXCEPTION 'ambassade : motif requis (5 à 1000 caractères)' USING ERRCODE = '22023';
  END IF;

  SELECT * INTO e FROM public.embassies WHERE id = p_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'ambassade : introuvable' USING ERRCODE = 'P0002';
  END IF;
  IF NOT e.is_suspended THEN
    RAISE EXCEPTION 'ambassade : pas suspendue' USING ERRCODE = '55000';
  END IF;

  PERFORM set_config('app.embassy_rpc', 'on', true);
  PERFORM set_config('app.embassy_reason', btrim(p_reason), true);
  UPDATE public.embassies SET
    is_suspended = false, suspended_at = NULL, suspended_reason = NULL
   WHERE id = p_id;
  PERFORM set_config('app.embassy_rpc', 'off', true);
  PERFORM set_config('app.embassy_reason', '', true);

  PERFORM public.write_admin_audit(
    'EMBASSY_REACTIVATED', 'embassy', p_id::text, 'success', NULL, p_id::text, '{}'::jsonb);
  RETURN 'reactivated';
END $$;

-- ── 7. Droits d'exécution ───────────────────────────────────────────────────
REVOKE ALL ON FUNCTION public.embassy_admin_verify(uuid, text, text)     FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.embassy_admin_reject(uuid, text)           FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.embassy_admin_suspend(uuid, text)          FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.embassy_admin_unsuspend(uuid, text)        FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.embassy_admin_verify(uuid, text, text)  TO authenticated;
GRANT EXECUTE ON FUNCTION public.embassy_admin_reject(uuid, text)        TO authenticated;
GRANT EXECUTE ON FUNCTION public.embassy_admin_suspend(uuid, text)       TO authenticated;
GRANT EXECUTE ON FUNCTION public.embassy_admin_unsuspend(uuid, text)     TO authenticated;

NOTIFY pgrst, 'reload schema';
