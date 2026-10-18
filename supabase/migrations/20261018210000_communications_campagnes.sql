-- Communications : des campagnes qui partent vraiment, après approbation.
--
-- Référentiel d'administration § 11 et spécification d'interfaces § 16.
--
-- ═══ CE QUI EXISTAIT : UN ÉCRAN QUI MENTAIT ═════════════════════════════════
--
-- « Notifications » du panneau faisait `INSERT INTO admin_notifications` puis
-- affichait « Notification envoyée avec succès ». Aucun déclencheur ne lit
-- cette table (`trg_notify_push` est sur `notifications`, pas sur elle) :
-- RIEN n'était diffusé. Mesuré le 2026-10-18 : une seule ligne, « Test panneau
-- admin », `sent_count = 0`, `target_type = 'admins'`. Le référentiel le
-- nomme : « un statut envoyé n'est pas assimilé à un statut lu » — ici, un
-- statut « envoyé » n'était même pas un envoi. Et l'annonce du 2026-09-15 avait
-- dû passer par un script SQL à la main (« il n'existe aucun outil de
-- diffusion »).
--
-- ═══ CE QUE CETTE MIGRATION POSE ═══════════════════════════════════════════
--
-- • `campaigns` : un message (type, titre, texte), une audience décrite
--   (tous / un pays / des comptes précis), un statut (brouillon → à approuver
--   → approuvée → en envoi → envoyée, ou refusée / annulée), l'auteur,
--   l'approbateur, les dates.
-- • `campaign_recipients` : une ligne par compte traité — `created` (la
--   notification existe, `trg_notify_push` prend le relais) ou
--   `skipped_pref` (le compte a coupé ces messages : on ne crée rien et on le
--   compte). `UNIQUE (campaign_id, user_id)` : relancer un envoi ne renotifie
--   personne.
-- • Cinq RPC : enregistrer, soumettre, relire (approuver / refuser), envoyer
--   par lots, annuler. L'audience est résolue CÔTÉ SERVEUR au moment de
--   l'envoi, jamais fournie par le client (comptes bannis exclus).
-- • Séparation : celui qui a rédigé n'approuve pas, superAdmin compris.
--   `communications.send` (déjà au catalogue, superAdmin seul) porte l'envoi
--   et l'approbation ; `communications.create` (contentMod) la rédaction.
-- • Envoi par lots de 1 à 500 comptes : chaque notification déclenche un
--   appel pg_net, un envoi unique de milliers de lignes saturerait la file.
--   Le panneau rappelle `campaign_send_batch` tant qu'il reste des comptes ;
--   un lot interrompu reprend où il s'est arrêté, sans doublon.
-- • Les types `promotional` et `official_info` respectent les préférences du
--   compte (`notifications_enabled`, `notification_prefs.system_messages`) ;
--   `security` et `transactional` n'en tiennent pas compte, parce que ce sont
--   des messages indispensables au service — le référentiel veut ne pas les
--   mélanger avec le promotionnel.
-- • `admin_notifications` n'est plus écrite : le droit INSERT et sa policy
--   sont retirés (la lecture de l'historique reste).
--
-- ═══ CE QU'ELLE NE FAIT PAS ═════════════════════════════════════════════════
--
-- • Pas de programmation : rien ne tourne en arrière-plan pour envoyer à une
--   heure donnée (pas de `pg_cron` posé sur ce projet). Une campagne part
--   quand quelqu'un lance l'envoi. Ne pas afficher de champ « date » tant
--   qu'un exécuteur n'existe pas.
-- • Pas de canal courriel, pas de statistiques de lecture ni de clics.
--   « Créée » n'est pas « livrée » n'est pas « lue » : le suivi s'arrête à
--   « notification créée », et la livraison réelle se lit dans
--   `net._http_response` (voir la recette du 2026-09-15).
-- • Pas de ciblage par âge, rôle ou activité : trois audiences seulement,
--   les moins invasives qui servent.
--
-- Banc : tools/rls_tests/communications_campagnes.sql.

SET lock_timeout = '5s';

-- ── 1. Permissions ──────────────────────────────────────────────────────────
-- `communications.send` existe déjà (legacy sendNotifications, superAdmin).
INSERT INTO public.admin_permissions (key, module, description, legacy_key) VALUES
  ('communications.view',   'communications', 'Voir les campagnes',                          NULL),
  ('communications.create', 'communications', 'Rédiger et soumettre une campagne',           NULL)
ON CONFLICT (key) DO NOTHING;

INSERT INTO public.admin_role_permissions (role, permission) VALUES
  ('contentMod', 'communications.view'),
  ('contentMod', 'communications.create')
ON CONFLICT DO NOTHING;

-- ── 2. Tables ───────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.campaigns (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  type              text NOT NULL
                    CHECK (type IN ('transactional', 'security', 'official_info', 'promotional')),
  title             text NOT NULL CHECK (length(btrim(title)) BETWEEN 3 AND 80),
  body              text NOT NULL CHECK (length(btrim(body)) BETWEEN 10 AND 300),
  audience          jsonb NOT NULL,
  status            text NOT NULL DEFAULT 'draft'
                    CHECK (status IN ('draft', 'pending_approval', 'approved', 'sending',
                                      'sent', 'rejected', 'cancelled')),
  author_id         text NOT NULL,
  reviewer_id       text,
  reviewed_at       timestamptz,
  review_note       text,
  send_started_at   timestamptz,
  sent_at           timestamptz,
  cancelled_by      text,
  cancel_reason     text,
  created_at        timestamptz NOT NULL DEFAULT now(),
  updated_at        timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS campaigns_status_idx ON public.campaigns (status, updated_at DESC);

CREATE TABLE IF NOT EXISTS public.campaign_recipients (
  campaign_id     uuid NOT NULL REFERENCES public.campaigns (id),
  user_id         text NOT NULL,
  status          text NOT NULL CHECK (status IN ('created', 'skipped_pref')),
  notification_id uuid,
  processed_at    timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (campaign_id, user_id)
);

ALTER TABLE public.campaigns           ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.campaign_recipients ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.campaigns           FROM PUBLIC, anon, authenticated;
REVOKE ALL ON public.campaign_recipients FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.campaigns           TO authenticated;
GRANT SELECT ON public.campaign_recipients TO authenticated;

DROP POLICY IF EXISTS campaigns_select ON public.campaigns;
CREATE POLICY campaigns_select ON public.campaigns
  FOR SELECT TO authenticated USING (public.admin_has_permission('communications.view'));
DROP POLICY IF EXISTS campaign_recipients_select ON public.campaign_recipients;
CREATE POLICY campaign_recipients_select ON public.campaign_recipients
  FOR SELECT TO authenticated USING (public.admin_has_permission('communications.view'));

-- ── 3. L'ancien chemin qui ne livrait rien est fermé ────────────────────────
DROP POLICY IF EXISTS admin_notifications_insert_admin ON public.admin_notifications;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON public.admin_notifications FROM PUBLIC, anon, authenticated;

-- ── 4. Validation de l'audience ─────────────────────────────────────────────
DROP FUNCTION IF EXISTS public.campaign_audience_check(jsonb);

CREATE FUNCTION public.campaign_audience_check(a jsonb) RETURNS void
LANGUAGE plpgsql
STABLE
SET search_path = public, pg_temp
AS $$
DECLARE
  v_kind text := a ->> 'kind';
  v_ids  jsonb := a -> 'user_ids';
BEGIN
  IF a IS NULL OR jsonb_typeof(a) <> 'object' THEN
    RAISE EXCEPTION 'campagne : audience invalide' USING ERRCODE = '22023';
  END IF;
  IF v_kind IS NULL OR v_kind NOT IN ('all', 'country', 'users') THEN
    RAISE EXCEPTION 'campagne : audience inconnue (all, country, users)' USING ERRCODE = '22023';
  END IF;
  IF v_kind = 'country'
     AND (jsonb_typeof(a -> 'country') IS DISTINCT FROM 'string'
          OR length(btrim(a ->> 'country')) NOT BETWEEN 2 AND 60) THEN
    RAISE EXCEPTION 'campagne : pays requis' USING ERRCODE = '22023';
  END IF;
  IF v_kind = 'users' THEN
    IF jsonb_typeof(v_ids) IS DISTINCT FROM 'array'
       OR jsonb_array_length(v_ids) NOT BETWEEN 1 AND 100 THEN
      RAISE EXCEPTION 'campagne : 1 à 100 comptes' USING ERRCODE = '22023';
    END IF;
  END IF;
END $$;

REVOKE ALL ON FUNCTION public.campaign_audience_check(jsonb) FROM PUBLIC, anon, authenticated;

-- Les comptes visés : jamais fournis par le client tels quels, toujours
-- relus dans `users`, bannis exclus.
DROP FUNCTION IF EXISTS public.campaign_audience_ids(jsonb);

CREATE FUNCTION public.campaign_audience_ids(a jsonb) RETURNS SETOF text
LANGUAGE sql
STABLE
SET search_path = public, pg_temp
AS $$
  SELECT u.id
    FROM public.users u
   WHERE coalesce(u.is_banned, false) = false
     AND CASE a ->> 'kind'
           WHEN 'all'     THEN true
           WHEN 'country' THEN u.country_code = btrim(a ->> 'country')
           WHEN 'users'   THEN u.id IN (SELECT jsonb_array_elements_text(a -> 'user_ids'))
           ELSE false END
$$;

REVOKE ALL ON FUNCTION public.campaign_audience_ids(jsonb) FROM PUBLIC, anon, authenticated;

-- Combien de comptes, d'après les mêmes règles que l'envoi ; pour que
-- l'approbateur voie ce qu'il approuve.
DROP FUNCTION IF EXISTS public.campaign_audience_count(uuid);

CREATE FUNCTION public.campaign_audience_count(p_id uuid) RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  c public.campaigns%ROWTYPE;
  v_respect boolean;
  v_total int;
  v_ignores int;
BEGIN
  IF (SELECT public.firebase_uid()) IS NULL OR NOT public.is_admin() THEN
    RAISE EXCEPTION 'campagne : réservé aux administrateurs' USING ERRCODE = '42501';
  END IF;
  PERFORM public.admin_require_permission('communications.view');
  SELECT * INTO c FROM public.campaigns WHERE id = p_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'campagne : introuvable' USING ERRCODE = 'P0002';
  END IF;
  v_respect := c.type IN ('promotional', 'official_info');

  SELECT count(*) INTO v_total FROM public.campaign_audience_ids(c.audience);
  SELECT count(*) INTO v_ignores
    FROM public.users u
   WHERE v_respect AND u.id IN (SELECT public.campaign_audience_ids(c.audience))
     AND (u.notifications_enabled IS FALSE
          OR coalesce(u.notification_prefs ->> 'system_messages', 'true') = 'false');
  RETURN jsonb_build_object('total', v_total, 'skipped_pref', v_ignores,
                            'will_notify', v_total - v_ignores);
END $$;

-- ── 5. Enregistrer ──────────────────────────────────────────────────────────
DROP FUNCTION IF EXISTS public.campaign_save(uuid, text, text, text, jsonb);

CREATE FUNCTION public.campaign_save(
  p_id       uuid,
  p_type     text,
  p_title    text,
  p_body     text,
  p_audience jsonb
) RETURNS uuid
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller text := (SELECT public.firebase_uid());
  c        public.campaigns%ROWTYPE;
  v_id     uuid;
BEGIN
  IF v_caller IS NULL OR NOT public.is_admin() THEN
    RAISE EXCEPTION 'campagne : réservé aux administrateurs' USING ERRCODE = '42501';
  END IF;
  PERFORM public.admin_require_permission('communications.create');

  IF p_type IS NULL OR p_type NOT IN ('transactional', 'security', 'official_info', 'promotional') THEN
    RAISE EXCEPTION 'campagne : type invalide' USING ERRCODE = '22023';
  END IF;
  IF p_title IS NULL OR length(btrim(p_title)) NOT BETWEEN 3 AND 80 THEN
    RAISE EXCEPTION 'campagne : titre requis (3 à 80 caractères)' USING ERRCODE = '22023';
  END IF;
  IF p_body IS NULL OR length(btrim(p_body)) NOT BETWEEN 10 AND 300 THEN
    RAISE EXCEPTION 'campagne : texte requis (10 à 300 caractères)' USING ERRCODE = '22023';
  END IF;
  PERFORM public.campaign_audience_check(p_audience);

  IF p_id IS NULL THEN
    INSERT INTO public.campaigns (type, title, body, audience, author_id)
    VALUES (p_type, btrim(p_title), btrim(p_body), p_audience, v_caller)
    RETURNING id INTO v_id;
  ELSE
    SELECT * INTO c FROM public.campaigns WHERE id = p_id FOR UPDATE;
    IF NOT FOUND THEN
      RAISE EXCEPTION 'campagne : introuvable' USING ERRCODE = 'P0002';
    END IF;
    IF c.status NOT IN ('draft', 'rejected') THEN
      RAISE EXCEPTION 'campagne : modification impossible depuis le statut %', c.status
        USING ERRCODE = '55000';
    END IF;
    IF c.author_id <> v_caller AND NOT public.is_super_admin() THEN
      RAISE EXCEPTION 'campagne : brouillon d''un autre rédacteur' USING ERRCODE = '42501';
    END IF;
    UPDATE public.campaigns SET
      type = p_type, title = btrim(p_title), body = btrim(p_body), audience = p_audience,
      status = 'draft', reviewer_id = NULL, reviewed_at = NULL, review_note = NULL,
      updated_at = now()
     WHERE id = p_id;
    v_id := p_id;
  END IF;

  PERFORM public.write_admin_audit(
    'CAMPAIGN_DRAFTED', 'campaign', v_id::text, 'success', NULL, v_id::text,
    jsonb_build_object('type', p_type, 'audience', p_audience ->> 'kind'));
  RETURN v_id;
END $$;

-- ── 6. Soumettre ────────────────────────────────────────────────────────────
DROP FUNCTION IF EXISTS public.campaign_submit(uuid);

CREATE FUNCTION public.campaign_submit(p_id uuid) RETURNS text
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

  SELECT * INTO c FROM public.campaigns WHERE id = p_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'campagne : introuvable' USING ERRCODE = 'P0002';
  END IF;
  IF c.status <> 'draft' THEN
    RAISE EXCEPTION 'campagne : soumission impossible depuis le statut %', c.status
      USING ERRCODE = '55000';
  END IF;
  IF c.author_id <> v_caller AND NOT public.is_super_admin() THEN
    RAISE EXCEPTION 'campagne : brouillon d''un autre rédacteur' USING ERRCODE = '42501';
  END IF;
  PERFORM public.campaign_audience_check(c.audience);

  UPDATE public.campaigns SET status = 'pending_approval', updated_at = now() WHERE id = p_id;

  PERFORM public.write_admin_audit(
    'CAMPAIGN_SUBMITTED', 'campaign', p_id::text, 'success', NULL, p_id::text, '{}'::jsonb);
  RETURN 'pending_approval';
END $$;

-- ── 7. Approuver ou refuser ─────────────────────────────────────────────────
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

  v_to := CASE p_decision WHEN 'approve' THEN 'approved' ELSE 'rejected' END;
  UPDATE public.campaigns SET
    status = v_to, reviewer_id = v_caller, reviewed_at = now(),
    review_note = nullif(btrim(p_note), ''), updated_at = now()
   WHERE id = p_id;

  PERFORM public.write_admin_audit(
    CASE p_decision WHEN 'approve' THEN 'CAMPAIGN_APPROVED' ELSE 'CAMPAIGN_REJECTED' END,
    'campaign', p_id::text, 'success', NULL, p_id::text, '{}'::jsonb);
  RETURN v_to;
END $$;

-- ── 8. Envoyer, par lots ────────────────────────────────────────────────────
DROP FUNCTION IF EXISTS public.campaign_send_batch(uuid, integer);

CREATE FUNCTION public.campaign_send_batch(p_id uuid, p_limit integer DEFAULT 200) RETURNS jsonb
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller  text := (SELECT public.firebase_uid());
  c         public.campaigns%ROWTYPE;
  v_respect boolean;
  v_notif   uuid;
  v_n       int := 0;
  v_creees  int := 0;
  v_restent int;
  u         record;
BEGIN
  IF v_caller IS NULL OR NOT public.is_admin() THEN
    RAISE EXCEPTION 'campagne : réservé aux administrateurs' USING ERRCODE = '42501';
  END IF;
  PERFORM public.admin_require_permission('communications.send');

  IF p_limit IS NULL OR p_limit < 1 OR p_limit > 500 THEN
    RAISE EXCEPTION 'campagne : lot de 1 à 500 comptes' USING ERRCODE = '22023';
  END IF;

  -- Le verrou de ligne sérialise deux envois simultanés : le second attend,
  -- puis ne trouve plus rien à traiter (ou le reste).
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
    PERFORM public.write_admin_audit(
      'CAMPAIGN_SEND_STARTED', 'campaign', p_id::text, 'success', NULL, p_id::text,
      jsonb_build_object('audience', c.audience ->> 'kind'));
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
      -- `system` : respecte la bascule « Messages système » côté serveur et
      -- côté app (voir project_annonce_push_diffusion). Le marqueur `campaign`
      -- relie la notification à la campagne. L'INSERT déclenche `trg_notify_push`.
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
    PERFORM public.write_admin_audit(
      'CAMPAIGN_SENT', 'campaign', p_id::text, 'success', NULL, p_id::text,
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

-- ── 9. Annuler ──────────────────────────────────────────────────────────────
DROP FUNCTION IF EXISTS public.campaign_cancel(uuid, text);

CREATE FUNCTION public.campaign_cancel(p_id uuid, p_reason text) RETURNS text
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
  IF p_reason IS NULL OR length(btrim(p_reason)) < 5 OR length(p_reason) > 1000 THEN
    RAISE EXCEPTION 'campagne : motif requis (5 à 1000 caractères)' USING ERRCODE = '22023';
  END IF;

  SELECT * INTO c FROM public.campaigns WHERE id = p_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'campagne : introuvable' USING ERRCODE = 'P0002';
  END IF;
  IF c.status NOT IN ('draft', 'pending_approval', 'approved', 'sending') THEN
    RAISE EXCEPTION 'campagne : annulation impossible depuis le statut %', c.status
      USING ERRCODE = '55000';
  END IF;

  -- Avant l'approbation, l'auteur retire son propre texte ; ensuite, l'arrêt
  -- d'une campagne approuvée ou en cours est celui de qui détient l'envoi.
  IF c.status IN ('draft', 'pending_approval') AND c.author_id = v_caller THEN
    PERFORM public.admin_require_permission('communications.create');
  ELSE
    PERFORM public.admin_require_permission('communications.send');
  END IF;

  UPDATE public.campaigns SET
    status = 'cancelled', cancelled_by = v_caller, cancel_reason = btrim(p_reason),
    updated_at = now()
   WHERE id = p_id;

  -- Un arrêt en cours d'envoi laisse des envois partiels : ils restent
  -- visibles dans `campaign_recipients`, et l'audit les chiffre.
  PERFORM public.write_admin_audit(
    'CAMPAIGN_CANCELLED', 'campaign', p_id::text, 'success', NULL, p_id::text,
    jsonb_build_object('from', c.status,
      'already_created', (SELECT count(*) FROM public.campaign_recipients
                           WHERE campaign_id = p_id AND status = 'created')));
  RETURN 'cancelled';
END $$;

-- ── 10. Droits d'exécution ──────────────────────────────────────────────────
REVOKE ALL ON FUNCTION public.campaign_audience_count(uuid)                         FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.campaign_save(uuid, text, text, text, jsonb)          FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.campaign_submit(uuid)                                 FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.campaign_review(uuid, text, text)                     FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.campaign_send_batch(uuid, integer)                    FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.campaign_cancel(uuid, text)                           FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.campaign_audience_count(uuid)                      TO authenticated;
GRANT EXECUTE ON FUNCTION public.campaign_save(uuid, text, text, text, jsonb)       TO authenticated;
GRANT EXECUTE ON FUNCTION public.campaign_submit(uuid)                              TO authenticated;
GRANT EXECUTE ON FUNCTION public.campaign_review(uuid, text, text)                  TO authenticated;
GRANT EXECUTE ON FUNCTION public.campaign_send_batch(uuid, integer)                 TO authenticated;
GRANT EXECUTE ON FUNCTION public.campaign_cancel(uuid, text)                        TO authenticated;

NOTIFY pgrst, 'reload schema';
