-- =============================================================================
-- `businesses.owner_id` retrouve sa cle etrangere vers `users`.
--
-- Constat du 2026-09-09, en branchant l'annuaire sur Supabase : la requete
-- `businesses?select=*,users(display_name)` echoue en **PGRST200** — « no
-- foreign key relationship between 'businesses' and 'users' ». La table n'a
-- AUCUNE cle etrangere, alors que le schema initial
-- (`20260522223150_initial_schema.sql`) declare bien
-- `owner_id TEXT NOT NULL REFERENCES users(id)`.
--
-- Explication : la table existait deja, importee depuis Firestore le
-- 2026-04-12. Le `CREATE TABLE IF NOT EXISTS` du schema initial n'a donc rien
-- cree — ni la cle etrangere, ni le `DEFAULT TRUE` de `is_active`, ce qui est
-- aussi pourquoi les deux lignes importees etaient invisibles.
--
-- 24 autres contraintes pointent deja vers `users` : c'est la norme du schema,
-- pas une exception. Aucune ligne orpheline (verifie avant d'ecrire cette
-- migration), l'ajout ne peut donc pas echouer sur des donnees existantes.
-- =============================================================================

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
     WHERE conname = 'businesses_owner_id_fkey'
       AND conrelid = 'public.businesses'::regclass
  ) THEN
    ALTER TABLE public.businesses
      ADD CONSTRAINT businesses_owner_id_fkey
      FOREIGN KEY (owner_id) REFERENCES public.users(id);
  END IF;
END
$$;

-- L'annuaire filtre et trie sur ces colonnes a chaque ouverture ; l'import ne
-- les a pas indexees non plus.
CREATE INDEX IF NOT EXISTS businesses_owner_idx ON public.businesses (owner_id);
CREATE INDEX IF NOT EXISTS businesses_actives_idx
  ON public.businesses (is_boosted DESC, created_at DESC)
  WHERE is_active = true;
