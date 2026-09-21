-- Annuaire des entreprises : `rating` et `review_count` deviennent calculés
-- par la base, à partir de `business_reviews`.
--
-- ═══ CE QUI ÉTAIT FAUX ════════════════════════════════════════════════════
--
-- `_versLigne` (business_supabase_datasource.dart) excluait ces colonnes en
-- les disant tenues par « des triggers d'agrégat ». Mesuré le 2026-09-21 en
-- production : aucun déclencheur sur `business_reviews`, aucune fonction qui
-- écrive `businesses.rating` ou `review_count`. Sur `businesses` ne vivent que
-- `businesses_updated_at` et la garde `businesses_garde_privileges`
-- (20260921071500), qui REFUSE désormais toute écriture cliente de ces
-- colonnes — elle les protège, elle n'en calcule aucune.
--
-- ═══ CE QUE CETTE MIGRATION NE RÉPARE PAS ═════════════════════════════════
--
-- (Suite : 20260921090000 fait basculer les avis sur cette table. Le
-- paragraphe ci-dessous décrit l'état au moment où celle-ci a été écrite.)
--
-- ⚠️ L'application n'écrit PAS les avis ici. `review_remote_datasource.dart`
-- les dépose dans la collection FIRESTORE `business_reviews`, et
-- `onReviewCreated/Updated/Deleted` (functions/index.js) recalcule la note
-- dans le document FIRESTORE `businesses/<id>` — qui n'existe plus depuis la
-- bascule du module sur Supabase (2026-09-10). Ce déclencheur est donc la
-- moitié serveur de la cible : il ne changera rien à l'écran tant que les avis
-- n'auront pas basculé à leur tour. Tant que ce n'est pas fait, la table
-- Supabase reste vide (0 ligne, mesuré) et fermée au client (RLS actif, AUCUNE
-- policy) : ce déclencheur ne s'y déclenchera que par le serveur.
--
-- `follower_count` n'a AUCUNE source : pas de table d'abonnement aux
-- entreprises, ni côté Supabase (`user_follows` relie des comptes à des
-- comptes, et `update_follow_counts` n'écrit que `users`) ni dans le code
-- client. Il n'y a rien à agréger ; la colonne reste à 0, gardée par la garde.
--
-- ═══ LA FORME ═════════════════════════════════════════════════════════════
--
-- SECURITY DEFINER, propriétaire `postgres` (celui qui applique `db push`).
-- En `SECURITY INVOKER`, la fonction s'exécuterait sous `authenticated` quand
-- un compte dépose un avis, et casserait de DEUX façons — mesurées par la
-- contre-épreuve du banc, pas déduites :
--   · avis d'un client quelconque : `businesses_update_owner` réduit l'UPDATE
--     de la fiche à 0 ligne, EN SILENCE. L'avis passe, la note reste figée ;
--     la garde n'est même pas atteinte (cas 18).
--   · avis du propriétaire de la fiche : la policy le laisse passer, la garde
--     lève 42501 « note, avis, abonnés et vues sont des agrégats », et c'est
--     l'AVIS entier qui est refusé (cas 19).
-- Sous DEFINER, `current_user` vaut `postgres` pendant l'UPDATE, hors RLS, et
-- la garde (INVOKER) le voit ainsi : `current_user NOT IN ('authenticated',
-- 'anon')`, chemin de confiance. Vérifié : cas 2 (catalogue), 7 à 16 (un
-- client), 17 (le propriétaire, garde réellement atteinte et traversée).
--
-- On RECALCULE, on n'incrémente pas : un compteur `+1/-1` dérive au premier
-- avis perdu, un agrégat se répare au prochain. Seuls les avis `published`
-- comptent — c'était déjà la règle de `recalculateBusinessRating` côté
-- Firestore ; un avis signalé (`flagged`) sort de la moyenne.
--
-- Sans avis publié : `rating` NULL (défaut de la colonne, « pas encore
-- noté ») et `review_count` 0. Le client lit NULL comme 0,0.
--
-- Concurrence : deux avis déposés en même temps sur la même fiche calculeraient
-- chacun leur moyenne sur un instantané qui ignore l'autre. D'où le verrou sur
-- la ligne de l'entreprise AVANT le calcul : en READ COMMITTED, chaque
-- instruction de la fonction prend un nouvel instantané, donc le second
-- attend le premier puis compte son avis.
--
-- Pas de clé étrangère de `business_reviews.business_id` vers `businesses` :
-- un avis orphelin met simplement à jour zéro ligne.
--
-- Banc : tools/rls_tests/agregats_avis_entreprises.sql

BEGIN;

CREATE OR REPLACE FUNCTION public.businesses_recalculer_avis(p_business_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
BEGIN
  IF p_business_id IS NULL THEN
    RETURN;
  END IF;

  PERFORM 1 FROM public.businesses WHERE id = p_business_id FOR UPDATE;

  UPDATE public.businesses b
     SET rating       = a.moyenne,
         review_count = a.nombre
    FROM (SELECT round(avg(r.rating), 2) AS moyenne,
                 count(*)::int           AS nombre
            FROM public.business_reviews r
           WHERE r.business_id = p_business_id
             AND r.status = 'published') a
   WHERE b.id = p_business_id
     AND (b.rating       IS DISTINCT FROM a.moyenne
       OR b.review_count IS DISTINCT FROM a.nombre);
END $$;

-- Une fonction utilitaire n'a pas à être appelable par PostgREST : elle ne
-- fait rien de dangereux, mais un `rpc` ouvert à tous est une surface de plus.
REVOKE ALL ON FUNCTION public.businesses_recalculer_avis(uuid) FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.business_reviews_agreger()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
BEGIN
  IF TG_OP IN ('UPDATE', 'DELETE') THEN
    PERFORM public.businesses_recalculer_avis(OLD.business_id);
  END IF;

  -- Un avis déplacé d'une fiche à l'autre recalcule les deux.
  IF TG_OP = 'INSERT'
     OR (TG_OP = 'UPDATE' AND NEW.business_id IS DISTINCT FROM OLD.business_id) THEN
    PERFORM public.businesses_recalculer_avis(NEW.business_id);
  END IF;

  RETURN NULL;
END $$;

REVOKE ALL ON FUNCTION public.business_reviews_agreger() FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS business_reviews_agreger ON public.business_reviews;

-- `UPDATE OF` : un « utile » (`helpful_count`) ou une retouche du texte ne
-- touche pas la moyenne, inutile de verrouiller la fiche pour ça.
CREATE TRIGGER business_reviews_agreger
  AFTER INSERT OR DELETE OR UPDATE OF rating, status, business_id
  ON public.business_reviews
  FOR EACH ROW EXECUTE FUNCTION public.business_reviews_agreger();

-- ── Rattrapage ─────────────────────────────────────────────────────────────
-- Toutes les fiches, y compris celles sans avis : une fiche à `rating = 0.00`
-- sans avis publié repasse à NULL, pour que les deux états n'en fassent qu'un.
UPDATE public.businesses b
   SET rating       = a.moyenne,
       review_count = coalesce(a.nombre, 0)
  FROM public.businesses b2
  LEFT JOIN (SELECT business_id,
                    round(avg(rating), 2) AS moyenne,
                    count(*)::int         AS nombre
               FROM public.business_reviews
              WHERE status = 'published'
              GROUP BY business_id) a ON a.business_id = b2.id
 WHERE b.id = b2.id
   AND (b.rating       IS DISTINCT FROM a.moyenne
     OR b.review_count IS DISTINCT FROM coalesce(a.nombre, 0));

COMMIT;
