-- Support : délais de service, escalade, modèles de réponse.
--
-- Référentiel d'administration § 10 et spécification d'interfaces § 15.
--
-- ═══ CE QU'ELLE POSE ═══════════════════════════════════════════════════════
--
-- • `support_sla_targets` : les délais cibles par catégorie ET priorité, en
--   heures (première réponse, résolution). La table naît VIDE : aucune durée
--   n'est inventée ici. Un superAdmin les arrête (`support_sla_set`, audité) ;
--   tant qu'une cible n'existe pas, le ticket n'a pas d'échéance et n'est
--   jamais « en retard ». `support_sla_status()` rend, pour chaque ticket
--   ouvert ou en cours qui a une cible, ses échéances et ses dépassements.
-- • L'escalade : un agent (`support.tickets.escalate`, contentMod) signale un
--   ticket qui le dépasse, avec un motif ; il entre dans la file du superAdmin,
--   seul autre rôle du support. Lever l'escalade
--   (`support.tickets.escalation.resolve`) est réservé au superAdmin. Le motif
--   vit sur le ticket, jamais dans l'audit.
-- • `support_reply_templates` : les modèles de réponse, de simples textes que
--   l'agent insère puis relit avant d'envoyer. Écrits par RPC (audit sans le
--   texte), lus par qui peut répondre.
--
-- ═══ CE QU'ELLE NE FAIT PAS ═══════════════════════════════════════════════
--
-- • Les heures sont des heures d'horloge, pas des heures ouvrées : aucun
--   calendrier de travail n'existe pour le support.
-- • Pas de pièces jointes : elles passent par Storage, dont les règles se
--   décident avec le bucket, pas ici.
-- • Pas de notification de l'escalade.
--
-- Banc : tools/rls_tests/support_sla_escalade_modeles.sql.

SET lock_timeout = '5s';

-- ── 1. Permissions ──────────────────────────────────────────────────────────
INSERT INTO public.admin_permissions (key, module, description, legacy_key) VALUES
  ('support.tickets.escalate',           'support', 'Escalader un ticket vers le superAdmin', NULL),
  ('support.tickets.escalation.resolve', 'support', 'Lever l''escalade d''un ticket',          NULL),
  ('support.sla.manage',                 'support', 'Arrêter les délais de service',           NULL),
  ('support.templates.manage',           'support', 'Gérer les modèles de réponse',            NULL)
ON CONFLICT (key) DO NOTHING;

-- escalation.resolve et sla.manage : aucun rôle, donc superAdmin seul.
INSERT INTO public.admin_role_permissions (role, permission) VALUES
  ('contentMod', 'support.tickets.escalate'),
  ('contentMod', 'support.templates.manage')
ON CONFLICT DO NOTHING;

-- ── 2. Colonnes d'escalade ─────────────────────────────────────────────────
ALTER TABLE public.support_tickets
  ADD COLUMN IF NOT EXISTS escalated_at      timestamptz,
  ADD COLUMN IF NOT EXISTS escalated_by      text,
  ADD COLUMN IF NOT EXISTS escalation_reason text;

CREATE INDEX IF NOT EXISTS support_tickets_escalated_idx
  ON public.support_tickets (escalated_at) WHERE escalated_at IS NOT NULL;

-- ── 3. Garde : l'utilisateur ne touche pas à l'escalade ─────────────────────
-- Même fonction que 20261018130000, avec les trois colonnes d'escalade en plus.
CREATE OR REPLACE FUNCTION public.support_tickets_guard()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public, pg_temp
AS $$
DECLARE
  v_uid text := (SELECT public.firebase_uid());
  m     jsonb;
  i     int;
  n_old int;
  v_old jsonb;
BEGIN
  IF v_uid IS NULL OR current_setting('app.support_rpc', true) = 'on' THEN
    RETURN NEW;
  END IF;

  IF TG_OP = 'INSERT' THEN
    IF NEW.assigned_to IS NOT NULL OR NEW.assigned_at IS NOT NULL
       OR NEW.resolution_note IS NOT NULL OR NEW.priority <> 'normal'
       OR NEW.status <> 'open'
       OR NEW.escalated_at IS NOT NULL OR NEW.escalated_by IS NOT NULL
       OR NEW.escalation_reason IS NOT NULL THEN
      RAISE EXCEPTION 'ticket : colonnes de traitement réservées au support'
        USING ERRCODE = '42501';
    END IF;
    n_old := 0;
    v_old := NULL;
  ELSE
    IF NEW.user_id IS DISTINCT FROM OLD.user_id
       OR NEW.assigned_to IS DISTINCT FROM OLD.assigned_to
       OR NEW.assigned_at IS DISTINCT FROM OLD.assigned_at
       OR NEW.priority IS DISTINCT FROM OLD.priority
       OR NEW.resolution_note IS DISTINCT FROM OLD.resolution_note
       OR NEW.escalated_at IS DISTINCT FROM OLD.escalated_at
       OR NEW.escalated_by IS DISTINCT FROM OLD.escalated_by
       OR NEW.escalation_reason IS DISTINCT FROM OLD.escalation_reason THEN
      RAISE EXCEPTION 'ticket : colonnes de traitement réservées au support'
        USING ERRCODE = '42501';
    END IF;
    -- L'utilisateur confirme (closed) ou rouvre (open) ; il ne se met pas
    -- « en cours » ni « résolu ».
    IF NEW.status IS DISTINCT FROM OLD.status AND NEW.status NOT IN ('open', 'closed') THEN
      RAISE EXCEPTION 'ticket : statut % réservé au support', NEW.status
        USING ERRCODE = '42501';
    END IF;
    v_old := OLD.messages;
    n_old := CASE WHEN jsonb_typeof(v_old) = 'array'
                  THEN jsonb_array_length(v_old) ELSE 0 END;
  END IF;

  IF NEW.messages IS DISTINCT FROM v_old THEN
    IF jsonb_typeof(NEW.messages) <> 'array'
       OR jsonb_array_length(NEW.messages) < n_old THEN
      RAISE EXCEPTION 'ticket : l''historique des messages ne se réécrit pas'
        USING ERRCODE = '42501';
    END IF;
    FOR i IN 0 .. n_old - 1 LOOP
      IF NEW.messages -> i IS DISTINCT FROM v_old -> i THEN
        RAISE EXCEPTION 'ticket : un message envoyé ne se modifie pas'
          USING ERRCODE = '42501';
      END IF;
    END LOOP;
    FOR i IN n_old .. jsonb_array_length(NEW.messages) - 1 LOOP
      m := NEW.messages -> i;
      IF coalesce((m ->> 'isFromSupport')::boolean, false)
         OR (m ->> 'senderId') IS DISTINCT FROM v_uid THEN
        RAISE EXCEPTION 'ticket : vous ne pouvez écrire qu''en votre nom'
          USING ERRCODE = '42501';
      END IF;
    END LOOP;
  END IF;

  RETURN NEW;
END $$;

-- ── 4. Délais cibles ───────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.support_sla_targets (
  category             text NOT NULL,
  priority             text NOT NULL,
  first_response_hours integer CHECK (first_response_hours BETWEEN 1 AND 8760),
  resolution_hours     integer CHECK (resolution_hours BETWEEN 1 AND 8760),
  updated_by           text,
  updated_at           timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (category, priority),
  CHECK (category IN ('transaction','account','technical','other','directory',
                      'privacy','complaint','appeal','security')),
  CHECK (priority IN ('low','normal','high','urgent')),
  CHECK (first_response_hours IS NOT NULL OR resolution_hours IS NOT NULL)
);
ALTER TABLE public.support_sla_targets ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.support_sla_targets FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.support_sla_targets TO authenticated;
DROP POLICY IF EXISTS support_sla_targets_select ON public.support_sla_targets;
CREATE POLICY support_sla_targets_select ON public.support_sla_targets
  FOR SELECT TO authenticated
  USING (public.admin_has_permission('support.tickets.view'));

-- Les deux durées à NULL ensemble : la cible est retirée.
DROP FUNCTION IF EXISTS public.support_sla_set(text, text, integer, integer);
CREATE FUNCTION public.support_sla_set(
  p_category text, p_priority text, p_first_hours integer, p_resolution_hours integer
) RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE v_caller text := (SELECT public.firebase_uid());
BEGIN
  IF v_caller IS NULL OR NOT public.is_admin() THEN
    RAISE EXCEPTION 'sla : réservé aux administrateurs' USING ERRCODE = '42501';
  END IF;
  PERFORM public.admin_require_permission('support.sla.manage');
  IF p_category IS NULL OR p_priority IS NULL
     OR p_category NOT IN ('transaction','account','technical','other','directory',
                           'privacy','complaint','appeal','security')
     OR p_priority NOT IN ('low','normal','high','urgent') THEN
    RAISE EXCEPTION 'sla : catégorie ou priorité invalide' USING ERRCODE = '22023';
  END IF;
  IF p_first_hours IS NULL AND p_resolution_hours IS NULL THEN
    DELETE FROM public.support_sla_targets WHERE category = p_category AND priority = p_priority;
  ELSE
    IF (p_first_hours IS NOT NULL AND p_first_hours NOT BETWEEN 1 AND 8760)
       OR (p_resolution_hours IS NOT NULL AND p_resolution_hours NOT BETWEEN 1 AND 8760) THEN
      RAISE EXCEPTION 'sla : durées de 1 à 8760 heures' USING ERRCODE = '22023';
    END IF;
    IF p_first_hours IS NOT NULL AND p_resolution_hours IS NOT NULL
       AND p_first_hours > p_resolution_hours THEN
      RAISE EXCEPTION 'sla : la première réponse ne peut pas suivre la résolution'
        USING ERRCODE = '22023';
    END IF;
    INSERT INTO public.support_sla_targets
      (category, priority, first_response_hours, resolution_hours, updated_by, updated_at)
    VALUES (p_category, p_priority, p_first_hours, p_resolution_hours, v_caller, now())
    ON CONFLICT (category, priority) DO UPDATE SET
      first_response_hours = EXCLUDED.first_response_hours,
      resolution_hours = EXCLUDED.resolution_hours,
      updated_by = EXCLUDED.updated_by, updated_at = now();
  END IF;
  PERFORM public.write_admin_audit(
    'SUPPORT_SLA_SET', 'support_sla', p_category || ':' || p_priority, 'success',
    NULL, NULL, jsonb_build_object('first', p_first_hours, 'resolution', p_resolution_hours));
END $$;

-- Échéances des tickets ouverts ou en cours qui ont une cible. Heures d'horloge.
DROP FUNCTION IF EXISTS public.support_sla_status();
CREATE FUNCTION public.support_sla_status() RETURNS TABLE (
  ticket_id uuid, first_response_due timestamptz, first_response_at timestamptz,
  first_response_late boolean, resolution_due timestamptz, resolution_late boolean)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF (SELECT public.firebase_uid()) IS NULL OR NOT public.is_admin() THEN
    RAISE EXCEPTION 'sla : réservé aux administrateurs' USING ERRCODE = '42501';
  END IF;
  PERFORM public.admin_require_permission('support.tickets.view');
  RETURN QUERY
  WITH base AS (
    SELECT k.id, k.created_at, s.first_response_hours AS fh, s.resolution_hours AS rh,
           (SELECT min((m ->> 'createdAt')::timestamptz)
              FROM jsonb_array_elements(CASE WHEN jsonb_typeof(k.messages) = 'array'
                                             THEN k.messages ELSE '[]'::jsonb END) m
             WHERE coalesce((m ->> 'isFromSupport')::boolean, false)) AS rep
      FROM public.support_tickets k
      JOIN public.support_sla_targets s ON s.category = k.category AND s.priority = k.priority
     WHERE k.status IN ('open', 'in_progress'))
  SELECT b.id,
         b.created_at + make_interval(hours => b.fh),
         b.rep,
         CASE WHEN b.fh IS NULL THEN NULL
              ELSE coalesce(b.rep, now()) > b.created_at + make_interval(hours => b.fh) END,
         b.created_at + make_interval(hours => b.rh),
         CASE WHEN b.rh IS NULL THEN NULL
              ELSE now() > b.created_at + make_interval(hours => b.rh) END
    FROM base b;
END $$;

-- ── 5. Escalade ────────────────────────────────────────────────────────────
DROP FUNCTION IF EXISTS public.support_ticket_escalate(uuid, text);
CREATE FUNCTION public.support_ticket_escalate(p_id uuid, p_reason text) RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller text := (SELECT public.firebase_uid());
  k public.support_tickets%ROWTYPE;
BEGIN
  IF v_caller IS NULL OR NOT public.is_admin() THEN
    RAISE EXCEPTION 'ticket : réservé aux administrateurs' USING ERRCODE = '42501';
  END IF;
  PERFORM public.admin_require_permission('support.tickets.escalate');
  IF p_reason IS NULL OR length(btrim(p_reason)) < 3 OR length(p_reason) > 1000 THEN
    RAISE EXCEPTION 'ticket : motif requis (3 à 1000 caractères)' USING ERRCODE = '22023';
  END IF;
  SELECT * INTO k FROM public.support_tickets WHERE id = p_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'ticket : introuvable' USING ERRCODE = 'P0002';
  END IF;
  IF k.status IN ('resolved', 'closed') THEN
    RAISE EXCEPTION 'ticket : on n''escalade pas un ticket %', k.status USING ERRCODE = '55000';
  END IF;
  IF k.escalated_at IS NOT NULL THEN
    RAISE EXCEPTION 'ticket : déjà escaladé' USING ERRCODE = '55000';
  END IF;
  PERFORM set_config('app.support_rpc', 'on', true);
  UPDATE public.support_tickets SET escalated_at = now(), escalated_by = v_caller,
    escalation_reason = btrim(p_reason), updated_at = now() WHERE id = p_id;
  PERFORM set_config('app.support_rpc', 'off', true);
  PERFORM public.write_admin_audit(
    'TICKET_ESCALATED', 'support_ticket', p_id::text, 'success', NULL, p_id::text, '{}'::jsonb);
END $$;

DROP FUNCTION IF EXISTS public.support_ticket_escalation_resolve(uuid);
CREATE FUNCTION public.support_ticket_escalation_resolve(p_id uuid) RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller text := (SELECT public.firebase_uid());
  k public.support_tickets%ROWTYPE;
BEGIN
  IF v_caller IS NULL OR NOT public.is_admin() THEN
    RAISE EXCEPTION 'ticket : réservé aux administrateurs' USING ERRCODE = '42501';
  END IF;
  PERFORM public.admin_require_permission('support.tickets.escalation.resolve');
  SELECT * INTO k FROM public.support_tickets WHERE id = p_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'ticket : introuvable' USING ERRCODE = 'P0002';
  END IF;
  IF k.escalated_at IS NULL THEN
    RAISE EXCEPTION 'ticket : pas escaladé' USING ERRCODE = '55000';
  END IF;
  PERFORM set_config('app.support_rpc', 'on', true);
  UPDATE public.support_tickets SET escalated_at = NULL, escalated_by = NULL,
    escalation_reason = NULL, updated_at = now() WHERE id = p_id;
  PERFORM set_config('app.support_rpc', 'off', true);
  PERFORM public.write_admin_audit(
    'TICKET_ESCALATION_RESOLVED', 'support_ticket', p_id::text, 'success', NULL, p_id::text,
    jsonb_build_object('escalated_by', k.escalated_by));
END $$;

-- ── 6. Modèles de réponse ──────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.support_reply_templates (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  title      text NOT NULL CHECK (length(btrim(title)) BETWEEN 1 AND 120),
  body       text NOT NULL CHECK (length(btrim(body)) BETWEEN 1 AND 4000),
  category   text,
  created_by text NOT NULL,
  updated_at timestamptz NOT NULL DEFAULT now(),
  CHECK (category IS NULL OR category IN ('transaction','account','technical','other',
         'directory','privacy','complaint','appeal','security'))
);
ALTER TABLE public.support_reply_templates ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.support_reply_templates FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.support_reply_templates TO authenticated;
DROP POLICY IF EXISTS support_reply_templates_select ON public.support_reply_templates;
CREATE POLICY support_reply_templates_select ON public.support_reply_templates
  FOR SELECT TO authenticated
  USING (public.admin_has_permission('support.tickets.reply'));

DROP FUNCTION IF EXISTS public.support_template_save(uuid, text, text, text);
CREATE FUNCTION public.support_template_save(
  p_id uuid, p_title text, p_body text, p_category text
) RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller text := (SELECT public.firebase_uid());
  v_id uuid;
BEGIN
  IF v_caller IS NULL OR NOT public.is_admin() THEN
    RAISE EXCEPTION 'modèle : réservé aux administrateurs' USING ERRCODE = '42501';
  END IF;
  PERFORM public.admin_require_permission('support.templates.manage');
  IF p_title IS NULL OR length(btrim(p_title)) NOT BETWEEN 1 AND 120
     OR p_body IS NULL OR length(btrim(p_body)) NOT BETWEEN 1 AND 4000 THEN
    RAISE EXCEPTION 'modèle : titre (120) et texte (4000) requis' USING ERRCODE = '22023';
  END IF;
  IF p_category IS NOT NULL AND p_category NOT IN ('transaction','account','technical',
       'other','directory','privacy','complaint','appeal','security') THEN
    RAISE EXCEPTION 'modèle : catégorie invalide' USING ERRCODE = '22023';
  END IF;
  IF p_id IS NULL THEN
    INSERT INTO public.support_reply_templates (title, body, category, created_by)
    VALUES (btrim(p_title), btrim(p_body), p_category, v_caller) RETURNING id INTO v_id;
  ELSE
    UPDATE public.support_reply_templates SET title = btrim(p_title), body = btrim(p_body),
      category = p_category, updated_at = now() WHERE id = p_id RETURNING id INTO v_id;
    IF v_id IS NULL THEN
      RAISE EXCEPTION 'modèle : introuvable' USING ERRCODE = 'P0002';
    END IF;
  END IF;
  PERFORM public.write_admin_audit(
    'SUPPORT_TEMPLATE_SAVED', 'support_template', v_id::text, 'success', NULL, NULL, '{}'::jsonb);
  RETURN v_id;
END $$;

DROP FUNCTION IF EXISTS public.support_template_delete(uuid);
CREATE FUNCTION public.support_template_delete(p_id uuid) RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF (SELECT public.firebase_uid()) IS NULL OR NOT public.is_admin() THEN
    RAISE EXCEPTION 'modèle : réservé aux administrateurs' USING ERRCODE = '42501';
  END IF;
  PERFORM public.admin_require_permission('support.templates.manage');
  DELETE FROM public.support_reply_templates WHERE id = p_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'modèle : introuvable' USING ERRCODE = 'P0002';
  END IF;
  PERFORM public.write_admin_audit(
    'SUPPORT_TEMPLATE_DELETED', 'support_template', p_id::text, 'success', NULL, NULL, '{}'::jsonb);
END $$;

-- ── 7. Droits d'exécution ──────────────────────────────────────────────────
REVOKE ALL ON FUNCTION public.support_sla_set(text, text, integer, integer) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.support_sla_status()                          FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.support_ticket_escalate(uuid, text)           FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.support_ticket_escalation_resolve(uuid)       FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.support_template_save(uuid, text, text, text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.support_template_delete(uuid)                 FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.support_sla_set(text, text, integer, integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.support_sla_status()                          TO authenticated;
GRANT EXECUTE ON FUNCTION public.support_ticket_escalate(uuid, text)           TO authenticated;
GRANT EXECUTE ON FUNCTION public.support_ticket_escalation_resolve(uuid)       TO authenticated;
GRANT EXECUTE ON FUNCTION public.support_template_save(uuid, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.support_template_delete(uuid)                 TO authenticated;
