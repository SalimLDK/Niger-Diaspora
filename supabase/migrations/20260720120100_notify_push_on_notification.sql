-- =============================================================================
-- Trigger / Webhook : notifications INSERT → push FCM via send-push
--
-- Problème corrigé : la migration 20260720120100 était vide, donc aucun
-- mécanisme serveur ne déclenchait l'Edge Function send-push après INSERT
-- dans `notifications`. Résultat : les notifications in-app étaient créées,
-- mais les push FCM n'arrivaient jamais.
--
-- Fix : utiliser pg_net pour appeler l'Edge Function send-push de manière
-- asynchrone et fiable. pg_net est une extension Supabase qui permet de faire
-- des requêtes HTTP depuis Postgres sans bloquer la transaction.
--
-- Prérequis :
--   - Extension pg_net activée (Supabase la fournit par défaut)
--   - Edge Function send-push déployée
--   - Secrets configurés dans Supabase :
--       FCM_SERVICE_ACCOUNT       : JSON du service account Firebase
--       PUSH_WEBHOOK_SECRET       : secret partagé pour authentifier l'appel
--       SERVICE_ROLE_KEY          : clé service role Supabase
--
-- Payload envoyé à send-push : le record notifications au format JSON.
-- send-push lit users.fcm_tokens et envoie les pushes FCM.
--
-- Idempotent : CREATE OR REPLACE + DROP TRIGGER IF EXISTS.
-- =============================================================================

CREATE EXTENSION IF NOT EXISTS pg_net;

CREATE OR REPLACE FUNCTION public.notify_push_on_notification()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_project_ref TEXT;
  v_edge_url    TEXT;
  v_secret      TEXT;
  v_payload     TEXT;
BEGIN
  -- Supabase Edge Functions URL pattern: https://<project-ref>.supabase.co/functions/v1/send-push
  -- We derive project_ref from the current database name if possible, or use a config value.
  v_project_ref := current_setting('app.supabase_project_ref', true);
  IF v_project_ref IS NULL OR v_project_ref = '' THEN
    -- Fallback: try to extract from auth settings or use a placeholder
    v_project_ref := 'diaspo-niger';
  END IF;

  v_edge_url := format('https://%s.supabase.co/functions/v1/send-push', v_project_ref);
  v_secret := current_setting('app.push_webhook_secret', true);
  IF v_secret IS NULL OR v_secret = '' THEN
    v_secret := 'default-secret';
  END IF;

  v_payload := jsonb_build_object(
    'type',   TG_OP,
    'table',  TG_TABLE_NAME,
    'record', row_to_json(NEW)
  )::text;

  -- Async HTTP POST via pg_net; non-blocking for the trigger transaction.
  PERFORM net.http_post(
    url     := v_edge_url,
    headers := jsonb_build_object(
      'Content-Type',   'application/json',
      'x-webhook-secret', v_secret
    ),
    body    := v_payload
  );

  RETURN NEW;
EXCEPTION
  WHEN OTHERS THEN
    -- Never fail the notifications INSERT because of a push failure.
    RAISE WARNING 'notify_push_on_notification: %', SQLERRM;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_notify_push_on_notification ON public.notifications;
CREATE TRIGGER trg_notify_push_on_notification
  AFTER INSERT ON public.notifications
  FOR EACH ROW
  EXECUTE FUNCTION public.notify_push_on_notification();

COMMENT ON FUNCTION public.notify_push_on_notification() IS
  'Après INSERT notifications : appelle asynchronement l''Edge Function send-push via pg_net pour envoyer les pushes FCM.';

REVOKE ALL ON FUNCTION public.notify_push_on_notification() FROM PUBLIC;

-- Helper to set project ref and webhook secret for the trigger.
-- Run this once after deployment:
--   ALTER DATABASE current_database() SET app.supabase_project_ref = 'your-project-ref';
--   ALTER DATABASE current_database() SET app.push_webhook_secret = 'your-webhook-secret';
