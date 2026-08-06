-- =============================================================================
-- Le court-circuit `type = 'message'` vivait dans `private`, pas `public`.
--
-- La migration 20260805230000 faisait
-- `CREATE OR REPLACE FUNCTION public.notify_push_on_notification` : elle a
-- créé une **deuxième** fonction homonyme dans `public` et laissé intacte
-- celle que le trigger appelle réellement. Résultat : le trigger
-- `trg_notify_push` continuait d'exécuter `private.notify_push_on_notification`
-- et de sauter les notifications de type `message`. La moitié « messages →
-- lignes notifications » du correctif marchait, la moitié « lignes
-- notifications → push » restait cassée — donc toujours aucun push de chat.
--
-- Comment ça s'est vu : `select prosrc from pg_proc where proname = '…'` sans
-- qualifier le schéma renvoyait DEUX lignes. Interroger `pg_trigger` en
-- joignant `pg_namespace` donne le schéma réel de la fonction appelée — c'est
-- la seule lecture qui ne ment pas.
--
-- Ici : on remplace la vraie fonction (dans `private`) et on supprime
-- l'homonyme parasite créé dans `public`, qui n'a jamais eu d'appelant.
-- =============================================================================

CREATE OR REPLACE FUNCTION private.notify_push_on_notification()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  cfg private.push_webhook_config%ROWTYPE;
BEGIN
  -- Plus de court-circuit sur `message` : le flux RTDB auquel il déléguait
  -- (Cloud Function onMessageCreated) ne se déclenche plus depuis que les
  -- messages sont écrits dans Supabase.
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
EXCEPTION
  WHEN OTHERS THEN
    -- Ne jamais faire échouer l'INSERT notifications à cause d'un push.
    RAISE WARNING 'notify_push_on_notification: %', SQLERRM;
    RETURN NEW;
END;
$$;

COMMENT ON FUNCTION private.notify_push_on_notification() IS
  'Après INSERT notifications (tous types, messages compris) : appelle '
  'l''Edge Function send-push via pg_net. URL et secret dans '
  'private.push_webhook_config.';

REVOKE ALL ON FUNCTION private.notify_push_on_notification() FROM PUBLIC;

-- L'homonyme créé par erreur dans `public` : aucun trigger ne le référence.
DROP FUNCTION IF EXISTS public.notify_push_on_notification();
