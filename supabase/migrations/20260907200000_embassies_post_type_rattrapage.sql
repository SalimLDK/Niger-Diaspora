-- Rattrapage : `post_type` manquait, l'annuaire etait vide pour tout le monde.
--
-- CE FICHIER EST UN DEPANNAGE, PAS LA CORRECTION DEFINITIVE. Il appartient a
-- l'auteur de `20260907190000_annuaire_postes_diplomatiques.sql` de trancher
-- ce qui suit -- voir la note en fin de fichier.
--
-- Ce qui s'est passe : la version de `20260907190000` qui a REELLEMENT tourne
-- creait la colonne `type` et l'index `embassies_type_idx`. Le fichier a
-- ensuite ete edite pour renommer la colonne en `post_type`, mais la ligne
-- `20260907190000` etait deja inscrite dans `supabase_migrations.schema_migrations` :
-- `db push` ne rejoue pas une version deja enregistree, donc le renommage
-- n'a jamais atteint la base. Constat en production le 2026-09-07 :
--
--   colonnes : ... type ...          <- pas de post_type
--   index    : embassies_type_idx    <- pas de embassies_post_type_idx
--
-- Effet visible : `EmbassiesSupabaseDataSource` selectionne `post_type`, la
-- requete echoue en 42703, `PostgrestException` devient `ServerException`, et
-- `EmbassiesRepositoryImpl` retombe sur un cache vide puis renvoie `[]`. L'ecran
-- affiche « Aucune ambassade disponible » sans qu'aucune erreur ne remonte
-- nulle part -- l'annuaire etait donc vide pour TOUS les utilisateurs, en
-- silence.

ALTER TABLE public.embassies ADD COLUMN IF NOT EXISTS post_type text;

UPDATE public.embassies
   SET post_type = type
 WHERE post_type IS DISTINCT FROM type;

CREATE INDEX IF NOT EXISTS embassies_post_type_idx
  ON public.embassies (post_type);

-- Volontairement PAS de CHECK ni de NOT NULL ici.
--
-- `20260907190000` declare
--   CHECK (post_type IN ('embassy', 'consulate', 'permanent_mission'))
-- alors que les 32 lignes en base portent aujourd'hui :
--
--   embassy 25 | consulate 4 | mission 2 | delegation 1
--
-- Trois lignes violeraient donc la contrainte. Decider si `mission` devient
-- `permanent_mission`, et ce que devient `delegation`, est un choix de
-- modelisation qui revient a l'auteur de l'annuaire -- pas a une migration de
-- depannage.
--
-- A FAIRE par cet auteur, en une seule migration :
--   1. remapper les valeurs `mission` / `delegation` ;
--   2. poser le CHECK et le NOT NULL prevus ;
--   3. supprimer `type` (et `embassies_type_idx`) une fois plus rien ne la
--      lisant, ou faire l'inverse et revenir a `type` cote Dart.
-- Tant que les deux colonnes coexistent, une fiche modifiee par le back-office
-- peut les desynchroniser.
