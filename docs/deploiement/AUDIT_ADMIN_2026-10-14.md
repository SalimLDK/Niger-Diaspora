# Audit du back-office admin — 2026-10-14

Audit complet de la zone « admin » : les 18 écrans et 6 providers de
`lib/features/admin/`, l'écran support admin, les trois routes `/admin/*` de
l'app, et tout ce qui décide des droits côté serveur (policies Supabase, règles
Firestore/RTDB/Storage, Cloud Functions). Lecture seule : aucun fichier de code
modifié, aucun déploiement, aucune commande contre la production.

Ce que je n'ai **pas** pu mesurer est dit explicitement en § 9 — en premier
lieu le schéma réel de Postgres, parce que les migrations du dépôt ne sont pas
ce qui tourne (dérive documentée) et que la lecture de la production m'a été
refusée. Une requête prête à lancer est fournie.

## Résumé

Sept constats structurent tout le reste, par ordre de gravité.

1. **Le back-office n'est pas livrable tel quel.** Son entrée web
   (`lib/features/admin/main.dart`) n'initialise pas Supabase alors que tous
   ses providers lisent `Supabase.instance.client`, et `AdminApp` n'a aucun
   `localizationsDelegates` alors que l'écran de connexion fait
   `AppLocalizations.of(context)!`. Aucune cible d'hébergement, aucune route de
   l'app mobile n'y mène. Les tests passent parce qu'ils montent les écrans
   avec les délégués (§ 1).
2. **Le rôle admin vit dans trois registres sans maître** (Firestore
   `users.adminRole`, Postgres `users.is_admin`/`admin_role`, RTDB
   `/admins`), reliés uniquement par une écriture cliente *best-effort*. Deux
   chemins de promotion divergent : l'écran Utilisateurs n'écrit que
   `is_admin` (sans `admin_role`, sans Firestore), l'écran Rôles écrit les trois
   mais ne trouve que les comptes qui ont encore un document Firestore —
   8 sur 54 au 2026-09-16 (§ 2).
3. **Le panneau regarde une base, l'app écrit dans l'autre.** Les
   signalements des utilisateurs partent dans **Firestore** ; la file de
   modération lit **Supabase**, qui ne reçoit que les signalements d'avis
   d'entreprise. Même écart pour le marketplace et les transferts. Le compteur
   « signalements en attente » du tableau de bord est donc faux par
   construction (§ 3).
4. **La piste d'audit n'a jamais rien enregistré.** Les actions du panneau
   écrivent `admin_audit_logs` côté Supabase — table sous RLS **sans aucune
   policy** (mesuré le 2026-09-20), insertion refusée, erreur avalée. Les
   changements de rôle écrivent `admin_audit_logs` côté Firestore — règle
   `allow write: if false`, erreur avalée. Idem `admin_notifications` : la
   « notification globale » n'a aucun consommateur, nulle part (§ 3, § 4).
5. **Un refus du serveur passe pour un succès** sur 22 des 24 écritures du
   provider : `update`/`delete` sans `.select()`, donc zéro ligne sans erreur,
   et les écrans affichent la snackbar de succès sans lire le booléen rendu.
   Ce n'est pas théorique : côté Postgres, rembourser/compléter/échouer une
   transaction, désactiver/supprimer un produit, supprimer un groupe n'ont
   **aucune policy admin** — zéro ligne à chaque fois, « succès » affiché et
   journalisé (§ 5, § 6).
6. **Quatre rôles côté client, un bit côté serveur.** Le modèle
   contentMod/businessMod/financeMod n'existe que dans `role_permissions.dart`
   et le rail de navigation ; les policies Postgres ne connaissent que
   `is_admin()` — et `users_update_admin` laisse tout admin réécrire toute
   colonne de tout utilisateur —, les callables Firebase acceptent n'importe
   quel rôle, et les règles Firestore laissent tout admin poser
   `isAdmin: true` sur n'importe qui, un drapeau hérité que les quatre helpers
   de règles honorent encore (§ 6, § 7).
7. **Le bannissement n'existe nulle part côté serveur.** Postgres :
   `users_update_own` ne contraint ni `is_banned`, ni `is_verified`, ni
   `session_id` — un banni se débannit d'un `PATCH` sur sa ligne, un compte se
   pose le badge vérifié ; et aucune policy ne lit `is_banned`. Firebase :
   aucune règle ne lit `isBanned`, aucune fonction ne révoque ou désactive un
   compte. Dans les deux bases, c'est le client qui s'éjecte lui-même (§ 6,
   § 7).

Le reste est un tableau de défauts d'écran (§ 8) et un plan de remédiation
ordonné (§ 10). La correction la plus rentable est aussi la plus courte :
choisir **un** registre de rôle (Postgres) et faire poser par une Cloud
Function un *custom claim* que les trois moteurs de règles lisent.

## Périmètre et méthode

- **Client** (lu intégralement) : `admin_provider.dart` (2 599 lignes),
  `permission_provider.dart`, `role_management_provider.dart`,
  `app_settings_provider.dart`, `app_settings_datasource.dart`,
  `permission_guard.dart`, `role_permissions.dart`, `admin_enums.dart`,
  `admin_login_screen.dart`, `admin_dashboard_screen.dart`, `admin_app.dart`,
  `main.dart` ; les autres écrans par leurs appels d'action et leur gestion
  d'erreur ; les datasources des fonctionnalités que le panneau modère
  (signalements, marketplace, transferts, événements, groupes, entreprises,
  support, ambassades) pour savoir quel backend chacune utilise.
- **Serveur** : deux relectures déléguées, l'une sur les 158 migrations
  Supabase (policies, GRANT/REVOKE, RPC `SECURITY DEFINER`, déclencheurs de
  garde), l'autre sur `functions/*.js`, `firestore.rules`,
  `database.rules.json`, `storage.rules`, `firebase.json`. Leurs affirmations
  les plus lourdes ont été revérifiées dans les fichiers avant d'être
  retenues.
- **Colonnes** : un script a extrait les colonnes de chaque table depuis les
  `CREATE TABLE`/`ALTER TABLE` des migrations, pour les comparer à celles que
  le provider écrit. Résultat à lire avec la dérive de schéma en tête (§ 4).
- **Production** : non mesurée (§ 9). Les faits de production cités viennent
  de `docs/deploiement/AUDIT_PRE_PROD_2026-09-20.md` et des mémoires de
  session, avec leur date.

## 1. Le back-office n'est pas livrable tel quel

Le panneau est une seconde application Flutter, avec son propre `main`
(`lib/features/admin/main.dart`), conçue pour le web : `usePathUrlStrategy()`,
App Check en reCAPTCHA v3, puis `runApp(AdminApp())`.

- **Supabase n'est jamais initialisé** par cette entrée
  (`main.dart:10-27` : Firebase et App Check seulement). Or les six notifiers
  du panneau passent tous par `Supabase.instance.client`
  (`admin_provider.dart:30`), et le pont d'authentification aussi
  (`supabase_auth_bridge.dart:61`). Le premier appel lève une erreur
  d'instance non initialisée — dès la connexion, puisque `signInWithEmail`
  passe par le pont pour lire `admin_role`
  (`auth_remote_datasource.dart:673-678`).
- **Aucun délégué de localisation** dans `AdminApp`
  (`admin_app.dart:14-33` : `MaterialApp` sans `localizationsDelegates` ni
  `supportedLocales`). `AppLocalizations.of` est nullable
  (`lib/l10n/app_localizations.dart:70-71`) et l'écran de connexion le
  déréférence (`admin_login_screen.dart:20`) : écran rouge avant même le
  premier champ. **Mesuré le 2026-10-14** par un test widget jetable qui
  monte `ProviderScope(child: AdminApp())` tel quel : première image,
  `Null check operator used on a null value`. Le test
  `admin_login_signout_test.dart:64-71` monte l'écran avec les délégués,
  d'où un vert trompeur.
- **Aucune cible d'hébergement** : `firebase.json` n'a que les deux sites
  marketing (`diaspo-niger`, `diasponiger`), `public: "public"`, et `/admin`
  y est réécrit vers la page marketing. Aucun script, aucun document ne
  construit `-t lib/features/admin/main.dart`.
- **Aucune route de l'app n'ouvre le tableau de bord** :
  `AdminDashboardScreen` n'est importé que par le module admin. Les seules
  surfaces admin atteignables dans l'app mobile sont `/admin/embassies`,
  `/admin/embassies/create` et `/admin/support` (`app_router.dart:791-797,
  1029-1031`), sans garde de routeur — déjà relevé le 20/09, toujours ouvert.
  Rien ne pointe vers elles non plus (ni menu, ni lien profond) ; elles ne
  s'atteignent qu'en tapant l'URL.

Conséquence : tout ce qui suit décrit un outil qui **n'a vraisemblablement
jamais tourné en production**. Deux faits le corroborent : `app_config/settings`
n'avait reçu aucune sauvegarde du back-office entre mai et août 2026 (mémoire
du 2026-08-19), et les deux seules écritures connues depuis ont été faites par
script. La bascule des drapeaux (`mlsMessagesComptes`, `multiAppareilComptes`)
passe elle aussi par des scripts, « aucune interface ne l'expose ».

Ce n'est pas une raison de baisser la garde : le code est compilé dans l'APK
public (les écrans d'ambassades et de support sont dans le routeur), et les
droits côté serveur, eux, sont bien actifs.

## 2. Trois registres de rôle, aucun maître

| Registre | Qui l'écrit | Qui le lit |
|---|---|---|
| Firestore `users/{uid}.adminRole` (et `isAdmin` hérité) | écran Rôles (`role_management_provider.dart:159-163`) | rail et gardes du panneau (`permission_provider.dart:14-50`), toutes les règles Firestore, les deux callables admin |
| Postgres `users.is_admin` + `admin_role` | écran Rôles (`:233-236`), écran Utilisateurs (`admin_provider.dart:1613-1664`) | toutes les policies RLS (`is_admin()`), la connexion au panneau et l'exemption de maintenance (`auth_remote_datasource.dart:766` → `UserEntity.isAdmin`) |
| RTDB `/admins/{uid}` | écran Rôles (`:244-249`) | règles des salons audio (modération fantôme) |

Rien côté serveur ne relie les trois : aucune Cloud Function, aucun
déclencheur, aucune migration (vérifié par le second agent : zéro
`setCustomUserClaims`, zéro `admin_role` dans `functions/`). La « synchro » est
`_syncRoleToBackends` (`role_management_provider.dart:224-259`) : Firestore
d'abord, puis Postgres et RTDB en *best-effort*, chaque échec ajouté à un
message et jamais rejoué (`:223` : « l'écriture Firestore a déjà eu lieu : on
ne la rejoue pas »).

Ce que ça produit concrètement :

- **Deux chemins de promotion qui se contredisent.** L'écran Utilisateurs
  (`promoteToAdmin`, `admin_provider.dart:1613-1637`) écrit **seulement**
  `is_admin: true` — pas d'`admin_role`, pas de Firestore, pas de RTDB. Le
  compte obtient alors tous les droits RLS (`is_admin()`) sans pouvoir se
  connecter au panneau (`UserEntity.isAdmin` lit `adminRole`, nul) ni y
  apparaître dans l'écran Rôles (qui ne lit que Firestore). Et dans la liste
  Utilisateurs du panneau, `_mapUser` (`:40-50`) transmet `isAdmin: true` à
  `UserModel.fromJson`, qui convertit tout `isAdmin` sans `adminRole` en
  **superAdmin** (`user_model.dart:62-64`) : l'écran affiche un Super
  Administrateur qui n'en est pas un. `demoteFromAdmin` (`:1640-1664`) fait
  l'inverse : `is_admin: false` en laissant `admin_role` — le compte perd la
  RLS mais garde la connexion au panneau et l'exemption de maintenance.
- **L'écran Rôles ne trouve que les comptes d'avant la migration.**
  `searchUserByEmail` (`:264-281`) et `assignRole` (`:146-153`, « Utilisateur
  non trouvé » si le document Firestore manque) ne lisent que Firestore. Au
  2026-09-16, 8 comptes sur 54 avaient encore un document `users` Firestore ;
  plus rien n'en crée. Pour les 46 autres, promouvoir est impossible par
  l'écran prévu — et possible par l'écran Utilisateurs, avec le résultat
  ci-dessus.
- **Un admin amorcé en SQL n'a rien côté Firebase.** La procédure
  (`docs/ops/AMORCAGE_ADMIN.md`) demande d'écrire les trois registres à la
  main. Sans document Firestore, `getAdminRole()` échoue sur `.data` d'un
  document absent : toutes les règles admin de `firestore.rules` rendent
  faux, le rail du panneau est vide (`AdminRole.none`,
  `permission_provider.dart:28-31`), les callables répondent
  `permission-denied`.
- **La révocation n'est pas atomique.** Si `ensureAuthenticated()` rend faux
  ou si l'UPDATE Postgres échoue (`:230-236`), le compte perd le panneau mais
  garde `is_admin = true`, donc toutes les policies RLS, y compris l'écriture
  sur toute la table `users`.

## 3. Le panneau regarde une base, l'app écrit dans l'autre

| Section du panneau | Ce que le panneau lit/écrit | Ce que l'app écrit | Effet |
|---|---|---|---|
| Signalements (`admin_provider.dart:1032-1260`) | Supabase `reports` | **Firestore** `reports` (`report_remote_datasource.dart:85-91`, `FirebaseCollections.reports`) | la file ne voit que les signalements d'avis d'entreprise (`avis_signaler`, seul écrivain Supabase). Les signalements d'utilisateurs, messages, groupes, événements, produits, conversations n'arrivent **nulle part** côté admin : les providers Firestore de `report_provider.dart` n'ont aucun consommateur hors du module. Le badge « signalements en attente » (`loadDashboardStats`, `:343-349`) compte Supabase. |
| Marketplace (`:1312-1460`) | Supabase `products`, `orders` | **Firestore** (`marketplace_remote_datasource.dart:46-49`) | tables Supabase vides (mesuré le 2026-09-21 par la migration `orders_ecriture_fermee`) ; section aveugle. Drapeau `marketplace` fermé en prod, donc sans victime aujourd'hui. |
| Transactions (`:1815-1980`) | Supabase `transactions` | **Firestore** (`transfer_remote_datasource.dart:38`) | idem ; « Rembourser » ne touche qu'une table vide, et de toute façon ne déclenche aucun remboursement Stripe (voir § 8). |
| Notification globale (`:2237-2330`) | insère `admin_notifications` | — | **aucun consommateur** : ni déclencheur SQL, ni edge function, ni Cloud Function ne lit cette table (`grep` sur `supabase/`, `functions/`, `lib/` : seules références, le panneau lui-même). « Notification envoyée avec succès » n'envoie rien. |
| Journal d'audit (`:2413-2493`) | Supabase `admin_audit_logs` | changements de rôle → **Firestore** `admin_audit_logs` (`role_management_provider.dart:298-310`) | deux journaux ; l'écran n'en lit qu'un. Et aucun des deux n'accepte l'écriture (§ 4, § 7). |
| Activité d'un utilisateur (`:1721-1740`), journal d'erreurs (`:2571-2596`) | `activity_logs`, `error_logs` | **personne n'écrit** ces tables (aucun `.from('activity_logs')`/`error_logs` hors du panneau, rien dans `functions/` ni `supabase/functions/`) | toujours vides, sans message. |
| Entreprises, événements, groupes, ambassades, support | Supabase | Supabase | **cohérent** — les seules sections qui regardent la bonne base. |

## 4. Ce que les migrations ne définissent pas (et ce que la prod a quand même)

Le script d'extraction donne, pour chaque colonne que le panneau écrit, si une
migration du dépôt la crée. Lecture obligatoire avec la dérive en tête : des
tables et colonnes ont été créées hors dépôt, et des migrations postérieures
les supposent (`orders_ecriture_fermee` pose un `GRANT UPDATE` sur six
colonnes de litige qu'aucune migration ne crée ; `avis_signaler` insère
`reporter_name`, `target_name`, `content_snapshot` dans `reports`, dont le
`CREATE TABLE` n'a que huit colonnes et un `CHECK` sur `target_type` qui
n'admet pas `business_review`).

| Table | Colonnes écrites par le panneau, absentes de toute migration | Si absentes en prod |
|---|---|---|
| `users` | `banned_at`, `verified_at` (`is_banned`, `ban_reason`, `session_id` : citées par des migrations récentes, donc présentes) | `banUser` et `verifyProfile` échouent en PGRST204 — **le bannissement ne s'applique pas** — et l'écran affiche quand même « Utilisateur banni » / « Profil vérifié » (§ 5) |
| `reports` | `admin_note`, `action_taken`, `reviewed_by`, `reviewed_at`, `reported_user_notified`, `reported_user_id` | résoudre ou classer un signalement échoue en PGRST204 |
| `transactions` | `refund_reason`, `refunded_by`, `refunded_at`, `completed_by`, `completed_at`, `failed_by`, `exchange_rate`, `amount_in_xof`, `fee`, `total_charged` | les trois actions échouent ; les montants lus sont nuls |
| `orders` | `has_dispute`, `dispute_resolution`, `dispute_note`, `dispute_resolved_by`, `dispute_resolved_at` | couvertes par le `GRANT` du 21/09 : présentes en prod, à confirmer |
| `events` (lecture) | `attendee_ids`, `poster_urls`, `organizer_name`, `recap_*` | nuls, l'écran s'en accommode |
| `businesses` | `is_boosted`, `boost_expires_at` | citées par trois migrations : présentes en prod |

Et les trois tables propres au panneau — `admin_audit_logs`,
`admin_notifications`, `activity_logs` — n'ont **aucun `CREATE TABLE`** dans
le dépôt. L'audit pré-prod du 2026-09-20 les a trouvées en production, **sous
RLS sans aucune policy** : lecture vide, insertion refusée (42501), sans
erreur visible. Aucune migration depuis ne leur a ajouté de policy. C'est la
preuve que la piste d'audit du panneau n'a jamais rien enregistré, et que
`fetchSentNotifications` a toujours rendu une liste vide.

`error_logs` n'apparaît nulle part : ni migration, ni audit — probablement
absente, auquel cas la section « journal d'erreurs » rend PGRST205, affiché
tel quel.

## 5. Un refus du serveur passe pour un succès

PostgREST ne lève rien quand une policy RLS filtre toutes les lignes d'un
`update` ou d'un `delete` : zéro ligne, pas d'erreur. Le provider le sait pour
deux méthodes — `deleteEvent` (`admin_provider.dart:757-793`) et
`cancelEvent` (`:795-827`) relisent `.select('id')` et rendent faux si vide,
avec un commentaire qui décrit exactement la panne. Les 22 autres ne le font
pas :

`forceLogoutUser` (`:391`), `verifyBusiness` (`:544`), `unverifyBusiness`
(`:574`), `toggleBoost` (`:604`), `deleteBusiness` (`:647`), `deleteGroup`
(`:829`), `toggleGroupPrivacy` (`:853`), `resolveReport` (`:1080`),
`dismissReport` (`:1167`), `deleteReportedContent` (`:1201`),
`toggleProductAvailability` (`:1372`), `deleteProduct` (`:1404`),
`resolveDispute` (`:1428`), `banUser` (`:1544`), `unbanUser` (`:1585`),
`promoteToAdmin` (`:1613`), `demoteFromAdmin` (`:1640`), `verifyProfile`
(`:1667`), `revokeVerification` (`:1694`), `refundTransaction` (`:1880`),
`markAsCompleted` (`:1914`), `markAsFailed` (`:1945`).

Chacune journalise ensuite un succès dans l'audit — qui est lui-même refusé et
avalé (`AdminAuditHelper.log`, `:2478-2493`, `catch` vide).

Les écrans aggravent : ils ignorent le booléen rendu et affichent la
snackbar de succès inconditionnellement — Utilisateurs
(`admin_users_management_screen.dart:503-535`), Entreprises
(`admin_businesses_screen.dart:379-415`), Marketplace
(`admin_marketplace_screen.dart:807-836`), Modération
(`admin_moderation_screen.dart:673-686`), Transactions
(`admin_transactions_screen.dart:613-654`). Seuls Rôles
(`admin_create_admin_screen.dart:671-688`, avec un commentaire qui nomme le
défaut) et Signalements lisent le résultat.

Même famille, côté réglages : `AppSettingsDataSourceImpl.getSettings`
(`app_settings_datasource.dart:35-52`) rend les **valeurs par défaut sur toute
erreur**, refus de permission compris. L'écran Réglages affiche alors des
défauts comme s'ils venaient du serveur, et « Enregistrer » les écrit par
`set(merge)` section par section (`:54-77`) — c'est-à-dire écrase la section
serveur avec les défauts. La règle `app_config` exige `isSuperAdmin()` en
Firestore (`firestore.rules:692-695`), donc un admin sans document Firestore
tombe exactement dans ce cas.

## 6. Côté Supabase : policies, RPC, déclencheurs

Rapport du premier agent (158 migrations relues dans l'ordre, état final),
revérifié sur les points 1 à 4 et 7.

1. **Un banni se débannit lui-même, un compte se vérifie lui-même — élevé.**
   `users_update_own` (final : `20260803200000_fix_users_policy_recursion.sql:44-50`)
   n'a comme `WITH CHECK` que `id`, `is_admin` et `admin_role`. Le déclencheur
   `guard_admin_flags` ne regarde que ces deux drapeaux
   (`20260803150000:82-83`). Rien ne protège `is_banned`, `ban_reason`,
   `banned_at`, `is_verified`, `verified_at`, `session_id`. Un `PATCH
   /rest/v1/users?id=eq.<soi>` avec `{"is_banned":false,"session_id":"…"}`
   passe ; `{"is_verified":true}` aussi — badge vérifié auto-attribué. Et
   `is_banned` n'est lu par **aucune** policy, fonction SQL ou edge function :
   `auth-firebase-exchange` délivre une session sans le regarder
   (`index.ts:176-180`). Le ban n'est appliqué que par le client qui s'éjecte
   lui-même (même constat que § 7.2 côté Firebase).
2. **Tout admin, quel que soit son rôle, réécrit n'importe quelle colonne de
   n'importe quel utilisateur — élevé.** `users_update_admin` :
   `FOR UPDATE USING (is_admin()) WITH CHECK (is_admin())`
   (`20260803120000:35-37`), et `authenticated` garde UPDATE sur toutes les
   colonnes (`20260920213600:64` ne révoque que TRUNCATE/REFERENCES/TRIGGER).
   `is_admin()` est vrai pour les quatre rôles (`20260803150000:53-60`, il ne
   teste que le booléen). Un contentMod compromis réécrit `fcm_tokens`,
   `email`, `phone_number`, `session_id` de qui il veut, ou bannit tout le
   monde. Même chose sur `businesses` : `businesses_garde_privileges` sort dès
   `is_admin()` (`20260921071500:117-119`) — un contentMod pose le boost
   payant gratuitement.
3. **Trois sections du panneau sont cassées côté serveur, en silence — élevé
   (fonctionnel).** `transactions` n'a **aucune policy UPDATE** (initial
   `:158-167`, « via service role » ; `20260803170000:76-82` ne réécrit que
   select/insert ; aucune migration ultérieure), et l'admin ne voit que ses
   propres lignes (`transactions_select_own`). `products` n'a que
   `products_manage_own FOR ALL USING (firebase_uid() = seller_id)`
   (`20260803170000:109-110`). `groups` : suppression réservée au créateur
   (`20260813234500:16-19`, `delete_group` `20260814003000:46-50`), `is_private`
   permis à un admin seulement sur un groupe officiel (`:21-22`). Rembourser,
   compléter, échouer une transaction, désactiver ou supprimer un produit,
   supprimer un groupe, rendre un groupe privé : zéro ligne, « succès »
   affiché, « succès » journalisé (§ 5).
4. **`get_or_create_official_group(text, text)` exécutable par `anon`, sans
   contrôle, avec `DISABLE TRIGGER` — moyen.** Définition finale
   `20260914090000_groupes_de_ville.sql:87-235` : `SECURITY DEFINER`, aucun
   test d'identité, `ALTER TABLE groups DISABLE TRIGGER …` (`:111-112`, verrou
   exclusif sur la table) puis INSERT d'un groupe `is_official = true`. Aucun
   `REVOKE`/`GRANT EXECUTE` sur cette signature dans le dépôt (la variante
   `get_or_create_ville_group(bigint)` en a un, `:239-240`). Une boucle
   anonyme sur tous les pays crée ~190 groupes officiels, chaque appel
   bloquant toutes les lectures de `groups` le temps du DDL.
5. **Diffusion et audit : tables hors dépôt, échecs avalés — moyen.** Voir
   § 4. S'y ajoute : aucun chemin de diffusion n'existe dans le schéma —
   INSERT sur `notifications` est révoqué pour `authenticated`
   (`20260916180000:34-39`), `create_user_notification` refuse le type
   `system` (liste fermée `20260921100000:96-102`) et plafonne à 60/h et
   10 par couple, admin compris (`:151-168`).
6. **Droits de table par défaut jamais retirés sur sept tables du
   périmètre — moyen.** `reports`, `products`, `transactions`, `events`,
   `groups`, `app_config`, `support_tickets` : aucun `REVOKE` ; `anon` et
   `authenticated` y gardent ALL, dont TRUNCATE (ignore le RLS). Pas
   exploitable par PostgREST aujourd'hui, mais la première fonction
   `SECURITY INVOKER` qui tronque ouvre la table.
7. **`is_admin` et `admin_role` divergent par construction — faible, mais
   c'est la racine du § 2.** Serveur : `is_admin()` teste `is_admin` seul,
   `is_super_admin()` les deux, `current_user_admin_role()` `admin_role`
   seul. Client : `adminRole` seul. Trou à l'INSERT : `users_insert_own`
   force `is_admin = FALSE` mais laisse `admin_role` libre
   (`20260803170000:50-51`), et le déclencheur est `BEFORE UPDATE` seulement
   (`20260803150000:110-112`) ; le client a un chemin INSERT
   (`ecriture_ligne_users.dart:43-46`). Résultat possible :
   `admin_role = 'superAdmin'` avec `is_admin = false` — aucun pouvoir
   serveur, mais connexion au panneau et exemption de maintenance.
8. **Deux superAdmins peuvent se rétrograder l'un l'autre en parallèle —
   faible.** `is_super_admin()` lit la ligne de l'appelant sans verrou ;
   aucune garde « dernier superAdmin ». La reprise passe par le SQL Editor.
   Raisonné, pas mesuré.
9. **`firebase_uid()` et `current_user_id()` : `SECURITY DEFINER` sans
   `SET search_path` — faible.** Tous les helpers admin reposent sur la
   première (`20260625195140:7-17`). Déjà relevé le 20/09.
10. **Collisions d'horodatage de migrations : aucune** (158 fichiers).

Tableau « qui peut faire l'écriture que le panneau fait » :

| Table, action | Autorisé pour | Référence |
|---|---|---|
| `users` : ban, badge, `session_id` | tout rôle admin ; **et le compte lui-même sur sa ligne** | `20260803120000:35-37`, `20260803200000:44-50` |
| `users` : `is_admin`, `admin_role` | superAdmin, jamais sur soi | `20260803150000:93-103` |
| `businesses` : badge, boost, suppression | tout rôle admin | `20260803170000:95-100`, `20260921071500:117-119` |
| `events` : suppression, annulation | admin, et 0 ligne détectée | `20260912200000:36-44` |
| `groups` : suppression | **personne** (créateur seul) | `20260813234500:16`, `20260814003000:46-50` |
| `groups` : `is_private` | admin sur groupe officiel seulement | `20260813234500:21-22` |
| `reports` : statut, résolution | admin (si les colonnes existent) | initial `:741-742` |
| `products` : désactivation, suppression | **personne** (vendeur seul) | `20260803170000:109-110` |
| `orders` : six colonnes de litige | admin, par `GRANT` colonne | `20260921034600:58-73` |
| `transactions` : rembourser, compléter, échouer | **personne** (aucune policy UPDATE) | initial `:158-167` |
| `embassies` | **superAdmin seul** (contentMod : 0 ligne) | `20260907190000:189-206` |
| `support_tickets` | admin | initial `:761-764` |
| `admin_audit_logs`, `admin_notifications`, `activity_logs`, `error_logs` | indéterminable depuis le dépôt ; RLS sans policy mesuré le 20/09 pour les trois premières | — |
| `anon`, toutes tables | nulle part | `20260920213600:49` |

Fonctions `SECURITY DEFINER` à nom sensible sans contrôle (141 analysées) :
hors `get_or_create_official_group`, aucune. `profils_admin` lève si
`NOT is_admin()` (`20260921080000:151-154`) ; les purges vivent dans `private`
et sont révoquées ; `exclure_du_groupe` et consorts passent par
`private.conversation_de_groupe_a_gerer`.

## 7. Côté Firebase : règles, fonctions, RTDB, Storage, hébergement

Rapport du second agent, revérifié sur les points 1, 2 et 5.

1. **Escalade par le drapeau hérité `isAdmin` — élevé.** Le bloc admin de
   `users/{userId}` (`firestore.rules:774-782`) ne protège que `adminRole` :
   tout admin, contentMod compris, peut poser `isAdmin: true` sur n'importe
   quel compte, y compris le sien. Or `isAdmin()` (`:54-60`) et les trois
   `canModerate*()` (`:69-95`) retombent chacune sur `userData.isAdmin ==
   true`, et le panneau affiche ce compte en superAdmin
   (`permission_provider.dart:44-46`). Seules les opérations `isSuperAdmin()`
   restent fermées. Postgres a la garde « pas sur sa propre ligne »
   (`20260803150000_harden_admin_role_escalation.sql:83-98`) ; Firestore ne
   l'a pas.
2. **Le bannissement n'existe pas pour Firebase — élevé.** Aucune occurrence
   de `banned` dans les trois fichiers de règles ; aucun `revokeRefreshTokens`
   ni `updateUser({disabled})` dans `functions/`. Le ban est une écriture
   cliente dans Postgres (`is_banned` + sentinelle `session_id`,
   `admin_provider.dart:1551-1566`) que l'app lit pour s'éjecter elle-même.
   Un client modifié, ou un ancien APK, garde un jeton valide et écrit dans
   RTDB `messages/`, `calls/`, `audioRooms/`, dans Storage `messages/`,
   `posts/`, et dans toutes les collections Firestore ouvertes aux
   authentifiés.
3. **Aucune synchronisation serveur des registres — élevé.** Voir § 2.
4. **RTDB `/admins` n'est inscriptible que par `/superAdmins`, que rien
   n'écrit — moyen.** `database.rules.json:174-187` : `superAdmins` est
   `.read/.write: false` ; seul écrivain de `admins/` dans le dépôt, le
   panneau ; écrivain de `superAdmins`, aucun. Soit la clé a été posée à la
   main en console (quatrième registre, hors code), soit chaque assignation
   de rôle finit par « non propagé à : Realtime Database » et la modération
   fantôme des salons n'a jamais fonctionné.
5. **L'audit Firestore des rôles est refusé en silence — moyen.**
   `admin_audit_logs` : `allow write: if false` (`:686-689`), pendant que
   `role_management_provider.dart:298-310` y écrit depuis le client et avale
   l'erreur. Les `assign_role`/`change_role` n'ont donc aucune trace, nulle
   part (le journal Supabase est lui aussi fermé, § 4). Bonus : `cleanupUserData`
   (`functions/index.js:2813`) consigne `wasAdmin: adminRole !== "none"`,
   vrai pour tout document sans `adminRole` — chaque compte supprimé est noté
   « ancien admin ».
6. **Callables admin : n'importe quel rôle, App Check jamais exigé — moyen.**
   `seedLegalContent` (`:3764-3839`, réécrit CGU/confidentialité/code de
   conduite) et `manualCallCleanup` (`:6641-6746`, dont `forceAll` coupe tous
   les appels actifs de tous les comptes) exigent un `adminRole` non vide,
   quel qu'il soit. Zéro `enforceAppCheck`/`context.app` dans `functions/`
   alors que le panneau active App Check : aucune fonction ne le consomme.
   Il n'existe **aucune** fonction serveur pour poser un rôle, créer un admin,
   bannir, forcer une déconnexion, diffuser à tous (aucun `sendToTopic`),
   écrire `app_config`, modérer `reports` : tout est fait par le panneau
   directement contre Firestore ou Supabase.
7. **Deux endpoints HTTP à secret partagé, morts — faible.**
   `seedLegalContentHttp` et `migrateDisplayNameLower` exigent
   `ADMIN_API_KEY` ; elle n'est ni dans `functions/.env` ni dans l'exemple, et
   la doc la dit absente en production. Fermés (401), mais code mort portant
   un secret. `stripeConnectWebhook` (`:3997-4002`) n'applique pas
   `isPlaceholderSecret` comme les deux autres webhooks — toujours fermé,
   mais incohérent.
8. **Storage : aucun chemin admin — info.** Ni risque ni capacité : un
   modérateur ne peut rien supprimer dans Storage depuis le panneau.
9. **Hébergement — info.** Pas de cible admin (§ 1) ; aucun en-tête de
   sécurité (`Content-Security-Policy`, `X-Frame-Options`,
   `Strict-Transport-Security`) sur les deux sites, déjà relevé le 20/09.

Hors périmètre admin, relevé au passage par l'agent et non revérifié ici :
`createLiveKitRoom` (`:4371-4380`) écrase `group_calls/{roomName}` sans
vérifier l'existence (prise de contrôle d'un appel de groupe par son nom), et
`getAudioRoomLiveKitToken` (`:7478-7483`) accepte `canPublish` du client.

## 8. Défauts d'écran

| Où | Quoi | Gravité |
|---|---|---|
| `admin_dashboard_screen.dart:330` | « Déconnexion » fait `pushReplacementNamed('/login')` **sans `signOut`** : la session Firebase reste ouverte, retour arrière ou `/dashboard` dans la barre d'adresse rend le panneau. | élevé (sur un poste partagé) |
| `admin_app.dart:29-33` | `/dashboard` est une route nommée sans garde : atteignable par URL sans connexion ; le rail est vide (`AdminRole.none`) mais `loadDashboardStats` part quand même. | moyen |
| `admin_dashboard_screen.dart:564-600` | Les sept actions rapides posent des index en dur (4, 1, 9, 8, 10, 11, 12) dans la liste **filtrée par rôle** (`:205-218`). Justes pour un superAdmin seulement : un contentMod qui touche « Voir les signalements » ouvre l'audit, « Envoyer une notification » sort de la liste et retombe sur l'aperçu (`:235`). | faible |
| `admin_dashboard_screen.dart:103` | Le badge de l'entrée **Utilisateurs** affiche `pendingReports`. | faible |
| `admin_provider.dart:1201-1260` | `deleteReportedContent` : `message` vise `messages` (un message MLS vit dans `mls_messages`) ; `user`, `post`, `comment`, `conversation`, `audio_room` n'ont pas de table → rien n'est supprimé, la fonction rend **vrai** et notifie l'auteur « Contenu supprimé » (`:1221-1228`). | moyen |
| `admin_provider.dart:1880-1912` | « Rembourser » pose `status = 'refunded'` et rien d'autre : aucun appel Stripe. La seule logique de remboursement du dépôt (`refundCancelledOrder`, `functions/index.js:6941`) est un déclencheur Firestore sur `orders`. Le libellé promet un remboursement qui n'a pas lieu. | moyen |
| `admin_provider.dart:1914-1943` | « Marquer complétée » pose `completed` sans confirmation du prestataire : une transaction jamais payée devient « réussie » côté admin. | moyen |
| `admin_notifications_screen.dart:465` | L'historique lit `notification['targetGroup']` sur des lignes Supabase en `snake_case` (`target_type`) : toujours « Tous ». | faible |
| `role_management_provider.dart:300-311` et `admin_provider.dart:2468` | Deux classes `AdminAuditHelper` du même nom, l'une Firestore, l'autre Supabase ; l'import de la seconde est masqué par la déclaration locale. Piège de relecture. | faible |
| `admin_analytics_screen` via `admin_provider.dart:2054-2070` | `countWhere` empile des `as dynamic` pour contourner le typage du builder ; fonctionne, se cassera en silence à la prochaine montée de `supabase_flutter`. | faible |
| `admin_login_screen.dart` | Pas de second facteur pour les comptes admin ; un mot de passe hameçonné vaut le panneau entier. Firebase Auth sait l'imposer (MFA TOTP/SMS) ; rien ne le fait. | moyen |
| `admin_settings_screen.dart` (taux de change, frais) | Les taux de change utilisés par `transfer_provider.dart` et `currency_provider.dart` sont saisis à la main dans `app_config/settings`. Pas un bug : un fait à connaître avant de rouvrir les transferts. | info |

## 9. Ce que je n'ai pas pu vérifier

- **Le schéma réel de Postgres.** `supabase db query --linked` m'a été refusé
  (lecture de production). La requête est prête et ne fait que lire :

  ```bash
  supabase db query --linked -f docs/deploiement/audit_admin_2026-10-14_verif_prod.sql
  ```

  Elle rend, en un seul JSON : les colonnes réelles des 17 tables que le
  panneau touche, le corps actuel de `is_admin()` et `is_super_admin()`, la
  présence de `profils_admin`, le nombre de comptes par couple
  (`is_admin`, `admin_role`) — donc les incohérences du § 2 —, les
  déclencheurs de `users`, le nombre de lignes de `reports`, et l'état RLS
  (actif / forcé) des tables admin. Elle tranche le § 4 en une lecture.
- **Le contenu de RTDB `/superAdmins` et `/admins`** en production (§ 7.4).
- **Les variables d'environnement effectivement déployées** sur Cloud
  Functions, et l'application d'App Check à Firestore/RTDB/Storage (réglage
  console).
- **Où, et si, le panneau web a déjà été servi.** Rien dans le dépôt ne le
  dit.
- Je n'ai pas lancé le panneau dans un navigateur (`flutter run -d chrome -t
  lib/features/admin/main.dart`) : le plantage de localisation du § 1 est
  mesuré en test widget ; l'absence de `Supabase.initialize` frapperait
  juste derrière, à la première requête.

## 10. Plan de remédiation proposé

Dans l'ordre où chaque étape rend la suivante possible.

1. **Un seul registre de rôle, et un claim.** Garder Postgres
   `users.admin_role` comme source ; une Cloud Function (webhook pg_net sur
   `users`, ou callable superAdmin en Admin SDK) pose
   `setCustomUserClaims(uid, {adminRole})` et écrit RTDB `/admins`. Les
   règles Firestore/RTDB lisent `request.auth.token.adminRole` ; le panneau
   lit `getIdTokenResult().claims`. Supprimer `isAdmin`, le repli hérité des
   quatre helpers, `permission_provider` sur Firestore, et la recherche
   Firestore de l'écran Rôles. Retirer `promoteToAdmin`/`demoteFromAdmin` de
   l'écran Utilisateurs (un seul chemin de promotion).
2. **Le ban côté serveur, dans les deux bases.** Postgres : un déclencheur
   `users_garde_privileges` sur le modèle de `businesses_garde_privileges`
   (`20260921071500:100-161`) qui refuse tout changement de
   `is_banned`/`ban_reason`/`banned_at`/`is_verified`/`verified_at` quand
   `NOT is_admin()`, et une policy restrictive (ou `firebase_uid()` rendant
   NULL) pour un compte banni, plus le refus dans `auth-firebase-exchange`.
   Firebase : la fonction du point 1, sur `is_banned = true`, fait
   `updateUser(uid, {disabled: true})` + `revokeRefreshTokens`. Le client n'a
   plus à s'éjecter lui-même. Au passage : `REVOKE ALL FROM anon` et
   `REVOKE TRUNCATE, REFERENCES, TRIGGER FROM authenticated` sur les sept
   tables du § 6.6, et `REVOKE EXECUTE … FROM anon` sur
   `get_or_create_official_group`.
3. **Un backend par donnée.** Signalements : faire écrire l'app dans Supabase
   `reports` (et élargir le `CHECK` de `target_type`), ou faire lire Firestore
   au panneau — pas les deux. Même décision pour marketplace et transferts
   le jour où leurs drapeaux rouvrent. D'ici là, masquer les trois sections
   plutôt que d'afficher du vide.
4. **Rendre les tables admin écrivables, par migration.** `CREATE TABLE IF
   NOT EXISTS` + policies `is_admin()` pour `admin_audit_logs`,
   `admin_notifications`, `activity_logs` (et décider du sort d'`error_logs`),
   avec `REVOKE` puis `GRANT` explicites. Faire écrire l'audit par un
   déclencheur ou une RPC `SECURITY DEFINER`, pas par le client : un journal
   que l'acteur écrit lui-même n'est pas un journal.
5. **Plus de succès à vide.** Généraliser le motif de `deleteEvent` :
   `.select('id')` sur chaque `update`/`delete`, faux si vide ; les écrans
   lisent le booléen ; `AdminAuditHelper.log` cesse d'avaler. `getSettings`
   propage l'erreur au lieu de rendre des défauts.
6. **Quatre rôles côté serveur, ou un seul partout.** Soit les policies et
   callables distinguent les rôles (fonction `admin_role() IN (...)` par
   table), soit le modèle client est réduit à superAdmin pour ne plus promettre
   une séparation qui n'existe pas.
7. **Le panneau lui-même.** `Supabase.initialize` + délégués dans `AdminApp`,
   garde d'authentification sur `/dashboard`, `signOut` sur « Déconnexion »,
   MFA obligatoire sur les comptes admin, cible d'hébergement dédiée avec
   en-têtes de sécurité, `enforceAppCheck` sur les callables. Garde de
   routeur sur `/admin/*` dans l'app mobile (modèle `/ghost`,
   `app_router.dart:412-421`).
8. **Les libellés qui promettent.** « Rembourser » devient « Marquer
   remboursée » tant qu'aucun appel Stripe n'existe ; « Contenu supprimé »
   n'est notifié que si une ligne a été supprimée.
