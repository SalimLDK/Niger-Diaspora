-- Signalements : une seule source, Supabase `public.reports`.
--
-- Le panneau admin lisait `public.reports`, mais l'app écrivait les
-- signalements dans Firestore (`reports`) : l'administrateur ne voyait pas un
-- signalement d'utilisateur. Cette migration prépare la table à les recevoir ;
-- le client les y écrit par `signalement_creer` (lecture : policies existantes).
--
-- Trois défauts de la table vivante, relevés le 2026-10-15 (0 ligne) :
--
-- 1. `reports_target_type_check` refusait `message`, `conversation`, `event`
--    et `product` — quatre des sept cibles que l'app sait signaler.
-- 2. `reports_update_admin` (initial_schema) n'existe pas en production : seules
--    les policies INSERT et SELECT y sont. Sous RLS sans policy UPDATE, la
--    résolution d'un signalement touchait zéro ligne.
-- 3. `authenticated` portait INSERT/UPDATE/DELETE sur toutes les colonnes, et
--    la policy d'insertion ne regarde que `reporter_id` : un signalant pouvait
--    se déposer un signalement déjà « resolved », signé d'un autre
--    `reviewed_by`. Un GRANT n'enlève rien : REVOKE d'abord.
--
-- `reported_user_id` est `uuid` alors que les identifiants sont des uid
-- Firebase (texte) : tout signalement d'utilisateur y aurait échoué en 22P02.

-- ── 1. Colonne, cibles acceptées, un signalement par signalant et cible ───
ALTER TABLE public.reports
  ALTER COLUMN reported_user_id TYPE text USING reported_user_id::text;

ALTER TABLE public.reports DROP CONSTRAINT IF EXISTS reports_target_type_check;
ALTER TABLE public.reports ADD CONSTRAINT reports_target_type_check CHECK (
  target_type = ANY (ARRAY['user', 'post', 'group', 'business', 'comment',
                           'audio_room', 'business_review', 'message',
                           'conversation', 'event', 'product']));

CREATE UNIQUE INDEX IF NOT EXISTS reports_un_par_signalant_et_cible
  ON public.reports (reporter_id, target_type, target_id);

-- ── 2. Droits : le client ne dépose plus, il appelle la fonction ──────────
REVOKE ALL ON public.reports FROM anon, authenticated;
GRANT SELECT ON public.reports TO authenticated;
-- L'administrateur traite un signalement : ces six colonnes, pas une de plus.
GRANT UPDATE (status, admin_note, action_taken, reviewed_by, reviewed_at,
              reported_user_notified)
  ON public.reports TO authenticated;

DROP POLICY IF EXISTS "reports_insert_own" ON public.reports;
DROP POLICY IF EXISTS "reports_update_admin" ON public.reports;
CREATE POLICY "reports_update_admin" ON public.reports
  FOR UPDATE TO authenticated
  USING (is_admin()) WITH CHECK (is_admin());

-- ── 3. Le dépôt ────────────────────────────────────────────────────────────
DROP FUNCTION IF EXISTS public.signalement_creer(text, text, text, text, text, text, text, jsonb);

CREATE FUNCTION public.signalement_creer(
  p_target_type      text,
  p_target_id        text,
  p_reason           text,
  p_description      text  DEFAULT NULL,
  p_conversation_id  text  DEFAULT NULL,
  p_reported_user_id text  DEFAULT NULL,
  p_target_name      text  DEFAULT NULL,
  p_snapshot         jsonb DEFAULT NULL
) RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_uid  text := public.firebase_uid();
  v_nom  text;
  v_id   uuid;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'signalement : connexion requise' USING ERRCODE = '42501';
  END IF;

  IF nullif(btrim(p_target_id), '') IS NULL
     OR nullif(btrim(p_reason), '') IS NULL THEN
    RAISE EXCEPTION 'signalement : cible et motif requis' USING ERRCODE = '22023';
  END IF;

  IF length(coalesce(p_description, '')) > 2000
     OR length(p_reason) > 100
     OR length(coalesce(p_snapshot::text, '')) > 20000 THEN
    RAISE EXCEPTION 'signalement : contenu trop long' USING ERRCODE = '22001';
  END IF;

  -- On ne se signale pas soi-même.
  IF p_target_type = 'user' AND p_target_id = v_uid THEN
    RAISE EXCEPTION 'signalement : impossible de se signaler' USING ERRCODE = '22023';
  END IF;

  -- Le nom du signalant vient de la base, jamais du client.
  SELECT display_name INTO v_nom FROM public.users WHERE id = v_uid;

  BEGIN
    INSERT INTO public.reports
      (reporter_id, reporter_name, target_type, target_id, target_name,
       reason, description, conversation_id, reported_user_id, content_snapshot)
    VALUES
      (v_uid, v_nom, p_target_type, btrim(p_target_id), p_target_name,
       btrim(p_reason), p_description, p_conversation_id, p_reported_user_id,
       p_snapshot)
    RETURNING id INTO v_id;
  EXCEPTION WHEN unique_violation THEN
    RAISE EXCEPTION 'signalement : déjà signalé' USING ERRCODE = '23505';
  END;

  RETURN v_id;
END $$;

REVOKE ALL ON FUNCTION public.signalement_creer(text, text, text, text, text, text, text, jsonb)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.signalement_creer(text, text, text, text, text, text, text, jsonb)
  TO authenticated;
