-- Migration des groupes hérités de Firestore vers public.groups (Supabase).
--
-- CONTEXTE
-- Le 2026-08-06, `groupRemoteDataSourceProvider` est passé de Firestore à
-- `GroupSupabaseDataSource`. Les groupes créés dans Supabase redeviennent donc
-- visibles et leur fiche s'ouvre. En contrepartie, les groupes restés côté
-- Firestore ne sont plus lisibles du tout : ils doivent être transférés ici.
--
-- POURQUOI UN NOUVEL IDENTIFIANT
-- `public.groups.id` est de type `uuid`, et un id hérité de Firestore fait
-- 20 caractères (ex. `yflqsRLMMhTPpiW0NFHx`) — il ne peut pas y être inséré.
-- On attribue donc un uuid neuf et on réaligne la référence. C'est possible
-- sans casse parce que `conversations.group_id` est de type **TEXT** (vérifié
-- en base) : la conversation, ses messages et ses épingles suivent le
-- changement sans migration de schéma.
--
-- PÉRIMÈTRE AU MOMENT DE L'ÉCRITURE
-- Un seul groupe hérité est référencé par une conversation :
--   yflqsRLMMhTPpiW0NFHx — « Groupe de test prive », 1 membre (son créateur).
-- La requête de contrôle en fin de fichier vérifie qu'il n'en reste aucun.
--
-- ⚠️ Ce script ne transfère PAS l'appartenance restée dans Firestore : il
-- recrée `group_members` à partir des participants de la conversation, seule
-- source d'appartenance disponible côté Supabase. Un membre du groupe qui
-- n'aurait jamais rejoint la conversation devra rejoindre à nouveau.

begin;

-- 1) Créer la ligne `groups` pour chaque group_id hérité encore référencé.
--    Le nom, la description et le créateur sont repris de la conversation.
with herites as (
  select distinct
         c.group_id                          as ancien_id,
         gen_random_uuid()                   as nouvel_id,
         coalesce(c.data->>'name', 'Groupe') as nom,
         c.created_by                        as createur
    from conversations c
   where c.group_id is not null
     and not exists (select 1 from groups g where g.id::text = c.group_id)
)
insert into groups (id, name, description, category, creator_id,
                    country_code, is_private, member_count,
                    created_at, updated_at)
select h.nouvel_id, h.nom,
       'Groupe migré depuis Firestore le ' || current_date,
       'general', h.createur, null, true, 0, now(), now()
  from herites h;

-- 2) Réaligner les conversations sur le nouvel identifiant.
--    On rapproche par le NOM, seul lien commun entre l'ancien et le nouveau.
update conversations c
   set group_id = g.id::text
  from groups g
 where c.group_id is not null
   and g.description like 'Groupe migré depuis Firestore%'
   and g.name = coalesce(c.data->>'name', 'Groupe')
   and not exists (select 1 from groups g2 where g2.id::text = c.group_id);

-- 3) Recréer l'appartenance à partir des participants de la conversation.
--    Le créateur de la conversation devient admin, les autres membres.
insert into group_members (group_id, user_id, role, joined_at)
select g.id,
       p.participant,
       case when p.participant = c.created_by then 'admin' else 'member' end,
       now()
  from conversations c
  join groups g on g.id::text = c.group_id
 cross join lateral unnest(c.participant_ids) as p(participant)
 where g.description like 'Groupe migré depuis Firestore%'
on conflict do nothing;

-- 4) Recompter les membres.
update groups g
   set member_count = (select count(*) from group_members m where m.group_id = g.id)
 where g.description like 'Groupe migré depuis Firestore%';

commit;

-- CONTRÔLE : doit rendre 0 ligne.
select c.group_id as encore_orphelin
  from conversations c
 where c.group_id is not null
   and not exists (select 1 from groups g where g.id::text = c.group_id);

-- Inventaire des groupes migrés.
select g.id, g.name, g.member_count,
       (select count(*) from conversations c where c.group_id = g.id::text) as conversations
  from groups g
 where g.description like 'Groupe migré depuis Firestore%';
