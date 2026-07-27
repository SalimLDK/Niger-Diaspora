# Diaspo Niger — Audit pré-prod & remédiation

**Date :** 2026-07-27
**Branche :** `wip-jules-2025-12-29T23-58-34-776Z`
**Périmètre :** revue de mise en production (go/no-go) + correction des bugs
remontés + validation sur appareil physique (Samsung A51, Android 13).

> ⚠️ Document de session durable. Il fait foi si le contexte de conversation est
> compacté ou si le travail reprend plus tard. Les autres traces durables sont
> les **commits git** (messages détaillés) et la **grille d'audit HTML**
> (`~/Downloads/audit-preprod-diaspo-niger.html`).

---

## 1. Verdict

**Verdict initial : NO-GO.** Un seul bloquant *confirmé par le code* (clé
service_role embarquée dans le bundle), plus une série de bugs fonctionnels
majeurs découverts en cours de route (appels, notifications, messages).

**Après remédiation :** tous les correctifs de code sont écrits, commités et —
pour la plupart — validés sur appareil. Il reste **3 actions d'infra à la charge
de l'équipe** (voir §7) avant le go-live, plus les tests device restants (appel
+ coupure réseau, iOS).

---

## 2. Tableau de synthèse

| # | Problème | Cause racine | Correctif | Fichier(s) | Commit | État |
|---|----------|--------------|-----------|------------|--------|------|
| 1 | Clé service_role extractible de l'app | `.env` (avec `SUPABASE_SERVICE_ROLE_KEY`) embarqué comme asset Flutter | Retrait de la clé ; migration vers nouvelles clés (publishable + secret) ; legacy désactivées | `.env`, `functions/*` | 9c76969 + suivants | ✅ code / ⏳ rotation faite par l'utilisateur |
| 2 | « Profil supprimé » dans Mes publications / Posts sauvegardés | `/profile/:userId` déclaré **avant** les routes statiques → `my-posts` capturé comme un userId | Réordonner : routes statiques avant la route paramétrée | `lib/core/router/app_router.dart` | 9c76969 | ✅ validé device |
| 3 | Messages affichés en chiffré | Le stream d'updates écrase le contenu déchiffré par la ligne brute ; re-déchiffrer est impossible (ratchet Signal) | Préserver le contenu déjà déchiffré, n'appliquer que les métadonnées | `lib/features/messages/presentation/providers/message_provider.dart` | 9c76969 | ✅ affichage clair validé |
| 4 | Notifications (like/commentaire/ami/…) muettes | RLS `notifications_own` (`firebase_uid() = user_id`) bloque l'INSERT cross-utilisateur | RPC `SECURITY DEFINER create_user_notification` (contourne RLS, valide l'appelant, estampille l'acteur) | `supabase/migrations/20260717120000_*.sql`, `notification_service.dart` | 9c76969 | ✅ code / ⏳ `db push` |
| 5 | Pipeline push mort | `private.push_webhook_config` vide + `verify_jwt` actif sur `send-push` + secrets absents | Config posée + `verify_jwt=false` dans `config.toml` + secrets | `supabase/config.toml`, secrets Supabase | c3eabae | ✅ **validé bout-en-bout device** |
| 6 | Appels « dans le vide » (app fermée) | Cloud Functions lisent les tokens FCM dans **Firestore**, alors qu'ils sont dans **Supabase** | `getFcmTokens/removeFcmTokens` via REST Supabase ; `onCallCreated/Updated` + `onMessageCreated` migrés | `functions/supabase.js`, `functions/index.js` | 1bb0cca | ✅ code / ⏳ `firebase deploy` |
| 7 | Triple UI d'appel entrant (« plusieurs couches ») | Garde de dédup placé **après** `await initialize()` → invocations concurrentes le franchissent toutes | Déplacer le check+set de dédup **avant tout `await`** (atomique) | `lib/core/services/native_call_service.dart` | f5304f9 | ✅ code / ⏳ re-test device |
| 8 | ATT iOS manquant (AdMob/IDFA) | Pas de `NSUserTrackingUsageDescription` | Ajout de la clé | `ios/Runner/Info.plist` | 9c76969 | ✅ (prompt ATT à câbler) |
| 9 | RLS ré-évaluées par ligne | `firebase_uid()` appelé nu dans les policies | Envelopper en `(SELECT firebase_uid())` sur messages/posts | `supabase/migrations/20260715120000_*.sql` | 9c76969 | ✅ code / ⏳ `db push` |
| 10 | `users` absente du realtime | Table pas dans la publication | `ALTER PUBLICATION … ADD TABLE users` + REPLICA IDENTITY FULL | `supabase/migrations/20260716120000_*.sql` | 9c76969 | ✅ code / ⏳ `db push` |
| 11 | Migration initiale non rejouable | `CREATE TABLE`/`INDEX` sans `IF NOT EXISTS`, policies sans `DROP` | Idempotence | `supabase/migrations/20260522223150_*.sql` | 9c76969 | ✅ |
| 12 | Fuite potentielle clé admin Firebase | `*-firebase-adminsdk-*.json` non couvert par `.gitignore` | Motifs ajoutés | `.gitignore` | c3eabae | ✅ |
| 13 | Rollback / RGPD non documentés | — | Doc créée | `docs/ROLLBACK_AND_DATA.md` | 9c76969 | ✅ doc (export RGPD à implémenter) |

---

## 3. Détails techniques (les insights qui comptent)

### 3.1 Sécurité — clé service_role & migration des clés
- Le `.env` était déclaré dans `pubspec.yaml` (`assets: - .env`) et chargé par
  `dotenv`. Il contenait `SUPABASE_SERVICE_ROLE_KEY` → **extractible de l'APK/IPA**,
  contournant toutes les RLS sur une base **partagée** avec d'autres projets.
- L'app n'a jamais été publiée → pas de fuite publique réelle, mais correctif
  permanent quand même.
- Migration effectuée vers le **nouveau système de clés Supabase** :
  - App → **publishable key** (`sb_publishable_…`) dans `.env`.
  - 13 Edge Functions → **secret key** (`sb_secret_…`) via le secret non réservé
    `SERVICE_ROLE_KEY` (car `SUPABASE_SERVICE_ROLE_KEY` est auto-injecté/réservé).
  - **Clés legacy désactivées** par l'utilisateur dans le dashboard.

### 3.2 Bug routing « Profil supprimé »
GoRouter matche les routes **dans l'ordre de déclaration**. `/profile/:userId`
était avant `/profile/my-posts` → `my-posts` interprété comme `userId="my-posts"`
→ `ProfileViewScreen` charge un profil inexistant → écran « Ce compte n'existe
plus ». **Règle :** toujours déclarer les sous-routes statiques avant la route
paramétrée. Complété côté serveur par la migration Jules `posts_author_fk_cascade`
(purge des posts orphelins).

### 3.3 Messages en chiffré — ratchet Signal
`getMessageUpdatesStream` fournit la ligne **brute** (chiffrée au repos). Le
handler d'update remplaçait tout le message par cette version → contenu chiffré à
l'écran dès qu'une réaction / un accusé de lecture arrivait. **On ne peut pas
re-déchiffrer** : le Double Ratchet de Signal consomme la clé du message au 1er
déchiffrement. Correctif : conserver le `content`/`fileUrl` déjà déchiffrés,
n'appliquer que les métadonnées mutables.

### 3.4 Notifications — RLS cross-utilisateur
`notifications_own` = `FOR ALL USING (firebase_uid() = user_id)`. Sans `WITH
CHECK` distinct, la condition s'applique aussi à l'INSERT. Quand A notifie B,
A insère `user_id=B` → `firebase_uid()=A ≠ B` → **42501 avalé en silence**. Donc
**toutes** les notifs entre utilisateurs échouaient. Correctif : RPC
`SECURITY DEFINER` qui contourne la RLS, exige l'authentification, vérifie que le
destinataire existe, et estampille `data.actor_id` (anti-usurpation).
*Durcissement idéal (non fait) :* créer ces notifs via des triggers DB sur
`post_likes`/`post_comments`/`friend_requests`.

### 3.5 Pipeline push (Supabase → FCM)
Chaîne : `INSERT notifications` → trigger `notify_push_on_notification` (pg_net)
→ Edge Function `send-push` → FCM HTTP v1. Trois causes d'échec réparées :
1. `private.push_webhook_config` était **vide** → trigger no-op.
2. Secrets manquants (`PUSH_WEBHOOK_SECRET`, `FCM_SERVICE_ACCOUNT`, `SERVICE_ROLE_KEY`).
3. **Piège :** `send-push` déployée avec `verify_jwt` par défaut, alors que le
   trigger n'envoie **aucun JWT** (auth par `x-webhook-secret`) → 401 avant
   exécution. Corrigé durablement via `[functions.send-push] verify_jwt=false`
   dans `supabase/config.toml` (survit aux futurs `functions deploy`, contrairement
   au flag `--no-verify-jwt`).

### 3.6 Appels dans le vide — mauvais datastore de tokens
`onCallCreated`/`onCallUpdated`/`onMessageCreated` lisaient les tokens FCM (et le
profil, et la conversation) dans **Firestore**, alors que tout a migré vers
**Supabase**. Tokens toujours vides → aucun push → l'appelé ne sonne pas quand
l'app est fermée. (En premier plan, l'appel sonnait via le stream, d'où
l'impression « ça marche parfois ».) Correctif : helper `functions/supabase.js`
(REST PostgREST, `fetch` natif Node 22, dégrade proprement si non configuré) +
réécriture des lectures.

### 3.7 Triple UI d'appel — trou de concurrence
Preuve device : « Showing incoming call UI » loggé **3× par appel**, dédup **0×**.
Le garde `if (_activeCallId == callId) return;` était **après** `await
initialize()`. En init lazy, 3 invocations concurrentes (stream + push, même tick)
franchissent toutes le garde avant que `_activeCallId` soit posé. Correctif :
check+set **avant tout `await`** → atomique. NB : la couche plein-écran +
bannière heads-up d'un **même** appel CallKit est normale ; c'est la
**multiplicité** qui était le bug.

---

## 4. Validé sur appareil (Samsung A51 / Android 13)

- ✅ Session Supabase établie (0× erreur 401) après migration des clés + redéploiement des fonctions.
- ✅ Push notification, **app en arrière-plan** (message test Firebase Console) — reçu, actionnable.
- ✅ Push notification, **app tuée** (`am kill`) — reçu + process réveillé par FCM.
- ✅ **Pipeline complet** `INSERT notifications` (type `like`) → push « Pipeline OK » reçu (app arrière-plan).
- ✅ Profil & « Mes publications » & « Posts sauvegardés » — plus de « Profil supprimé ».
- ✅ Message affiché **en clair** dans la conversation.
- ✅ Token FCM obtenu → App Check ne bloque pas l'enregistrement FCM.
- ⏳ **Non encore re-testé** : triple UI d'appel après le fix #7 ; appel + coupure réseau ; tout iOS.

---

## 5. Incident de concurrence git (IMPORTANT)

**Jules (agent automatisé) réécrit activement la même branche** `wip-jules-…` en
parallèle. Conséquences observées **dans cette seule session** :
- Mon correctif `native_call_service` (dédup) a été **silencieusement écrasé** par
  une opération git de Jules → ré-appliqué et commité (`f5304f9`).
- En commitant un `functions/index.js` **périmé**, j'ai **supprimé par accident**
  une fonction de Jules (`onCommentMention`) → repéré, **reverté** (`3539121`),
  `onCommentMention` restauré, `onMessageCreated` intact.

**Recommandation forte :** ne pas faire tourner Jules sur cette branche pendant
le travail manuel, **ou** isoler chacun sur sa propre branche. Sinon, perte de
travail garantie dans les deux sens.

---

## 6. Liste des commits (cette session)

| Hash | Message |
|------|---------|
| `9c76969` | fix(preprod): sécurité clés Supabase, routing profil, RLS perf & robustesse |
| `c3eabae` | fix(push): débloque le pipeline de notifications + colmate une fuite de clé admin |
| `1bb0cca` | fix(calls): push d'appel lit les tokens FCM dans Supabase (fin des appels dans le vide) |
| `ff0b2f8` | docs(functions): documente SUPABASE_URL + SUPABASE_SERVICE_KEY (pushes) |
| `f5304f9` | fix(calls): dédup UI appel entrant AVANT l'await d'init (fin du triple affichage) |
| `2ea365b` | *(erreur — supprimait onCommentMention)* |
| `3539121` | Revert de `2ea365b` (restaure onCommentMention) |

> Aucun de ces commits n'a été **poussé** (pas de `git push`).

---

## 7. Reste à faire (checklist go-live)

### Infra (à la charge de l'équipe)
- [ ] **`supabase db push`** — appliquer les 3 migrations au distant. La RPC
      `20260717120000_create_user_notification_rpc` a été créée **après** le
      dernier push → à confirmer. (Base **partagée en prod** : backup avant.)
- [ ] **`SUPABASE_SERVICE_KEY`** (clé `sb_secret_…`) dans `functions/.env`, puis
      **`firebase deploy --only functions`** — sinon push appel/message muets.
- [ ] Vérifier que les secrets `send-push` sont bien posés
      (`FCM_SERVICE_ACCOUNT`, `PUSH_WEBHOOK_SECRET`, `SERVICE_ROLE_KEY`).

### Produit / code (chantiers restants)
- [ ] **Export RGPD** des données personnelles (n'existe pas ; plan dans
      `docs/ROLLBACK_AND_DATA.md`).
- [ ] **Prompt ATT iOS** : la clé Info.plist est là, mais l'app ne demande pas
      encore l'autorisation (ou passer AdMob en non-personnalisé).
- [ ] **Suppression de compte** : compléter le nettoyage des résidus Firebase.

### Tests device (irremplaçables)
- [ ] Re-tester le **triple affichage d'appel** (fix #7 ré-appliqué).
- [ ] **Appel + coupure réseau** : reconnexion ou fin propre, jamais de crash.
- [ ] **iOS** : push APNs release, appels, ATT — rien n'a été testé sur iOS.
- [ ] **2G/3G** et réseau instable (cible diaspora/Sahel).

### Formalités stores
- [ ] Play Store : formulaire Data Safety + justifier permissions sensibles.
- [ ] App Store : Privacy nutrition labels.

---

## 8. Points de vigilance / gotchas pour la suite

- **Deux systèmes temps réel pour les messages** coexistent (Firebase RTDB +
  Supabase Realtime) sans synchro documentée — clarifier qui fait autorité.
- Beaucoup d'**anciens triggers Firestore** (`sendNotificationOnCreate`,
  triggers sur `orders`/`events`/`transfers`/`business_reviews`…) sont
  probablement **morts** (collections migrées vers Supabase). Ne pas les
  « réparer » à l'aveugle : ils feraient doublon avec la création côté app.
- La CLI `supabase` n'est pas toujours dans le PATH du shell utilisé — d'où
  l'impossibilité ponctuelle de reconfirmer l'état distant des migrations.

---

## 9. Historique des demandes (chronologique)

Toutes les requêtes formulées pendant la session, dans l'ordre :

1. **Audit de mise en production** : rôle d'auditeur technique, verdict go/no-go
   item par item, grille en 10 sections (isolation Supabase partagée, RLS,
   Firebase/migrations, temps réel, sécurité mobile, build iOS, build Android,
   réseau dégradé, i18n, observabilité/RGPD). Priorité : isolation base partagée,
   RLS, BuildContext async.
2. Utiliser le fichier `audit-preprod-diaspo-niger.html` (grille interactive) et
   le remplir avec les statuts + preuves.
3. **« Corrige la clé service_role dans le .env »** + traiter les 5 points nets :
   double source de vérité messages, ATT iOS, wrap `firebase_uid()`, rollback +
   export RGPD, idempotence de la migration initiale.
4. Expliquer la partie sur la rotation de la clé service_role (« je n'ai pas
   compris »).
5. « Que dois-je faire ? » → checklist d'actions.
6. Capture d'écran du dashboard Supabase : « je ne vois pas de *générer une
   nouvelle* » → explication du nouveau système de clés.
7. **« Option B, les clés legacy sont désactivées »** → migrer les Edge Functions
   vers la nouvelle secret key.
8. Erreur `Env name cannot start with SUPABASE_` → diagnostic (variable réservée
   auto-injectée).
9. **« Considère que l'app n'a jamais été publiée »** → simplification de la
   stratégie de rotation.
10. Fourniture de la clé `sb_publishable_…` → mise à jour du `.env`.
11. **« Lance l'émulateur »** → puis choix « 2 » = lancer sur le téléphone
    physique (Samsung A51).
12. **« Dans mes publications on montre profil supprimé »** → corriger : erreur ≠
    suppression, et `users` en realtime.
13. **« Oui, fais le test d'appel + coupure réseau »** + signalement de 3 bugs :
    « plusieurs couches » / texte « callkit » brut, appels qui tombent dans le
    vide / impossibles, **messages affichés en crypté**.
14. **« Prépare le commit de tous ces correctifs »**, puis continuer les tests
    device (push notifications).
15. **« Enchaîne sur le pipeline complet (SQL) »** + **« gère aussi les
    notifications in-app et off-app »**.
16. **« Les notifications aussi ne marchent pas bien »**.
17. **« Oui »** → Option A : donner un accès Supabase aux Cloud Functions
    (lecture des tokens).
18. **« Oui, fais aussi `onMessageCreated` »** (push de message off-app).
19. Confirmation de l'approche Option A (config infra `SUPABASE_URL` + clé posée
    par l'utilisateur).
20. **« Oui »** → rebuild pour valider le fix messages-cryptés sur device.
21. **« Fais une capture d'écran »** (a capté l'appel entrant en direct).
22. **« On enchaîne sur l'analyse du double affichage »** — NB : le bandeau
    compact CallKit s'affiche **lui aussi en double**.
23. **« Fais-le »** → rebuild avec le fix de dédup d'appel.
24. **« Vérifie si toutes les modifications de cette session sont appliquées »**.
25. **« As-tu accès à toutes les infos et problèmes de cette session ? »**
26. **« Peux-tu produire un document entier de ces infos de façon claire ? »**
    → ce document.
27. **« Continue et ajoute toutes les requêtes que je t'ai demandées »** → cette
    section.

> Note : plusieurs demandes d'explication (« je n'ai pas compris », « que
> dois-je faire ») ont porté sur la **rotation des clés Supabase** et le passage
> legacy → nouveau système de clés (publishable / secret).
