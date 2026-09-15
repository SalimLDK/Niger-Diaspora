-- Registre d'appareils MLS (plan MLS, phase 2).
--
-- POURQUOI CETTE PHASE VIENT EN PREMIER
-- Le chantier Signal s'est arrêté exactement ici sans que personne ne le
-- voie : 49 appareils enregistrés dans `e2ee_devices`, 4 581 prékeys, et
-- 0 message chiffré. Un registre qui n'est pas VIVANT rend le multi-appareil
-- fictif. La preuve de vie de cette phase est une requête, pas du code :
--   select count(*) from mls_devices where last_seen_at > now() - interval '7 days';
--
-- CE QUE LE SERVEUR VOIT
-- Des clés PUBLIQUES seulement : la clé de signature de l'appareil, sa
-- credential MLS (l'identité `uid:appareil` signée), et des KeyPackages —
-- conçus par RFC 9420 pour être distribués. La clé privée de signature et
-- les secrets HPKE des KeyPackages restent dans la base SQLite du moteur
-- Rust, sur l'appareil. Un opérateur de la base peut savoir qui a quel
-- appareil ; il ne peut rien déchiffrer.
--
-- CE QUE LE RLS NE GARANTIT PAS
-- Il n'empêche pas le serveur de SUBSTITUER un KeyPackage (confiance au
-- premier usage). Seule la vérification hors bande (phase 7) y répond.
--
-- POURQUOI `mls_` ET NON `devices`
-- `e2ee_devices` (Signal) reste en service tant que le legacy vit. Deux
-- tables « devices » sans préfixe auraient fini confondues dans un select.
--
-- IDENTIFIANTS
-- `user_id` est l'uid Firebase (text, 28 caractères), comme partout ;
-- `firebase_uid()` le rend. Pas de clé étrangère vers `users` : un compte
-- sans ligne `users` (ça existe, cf. la migration Supabase) doit quand même
-- pouvoir enregistrer son appareil — un refus ici serait muet.

-- ── Appareils ───────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.mls_devices (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id        text NOT NULL,
  -- `stableDeviceId()` : condensé du SSAID salé par l'uid, stable entre deux
  -- vidages de données. Même appareil + même compte = même ligne, jamais un
  -- doublon (le défaut de `e2ee_devices`, 2 → 3 lignes constaté le 2026-08-04).
  stable_id      text NOT NULL,
  name           text NOT NULL,
  platform       text NOT NULL CHECK (platform IN ('android', 'ios', 'web', 'desktop')),
  -- Identité portée par la credential MLS : `uid:stable_id`. Recopiée en
  -- clair pour que le client retrouve une ligne depuis un membre de groupe
  -- sans décoder de credential.
  mls_identity   text NOT NULL,
  signature_key  bytea NOT NULL,
  credential     bytea NOT NULL,
  created_at     timestamptz NOT NULL DEFAULT now(),
  last_seen_at   timestamptz NOT NULL DEFAULT now(),
  revoked_at     timestamptz,
  UNIQUE (user_id, stable_id)
);

CREATE INDEX IF NOT EXISTS mls_devices_user_actifs_idx
  ON public.mls_devices (user_id)
  WHERE revoked_at IS NULL;

ALTER TABLE public.mls_devices ENABLE ROW LEVEL SECURITY;

-- Lecture ouverte à tout compte connecté : pour ajouter quelqu'un à une
-- conversation, il faut voir SES appareils. Ce sont des clés publiques.
DROP POLICY IF EXISTS "mls_devices: lecture authentifiee" ON public.mls_devices;
CREATE POLICY "mls_devices: lecture authentifiee" ON public.mls_devices
  AS PERMISSIVE FOR SELECT TO authenticated
  USING (true);

DROP POLICY IF EXISTS "mls_devices: les siens" ON public.mls_devices;
CREATE POLICY "mls_devices: les siens" ON public.mls_devices
  AS PERMISSIVE FOR INSERT TO authenticated
  WITH CHECK (user_id = (SELECT firebase_uid()));

DROP POLICY IF EXISTS "mls_devices: modifier les siens" ON public.mls_devices;
CREATE POLICY "mls_devices: modifier les siens" ON public.mls_devices
  AS PERMISSIVE FOR UPDATE TO authenticated
  USING (user_id = (SELECT firebase_uid()))
  WITH CHECK (user_id = (SELECT firebase_uid()));

DROP POLICY IF EXISTS "mls_devices: supprimer les siens" ON public.mls_devices;
CREATE POLICY "mls_devices: supprimer les siens" ON public.mls_devices
  AS PERMISSIVE FOR DELETE TO authenticated
  USING (user_id = (SELECT firebase_uid()));

REVOKE ALL ON public.mls_devices FROM anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.mls_devices TO authenticated;

-- ── KeyPackages ─────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.mls_key_packages (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  device_id      uuid NOT NULL REFERENCES public.mls_devices (id) ON DELETE CASCADE,
  key_package    bytea NOT NULL,
  cipher_suite   text NOT NULL,
  -- Le « dernier recours » n'est jamais consommé : il évite qu'un appareil
  -- resté longtemps hors ligne devienne impossible à ajouter.
  is_last_resort boolean NOT NULL DEFAULT false,
  created_at     timestamptz NOT NULL DEFAULT now(),
  expires_at     timestamptz NOT NULL,
  used_at        timestamptz
);

CREATE INDEX IF NOT EXISTS mls_key_packages_disponibles_idx
  ON public.mls_key_packages (device_id, created_at)
  WHERE used_at IS NULL;

ALTER TABLE public.mls_key_packages ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "mls_key_packages: lecture authentifiee" ON public.mls_key_packages;
CREATE POLICY "mls_key_packages: lecture authentifiee" ON public.mls_key_packages
  AS PERMISSIVE FOR SELECT TO authenticated
  USING (true);

DROP POLICY IF EXISTS "mls_key_packages: publier pour son appareil" ON public.mls_key_packages;
CREATE POLICY "mls_key_packages: publier pour son appareil" ON public.mls_key_packages
  AS PERMISSIVE FOR INSERT TO authenticated
  WITH CHECK (EXISTS (
    SELECT 1 FROM public.mls_devices d
    WHERE d.id = device_id AND d.user_id = (SELECT firebase_uid())
  ));

DROP POLICY IF EXISTS "mls_key_packages: retirer les siens" ON public.mls_key_packages;
CREATE POLICY "mls_key_packages: retirer les siens" ON public.mls_key_packages
  AS PERMISSIVE FOR DELETE TO authenticated
  USING (EXISTS (
    SELECT 1 FROM public.mls_devices d
    WHERE d.id = device_id AND d.user_id = (SELECT firebase_uid())
  ));

-- Pas de policy UPDATE : consommer un paquet passe par `claim_key_package`,
-- qui le fait de façon atomique. Sans ça, deux ajouts concurrents prendraient
-- le même paquet et le second Welcome serait indéchiffrable.
REVOKE ALL ON public.mls_key_packages FROM anon;
GRANT SELECT, INSERT, DELETE ON public.mls_key_packages TO authenticated;

-- Réclamation atomique : un paquet frais si possible, le dernier recours
-- sinon, NULL si l'appareil n'a rien de valide. `FOR UPDATE SKIP LOCKED`
-- fait l'arbitrage entre deux réclamants.
CREATE OR REPLACE FUNCTION public.claim_key_package(p_device_id uuid)
RETURNS public.mls_key_packages
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $function$
DECLARE
  r public.mls_key_packages;
BEGIN
  IF (SELECT firebase_uid()) IS NULL THEN
    RAISE EXCEPTION 'claim_key_package: session requise' USING ERRCODE = '42501';
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

-- Un appareil révoqué n'a plus de paquets valides : personne ne doit pouvoir
-- l'ajouter à un groupe après coup.
CREATE OR REPLACE FUNCTION public.mls_devices_revocation()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $function$
BEGIN
  IF NEW.revoked_at IS NOT NULL AND OLD.revoked_at IS NULL THEN
    DELETE FROM public.mls_key_packages
     WHERE device_id = NEW.id AND used_at IS NULL;
  END IF;
  RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS mls_devices_revocation_trg ON public.mls_devices;
CREATE TRIGGER mls_devices_revocation_trg
  AFTER UPDATE OF revoked_at ON public.mls_devices
  FOR EACH ROW
  EXECUTE FUNCTION public.mls_devices_revocation();

-- ── Diagnostics ─────────────────────────────────────────────────────────────
--
-- Le motif d'un échec s'écrit EN BASE, jamais dans les journaux : `debugPrint`
-- ne remonte pas dans logcat sur un build release, et c'est ce qui a rendu la
-- panne Signal invisible pendant des semaines. Jamais un octet de contenu ici.

CREATE TABLE IF NOT EXISTS public.mls_diagnostics (
  id         bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  user_id    text NOT NULL,
  device_id  uuid,
  event      text NOT NULL,
  detail     jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS mls_diagnostics_created_at_idx
  ON public.mls_diagnostics (created_at);

ALTER TABLE public.mls_diagnostics ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "mls_diagnostics: ecrire les siens" ON public.mls_diagnostics;
CREATE POLICY "mls_diagnostics: ecrire les siens" ON public.mls_diagnostics
  AS PERMISSIVE FOR INSERT TO authenticated
  WITH CHECK (user_id = (SELECT firebase_uid()));

DROP POLICY IF EXISTS "mls_diagnostics: lire les siens ou admin" ON public.mls_diagnostics;
CREATE POLICY "mls_diagnostics: lire les siens ou admin" ON public.mls_diagnostics
  AS PERMISSIVE FOR SELECT TO authenticated
  USING (
    user_id = (SELECT firebase_uid())
    OR EXISTS (
      SELECT 1 FROM public.users u
      WHERE u.id = (SELECT firebase_uid()) AND u.is_admin = true
    )
  );

REVOKE ALL ON public.mls_diagnostics FROM anon;
GRANT SELECT, INSERT ON public.mls_diagnostics TO authenticated;
