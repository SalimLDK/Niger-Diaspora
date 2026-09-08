-- Retrait de `post_type` : mon depannage est devenu inutile, il ne doit pas
-- laisser de trace.
--
-- Enchainement, le 2026-09-07 :
--
--   1. `20260907190000` decrivait la colonne du type de poste sous le nom
--      `post_type`, et `EmbassiesSupabaseDataSource` la selectionnait sous ce
--      nom -- alors que la table qui tourne l'appelle `type`. La requete
--      echouait en 42703, l'exception etait avalee, et l'annuaire s'affichait
--      vide pour TOUS les utilisateurs, sans une erreur nulle part (constate
--      sur SM A515F).
--   2. `20260907200000` (le depannage) a ajoute `post_type` en la remplissant
--      depuis `type`, pour rendre l'annuaire visible le temps de trancher.
--   3. L'auteur de l'annuaire a tranche dans l'autre sens : `type` fait foi.
--      Sa migration corrigee et son datasource lisent desormais `type`.
--
-- `post_type` n'est donc plus lue par personne. La garder serait pire qu'un
-- reliquat : deux colonnes decrivant la meme chose, dont une seule est mise a
-- jour par le back-office, divergent des la premiere fiche modifiee -- et la
-- prochaine lecture qui tomberait sur la mauvaise serait juste fausse, sans
-- erreur pour le signaler.
--
-- Verifie avant retrait : les 32 lignes ont `post_type = type` (aucune
-- divergence a sauver), et plus aucun `.dart` ni `.sql` du depot ne cite
-- `post_type` en dehors d'un commentaire d'historique.

DROP INDEX IF EXISTS public.embassies_post_type_idx;

ALTER TABLE public.embassies DROP COLUMN IF EXISTS post_type;
