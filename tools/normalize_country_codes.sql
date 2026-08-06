-- Normalise `country_code` vers l'ISO-2, sur `users` et `groups`.
--
-- POURQUOI
-- Les deux colonnes s'appellent `country_code` mais contenaient un mélange de
-- codes et de libellés : `CA` à côté de `Canada`, `NE` à côté de `Niger`.
-- Toutes les comparaisons d'égalité échouaient donc en silence — en
-- particulier le filtre par pays de la liste des groupes
-- (`g.country == _selectedCountry`) et `availableGroupCountriesProvider`, qui
-- dérive de cette colonne. Un commentaire de `groups_screen` signalait déjà
-- que le repli sur `'NE'` ne se déclenchait jamais avec `'Niger'`.
--
-- Les deux sources d'écriture ont été corrigées en même temps que ce script :
--   * `profile_supabase_datasource` écrivait `currentCountry`, qui vient du
--     géocodage inverse sous forme de libellé ;
--   * `create_group_screen` écrivait un libellé de sa liste `_hostCountries`.
-- Sans ces correctifs, la base se re-salirait à la première écriture.
--
-- PÉRIMÈTRE MESURÉ AVANT EXÉCUTION
--   users  : 'Niger'  ×1
--   groups : 'Niger'  ×2, 'Canada' ×1
-- La correspondance ci-dessous couvre les libellés de `Country.label` et leurs
-- variantes accentuées ; tout ce qui n'y figure pas est laissé INTACT plutôt
-- que d'être deviné.
--
-- IDEMPOTENT : un code déjà ISO ne correspond à aucune entrée et reste en place.

begin;

create temp table pays_iso (libelle text primary key, code text not null) on commit drop;

insert into pays_iso (libelle, code) values
  ('niger','NE'), ('benin','BJ'), ('burkina faso','BF'), ('mali','ML'),
  ('nigeria','NG'), ('senegal','SN'), ('sénégal','SN'),
  ('cote d''ivoire','CI'), ('côte d''ivoire','CI'),
  ('togo','TG'), ('ghana','GH'), ('cameroun','CM'), ('cameroon','CM'),
  ('algerie','DZ'), ('algérie','DZ'), ('libye','LY'), ('libya','LY'),
  ('maroc','MA'), ('morocco','MA'), ('tunisie','TN'), ('tunisia','TN'),
  ('france','FR'), ('belgique','BE'), ('allemagne','DE'), ('italie','IT'),
  ('espagne','ES'), ('royaume-uni','GB'), ('royaume uni','GB'),
  ('suisse','CH'), ('pays-bas','NL'), ('pays bas','NL'),
  ('etats-unis','US'), ('états-unis','US'), ('etats unis','US'),
  ('canada','CA'), ('arabie saoudite','SA'),
  ('emirats arabes unis','AE'), ('émirats arabes unis','AE'), ('qatar','QA');

-- 0) Lever les doublons de groupe officiel que la normalisation ferait
--    apparaître.
--
--    `uniq_official_group_per_country` est un index UNIQUE PARTIEL sur
--    `country_code` WHERE `is_official`. Tant que le même pays s'écrivait de
--    deux façons, il ne voyait pas les doublons : « Diaspora Niger — Canada »
--    (`Canada`, créé le 16/07) et « Diaspora Niger — CA » (`CA`, créé le
--    20/07) coexistaient. C'est le même enchaînement que le défaut des
--    conversations de groupe — `ensureOfficialGroup` a cherché par `CA`, n'a
--    pas trouvé le groupe rangé sous `Canada`, et en a créé un second.
--
--    On DÉCLASSE le doublon le plus récent et vide au lieu de le supprimer :
--    l'index étant partiel, `is_official = false` suffit à lever le conflit,
--    et rien n'est détruit. Ne sont déclassés que les groupes officiels
--    strictement vides — aucun membre, aucune conversation — dont un homologue
--    officiel plus ancien couvre le même pays une fois normalisé.
with normalise as (
  select g.id,
         coalesce(p.code, g.country_code) as code_iso,
         g.created_at,
         (select count(*) from group_members m where m.group_id = g.id)
           + (select count(*) from conversations c where c.group_id = g.id::text)
           as activite
    from groups g
    left join pays_iso p on lower(trim(g.country_code)) = p.libelle
   where g.is_official and g.country_code is not null
),
doublons as (
  select n.id
    from normalise n
   where n.activite = 0
     and exists (
       select 1 from normalise n2
        where n2.code_iso = n.code_iso
          and n2.id <> n.id
          and (n2.activite > 0 or n2.created_at < n.created_at)
     )
)
update groups set is_official = false where id in (select id from doublons);

-- 1) users
update users u
   set country_code = p.code
  from pays_iso p
 where u.country_code is not null
   and lower(trim(u.country_code)) = p.libelle
   and u.country_code <> p.code;

-- 2) groups
update groups g
   set country_code = p.code
  from pays_iso p
 where g.country_code is not null
   and lower(trim(g.country_code)) = p.libelle
   and g.country_code <> p.code;

-- 3) Une chaîne vide n'est pas un pays : la ramener à NULL, sinon elle
--    alimente `availableGroupCountries` et produit une puce de filtre muette.
update users  set country_code = null where country_code = '';
update groups set country_code = null where country_code = '';

commit;

-- CONTRÔLE : doit rendre 0 ligne — plus aucune valeur de plus de 2 caractères.
select 'users' as source, country_code, count(*) as n
  from users  where country_code is not null and length(country_code) > 2
 group by country_code
union all
select 'groups', country_code, count(*)
  from groups where country_code is not null and length(country_code) > 2
 group by country_code;

-- Inventaire final.
select 'users' as source, country_code, count(*) as n from users  group by country_code
union all
select 'groups', country_code, count(*) from groups group by country_code
 order by 1, 2;
