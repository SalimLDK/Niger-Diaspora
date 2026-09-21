-- `users` : les trois dernières lectures dont la version cliente 1.1b a besoin.
--
-- Suite de `20260921080000_users_rpc_colonnes_privees.sql` — la cible, ses
-- quatre conditions et ses 16 sites sont dans
-- `supabase/users-colonnes-privees-cible.sql`. Comme la précédente, cette
-- migration est ADDITIVE : aucun droit ne change.
--
-- En réécrivant les 16 sites, trois ne trouvaient pas de voie :
--
-- 1. LA CARTE EN MODE PAYS (`getProfilesByCountry`, rayon « 0 ») place des
--    marqueurs, donc lit des positions — mais par pays, pas par boîte.
--    `positions_partagees()` ne sait chercher que par boîte.
--
-- 2. LA CARTE EN DIRECT (`watchProfileLocationUpdates`) reçoit par le temps
--    réel la ligne `users` de qui bouge. Sous la cible, le temps réel en
--    RETIRE `latitude`, `longitude` et `location_updated_at` sans erreur
--    (mesuré : tools/rls_tests/temps_reel_droits_colonnes.sql) : le rappel
--    sortirait tôt et plus personne ne bougerait à l'écran. Le message garde
--    `id` et `share_location` : il suffit d'aller chercher la position de CES
--    identifiants-là.
--
--    → `positions_partagees_par_ids(ids)` sert les deux, avec exactement les
--      exclusions de `positions_partagees()`.
--
-- 3. L'ENREGISTREMENT DU JETON PUSH (`notification_service.dart:1749`, :1797)
--    est un lire-modifier-écrire de `fcm_tokens` sur sa propre ligne. Sous la
--    cible, la lecture tomberait en 42501 : plus AUCUNE notification sur un
--    nouvel appareil. Le relire par `mon_profil_prive()` marcherait, mais
--    garderait la course du lire-modifier-écrire (deux appareils qui
--    s'enregistrent en même temps : le second efface le jeton du premier).
--
--    → `ajouter_jeton_push()` et `retirer_jeton_push()` font la modification
--      EN BASE, en une instruction. Plus de lecture, plus de course.
--
-- Banc : tools/rls_tests/users_rpc_jetons_positions.sql

-- ── 1 & 2. Positions, par identifiants ─────────────────────────────────────
-- Plafond de 200 identifiants par appel, pris dans l'ordre : ce qui dépasse
-- est ignoré, pas refusé. La carte n'en demande jamais autant (50 membres
-- par sondage), mais une fonction qui contourne le RLS ne doit pas servir de
-- balayage.
CREATE OR REPLACE FUNCTION public.positions_partagees_par_ids(p_ids text[])
RETURNS TABLE (
  id                  text,
  latitude            double precision,
  longitude           double precision,
  location_updated_at timestamptz
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT u.id, u.latitude, u.longitude, u.location_updated_at
    FROM public.users u
   WHERE (SELECT public.firebase_uid()) IS NOT NULL
     AND u.id = ANY ((p_ids)[1:200])
     -- Exactement les exclusions de `positions_partagees()` : le
     -- consentement, la visibilité, et `users_select` repris mot pour mot.
     AND u.share_location IS TRUE
     AND u.is_visible IS TRUE
     AND (NOT u.is_private OR u.id = (SELECT public.firebase_uid()))
     AND u.latitude  IS NOT NULL
     AND u.longitude IS NOT NULL;
$$;

REVOKE ALL ON FUNCTION public.positions_partagees_par_ids(text[]) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.positions_partagees_par_ids(text[]) TO authenticated;

-- ── 3. Le jeton push, modifié en base ──────────────────────────────────────
-- Toujours SA ligne : pas de paramètre d'identité, c'est `firebase_uid()`
-- qui la désigne. L'ancien code prenait un `userId` du client ; une fonction
-- qui contourne le RLS ne peut pas faire de même.
--
-- `fcm_tokens` est un `jsonb NOT NULL` (défaut `[]`) qui devrait être un
-- tableau. `NOT NULL` n'interdit pas le `null` JSON, ni un scalaire : ceux-là
-- repartent d'un tableau vide — `'null'::jsonb || '"x"'` donnerait
-- `[null, "x"]`, et `send-push` tenterait d'envoyer au jeton `null`.
CREATE OR REPLACE FUNCTION public.ajouter_jeton_push(p_jeton text)
RETURNS void
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_uid text := public.firebase_uid();
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'ajouter_jeton_push : session requise' USING ERRCODE = '42501';
  END IF;
  -- Un jeton FCM fait ~160 caractères ; 4096 laisse de la marge sans
  -- permettre de gonfler la ligne.
  IF p_jeton IS NULL OR btrim(p_jeton) = '' OR length(p_jeton) > 4096 THEN
    RAISE EXCEPTION 'ajouter_jeton_push : jeton invalide' USING ERRCODE = '22023';
  END IF;

  UPDATE public.users u
     SET fcm_tokens = CASE
           WHEN jsonb_typeof(u.fcm_tokens) = 'array' AND u.fcm_tokens ? p_jeton
             THEN u.fcm_tokens
           WHEN jsonb_typeof(u.fcm_tokens) = 'array'
             THEN u.fcm_tokens || to_jsonb(p_jeton)
           ELSE jsonb_build_array(p_jeton)
         END,
         last_token_update = now()
   WHERE u.id = v_uid;
END $$;

REVOKE ALL ON FUNCTION public.ajouter_jeton_push(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.ajouter_jeton_push(text) TO authenticated;

CREATE OR REPLACE FUNCTION public.retirer_jeton_push(p_jeton text)
RETURNS void
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_uid text := public.firebase_uid();
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'retirer_jeton_push : session requise' USING ERRCODE = '42501';
  END IF;
  IF p_jeton IS NULL THEN
    RETURN;
  END IF;

  UPDATE public.users u
     SET fcm_tokens = (
           SELECT coalesce(jsonb_agg(e), '[]'::jsonb)
             FROM jsonb_array_elements(u.fcm_tokens) e
            WHERE e <> to_jsonb(p_jeton))
   WHERE u.id = v_uid
     AND jsonb_typeof(u.fcm_tokens) = 'array'
     AND u.fcm_tokens ? p_jeton;
END $$;

REVOKE ALL ON FUNCTION public.retirer_jeton_push(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.retirer_jeton_push(text) TO authenticated;
