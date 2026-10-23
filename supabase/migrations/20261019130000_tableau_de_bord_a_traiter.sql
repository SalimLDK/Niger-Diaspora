-- Tableau de bord : le bloc « À traiter », calculé côté serveur, par droit.
--
-- Référentiel d'administration § 4 et spécification d'interfaces § 7 :
-- « Bloc “À traiter” trié par priorité et ancienneté », « les métriques sont
-- calculées côté serveur », « un utilisateur ne voit que les données
-- autorisées », « chaque indicateur précise sa période et sa date de mise à
-- jour », « une erreur de chargement ne doit pas être remplacée
-- silencieusement par zéro ».
--
-- ═══ CE QUI EXISTAIT ═══════════════════════════════════════════════════════
--
-- Le tableau de bord comptait des tables entières (`tableCount`) et rendait 0
-- quand la requête échouait — un refus de permission devenait « 0 signalement
-- en attente », indiscernable d'un tableau de bord calme. Aucune des files
-- construites depuis (signalements, support, démarches, campagnes, demandes de
-- données, incidents, fiches à vérifier) n'y figurait, et rien n'y disait de
-- quand datait un chiffre.
--
-- ═══ CE QUE CETTE MIGRATION POSE ═══════════════════════════════════════════
--
-- • `admin_dashboard_tasks()` : une liste d'éléments {key, count, urgent,
--   oldest_at} et la date de calcul. Chaque élément n'est calculé QUE si
--   l'appelant porte la permission du module — un rôle sans droit ne reçoit
--   pas la ligne (et non un 0). `urgent` est un sous-ensemble défini par
--   l'élément (en retard, non attribué, critique…), `oldest_at` l'ancienneté
--   de ce qui attend le plus.
-- • Les libellés et les DÉFINITIONS vivent dans l'application (traduits) ; le
--   serveur ne renvoie que des clés et des nombres.
-- • État courant, pas période : un « à traiter » est ce qui attend AU MOMENT du
--   calcul, daté par `computed_at`.
--
-- ═══ CE QU'ELLE NE FAIT PAS ═════════════════════════════════════════════════
--
-- • Elle ne remplace pas les compteurs « Utilisateurs / Événements / Groupes… »
--   du tableau de bord, qui restent calculés par le client ; l'application les
--   montre désormais « indisponibles » quand leur lecture échoue, au lieu de 0.
-- • Pas d'alertes d'exploitation (services indisponibles, volume anormal de
--   signalements) : il n'existe aucune source de ces mesures à ce jour.
--
-- Banc : tools/rls_tests/tableau_de_bord_a_traiter.sql.

SET lock_timeout = '5s';

DROP FUNCTION IF EXISTS public.admin_dashboard_tasks();

CREATE FUNCTION public.admin_dashboard_tasks() RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_items jsonb := '[]'::jsonb;
  v_n     bigint;
  v_u     bigint;
  v_old   timestamptz;
BEGIN
  IF (SELECT public.firebase_uid()) IS NULL OR NOT public.is_admin() THEN
    RAISE EXCEPTION 'tableau de bord : réservé aux administrateurs' USING ERRCODE = '42501';
  END IF;

  -- Signalements : nouveaux, en examen ou escaladés ; urgent = non pris en charge.
  IF public.admin_has_permission('moderation.reports.view') THEN
    SELECT count(*), count(*) FILTER (WHERE status = 'pending'), min(created_at)
      INTO v_n, v_u, v_old
      FROM public.reports WHERE status IN ('pending', 'reviewing', 'escalated');
    v_items := v_items || jsonb_build_object('key', 'reports', 'count', v_n,
                                             'urgent', v_u, 'oldest_at', v_old);
  END IF;

  -- Support : tickets ouverts ou en cours ; urgent = ouverts, donc non pris.
  IF public.admin_has_permission('support.tickets.view') THEN
    SELECT count(*), count(*) FILTER (WHERE status = 'open'), min(created_at)
      INTO v_n, v_u, v_old
      FROM public.support_tickets WHERE status IN ('open', 'in_progress');
    v_items := v_items || jsonb_build_object('key', 'support', 'count', v_n,
                                             'urgent', v_u, 'oldest_at', v_old);
  END IF;

  -- Démarches consulaires : textes à relire + démarches publiées dont la
  -- révision datée est dépassée ; urgent = révisions en retard.
  IF public.admin_has_permission('consular.view') THEN
    SELECT (SELECT count(*) FROM public.demarches_brouillons WHERE status IN ('pending', 'approved'))
         + (SELECT count(*) FROM public.demarches_consulaires
             WHERE publication_status = 'published' AND next_review_at < now()),
           (SELECT count(*) FROM public.demarches_consulaires
             WHERE publication_status = 'published' AND next_review_at < now()),
           (SELECT min(t) FROM (
              SELECT min(submitted_at) AS t FROM public.demarches_brouillons
               WHERE status IN ('pending', 'approved')
              UNION ALL
              SELECT min(next_review_at) FROM public.demarches_consulaires
               WHERE publication_status = 'published' AND next_review_at < now()) x)
      INTO v_n, v_u, v_old;
    v_items := v_items || jsonb_build_object('key', 'demarches', 'count', v_n,
                                             'urgent', v_u, 'oldest_at', v_old);
  END IF;

  -- Campagnes : messages soumis qui attendent un autre administrateur.
  IF public.admin_has_permission('communications.send') THEN
    SELECT count(*), NULL::bigint, min(updated_at)
      INTO v_n, v_u, v_old
      FROM public.campaigns WHERE status = 'pending_approval';
    v_items := v_items || jsonb_build_object('key', 'campaigns', 'count', v_n,
                                             'urgent', v_u, 'oldest_at', v_old);
  END IF;

  -- Demandes relatives aux données : ouvertes ; urgent = échéance interne dépassée.
  IF public.admin_has_permission('privacy.requests.manage') THEN
    SELECT count(*), count(*) FILTER (WHERE due_at < now()), min(created_at)
      INTO v_n, v_u, v_old
      FROM public.privacy_requests
     WHERE status IN ('received', 'identity_verified', 'in_progress');
    v_items := v_items || jsonb_build_object('key', 'privacy', 'count', v_n,
                                             'urgent', v_u, 'oldest_at', v_old);
  END IF;

  -- Incidents de sécurité : non clos ; urgent = gravité élevée ou critique.
  IF public.admin_has_permission('security.incidents.manage') THEN
    SELECT count(*), count(*) FILTER (WHERE severity IN ('high', 'critical')), min(detected_at)
      INTO v_n, v_u, v_old
      FROM public.security_incidents WHERE status <> 'closed';
    v_items := v_items || jsonb_build_object('key', 'incidents', 'count', v_n,
                                             'urgent', v_u, 'oldest_at', v_old);
  END IF;

  -- Annuaire : fiches actives sans badge. Un « à traiter » faible, sans urgence.
  IF public.admin_has_permission('directory.listings.approve') THEN
    SELECT count(*), NULL::bigint, min(created_at)
      INTO v_n, v_u, v_old
      FROM public.businesses WHERE is_active AND NOT is_verified;
    v_items := v_items || jsonb_build_object('key', 'listings', 'count', v_n,
                                             'urgent', v_u, 'oldest_at', v_old);
  END IF;

  RETURN jsonb_build_object('computed_at', now(), 'items', v_items);
END $$;

REVOKE ALL ON FUNCTION public.admin_dashboard_tasks() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_dashboard_tasks() TO authenticated;

NOTIFY pgrst, 'reload schema';
