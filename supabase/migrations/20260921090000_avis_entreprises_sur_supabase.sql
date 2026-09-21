-- Avis sur les entreprises : la table Supabase devient la seule source.
--
-- ═══ D'OÙ L'ON PART ═══════════════════════════════════════════════════════
--
-- Mesuré le 2026-09-21. L'app écrivait et lisait ses avis dans la collection
-- FIRESTORE `business_reviews` (`review_remote_datasource.dart`), alors que
-- les entreprises vivent dans `public.businesses` depuis le 2026-09-10 : la
-- note recalculée par `onReviewCreated` (functions/index.js) visait un
-- document Firestore `businesses/<id>` qui n'existe plus. La table
-- `public.business_reviews` existait, vide (0 ligne), RLS actif et AUCUNE
-- policy, avec tous les droits par défaut pour `anon` et `authenticated`.
-- Côté Firestore, la collection est à 0 document : rien à recopier.
--
-- La migration précédente (20260921083000) pose le déclencheur d'agrégat qui
-- tient `businesses.rating` / `review_count`. Celle-ci ouvre la table au
-- client, dans les limites de ce qu'il a le droit d'y faire.
--
-- ═══ QUI ÉCRIT QUOI ═══════════════════════════════════════════════════════
--
-- Un compte, sur SON avis : il le dépose, le retouche (note, titre, texte,
-- photos) et le retire. Les droits sont posés PAR COLONNE : le nouveau
-- datasource n'envoie que ces colonnes-là (il n'y a pas de client plus ancien
-- sur cette table, le piège de l'upsert qui renvoie toute la ligne ne se pose
-- pas). `status`, `helpful_*`, `owner_reply*` et l'identité affichée ne sont
-- donc jamais écrits par le client.
--
-- L'identité affichée (`user_display_name`, `user_photo_url`) est recopiée
-- de `users` par un déclencheur, pas fournie par le client : sinon n'importe
-- qui signait un avis au nom de n'importe qui.
--
-- Trois gestes touchent l'avis D'UN AUTRE, donc passent par des fonctions
-- SECURITY DEFINER qui ne font que ça :
--   · `avis_marquer_utile`  — ajoute ou retire SON uid de `helpful_by_user_ids`
--     (le compteur en est déduit, il ne peut plus dériver) ;
--   · `avis_repondre`       — la réponse du gérant, réservée au propriétaire
--     de la fiche. Elle passait par `updateReview`, c'est-à-dire par la
--     réécriture de l'avis d'autrui : les règles Firestore la refusaient déjà ;
--   · `avis_signaler`       — un signalement dans `public.reports`, que le
--     back-office lit déjà ; au troisième signalant distinct, l'avis passe
--     `flagged` et sort de la moyenne (règle reprise de l'ancien client).
--
-- Règles de fond, alignées sur ce que l'écran montre déjà : le propriétaire
-- ne note pas sa propre fiche (le bouton lui est masqué), on ne se trouve pas
-- « utile » soi-même, on ne signale pas son propre avis. Le serveur les tient
-- maintenant aussi.
--
-- ═══ CE QUI RESTE CÔTÉ FIREBASE ═══════════════════════════════════════════
--
-- La collection Firestore et les trois fonctions `onReview*` restent en place,
-- mortes : une version antérieure de l'app pourrait encore y écrire. Les
-- règles Firestore n'en sont pas modifiées ici.
--
-- Banc : tools/rls_tests/avis_entreprises_sur_supabase.sql

BEGIN;

-- ── Colonnes et bornes ─────────────────────────────────────────────────────
ALTER TABLE public.business_reviews
  ADD COLUMN IF NOT EXISTS owner_reply    text,
  ADD COLUMN IF NOT EXISTS owner_reply_at timestamptz;

-- Le formulaire limite à 3 photos et la réponse du gérant à 500 caractères ;
-- le serveur laisse une marge, mais pose une borne.
ALTER TABLE public.business_reviews
  DROP CONSTRAINT IF EXISTS business_reviews_bornes,
  ADD CONSTRAINT business_reviews_bornes CHECK (
        char_length(btrim(content)) BETWEEN 1 AND 5000
    AND (title IS NULL OR char_length(title) <= 200)
    AND cardinality(image_urls) <= 3
    AND (owner_reply IS NULL OR char_length(owner_reply) <= 1000)
  );

-- ── Droits : REVOKE d'abord, sinon le GRANT ne restreint rien ──────────────
REVOKE ALL ON public.business_reviews FROM anon, authenticated;

GRANT SELECT ON public.business_reviews TO authenticated;
GRANT INSERT (business_id, user_id, rating, title, content, image_urls)
  ON public.business_reviews TO authenticated;
GRANT UPDATE (rating, title, content, image_urls)
  ON public.business_reviews TO authenticated;
GRANT DELETE ON public.business_reviews TO authenticated;

-- ── Policies ───────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS business_reviews_lecture ON public.business_reviews;
DROP POLICY IF EXISTS business_reviews_depot   ON public.business_reviews;
DROP POLICY IF EXISTS business_reviews_retouche ON public.business_reviews;
DROP POLICY IF EXISTS business_reviews_retrait ON public.business_reviews;

-- Un avis signalé disparaît du public, pas de son auteur, du gérant de la
-- fiche ni du back-office.
CREATE POLICY business_reviews_lecture ON public.business_reviews
  FOR SELECT TO authenticated
  USING (
       status = 'published'
    OR user_id = (SELECT public.firebase_uid())
    OR (SELECT public.is_admin())
    OR EXISTS (SELECT 1 FROM public.businesses b
                WHERE b.id = business_id
                  AND b.owner_id = (SELECT public.firebase_uid()))
  );

CREATE POLICY business_reviews_depot ON public.business_reviews
  FOR INSERT TO authenticated
  WITH CHECK (
        user_id = (SELECT public.firebase_uid())
    AND EXISTS (SELECT 1 FROM public.businesses b
                 WHERE b.id = business_id
                   AND b.is_active
                   AND b.owner_id <> (SELECT public.firebase_uid()))
  );

CREATE POLICY business_reviews_retouche ON public.business_reviews
  FOR UPDATE TO authenticated
  USING      (user_id = (SELECT public.firebase_uid()))
  WITH CHECK (user_id = (SELECT public.firebase_uid()));

-- Le back-office supprime un avis signalé (`deleteReportedContent`).
CREATE POLICY business_reviews_retrait ON public.business_reviews
  FOR DELETE TO authenticated
  USING (user_id = (SELECT public.firebase_uid()) OR (SELECT public.is_admin()));

-- ── Identité affichée et horodatage, posés par le serveur ──────────────────
CREATE OR REPLACE FUNCTION public.business_reviews_identite()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_nom   text;
  v_photo text;
BEGIN
  IF TG_OP = 'INSERT' THEN
    SELECT u.display_name, u.avatar_url INTO v_nom, v_photo
      FROM public.users u WHERE u.id = NEW.user_id;
    NEW.user_display_name := coalesce(nullif(btrim(v_nom), ''), NEW.user_display_name, '');
    NEW.user_photo_url    := coalesce(v_photo, NEW.user_photo_url);
    NEW.created_at        := now();
    NEW.updated_at        := now();
    RETURN NEW;
  END IF;

  -- « Modifié le » ne bouge que si l'AUTEUR a changé son avis : un « utile »
  -- ou une réponse du gérant ne le rajeunit pas.
  IF NEW.rating     IS DISTINCT FROM OLD.rating
     OR NEW.title   IS DISTINCT FROM OLD.title
     OR NEW.content IS DISTINCT FROM OLD.content
     OR NEW.image_urls IS DISTINCT FROM OLD.image_urls THEN
    NEW.updated_at := now();
  END IF;
  RETURN NEW;
END $$;

REVOKE ALL ON FUNCTION public.business_reviews_identite() FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS business_reviews_identite ON public.business_reviews;
CREATE TRIGGER business_reviews_identite
  BEFORE INSERT OR UPDATE ON public.business_reviews
  FOR EACH ROW EXECUTE FUNCTION public.business_reviews_identite();

-- ── « Utile » ──────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.avis_marquer_utile(p_review_id uuid, p_utile boolean)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_uid    text := public.firebase_uid();
  v_nombre integer;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'avis : connexion requise' USING ERRCODE = '42501';
  END IF;

  -- Une seule instruction : l'expression est réévaluée sur la version
  -- verrouillée de la ligne, deux « utile » simultanés ne s'écrasent pas.
  UPDATE public.business_reviews r
     SET helpful_by_user_ids = CASE
           WHEN p_utile THEN
             CASE WHEN v_uid = ANY (r.helpful_by_user_ids) THEN r.helpful_by_user_ids
                  ELSE array_append(r.helpful_by_user_ids, v_uid) END
           ELSE array_remove(r.helpful_by_user_ids, v_uid) END,
         helpful_count = cardinality(CASE
           WHEN p_utile THEN
             CASE WHEN v_uid = ANY (r.helpful_by_user_ids) THEN r.helpful_by_user_ids
                  ELSE array_append(r.helpful_by_user_ids, v_uid) END
           ELSE array_remove(r.helpful_by_user_ids, v_uid) END)
   WHERE r.id = p_review_id
     AND r.status = 'published'
     AND r.user_id <> v_uid
  RETURNING r.helpful_count INTO v_nombre;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'avis : introuvable, non publié, ou le vôtre'
      USING ERRCODE = 'P0002';
  END IF;
  RETURN v_nombre;
END $$;

-- ── Réponse du gérant ──────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.avis_repondre(p_review_id uuid, p_reponse text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_uid     text := public.firebase_uid();
  v_reponse text := nullif(btrim(coalesce(p_reponse, '')), '');
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'avis : connexion requise' USING ERRCODE = '42501';
  END IF;

  UPDATE public.business_reviews r
     SET owner_reply    = v_reponse,
         owner_reply_at = CASE WHEN v_reponse IS NULL THEN NULL ELSE now() END
    FROM public.businesses b
   WHERE r.id = p_review_id
     AND b.id = r.business_id
     AND b.owner_id = v_uid;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'avis : seul le gérant de la fiche répond à ses avis'
      USING ERRCODE = '42501';
  END IF;
END $$;

-- ── Signalement ────────────────────────────────────────────────────────────
ALTER TABLE public.reports DROP CONSTRAINT IF EXISTS reports_target_type_check;
ALTER TABLE public.reports ADD CONSTRAINT reports_target_type_check CHECK (
  target_type = ANY (ARRAY['user', 'post', 'group', 'business', 'comment',
                           'audio_room', 'business_review']));

CREATE OR REPLACE FUNCTION public.avis_signaler(p_review_id uuid, p_motif text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_uid   text := public.firebase_uid();
  v_motif text := btrim(coalesce(p_motif, ''));
  v_avis  public.business_reviews%ROWTYPE;
  v_fiche text;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'avis : connexion requise' USING ERRCODE = '42501';
  END IF;
  IF char_length(v_motif) NOT BETWEEN 1 AND 1000 THEN
    RAISE EXCEPTION 'avis : motif vide ou trop long' USING ERRCODE = '22023';
  END IF;

  SELECT * INTO v_avis FROM public.business_reviews
   WHERE id = p_review_id AND status = 'published' AND user_id <> v_uid
   FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'avis : introuvable, non publié, ou le vôtre'
      USING ERRCODE = 'P0002';
  END IF;

  -- Un compte ne compte qu'une fois : resignaler ne pousse pas vers le seuil.
  IF NOT EXISTS (SELECT 1 FROM public.reports
                  WHERE target_type = 'business_review'
                    AND target_id = p_review_id::text
                    AND reporter_id = v_uid) THEN
    SELECT name INTO v_fiche FROM public.businesses WHERE id = v_avis.business_id;
    INSERT INTO public.reports (reporter_id, reporter_name, target_type, target_id,
                                target_name, reason, content_snapshot)
    VALUES (v_uid,
            (SELECT display_name FROM public.users WHERE id = v_uid),
            'business_review', p_review_id::text,
            coalesce(v_fiche, 'Entreprise'),
            v_motif,
            jsonb_build_object(
              'text',        v_avis.content,
              'contentType', 'business_review',
              'capturedAt',  now(),
              'metadata',    jsonb_build_object(
                               'business_id', v_avis.business_id,
                               'author_id',   v_avis.user_id,
                               'rating',      v_avis.rating,
                               'title',       v_avis.title)));
  END IF;

  IF (SELECT count(DISTINCT reporter_id) FROM public.reports
       WHERE target_type = 'business_review'
         AND target_id = p_review_id::text
         AND status IN ('pending', 'reviewing')) >= 3 THEN
    UPDATE public.business_reviews SET status = 'flagged' WHERE id = p_review_id;
  END IF;
END $$;

REVOKE ALL ON FUNCTION public.avis_marquer_utile(uuid, boolean) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.avis_repondre(uuid, text)         FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.avis_signaler(uuid, text)         FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.avis_marquer_utile(uuid, boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION public.avis_repondre(uuid, text)         TO authenticated;
GRANT EXECUTE ON FUNCTION public.avis_signaler(uuid, text)         TO authenticated;

COMMIT;
