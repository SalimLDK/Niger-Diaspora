# Amorçage des droits admin

Les droits admin vivent dans **trois backends** qui ne se parlent pas :

| Backend | Emplacement | Sert à |
|---|---|---|
| Firestore | `users/{uid}.adminRole` | source de vérité de l'app, pilote l'UI du back-office |
| Postgres (Supabase) | `users.is_admin` / `users.admin_role` | pilote `is_admin()`, donc toutes les policies RLS admin |
| Realtime Database | `/admins/{uid}` | pilote les règles des salons audio (modération fantôme) |

`role_management_provider.dart` écrit les trois quand un superAdmin assigne un
rôle. Mais **le tout premier superAdmin ne peut pas se créer lui-même** : les
deux backends de droits exigent d'être déjà superAdmin pour être modifiés.
Cet amorçage est donc manuel, et volontairement hors de portée de l'app.

## Pourquoi c'est verrouillé ainsi

L'application a 4 rôles (`superAdmin`, `contentMod`, `businessMod`,
`financeMod`) mais les deux backends de droits ne connaissaient qu'un booléen
« admin ou non ». Un `contentMod` pouvait donc se promouvoir superAdmin en
appelant directement l'API — la clé anon Supabase est publique, embarquée dans
l'app, et la hiérarchie n'était appliquée que côté client.

Deux verrous ont été posés :

- **Postgres** : le trigger `users_guard_admin_flags`
  (`20260803150000_harden_admin_role_escalation.sql`) n'autorise la
  modification de `is_admin` / `admin_role` qu'à un superAdmin, et jamais sur
  sa propre ligne. Sans session applicative (SQL Editor, `service_role`), le
  trigger laisse passer : c'est le chemin d'amorçage.
- **RTDB** : `/admins` n'est écrivable que par un membre de `/superAdmins`, et
  `/superAdmins` est en `.read: false` / `.write: false` — donc inaccessible
  depuis n'importe quel client, quel que soit son rôle. Seuls la console
  Firebase et l'Admin SDK passent outre les règles.

## Amorcer le premier superAdmin

Il faut le **Firebase UID** du compte (c'est aussi la clé primaire de
`public.users` côté Postgres — voir `auth-firebase-exchange/index.ts`).

### 1. Firestore

Console Firebase → Firestore → `users/{uid}` → champ `adminRole` = `superAdmin`.

### 2. Postgres

Supabase → SQL Editor (le trigger ne s'applique pas ici, `firebase_uid()` y est
`NULL`) :

```sql
UPDATE users
SET is_admin = TRUE, admin_role = 'superAdmin'
WHERE id = '<firebase_uid>';
```

### 3. Realtime Database

Console Firebase → Realtime Database → créer :

```
/superAdmins/<firebase_uid> = true
/admins/<firebase_uid>      = true
```

`/superAdmins` donne le droit de gérer les autres admins ; `/admins` donne les
droits de modération dans les salons. Les deux sont nécessaires pour un
superAdmin opérationnel.

## Ensuite

Une fois ce compte amorcé, tout se fait depuis l'écran de gestion des rôles du
back-office : il écrit les trois backends et signale toute désynchronisation.

Pour révoquer un superAdmin, refaire les trois étapes en sens inverse depuis un
**autre** compte superAdmin — un compte ne peut pas modifier ses propres droits.

## Vérifier

```sql
-- doit renvoyer TRUE pour le compte amorcé, en session applicative
SELECT is_admin(), is_super_admin();

-- doit échouer avec 42501 même pour un superAdmin
UPDATE users SET admin_role = 'superAdmin' WHERE id = (SELECT firebase_uid());
```

Côté RTDB, un compte `contentMod` qui tente d'écrire `/admins/<n'importe qui>`
doit recevoir `PERMISSION_DENIED`.
