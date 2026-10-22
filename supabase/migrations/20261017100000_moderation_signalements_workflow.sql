-- Modération des signalements, tranche 1 : le workflow vit en base.
--
-- Référentiel d'administration § 6 (docs/ADMIN_GUIDE_DEVELOPPEUR.md, étape 2).
-- Aujourd'hui le panneau écrit `reports.status` directement (UPDATE de six
-- colonnes, policy `is_admin()`), sans transition contrôlée, sans motif
-- normalisé, sans responsable, sans trace : deux modérateurs peuvent « résoudre »
-- le même dossier, un dossier classé peut repartir en `pending`, et rien ne dit
-- qui a décidé quoi. Table vivante : 0 ligne au 2026-10-17.
--
-- ═══ CE QUE CETTE MIGRATION POSE ═══════════════════════════════════════════
--
-- • Cinq colonnes : `assigned_to`, `assigned_at`, `priority`, `due_at`,
--   `reason_code` (motif normalisé de la dernière décision) — additif, les
--   écrivains actuels ne les voient pas.
-- • Un statut de plus : `escalated`. Les quatre existants sont conservés
--   (`pending` ≈ NOUVEAU, `reviewing` ≈ EN_EXAMEN, `resolved` = décision avec
--   action, `dismissed` = sans suite) : renommer casserait le client déployé.
-- • `moderation_report_transitions` : les seules transitions permises, la
--   permission qu'elles exigent, le nom d'audit, et ce qu'elles exigent
--   (motif normalisé, justification, action exécutée).
-- • `signalement_transition(...)` : la SEULE porte de changement de statut.
--   Verrouille la ligne (FOR UPDATE), refuse une transition absente de la
--   table (55000), vérifie la permission, impose le responsable (sauf
--   superAdmin ou reprise d'une escalade), exige motif/justification selon la
--   transition, et écrit l'audit DANS LA MÊME TRANSACTION (write_admin_audit).
--   Deux appels concurrents : le second voit le nouveau statut et est refusé.
-- • Deux permissions : `moderation.reports.assign`, `moderation.reports.escalate`
--   (mappées à contentMod ; superAdmin a tout).
--
-- ═══ CE QU'ELLE NE FAIT PAS ═════════════════════════════════════════════════
--
-- • Elle ne ferme pas l'UPDATE direct du client : le panneau déployé s'en sert
--   encore. La fermeture est dans
--   supabase/moderation-signalements-update-ferme-cible.sql, à appliquer APRÈS
--   la bascule du client (tranche 2), sinon « Résoudre » ne touche plus aucune
--   ligne, en silence.
-- • Pas de demande d'informations, de recours ni de notification (tranches
--   suivantes ; les notifications passeront par l'outbox, pas par cette RPC).
--
-- Banc : tools/rls_tests/moderation_signalements_workflow.sql.

SET lock_timeout = '5s';

-- ── 1. Colonnes ─────────────────────────────────────────────────────────────
ALTER TABLE public.reports
  ADD COLUMN IF NOT EXISTS assigned_to text,
  ADD COLUMN IF NOT EXISTS assigned_at timestamptz,
  ADD COLUMN IF NOT EXISTS priority    text NOT NULL DEFAULT 'normal',
  ADD COLUMN IF NOT EXISTS due_at      timestamptz,
  ADD COLUMN IF NOT EXISTS reason_code text;

ALTER TABLE public.reports DROP CONSTRAINT IF EXISTS reports_priority_check;
ALTER TABLE public.reports ADD CONSTRAINT reports_priority_check
  CHECK (priority IN ('low', 'normal', 'high', 'urgent'));

-- Le statut : on retrouve la contrainte par sa définition (son nom n'est pas
-- dans les migrations), on la remplace par la même + `escalated`.
DO $$
DECLARE c record;
BEGIN
  FOR c IN
    SELECT conname FROM pg_constraint
     WHERE conrelid = 'public.reports'::regclass AND contype = 'c'
       AND pg_get_constraintdef(oid) ~ 'status'
  LOOP
    EXECUTE format('ALTER TABLE public.reports DROP CONSTRAINT %I', c.conname);
  END LOOP;
END $$;
ALTER TABLE public.reports ADD CONSTRAINT reports_status_check
  CHECK (status IN ('pending', 'reviewing', 'escalated', 'resolved', 'dismissed'));

CREATE INDEX IF NOT EXISTS reports_file_idx
  ON public.reports (status, priority, created_at)
  WHERE status IN ('pending', 'reviewing', 'escalated');

-- ── 2. Permissions ──────────────────────────────────────────────────────────
INSERT INTO public.admin_permissions (key, module, description, legacy_key) VALUES
  ('moderation.reports.assign',   'moderation', 'Prendre en charge un signalement', NULL),
  ('moderation.reports.escalate', 'moderation', 'Escalader un signalement',         NULL)
ON CONFLICT (key) DO NOTHING;

INSERT INTO public.admin_role_permissions (role, permission) VALUES
  ('contentMod', 'moderation.reports.assign'),
  ('contentMod', 'moderation.reports.escalate')
ON CONFLICT DO NOTHING;

-- ── 3. Les transitions permises ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.moderation_report_transitions (
  from_status  text NOT NULL,
  to_status    text NOT NULL,
  permission   text NOT NULL REFERENCES public.admin_permissions (key),
  audit_action text NOT NULL,
  needs_reason boolean NOT NULL DEFAULT false,  -- motif normalisé
  needs_note   boolean NOT NULL DEFAULT false,  -- justification libre
  needs_action boolean NOT NULL DEFAULT false,  -- action_taken
  takes_over   boolean NOT NULL DEFAULT false,  -- le responsable devient l'appelant
  PRIMARY KEY (from_status, to_status)
);

INSERT INTO public.moderation_report_transitions
  (from_status, to_status, permission, audit_action,
   needs_reason, needs_note, needs_action, takes_over)
VALUES
  ('pending',   'reviewing', 'moderation.reports.assign',   'REPORT_ASSIGNED',    false, false, false, true),
  ('reviewing', 'dismissed', 'moderation.reports.review',   'MODERATION_DECIDED', true,  true,  false, false),
  ('reviewing', 'resolved',  'moderation.reports.review',   'MODERATION_DECIDED', true,  true,  true,  false),
  ('reviewing', 'escalated', 'moderation.reports.escalate', 'REPORT_ESCALATED',   true,  true,  false, false),
  ('escalated', 'reviewing', 'moderation.reports.assign',   'REPORT_ASSIGNED',    false, false, false, true)
ON CONFLICT (from_status, to_status) DO NOTHING;

ALTER TABLE public.moderation_report_transitions ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.moderation_report_transitions FROM anon, authenticated;
GRANT SELECT ON public.moderation_report_transitions TO authenticated;
DROP POLICY IF EXISTS moderation_report_transitions_select ON public.moderation_report_transitions;
CREATE POLICY moderation_report_transitions_select ON public.moderation_report_transitions
  FOR SELECT TO authenticated USING (public.is_admin());

-- ── 4. La porte unique ──────────────────────────────────────────────────────
DROP FUNCTION IF EXISTS public.signalement_transition(uuid, text, text, text, text);

CREATE FUNCTION public.signalement_transition(
  p_report_id    uuid,
  p_to           text,
  p_reason_code  text DEFAULT NULL,
  p_note         text DEFAULT NULL,
  p_action_taken text DEFAULT NULL
) RETURNS text
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller text := (SELECT public.firebase_uid());
  r        public.reports%ROWTYPE;
  t        public.moderation_report_transitions%ROWTYPE;
  v_motifs text[];
BEGIN
  IF v_caller IS NULL OR NOT public.is_admin() THEN
    RAISE EXCEPTION 'signalement : réservé aux administrateurs' USING ERRCODE = '42501';
  END IF;

  -- Verrou de ligne : une seconde décision attend la première, puis voit le
  -- nouveau statut.
  SELECT * INTO r FROM public.reports WHERE id = p_report_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'signalement : introuvable' USING ERRCODE = 'P0002';
  END IF;

  SELECT * INTO t FROM public.moderation_report_transitions
   WHERE from_status = r.status AND to_status = p_to;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'signalement : passage % → % impossible', r.status, p_to
      USING ERRCODE = '55000';
  END IF;

  PERFORM public.admin_require_permission(t.permission);

  -- Un dossier attribué à quelqu'un d'autre se décide par son responsable ;
  -- le superAdmin garde la main, et une reprise (takes_over) se fait par
  -- définition depuis le poste d'un autre.
  IF NOT t.takes_over
     AND r.assigned_to IS NOT NULL AND r.assigned_to <> v_caller
     AND NOT public.is_super_admin() THEN
    RAISE EXCEPTION 'signalement : dossier attribué à un autre modérateur'
      USING ERRCODE = '42501';
  END IF;

  IF length(coalesce(p_note, '')) > 2000 THEN
    RAISE EXCEPTION 'signalement : justification trop longue (2000 max)' USING ERRCODE = '22001';
  END IF;

  IF t.needs_reason THEN
    v_motifs := CASE p_to
      WHEN 'dismissed' THEN ARRAY['rule_not_violated', 'insufficient_evidence',
                                  'content_unavailable', 'duplicate', 'out_of_scope']
      WHEN 'resolved'  THEN ARRAY['content_removed', 'user_warned', 'user_suspended',
                                  'user_banned', 'correction_requested']
      WHEN 'escalated' THEN ARRAY['high_risk', 'conflict_of_interest', 'legal',
                                  'security', 'uncertain']
      ELSE ARRAY[]::text[] END;
    IF p_reason_code IS NULL OR NOT (p_reason_code = ANY (v_motifs)) THEN
      RAISE EXCEPTION 'signalement : motif normalisé requis (%)', array_to_string(v_motifs, ', ')
        USING ERRCODE = '22023';
    END IF;
  END IF;
  IF t.needs_note AND nullif(btrim(coalesce(p_note, '')), '') IS NULL THEN
    RAISE EXCEPTION 'signalement : justification requise' USING ERRCODE = '22023';
  END IF;
  IF t.needs_action AND nullif(btrim(coalesce(p_action_taken, '')), '') IS NULL THEN
    RAISE EXCEPTION 'signalement : action exécutée requise' USING ERRCODE = '22023';
  END IF;

  UPDATE public.reports SET
    status       = p_to,
    reason_code  = CASE WHEN t.needs_reason THEN p_reason_code ELSE reason_code END,
    admin_note   = coalesce(nullif(btrim(p_note), ''), admin_note),
    action_taken = CASE WHEN t.needs_action THEN btrim(p_action_taken) ELSE action_taken END,
    assigned_to  = CASE WHEN t.takes_over THEN v_caller ELSE assigned_to END,
    assigned_at  = CASE WHEN t.takes_over THEN now()    ELSE assigned_at END,
    reviewed_by  = v_caller,
    reviewed_at  = now()
  WHERE id = p_report_id;

  PERFORM public.write_admin_audit(
    t.audit_action, 'report', p_report_id::text, 'success',
    p_reason_code, p_report_id::text,
    jsonb_build_object('from', r.status, 'to', p_to));

  RETURN p_to;
END $$;

REVOKE ALL ON FUNCTION public.signalement_transition(uuid, text, text, text, text)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.signalement_transition(uuid, text, text, text, text)
  TO authenticated;

NOTIFY pgrst, 'reload schema';
