-- `users` : les trois lectures dont la fermeture 1.1b aura besoin.
--
-- ═══ LE PROBLÈME, ET POURQUOI CETTE MIGRATION NE FERME RIEN ═══════════════
--
-- Un compte connecté lit, chez tout profil non privé, `email`,
-- `phone_number`, `latitude`, `longitude`, `fcm_tokens`, `voip_token`,
-- `session_id`, `cart_data`, `ban_reason`. Mesuré le 2026-09-21 sous
-- l'identité d'un compte ordinaire : 127 profils lisibles, 89 e-mails,
-- 65 positions, 64 jeux de jetons push, 35 identifiants de session.
--
-- Et deux consentements que le serveur n'applique pas :
--   · `share_location` — 6 personnes l'ont coupé et restent localisables,
--     dont 2 avec une position de moins de 30 jours. La carte ne les
--     écarte que parce que le CLIENT ajoute `.eq('share_location', true)` ;
--     une requête qui l'omet les obtient ;
--   · `phone_visibility` — 1 téléphone réglé sur `private` reste lisible.
--
-- La seule fermeture est `REVOKE SELECT` + `GRANT SELECT (colonnes
-- publiques)`. Elle ne peut PAS être posée aujourd'hui : 13 sites de l'app
-- lisent `users` sans nommer leurs colonnes (10 `select()` nus, un
-- `.stream()`, le `RETURNING *` de l'upsert de `updateProfile`), et sous
-- droits par colonnes PostgREST refuse la requête ENTIÈRE en 42501 — tous
-- les builds installés perdraient profil, carte, recherche et liste des
-- discussions.
--
-- Cette migration pose donc ce que la version cliente appellera, et rien
-- d'autre. Elle est ADDITIVE : aucun droit ne change, aucune lecture
-- existante n'est touchée. La fermeture elle-même est écrite à part, en
-- cible non appliquée : `supabase/cibles/users_colonnes_privees.sql`.
--
-- ═══ LE PRINCIPE QUI DICTE LA FORME ═══════════════════════════════════════
--
-- Un droit par colonne vaut pour TOUT le rôle, jamais par ligne. Or chaque
-- colonne sensible est aussi nécessaire à son PROPRIÉTAIRE :
-- `session_service.dart:281` lit `session_id` et `is_banned` de sa propre
-- ligne pour éjecter un appareil révoqué ; `updateProfile` relit la ligne
-- qu'il vient d'écrire. Révoquer `session_id` sans autre voie ferait cesser
-- la révocation de session par un administrateur — sans un mot, parce que
-- le temps réel RETIRE une colonne révoquée au lieu d'échouer (mesuré :
-- `tools/rls_tests/temps_reel_droits_colonnes.sql`).
--
-- D'où des fonctions `SECURITY DEFINER` : elles s'exécutent sous le
-- propriétaire de la table, donc hors des droits par colonne, et c'est À
-- ELLES d'appliquer la règle de ligne que le GRANT ne sait pas exprimer.
-- Contrepartie : elles contournent aussi le RLS. Chacune est donc écrite
-- pour n'être NULLE PART plus large que `users_select`
-- (`NOT is_private OR is_admin() OR soi`), et le banc le vérifie.
--
-- Banc : tools/rls_tests/users_rpc_colonnes_privees.sql

-- ── 1. Sa propre ligne, entière ────────────────────────────────────────────
-- Pour `getProfile(soi)`, la relecture de `updateProfile`, et la lecture
-- initiale du guetteur de session. Une ligne au plus, la sienne, jamais
-- celle d'un autre : pas de paramètre, donc rien à falsifier.
CREATE OR REPLACE FUNCTION public.mon_profil_prive()
RETURNS SETOF public.users
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT u.*
    FROM public.users u
   WHERE (SELECT public.firebase_uid()) IS NOT NULL
     AND u.id = (SELECT public.firebase_uid());
$$;

REVOKE ALL ON FUNCTION public.mon_profil_prive() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.mon_profil_prive() TO authenticated;

-- ── 2. Les positions, avec le consentement appliqué par le serveur ─────────
-- Remplace la lecture de `getNearbyProfiles` (profile_supabase_datasource.dart
-- :259), qui obtenait les coordonnées par `SELECT *` et ne respectait
-- `share_location` que parce que le client le demandait.
--
-- Ne rend QUE l'identifiant, la position et sa date : l'identité se relit
-- ensuite par colonnes publiques. Séparer les deux, c'est ce qui permettra
-- de retirer `latitude`/`longitude` du GRANT sans perdre la carte.
--
-- Plus étroite que `users_select` sur un point, délibérément : la branche
-- `is_admin()` n'y est pas. Un administrateur n'a pas besoin de voir sur la
-- carte les profils privés, et une fonction qui contourne le RLS doit rester
-- en deçà, jamais au-delà.
--
-- Pas d'arrondi. La carte montre aujourd'hui la position exacte de qui la
-- partage ; arrondir est une décision de produit, pas de sécurité, et elle
-- touche la promesse de la fiche Play (« position approximative », voir le
-- suivi). À trancher avec la version cliente.
CREATE OR REPLACE FUNCTION public.positions_partagees(
  p_lat_min double precision,
  p_lat_max double precision,
  p_lng_min double precision,
  p_lng_max double precision,
  p_limite  integer DEFAULT 50
)
RETURNS TABLE (
  id                  text,
  latitude            double precision,
  longitude           double precision,
  location_updated_at timestamptz
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT u.id, u.latitude, u.longitude, u.location_updated_at
    FROM public.users u
   WHERE (SELECT public.firebase_uid()) IS NOT NULL
     -- Le consentement, enfin appliqué par le serveur.
     AND u.share_location IS TRUE
     AND u.is_visible IS TRUE
     -- `users_select`, repris MOT POUR MOT : `NOT is_private` écarte aussi les
     -- NULL, là où `IS NOT TRUE` les laisserait passer.
     AND (NOT u.is_private OR u.id = (SELECT public.firebase_uid()))
     AND u.latitude  BETWEEN p_lat_min AND p_lat_max
     AND u.longitude BETWEEN p_lng_min AND p_lng_max
   -- Même tri que la requête qu'elle remplace : sans ORDER BY, une troncature
   -- rend des lignes arbitraires (voir le commentaire de `getNearbyProfiles`).
   ORDER BY u.location_updated_at DESC NULLS LAST
   LIMIT LEAST(GREATEST(coalesce(p_limite, 50), 1), 100);
$$;

REVOKE ALL ON FUNCTION public.positions_partagees(
  double precision, double precision, double precision, double precision, integer
) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.positions_partagees(
  double precision, double precision, double precision, double precision, integer
) TO authenticated;

-- ── 3. Le back-office ──────────────────────────────────────────────────────
-- Remplace `fetchRecentUsers` (admin_provider.dart:372, 20 lignes) et
-- `fetchAllUsers` (:1512, `limit` paramétré) : même tri, même troncature.
-- Le back-office tourne sous le rôle `authenticated`, comme tout le monde —
-- sans cette fonction, le REVOKE lui retirerait l'e-mail et le motif de
-- bannissement des comptes qu'il administre. La leçon de `orders` du même
-- jour : ne jamais fermer une lecture sans vérifier que le chemin
-- d'administration la traverse encore.
--
-- `plpgsql` pour pouvoir LEVER : une fonction `sql` qui filtrerait sur
-- `is_admin()` rendrait zéro ligne à un non-administrateur, et un écran vide
-- se lit comme « aucun utilisateur », pas comme un refus.
CREATE OR REPLACE FUNCTION public.profils_admin(p_limite integer DEFAULT 50)
RETURNS SETOF public.users
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'profils_admin : réservé aux administrateurs'
      USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
    SELECT u.*
      FROM public.users u
     ORDER BY u.created_at DESC
     LIMIT LEAST(GREATEST(coalesce(p_limite, 50), 1), 500);
END $$;

REVOKE ALL ON FUNCTION public.profils_admin(integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.profils_admin(integer) TO authenticated;
