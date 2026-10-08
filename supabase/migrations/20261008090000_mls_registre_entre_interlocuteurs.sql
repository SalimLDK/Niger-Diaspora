-- Registre MLS : servi à ses interlocuteurs seulement, et KeyPackages
-- réclamables par eux seuls.
--
-- LES DÉFAUTS (audit du 2026-10-03, P2 contrôle d'accès)
-- 1. `mls_devices` était lisible par tout compte connecté (`USING (true)`) :
--    nom de chaque appareil (« Pixel de … »), plateforme, date de création,
--    et `last_seen_at` — une présence en ligne — de n'importe quel
--    utilisateur, sans le moindre lien avec lui.
-- 2. `claim_key_package` (SECURITY DEFINER) servait n'importe quel appareil à
--    n'importe quel compte. Un inconnu pouvait épuiser les KeyPackages neufs
--    d'une cible : les ajouts suivants retombaient sur le paquet de dernier
--    recours, réutilisé de groupe en groupe.
-- 3. `mls_key_packages` était lisible par tous, alors que seul son
--    propriétaire le lit directement (compte de ses paquets) — les autres
--    passent par `claim_key_package`.
--
-- LE CORRECTIF
-- `partage_une_conversation_avec(autre)` : vrai pour soi-même, et pour qui
-- figure avec l'appelant dans une même conversation. C'est exactement le
-- besoin de MLS — on ne chiffre que pour ses interlocuteurs.
--   · `mls_devices` : lisible par ses interlocuteurs ;
--   · `claim_key_package` : refusé (42501) hors interlocuteurs ;
--   · `mls_key_packages` : lisible par son propriétaire seul.
-- Les fonctions SECURITY DEFINER (notifications, RPC) ne sont pas touchées.
--
-- Ce qui change à l'écran : scanner le code de sécurité d'un appareil dont
-- on ne partage aucune conversation répond « appareil inconnu » — on
-- vérifie un interlocuteur.
--
-- Banc : tools/rls_tests/mls_registre_entre_interlocuteurs.sql

-- Index des policies de la messagerie (`participant_ids @> ARRAY[…]`), que
-- le dépôt ne déclarait nulle part : la table a été créée hors migrations.
CREATE INDEX IF NOT EXISTS conversations_participant_ids_gin
  ON public.conversations USING gin (participant_ids);

-- SECURITY DEFINER : lue depuis une policy, elle ne doit pas repasser par la
-- RLS de `conversations` (récursion, et lecture filtrée).
CREATE OR REPLACE FUNCTION public.partage_une_conversation_avec(p_autre TEXT)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
  SELECT p_autre IS NOT NULL
     AND public.firebase_uid() IS NOT NULL
     AND (
       p_autre = public.firebase_uid()
       OR EXISTS (
         SELECT 1 FROM public.conversations c
          WHERE c.participant_ids @> ARRAY[public.firebase_uid(), p_autre]
       )
     );
$$;

REVOKE ALL ON FUNCTION public.partage_une_conversation_avec(TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.partage_une_conversation_avec(TEXT) TO authenticated;

DROP POLICY IF EXISTS "mls_devices: lecture authentifiee" ON public.mls_devices;
DROP POLICY IF EXISTS "mls_devices: lecture entre interlocuteurs" ON public.mls_devices;
CREATE POLICY "mls_devices: lecture entre interlocuteurs" ON public.mls_devices
  AS PERMISSIVE FOR SELECT TO authenticated
  USING (public.partage_une_conversation_avec(user_id));

DROP POLICY IF EXISTS "mls_key_packages: lecture authentifiee" ON public.mls_key_packages;
DROP POLICY IF EXISTS "mls_key_packages: lecture des siens" ON public.mls_key_packages;
CREATE POLICY "mls_key_packages: lecture des siens" ON public.mls_key_packages
  AS PERMISSIVE FOR SELECT TO authenticated
  USING (EXISTS (
    SELECT 1 FROM public.mls_devices d
     WHERE d.id = device_id AND d.user_id = (SELECT public.firebase_uid())
  ));

-- Repris de 20260915100000, avec la garde des interlocuteurs.
CREATE OR REPLACE FUNCTION public.claim_key_package(p_device_id uuid)
RETURNS public.mls_key_packages
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $function$
DECLARE
  r public.mls_key_packages;
  v_proprietaire text;
BEGIN
  IF (SELECT firebase_uid()) IS NULL THEN
    RAISE EXCEPTION 'claim_key_package: session requise' USING ERRCODE = '42501';
  END IF;

  SELECT user_id INTO v_proprietaire FROM public.mls_devices WHERE id = p_device_id;
  IF v_proprietaire IS NULL THEN
    RETURN NULL;
  END IF;
  IF NOT public.partage_une_conversation_avec(v_proprietaire) THEN
    RAISE EXCEPTION 'claim_key_package: aucune conversation commune'
      USING ERRCODE = '42501';
  END IF;

  UPDATE public.mls_key_packages
     SET used_at = now()
   WHERE id = (
     SELECT id FROM public.mls_key_packages
      WHERE device_id = p_device_id
        AND used_at IS NULL
        AND NOT is_last_resort
        AND expires_at > now()
      ORDER BY created_at
      LIMIT 1
      FOR UPDATE SKIP LOCKED
   )
  RETURNING * INTO r;

  IF r.id IS NULL THEN
    SELECT * INTO r FROM public.mls_key_packages
     WHERE device_id = p_device_id
       AND is_last_resort
       AND expires_at > now()
     ORDER BY created_at DESC
     LIMIT 1;
  END IF;

  RETURN r;
END;
$function$;

REVOKE ALL ON FUNCTION public.claim_key_package(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.claim_key_package(uuid) TO authenticated;

NOTIFY pgrst, 'reload schema';
