-- Annuaire (fiches d'entreprises) : vérification motivée, archivage,
-- historique, et plus aucune écriture directe d'administrateur.
--
-- Référentiel d'administration § 7 et spécification d'interfaces § 12.
--
-- ═══ CE QUI EXISTAIT ═══════════════════════════════════════════════════════
--
-- • `businesses_update_owner` et `businesses_delete_owner` portaient
--   `OR is_admin()` : tout administrateur — financeMod compris — réécrivait ou
--   effaçait n'importe quelle fiche, sans motif, sans trace, et le déclencheur
--   `businesses_garde_privileges` lui laissait poser le badge « vérifié » et la
--   promotion payante par simple appartenance au rôle (`IF is_admin() THEN
--   RETURN NEW`).
-- • Le badge « vérifié » ne portait ni qui l'avait posé, ni sur quelle base,
--   ni quand. Le référentiel : « une fiche non vérifiée ne doit pas être
--   présentée comme officiellement certifiée » — et, a contrario, une fiche
--   vérifiée doit pouvoir dire d'où vient la vérification.
-- • Pas d'archivage : le seul retrait était la suppression définitive (les
--   avis, abonnés et vues partaient avec).
-- • Les données vivantes le montrent : 7 fiches, dont un nom vide, un nom
--   « 200000 », une ville « carte », un pays « Libya » pour Tahoua. Personne
--   n'a de geste pour retirer cela sans détruire.
--
-- ═══ CE QUE CETTE MIGRATION POSE ═══════════════════════════════════════════
--
-- • Colonnes de vérification et d'archivage : `verified_at`, `verified_by`,
--   `verification_source`, `next_review_at`, `archived_at`, `archived_reason`.
-- • `business_history` : un déclencheur consigne tout changement de nom, de
--   catégorie, de localisation, de badge, d'activité ou de promotion — par le
--   propriétaire comme par un administrateur — avec ancien / nouveau, auteur,
--   rôle et motif. Une suppression laisse un instantané. Ajout seul.
-- • Six RPC : vérifier (source obligatoire), retirer le badge, archiver,
--   restaurer, régler la promotion, supprimer. Motif ou source obligatoire,
--   audit dans la même transaction, statuts incohérents refusés (55000).
-- • `directory.listings.archive` (businessMod). Vérifier / retirer le badge :
--   `directory.listings.approve` ; promotion : `.boost` ; suppression :
--   `.delete` — les clés du catalogue, déjà portées par businessMod.
-- • Les policies d'écriture perdent leur `OR is_admin()`. Le déclencheur de
--   garde perd son exemption `is_admin()` : un administrateur qui écrirait
--   `is_verified` par PostgREST est refusé comme tout le monde ; seules les
--   RPC (SECURITY DEFINER, donc hors du filtre) posent le badge.
-- • Un propriétaire ne peut pas lever lui-même l'archivage de sa fiche.
-- • La lecture des fiches archivées par un administrateur passe par
--   `directory.listings.view`, plus par le seul drapeau admin.
--
-- ═══ CE QU'ELLE NE FAIT PAS ═════════════════════════════════════════════════
--
-- • Pas de détection de doublons (un index sur le nom normalisé et la ville
--   ferait échouer les créations existantes ; à décider avec l'équipe).
-- • Pas de validation du référentiel géographique : `country_code` porte des
--   noms en toutes lettres (« Niger », « Libya »), pas des codes ; la
--   normalisation est un chantier de données, pas de cette tranche.
-- • Pas de notification du propriétaire quand sa fiche est archivée ou perd
--   son badge : il le voit sur sa fiche (`archived_reason`), pas par push.
-- • Pas de file de relecture périodique : `next_review_at` est posé, rien ne
--   le lit encore.
--
-- Banc : tools/rls_tests/annuaire_moderation.sql.

SET lock_timeout = '5s';

-- ── 1. Colonnes ─────────────────────────────────────────────────────────────
ALTER TABLE public.businesses
  ADD COLUMN IF NOT EXISTS verified_at          timestamptz,
  ADD COLUMN IF NOT EXISTS verified_by          text,
  ADD COLUMN IF NOT EXISTS verification_source  text,
  ADD COLUMN IF NOT EXISTS next_review_at       timestamptz,
  ADD COLUMN IF NOT EXISTS archived_at          timestamptz,
  ADD COLUMN IF NOT EXISTS archived_reason      text;

-- ── 2. Permission ───────────────────────────────────────────────────────────
INSERT INTO public.admin_permissions (key, module, description, legacy_key) VALUES
  ('directory.listings.archive', 'directory', 'Archiver / restaurer une fiche (motif obligatoire)', NULL)
ON CONFLICT (key) DO NOTHING;
INSERT INTO public.admin_role_permissions (role, permission) VALUES
  ('businessMod', 'directory.listings.archive')
ON CONFLICT DO NOTHING;

-- ── 3. L'historique ─────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.business_history (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id   uuid NOT NULL,       -- pas de FK : l'historique survit à la suppression
  business_name text,
  kind          text NOT NULL CHECK (kind IN ('changed', 'deleted')),
  actor_id      text,
  actor_role    text NOT NULL CHECK (actor_role IN ('owner', 'admin', 'system')),
  changes       jsonb NOT NULL,
  reason        text,
  occurred_at   timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS business_history_business_idx
  ON public.business_history (business_id, occurred_at DESC);

ALTER TABLE public.business_history ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.business_history FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.business_history TO authenticated;
DROP POLICY IF EXISTS business_history_select ON public.business_history;
CREATE POLICY business_history_select ON public.business_history
  FOR SELECT TO authenticated
  USING (public.admin_has_permission('directory.listings.view'));

CREATE OR REPLACE FUNCTION public.business_history_append_only()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public, pg_temp
AS $$
BEGIN
  RAISE EXCEPTION 'business_history est en ajout seul (% refusé)', TG_OP
    USING ERRCODE = '42501';
END $$;

DROP TRIGGER IF EXISTS business_history_no_rewrite ON public.business_history;
CREATE TRIGGER business_history_no_rewrite
  BEFORE UPDATE OR DELETE ON public.business_history
  FOR EACH ROW EXECUTE FUNCTION public.business_history_append_only();

CREATE OR REPLACE FUNCTION public.businesses_record_history()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_uid     text := (SELECT public.firebase_uid());
  v_role    text;
  v_changes jsonb := '{}'::jsonb;
  v_reason  text := nullif(current_setting('app.business_reason', true), '');
  c         text;
  v_old     jsonb;
  v_new     jsonb;
  v_suivies constant text[] := ARRAY['name', 'category', 'country_code', 'city',
    'address', 'is_verified', 'verification_source', 'is_active', 'archived_at',
    'is_boosted', 'boost_expires_at'];
BEGIN
  v_role := CASE
    WHEN current_setting('app.business_rpc', true) = 'on' THEN 'admin'
    WHEN v_uid IS NULL THEN 'system'
    WHEN v_uid = OLD.owner_id THEN 'owner'
    ELSE 'admin' END;

  IF TG_OP = 'DELETE' THEN
    INSERT INTO public.business_history (business_id, business_name, kind, actor_id, actor_role, changes, reason)
    VALUES (OLD.id, OLD.name, 'deleted', v_uid, v_role,
            jsonb_build_object('name', OLD.name, 'owner_id', OLD.owner_id,
                               'category', OLD.category, 'city', OLD.city,
                               'is_verified', OLD.is_verified),
            v_reason);
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
    INSERT INTO public.business_history (business_id, business_name, kind, actor_id, actor_role, changes, reason)
    VALUES (NEW.id, NEW.name, 'changed', v_uid, v_role, v_changes, v_reason);
  END IF;
  RETURN NEW;
END $$;

REVOKE ALL ON FUNCTION public.businesses_record_history() FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS trg_businesses_record_history_upd ON public.businesses;
CREATE TRIGGER trg_businesses_record_history_upd
  AFTER UPDATE ON public.businesses
  FOR EACH ROW EXECUTE FUNCTION public.businesses_record_history();
DROP TRIGGER IF EXISTS trg_businesses_record_history_del ON public.businesses;
CREATE TRIGGER trg_businesses_record_history_del
  BEFORE DELETE ON public.businesses
  FOR EACH ROW EXECUTE FUNCTION public.businesses_record_history();

-- ── 4. Le déclencheur de garde : plus d'exemption « admin » ─────────────────
-- Corps de 20260921071500, moins `IF is_admin() THEN RETURN NEW`, plus les
-- colonnes de vérification et d'archivage. Les chemins de confiance
-- (`current_user NOT IN ('authenticated','anon')` : migrations, déclencheurs,
-- fonctions SECURITY DEFINER, service_role) passent toujours.
CREATE OR REPLACE FUNCTION public.businesses_garde_privileges()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public, pg_temp
AS $$
BEGIN
  IF current_user NOT IN ('authenticated', 'anon') THEN
    RETURN NEW;
  END IF;

  IF TG_OP = 'INSERT' THEN
    IF coalesce(NEW.is_verified, false)
       OR coalesce(NEW.is_boosted, false)
       OR NEW.boost_expires_at IS NOT NULL
       OR NEW.verified_at IS NOT NULL OR NEW.verified_by IS NOT NULL
       OR NEW.verification_source IS NOT NULL OR NEW.next_review_at IS NOT NULL
       OR NEW.archived_at IS NOT NULL OR NEW.archived_reason IS NOT NULL THEN
      RAISE EXCEPTION
        'businesses : une fiche ne naît ni vérifiée, ni promue, ni archivée'
        USING ERRCODE = '42501';
    END IF;
    RETURN NEW;
  END IF;

  -- On compare les VALEURS, pas les colonnes écrites : `updateBusiness`
  -- renvoie toute la ligne, donc une réécriture à l'identique doit passer.
  IF NEW.is_verified      IS DISTINCT FROM OLD.is_verified
     OR NEW.is_boosted       IS DISTINCT FROM OLD.is_boosted
     OR NEW.boost_expires_at IS DISTINCT FROM OLD.boost_expires_at
     OR NEW.verified_at         IS DISTINCT FROM OLD.verified_at
     OR NEW.verified_by         IS DISTINCT FROM OLD.verified_by
     OR NEW.verification_source IS DISTINCT FROM OLD.verification_source
     OR NEW.next_review_at      IS DISTINCT FROM OLD.next_review_at
     OR NEW.archived_at         IS DISTINCT FROM OLD.archived_at
     OR NEW.archived_reason     IS DISTINCT FROM OLD.archived_reason
  THEN
    RAISE EXCEPTION
      'businesses : badge, promotion, vérification et archivage sont posés par le serveur, pas par la fiche'
      USING ERRCODE = '42501';
  END IF;

  -- Une fiche archivée par l'administration ne se réactive pas d'elle-même.
  IF OLD.archived_at IS NOT NULL AND NEW.is_active IS DISTINCT FROM OLD.is_active THEN
    RAISE EXCEPTION 'businesses : fiche archivée, seule l''administration la restaure'
      USING ERRCODE = '42501';
  END IF;

  IF NEW.rating           IS DISTINCT FROM OLD.rating
     OR NEW.review_count    IS DISTINCT FROM OLD.review_count
     OR NEW.follower_count  IS DISTINCT FROM OLD.follower_count
     OR NEW.view_count      IS DISTINCT FROM OLD.view_count
  THEN
    RAISE EXCEPTION
      'businesses : note, avis, abonnés et vues sont des agrégats, pas des champs'
      USING ERRCODE = '42501';
  END IF;

  RETURN NEW;
END $$;

-- ── 5. Policies : le propriétaire écrit, l'administrateur lit ───────────────
DROP POLICY IF EXISTS businesses_select_active ON public.businesses;
CREATE POLICY businesses_select_active ON public.businesses
  FOR SELECT TO authenticated
  USING (is_active = true
         OR (SELECT public.firebase_uid()) = owner_id
         OR public.admin_has_permission('directory.listings.view'));

DROP POLICY IF EXISTS businesses_update_owner ON public.businesses;
CREATE POLICY businesses_update_owner ON public.businesses
  FOR UPDATE TO authenticated
  USING ((SELECT public.firebase_uid()) = owner_id);

DROP POLICY IF EXISTS businesses_delete_owner ON public.businesses;
CREATE POLICY businesses_delete_owner ON public.businesses
  FOR DELETE TO authenticated
  USING ((SELECT public.firebase_uid()) = owner_id);

-- ── 6. Les RPC ──────────────────────────────────────────────────────────────
-- Gabarit commun : administrateur + permission + verrou de ligne.
DROP FUNCTION IF EXISTS public.business_admin_verify(uuid, text, timestamptz);

CREATE FUNCTION public.business_admin_verify(
  p_id          uuid,
  p_source      text,
  p_next_review timestamptz DEFAULT NULL
) RETURNS text
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller text := (SELECT public.firebase_uid());
  b        public.businesses%ROWTYPE;
BEGIN
  IF v_caller IS NULL OR NOT public.is_admin() THEN
    RAISE EXCEPTION 'fiche : réservé aux administrateurs' USING ERRCODE = '42501';
  END IF;
  PERFORM public.admin_require_permission('directory.listings.approve');

  IF p_source IS NULL OR length(btrim(p_source)) < 5 OR length(p_source) > 500 THEN
    RAISE EXCEPTION 'fiche : base de la vérification requise (5 à 500 caractères)'
      USING ERRCODE = '22023';
  END IF;
  IF p_next_review IS NOT NULL AND p_next_review <= now() THEN
    RAISE EXCEPTION 'fiche : la prochaine révision doit être dans le futur' USING ERRCODE = '22023';
  END IF;

  SELECT * INTO b FROM public.businesses WHERE id = p_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'fiche : introuvable' USING ERRCODE = 'P0002';
  END IF;
  IF b.archived_at IS NOT NULL OR NOT b.is_active THEN
    RAISE EXCEPTION 'fiche : une fiche archivée ou inactive ne se vérifie pas' USING ERRCODE = '55000';
  END IF;
  IF b.is_verified THEN
    RAISE EXCEPTION 'fiche : déjà vérifiée' USING ERRCODE = '55000';
  END IF;

  PERFORM set_config('app.business_rpc', 'on', true);
  PERFORM set_config('app.business_reason', btrim(p_source), true);
  UPDATE public.businesses SET
    is_verified = true, verified_at = now(), verified_by = v_caller,
    verification_source = btrim(p_source), next_review_at = p_next_review
   WHERE id = p_id;
  PERFORM set_config('app.business_rpc', 'off', true);
  PERFORM set_config('app.business_reason', '', true);

  PERFORM public.write_admin_audit(
    'LISTING_VERIFIED', 'business', p_id::text, 'success', NULL, p_id::text,
    jsonb_build_object('next_review', p_next_review));
  RETURN 'verified';
END $$;

DROP FUNCTION IF EXISTS public.business_admin_unverify(uuid, text);

CREATE FUNCTION public.business_admin_unverify(p_id uuid, p_reason text) RETURNS text
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller text := (SELECT public.firebase_uid());
  b        public.businesses%ROWTYPE;
BEGIN
  IF v_caller IS NULL OR NOT public.is_admin() THEN
    RAISE EXCEPTION 'fiche : réservé aux administrateurs' USING ERRCODE = '42501';
  END IF;
  PERFORM public.admin_require_permission('directory.listings.approve');

  IF p_reason IS NULL OR length(btrim(p_reason)) < 5 OR length(p_reason) > 1000 THEN
    RAISE EXCEPTION 'fiche : motif requis (5 à 1000 caractères)' USING ERRCODE = '22023';
  END IF;

  SELECT * INTO b FROM public.businesses WHERE id = p_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'fiche : introuvable' USING ERRCODE = 'P0002';
  END IF;
  IF NOT b.is_verified THEN
    RAISE EXCEPTION 'fiche : pas vérifiée' USING ERRCODE = '55000';
  END IF;

  PERFORM set_config('app.business_rpc', 'on', true);
  PERFORM set_config('app.business_reason', btrim(p_reason), true);
  UPDATE public.businesses SET
    is_verified = false, verified_at = NULL, verified_by = NULL,
    verification_source = NULL, next_review_at = NULL
   WHERE id = p_id;
  PERFORM set_config('app.business_rpc', 'off', true);
  PERFORM set_config('app.business_reason', '', true);

  PERFORM public.write_admin_audit(
    'LISTING_UNVERIFIED', 'business', p_id::text, 'success', NULL, p_id::text,
    jsonb_build_object('verified_by', b.verified_by));
  RETURN 'unverified';
END $$;

DROP FUNCTION IF EXISTS public.business_admin_archive(uuid, text);

CREATE FUNCTION public.business_admin_archive(p_id uuid, p_reason text) RETURNS text
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller text := (SELECT public.firebase_uid());
  b        public.businesses%ROWTYPE;
BEGIN
  IF v_caller IS NULL OR NOT public.is_admin() THEN
    RAISE EXCEPTION 'fiche : réservé aux administrateurs' USING ERRCODE = '42501';
  END IF;
  PERFORM public.admin_require_permission('directory.listings.archive');

  IF p_reason IS NULL OR length(btrim(p_reason)) < 5 OR length(p_reason) > 1000 THEN
    RAISE EXCEPTION 'fiche : motif requis (5 à 1000 caractères)' USING ERRCODE = '22023';
  END IF;

  SELECT * INTO b FROM public.businesses WHERE id = p_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'fiche : introuvable' USING ERRCODE = 'P0002';
  END IF;
  IF b.archived_at IS NOT NULL THEN
    RAISE EXCEPTION 'fiche : déjà archivée' USING ERRCODE = '55000';
  END IF;

  -- Une fiche retirée du public ne reste ni « vérifiée » ni « promue ».
  PERFORM set_config('app.business_rpc', 'on', true);
  PERFORM set_config('app.business_reason', btrim(p_reason), true);
  UPDATE public.businesses SET
    is_active = false, archived_at = now(), archived_reason = btrim(p_reason),
    is_boosted = false, boost_expires_at = NULL
   WHERE id = p_id;
  PERFORM set_config('app.business_rpc', 'off', true);
  PERFORM set_config('app.business_reason', '', true);

  PERFORM public.write_admin_audit(
    'LISTING_ARCHIVED', 'business', p_id::text, 'success', NULL, p_id::text,
    jsonb_build_object('was_boosted', b.is_boosted, 'was_verified', b.is_verified));
  RETURN 'archived';
END $$;

DROP FUNCTION IF EXISTS public.business_admin_restore(uuid, text);

CREATE FUNCTION public.business_admin_restore(p_id uuid, p_reason text) RETURNS text
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller text := (SELECT public.firebase_uid());
  b        public.businesses%ROWTYPE;
BEGIN
  IF v_caller IS NULL OR NOT public.is_admin() THEN
    RAISE EXCEPTION 'fiche : réservé aux administrateurs' USING ERRCODE = '42501';
  END IF;
  PERFORM public.admin_require_permission('directory.listings.archive');

  IF p_reason IS NULL OR length(btrim(p_reason)) < 5 OR length(p_reason) > 1000 THEN
    RAISE EXCEPTION 'fiche : motif requis (5 à 1000 caractères)' USING ERRCODE = '22023';
  END IF;

  SELECT * INTO b FROM public.businesses WHERE id = p_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'fiche : introuvable' USING ERRCODE = 'P0002';
  END IF;
  IF b.archived_at IS NULL THEN
    RAISE EXCEPTION 'fiche : pas archivée' USING ERRCODE = '55000';
  END IF;

  PERFORM set_config('app.business_rpc', 'on', true);
  PERFORM set_config('app.business_reason', btrim(p_reason), true);
  UPDATE public.businesses SET
    is_active = true, archived_at = NULL, archived_reason = NULL
   WHERE id = p_id;
  PERFORM set_config('app.business_rpc', 'off', true);
  PERFORM set_config('app.business_reason', '', true);

  PERFORM public.write_admin_audit(
    'LISTING_RESTORED', 'business', p_id::text, 'success', NULL, p_id::text, '{}'::jsonb);
  RETURN 'restored';
END $$;

DROP FUNCTION IF EXISTS public.business_admin_set_boost(uuid, boolean, integer, text);

CREATE FUNCTION public.business_admin_set_boost(
  p_id      uuid,
  p_boosted boolean,
  p_days    integer,
  p_reason  text
) RETURNS text
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller text := (SELECT public.firebase_uid());
  b        public.businesses%ROWTYPE;
BEGIN
  IF v_caller IS NULL OR NOT public.is_admin() THEN
    RAISE EXCEPTION 'fiche : réservé aux administrateurs' USING ERRCODE = '42501';
  END IF;
  PERFORM public.admin_require_permission('directory.listings.boost');

  IF p_boosted IS NULL THEN
    RAISE EXCEPTION 'fiche : état de promotion requis' USING ERRCODE = '22023';
  END IF;
  IF p_reason IS NULL OR length(btrim(p_reason)) < 5 OR length(p_reason) > 1000 THEN
    RAISE EXCEPTION 'fiche : motif requis (5 à 1000 caractères)' USING ERRCODE = '22023';
  END IF;
  IF p_boosted AND (p_days IS NULL OR p_days < 1 OR p_days > 365) THEN
    RAISE EXCEPTION 'fiche : durée de promotion requise (1 à 365 jours)' USING ERRCODE = '22023';
  END IF;

  SELECT * INTO b FROM public.businesses WHERE id = p_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'fiche : introuvable' USING ERRCODE = 'P0002';
  END IF;
  IF p_boosted AND (b.archived_at IS NOT NULL OR NOT b.is_active) THEN
    RAISE EXCEPTION 'fiche : une fiche archivée ou inactive ne se promeut pas' USING ERRCODE = '55000';
  END IF;
  IF p_boosted = coalesce(b.is_boosted, false) AND NOT p_boosted THEN
    RAISE EXCEPTION 'fiche : pas promue' USING ERRCODE = '55000';
  END IF;

  PERFORM set_config('app.business_rpc', 'on', true);
  PERFORM set_config('app.business_reason', btrim(p_reason), true);
  UPDATE public.businesses SET
    is_boosted = p_boosted,
    boost_expires_at = CASE WHEN p_boosted THEN now() + make_interval(days => p_days) END
   WHERE id = p_id;
  PERFORM set_config('app.business_rpc', 'off', true);
  PERFORM set_config('app.business_reason', '', true);

  PERFORM public.write_admin_audit(
    'LISTING_BOOST_CHANGED', 'business', p_id::text, 'success', NULL, p_id::text,
    jsonb_build_object('boosted', p_boosted, 'days', p_days));
  RETURN CASE WHEN p_boosted THEN 'boosted' ELSE 'unboosted' END;
END $$;

DROP FUNCTION IF EXISTS public.business_admin_delete(uuid, text);

CREATE FUNCTION public.business_admin_delete(p_id uuid, p_reason text) RETURNS text
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller text := (SELECT public.firebase_uid());
  b        public.businesses%ROWTYPE;
BEGIN
  IF v_caller IS NULL OR NOT public.is_admin() THEN
    RAISE EXCEPTION 'fiche : réservé aux administrateurs' USING ERRCODE = '42501';
  END IF;
  PERFORM public.admin_require_permission('directory.listings.delete');

  IF p_reason IS NULL OR length(btrim(p_reason)) < 5 OR length(p_reason) > 1000 THEN
    RAISE EXCEPTION 'fiche : motif requis (5 à 1000 caractères)' USING ERRCODE = '22023';
  END IF;

  SELECT * INTO b FROM public.businesses WHERE id = p_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'fiche : introuvable' USING ERRCODE = 'P0002';
  END IF;

  PERFORM set_config('app.business_rpc', 'on', true);
  PERFORM set_config('app.business_reason', btrim(p_reason), true);
  DELETE FROM public.businesses WHERE id = p_id;
  PERFORM set_config('app.business_rpc', 'off', true);
  PERFORM set_config('app.business_reason', '', true);

  PERFORM public.write_admin_audit(
    'LISTING_DELETED', 'business', p_id::text, 'success', NULL, p_id::text,
    jsonb_build_object('was_verified', b.is_verified, 'was_boosted', b.is_boosted));
  RETURN 'deleted';
END $$;

-- ── 7. Droits d'exécution ───────────────────────────────────────────────────
REVOKE ALL ON FUNCTION public.business_admin_verify(uuid, text, timestamptz)       FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.business_admin_unverify(uuid, text)                  FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.business_admin_archive(uuid, text)                   FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.business_admin_restore(uuid, text)                   FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.business_admin_set_boost(uuid, boolean, integer, text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.business_admin_delete(uuid, text)                    FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.business_admin_verify(uuid, text, timestamptz)       TO authenticated;
GRANT EXECUTE ON FUNCTION public.business_admin_unverify(uuid, text)                  TO authenticated;
GRANT EXECUTE ON FUNCTION public.business_admin_archive(uuid, text)                   TO authenticated;
GRANT EXECUTE ON FUNCTION public.business_admin_restore(uuid, text)                   TO authenticated;
GRANT EXECUTE ON FUNCTION public.business_admin_set_boost(uuid, boolean, integer, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.business_admin_delete(uuid, text)                    TO authenticated;

NOTIFY pgrst, 'reload schema';
