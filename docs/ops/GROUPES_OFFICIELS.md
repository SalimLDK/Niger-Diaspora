# Groupes officiels : convention de création

`groups.is_official = true` n'est qu'un **badge d'affichage** — trié en tête
dans `groups_screen.dart:273`, pastille dans `groups_map_screen.dart`. Rien
dans l'app ne le pose : marquer un groupe officiel est, aujourd'hui comme
demain, une action manuelle en SQL. Ce document fixe la règle à suivre
**avant** de créer le prochain, pour ne pas reproduire l'incident du
2026-08-13 (voir plus bas).

## Ce qui s'est passé une première fois

Le seul groupe officiel existant (« Diaspora Niger — Canada »,
`03077217-24d5-4cfa-9ec6-ed5b593c3cd2`) avait été créé avec `creator_id`
pointant vers le compte **personnel** de Sim A, et `creator_name` forcé en
façade à « Diaspo Niger ». Deux conséquences, découvertes en corrigeant un
signalement utilisateur :

- l'app affichait le vrai nom/profession du compte perso partout où elle lit
  le profil derrière `creator_id` (liste des membres), en contradiction avec
  le texte « Créé par Diaspo Niger » affiché ailleurs sur la même fiche ;
- `group_members` pour ce groupe n'avait **aucune** ligne `role IN ('owner',
  'admin')` — les policies RLS de modification (`groups_update_admin`,
  `is_group_admin()`) ne regardent que `group_members.role`, jamais
  `creator_id`. Le bouton « Modifier » s'affichait pour Sim A côté app (via le
  raccourci client `isCreator`) mais l'écriture aurait été refusée en
  silence par RLS — ce groupe n'avait donc **aucun administrateur
  fonctionnel**, malgré ce que l'UI laissait croire.

Correctif appliqué le 2026-08-13 : compte plateforme distinct créé
(`czk5UoUclLOFmbRtUIZ5XYLYKo52`, email `support@diasponiger.com`), réassigné
comme `creator_id`, avec une ligne `group_members` `role='owner'` — et
*seulement* lui, par décision explicite de Salim : aucun compte personnel ne
conserve de droit de gestion implicite sur ce groupe. Vérifié sur SM A515F,
connecté sous un compte tiers (Sim A) : « Membres · 3 », ligne créateur sans
tap possible, cohérente partout sur la fiche.

## Le bug était structurel, pas seulement historique

Ce groupe n'a pas été créé à la main : `get_or_create_official_group()`
(RPC appelée automatiquement par `ProfileNotifier._joinOfficialCountryGroup`
dès qu'un profil renseigne un `countryCode` sans groupe officiel existant)
tentait bien de poser `creator_id = 'system_official'`, mais
`enforce_group_creator_trigger` (BEFORE INSERT sur `groups`) écrase
**toujours** `creator_id` par l'identité de l'appelant, quoi que l'INSERT
tente de poser — c'est ce qui a produit ce groupe avec le compte perso du
premier utilisateur ayant renseigné le Canada.

Pire : depuis le 2026-08-06, `groups_guard_official` (voir plus bas) refuse
l'INSERT entier pour tout appelant qui n'est pas admin plateforme. Comme la
RPC tourne dans la session de l'utilisateur normal qui vient de renseigner
son pays, **plus aucun groupe officiel ne pouvait être créé pour un nouveau
pays depuis cette date** — en échec silencieux, l'erreur 42501 étant avalée
par `_joinOfficialCountryGroup` (`(failure) async {}`, best-effort assumé).

**Corrigé** (migration
`20260813233000_fix_official_group_creator_and_admin.sql`) : la RPC
désactive les deux triggers concernés le temps du seul INSERT qui doit porter
le compte plateforme plutôt que l'appelant — même technique que la migration
des groupes hérités du 2026-08-06 (transactionnel, `ALTER TABLE ...
DISABLE/ENABLE TRIGGER` dans le même bloc, un échec annule tout par
ROLLBACK) — puis pose la ligne `group_members role='owner'` manquante.
Testé en rejouant l'appel sous une identité non-admin réelle, dans une
transaction annulée par `ROLLBACK` (`SET LOCAL request.jwt.claims`) : plus
d'exception, `creator_id` correctement posé sur le compte plateforme,
`member_count` correct. Le chemin « pays déjà couvert » (retour anticipé,
aucun INSERT) reste inchangé et vérifié intact.

## Règle pour tout nouveau groupe officiel

1. **`creator_id` doit être le compte plateforme**, jamais un compte
   personnel avec un `creator_name` de façade. `creator_id` est lu comme une
   vraie identité à deux endroits qui comptent : la policy RLS
   `groups_delete` (`firebase_uid() = creator_id`, seul chemin de
   suppression) et l'affichage de la ligne « Créateur » côté membres.
2. **Les droits réels ne viennent jamais de `creator_id`.** Poser
   explicitement une ligne `group_members` avec `role IN ('owner','admin')`
   pour quiconque doit pouvoir modifier le groupe ou modérer ses membres —
   `is_group_admin()` (`pg_proc`) ne lit que cette table. Sans ligne
   `owner`/`admin`, le groupe est administrable par **personne**, même son
   créateur nominal.
3. Si un compte personnel doit avoir la main au quotidien sans se
   reconnecter comme le compte plateforme, c'est une **décision par
   groupe**, à prendre et documenter explicitement (ligne `group_members`
   dédiée) — jamais un effet de bord de la création.

Un nouveau pays n'a donc plus besoin d'étapes manuelles : la RPC
`get_or_create_official_group` provisionne désormais correctement, avec le
bon `creator_id` et le bon `group_members`. Les étapes SQL ci-dessous ne
servent plus qu'à un groupe officiel **hors de ce mécanisme** (pas rattaché
à un pays) ou à un futur compte plateforme distinct.

## Étapes concrètes (compte plateforme déjà amorcé, hors flux pays)

```sql
-- 1. Marquer le groupe officiel et lui donner sa vraie identité de créateur
UPDATE groups
SET is_official = true,
    creator_id = '<firebase_uid_compte_plateforme>',
    creator_name = 'Diaspo Niger'
WHERE id = '<group_id>';

-- 2. Donner au compte plateforme les droits réels (RLS les exige séparément)
INSERT INTO group_members (group_id, user_id, role)
VALUES ('<group_id>', '<firebase_uid_compte_plateforme>', 'owner')
ON CONFLICT (group_id, user_id) DO UPDATE SET role = 'owner';
```

Vérifier après coup, en session applicative du compte plateforme :

```sql
SELECT is_group_admin('<group_id>');  -- doit rendre TRUE
```

## Amorcer un compte plateforme

Un seul existe aujourd'hui, `czk5UoUclLOFmbRtUIZ5XYLYKo52` (« Diaspo Niger »,
email `support@diasponiger.com`), déjà `owner` du groupe officiel actuel.
Pour un futur compte distinct (par pays, par organisation partenaire…) :

1. Créer le compte Firebase Auth (Console → Authentication → Add user) —
   **hors de portée d'un agent** : action de création de compte, à faire à la
   main, comme pour l'amorçage superAdmin ([AMORCAGE_ADMIN.md](AMORCAGE_ADMIN.md)).
2. Se connecter une fois dans l'app avec ce compte : déclenche le pont
   Firebase→Supabase standard (`auth_mappings`, ligne `users`) sans script
   dédié — c'est le même chemin que n'importe quelle inscription.
3. Ajuster son profil (`display_name`, `is_verified`, avatar) et suivre les
   étapes SQL ci-dessus pour chaque groupe qu'il doit posséder.
