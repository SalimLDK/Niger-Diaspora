-- =============================================================================
-- `blocked_users` : rendre la recherche INVERSE possible.
--
-- Le blocage est écrit dans les deux sens côté Firestore (`blockUser` ajoute
-- l'auteur du blocage dans le `blockedByUserIds` de sa cible, « for reverse
-- lookup »), mais les profils viennent de Supabase et
-- `profile_supabase_datasource._mapProfile` code en dur `blockedByUserIds: []`.
-- Résultat : les dix endroits de l'app qui demandent « cette personne m'a-t-elle
-- bloqué ? » reçoivent toujours non. Concrètement, si B bloque A, B ne voit
-- plus A — mais A continue de voir la position de B sur la carte, son statut
-- « en ligne », et peut toujours lui écrire.
--
-- La table `blocked_users(blocker_id, blocked_id)` existe déjà avec la bonne
-- forme, mais deux choses l'empêchent de servir :
--
-- 1. Sa politique unique `blocked_users_own` est en `ALL` sur
--    `firebase_uid() = blocker_id`. Elle ne laisse donc lire que les lignes où
--    l'on est le BLOQUEUR. La recherche inverse — les lignes où l'on est le
--    BLOQUÉ — est refusée en silence : la requête réussit et ne renvoie rien.
--    C'est le pire mode d'échec possible pour un garde de confidentialité.
--
-- 2. La table n'est pas dans la publication realtime, donc un blocage ne
--    prendrait effet chez la personne bloquée qu'au prochain chargement.
--
-- On sépare donc lecture et écriture :
--   - LECTURE  : les deux sens (je suis bloqueur OU bloqué) ;
--   - ÉCRITURE : le bloqueur seul, comme avant.
--
-- Ce que ça expose, et pourquoi c'est assumé : la personne bloquée peut
-- techniquement lire qu'elle l'a été. C'est déjà le cas côté Firestore, où
-- `blockedByUserIds` vit sur son propre document et lui est lisible. Masquer
-- l'information supposerait de filtrer côté serveur, dans des RPC, sans jamais
-- rien renvoyer au client — un autre chantier. Le client a besoin de la liste
-- pour appliquer le blocage.
--
-- Idempotent : sûr à rejouer.
-- =============================================================================

DROP POLICY IF EXISTS blocked_users_own ON public.blocked_users;
DROP POLICY IF EXISTS blocked_users_select ON public.blocked_users;
DROP POLICY IF EXISTS blocked_users_insert ON public.blocked_users;
DROP POLICY IF EXISTS blocked_users_delete ON public.blocked_users;

-- Lecture : les deux sens.
CREATE POLICY blocked_users_select ON public.blocked_users
    FOR SELECT
    USING (
        (SELECT firebase_uid()) = blocker_id
        OR (SELECT firebase_uid()) = blocked_id
    );

-- Écriture : on ne bloque que pour soi-même.
CREATE POLICY blocked_users_insert ON public.blocked_users
    FOR INSERT
    WITH CHECK ((SELECT firebase_uid()) = blocker_id);

CREATE POLICY blocked_users_delete ON public.blocked_users
    FOR DELETE
    USING ((SELECT firebase_uid()) = blocker_id);

-- Aucune politique UPDATE : la table n'a que sa clé primaire et `created_at`,
-- il n'y a rien à modifier. Bloquer puis débloquer, c'est INSERT puis DELETE.

-- Un blocage doit prendre effet tout de suite chez la personne bloquée, pas au
-- prochain chargement d'écran. REPLICA IDENTITY FULL : nécessaire pour que les
-- événements DELETE (déblocage) portent l'ancienne ligne et passent la RLS.
ALTER TABLE public.blocked_users REPLICA IDENTITY FULL;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND schemaname = 'public'
      AND tablename = 'blocked_users'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.blocked_users;
  END IF;
END $$;

-- Index pour la recherche inverse. La clé primaire `(blocker_id, blocked_id)`
-- sert déjà le sens direct ; elle ne sert à rien quand on filtre sur la
-- seconde colonne seule.
CREATE INDEX IF NOT EXISTS blocked_users_blocked_id_idx
    ON public.blocked_users (blocked_id);

NOTIFY pgrst, 'reload schema';
