-- Panneau admin : liste des utilisateurs paginée, avec recherche et filtre
-- côté serveur.
--
-- `profils_admin(p_limite)` ne rend que les N plus récents : passé 50 (500 au
-- maximum), les comptes plus anciens étaient invisibles, et la recherche de
-- l'écran ne filtrait que cette liste tronquée. Cette fonction rend une page.
--
-- Fonction NOUVELLE (nom distinct) : aucune surcharge de `profils_admin` à
-- supprimer, l'ancienne reste servie au tableau de bord.
--
-- Même garde que `profils_admin` : `is_admin()`, 42501 sinon. SECURITY
-- DEFINER pour les colonnes privées (fermeture 1.1b), donc aucun filtre RLS :
-- la garde est la seule porte.

CREATE OR REPLACE FUNCTION public.profils_admin_page(
  p_recherche text    DEFAULT NULL,
  p_filtre    text    DEFAULT 'tous',
  p_decalage  integer DEFAULT 0,
  p_limite    integer DEFAULT 50
)
RETURNS SETOF public.users
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_motif text := NULL;
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'profils_admin_page : réservé aux administrateurs'
      USING ERRCODE = '42501';
  END IF;

  IF p_filtre NOT IN ('tous', 'admins', 'bannis') THEN
    RAISE EXCEPTION 'profils_admin_page : filtre inconnu (%)', p_filtre
      USING ERRCODE = '22023';
  END IF;

  -- `%`, `_` et `\` saisis par l'admin sont des caractères, pas des jokers.
  IF nullif(btrim(p_recherche), '') IS NOT NULL THEN
    v_motif := '%' || replace(replace(replace(btrim(p_recherche),
                 '\', '\'), '%', '\%'), '_', '\_') || '%';
  END IF;

  RETURN QUERY
    SELECT u.*
      FROM public.users u
     WHERE (v_motif IS NULL
            OR u.display_name ILIKE v_motif
            OR u.email ILIKE v_motif)
       AND (p_filtre = 'tous'
            OR (p_filtre = 'admins' AND u.is_admin)
            OR (p_filtre = 'bannis' AND u.is_banned))
     ORDER BY u.created_at DESC, u.id
    OFFSET GREATEST(coalesce(p_decalage, 0), 0)
     LIMIT LEAST(GREATEST(coalesce(p_limite, 50), 1), 200);
END $$;

REVOKE ALL ON FUNCTION public.profils_admin_page(text, text, integer, integer)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.profils_admin_page(text, text, integer, integer)
  TO authenticated;
