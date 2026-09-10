-- =============================================================================
-- `business_boosts` : la seule table qui manquait pour que l'annuaire quitte
-- Firestore.
--
-- Constat du 2026-09-09 : le module Entreprises (`BusinessRemoteDataSourceImpl`)
-- parle **Firestore**, alors que les entreprises vivent dans
-- `public.businesses`. Ouvrir `/businesses/<uuid>` — par lien profond, par QR
-- ou depuis l'annuaire — cherche un document Firestore absent et affiche
-- « Entreprise non trouvée ». Meme famille de defaut que les evenements,
-- corrigee le meme jour.
--
-- `businesses`, `business_posts` et `business_reviews` existent deja cote
-- Supabase. `business_boosts` n'existait pas : sans elle, la bascule du
-- datasource laisserait quatre methodes sans destination.
--
-- La table ne porte que ce que `BusinessBoostModel` expose, rien de plus.
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.business_boosts (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id       uuid NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
  -- `text` et non `uuid` : les identifiants de compte sont des uid Firebase,
  -- comme partout ailleurs dans ce schema (cf. `businesses.owner_id`).
  user_id           text NOT NULL REFERENCES public.users(id),
  type              text NOT NULL DEFAULT 'standard',
  duration          text NOT NULL DEFAULT 'days7',
  -- `numeric` et non `double precision` : c'est un montant.
  amount            numeric NOT NULL,
  currency          text NOT NULL DEFAULT 'XOF',
  start_date        timestamptz NOT NULL,
  end_date          timestamptz NOT NULL,
  status            text NOT NULL DEFAULT 'active',
  payment_reference text,
  created_at        timestamptz NOT NULL DEFAULT now()
);

-- `getActiveBoost` et `getBoostHistory` interrogent toutes deux par entreprise.
CREATE INDEX IF NOT EXISTS business_boosts_business_idx
  ON public.business_boosts (business_id, end_date DESC);

ALTER TABLE public.business_boosts ENABLE ROW LEVEL SECURITY;

-- Lecture : le proprietaire de l'entreprise et l'acheteur du boost. Personne
-- d'autre n'a besoin de l'historique de paiement d'un tiers — la fiche
-- publique lit `businesses.is_boosted`, pas cette table.
DROP POLICY IF EXISTS "business_boosts: proprietaire ou acheteur" ON public.business_boosts;
CREATE POLICY "business_boosts: proprietaire ou acheteur" ON public.business_boosts
  AS PERMISSIVE
  FOR SELECT
  TO authenticated
  USING (
    user_id = (SELECT public.firebase_uid())
    OR EXISTS (
      SELECT 1 FROM public.businesses b
       WHERE b.id = business_boosts.business_id
         AND b.owner_id = (SELECT public.firebase_uid())
    )
  );

-- Ecriture : seul l'acheteur pose sa ligne, et pour lui-meme.
DROP POLICY IF EXISTS "business_boosts: achat pour soi" ON public.business_boosts;
CREATE POLICY "business_boosts: achat pour soi" ON public.business_boosts
  AS PERMISSIVE
  FOR INSERT
  TO authenticated
  WITH CHECK (user_id = (SELECT public.firebase_uid()));

-- Sans ce GRANT, RLS n'est jamais atteint : la lecture echoue en amont, sur le
-- droit de table, et l'app ne voit qu'une erreur sans cause lisible.
GRANT SELECT, INSERT ON public.business_boosts TO authenticated;

-- ── `increment_business_view_count` ──────────────────────────────────────────
--
-- PostgREST ne sait pas incrementer : un lire-puis-ecrire depuis le client
-- perdrait des vues des que deux fiches sont ouvertes en meme temps, et
-- surtout il exigerait un droit d'UPDATE sur `businesses` pour un visiteur qui
-- n'en est pas proprietaire. La fonction fait l'increment en base, sous
-- SECURITY DEFINER, et ne touche que ce compteur.

CREATE OR REPLACE FUNCTION public.increment_business_view_count(p_business_id uuid)
RETURNS void
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  UPDATE public.businesses
     SET view_count = COALESCE(view_count, 0) + 1
   WHERE id = p_business_id
     AND is_active = true;
$$;

REVOKE ALL ON FUNCTION public.increment_business_view_count(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.increment_business_view_count(uuid) TO authenticated;
