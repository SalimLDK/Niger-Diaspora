-- =============================================================================
-- `users_near_point` — destinataires d'un événement local, par rayon GPS.
--
-- `notifyLocalEventCreated` sélectionnait ses destinataires sur la ville :
-- `users.city == eventCity`. Or `city` est **vide pour tous les comptes** (10
-- sur 10 au 2026-08-06) — le champ existe dans deux écrans de profil, personne
-- ne le remplit. La fonction ne trouvait donc jamais personne, et aucune
-- notification d'événement local n'est jamais partie.
--
-- La latitude/longitude, elle, est renseignée (5 comptes sur 10) : c'est la
-- carte « membres autour » qui la publie. On apparie donc là-dessus.
--
-- Pré-filtre par boîte englobante avant le haversine : sans lui, chaque
-- création d'événement calculerait un cosinus par utilisateur.
-- 111 km ≈ 1° de latitude ; en longitude il faut diviser par cos(lat), borné
-- pour ne pas exploser près des pôles.
--
-- Filtre aussi sur les deux préférences, pour que l'appelant n'ait pas à les
-- reconnaître : `notify_local_events` et l'interrupteur maître.
--
-- SECURITY DEFINER + REVOKE : appelée uniquement par les Cloud Functions avec
-- la clé service_role, jamais par un client.
-- =============================================================================

CREATE OR REPLACE FUNCTION public.users_near_point(
  p_lat       DOUBLE PRECISION,
  p_lng       DOUBLE PRECISION,
  p_radius_km DOUBLE PRECISION DEFAULT 50
)
RETURNS TABLE (id TEXT)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT u.id
  FROM users u
  WHERE u.notify_local_events IS TRUE
    AND u.notifications_enabled IS DISTINCT FROM FALSE
    AND u.latitude IS NOT NULL
    AND u.longitude IS NOT NULL
    -- Boîte englobante : rejette la grande majorité sans trigonométrie.
    AND u.latitude BETWEEN p_lat - (p_radius_km / 111.0)
                       AND p_lat + (p_radius_km / 111.0)
    AND u.longitude BETWEEN
          p_lng - (p_radius_km / (111.0 * GREATEST(COS(RADIANS(p_lat)), 0.01)))
      AND p_lng + (p_radius_km / (111.0 * GREATEST(COS(RADIANS(p_lat)), 0.01)))
    -- Distance orthodromique. LEAST/GREATEST bornent l'argument d'ACOS : les
    -- arrondis flottants le poussent parfois hors de [-1, 1] et ACOS lève.
    AND 6371.0 * ACOS(
          LEAST(1.0, GREATEST(-1.0,
              COS(RADIANS(p_lat)) * COS(RADIANS(u.latitude))
            * COS(RADIANS(u.longitude) - RADIANS(p_lng))
            + SIN(RADIANS(p_lat)) * SIN(RADIANS(u.latitude))
          ))
        ) <= p_radius_km;
$$;

COMMENT ON FUNCTION public.users_near_point(DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION) IS
  'Utilisateurs à moins de p_radius_km d''un point, ayant accepté les '
  'notifications d''événements locaux. Appelée par notifyLocalEventCreated.';

REVOKE ALL ON FUNCTION public.users_near_point(DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.users_near_point(DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION) FROM anon;
REVOKE ALL ON FUNCTION public.users_near_point(DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION) FROM authenticated;

NOTIFY pgrst, 'reload schema';
