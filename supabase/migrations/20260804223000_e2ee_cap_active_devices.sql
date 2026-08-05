-- Plafonne le nombre d'appareils E2EE actifs.
--
-- PROBLÈME (constaté le 2026-08-04)
-- La version déployée de `e2ee_add_active_device` se contente d'un
--   active_devices = ARRAY(SELECT DISTINCT unnest(active_devices || ARRAY[p_device_id]))
-- sans aucun contrôle de nombre. Le seul test des 5 appareils vit côté client,
-- dans `DeviceSyncService.registerCurrentDevice`, qui n'est PAS sur le chemin
-- vivant : la publication réelle passe par
-- `KeyManagerService._publishKeysToSupabase`, qui appelle la RPC directement.
-- « 3 appareils sur 5 » et « au-delà de 5, il faudra en révoquer un » sont donc
-- des promesses que le backend ne tient pas.
--
-- Ce n'est pas cosmétique : tout message destiné au compte doit être chiffré
-- pour CHAQUE appareil actif, identités mortes comprises.
--
-- CHOIX DE CONCEPTION : élaguer, ne pas refuser.
-- Refuser au-delà de 5 bloquerait la publication des clés d'un appareil
-- légitime. L'échec étant silencieux côté client, l'utilisateur retomberait sur
-- le repli AES global sans jamais le savoir — une régression pire que le mal.
-- On conserve donc les 5 appareils les plus récemment actifs, en gardant
-- toujours celui qui vient de s'enregistrer.
--
-- ⚠️ NON DÉPLOYÉ ET NON TESTÉ. À relire, puis à exécuter sur une branche
-- Supabase ou un projet de test avant la production : l'auteur n'a pas pu
-- l'exécuter (modifier une fonction déployée agit immédiatement sur la prod).

CREATE OR REPLACE FUNCTION public.e2ee_add_active_device(
  p_user_id text,
  p_device_id text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE
  v_max_devices constant int := 5;
BEGIN
  INSERT INTO e2ee_user_keys (user_id, e2ee_enabled, e2ee_version, active_devices, updated_at)
  VALUES (p_user_id, TRUE, 1, ARRAY[p_device_id], NOW())
  ON CONFLICT (user_id) DO UPDATE
    SET active_devices = (
          SELECT ARRAY(
            SELECT DISTINCT unnest(e2ee_user_keys.active_devices || ARRAY[p_device_id])
          )
        ),
        e2ee_enabled = TRUE,
        updated_at   = NOW();

  -- Élagage : on garde les v_max_devices plus récemment actifs.
  -- `dev = p_device_id` en tête du tri garantit que l'appareil qui vient de
  -- s'enregistrer n'est jamais celui qu'on retire, même sans `last_active`.
  UPDATE e2ee_user_keys u
  SET active_devices = (
        SELECT ARRAY(
          SELECT dev
          FROM unnest(u.active_devices) AS dev
          LEFT JOIN e2ee_devices d
            ON d.user_id = u.user_id AND d.device_id = dev
          ORDER BY (dev = p_device_id) DESC, d.last_active DESC NULLS LAST
          LIMIT v_max_devices
        )
      ),
      updated_at = NOW()
  WHERE u.user_id = p_user_id
    AND array_length(u.active_devices, 1) > v_max_devices;
END;
$function$;
