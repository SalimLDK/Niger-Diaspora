-- Démarches consulaires : brouillon → relecture → approbation → publication.
--
-- Référentiel d'administration § 9 et spécification d'interfaces § 14.
--
-- ═══ CE QUI EXISTAIT ═══════════════════════════════════════════════════════
--
-- `demarches_consulaires` (20 lignes, lues par l'application via
-- `get_demarches_catalogue()`) était écrite par la policy `is_admin()` FOR ALL :
-- n'importe quel administrateur, même financeMod, pouvait réécrire une pièce,
-- un montant ou un renseignement de contact, en direct, sans relecture, sans
-- trace et sans version. La provenance était portée une seule fois, pour tout
-- le catalogue (`demarches_catalogue_meta`), jamais par démarche. Or l'usager
-- s'appuie dessus pour constituer un dossier.
--
-- ═══ CE QUE CETTE MIGRATION POSE ═══════════════════════════════════════════
--
-- • Par démarche : `source_url`, `source_publisher`, `verified_at`,
--   `next_review_at`, `version`, `publication_status`, `published_at/by`.
--   Les 20 démarches publiées héritent la provenance du catalogue
--   (diplomatie.gouv.ne, consultée le 2026-09-07). `next_review_at` reste NUL :
--   la périodicité de révision est une décision éditoriale, pas la mienne.
--   Une démarche ne peut pas être `published` sans source ni date de
--   vérification (CHECK).
-- • `demarches_brouillons` : le texte en cours de relecture. La démarche
--   publiée ne bouge pas tant qu'une publication n'a pas eu lieu.
-- • `demarches_versions` : un instantané à chaque publication et à chaque
--   dépublication (le texte, la source, qui, pourquoi). Ne se réécrit jamais.
-- • Sept RPC : enregistrer un brouillon, le soumettre, le retirer, l'approuver
--   ou le refuser, publier, dépublier. Chacune verrouille ses lignes, vérifie
--   permission et statut, et écrit l'audit dans la même transaction.
-- • Quatre permissions (`consular.view/procedures.edit/approve/publish`),
--   mappées à contentMod ; superAdmin a tout le catalogue.
-- • `demarches_consulaires` n'est plus écrite que par `demarche_publish` :
--   la policy d'écriture et les droits INSERT/UPDATE/DELETE sont retirés.
--   Aucun écrivain du dépôt n'y touchait (l'application ne fait que lire).
-- • La lecture publique ne montre que `published`. Un administrateur muni de
--   `consular.view` voit aussi les brouillons dépubliés.
--
-- ═══ RÈGLES ═════════════════════════════════════════════════════════════════
--
-- • Séparation : celui qui a rédigé ne peut pas approuver (42501), superAdmin
--   compris — la même règle que les recours.
-- • Conflit : un brouillon garde la version de base qu'il modifie ; si la
--   démarche a été publiée entre-temps, la publication est refusée (55000)
--   plutôt que d'écraser le travail d'un autre.
-- • Pas de texte libre dans l'audit.
--
-- ═══ CE QU'ELLE NE FAIT PAS ═════════════════════════════════════════════════
--
-- • Dépublier n'efface pas ce que l'application a déjà en cache, ni la copie
--   embarquée (assets/data/demarches_consulaires.json) : une démarche
--   dépubliée reste affichée sur un téléphone hors ligne jusqu'à sa prochaine
--   synchronisation. À corriger côté application, pas ici.
-- • L'application n'affiche pas encore la date de vérification de chaque
--   démarche (le RPC la fournit désormais : `verifieLe`, `sourceUrl`).
-- • Rubriques et métadonnées du catalogue gardent leur policy d'écriture
--   d'origine (tranche suivante).
-- • Annuaire (`businesses`) et événements (`events`) : autres tranches, leurs
--   modèles de propriété et de statut sont différents.
--
-- Banc : tools/rls_tests/demarches_workflow.sql.

SET lock_timeout = '5s';

-- ── 1. Provenance par démarche ──────────────────────────────────────────────
ALTER TABLE public.demarches_consulaires
  ADD COLUMN IF NOT EXISTS source_url         text,
  ADD COLUMN IF NOT EXISTS source_publisher   text,
  ADD COLUMN IF NOT EXISTS verified_at        timestamptz,
  ADD COLUMN IF NOT EXISTS next_review_at     timestamptz,
  ADD COLUMN IF NOT EXISTS version            integer NOT NULL DEFAULT 1,
  ADD COLUMN IF NOT EXISTS publication_status text NOT NULL DEFAULT 'published',
  ADD COLUMN IF NOT EXISTS published_at       timestamptz,
  ADD COLUMN IF NOT EXISTS published_by       text;

UPDATE public.demarches_consulaires d
   SET source_url       = COALESCE(d.source_url, m.url),
       source_publisher = COALESCE(d.source_publisher, m.editeur),
       verified_at      = COALESCE(d.verified_at, m.consulte_le::timestamptz),
       published_at     = COALESCE(d.published_at, d.updated_at)
  FROM public.demarches_catalogue_meta m
 WHERE d.publication_status = 'published';

ALTER TABLE public.demarches_consulaires
  DROP CONSTRAINT IF EXISTS demarches_consulaires_status_check,
  DROP CONSTRAINT IF EXISTS demarches_consulaires_source_requise;
ALTER TABLE public.demarches_consulaires
  ADD CONSTRAINT demarches_consulaires_status_check
    CHECK (publication_status IN ('published', 'unpublished')),
  ADD CONSTRAINT demarches_consulaires_source_requise
    CHECK (publication_status <> 'published'
           OR (source_url IS NOT NULL AND verified_at IS NOT NULL));

-- ── 2. Permissions ──────────────────────────────────────────────────────────
INSERT INTO public.admin_permissions (key, module, description, legacy_key) VALUES
  ('consular.view',                'consular', 'Voir les démarches consulaires (brouillons compris)', NULL),
  ('consular.procedures.edit',     'consular', 'Rédiger et soumettre une démarche',                   NULL),
  ('consular.procedures.approve',  'consular', 'Approuver ou refuser une démarche soumise',           NULL),
  ('consular.procedures.publish',  'consular', 'Publier ou dépublier une démarche',                   NULL)
ON CONFLICT (key) DO NOTHING;

INSERT INTO public.admin_role_permissions (role, permission) VALUES
  ('contentMod', 'consular.view'),
  ('contentMod', 'consular.procedures.edit'),
  ('contentMod', 'consular.procedures.approve'),
  ('contentMod', 'consular.procedures.publish')
ON CONFLICT DO NOTHING;

-- ── 3. Brouillons et versions ───────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.demarches_brouillons (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  demarche_id      text NOT NULL,
  base_version     integer NOT NULL DEFAULT 0,  -- 0 : nouvelle démarche
  payload          jsonb NOT NULL,
  source_url       text,
  source_publisher text,
  verified_at      timestamptz,
  next_review_at   timestamptz,
  change_reason    text,
  status           text NOT NULL DEFAULT 'draft'
                   CHECK (status IN ('draft', 'pending', 'approved', 'rejected',
                                     'published', 'withdrawn')),
  author_id        text NOT NULL,
  submitted_at     timestamptz,
  reviewer_id      text,
  reviewed_at      timestamptz,
  review_note      text,
  created_at       timestamptz NOT NULL DEFAULT now(),
  updated_at       timestamptz NOT NULL DEFAULT now()
);

-- Un seul brouillon vivant par démarche.
CREATE UNIQUE INDEX IF NOT EXISTS demarches_brouillons_vivant_uidx
  ON public.demarches_brouillons (demarche_id)
  WHERE status IN ('draft', 'pending', 'approved');

CREATE TABLE IF NOT EXISTS public.demarches_versions (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  demarche_id      text NOT NULL,
  version          integer NOT NULL,
  event            text NOT NULL CHECK (event IN ('published', 'unpublished')),
  snapshot         jsonb NOT NULL,
  source_url       text,
  verified_at      timestamptz,
  actor_id         text,
  reason           text,
  occurred_at      timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS demarches_versions_demarche_idx
  ON public.demarches_versions (demarche_id, occurred_at DESC);

-- La première version des 20 démarches déjà publiées.
INSERT INTO public.demarches_versions
  (demarche_id, version, event, snapshot, source_url, verified_at, actor_id, reason, occurred_at)
SELECT d.id, d.version, 'published',
       to_jsonb(d) - 'publication_status',
       d.source_url, d.verified_at, NULL, 'catalogue initial', COALESCE(d.published_at, now())
  FROM public.demarches_consulaires d
 WHERE NOT EXISTS (SELECT 1 FROM public.demarches_versions v WHERE v.demarche_id = d.id);

CREATE OR REPLACE FUNCTION public.demarches_versions_append_only()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public, pg_temp
AS $$
BEGIN
  RAISE EXCEPTION 'demarches_versions est en ajout seul (% refusé)', TG_OP
    USING ERRCODE = '42501';
END $$;

DROP TRIGGER IF EXISTS demarches_versions_no_rewrite ON public.demarches_versions;
CREATE TRIGGER demarches_versions_no_rewrite
  BEFORE UPDATE OR DELETE ON public.demarches_versions
  FOR EACH ROW EXECUTE FUNCTION public.demarches_versions_append_only();

-- ── 4. Droits et lecture ────────────────────────────────────────────────────
ALTER TABLE public.demarches_brouillons ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.demarches_versions   ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.demarches_brouillons FROM PUBLIC, anon, authenticated;
REVOKE ALL ON public.demarches_versions   FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.demarches_brouillons TO authenticated;
GRANT SELECT ON public.demarches_versions   TO authenticated;

DROP POLICY IF EXISTS demarches_brouillons_select ON public.demarches_brouillons;
CREATE POLICY demarches_brouillons_select ON public.demarches_brouillons
  FOR SELECT TO authenticated USING (public.admin_has_permission('consular.view'));
DROP POLICY IF EXISTS demarches_versions_select ON public.demarches_versions;
CREATE POLICY demarches_versions_select ON public.demarches_versions
  FOR SELECT TO authenticated USING (public.admin_has_permission('consular.view'));

-- La démarche : public = publiée ; consular.view = tout. Plus d'écriture
-- directe, pour personne.
DROP POLICY IF EXISTS demarches_consulaires_select ON public.demarches_consulaires;
DROP POLICY IF EXISTS demarches_consulaires_write  ON public.demarches_consulaires;
-- Deux policies, pas une avec un OR : `anon` n'a pas EXECUTE sur
-- `admin_has_permission`, et une policy qui l'évalue pour `anon` fait ÉCHOUER
-- toute lecture publique (42501) — le catalogue entier. Trouvé par le banc.
CREATE POLICY demarches_consulaires_select ON public.demarches_consulaires
  FOR SELECT TO anon, authenticated
  USING (publication_status = 'published');
DROP POLICY IF EXISTS demarches_consulaires_select_admin ON public.demarches_consulaires;
CREATE POLICY demarches_consulaires_select_admin ON public.demarches_consulaires
  FOR SELECT TO authenticated
  USING (public.admin_has_permission('consular.view'));
REVOKE INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER
  ON public.demarches_consulaires FROM PUBLIC, anon, authenticated;

-- ── 5. Contrôle du contenu d'un brouillon ───────────────────────────────────
DROP FUNCTION IF EXISTS public.demarche_payload_check(jsonb);

CREATE FUNCTION public.demarche_payload_check(p jsonb) RETURNS void
LANGUAGE plpgsql
STABLE
SET search_path = public, pg_temp
AS $$
DECLARE
  k       text;
  v_cles  text[] := ARRAY['titre', 'titre_source', 'rubrique', 'request_type', 'lieu',
    'exige_carte_consulaire', 'est_prerequis_de_tout_le_reste', 'resume', 'pieces',
    'pieces_conditionnelles', 'cout', 'delai', 'juridiction_competente',
    'avertissements', 'ordre'];
BEGIN
  IF p IS NULL OR jsonb_typeof(p) <> 'object' THEN
    RAISE EXCEPTION 'démarche : contenu invalide' USING ERRCODE = '22023';
  END IF;
  FOR k IN SELECT jsonb_object_keys(p) LOOP
    IF NOT (k = ANY (v_cles)) THEN
      RAISE EXCEPTION 'démarche : champ inconnu « % »', k USING ERRCODE = '22023';
    END IF;
  END LOOP;
  IF length(p::text) > 60000 THEN
    RAISE EXCEPTION 'démarche : contenu trop volumineux' USING ERRCODE = '22001';
  END IF;

  IF jsonb_typeof(p -> 'titre') IS DISTINCT FROM 'string'
     OR length(btrim(p ->> 'titre')) NOT BETWEEN 3 AND 200 THEN
    RAISE EXCEPTION 'démarche : titre requis (3 à 200 caractères)' USING ERRCODE = '22023';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.demarches_rubriques WHERE id = p ->> 'rubrique') THEN
    RAISE EXCEPTION 'démarche : rubrique inconnue' USING ERRCODE = '22023';
  END IF;
  IF jsonb_typeof(p -> 'request_type') IS DISTINCT FROM 'string'
     OR btrim(p ->> 'request_type') = '' THEN
    RAISE EXCEPTION 'démarche : type de demande requis' USING ERRCODE = '22023';
  END IF;
  IF jsonb_typeof(p -> 'cout') IS DISTINCT FROM 'object' THEN
    RAISE EXCEPTION 'démarche : coût requis (objet)' USING ERRCODE = '22023';
  END IF;
  FOREACH k IN ARRAY ARRAY['pieces', 'pieces_conditionnelles', 'avertissements'] LOOP
    IF p ? k AND jsonb_typeof(p -> k) <> 'array' THEN
      RAISE EXCEPTION 'démarche : « % » doit être une liste', k USING ERRCODE = '22023';
    END IF;
  END LOOP;
  IF p ? 'juridiction_competente'
     AND jsonb_typeof(p -> 'juridiction_competente') NOT IN ('object', 'null') THEN
    RAISE EXCEPTION 'démarche : juridiction invalide' USING ERRCODE = '22023';
  END IF;
  FOREACH k IN ARRAY ARRAY['exige_carte_consulaire', 'est_prerequis_de_tout_le_reste'] LOOP
    IF p ? k AND jsonb_typeof(p -> k) <> 'boolean' THEN
      RAISE EXCEPTION 'démarche : « % » doit être vrai ou faux', k USING ERRCODE = '22023';
    END IF;
  END LOOP;
  IF p ? 'ordre' AND jsonb_typeof(p -> 'ordre') <> 'number' THEN
    RAISE EXCEPTION 'démarche : ordre invalide' USING ERRCODE = '22023';
  END IF;
END $$;

REVOKE ALL ON FUNCTION public.demarche_payload_check(jsonb) FROM PUBLIC, anon, authenticated;

-- ── 6. Enregistrer un brouillon ─────────────────────────────────────────────
DROP FUNCTION IF EXISTS public.demarche_draft_save(text, jsonb, text, text, timestamptz, timestamptz, text);

CREATE FUNCTION public.demarche_draft_save(
  p_demarche_id      text,
  p_payload          jsonb,
  p_source_url       text,
  p_source_publisher text,
  p_verified_at      timestamptz,
  p_next_review_at   timestamptz,
  p_change_reason    text
) RETURNS uuid
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller text := (SELECT public.firebase_uid());
  live     public.demarches_consulaires%ROWTYPE;
  v_base   jsonb;
  v_full   jsonb;
  b        public.demarches_brouillons%ROWTYPE;
  v_id     uuid;
  v_a_brouillon boolean;
BEGIN
  IF v_caller IS NULL OR NOT public.is_admin() THEN
    RAISE EXCEPTION 'démarche : réservé aux administrateurs' USING ERRCODE = '42501';
  END IF;
  PERFORM public.admin_require_permission('consular.procedures.edit');

  IF p_demarche_id IS NULL OR p_demarche_id !~ '^[a-z0-9_]{3,64}$' THEN
    RAISE EXCEPTION 'démarche : identifiant invalide (minuscules, chiffres, _)' USING ERRCODE = '22023';
  END IF;
  IF p_source_url IS NOT NULL AND p_source_url !~ '^https://[^\s]{4,}$' THEN
    RAISE EXCEPTION 'démarche : l''adresse de la source doit commencer par https://' USING ERRCODE = '22023';
  END IF;
  IF p_verified_at IS NOT NULL AND p_verified_at > now() THEN
    RAISE EXCEPTION 'démarche : la date de vérification est dans le futur' USING ERRCODE = '22023';
  END IF;
  IF p_next_review_at IS NOT NULL
     AND p_next_review_at <= COALESCE(p_verified_at, now()) THEN
    RAISE EXCEPTION 'démarche : la révision doit suivre la vérification' USING ERRCODE = '22023';
  END IF;
  IF length(coalesce(p_change_reason, '')) > 1000 THEN
    RAISE EXCEPTION 'démarche : motif trop long (1000 max)' USING ERRCODE = '22001';
  END IF;

  SELECT * INTO live FROM public.demarches_consulaires WHERE id = p_demarche_id;
  IF FOUND THEN
    IF nullif(btrim(coalesce(p_change_reason, '')), '') IS NULL THEN
      -- Le motif peut déjà être porté par le brouillon en cours.
      PERFORM 1 FROM public.demarches_brouillons
        WHERE demarche_id = p_demarche_id AND status = 'draft'
          AND nullif(btrim(coalesce(change_reason, '')), '') IS NOT NULL;
      IF NOT FOUND THEN
        RAISE EXCEPTION 'démarche : motif de la modification requis' USING ERRCODE = '22023';
      END IF;
    END IF;
    -- L'état publié, restreint aux champs éditables.
    v_base := jsonb_build_object(
      'titre', live.titre, 'titre_source', live.titre_source, 'rubrique', live.rubrique,
      'request_type', live.request_type, 'lieu', live.lieu,
      'exige_carte_consulaire', live.exige_carte_consulaire,
      'est_prerequis_de_tout_le_reste', live.est_prerequis_de_tout_le_reste,
      'resume', live.resume, 'pieces', live.pieces,
      'pieces_conditionnelles', live.pieces_conditionnelles, 'cout', live.cout,
      'delai', live.delai, 'juridiction_competente', live.juridiction_competente,
      'avertissements', live.avertissements, 'ordre', live.ordre);
  ELSE
    v_base := '{}'::jsonb;
  END IF;

  -- Un brouillon déjà ouvert sert de base : on le complète, on ne repart pas
  -- de la version publiée (sinon chaque enregistrement partiel l'effacerait).
  SELECT * INTO b FROM public.demarches_brouillons
   WHERE demarche_id = p_demarche_id AND status IN ('draft', 'pending', 'approved')
   FOR UPDATE;
  v_a_brouillon := FOUND;
  IF v_a_brouillon THEN
    v_base := v_base || b.payload;
  END IF;
  v_full := v_base || coalesce(p_payload, '{}'::jsonb);
  PERFORM public.demarche_payload_check(v_full);

  IF v_a_brouillon THEN
    IF b.status <> 'draft' THEN
      RAISE EXCEPTION 'démarche : un brouillon est déjà % ; le retirer avant de le modifier', b.status
        USING ERRCODE = '55000';
    END IF;
    IF b.author_id <> v_caller AND NOT public.is_super_admin() THEN
      RAISE EXCEPTION 'démarche : brouillon d''un autre rédacteur' USING ERRCODE = '42501';
    END IF;
    UPDATE public.demarches_brouillons SET
      payload = v_full, source_url = p_source_url, source_publisher = p_source_publisher,
      verified_at = p_verified_at, next_review_at = p_next_review_at,
      change_reason = coalesce(nullif(btrim(p_change_reason), ''), b.change_reason),
      updated_at = now()
     WHERE id = b.id
     RETURNING id INTO v_id;
  ELSE
    INSERT INTO public.demarches_brouillons
      (demarche_id, base_version, payload, source_url, source_publisher,
       verified_at, next_review_at, change_reason, author_id)
    VALUES
      (p_demarche_id, CASE WHEN live.id IS NULL THEN 0 ELSE live.version END, v_full,
       p_source_url, p_source_publisher, p_verified_at, p_next_review_at,
       nullif(btrim(p_change_reason), ''), v_caller)
    RETURNING id INTO v_id;
  END IF;

  PERFORM public.write_admin_audit(
    'DEMARCHE_DRAFTED', 'demarche', p_demarche_id, 'success', NULL, p_demarche_id,
    jsonb_build_object('draft', v_id, 'is_new', live.id IS NULL));
  RETURN v_id;
END $$;

-- ── 7. Soumettre / retirer ──────────────────────────────────────────────────
DROP FUNCTION IF EXISTS public.demarche_submit(uuid);

CREATE FUNCTION public.demarche_submit(p_draft_id uuid) RETURNS text
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller text := (SELECT public.firebase_uid());
  b        public.demarches_brouillons%ROWTYPE;
BEGIN
  IF v_caller IS NULL OR NOT public.is_admin() THEN
    RAISE EXCEPTION 'démarche : réservé aux administrateurs' USING ERRCODE = '42501';
  END IF;
  PERFORM public.admin_require_permission('consular.procedures.edit');

  SELECT * INTO b FROM public.demarches_brouillons WHERE id = p_draft_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'démarche : brouillon introuvable' USING ERRCODE = 'P0002';
  END IF;
  IF b.status <> 'draft' THEN
    RAISE EXCEPTION 'démarche : soumission impossible depuis le statut %', b.status
      USING ERRCODE = '55000';
  END IF;
  IF b.author_id <> v_caller AND NOT public.is_super_admin() THEN
    RAISE EXCEPTION 'démarche : brouillon d''un autre rédacteur' USING ERRCODE = '42501';
  END IF;
  -- Aucune démarche publiée sans source documentée ni date de vérification.
  IF b.source_url IS NULL OR b.verified_at IS NULL
     OR nullif(btrim(coalesce(b.source_publisher, '')), '') IS NULL THEN
    RAISE EXCEPTION 'démarche : source (éditeur, adresse) et date de vérification requises'
      USING ERRCODE = '22023';
  END IF;
  PERFORM public.demarche_payload_check(b.payload);

  UPDATE public.demarches_brouillons
     SET status = 'pending', submitted_at = now(), updated_at = now()
   WHERE id = p_draft_id;

  PERFORM public.write_admin_audit(
    'DEMARCHE_SUBMITTED', 'demarche', b.demarche_id, 'success', NULL, b.demarche_id,
    jsonb_build_object('draft', p_draft_id));
  RETURN 'pending';
END $$;

DROP FUNCTION IF EXISTS public.demarche_withdraw(uuid);

CREATE FUNCTION public.demarche_withdraw(p_draft_id uuid) RETURNS text
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller text := (SELECT public.firebase_uid());
  b        public.demarches_brouillons%ROWTYPE;
BEGIN
  IF v_caller IS NULL OR NOT public.is_admin() THEN
    RAISE EXCEPTION 'démarche : réservé aux administrateurs' USING ERRCODE = '42501';
  END IF;
  PERFORM public.admin_require_permission('consular.procedures.edit');

  SELECT * INTO b FROM public.demarches_brouillons WHERE id = p_draft_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'démarche : brouillon introuvable' USING ERRCODE = 'P0002';
  END IF;
  IF b.status NOT IN ('draft', 'pending', 'approved') THEN
    RAISE EXCEPTION 'démarche : retrait impossible depuis le statut %', b.status
      USING ERRCODE = '55000';
  END IF;
  IF b.author_id <> v_caller AND NOT public.is_super_admin() THEN
    RAISE EXCEPTION 'démarche : brouillon d''un autre rédacteur' USING ERRCODE = '42501';
  END IF;

  UPDATE public.demarches_brouillons SET status = 'withdrawn', updated_at = now()
   WHERE id = p_draft_id;

  PERFORM public.write_admin_audit(
    'DEMARCHE_WITHDRAWN', 'demarche', b.demarche_id, 'success', NULL, b.demarche_id,
    jsonb_build_object('draft', p_draft_id, 'from', b.status));
  RETURN 'withdrawn';
END $$;

-- ── 8. Approuver ou refuser ─────────────────────────────────────────────────
DROP FUNCTION IF EXISTS public.demarche_review(uuid, text, text);

CREATE FUNCTION public.demarche_review(
  p_draft_id uuid,
  p_decision text,
  p_note     text DEFAULT NULL
) RETURNS text
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller text := (SELECT public.firebase_uid());
  b        public.demarches_brouillons%ROWTYPE;
  v_to     text;
BEGIN
  IF v_caller IS NULL OR NOT public.is_admin() THEN
    RAISE EXCEPTION 'démarche : réservé aux administrateurs' USING ERRCODE = '42501';
  END IF;
  PERFORM public.admin_require_permission('consular.procedures.approve');

  IF p_decision IS NULL OR p_decision NOT IN ('approve', 'reject') THEN
    RAISE EXCEPTION 'démarche : décision invalide (approve, reject)' USING ERRCODE = '22023';
  END IF;
  IF length(coalesce(p_note, '')) > 1000 THEN
    RAISE EXCEPTION 'démarche : note trop longue (1000 max)' USING ERRCODE = '22001';
  END IF;
  IF p_decision = 'reject' AND nullif(btrim(coalesce(p_note, '')), '') IS NULL THEN
    RAISE EXCEPTION 'démarche : un refus doit être motivé' USING ERRCODE = '22023';
  END IF;

  SELECT * INTO b FROM public.demarches_brouillons WHERE id = p_draft_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'démarche : brouillon introuvable' USING ERRCODE = 'P0002';
  END IF;
  IF b.status <> 'pending' THEN
    RAISE EXCEPTION 'démarche : relecture impossible depuis le statut %', b.status
      USING ERRCODE = '55000';
  END IF;
  -- Séparation auteur / approbateur : pas même le superAdmin.
  IF b.author_id = v_caller THEN
    RAISE EXCEPTION 'démarche : vous avez rédigé ce texte, un autre administrateur doit le relire'
      USING ERRCODE = '42501';
  END IF;

  v_to := CASE p_decision WHEN 'approve' THEN 'approved' ELSE 'rejected' END;
  UPDATE public.demarches_brouillons SET
    status = v_to, reviewer_id = v_caller, reviewed_at = now(),
    review_note = nullif(btrim(p_note), ''), updated_at = now()
   WHERE id = p_draft_id;

  PERFORM public.write_admin_audit(
    CASE p_decision WHEN 'approve' THEN 'DEMARCHE_APPROVED' ELSE 'DEMARCHE_REJECTED' END,
    'demarche', b.demarche_id, 'success', NULL, b.demarche_id,
    jsonb_build_object('draft', p_draft_id));
  RETURN v_to;
END $$;

-- ── 9. Publier ──────────────────────────────────────────────────────────────
DROP FUNCTION IF EXISTS public.demarche_publish(uuid);

CREATE FUNCTION public.demarche_publish(p_draft_id uuid) RETURNS integer
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller text := (SELECT public.firebase_uid());
  b        public.demarches_brouillons%ROWTYPE;
  live     public.demarches_consulaires%ROWTYPE;
  p        jsonb;
  v_ver    integer;
BEGIN
  IF v_caller IS NULL OR NOT public.is_admin() THEN
    RAISE EXCEPTION 'démarche : réservé aux administrateurs' USING ERRCODE = '42501';
  END IF;
  PERFORM public.admin_require_permission('consular.procedures.publish');

  SELECT * INTO b FROM public.demarches_brouillons WHERE id = p_draft_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'démarche : brouillon introuvable' USING ERRCODE = 'P0002';
  END IF;
  IF b.status <> 'approved' THEN
    RAISE EXCEPTION 'démarche : publication impossible depuis le statut %', b.status
      USING ERRCODE = '55000';
  END IF;

  SELECT * INTO live FROM public.demarches_consulaires WHERE id = b.demarche_id FOR UPDATE;
  IF (FOUND AND live.version <> b.base_version) OR (NOT FOUND AND b.base_version <> 0) THEN
    RAISE EXCEPTION 'démarche : le texte publié a changé depuis la rédaction (version % → %) ; refaire un brouillon',
      b.base_version, CASE WHEN FOUND THEN live.version ELSE 0 END
      USING ERRCODE = '55000';
  END IF;
  IF b.source_url IS NULL OR b.verified_at IS NULL THEN
    RAISE EXCEPTION 'démarche : source et date de vérification requises' USING ERRCODE = '22023';
  END IF;

  p := b.payload;
  PERFORM public.demarche_payload_check(p);
  v_ver := CASE WHEN live.id IS NULL THEN 1 ELSE live.version + 1 END;

  INSERT INTO public.demarches_consulaires
    (id, titre, titre_source, rubrique, request_type, lieu, exige_carte_consulaire,
     est_prerequis_de_tout_le_reste, resume, pieces, pieces_conditionnelles, cout,
     delai, juridiction_competente, avertissements, ordre, updated_at,
     source_url, source_publisher, verified_at, next_review_at, version,
     publication_status, published_at, published_by)
  VALUES
    (b.demarche_id, btrim(p ->> 'titre'), nullif(p ->> 'titre_source', ''), p ->> 'rubrique',
     p ->> 'request_type', coalesce(nullif(p ->> 'lieu', ''), 'consulat'),
     coalesce((p ->> 'exige_carte_consulaire')::boolean, false),
     coalesce((p ->> 'est_prerequis_de_tout_le_reste')::boolean, false),
     nullif(p ->> 'resume', ''), coalesce(p -> 'pieces', '[]'::jsonb),
     coalesce(p -> 'pieces_conditionnelles', '[]'::jsonb), p -> 'cout',
     nullif(p ->> 'delai', ''),
     CASE WHEN jsonb_typeof(p -> 'juridiction_competente') = 'object'
          THEN p -> 'juridiction_competente' END,
     coalesce(p -> 'avertissements', '[]'::jsonb),
     coalesce((p ->> 'ordre')::integer, 0), now(),
     b.source_url, b.source_publisher, b.verified_at, b.next_review_at, v_ver,
     'published', now(), v_caller)
  ON CONFLICT (id) DO UPDATE SET
    titre = EXCLUDED.titre, titre_source = EXCLUDED.titre_source,
    rubrique = EXCLUDED.rubrique, request_type = EXCLUDED.request_type,
    lieu = EXCLUDED.lieu, exige_carte_consulaire = EXCLUDED.exige_carte_consulaire,
    est_prerequis_de_tout_le_reste = EXCLUDED.est_prerequis_de_tout_le_reste,
    resume = EXCLUDED.resume, pieces = EXCLUDED.pieces,
    pieces_conditionnelles = EXCLUDED.pieces_conditionnelles, cout = EXCLUDED.cout,
    delai = EXCLUDED.delai, juridiction_competente = EXCLUDED.juridiction_competente,
    avertissements = EXCLUDED.avertissements, ordre = EXCLUDED.ordre,
    updated_at = now(), source_url = EXCLUDED.source_url,
    source_publisher = EXCLUDED.source_publisher, verified_at = EXCLUDED.verified_at,
    next_review_at = EXCLUDED.next_review_at, version = EXCLUDED.version,
    publication_status = 'published', published_at = now(), published_by = v_caller;

  INSERT INTO public.demarches_versions
    (demarche_id, version, event, snapshot, source_url, verified_at, actor_id, reason)
  SELECT d.id, d.version, 'published', to_jsonb(d) - 'publication_status',
         d.source_url, d.verified_at, v_caller, b.change_reason
    FROM public.demarches_consulaires d WHERE d.id = b.demarche_id;

  UPDATE public.demarches_brouillons SET status = 'published', updated_at = now()
   WHERE id = p_draft_id;
  -- L'application met son cache en rapport avec cette version.
  UPDATE public.demarches_catalogue_meta SET version = version + 1, updated_at = now();

  PERFORM public.write_admin_audit(
    'DEMARCHE_PUBLISHED', 'demarche', b.demarche_id, 'success', NULL, b.demarche_id,
    jsonb_build_object('draft', p_draft_id, 'version', v_ver, 'approved_by', b.reviewer_id));
  RETURN v_ver;
END $$;

-- ── 10. Dépublier ───────────────────────────────────────────────────────────
DROP FUNCTION IF EXISTS public.demarche_unpublish(text, text);

CREATE FUNCTION public.demarche_unpublish(p_demarche_id text, p_reason text) RETURNS text
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller text := (SELECT public.firebase_uid());
  live     public.demarches_consulaires%ROWTYPE;
BEGIN
  IF v_caller IS NULL OR NOT public.is_admin() THEN
    RAISE EXCEPTION 'démarche : réservé aux administrateurs' USING ERRCODE = '42501';
  END IF;
  PERFORM public.admin_require_permission('consular.procedures.publish');

  IF p_reason IS NULL OR length(btrim(p_reason)) < 5 OR length(p_reason) > 1000 THEN
    RAISE EXCEPTION 'démarche : motif de dépublication requis (5 à 1000 caractères)'
      USING ERRCODE = '22023';
  END IF;

  SELECT * INTO live FROM public.demarches_consulaires WHERE id = p_demarche_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'démarche : introuvable' USING ERRCODE = 'P0002';
  END IF;
  IF live.publication_status <> 'published' THEN
    RAISE EXCEPTION 'démarche : déjà dépubliée' USING ERRCODE = '55000';
  END IF;

  UPDATE public.demarches_consulaires
     SET publication_status = 'unpublished', updated_at = now()
   WHERE id = p_demarche_id;

  INSERT INTO public.demarches_versions
    (demarche_id, version, event, snapshot, source_url, verified_at, actor_id, reason)
  VALUES
    (p_demarche_id, live.version, 'unpublished', to_jsonb(live) - 'publication_status',
     live.source_url, live.verified_at, v_caller, btrim(p_reason));

  UPDATE public.demarches_catalogue_meta SET version = version + 1, updated_at = now();

  PERFORM public.write_admin_audit(
    'DEMARCHE_UNPUBLISHED', 'demarche', p_demarche_id, 'success', NULL, p_demarche_id,
    jsonb_build_object('version', live.version));
  RETURN 'unpublished';
END $$;

-- ── 11. Le catalogue public ne montre que ce qui est publié ─────────────────
CREATE OR REPLACE FUNCTION public.get_demarches_catalogue()
RETURNS jsonb
LANGUAGE sql
STABLE
SECURITY INVOKER
SET search_path = public
AS $fn$
  SELECT jsonb_build_object(
    'version', m.version,
    'source', jsonb_build_object(
      'editeur',    m.editeur,
      'url',        m.url,
      'consulteLe', m.consulte_le
    ),
    'rubriques', COALESCE((
      SELECT jsonb_agg(
        jsonb_build_object('id', r.id, 'titre', r.titre, 'ordre', r.ordre)
        ORDER BY r.ordre
      )
      FROM public.demarches_rubriques r
    ), '[]'::jsonb),
    'demarches', COALESCE((
      SELECT jsonb_agg(
        jsonb_strip_nulls(jsonb_build_object(
          'id',                          d.id,
          'titre',                       d.titre,
          'titreSource',                 d.titre_source,
          'rubrique',                    d.rubrique,
          'requestType',                 d.request_type,
          'lieu',                        d.lieu,
          'exigeCarteConsulaire',        d.exige_carte_consulaire,
          'estPrerequisDeToutLeReste',   d.est_prerequis_de_tout_le_reste,
          'resume',                      d.resume,
          'pieces',                      d.pieces,
          'piecesConditionnelles',       d.pieces_conditionnelles,
          'cout',                        d.cout,
          'delai',                       d.delai,
          'juridictionCompetente',       d.juridiction_competente,
          'avertissements',              d.avertissements,
          'sourceUrl',                   d.source_url,
          'verifieLe',                   d.verified_at
        ))
        ORDER BY d.ordre
      )
      FROM public.demarches_consulaires d
      WHERE d.publication_status = 'published'
    ), '[]'::jsonb)
  )
  FROM public.demarches_catalogue_meta m
  LIMIT 1;
$fn$;

-- ── 12. Droits d'exécution ──────────────────────────────────────────────────
REVOKE ALL ON FUNCTION public.demarche_draft_save(text, jsonb, text, text, timestamptz, timestamptz, text)
  FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.demarche_submit(uuid)            FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.demarche_withdraw(uuid)          FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.demarche_review(uuid, text, text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.demarche_publish(uuid)           FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.demarche_unpublish(text, text)   FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.demarche_draft_save(text, jsonb, text, text, timestamptz, timestamptz, text)
  TO authenticated;
GRANT EXECUTE ON FUNCTION public.demarche_submit(uuid)            TO authenticated;
GRANT EXECUTE ON FUNCTION public.demarche_withdraw(uuid)          TO authenticated;
GRANT EXECUTE ON FUNCTION public.demarche_review(uuid, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.demarche_publish(uuid)           TO authenticated;
GRANT EXECUTE ON FUNCTION public.demarche_unpublish(text, text)   TO authenticated;

NOTIFY pgrst, 'reload schema';
