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
-- TRAÇABILITÉ
-- L'ancien identifiant est conservé dans la description, sous la forme
-- `[migré de <ancien_id>]`. C'est ce marqueur — et non le nom du groupe — qui
-- sert à réaligner les conversations : deux groupes homonymes casseraient un
-- rapprochement par nom. Il documente aussi l'origine après coup.
--
-- ⚠️ Ce script ne transfère PAS l'appartenance restée dans Firestore : il
-- recrée `group_members` à partir des participants de la conversation, seule
-- source d'appartenance disponible côté Supabase. Un membre du groupe qui
-- n'aurait jamais rejoint la conversation devra rejoindre à nouveau.
--
-- IDEMPOTENT : relancer le script ne recrée rien (le `not exists` sur
-- `groups` ne voit plus les group_id déjà réalignés).

begin;

-- 0) Neutraliser le garde-fou de création, le temps de la transaction.
--
--    `enforce_group_creator_trigger` force `creator_id` depuis le JWT vérifié
--    et REFUSE l'insertion s'il n'y a ni claim `firebase_uid` ni entrée dans
--    `auth_mappings`. C'est une protection réelle — elle empêche de créer un
--    groupe au nom d'autrui — mais une migration passe par un rôle admin, sans
--    JWT utilisateur : sans ça, l'insert échoue avec P0001.
--
--    Le `ALTER TABLE` est transactionnel dans PostgreSQL : si quoi que ce soit
--    échoue plus bas, le ROLLBACK réactive le trigger. Il n'y a donc aucune
--    fenêtre où la base resterait sans son garde-fou.
--
--    `group_members_count_trigger` (sur group_members) est laissé ACTIF : il
--    tient `member_count` à jour tout seul.
alter table groups disable trigger enforce_group_creator_trigger;

-- 1) Une ligne `groups` par group_id hérité encore référencé.
--    Le GROUP BY est indispensable AVANT `gen_random_uuid()` : avec un
--    `select distinct`, l'uuid étant calculé par ligne, un groupe portant
--    deux conversations aurait reçu deux identifiants différents.
with herites as (
  select c.group_id                                  as ancien_id,
         min(coalesce(c.data->>'name', 'Groupe'))    as nom,
         min(c.created_by)                           as createur
    from conversations c
   where c.group_id is not null
     and not exists (select 1 from groups g where g.id::text = c.group_id)
   group by c.group_id
)
insert into groups (id, name, description, category, creator_id,
                    country_code, is_private, member_count,
                    created_at, updated_at)
select gen_random_uuid(), h.nom,
       '[migré de ' || h.ancien_id || '] Groupe transféré depuis Firestore le '
         || current_date,
       'general', h.createur, null, true, 0, now(), now()
  from herites h;

-- 2) Réaligner les conversations, en s'appuyant sur le marqueur d'origine.
update conversations c
   set group_id = g.id::text
  from groups g
 where c.group_id is not null
   and g.description like '[migré de ' || c.group_id || ']%';

-- 3) Recréer l'appartenance depuis les participants de la conversation.
--    Le créateur de la conversation devient admin, les autres membres.
insert into group_members (group_id, user_id, role, joined_at)
select g.id,
       p.participant,
       case when p.participant = c.created_by then 'admin' else 'member' end,
       now()
  from conversations c
  join groups g on g.id::text = c.group_id
 cross join lateral unnest(c.participant_ids) as p(participant)
 where g.description like '[migré de %'
on conflict do nothing;

-- 4) Recompter les membres des groupes migrés (filet : le trigger
--    `group_members_count_trigger` l'a normalement déjà fait).
update groups g
   set member_count = (select count(*) from group_members m where m.group_id = g.id)
 where g.description like '[migré de %';

-- 4bis) Effacer le marqueur : il a fini son office.
--    La description est AFFICHÉE À L'UTILISATEUR, sous le nom du groupe dans
--    la liste — un « [migré de yflqsRLMMhTPpiW0NFHx] » y apparaissait en clair
--    (constaté sur appareil). Le marqueur ne sert qu'au rapprochement de
--    l'étape 2 ; la traçabilité vit dans ce script et dans l'historique git.
--    On laisse une description vide plutôt qu'un texte inventé : Firestore
--    n'expose pas la sienne à ce script.
update groups
   set description = ''
 where description like '[migré de %';

-- 5) Remettre le garde-fou.
alter table groups enable trigger enforce_group_creator_trigger;

commit;

-- CONTRÔLE 0 : le garde-fou doit être réactivé — `tgenabled` = 'O'.
select tgname, tgenabled
  from pg_trigger
 where tgname = 'enforce_group_creator_trigger';

-- CONTRÔLE 1 : doit rendre 0 ligne (plus aucune conversation orpheline).
select c.id as conversation, c.group_id as group_id_orphelin
  from conversations c
 where c.group_id is not null
   and not exists (select 1 from groups g where g.id::text = c.group_id);

-- CONTRÔLE 2 : inventaire des groupes migrés.
--    Le marqueur ayant été effacé à l'étape 4bis, on retrouve les groupes par
--    leur date de création (l'insert date de cette exécution).
select g.id, g.name, g.member_count,
       (select count(*) from conversations c where c.group_id = g.id::text) as conversations,
       (select count(*) from messages m
         join conversations c2 on c2.id = m.conversation_id
        where c2.group_id = g.id::text) as messages
  from groups g
 where g.created_at > now() - interval '5 minutes'
 order by g.created_at desc;
