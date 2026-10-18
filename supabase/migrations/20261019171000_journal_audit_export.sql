-- Journal d'audit : export limité et lui-même audité.
--
-- Référentiel d'administration § 12 et spécification d'interfaces § 17.
--
-- ═══ CE QUI EXISTAIT ═══════════════════════════════════════════════════════
--
-- • La table est déjà en ajout seul (déclencheurs UPDATE/DELETE/TRUNCATE) et
--   lisible avec `security.audit.view` (20261016090000). Rien à refaire là.
-- • Aucun moyen d'EXPORTER : copier le journal passait par des lectures
--   répétées, sans trace de qui avait emporté quoi.
--
-- ═══ CE QUE CETTE MIGRATION POSE ═══════════════════════════════════════════
--
-- • La permission `security.audit.export`, SANS rôle associé : seul le
--   superAdmin la détient (admin_has_permission lui accorde tout le
--   catalogue). Elle est distincte de la lecture : voir n'est pas emporter.
-- • `admin_audit_export(...)` : mêmes filtres que l'écran (acteur, action,
--   ressource, résultat, période), plafonnée à 5000 lignes, qui rend les
--   lignes ET écrit dans le journal `AUDIT_EXPORTED` — filtres, nombre de
--   lignes, plafond atteint ou non — dans la même transaction. Si l'écriture
--   de l'audit échoue, l'export échoue : pas d'export sans trace.
-- • Les filtres sont posés en paramètres liés, jamais concaténés ; `p_action`
--   et `p_actor` se comparent en sous-chaîne insensible à la casse après
--   échappement des jokers LIKE.
--
-- ═══ CE QU'ELLE NE FAIT PAS ═════════════════════════════════════════════════
--
-- • Elle ne produit pas le fichier : elle rend les lignes, le client les met
--   en CSV. Le journal prouve qu'un export a eu lieu, pas où le fichier est
--   ensuite allé.
-- • Elle ne retire pas la policy d'INSERT `admin_audit_logs_insert_admin` :
--   cela attend le redéploiement du panneau (supabase/admin-audit-ecriture-
--   par-rpc-cible.sql).
--
-- Banc : tools/rls_tests/journal_audit_export.sql.

SET lock_timeout = '5s';

INSERT INTO public.admin_permissions (key, module, description, legacy_key) VALUES
  ('security.audit.export', 'security', 'Exporter le journal d''audit (plafonné, lui-même audité)', NULL)
ON CONFLICT (key) DO NOTHING;

DROP FUNCTION IF EXISTS public.admin_audit_export(text, text, text, text, text, timestamptz, timestamptz, integer);

CREATE FUNCTION public.admin_audit_export(
  p_actor         text        DEFAULT NULL,
  p_action        text        DEFAULT NULL,
  p_resource_type text        DEFAULT NULL,
  p_resource_id   text        DEFAULT NULL,
  p_result        text        DEFAULT NULL,
  p_from          timestamptz DEFAULT NULL,
  p_to            timestamptz DEFAULT NULL,
  p_limit         integer     DEFAULT 5000
)
RETURNS jsonb
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_actor_like  text;
  v_action_like text;
  v_rows        jsonb;
  v_n           integer;
  v_plafond     constant integer := 5000;
BEGIN
  PERFORM public.admin_require_permission('security.audit.export');

  IF p_limit IS NULL OR p_limit < 1 OR p_limit > v_plafond THEN
    RAISE EXCEPTION 'admin_audit_export : limite entre 1 et % (reçu %)', v_plafond, p_limit
      USING ERRCODE = '22023';
  END IF;
  IF p_result IS NOT NULL AND p_result NOT IN ('success', 'denied', 'failed', 'partial') THEN
    RAISE EXCEPTION 'admin_audit_export : result invalide' USING ERRCODE = '22023';
  END IF;
  IF p_from IS NOT NULL AND p_to IS NOT NULL AND p_from > p_to THEN
    RAISE EXCEPTION 'admin_audit_export : période inversée' USING ERRCODE = '22023';
  END IF;

  -- Sous-chaîne littérale : on échappe \, % et _ avant de poser les jokers.
  v_actor_like := CASE WHEN NULLIF(btrim(p_actor), '') IS NULL THEN NULL
    ELSE '%' || replace(replace(replace(btrim(p_actor), '\', '\\'), '%', '\%'), '_', '\_') || '%' END;
  v_action_like := CASE WHEN NULLIF(btrim(p_action), '') IS NULL THEN NULL
    ELSE '%' || replace(replace(replace(btrim(p_action), '\', '\\'), '%', '\%'), '_', '\_') || '%' END;

  SELECT COALESCE(jsonb_agg(to_jsonb(t) ORDER BY t.created_at DESC, t.id), '[]'::jsonb),
         count(*)::integer
    INTO v_rows, v_n
    FROM (
      SELECT l.id, l.created_at, l.admin_id, l.admin_name, l.action,
             l.target_type, l.target_id, l.result, l.reason_code,
             l.correlation_id, l.details
        FROM public.admin_audit_logs l
       WHERE (v_actor_like IS NULL OR l.admin_name ILIKE v_actor_like OR l.admin_id = btrim(p_actor))
         AND (v_action_like IS NULL OR l.action ILIKE v_action_like)
         AND (p_resource_type IS NULL OR l.target_type = p_resource_type)
         AND (p_resource_id IS NULL OR l.target_id = p_resource_id)
         AND (p_result IS NULL OR l.result = p_result)
         AND (p_from IS NULL OR l.created_at >= p_from)
         AND (p_to IS NULL OR l.created_at < p_to)
       ORDER BY l.created_at DESC, l.id
       LIMIT p_limit
    ) t;

  -- L'export laisse sa trace dans la même transaction : sans elle, pas d'export.
  PERFORM public.write_admin_audit(
    'AUDIT_EXPORTED', 'audit', NULL, 'success', NULL, NULL,
    jsonb_build_object(
      'rows', v_n,
      'limit', p_limit,
      'truncated', v_n >= p_limit,
      'filters', jsonb_strip_nulls(jsonb_build_object(
        'actor', NULLIF(btrim(p_actor), ''),
        'action', NULLIF(btrim(p_action), ''),
        'resource_type', p_resource_type,
        'resource_id', p_resource_id,
        'result', p_result,
        'from', p_from,
        'to', p_to))));

  RETURN jsonb_build_object('rows', v_rows, 'count', v_n, 'truncated', v_n >= p_limit);
END $$;

REVOKE ALL ON FUNCTION public.admin_audit_export(text, text, text, text, text, timestamptz, timestamptz, integer)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_audit_export(text, text, text, text, text, timestamptz, timestamptz, integer)
  TO authenticated;

NOTIFY pgrst, 'reload schema';
