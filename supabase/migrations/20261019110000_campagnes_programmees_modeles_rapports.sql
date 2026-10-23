-- Campagnes : programmation, modèles de messages, rapport d'envoi.
--
-- Suite de 20261018210000. Elle lève trois limites que celle-ci avait nommées.
--
-- ═══ UNE ERREUR À CORRIGER D'ABORD ═════════════════════════════════════════
--
-- L'en-tête de 20261018210000 (et ce que j'ai écrit à l'utilisateur) disait
-- qu'aucun exécuteur planifié n'existait sur ce projet, « pas de pg_cron posé ».
-- C'est FAUX : `pg_cron` 1.6.4 est installé et `cron.job` porte déjà des tâches
-- (relances toutes les 15 minutes, tâches quotidiennes à 9 h, départs des
-- groupes officiels…). La programmation était donc possible dès le départ.
-- Constaté le 2026-10-18 en lisant `cron.job`.
--
-- ═══ CE QUE CETTE MIGRATION POSE ═══════════════════════════════════════════
--
-- • `campaigns.scheduled_at` et `campaign_schedule(id, quand)` : on programme
--   un brouillon (ou un refusé) entre 5 minutes et 90 jours. L'approbation
--   porte donc sur le texte, l'audience ET l'heure ; approuver une heure déjà
--   passée est refusé (22023). Une campagne programmée ne s'envoie plus à la
--   main (55000) : elle part à son heure, ou s'annule.
-- • `private.campaign_send_due()` et une tâche `pg_cron` toutes les 5 minutes
--   (`campaign_send_due`) : elle envoie, par lots de 200, les campagnes
--   APPROUVÉES dont l'heure est venue — jamais une campagne qui n'a pas été
--   approuvée, jamais une campagne sans heure. Une campagne qui échoue est
--   isolée (sous-transaction) et tracée ; les autres partent. La même
--   logique d'envoi sert l'envoi manuel et la tâche (`private.campaign_send_core`),
--   donc les mêmes garanties : un compte n'est jamais notifié deux fois.
-- • L'audit de la tâche est écrit sous l'acteur `system:cron`, avec le même
--   journal que les humains.
-- • `campaign_templates` : des modèles de messages (nom, type, titre, texte),
--   sans audience ni heure — rédigés, archivés, réutilisés dans l'éditeur.
--   Un modèle n'approuve rien : la campagne qui en part reste soumise à
--   l'approbation habituelle.
-- • `campaign_report(id)` : le rapport d'envoi — notifications créées, comptes
--   ignorés pour préférences, restants, comptes joignables par push (porteurs
--   d'un jeton), délai entre l'heure programmée et le départ, durée de l'envoi.
--
-- ═══ CE QU'ELLE NE FAIT PAS ═════════════════════════════════════════════════
--
-- • Aucune mesure de LIVRAISON ni de lecture : « joignables par push » compte
--   les comptes qui ont un jeton, pas ceux qui ont reçu. La livraison réelle
--   se lit dans `net._http_response` (recette du 2026-09-15).
-- • Pas de canal courriel, pas de clics.
-- • Une campagne approuvée et programmée dont l'heure passe pendant une
--   panne de la tâche part au prochain passage (elle n'est pas perdue), mais
--   en retard : le rapport chiffre ce retard.
--
-- Banc : tools/rls_tests/campagnes_programmees.sql.

SET lock_timeout = '5s';

-- ── 1. Colonne, permission, modèles ─────────────────────────────────────────
ALTER TABLE public.campaigns ADD COLUMN IF NOT EXISTS scheduled_at timestamptz;
CREATE INDEX IF NOT EXISTS campaigns_due_idx
  ON public.campaigns (scheduled_at) WHERE status IN ('approved', 'sending');

CREATE TABLE IF NOT EXISTS public.campaign_templates (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name        text NOT NULL CHECK (length(btrim(name)) BETWEEN 3 AND 60),
  type        text NOT NULL
              CHECK (type IN ('transactional', 'security', 'official_info', 'promotional')),
  title       text NOT NULL CHECK (length(btrim(title)) BETWEEN 3 AND 80),
  body        text NOT NULL CHECK (length(btrim(body)) BETWEEN 10 AND 300),
  created_by  text NOT NULL,
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now(),
  archived_at timestamptz
);
-- Un nom par modèle vivant.
CREATE UNIQUE INDEX IF NOT EXISTS campaign_templates_name_uidx
  ON public.campaign_templates (lower(btrim(name))) WHERE archived_at IS NULL;

ALTER TABLE public.campaign_templates ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.campaign_templates FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.campaign_templates TO authenticated;
DROP POLICY IF EXISTS campaign_templates_select ON public.campaign_templates;
CREATE POLICY campaign_templates_select ON public.campaign_templates
  FOR SELECT TO authenticated USING (public.admin_has_permission('communications.view'));

-- ── 2. Un écrivain d'audit sans session (la tâche n'est pas un administrateur) ──
DROP FUNCTION IF EXISTS private.audit_ecrire(text, text, text, text, text, text, jsonb);

CREATE FUNCTION private.audit_ecrire(
  p_actor    text,
  p_name     text,
  p_action   text,
  p_resource text,
  p_id       text,
  p_result   text,
  p_meta     jsonb
) RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  INSERT INTO public.admin_audit_logs
    (admin_id, admin_name, action, target_type, target_id, details, result, correlation_id)
  VALUES (p_actor, p_name, p_action, p_resource, p_id, coalesce(p_meta, '{}'::jsonb),
          p_result, p_id);
END $$;

REVOKE ALL ON FUNCTION private.audit_ecrire(text, text, text, text, text, text, jsonb)
  FROM PUBLIC, anon, authenticated;

-- ── 3. Le cœur de l'envoi, commun à la main et à la tâche ───────────────────
DROP FUNCTION IF EXISTS private.campaign_send_core(uuid, integer, text, text);

CREATE FUNCTION private.campaign_send_core(
  p_id    uuid,
  p_limit integer,
  p_actor text,
  p_name  text
) RETURNS jsonb
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  c         public.campaigns%ROWTYPE;
  v_respect boolean;
  v_notif   uuid;
  v_n       int := 0;
  v_creees  int := 0;
  v_restent int;
  u         record;
BEGIN
  -- Le verrou de ligne sérialise deux envois simultanés (main + tâche).
  SELECT * INTO c FROM public.campaigns WHERE id = p_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'campagne : introuvable' USING ERRCODE = 'P0002';
  END IF;
  IF c.status NOT IN ('approved', 'sending') THEN
    RAISE EXCEPTION 'campagne : envoi impossible depuis le statut %', c.status
      USING ERRCODE = '55000';
  END IF;

  IF c.status = 'approved' THEN
    UPDATE public.campaigns SET status = 'sending', send_started_at = now(), updated_at = now()
     WHERE id = p_id;
    PERFORM private.audit_ecrire(p_actor, p_name, 'CAMPAIGN_SEND_STARTED', 'campaign',
      p_id::text, 'success', jsonb_build_object('audience', c.audience ->> 'kind',
                                                'scheduled', c.scheduled_at IS NOT NULL));
  END IF;

  v_respect := c.type IN ('promotional', 'official_info');

  FOR u IN
    SELECT us.id, us.notifications_enabled, us.notification_prefs
      FROM public.users us
     WHERE us.id IN (SELECT public.campaign_audience_ids(c.audience))
       AND NOT EXISTS (SELECT 1 FROM public.campaign_recipients r
                        WHERE r.campaign_id = p_id AND r.user_id = us.id)
     ORDER BY us.id
     LIMIT p_limit
  LOOP
    v_n := v_n + 1;
    IF v_respect
       AND (u.notifications_enabled IS FALSE
            OR coalesce(u.notification_prefs ->> 'system_messages', 'true') = 'false') THEN
      INSERT INTO public.campaign_recipients (campaign_id, user_id, status)
      VALUES (p_id, u.id, 'skipped_pref')
      ON CONFLICT DO NOTHING;
    ELSE
      INSERT INTO public.notifications (user_id, type, title, body, data)
      VALUES (u.id, 'system', c.title, c.body,
              jsonb_build_object('campaign', p_id::text))
      RETURNING id INTO v_notif;
      INSERT INTO public.campaign_recipients (campaign_id, user_id, status, notification_id)
      VALUES (p_id, u.id, 'created', v_notif)
      ON CONFLICT DO NOTHING;
      v_creees := v_creees + 1;
    END IF;
  END LOOP;

  SELECT count(*) INTO v_restent
    FROM public.campaign_audience_ids(c.audience) i(id)
   WHERE NOT EXISTS (SELECT 1 FROM public.campaign_recipients r
                      WHERE r.campaign_id = p_id AND r.user_id = i.id);

  IF v_restent = 0 THEN
    UPDATE public.campaigns SET status = 'sent', sent_at = now(), updated_at = now()
     WHERE id = p_id;
    PERFORM private.audit_ecrire(p_actor, p_name, 'CAMPAIGN_SENT', 'campaign', p_id::text, 'success',
      jsonb_build_object(
        'created', (SELECT count(*) FROM public.campaign_recipients
                     WHERE campaign_id = p_id AND status = 'created'),
        'skipped_pref', (SELECT count(*) FROM public.campaign_recipients
                          WHERE campaign_id = p_id AND status = 'skipped_pref')));
  END IF;

  RETURN jsonb_build_object('processed', v_n, 'created', v_creees,
                            'remaining', v_restent,
                            'status', CASE WHEN v_restent = 0 THEN 'sent' ELSE 'sending' END);
END $$;

REVOKE ALL ON FUNCTION private.campaign_send_core(uuid, integer, text, text)
  FROM PUBLIC, anon, authenticated;

-- L'envoi manuel : mêmes contrôles qu'avant, plus le refus d'une campagne
-- programmée dont l'heure n'est pas venue.
DROP FUNCTION IF EXISTS public.campaign_send_batch(uuid, integer);

CREATE FUNCTION public.campaign_send_batch(p_id uuid, p_limit integer DEFAULT 200) RETURNS jsonb
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller text := (SELECT public.firebase_uid());
  v_name   text;
  v_prog   timestamptz;
BEGIN
  IF v_caller IS NULL OR NOT public.is_admin() THEN
    RAISE EXCEPTION 'campagne : réservé aux administrateurs' USING ERRCODE = '42501';
  END IF;
  PERFORM public.admin_require_permission('communications.send');

  IF p_limit IS NULL OR p_limit < 1 OR p_limit > 500 THEN
    RAISE EXCEPTION 'campagne : lot de 1 à 500 comptes' USING ERRCODE = '22023';
  END IF;

  SELECT scheduled_at INTO v_prog FROM public.campaigns WHERE id = p_id;
  IF v_prog IS NOT NULL AND v_prog > now() THEN
    RAISE EXCEPTION 'campagne : programmée, elle part à son heure (ou s''annule)'
      USING ERRCODE = '55000';
  END IF;

  SELECT display_name INTO v_name FROM public.users WHERE id = v_caller;
  RETURN private.campaign_send_core(p_id, p_limit, v_caller, v_name);
END $$;

-- ── 4. Programmer ───────────────────────────────────────────────────────────
DROP FUNCTION IF EXISTS public.campaign_schedule(uuid, timestamptz);

CREATE FUNCTION public.campaign_schedule(p_id uuid, p_at timestamptz) RETURNS text
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller text := (SELECT public.firebase_uid());
  c        public.campaigns%ROWTYPE;
BEGIN
  IF v_caller IS NULL OR NOT public.is_admin() THEN
    RAISE EXCEPTION 'campagne : réservé aux administrateurs' USING ERRCODE = '42501';
  END IF;
  PERFORM public.admin_require_permission('communications.create');

  IF p_at IS NOT NULL AND (p_at < now() + interval '5 minutes' OR p_at > now() + interval '90 days') THEN
    RAISE EXCEPTION 'campagne : heure entre 5 minutes et 90 jours' USING ERRCODE = '22023';
  END IF;

  SELECT * INTO c FROM public.campaigns WHERE id = p_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'campagne : introuvable' USING ERRCODE = 'P0002';
  END IF;
  IF c.status NOT IN ('draft', 'rejected') THEN
    RAISE EXCEPTION 'campagne : l''heure se fixe avant la soumission (statut %)', c.status
      USING ERRCODE = '55000';
  END IF;
  IF c.author_id <> v_caller AND NOT public.is_super_admin() THEN
    RAISE EXCEPTION 'campagne : brouillon d''un autre rédacteur' USING ERRCODE = '42501';
  END IF;

  UPDATE public.campaigns SET scheduled_at = p_at, status = 'draft',
         reviewer_id = NULL, reviewed_at = NULL, review_note = NULL, updated_at = now()
   WHERE id = p_id;

  PERFORM public.write_admin_audit(
    'CAMPAIGN_SCHEDULED', 'campaign', p_id::text, 'success', NULL, p_id::text,
    jsonb_build_object('scheduled_at', p_at));
  RETURN CASE WHEN p_at IS NULL THEN 'unscheduled' ELSE 'scheduled' END;
END $$;

-- L'approbation porte aussi sur l'heure : on n'approuve pas une heure passée.
DROP FUNCTION IF EXISTS public.campaign_review(uuid, text, text);

CREATE FUNCTION public.campaign_review(
  p_id       uuid,
  p_decision text,
  p_note     text DEFAULT NULL
) RETURNS text
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller text := (SELECT public.firebase_uid());
  c        public.campaigns%ROWTYPE;
  v_to     text;
BEGIN
  IF v_caller IS NULL OR NOT public.is_admin() THEN
    RAISE EXCEPTION 'campagne : réservé aux administrateurs' USING ERRCODE = '42501';
  END IF;
  PERFORM public.admin_require_permission('communications.send');

  IF p_decision IS NULL OR p_decision NOT IN ('approve', 'reject') THEN
    RAISE EXCEPTION 'campagne : décision invalide (approve, reject)' USING ERRCODE = '22023';
  END IF;
  IF length(coalesce(p_note, '')) > 1000 THEN
    RAISE EXCEPTION 'campagne : note trop longue (1000 max)' USING ERRCODE = '22001';
  END IF;
  IF p_decision = 'reject' AND nullif(btrim(coalesce(p_note, '')), '') IS NULL THEN
    RAISE EXCEPTION 'campagne : un refus doit être motivé' USING ERRCODE = '22023';
  END IF;

  SELECT * INTO c FROM public.campaigns WHERE id = p_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'campagne : introuvable' USING ERRCODE = 'P0002';
  END IF;
  IF c.status <> 'pending_approval' THEN
    RAISE EXCEPTION 'campagne : relecture impossible depuis le statut %', c.status
      USING ERRCODE = '55000';
  END IF;
  IF c.author_id = v_caller THEN
    RAISE EXCEPTION 'campagne : vous avez rédigé ce message, un autre administrateur doit l''approuver'
      USING ERRCODE = '42501';
  END IF;
  IF p_decision = 'approve' AND c.scheduled_at IS NOT NULL
     AND c.scheduled_at <= now() + interval '2 minutes' THEN
    RAISE EXCEPTION 'campagne : l''heure programmée est passée ou trop proche, à reprogrammer'
      USING ERRCODE = '22023';
  END IF;

  v_to := CASE p_decision WHEN 'approve' THEN 'approved' ELSE 'rejected' END;
  UPDATE public.campaigns SET
    status = v_to, reviewer_id = v_caller, reviewed_at = now(),
    review_note = nullif(btrim(p_note), ''), updated_at = now()
   WHERE id = p_id;

  PERFORM public.write_admin_audit(
    CASE p_decision WHEN 'approve' THEN 'CAMPAIGN_APPROVED' ELSE 'CAMPAIGN_REJECTED' END,
    'campaign', p_id::text, 'success', NULL, p_id::text,
    jsonb_build_object('scheduled_at', c.scheduled_at));
  RETURN v_to;
END $$;

-- ── 5. La tâche planifiée ───────────────────────────────────────────────────
DROP FUNCTION IF EXISTS private.campaign_send_due();

CREATE FUNCTION private.campaign_send_due() RETURNS integer
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  c record;
  n int := 0;
BEGIN
  -- Seulement du programmé ET approuvé (ou déjà en envoi) dont l'heure est
  -- venue. Trois campagnes par passage, 200 comptes chacune : le reste part au
  -- passage suivant, sans doublon.
  FOR c IN
    SELECT id FROM public.campaigns
     WHERE status IN ('approved', 'sending')
       AND scheduled_at IS NOT NULL AND scheduled_at <= now()
     ORDER BY scheduled_at
     LIMIT 3
  LOOP
    BEGIN
      PERFORM private.campaign_send_core(c.id, 200, 'system:cron', 'Envoi programmé');
      n := n + 1;
    EXCEPTION WHEN OTHERS THEN
      -- Une campagne en échec n'arrête pas les autres ; elle est tracée.
      PERFORM private.audit_ecrire('system:cron', 'Envoi programmé', 'CAMPAIGN_SEND_FAILED',
        'campaign', c.id::text, 'failed', jsonb_build_object('sqlstate', SQLSTATE));
    END;
  END LOOP;
  RETURN n;
END $$;

REVOKE ALL ON FUNCTION private.campaign_send_due() FROM PUBLIC, anon, authenticated;

DO $$
BEGIN
  PERFORM cron.unschedule('campaign_send_due');
EXCEPTION WHEN OTHERS THEN
  NULL;  -- première pose : rien à retirer
END $$;
SELECT cron.schedule('campaign_send_due', '*/5 * * * *', 'SELECT private.campaign_send_due()');

-- ── 6. Modèles ──────────────────────────────────────────────────────────────
DROP FUNCTION IF EXISTS public.campaign_template_save(uuid, text, text, text, text);

CREATE FUNCTION public.campaign_template_save(
  p_id    uuid,
  p_name  text,
  p_type  text,
  p_title text,
  p_body  text
) RETURNS uuid
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
    RAISE EXCEPTION 'modèle : réservé aux administrateurs' USING ERRCODE = '42501';
  END IF;
  PERFORM public.admin_require_permission('communications.create');

  IF p_name IS NULL OR length(btrim(p_name)) NOT BETWEEN 3 AND 60 THEN
    RAISE EXCEPTION 'modèle : nom requis (3 à 60 caractères)' USING ERRCODE = '22023';
  END IF;
  IF p_type IS NULL OR p_type NOT IN ('transactional', 'security', 'official_info', 'promotional') THEN
    RAISE EXCEPTION 'modèle : type invalide' USING ERRCODE = '22023';
  END IF;
  IF p_title IS NULL OR length(btrim(p_title)) NOT BETWEEN 3 AND 80 THEN
    RAISE EXCEPTION 'modèle : titre requis (3 à 80 caractères)' USING ERRCODE = '22023';
  END IF;
  IF p_body IS NULL OR length(btrim(p_body)) NOT BETWEEN 10 AND 300 THEN
    RAISE EXCEPTION 'modèle : texte requis (10 à 300 caractères)' USING ERRCODE = '22023';
  END IF;

  BEGIN
    IF p_id IS NULL THEN
      INSERT INTO public.campaign_templates (name, type, title, body, created_by)
      VALUES (btrim(p_name), p_type, btrim(p_title), btrim(p_body), v_caller)
      RETURNING id INTO v_id;
    ELSE
      UPDATE public.campaign_templates SET
        name = btrim(p_name), type = p_type, title = btrim(p_title), body = btrim(p_body),
        updated_at = now()
       WHERE id = p_id AND archived_at IS NULL
       RETURNING id INTO v_id;
      IF v_id IS NULL THEN
        RAISE EXCEPTION 'modèle : introuvable ou archivé' USING ERRCODE = 'P0002';
      END IF;
    END IF;
  EXCEPTION WHEN unique_violation THEN
    RAISE EXCEPTION 'modèle : un modèle porte déjà ce nom' USING ERRCODE = '55000';
  END;

  PERFORM public.write_admin_audit(
    'CAMPAIGN_TEMPLATE_SAVED', 'campaign_template', v_id::text, 'success', NULL, v_id::text,
    jsonb_build_object('type', p_type));
  RETURN v_id;
END $$;

DROP FUNCTION IF EXISTS public.campaign_template_archive(uuid);

CREATE FUNCTION public.campaign_template_archive(p_id uuid) RETURNS text
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF (SELECT public.firebase_uid()) IS NULL OR NOT public.is_admin() THEN
    RAISE EXCEPTION 'modèle : réservé aux administrateurs' USING ERRCODE = '42501';
  END IF;
  PERFORM public.admin_require_permission('communications.create');

  UPDATE public.campaign_templates SET archived_at = now(), updated_at = now()
   WHERE id = p_id AND archived_at IS NULL;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'modèle : introuvable ou déjà archivé' USING ERRCODE = 'P0002';
  END IF;
  PERFORM public.write_admin_audit(
    'CAMPAIGN_TEMPLATE_ARCHIVED', 'campaign_template', p_id::text, 'success', NULL, p_id::text, '{}'::jsonb);
  RETURN 'archived';
END $$;

-- ── 7. Rapport d'envoi ──────────────────────────────────────────────────────
DROP FUNCTION IF EXISTS public.campaign_report(uuid);

CREATE FUNCTION public.campaign_report(p_id uuid) RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  c         public.campaigns%ROWTYPE;
  v_creees  int;
  v_ignores int;
  v_push    int;
  v_total   int;
BEGIN
  IF (SELECT public.firebase_uid()) IS NULL OR NOT public.is_admin() THEN
    RAISE EXCEPTION 'campagne : réservé aux administrateurs' USING ERRCODE = '42501';
  END IF;
  PERFORM public.admin_require_permission('communications.view');

  SELECT * INTO c FROM public.campaigns WHERE id = p_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'campagne : introuvable' USING ERRCODE = 'P0002';
  END IF;

  SELECT count(*) FILTER (WHERE r.status = 'created'),
         count(*) FILTER (WHERE r.status = 'skipped_pref'),
         count(*) FILTER (WHERE r.status = 'created'
                          AND jsonb_typeof(u.fcm_tokens) = 'array'
                          AND jsonb_array_length(u.fcm_tokens) > 0)
    INTO v_creees, v_ignores, v_push
    FROM public.campaign_recipients r
    LEFT JOIN public.users u ON u.id = r.user_id
   WHERE r.campaign_id = p_id;

  SELECT count(*) INTO v_total FROM public.campaign_audience_ids(c.audience);

  RETURN jsonb_build_object(
    'status', c.status,
    'scheduled_at', c.scheduled_at,
    'send_started_at', c.send_started_at,
    'sent_at', c.sent_at,
    'created', v_creees,
    'skipped_pref', v_ignores,
    'remaining', greatest(v_total - v_creees - v_ignores, 0),
    -- Joignables par push = porteurs d'un jeton : PAS « reçus ».
    'reachable_by_push', v_push,
    'start_delay_seconds', CASE WHEN c.scheduled_at IS NOT NULL AND c.send_started_at IS NOT NULL
                                THEN extract(epoch FROM (c.send_started_at - c.scheduled_at))::int END,
    'duration_seconds', CASE WHEN c.send_started_at IS NOT NULL AND c.sent_at IS NOT NULL
                             THEN extract(epoch FROM (c.sent_at - c.send_started_at))::int END);
END $$;

-- ── 8. Droits d'exécution ───────────────────────────────────────────────────
REVOKE ALL ON FUNCTION public.campaign_send_batch(uuid, integer)  FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.campaign_schedule(uuid, timestamptz) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.campaign_review(uuid, text, text)   FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.campaign_template_save(uuid, text, text, text, text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.campaign_template_archive(uuid)     FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.campaign_report(uuid)               FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.campaign_send_batch(uuid, integer)  TO authenticated;
GRANT EXECUTE ON FUNCTION public.campaign_schedule(uuid, timestamptz) TO authenticated;
GRANT EXECUTE ON FUNCTION public.campaign_review(uuid, text, text)   TO authenticated;
GRANT EXECUTE ON FUNCTION public.campaign_template_save(uuid, text, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.campaign_template_archive(uuid)     TO authenticated;
GRANT EXECUTE ON FUNCTION public.campaign_report(uuid)               TO authenticated;

NOTIFY pgrst, 'reload schema';
