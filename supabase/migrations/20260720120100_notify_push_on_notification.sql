-- =============================================================================
-- Trigger : notifications INSERT → push FCM via l'Edge Function send-push.
--
-- ⚠️ Ce fichier a été RÉÉCRIT le 2026-08-05 pour refléter ce qui tourne
-- réellement sur le distant. La version précédente n'a jamais été celle
-- déployée : elle lisait l'URL et le secret dans
-- `current_setting('app.supabase_project_ref')` / `app.push_webhook_secret`,
-- deux réglages qui valent NULL sur le projet — elle serait donc retombée sur
-- ses valeurs de repli `https://diaspo-niger.supabase.co` et `default-secret`,
-- et aurait cassé les notifications qui fonctionnent. La rejouer à la main
-- aurait fait des dégâts ; d'où cette remise à niveau.
--
-- Le mécanisme réel : une table de configuration privée, écrite hors dépôt
-- (elle contient le secret partagé, qui n'a rien à faire dans le repo).
--
--   private.push_webhook_config
--     id             BOOLEAN PK, toujours TRUE (ligne unique)
--     function_url   https://<project-ref>.supabase.co/functions/v1/send-push
--     webhook_secret secret partagé, présenté en `x-webhook-secret`
--
-- Renseigner la ligne une seule fois, hors migration :
--   INSERT INTO private.push_webhook_config (id, function_url, webhook_secret)
--   VALUES (TRUE, 'https://<ref>.supabase.co/functions/v1/send-push', '<secret>')
--   ON CONFLICT (id) DO UPDATE
--     SET function_url = EXCLUDED.function_url,
--         webhook_secret = EXCLUDED.webhook_secret;
--
-- Si la ligne est absente, le trigger est un no-op : la notification in-app
-- est créée, aucun push n'est envoyé.
--
-- Le court-circuit `IF NEW.type = 'message'` que portait la version déployée
-- est retiré par la migration 20260805230000 — voir son en-tête.
--
-- Idempotent : CREATE ... IF NOT EXISTS + CREATE OR REPLACE + DROP TRIGGER IF EXISTS.
-- =============================================================================

CREATE EXTENSION IF NOT EXISTS pg_net;

CREATE SCHEMA IF NOT EXISTS private;

CREATE TABLE IF NOT EXISTS private.push_webhook_config (
  id             BOOLEAN PRIMARY KEY DEFAULT TRUE,
  function_url   TEXT NOT NULL,
  webhook_secret TEXT NOT NULL,
  CONSTRAINT push_webhook_config_singleton CHECK (id IS TRUE)
);

-- Table de secrets : aucun accès client, ni anon ni authenticated.
REVOKE ALL ON private.push_webhook_config FROM PUBLIC;

CREATE OR REPLACE FUNCTION public.notify_push_on_notification()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  cfg private.push_webhook_config%ROWTYPE;
BEGIN
  -- Les messages de chat sont poussés par un autre flux : on les ignore ici.
  -- (Hypothèse fausse depuis le passage des messages à Supabase — levée par
  -- la migration 20260805230000.)
  IF NEW.type = 'message' THEN
    RETURN NEW;
  END IF;

  SELECT * INTO cfg FROM private.push_webhook_config WHERE id IS TRUE;
  IF NOT FOUND THEN
    RETURN NEW; -- non configuré : no-op (la notif in-app reste créée)
  END IF;

  PERFORM net.http_post(
    url := cfg.function_url,
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-webhook-secret', cfg.webhook_secret
    ),
    body := jsonb_build_object('record', to_jsonb(NEW)),
    timeout_milliseconds := 5000
  );
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_notify_push ON public.notifications;
CREATE TRIGGER trg_notify_push
  AFTER INSERT ON public.notifications
  FOR EACH ROW
  EXECUTE FUNCTION public.notify_push_on_notification();

REVOKE ALL ON FUNCTION public.notify_push_on_notification() FROM PUBLIC;
