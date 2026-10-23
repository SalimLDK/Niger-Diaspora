-- Recherche globale et file « à traiter » de l'administrateur.
--
-- Spécification d'interfaces § 3 (recherche globale) et § 4 (centre de
-- notifications de l'administrateur).
--
-- ═══ CE QU'ELLE POSE ═══════════════════════════════════════════════════════
--
-- • `admin_global_search(q, limite)` : une recherche par mot, sur huit
--   sources, dont CHACUNE est filtrée par la permission de lecture qui la
--   protège déjà ailleurs. Un administrateur qui n'a pas le droit de lire les
--   membres ne reçoit aucun membre — et la réponse dit quelles sources ont été
--   ignorées faute de droit, pour que « aucun résultat » ne soit pas confondu
--   avec « pas le droit de chercher là ».
--     membres        community.members.view     nom, pseudo (jamais le courriel)
--     tickets        support.tickets.view        objet, nom du membre
--     signalements   moderation.reports.view     cible, motif, auteur
--     entreprises    directory.listings.view     nom
--     événements     events.moderate             titre (tous statuts)
--     démarches      consular.view               titre
--     ambassades     consular.view               nom, ville
--     campagnes      communications.view         titre
--   La recherche est une consultation de données personnelles : elle est
--   journalisée (qui, combien de caractères, quelles sources, combien de
--   résultats) — JAMAIS le mot cherché, qui peut être un nom de membre.
-- • `admin_attention_queue()` : ce qui attend l'administrateur, compté en base
--   au moment de l'appel — pas une table de notifications à tenir à jour, donc
--   rien qui puisse mentir ou rester allumé après coup. Une ligne par source
--   dont il détient le droit : total, dont en retard, plus ancien.
--
-- ═══ CE QU'ELLE NE FAIT PAS ═══════════════════════════════════════════════
--
-- • Pas de recherche dans le texte des messages, des publications ou des
--   tickets : seulement des titres et des noms.
-- • Pas de recherche par courriel ni par téléphone.
-- • Pas de poussée vers l'administrateur : la file se lit à l'ouverture.
--
-- Banc : tools/rls_tests/recherche_globale_a_traiter.sql.

SET lock_timeout = '5s';

-- ── 1. Recherche ───────────────────────────────────────────────────────────
DROP FUNCTION IF EXISTS public.admin_global_search(text, integer);
CREATE FUNCTION public.admin_global_search(p_query text, p_limit integer DEFAULT 8)
RETURNS jsonb
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_q       text;
  v_pat     text;
  v_lim     integer := least(greatest(coalesce(p_limit, 8), 1), 20);
  v_groups  jsonb := '[]'::jsonb;
  v_searched text[] := '{}';
  v_skipped  text[] := '{}';
  v_hits    jsonb;
  v_total   integer := 0;
  v_n       integer;
BEGIN
  IF (SELECT public.firebase_uid()) IS NULL OR NOT public.is_admin() THEN
    RAISE EXCEPTION 'recherche : réservé aux administrateurs' USING ERRCODE = '42501';
  END IF;
  v_q := btrim(coalesce(p_query, ''));
  IF length(v_q) < 2 OR length(v_q) > 80 THEN
    RAISE EXCEPTION 'recherche : 2 à 80 caractères' USING ERRCODE = '22023';
  END IF;
  -- Les jokers du mot cherché sont des lettres, pas des motifs.
  v_pat := '%' || replace(replace(replace(v_q, '\', '\\'), '%', '\%'), '_', '\_') || '%';

  -- membres
  IF public.admin_has_permission('community.members.view') THEN
    v_searched := v_searched || ARRAY['members'];
    SELECT coalesce(jsonb_agg(jsonb_build_object(
             'id', u.id, 'title', u.display_name,
             'subtitle', coalesce('@' || u.handle, ''),
             'status', CASE WHEN u.is_banned THEN 'banned'
                            WHEN u.suspended_until IS NOT NULL AND u.suspended_until > now() THEN 'suspended'
                            ELSE 'active' END)), '[]'::jsonb), count(*)
      INTO v_hits, v_n
      FROM (SELECT * FROM public.users
             WHERE display_name ILIKE v_pat OR handle ILIKE v_pat
             ORDER BY display_name LIMIT v_lim) u;
    v_total := v_total + v_n;
    IF v_n > 0 THEN v_groups := v_groups || jsonb_build_object('kind', 'members', 'items', v_hits); END IF;
  ELSE v_skipped := v_skipped || ARRAY['members']; END IF;

  -- tickets
  IF public.admin_has_permission('support.tickets.view') THEN
    v_searched := v_searched || ARRAY['tickets'];
    SELECT coalesce(jsonb_agg(jsonb_build_object(
             'id', t.id, 'title', t.subject, 'subtitle', t.user_name, 'status', t.status)), '[]'::jsonb), count(*)
      INTO v_hits, v_n
      FROM (SELECT * FROM public.support_tickets
             WHERE subject ILIKE v_pat OR user_name ILIKE v_pat
             ORDER BY updated_at DESC LIMIT v_lim) t;
    v_total := v_total + v_n;
    IF v_n > 0 THEN v_groups := v_groups || jsonb_build_object('kind', 'tickets', 'items', v_hits); END IF;
  ELSE v_skipped := v_skipped || ARRAY['tickets']; END IF;

  -- signalements
  IF public.admin_has_permission('moderation.reports.view') THEN
    v_searched := v_searched || ARRAY['reports'];
    SELECT coalesce(jsonb_agg(jsonb_build_object(
             'id', r.id, 'title', coalesce(r.target_name, r.target_type),
             'subtitle', r.reason, 'status', r.status)), '[]'::jsonb), count(*)
      INTO v_hits, v_n
      FROM (SELECT * FROM public.reports
             WHERE target_name ILIKE v_pat OR reason ILIKE v_pat OR reporter_name ILIKE v_pat
             ORDER BY created_at DESC LIMIT v_lim) r;
    v_total := v_total + v_n;
    IF v_n > 0 THEN v_groups := v_groups || jsonb_build_object('kind', 'reports', 'items', v_hits); END IF;
  ELSE v_skipped := v_skipped || ARRAY['reports']; END IF;

  -- entreprises
  IF public.admin_has_permission('directory.listings.view') THEN
    v_searched := v_searched || ARRAY['businesses'];
    SELECT coalesce(jsonb_agg(jsonb_build_object(
             'id', b.id, 'title', b.name, 'subtitle', coalesce(b.city, ''),
             'status', CASE WHEN b.archived_at IS NOT NULL THEN 'archived'
                            WHEN b.is_verified THEN 'verified' ELSE 'active' END)), '[]'::jsonb), count(*)
      INTO v_hits, v_n
      FROM (SELECT * FROM public.businesses WHERE name ILIKE v_pat ORDER BY name LIMIT v_lim) b;
    v_total := v_total + v_n;
    IF v_n > 0 THEN v_groups := v_groups || jsonb_build_object('kind', 'businesses', 'items', v_hits); END IF;
  ELSE v_skipped := v_skipped || ARRAY['businesses']; END IF;

  -- événements
  IF public.admin_has_permission('events.moderate') THEN
    v_searched := v_searched || ARRAY['events'];
    SELECT coalesce(jsonb_agg(jsonb_build_object(
             'id', e.id, 'title', e.title, 'subtitle', coalesce(e.city, ''), 'status', e.status)), '[]'::jsonb), count(*)
      INTO v_hits, v_n
      FROM (SELECT * FROM public.events WHERE title ILIKE v_pat ORDER BY starts_at DESC LIMIT v_lim) e;
    v_total := v_total + v_n;
    IF v_n > 0 THEN v_groups := v_groups || jsonb_build_object('kind', 'events', 'items', v_hits); END IF;
  ELSE v_skipped := v_skipped || ARRAY['events']; END IF;

  -- démarches et ambassades
  IF public.admin_has_permission('consular.view') THEN
    v_searched := v_searched || ARRAY['procedures', 'embassies'];
    SELECT coalesce(jsonb_agg(jsonb_build_object(
             'id', d.id, 'title', d.titre, 'subtitle', coalesce(d.rubrique, ''),
             'status', d.publication_status)), '[]'::jsonb), count(*)
      INTO v_hits, v_n
      FROM (SELECT * FROM public.demarches_consulaires WHERE titre ILIKE v_pat ORDER BY titre LIMIT v_lim) d;
    v_total := v_total + v_n;
    IF v_n > 0 THEN v_groups := v_groups || jsonb_build_object('kind', 'procedures', 'items', v_hits); END IF;

    SELECT coalesce(jsonb_agg(jsonb_build_object(
             'id', m.id, 'title', m.name, 'subtitle', coalesce(m.city, ''),
             'status', CASE WHEN m.is_suspended THEN 'suspended'
                            WHEN m.is_verified THEN 'verified' ELSE 'active' END)), '[]'::jsonb), count(*)
      INTO v_hits, v_n
      FROM (SELECT * FROM public.embassies WHERE name ILIKE v_pat OR city ILIKE v_pat ORDER BY name LIMIT v_lim) m;
    v_total := v_total + v_n;
    IF v_n > 0 THEN v_groups := v_groups || jsonb_build_object('kind', 'embassies', 'items', v_hits); END IF;
  ELSE v_skipped := v_skipped || ARRAY['procedures', 'embassies']; END IF;

  -- campagnes
  IF public.admin_has_permission('communications.view') THEN
    v_searched := v_searched || ARRAY['campaigns'];
    SELECT coalesce(jsonb_agg(jsonb_build_object(
             'id', c.id, 'title', c.title, 'subtitle', c.type, 'status', c.status)), '[]'::jsonb), count(*)
      INTO v_hits, v_n
      FROM (SELECT * FROM public.campaigns WHERE title ILIKE v_pat ORDER BY updated_at DESC LIMIT v_lim) c;
    v_total := v_total + v_n;
    IF v_n > 0 THEN v_groups := v_groups || jsonb_build_object('kind', 'campaigns', 'items', v_hits); END IF;
  ELSE v_skipped := v_skipped || ARRAY['campaigns']; END IF;

  -- Le mot cherché n'entre jamais dans l'audit : longueur, sources, nombre.
  PERFORM public.write_admin_audit(
    'ADMIN_SEARCH', 'search', NULL, 'success', NULL, NULL,
    jsonb_build_object('length', length(v_q), 'sources', to_jsonb(v_searched), 'results', v_total));

  RETURN jsonb_build_object('groups', v_groups, 'searched', to_jsonb(v_searched),
                            'skipped', to_jsonb(v_skipped), 'total', v_total);
END $$;

-- ── 2. Ce qui attend l'administrateur ──────────────────────────────────────
DROP FUNCTION IF EXISTS public.admin_attention_queue();
CREATE FUNCTION public.admin_attention_queue()
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_out jsonb := '[]'::jsonb;
  v_total integer;
  v_late  integer;
  v_old   timestamptz;
BEGIN
  IF (SELECT public.firebase_uid()) IS NULL OR NOT public.is_admin() THEN
    RAISE EXCEPTION 'file : réservé aux administrateurs' USING ERRCODE = '42501';
  END IF;

  IF public.admin_has_permission('moderation.reports.view') THEN
    SELECT count(*), count(*) FILTER (WHERE due_at IS NOT NULL AND due_at < now()), min(created_at)
      INTO v_total, v_late, v_old
      FROM public.reports WHERE status IN ('pending', 'escalated');
    v_out := v_out || jsonb_build_object('key', 'reports', 'total', v_total, 'late', v_late, 'oldest', v_old);
  END IF;

  IF public.admin_has_permission('moderation.appeals.view') THEN
    SELECT count(*), 0, min(received_at) INTO v_total, v_late, v_old
      FROM public.moderation_appeals WHERE status IN ('received', 'under_review');
    v_out := v_out || jsonb_build_object('key', 'appeals', 'total', v_total, 'late', 0, 'oldest', v_old);
  END IF;

  IF public.admin_has_permission('support.tickets.view') THEN
    SELECT count(*), count(*) FILTER (WHERE has_unread_user_messages), min(created_at)
      INTO v_total, v_late, v_old
      FROM public.support_tickets WHERE status IN ('open', 'in_progress');
    v_out := v_out || jsonb_build_object('key', 'tickets', 'total', v_total, 'late', v_late, 'oldest', v_old);

    SELECT count(*), 0, min(escalated_at) INTO v_total, v_late, v_old
      FROM public.support_tickets WHERE escalated_at IS NOT NULL AND status IN ('open', 'in_progress');
    v_out := v_out || jsonb_build_object('key', 'tickets_escalated', 'total', v_total, 'late', 0, 'oldest', v_old);

    SELECT count(*) INTO v_total FROM public.support_sla_status()
     WHERE coalesce(first_response_late, false) OR coalesce(resolution_late, false);
    v_out := v_out || jsonb_build_object('key', 'tickets_overdue', 'total', v_total, 'late', v_total, 'oldest', NULL);
  END IF;

  IF public.admin_has_permission('privacy.requests.manage') THEN
    SELECT count(*), count(*) FILTER (WHERE due_at IS NOT NULL AND due_at < now()), min(created_at)
      INTO v_total, v_late, v_old
      FROM public.privacy_requests WHERE status IN ('received', 'identity_verified', 'in_progress');
    v_out := v_out || jsonb_build_object('key', 'privacy', 'total', v_total, 'late', v_late, 'oldest', v_old);
  END IF;

  IF public.admin_has_permission('consular.procedures.approve') THEN
    SELECT count(*), 0, min(submitted_at) INTO v_total, v_late, v_old
      FROM public.demarches_brouillons WHERE status = 'pending';
    v_out := v_out || jsonb_build_object('key', 'procedures', 'total', v_total, 'late', 0, 'oldest', v_old);
  END IF;

  IF public.admin_has_permission('communications.send') THEN
    SELECT count(*), 0, min(updated_at) INTO v_total, v_late, v_old
      FROM public.campaigns WHERE status = 'pending_approval';
    v_out := v_out || jsonb_build_object('key', 'campaigns', 'total', v_total, 'late', 0, 'oldest', v_old);
  END IF;

  IF public.admin_has_permission('directory.listings.view') THEN
    SELECT count(*), count(*), min(next_review_at) INTO v_total, v_late, v_old
      FROM public.businesses WHERE archived_at IS NULL AND next_review_at IS NOT NULL AND next_review_at < now();
    v_out := v_out || jsonb_build_object('key', 'businesses_review', 'total', v_total, 'late', v_late, 'oldest', v_old);
  END IF;

  RETURN v_out;
END $$;

-- ── 3. Droits d'exécution ──────────────────────────────────────────────────
REVOKE ALL ON FUNCTION public.admin_global_search(text, integer) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.admin_attention_queue()            FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_global_search(text, integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_attention_queue()            TO authenticated;

NOTIFY pgrst, 'reload schema';
