# Amorçage des droits admin

Le rôle admin a **une source** et deux dérivés, et un seul chemin d'écriture
côté serveur.

| Registre | Rôle | Qui l'écrit | Qui le lit |
|---|---|---|---|
| Postgres `users.admin_role` (+ `users.is_admin`, toujours ensemble) | **source** | la callable `setAdminRole` ; le script d'amorçage | `is_admin()`, `is_super_admin()`, donc toutes les policies RLS ; la connexion au panneau |
| Custom claim Firebase `{ adminRole }` | dérivé | idem | les règles Firestore et RTDB (`request.auth.token.adminRole`) ; le panneau (`getIdTokenResult().claims`) |
| RTDB `/admins/{uid}` | dérivé | idem | plus personne après la bascule des règles ; conservé pour les builds antérieurs |

**Firestore `users/{uid}.adminRole` n'est plus un registre.** Plus rien ne
l'écrit ni ne le lit : ni les règles, ni le panneau, ni les callables. Un
document Firestore absent n'enlève plus aucun droit, et un champ `isAdmin`
posé à la main n'en donne aucun — c'est l'escalade que fermait l'audit du
2026-10-14 (`docs/deploiement/AUDIT_ADMIN_2026-10-14.md`, § 2 et § 7.1).

## Comment un rôle s'écrit

Depuis l'écran Rôles du back-office, qui appelle la Cloud Function
`setAdminRole` (`functions/index.js`, logique dans `functions/roles_admin.js`).
Elle :

1. vérifie que l'appelant est superAdmin **dans Postgres** (les deux colonnes,
   comme `is_super_admin()`) — pas d'après son claim ;
2. refuse sa propre ligne, et tout changement qui laisserait zéro superAdmin ;
3. écrit Postgres (`is_admin` ET `admin_role`), pose le claim, écrit RTDB ;
   si le claim échoue, Postgres est remis à sa valeur d'avant ;
4. journalise dans `admin_audit_logs` par la clé de service — le client ne
   peut pas y écrire, et n'a jamais pu.

Banc : `cd functions && npm test`.

Le claim n'entre dans le jeton du compte visé qu'à son prochain
rafraîchissement (≤ 1 h, ou immédiat à l'ouverture du panneau, qui force
`getIdToken(true)`). Postgres est relu à chaque requête : les policies RLS
voient le nouveau rôle tout de suite.

## Amorcer le premier superAdmin

La callable exige un appelant déjà superAdmin : le premier ne peut pas passer
par elle. Le script écrit les **mêmes trois registres** avec les **mêmes
aides** (`functions/supabase.js`), par l'Admin SDK et la clé de service.

Prérequis, depuis la racine du dépôt :

- `functions/.env` avec `SUPABASE_URL` et `SUPABASE_SERVICE_KEY` ;
- la clé de service Firebase (`<projet>-firebase-adminsdk-<hash>.json`) dans
  `functions/` — ignorée par git — ou `GOOGLE_APPLICATION_CREDENTIALS` ;
- `cd functions && npm install` (le script charge `firebase-admin` de là) ;
- le compte s'est connecté **au moins une fois** à l'app : sa ligne
  `public.users` existe (créée par `auth-firebase-exchange`). Le script refuse
  sinon, et ne crée pas de profil.

```bash
node tools/amorcer_super_admin.mjs --email <email>
```

Sans `--confirmer`, le script **lit seulement** : il affiche les trois
registres et dit si leur contenu est cohérent. Relire, puis :

```bash
node tools/amorcer_super_admin.mjs --email <email> --confirmer
```

Il affiche l'état après écriture. La ligne `Cohérence des trois registres :
OUI` est ce qu'on attend.

Options : `--uid <uid>` à la place de `--email` ; `--role contentMod` (ou
`businessMod`, `financeMod`) pour un autre rôle ; `--retirer` pour tout
révoquer — refusé sur le dernier superAdmin.

## Ensuite

Tout passe par l'écran Rôles. Il cherche le compte **dans Postgres** par
e-mail (plus dans Firestore : 8 documents Firestore pour 303 lignes Postgres
au 2026-10-14), appelle `setAdminRole`, et affiche le refus du serveur quand
il y en a un.

Pour révoquer un superAdmin : depuis un **autre** compte superAdmin, ou par
le script avec `--retirer`. Un compte ne peut jamais modifier ses propres
droits — ni par l'écran, ni par la callable, ni par le déclencheur Postgres
`users_guard_admin_flags`, qui reste en place en défense en profondeur.

## Secours

Le script est idempotent : le relancer avec le rôle courant repose les deux
dérivés sans rien changer à la source. C'est le geste à faire si :

- un compte a `is_admin = true` sans `admin_role` (l'admin fantôme du 14/10)
  — poser le vrai rôle, ou `--retirer` ;
- un claim a disparu (compte recréé, claims effacés) ;
- RTDB `/admins` est vide pour un admin.

Pour lire sans écrire, la commande sans `--confirmer` suffit.

## Vérifier

Côté Postgres, en session applicative du compte amorcé :

```sql
SELECT is_admin(), is_super_admin();   -- TRUE, TRUE
-- doit échouer en 42501, superAdmin compris :
UPDATE users SET admin_role = 'superAdmin' WHERE id = (SELECT firebase_uid());
```

Côté Firebase, le script sans `--confirmer` affiche le claim lu par l'Admin
SDK. Les bancs de règles (`tools/rules_tests/`, émulateurs) vérifient que
`auth.token.adminRole` est bien ce que les règles lisent, et qu'un document
Firestore `isAdmin: true` ne donne plus rien.

## Ordre de déploiement

Les règles lisent le claim : déployées **avant** que le claim existe, elles
retireraient tous les droits Firebase à l'admin en place.

1. `firebase deploy --only functions:setAdminRole` ;
2. `node tools/amorcer_super_admin.mjs --email <admin actuel> --confirmer`
   pour chaque superAdmin existant (le script dit lesquels sont incohérents) ;
3. règles Firestore et RTDB, **après** leurs bancs (CLAUDE.md) ;
4. le client (panneau et app).
