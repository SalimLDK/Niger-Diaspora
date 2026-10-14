-- Un jeton push n'appartient qu'à un seul compte.
--
-- Audit des notifications du 2026-10-14, constat n° 1. Trois faits qui, mis
-- bout à bout, laissaient n'importe quel compte faire sonner le téléphone de
-- n'importe qui d'autre :
--
-- 1. `fcm_tokens` et `voip_token` d'autrui sont LISIBLES (la fermeture par
--    colonnes, `supabase/users-colonnes-privees-cible.sql`, attend encore sa
--    version cliente publiée) ;
-- 2. rien n'empêchait un jeton d'être rattaché à DEUX comptes :
--    `ajouter_jeton_push` ne regardait que la ligne de l'appelant, et
--    `users_update_own` laisse écrire `fcm_tokens` et `voip_token` en direct ;
-- 3. tout ce qui pousse vers un compte (`send-push`, `onCallCreated`) envoie
--    à TOUS ses jetons.
--
-- L'attaquant copiait le jeton de sa victime dans sa propre ligne, se faisait
-- appeler par un second compte à lui : l'écran d'appel entrant s'affichait
-- sur le téléphone de la victime, avec le nom de son choix, et le blocage —
-- vérifié entre ses deux comptes — ne voyait rien.
--
-- Le point 1 ne peut pas se fermer aujourd'hui (il casserait les versions
-- installées). On ferme le point 2 : LE PREMIER COMPTE QUI DÉTIENT UN JETON LE
-- GARDE. Un jeton n'est lisible par autrui qu'une fois enregistré par son
-- propriétaire — trop tard pour se l'approprier.
--
-- Le cas légitime d'un téléphone qui change de compte : le client retire son
-- jeton à la déconnexion (`retirer_jeton_push`) puis en demande un neuf à
-- Firebase (`deleteToken`). Si la déconnexion s'est faite hors ligne, le
-- jeton reste sur l'ancien compte ; le nouveau reçoit alors 23505 de
-- `ajouter_jeton_push`, et le client fait tourner son jeton une fois.
--
-- Banc : tools/rls_tests/jeton_push_un_seul_compte.sql

-- ── 1. Les doublons d'aujourd'hui ────────────────────────────────────────────
-- Impossible de savoir lequel des comptes est le légitime : le jeton est
-- retiré de TOUS. L'appareil se réenregistre à son prochain lancement
-- (`saveTokenForUser`, à chaque démarrage), et c'est alors lui le premier.
WITH doublons AS (
  SELECT e AS jeton
    FROM public.users u,
         jsonb_array_elements(CASE WHEN jsonb_typeof(u.fcm_tokens) = 'array'
                                   THEN u.fcm_tokens ELSE '[]'::jsonb END) e
   GROUP BY e
  HAVING count(DISTINCT u.id) > 1
)
UPDATE public.users u
   SET fcm_tokens = (
         SELECT coalesce(jsonb_agg(x), '[]'::jsonb)
           FROM jsonb_array_elements(u.fcm_tokens) x
          WHERE x NOT IN (SELECT jeton FROM doublons))
 WHERE jsonb_typeof(u.fcm_tokens) = 'array'
   AND EXISTS (SELECT 1 FROM jsonb_array_elements(u.fcm_tokens) x
                WHERE x IN (SELECT jeton FROM doublons));

UPDATE public.users
   SET voip_token = NULL
 WHERE voip_token IN (SELECT voip_token FROM public.users
                       WHERE voip_token IS NOT NULL
                       GROUP BY voip_token HAVING count(*) > 1);

-- `@>` sur `fcm_tokens` : servi par cet index (jsonb_ops).
CREATE INDEX IF NOT EXISTS users_fcm_tokens_gin
  ON public.users USING gin (fcm_tokens);
CREATE INDEX IF NOT EXISTS users_voip_token_idx
  ON public.users (voip_token) WHERE voip_token IS NOT NULL;

-- ── 2. La garde, sur TOUTE écriture ──────────────────────────────────────────
-- Un déclencheur plutôt qu'un refus dans la seule RPC : les versions
-- installées écrivent encore `voip_token` en direct, et `users_update_own`
-- laisse écrire `fcm_tokens` de même. Un jeton déjà tenu par un autre compte
-- est RETIRÉ de l'écriture, sans erreur — une version installée qui
-- enregistre son jeton légitime ne doit pas voir tout son enregistrement de
-- profil échouer.
--
-- SECURITY DEFINER : il faut voir les jetons des profils privés, que le RLS
-- de l'appelant cache. Aucune décision ici ne dépend de `current_user`.
CREATE OR REPLACE FUNCTION private.jeton_push_d_un_seul_compte()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_garde jsonb := '[]'::jsonb;
  e       jsonb;
BEGIN
  IF jsonb_typeof(NEW.fcm_tokens) = 'array'
     AND (TG_OP = 'INSERT' OR NEW.fcm_tokens IS DISTINCT FROM OLD.fcm_tokens) THEN
    FOR e IN SELECT x FROM jsonb_array_elements(NEW.fcm_tokens) x LOOP
      IF TG_OP = 'UPDATE' AND jsonb_typeof(OLD.fcm_tokens) = 'array'
         AND OLD.fcm_tokens @> jsonb_build_array(e) THEN
        -- Déjà à lui : le garder (le retrait de jetons morts passe par ici).
        v_garde := v_garde || jsonb_build_array(e);
      ELSIF jsonb_typeof(e) = 'string'
        AND NOT EXISTS (SELECT 1 FROM public.users u
                         WHERE u.id <> NEW.id
                           AND u.fcm_tokens @> jsonb_build_array(e)) THEN
        v_garde := v_garde || jsonb_build_array(e);
      END IF;
    END LOOP;
    NEW.fcm_tokens := v_garde;
  END IF;

  IF NEW.voip_token IS NOT NULL
     AND (TG_OP = 'INSERT' OR NEW.voip_token IS DISTINCT FROM OLD.voip_token)
     AND EXISTS (SELECT 1 FROM public.users u
                  WHERE u.id <> NEW.id AND u.voip_token = NEW.voip_token) THEN
    NEW.voip_token := CASE WHEN TG_OP = 'UPDATE' THEN OLD.voip_token END;
  END IF;

  RETURN NEW;
END $$;

REVOKE ALL ON FUNCTION private.jeton_push_d_un_seul_compte() FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS trg_jeton_push_d_un_seul_compte ON public.users;
CREATE TRIGGER trg_jeton_push_d_un_seul_compte
  BEFORE INSERT OR UPDATE OF fcm_tokens, voip_token ON public.users
  FOR EACH ROW EXECUTE FUNCTION private.jeton_push_d_un_seul_compte();

-- ── 3. La RPC le dit, elle ───────────────────────────────────────────────────
-- Le client à jour a besoin de savoir que son jeton a été écarté, pour en
-- demander un neuf : 23505, au lieu du silence du déclencheur.
CREATE OR REPLACE FUNCTION public.ajouter_jeton_push(p_jeton text)
RETURNS void
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_uid text := public.firebase_uid();
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'ajouter_jeton_push : session requise' USING ERRCODE = '42501';
  END IF;
  -- Un jeton FCM fait ~160 caractères ; 4096 laisse de la marge sans
  -- permettre de gonfler la ligne.
  IF p_jeton IS NULL OR btrim(p_jeton) = '' OR length(p_jeton) > 4096 THEN
    RAISE EXCEPTION 'ajouter_jeton_push : jeton invalide' USING ERRCODE = '22023';
  END IF;
  IF EXISTS (SELECT 1 FROM public.users u
              WHERE u.id <> v_uid
                AND u.fcm_tokens @> jsonb_build_array(p_jeton)) THEN
    RAISE EXCEPTION 'ajouter_jeton_push : jeton rattaché à un autre compte'
      USING ERRCODE = '23505';
  END IF;

  UPDATE public.users u
     SET fcm_tokens = CASE
           WHEN jsonb_typeof(u.fcm_tokens) = 'array' AND u.fcm_tokens ? p_jeton
             THEN u.fcm_tokens
           WHEN jsonb_typeof(u.fcm_tokens) = 'array'
             THEN u.fcm_tokens || to_jsonb(p_jeton)
           ELSE jsonb_build_array(p_jeton)
         END,
         last_token_update = now()
   WHERE u.id = v_uid;
END $$;

REVOKE ALL ON FUNCTION public.ajouter_jeton_push(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.ajouter_jeton_push(text) TO authenticated;
