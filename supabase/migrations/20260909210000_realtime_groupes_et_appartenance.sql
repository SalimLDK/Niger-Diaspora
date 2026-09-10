-- Ni `public.groups` ni `public.group_members` n'ont jamais été dans la
-- publication `supabase_realtime`. Relevé du 2026-09-09 sur le projet lié :
--
--   select tablename from pg_publication_tables
--    where pubname='supabase_realtime'
--      and tablename in ('groups','group_members','conversations',
--                        'group_requests','group_invites');
--   -> conversations, group_requests, group_invites
--
-- Conséquence : `GroupSupabaseDataSource.getGroupStream` est un
-- `.stream(primaryKey: ['id'])` sur `groups` qui ne fait **que son
-- chargement initial** et n'émet plus rien ensuite. Le commentaire du
-- provider (« Stream provider for real-time group updates ») décrit une
-- réactivité qui n'existait pas. D'où le défaut signalé : quand un admin
-- accepte une demande d'adhésion, ou qu'un membre quitte le groupe, l'écran
-- des autres utilisateurs garde l'ancienne liste et l'ancien compte jusqu'à
-- ce qu'ils quittent puis rouvrent la fiche.
--
-- Les deux tables sont nécessaires, pas seulement `groups` :
--
-- * `group_members` porte l'appartenance réelle. `groups.member_ids` est NULL
--   sur toutes les lignes et l'app recompose la liste depuis cette table
--   (`_membershipFor`). Un changement de rôle (membre -> admin) est un UPDATE
--   ici et ne touche aucune autre table.
-- * `groups` porte `member_count`, que `group_members_count_trigger` met à
--   jour sur INSERT/DELETE, et tout le reste de la fiche (nom, avatar,
--   description, permissions) que seul un UPDATE de cette table modifie.
--
-- RLS reste la seule barrière, et elle est déjà posée — Realtime évalue les
-- policies avec le JWT du client, comme pour `messages` :
--
-- * `group_members_select` : `firebase_uid() = user_id OR is_group_public(...)
--   OR is_group_member(...)`
-- * `groups_select_public` : `NOT is_private OR creator OR membre OR invité`
--
-- REPLICA IDENTITY reste à `default` pour les deux. Contrairement à
-- `notifications` (migration 20260823170000), cela ne coupe PAS les DELETE
-- utiles ici : la clé primaire de `group_members` est `(group_id, user_id)`,
-- donc un événement DELETE porte bien `group_id` et le filtre
-- `group_id=eq.<uuid>` de l'abonnement peut être évalué dessus. C'est
-- exactement l'événement « untel a quitté le groupe ». Passer à `full`
-- coûterait du WAL sans rien ajouter.

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
     WHERE pubname = 'supabase_realtime'
       AND schemaname = 'public'
       AND tablename = 'groups'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.groups;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
     WHERE pubname = 'supabase_realtime'
       AND schemaname = 'public'
       AND tablename = 'group_members'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.group_members;
  END IF;
END
$$;
