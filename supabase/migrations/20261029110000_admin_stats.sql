-- Statistiques agrégées pour la console : une fonction serveur, une permission (`dashboard.analytics.view`).
-- NON APPLIQUÉE — à répéter par tools/rls_tests/roles_durcissement_complet.sql.
--
-- POURQUOI. La page Statistiques lisait `users`, `reports`, `support_tickets`… en direct. Depuis la fermeture
-- de l'héritage `is_admin()` (20261029100000), un analyste n'y voit plus que les lignes publiques : un compteur
-- aurait affiché une valeur FAIBLE SANS ERREUR (le RLS filtre en silence), ce que la console s'interdit.
-- Cette fonction compte côté serveur, pour qui a la permission, et ne rend QUE des agrégats : aucune ligne,
-- aucun identifiant, aucune coordonnée. Un refus est un 42501, pas un zéro.
--
-- Les compteurs de `reports` et `support_tickets` sont des totaux « à traiter » : ils ne donnent ni l'auteur,
-- ni l'objet, ni le motif d'un dossier.

SET lock_timeout = '5s';

DROP FUNCTION IF EXISTS public.admin_stats();

CREATE FUNCTION public.admin_stats()
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_inscriptions jsonb;
  v_pays         jsonb;
BEGIN
  IF (SELECT public.firebase_uid()) IS NULL OR NOT public.is_admin() THEN
    RAISE EXCEPTION 'statistiques : réservé aux administrateurs' USING ERRCODE = '42501';
  END IF;
  PERFORM public.admin_require_permission('dashboard.analytics.view');

  SELECT coalesce(jsonb_agg(jsonb_build_object('day', d::date, 'n', coalesce(c.n, 0)) ORDER BY d), '[]'::jsonb)
    INTO v_inscriptions
    FROM generate_series(current_date - 29, current_date, interval '1 day') AS d
    LEFT JOIN (SELECT created_at::date AS j, count(*) AS n
                 FROM public.users WHERE created_at >= current_date - 29 GROUP BY 1) c
           ON c.j = d::date;

  -- Pays : agrégat seulement, et seuls les pays d'au moins 3 membres, pour ne désigner personne.
  SELECT coalesce(jsonb_agg(jsonb_build_object('country', country_code, 'n', n) ORDER BY n DESC), '[]'::jsonb)
    INTO v_pays
    FROM (SELECT country_code, count(*) AS n
            FROM public.users
           WHERE country_code IS NOT NULL
           GROUP BY country_code
          HAVING count(*) >= 3
           ORDER BY n DESC
           LIMIT 10) t;

  RETURN jsonb_build_object(
    'computed_at',      now(),
    'users_total',      (SELECT count(*) FROM public.users),
    'users_active_24h', (SELECT count(*) FROM public.users WHERE last_active_at >= now() - interval '1 day'),
    'users_active_7d',  (SELECT count(*) FROM public.users WHERE last_active_at >= now() - interval '7 days'),
    'users_banned',     (SELECT count(*) FROM public.users WHERE coalesce(is_banned, false)),
    'groups',           (SELECT count(*) FROM public.groups),
    'events_upcoming',  (SELECT count(*) FROM public.events WHERE status = 'upcoming'),
    'businesses_active',(SELECT count(*) FROM public.businesses WHERE is_active),
    'reports_open',     (SELECT count(*) FROM public.reports WHERE status IN ('pending', 'reviewing', 'escalated')),
    'tickets_open',     (SELECT count(*) FROM public.support_tickets WHERE status IN ('open', 'in_progress')),
    'signups_30d',      v_inscriptions,
    'top_countries',    v_pays
  );
END $$;

REVOKE ALL ON FUNCTION public.admin_stats() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_stats() TO authenticated;

NOTIFY pgrst, 'reload schema';
