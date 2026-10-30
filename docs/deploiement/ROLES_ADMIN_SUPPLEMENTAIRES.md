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

## Résultat de la mesure (production, 2026-10-29) et réponse préparée

La requête a rendu 16 policies et 6 fonctions qui ne demandent que `is_admin()`. Classées :

| Objet | Type | Gravité pour les rôles limités |
|---|---|---|
| `demarches_rubriques`, `demarches_catalogue_meta` (ALL) | écriture | **Élevée** : contourne relecture et publication des démarches |
| `groups_update_admin` (UPDATE) | écriture | **Élevée** : modification des groupes officiels |
| `profils_admin`, `profils_admin_page` | fonction | **Élevée** : lignes complètes de `users` (e-mail, téléphone, position) |
| `users_select`, `reports_select_own` | lecture | **Élevée** : profils privés, identité des déclarants |
| `business_reviews_retrait` (DELETE) | écriture | Moyenne |
| `conversations_guard_admin_fields`, `guard_group_official` | fonction | Moyenne |
| `reports_update_admin` | écriture | Faible (réduite à `reported_user_notified` si 20261023090000 est appliquée) |
| `activity_logs`, `error_logs`, `admin_notifications` (SELECT) | lecture | Faible à moyenne |
| `write_admin_audit` | fonction | Moyenne, **non traitée** : le panneau Flutter l'appelle directement |
| `users_update_own`, tables de configuration | — | Sans objet (auto-garde, lecture de configuration) |

**Réponse : `supabase/migrations/20261029100000_roles_limites_heritage_is_admin.sql`**, non appliquée.
Les 10 policies et 4 fonctions visées passent de `is_admin()` à `is_admin() AND NOT is_limited_admin()` :
les rôles limités en sortent, les quatre rôles historiques gardent exactement leurs droits. Les définitions sont
relues dans la base puis réécrites (pas retapées), et la migration échoue si un remplacement n'a rien changé.
Banc : `tools/rls_tests/roles_limites_heritage.sql` (non lancé).

### Décisions qui restent à vous

1. **Resserrer aussi les rôles historiques ?** La migration ne le fait pas. Remplacer `is_admin()` par une permission
   nommée retirerait, par exemple, la lecture des signalements au gestionnaire commercial et au gestionnaire financier.
2. **`write_admin_audit`** : tout administrateur peut y écrire une ligne, y compris l'auditeur. La fermer demande que
   le panneau Flutter cesse de l'appeler directement.
3. **Les compteurs de la page Statistiques pour l'analyste** : avec ces fermetures, ses lectures directes de `users`
   et `reports` ne voient que les lignes publiques, et un compteur affiche une valeur faible sans erreur. Il faut une
   fonction serveur `admin_stats()` réservée à `dashboard.analytics.view` avant de lui donner cette page.
4. **Écritures sur les tables de démarches** : le panneau Flutter ne fait que les lire ; les policies d'écriture
   pourraient être supprimées pour tout le monde. Plus sûr, mais c'est une décision séparée.

## Durcissement complet — préparé le 2026-10-29, NON appliqué

Suite des trois décisions (resserrer les rôles historiques, fermer `write_admin_audit`, statistiques de l'analyste).
Quatre migrations, **à appliquer une par une, dans cet ordre, chacune après sa répétition** :

| # | Migration | Effet | Condition |
|---|---|---|---|
| 1 | `20261029110000_admin_stats.sql` | `admin_stats()` : agrégats pour `dashboard.analytics.view` (pays de 3 membres au moins) | aucune ; la console l'appelle déjà |
| 2 | `20261029120000_audit_enveloppe_panneau.sql` | `admin_audit_client()` : enveloppe qui refuse les rôles limités | aucune |
| — | **Déployer le panneau Flutter** (`admin_provider.dart` appelle maintenant `admin_audit_client`) | | avant la 3 |
| 3 | `20261029130000_audit_ecriture_serveur_seulement.sql` | `REVOKE` d'`write_admin_audit` aux rôles de connexion | **panneau déployé** ; sinon l'audit du panneau s'arrête |
| 4 | `20261029140000_resserrer_roles_historiques.sql` | un droit nommé remplace `is_admin()` dans 10 policies et 4 fonctions | après `20261029100000` |

**Changement net pour les rôles en place (migration 4)** : `businessMod` et `financeMod` ne lisent plus les signalements,
les profils privés ni `profils_admin` ; seul `contentMod` les lit. `superAdmin` garde tout le catalogue. Une policy qui
s'applique à `anon` ou `public` est laissée en l'état (`admin_has_permission` n'est pas exécutable par anon) : le
NOTICE de la migration la nomme.

Banc : `tools/rls_tests/roles_durcissement_complet.sql` (non lancé). Les bancs existants
`admin_catalogue_permissions_et_audit.sql`, `admin_audit_ecriture_par_rpc_cible.sql` et `journal_audit_export.sql`
appellent `write_admin_audit` en direct : leurs cas d'écriture échoueront une fois la migration 3 appliquée,
c'est le changement voulu, à actualiser alors.

Tests de panneau Flutter : `flutter analyze` n'a pas été relancé sur le changement de `admin_provider.dart` (une
chaîne remplacée) ; à faire dans ce worktree après `flutter pub get`.

## Ordre de mise en service

1. ~~Lancer la requête de mesure~~ : faite le 2026-10-29, voir ci-dessus. Relire les quatre décisions.
2. Répéter chaque banc avec ses migrations, dans l'ordre : `roles_admin_supplementaires.sql` avec `20261029090000`, puis
   `roles_limites_heritage.sql` avec `20261029090000` **et** `20261029100000` (concaténées en un fichier, car
   `repeter_cible.py` n'en prend qu'une). Lancer par `supabase db query --linked -f <fichier>` — attendu : **0 ÉCHEC** chacun.
3. Vérifier les doublons de préfixe : `ls supabase/migrations | awk -F_ '{print $1}' | sort | uniq -d` (sortie vide).
4. Appliquer les migrations UNE PAR UNE, dans l'ordre : `supabase db query --linked -f <fichier>` puis
   `supabase migration repair --status applied <version> --linked` (jamais `db push` s'il y en a d'autres en attente).
5. Relancer le banc tel quel (état vivant) : 0 ÉCHEC.
6. Déployer `setAdminRole` (`firebase deploy --only functions:setAdminRole`, après `cd functions && npm install && npm test`).
7. Attribuer un rôle à **un** compte de test, vérifier ses refus dans la console, avant tout autre.

## Ce qui ne change pas

- Le panneau Flutter lit un rôle inconnu comme `AdminRole.none` (`fromString`) : un compte à rôle limité n'y voit
  rien. Il travaille dans la console web.
- Règles Firestore et RTDB : inchangées, aucun déploiement de règles.
