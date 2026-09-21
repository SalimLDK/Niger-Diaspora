-- Annuaire des entreprises : la promotion payante et le badge « vérifié »
-- cessent d'être en libre-service.
--
-- ═══ CE QUI ÉTAIT OUVERT ══════════════════════════════════════════════════
--
-- L'audit nommait `business_boosts`, « dont le client insère `status:'active'`,
-- `amount:0` ». C'est vrai, et c'est la plus petite moitié : cette table est
-- la QUITTANCE. L'EFFET payant, lui, est ailleurs.
--
-- 1. `businesses_update_owner` est un `FOR UPDATE` **sans `WITH CHECK`** et
--    sans restriction de colonnes : le propriétaire réécrivait TOUTE sa ligne.
--    Or elle porte `is_boosted` et `boost_expires_at` — la promotion payante —
--    et `is_verified`, le badge de confiance. Le client ne s'en prive pas :
--    `updateBusinessBoostStatus` (business_supabase_datasource.dart:431) pose
--    `is_boosted` directement, et `_versLigne` (:106) envoie `is_verified` à
--    chaque `createBusiness` / `updateBusiness`. Se booster et se vérifier
--    soi-même ne demandait aucune ruse : c'est le chemin nominal du code.
--
-- 2. `business_boosts` : `GRANT SELECT, INSERT … TO authenticated` écrit sans
--    `REVOKE` préalable. C'est le piège documenté au CLAUDE.md, et il est ici
--    en vrai : la table gardait **tous** les droits par défaut, pour `anon`
--    comme pour `authenticated` — DELETE, TRUNCATE et UPDATE compris. Le
--    `GRANT` donnait l'illusion d'une restriction et n'en posait aucune.
--    La policy d'INSERT ne vérifiait que l'identité de l'acheteur : montant,
--    devise, `status` et `end_date` étaient libres.
--
-- 3. `businesses` portait les mêmes droits par défaut pour `anon`, et ses
--    quatre policies étaient offertes à `public`.
--
-- ═══ POURQUOI UN DÉCLENCHEUR ET PAS UN `REVOKE` ═══════════════════════════
--
-- La restriction par colonnes est impossible ici. `updateBusiness`
-- (:338) envoie **toute** la ligne à chaque modification — changer le numéro
-- de téléphone réécrit `is_verified` avec sa valeur courante. Un
-- `REVOKE UPDATE (is_verified, …)` ferait donc échouer la requête ENTIÈRE en
-- 42501, sur la moindre retouche : c'est le piège de l'upsert, déjà payé sur
-- `mls_messages`. Postgres vérifie le privilège de colonne à la requête, pas
-- à la valeur.
--
-- Le motif maison est le déclencheur `SECURITY INVOKER`, déjà employé deux
-- fois dans ce schéma : `users_guard_admin_flags` (droits admin) et
-- `messages_garde_update` (identité d'un message). Il ne regarde pas les
-- colonnes écrites, mais les valeurs qui BOUGENT — donc une réécriture à
-- l'identique passe, et seule une tentative de changement lève.
--
-- ═══ CE QUE ÇA LAISSE ═════════════════════════════════════════════════════
--
-- Le propriétaire garde la main pleine sur sa fiche : nom, description,
-- photos, horaires, position, catégorie, étiquettes, services. Il crée,
-- modifie et supprime son entreprise comme avant.
--
-- Le back-office garde tout : il écrit `is_verified` (admin_provider.dart:547
-- et :577) et bascule la promotion (:~600) sous l'identité de
-- l'administrateur, par PostgREST — d'où la sortie `is_admin()` en tête du
-- déclencheur, sans laquelle la vérification des fiches cesserait de marcher.
-- La leçon de `orders` du même jour : ne jamais refermer une écriture sans
-- vérifier que le chemin d'administration la traverse encore.
--
-- `increment_business_view_count` est `SECURITY DEFINER` : elle s'exécute
-- sous le propriétaire de la fonction, donc par le chemin de confiance. Le
-- compteur de vues continue de monter.
--
-- ⚠️ RISQUE CONNU, ÉTROIT ET ASSUMÉ. `updateBusiness` renvoie le modèle que
-- l'écran détient. Si un administrateur vérifie la fiche pendant que son
-- propriétaire a l'écran d'édition ouvert, la prochaine modification, même
-- innocente, lèvera 42501 sur une valeur périmée. Fenêtre minuscule
-- (2 entreprises, drapeau `businessDirectory` fermé), et le remède définitif
-- est côté client : cesser d'envoyer ces colonnes. Consigné au suivi.
--
-- ═══ CE QUI EXISTE ════════════════════════════════════════════════════════
--
-- Mesuré le 2026-09-21 : 2 entreprises, **0 promue**, 0 quittance de boost.
-- Côté Firestore, `businesses`, `business_boosts`, `business_posts` et
-- `business_reviews` sont à 0 document — le module a basculé sur Supabase le
-- 2026-09-10. Le drapeau `businessDirectory` est fermé.
--
-- Rouvrir la promotion demandera un paiement confirmé côté serveur, et
-- `is_boosted` posé par une fonction, jamais par la fiche.
--
-- Banc : tools/rls_tests/boost_et_badge_verifie.sql

-- ── business_boosts : la quittance devient une lecture ─────────────────────
REVOKE ALL ON public.business_boosts FROM anon;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER
  ON public.business_boosts FROM authenticated;

DROP POLICY IF EXISTS "business_boosts: achat pour soi" ON public.business_boosts;

-- ── businesses : l'écriture reste au propriétaire, sauf ce qui se paie ─────
REVOKE ALL ON public.businesses FROM anon;

REVOKE TRUNCATE, REFERENCES, TRIGGER ON public.businesses FROM authenticated;

ALTER POLICY businesses_select_active ON public.businesses TO authenticated;
ALTER POLICY businesses_insert_own    ON public.businesses TO authenticated;
ALTER POLICY businesses_update_owner  ON public.businesses TO authenticated;
ALTER POLICY businesses_delete_owner  ON public.businesses TO authenticated;

CREATE OR REPLACE FUNCTION public.businesses_garde_privileges()
RETURNS trigger
LANGUAGE plpgsql
SET search_path TO 'public', 'pg_temp'
AS $$
BEGIN
  -- Chemins de confiance : `postgres` (migrations, déclencheurs, et toute
  -- fonction SECURITY DEFINER — dont `increment_business_view_count`) et
  -- `service_role` (Edge Functions). Seul ce qui arrive par PostgREST sous
  -- l'identité d'un compte est filtré ici.
  IF current_user NOT IN ('authenticated', 'anon') THEN
    RETURN NEW;
  END IF;

  -- Le back-office vérifie les fiches et bascule la promotion sous l'identité
  -- de l'administrateur, par PostgREST. Sans cette sortie, les deux cesseraient
  -- de marcher — en silence pour l'un, en 42501 pour l'autre.
  IF public.is_admin() THEN
    RETURN NEW;
  END IF;

  IF TG_OP = 'INSERT' THEN
    -- Une fiche naît sans badge et sans promotion. `_versLigne` envoie bien
    -- ces trois colonnes à la création, mais à `false`/`false`/`null` : le
    -- parcours nominal passe.
    IF coalesce(NEW.is_verified, false)
       OR coalesce(NEW.is_boosted, false)
       OR NEW.boost_expires_at IS NOT NULL THEN
      RAISE EXCEPTION
        'businesses : une fiche ne naît ni vérifiée ni promue (is_verified, is_boosted, boost_expires_at)'
        USING ERRCODE = '42501';
    END IF;
    RETURN NEW;
  END IF;

  -- On compare les VALEURS, pas les colonnes écrites : `updateBusiness`
  -- renvoie toute la ligne, donc une réécriture à l'identique doit passer.
  IF NEW.is_verified      IS DISTINCT FROM OLD.is_verified
     OR NEW.is_boosted       IS DISTINCT FROM OLD.is_boosted
     OR NEW.boost_expires_at IS DISTINCT FROM OLD.boost_expires_at
  THEN
    RAISE EXCEPTION
      'businesses : le badge vérifié et la promotion sont posés par le serveur, pas par la fiche'
      USING ERRCODE = '42501';
  END IF;

  -- Les compteurs. `_versLigne` ne les envoie pas — son commentaire les dit
  -- « tenus par des triggers d'agrégat », ce qui est faux aujourd'hui (aucun
  -- déclencheur n'existe sur `business_reviews`). Rien ne les protégeait donc
  -- d'un `PATCH` direct posant une note de 5.
  IF NEW.rating           IS DISTINCT FROM OLD.rating
     OR NEW.review_count    IS DISTINCT FROM OLD.review_count
     OR NEW.follower_count  IS DISTINCT FROM OLD.follower_count
     OR NEW.view_count      IS DISTINCT FROM OLD.view_count
  THEN
    RAISE EXCEPTION
      'businesses : note, avis, abonnés et vues sont des agrégats, pas des champs'
      USING ERRCODE = '42501';
  END IF;

  RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS businesses_garde_privileges ON public.businesses;

CREATE TRIGGER businesses_garde_privileges
  BEFORE INSERT OR UPDATE ON public.businesses
  FOR EACH ROW EXECUTE FUNCTION public.businesses_garde_privileges();
