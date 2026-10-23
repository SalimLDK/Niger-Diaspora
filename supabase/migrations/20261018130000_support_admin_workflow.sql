-- Support : le workflow des tickets vit en base, et la table redevient celle
-- que l'application écrit.
--
-- Référentiel d'administration § 10 et spécification d'interfaces § 15.
--
-- ═══ CE QUE LA PRODUCTION AVAIT, ET QUE LE CODE NE SAVAIT PAS ══════════════
--
-- Mesuré le 2026-10-18 sur la base liée : `support_tickets` n'a que les 7
-- colonnes de 20260522223150 (id, user_id, subject, status, messages,
-- created_at, updated_at). Or l'application écrit et lit aussi `user_name`,
-- `user_email`, `description`, `category`, `related_transaction_id`,
-- `has_unread_user_messages`, `has_unread_support_messages`
-- (support_ticket_supabase_datasource.dart) : PostgREST répond « colonne
-- introuvable », donc CRÉER UN TICKET ÉCHOUE. La table compte 0 ligne. Et la
-- seule policy est `support_tickets_own` : aucun administrateur ne lit un
-- ticket. Cette migration ajoute les colonnes manquantes (additif).
--
-- ═══ CE QU'ELLE POSE ═══════════════════════════════════════════════════════
--
-- • Colonnes d'application + colonnes de traitement : `priority`,
--   `assigned_to`, `assigned_at`, `resolution_note`.
-- • `support_ticket_notes` : les notes internes, dans une table à part. Elles
--   ne partent jamais dans `messages`, que l'utilisateur lit.
-- • `support_ticket_transitions` + `support_ticket_transition(...)` : la seule
--   porte de changement de statut côté administration (même modèle que
--   `signalement_transition`), avec audit dans la même transaction.
-- • `support_ticket_reply`, `support_ticket_note`, `support_ticket_set_priority`,
--   `support_ticket_mark_read`.
-- • Cinq permissions, mappées à contentMod (superAdmin a tout).
-- • Un déclencheur de garde : un utilisateur ordinaire n'écrit que ses propres
--   messages (jamais `isFromSupport`), ne touche ni au responsable, ni à la
--   priorité, ni à la note de résolution, et ne fait passer son ticket qu'à
--   `open` ou `closed`. Sans lui, la policy `support_tickets_own` (FOR ALL)
--   laissait écrire n'importe quoi dans sa propre ligne, y compris une réponse
--   « du support ». Un REVOKE par colonne casserait l'application, qui renvoie
--   des lignes entières : on compare les valeurs.
-- • Un administrateur LIT les tickets avec `support.tickets.view` ; il ne les
--   ÉCRIT que par les RPC.
-- • DELETE retiré aux utilisateurs : l'application ne supprime jamais un
--   ticket, et le droit effacerait l'historique d'un litige. La purge de
--   compte passe par `private.purge_delete` (SECURITY DEFINER), non touchée.
--
-- ═══ CE QU'ELLE NE FAIT PAS ═══════════════════════════════════════════════
--
-- • Pas de délai de service (SLA) : « mesurés par catégorie et priorité »
--   demande des durées que personne n'a arrêtées. Pas de colonne `due_at`
--   inventée.
-- • Pas d'escalade (`support.tickets.escalate`) : il n'existe qu'un rôle
--   habilité au support (contentMod) ; escalader vers qui ?
-- • Pas de notification de l'utilisateur (outbox) : la réponse se lit dans le
--   ticket, `has_unread_support_messages` s'allume.
-- • Pas de pièces jointes (tranche suivante).
--
-- Banc : tools/rls_tests/support_admin_workflow.sql.

SET lock_timeout = '5s';

-- ── 1. Colonnes ─────────────────────────────────────────────────────────────
ALTER TABLE public.support_tickets
  ADD COLUMN IF NOT EXISTS user_name  text NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS user_email text NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS description text NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS category   text NOT NULL DEFAULT 'other',
  ADD COLUMN IF NOT EXISTS related_transaction_id text,
  ADD COLUMN IF NOT EXISTS has_unread_user_messages    boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS has_unread_support_messages boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS priority        text NOT NULL DEFAULT 'normal',
  ADD COLUMN IF NOT EXISTS assigned_to     text,
  ADD COLUMN IF NOT EXISTS assigned_at     timestamptz,
  ADD COLUMN IF NOT EXISTS resolution_note text;

ALTER TABLE public.support_tickets DROP CONSTRAINT IF EXISTS support_tickets_category_check;
ALTER TABLE public.support_tickets ADD CONSTRAINT support_tickets_category_check
  CHECK (category IN ('transaction', 'account', 'technical', 'other',
                      'directory', 'privacy', 'complaint', 'appeal', 'security'));
ALTER TABLE public.support_tickets DROP CONSTRAINT IF EXISTS support_tickets_priority_check;
ALTER TABLE public.support_tickets ADD CONSTRAINT support_tickets_priority_check
  CHECK (priority IN ('low', 'normal', 'high', 'urgent'));

CREATE INDEX IF NOT EXISTS support_tickets_file_idx
  ON public.support_tickets (status, priority, created_at)
  WHERE status IN ('open', 'in_progress');

-- ── 2. Permissions ──────────────────────────────────────────────────────────
INSERT INTO public.admin_permissions (key, module, description, legacy_key) VALUES
  ('support.tickets.view',   'support', 'Voir les tickets du support',                NULL),
  ('support.tickets.assign', 'support', 'Prendre en charge un ticket, changer sa priorité', NULL),
  ('support.tickets.reply',  'support', 'Répondre à l''utilisateur, noter en interne', NULL),
  ('support.tickets.close',  'support', 'Clôturer un ticket',                         NULL)
ON CONFLICT (key) DO NOTHING;

INSERT INTO public.admin_role_permissions (role, permission) VALUES
  ('contentMod', 'support.tickets.view'),
  ('contentMod', 'support.tickets.assign'),
  ('contentMod', 'support.tickets.reply'),
  ('contentMod', 'support.tickets.close')
ON CONFLICT DO NOTHING;

-- ── 3. Notes internes ───────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.support_ticket_notes (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  ticket_id  uuid NOT NULL REFERENCES public.support_tickets (id) ON DELETE CASCADE,
  author_id  text NOT NULL,
  body       text NOT NULL CHECK (length(btrim(body)) BETWEEN 1 AND 4000),
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS support_ticket_notes_ticket_idx
  ON public.support_ticket_notes (ticket_id, created_at);

ALTER TABLE public.support_ticket_notes ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.support_ticket_notes FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.support_ticket_notes TO authenticated;
DROP POLICY IF EXISTS support_ticket_notes_select ON public.support_ticket_notes;
CREATE POLICY support_ticket_notes_select ON public.support_ticket_notes
  FOR SELECT TO authenticated
  USING (public.admin_has_permission('support.tickets.view'));

-- ── 4. Lecture administrateur, et droits de la table ────────────────────────
DROP POLICY IF EXISTS support_tickets_admin_select ON public.support_tickets;
CREATE POLICY support_tickets_admin_select ON public.support_tickets
  FOR SELECT TO authenticated
  USING (public.admin_has_permission('support.tickets.view'));

REVOKE ALL ON public.support_tickets FROM PUBLIC, anon;
REVOKE DELETE, TRUNCATE, REFERENCES, TRIGGER ON public.support_tickets FROM authenticated;

-- ── 5. Garde : ce qu'un utilisateur ordinaire peut écrire ───────────────────
-- Les RPC ci-dessous posent `app.support_rpc` pour la durée de leur
-- transaction ; sans session applicative (migration, service_role) le
-- déclencheur laisse passer. Tout le reste — un administrateur écrivant son
-- PROPRE ticket compris — subit les règles de l'utilisateur.
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
       OR NEW.status <> 'open' THEN
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
       OR NEW.resolution_note IS DISTINCT FROM OLD.resolution_note THEN
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

DROP TRIGGER IF EXISTS support_tickets_guard ON public.support_tickets;
CREATE TRIGGER support_tickets_guard
  BEFORE INSERT OR UPDATE ON public.support_tickets
  FOR EACH ROW EXECUTE FUNCTION public.support_tickets_guard();

-- ── 6. Les transitions permises ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.support_ticket_transitions (
  from_status  text NOT NULL,
  to_status    text NOT NULL,
  permission   text NOT NULL REFERENCES public.admin_permissions (key),
  audit_action text NOT NULL,
  needs_note   boolean NOT NULL DEFAULT false,
  takes_over   boolean NOT NULL DEFAULT false,
  PRIMARY KEY (from_status, to_status)
);

INSERT INTO public.support_ticket_transitions
  (from_status, to_status, permission, audit_action, needs_note, takes_over)
VALUES
  ('open',        'in_progress', 'support.tickets.assign', 'TICKET_ASSIGNED',   false, true),
  ('in_progress', 'in_progress', 'support.tickets.assign', 'TICKET_REASSIGNED', true,  true),
  ('in_progress', 'resolved',    'support.tickets.reply',  'TICKET_RESOLVED',   true,  false),
  ('in_progress', 'closed',      'support.tickets.close',  'TICKET_CLOSED',     true,  false),
  ('resolved',    'closed',      'support.tickets.close',  'TICKET_CLOSED',     true,  false),
  ('resolved',    'in_progress', 'support.tickets.assign', 'TICKET_REOPENED',   true,  true)
ON CONFLICT (from_status, to_status) DO NOTHING;

ALTER TABLE public.support_ticket_transitions ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.support_ticket_transitions FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.support_ticket_transitions TO authenticated;
DROP POLICY IF EXISTS support_ticket_transitions_select ON public.support_ticket_transitions;
CREATE POLICY support_ticket_transitions_select ON public.support_ticket_transitions
  FOR SELECT TO authenticated USING (public.is_admin());

-- ── 7. La porte unique des statuts ──────────────────────────────────────────
DROP FUNCTION IF EXISTS public.support_ticket_transition(uuid, text, text);

CREATE FUNCTION public.support_ticket_transition(
  p_id   uuid,
  p_to   text,
  p_note text DEFAULT NULL
) RETURNS text
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller text := (SELECT public.firebase_uid());
  k        public.support_tickets%ROWTYPE;
  t        public.support_ticket_transitions%ROWTYPE;
BEGIN
  IF v_caller IS NULL OR NOT public.is_admin() THEN
    RAISE EXCEPTION 'ticket : réservé aux administrateurs' USING ERRCODE = '42501';
  END IF;

  SELECT * INTO k FROM public.support_tickets WHERE id = p_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'ticket : introuvable' USING ERRCODE = 'P0002';
  END IF;

  SELECT * INTO t FROM public.support_ticket_transitions
   WHERE from_status = k.status AND to_status = p_to;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'ticket : passage % → % impossible', k.status, p_to USING ERRCODE = '55000';
  END IF;

  PERFORM public.admin_require_permission(t.permission);

  IF NOT t.takes_over AND k.assigned_to IS DISTINCT FROM v_caller
     AND NOT public.is_super_admin() THEN
    RAISE EXCEPTION 'ticket : attribué à un autre agent' USING ERRCODE = '42501';
  END IF;
  IF length(coalesce(p_note, '')) > 2000 THEN
    RAISE EXCEPTION 'ticket : note trop longue (2000 max)' USING ERRCODE = '22001';
  END IF;
  IF t.needs_note AND nullif(btrim(coalesce(p_note, '')), '') IS NULL THEN
    RAISE EXCEPTION 'ticket : motif ou résolution requis' USING ERRCODE = '22023';
  END IF;

  PERFORM set_config('app.support_rpc', 'on', true);
  UPDATE public.support_tickets SET
    status          = p_to,
    assigned_to     = CASE WHEN t.takes_over THEN v_caller ELSE assigned_to END,
    assigned_at     = CASE WHEN t.takes_over THEN now()    ELSE assigned_at END,
    resolution_note = CASE WHEN p_to IN ('resolved', 'closed')
                           THEN nullif(btrim(p_note), '') ELSE resolution_note END,
    updated_at      = now()
  WHERE id = p_id;
  PERFORM set_config('app.support_rpc', 'off', true);

  PERFORM public.write_admin_audit(
    t.audit_action, 'support_ticket', p_id::text, 'success',
    NULL, p_id::text,
    jsonb_build_object('from', k.status, 'to', p_to));
  RETURN p_to;
END $$;

-- ── 8. Répondre à l'utilisateur ─────────────────────────────────────────────
DROP FUNCTION IF EXISTS public.support_ticket_reply(uuid, text);

CREATE FUNCTION public.support_ticket_reply(p_id uuid, p_body text) RETURNS text
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller text := (SELECT public.firebase_uid());
  k        public.support_tickets%ROWTYPE;
  v_msg_id text;
BEGIN
  IF v_caller IS NULL OR NOT public.is_admin() THEN
    RAISE EXCEPTION 'ticket : réservé aux administrateurs' USING ERRCODE = '42501';
  END IF;
  PERFORM public.admin_require_permission('support.tickets.reply');

  IF p_body IS NULL OR length(btrim(p_body)) < 1 OR length(p_body) > 4000 THEN
    RAISE EXCEPTION 'ticket : réponse requise (4000 caractères au plus)' USING ERRCODE = '22023';
  END IF;

  SELECT * INTO k FROM public.support_tickets WHERE id = p_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'ticket : introuvable' USING ERRCODE = 'P0002';
  END IF;
  IF k.status <> 'in_progress' THEN
    RAISE EXCEPTION 'ticket : le ticket doit être pris en charge pour répondre (statut %)', k.status
      USING ERRCODE = '55000';
  END IF;
  IF k.assigned_to IS DISTINCT FROM v_caller AND NOT public.is_super_admin() THEN
    RAISE EXCEPTION 'ticket : attribué à un autre agent' USING ERRCODE = '42501';
  END IF;

  v_msg_id := 'msg_' || (extract(epoch FROM clock_timestamp()) * 1000)::bigint;
  PERFORM set_config('app.support_rpc', 'on', true);
  UPDATE public.support_tickets SET
    messages = coalesce(messages, '[]'::jsonb) || jsonb_build_array(jsonb_build_object(
      'id', v_msg_id,
      'senderId', v_caller,
      -- Le nom de l'agent n'est pas montré à l'utilisateur : le support parle
      -- d'une seule voix, l'auteur est dans l'audit.
      'senderName', 'Support Diaspo Niger',
      'isFromSupport', true,
      'content', btrim(p_body),
      'createdAt', to_char(now() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"'))),
    has_unread_support_messages = true,
    updated_at = now()
  WHERE id = p_id;
  PERFORM set_config('app.support_rpc', 'off', true);

  -- L'audit ne porte pas le texte de la réponse.
  PERFORM public.write_admin_audit(
    'TICKET_REPLIED', 'support_ticket', p_id::text, 'success',
    NULL, p_id::text, jsonb_build_object('message', v_msg_id));
  RETURN v_msg_id;
END $$;

-- ── 9. Note interne ─────────────────────────────────────────────────────────
DROP FUNCTION IF EXISTS public.support_ticket_note(uuid, text);

CREATE FUNCTION public.support_ticket_note(p_id uuid, p_body text) RETURNS uuid
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller text := (SELECT public.firebase_uid());
  v_id     uuid;
BEGIN
  IF v_caller IS NULL OR NOT public.is_admin() THEN
    RAISE EXCEPTION 'ticket : réservé aux administrateurs' USING ERRCODE = '42501';
  END IF;
  PERFORM public.admin_require_permission('support.tickets.reply');

  IF p_body IS NULL OR length(btrim(p_body)) < 1 OR length(p_body) > 4000 THEN
    RAISE EXCEPTION 'ticket : note requise (4000 caractères au plus)' USING ERRCODE = '22023';
  END IF;
  PERFORM 1 FROM public.support_tickets WHERE id = p_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'ticket : introuvable' USING ERRCODE = 'P0002';
  END IF;

  INSERT INTO public.support_ticket_notes (ticket_id, author_id, body)
  VALUES (p_id, v_caller, btrim(p_body)) RETURNING id INTO v_id;

  PERFORM public.write_admin_audit(
    'TICKET_NOTE_ADDED', 'support_ticket', p_id::text, 'success',
    NULL, p_id::text, jsonb_build_object('note', v_id));
  RETURN v_id;
END $$;

-- ── 10. Priorité ────────────────────────────────────────────────────────────
DROP FUNCTION IF EXISTS public.support_ticket_set_priority(uuid, text);

CREATE FUNCTION public.support_ticket_set_priority(p_id uuid, p_priority text) RETURNS text
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller text := (SELECT public.firebase_uid());
  k        public.support_tickets%ROWTYPE;
BEGIN
  IF v_caller IS NULL OR NOT public.is_admin() THEN
    RAISE EXCEPTION 'ticket : réservé aux administrateurs' USING ERRCODE = '42501';
  END IF;
  PERFORM public.admin_require_permission('support.tickets.assign');

  IF p_priority IS NULL OR p_priority NOT IN ('low', 'normal', 'high', 'urgent') THEN
    RAISE EXCEPTION 'ticket : priorité invalide (low, normal, high, urgent)' USING ERRCODE = '22023';
  END IF;
  SELECT * INTO k FROM public.support_tickets WHERE id = p_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'ticket : introuvable' USING ERRCODE = 'P0002';
  END IF;
  IF k.status IN ('resolved', 'closed') THEN
    RAISE EXCEPTION 'ticket : priorité figée sur un ticket %', k.status USING ERRCODE = '55000';
  END IF;

  PERFORM set_config('app.support_rpc', 'on', true);
  UPDATE public.support_tickets SET priority = p_priority, updated_at = now()
   WHERE id = p_id;
  PERFORM set_config('app.support_rpc', 'off', true);

  PERFORM public.write_admin_audit(
    'TICKET_PRIORITY_CHANGED', 'support_ticket', p_id::text, 'success',
    NULL, p_id::text, jsonb_build_object('from', k.priority, 'to', p_priority));
  RETURN p_priority;
END $$;

-- ── 11. Marquer les messages de l'utilisateur comme lus ─────────────────────
-- Pas d'audit : consulter un ticket n'est pas une action sensible.
DROP FUNCTION IF EXISTS public.support_ticket_mark_read(uuid);

CREATE FUNCTION public.support_ticket_mark_read(p_id uuid) RETURNS void
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF (SELECT public.firebase_uid()) IS NULL OR NOT public.is_admin() THEN
    RAISE EXCEPTION 'ticket : réservé aux administrateurs' USING ERRCODE = '42501';
  END IF;
  PERFORM public.admin_require_permission('support.tickets.view');

  PERFORM set_config('app.support_rpc', 'on', true);
  UPDATE public.support_tickets SET has_unread_user_messages = false
   WHERE id = p_id AND has_unread_user_messages;
  PERFORM set_config('app.support_rpc', 'off', true);
END $$;

-- ── 12. Droits d'exécution ──────────────────────────────────────────────────
REVOKE ALL ON FUNCTION public.support_ticket_transition(uuid, text, text)   FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.support_ticket_reply(uuid, text)              FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.support_ticket_note(uuid, text)               FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.support_ticket_set_priority(uuid, text)       FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.support_ticket_mark_read(uuid)                FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.support_ticket_transition(uuid, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.support_ticket_reply(uuid, text)            TO authenticated;
GRANT EXECUTE ON FUNCTION public.support_ticket_note(uuid, text)             TO authenticated;
GRANT EXECUTE ON FUNCTION public.support_ticket_set_priority(uuid, text)     TO authenticated;
GRANT EXECUTE ON FUNCTION public.support_ticket_mark_read(uuid)              TO authenticated;

NOTIFY pgrst, 'reload schema';
