-- Recale `groups.member_count` sur le contenu réel de `group_members`.
--
-- POURQUOI
-- Un trigger `group_members_count_trigger` maintient bien ce compteur, mais il
-- n'a jamais rattrapé les lignes antérieures à sa création. Résultat constaté
-- le 2026-08-06 : la fiche d'un groupe affiche « Membres · 0 » tout en listant
-- son créateur, et propose « Rejoindre le groupe » à quelqu'un qui en est déjà
-- membre.
--
-- Sans effet sur les droits — l'appartenance réelle est `group_members`, et
-- c'est elle que lisent les RLS. C'est un défaut d'affichage.
--
-- IDEMPOTENT : relancer ne change rien une fois les compteurs à jour.

begin;

update groups g
   set member_count = coalesce(
         (select count(*) from group_members m where m.group_id = g.id), 0)
 where g.member_count is distinct from coalesce(
         (select count(*) from group_members m where m.group_id = g.id), 0);

commit;

-- CONTRÔLE : doit rendre 0 ligne.
select g.id, g.name, g.member_count,
       (select count(*) from group_members m where m.group_id = g.id) as reel
  from groups g
 where g.member_count is distinct from coalesce(
         (select count(*) from group_members m where m.group_id = g.id), 0);
