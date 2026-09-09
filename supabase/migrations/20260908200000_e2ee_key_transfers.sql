-- Rendez-vous chiffré pour le transfert des clés d'un téléphone à l'autre.
--
-- POURQUOI CETTE TABLE
-- La seule reprise de clés existante passe par une sauvegarde chiffrée par
-- passphrase (`key_backups/<uid>/backup.enc`). Une passphrase perdue laisse un
-- appareil neuf en « à restaurer » à vie : pire que pas de sauvegarde du tout.
-- Ce chemin-ci n'en demande aucune — l'ancien téléphone envoie les clés au
-- nouveau, et le secret voyage par le QR code, pas par le réseau.
--
-- CE QUE LE SERVEUR VOIT
-- Rien d'utilisable. `payload` est le chiffré AES-256-GCM de l'export complet
-- du stockage sécurisé ; la clé est tirée au sort par l'appareil receveur,
-- affichée dans le QR et lue par la caméra de l'ancien. Elle ne transite jamais
-- ici. Un opérateur de la base voit un blob et un horodatage.
--
-- POURQUOI LA LIGNE EST QUAND MÊME PROTÉGÉE PAR RLS
-- Le QR peut être photographié par-dessus l'épaule. Sans RLS, l'id suffirait
-- alors à lire le blob et à le déchiffrer. Avec, il faut EN PLUS être connecté
-- sur le compte — ce qui rend le vol du QR seul inoffensif. Les deux appareils
-- sont authentifiés sur le même compte : `firebase_uid()` les couvre tous deux.
--
-- DURÉE DE VIE
-- Un transfert vit quelques minutes. La purge est faite par un trigger d'INSERT
-- (au niveau instruction) plutôt que par un cron : la table reste minuscule, et
-- personne n'a à se souvenir d'installer un planificateur. `SECURITY DEFINER`
-- est obligatoire — un trigger ordinaire s'exécute avec les droits de l'appelant
-- et la purge, filtrée par RLS, ne toucherait que ses propres lignes.

CREATE TABLE IF NOT EXISTS public.e2ee_key_transfers (
  id          text PRIMARY KEY,
  user_id     text NOT NULL,
  payload     text NOT NULL,
  nonce       text NOT NULL,
  mac         text NOT NULL,
  created_at  timestamptz NOT NULL DEFAULT now(),
  consumed_at timestamptz
);

CREATE INDEX IF NOT EXISTS e2ee_key_transfers_created_at_idx
  ON public.e2ee_key_transfers (created_at);

ALTER TABLE public.e2ee_key_transfers ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "e2ee_key_transfers: own transfers" ON public.e2ee_key_transfers;
CREATE POLICY "e2ee_key_transfers: own transfers" ON public.e2ee_key_transfers
  AS PERMISSIVE
  FOR ALL
  TO authenticated
  USING ((user_id = (SELECT firebase_uid())))
  WITH CHECK ((user_id = (SELECT firebase_uid())));

-- `anon` garde des droits de table sur presque tout le schéma : RLS est la
-- seule barrière ailleurs, on ne lui laisse pas même ça ici.
REVOKE ALL ON public.e2ee_key_transfers FROM anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.e2ee_key_transfers TO authenticated;

CREATE OR REPLACE FUNCTION public.e2ee_key_transfers_purge()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $function$
BEGIN
  DELETE FROM public.e2ee_key_transfers
  WHERE created_at < now() - interval '15 minutes';
  RETURN NULL;
END;
$function$;

DROP TRIGGER IF EXISTS e2ee_key_transfers_purge_trg ON public.e2ee_key_transfers;
CREATE TRIGGER e2ee_key_transfers_purge_trg
  AFTER INSERT ON public.e2ee_key_transfers
  FOR EACH STATEMENT
  EXECUTE FUNCTION public.e2ee_key_transfers_purge();
