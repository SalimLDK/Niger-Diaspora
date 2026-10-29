# Rôles d'administration supplémentaires — préparé, rien n'est appliqué

Quatre rôles de plus : `supportAgent`, `validator`, `auditor`, `analyst`. Préparé le 2026-10-29.
**Ni la migration, ni la fonction, ni aucun rôle attribué n'ont touché la production.**

## Ce qui est prêt

| Quoi | Où | État |
|---|---|---|
| Migration : contraintes `CHECK` (huit rôles), droits de chaque rôle | `supabase/migrations/20261029090000_roles_admin_supplementaires.sql` | écrite, **non appliquée, non répétée** |
| Banc SQL (`BEGIN … ROLLBACK`), 26 cas d'accès/refus + contraintes + comptes | `tools/rls_tests/roles_admin_supplementaires.sql` | écrit, **non lancé** |
| `setAdminRole` accepte les huit rôles ; claim séparé pour les quatre nouveaux | `functions/roles_admin.js`, `functions/index.js` | banc Node : 46/46 |
| Colonnes des nouveaux rôles dans la matrice | console `backoffice/src/pages/Roles.tsx` | typecheck et build propres |

## Droits accordés

| Rôle | Droits (clés du catalogue) |
|---|---|
| `supportAgent` | `dashboard.view`, `support.tickets.view` / `reply` / `assign` / `escalate` / `close` |
| `validator` | `dashboard.view`, `consular.view`, `consular.procedures.approve` / `edit`, `consular.embassies.verify`, `directory.listings.view` / `approve`, `events.approve` (ne publie pas, n'approuve pas de campagne) |
| `auditor` | `dashboard.view`, `security.audit.view` / `export` |
| `analyst` | `dashboard.view`, `dashboard.analytics.view`, `events.analytics.view` |

## Deux décisions de conception, et pourquoi

1. **Le claim d'un rôle limité n'est pas `adminRole`.** `functions/index.js` utilise
   `ROLES_ADMIN.includes(token.adminRole)` comme porte d'autorisation (deux fonctions), les règles
   Firestore énumèrent les quatre rôles, et la règle RTDB `auth.token.adminRole != null` ouvre des
   droits à n'importe quelle valeur. Ajouter un rôle à `ROLES_ADMIN` ou le poser dans `adminRole` lui
   donnerait tout cela. Il est donc posé dans `adminRoleLimite`, que ni les portes ni les règles ne lisent,
   et il n'entre pas dans RTDB `/admins`. Son seul pouvoir est `admin_has_permission` en base.
2. **`is_admin()` n'est pas modifiée.** Une soixantaine de RPC l'appellent avant
   `admin_require_permission` : la durcir couperait les nouveaux rôles de leurs propres fonctions.

## Le risque que le dépôt ne peut pas mesurer

Un rôle d'administration pose `users.is_admin = true`, et `is_admin()` ne lit que ce drapeau. Toute
policy `… OR is_admin()` sans `admin_has_permission(…)` ouvre ses droits à un auditeur comme à un
super-administrateur. Le dépôt compte 186 occurrences de `is_admin()` ; ce qui reste vivant, seule la base
le sait. **L'auditeur et l'analyste ne sont « en lecture seule » que si aucune policy d'écriture héritée
ne subsiste.** La mesure (lecture seule du catalogue, aucune donnée) est en tête de la migration :

```sql
SELECT schemaname||'.'||tablename AS objet, cmd, policyname
  FROM pg_policies
 WHERE (coalesce(qual,'')||coalesce(with_check,'')) ~ 'is_admin\(\)'
   AND (coalesce(qual,'')||coalesce(with_check,'')) !~ 'admin_has_permission'
 ORDER BY 1, 2, 3;
```

À faire de la même façon pour les fonctions `SECURITY DEFINER` qui testent `is_admin()` seul. Je n'ai pas
pu lancer cette requête : la session m'a refusé l'accès à la base liée.

## Ordre de mise en service

1. Lancer la requête de mesure ci-dessus ; fermer ou assumer chaque ligne d'écriture restante.
2. Répéter : `python tools/rls_tests/repeter_cible.py tools/rls_tests/roles_admin_supplementaires.sql supabase/migrations/20261029090000_roles_admin_supplementaires.sql /tmp/repetition.sql`,
   puis `supabase db query --linked -f /tmp/repetition.sql` — attendu : **0 ÉCHEC**.
3. Vérifier les doublons de préfixe : `ls supabase/migrations | awk -F_ '{print $1}' | sort | uniq -d` (sortie vide).
4. Appliquer la migration seule : `supabase db query --linked -f <fichier>` puis
   `supabase migration repair --status applied 20261029090000 --linked` (jamais `db push` s'il y en a d'autres en attente).
5. Relancer le banc tel quel (état vivant) : 0 ÉCHEC.
6. Déployer `setAdminRole` (`firebase deploy --only functions:setAdminRole`, après `cd functions && npm install && npm test`).
7. Attribuer un rôle à **un** compte de test, vérifier ses refus dans la console, avant tout autre.

## Ce qui ne change pas

- Le panneau Flutter lit un rôle inconnu comme `AdminRole.none` (`fromString`) : un compte à rôle limité n'y voit
  rien. Il travaille dans la console web.
- Règles Firestore et RTDB : inchangées, aucun déploiement de règles.
