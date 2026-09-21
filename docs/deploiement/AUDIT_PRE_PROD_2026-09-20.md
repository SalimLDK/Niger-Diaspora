# Audit avant mise en production — 2026-09-20

Base analysée : tip de `wip-jules-…` (`e8df59b`), dans le worktree
`.claude/worktrees/analyse-prod`. Le dépôt principal avait 72 commits de
retard ce jour-là : ne pas auditer depuis lui.

**Méthode.** Six audits statiques en parallèle (secrets, build Android/iOS,
Supabase, Firebase, code Dart, documents de suivi), puis contre-vérification
des constats les plus lourds **contre la production** : catalogue Postgres en
`BEGIN TRANSACTION READ ONLY`, rôle `anon` simulé (décomptes seulement, aucune
donnée personnelle lue), règles Firestore/Storage déployées lues par l'API
`firebaserules`, liste des Edge Functions déployées. Aucun exploit n'a été
exécuté, aucune écriture faite.

Marques : **[PROD]** vérifié sur la production · **[LU]** lu dans le code du
dépôt · **[À VÉRIFIER]** dépend d'une console ou d'un appareil.

---

## 0. Ce qui est sain

- `flutter analyze` : 1 remarque (import inutile, `test/banc/mls_banc_test.dart:23`).
- `flutter test` (hors bancs réseau) : **1 910 passés, 0 échec, 0 ignoré**.
- Migrations : 144 locales = 144 au registre distant, aucune collision d'horodatage. **[PROD]**
- RLS activé sur les 104 tables de `public`. **[PROD]**
- `firestore.rules` et `storage.rules` du dépôt = production, hors commentaires. **[PROD]**
- Aucun secret suivi par git ni dans l'historique ; le `.env` embarqué dans l'APK ne contient que des valeurs publiques.
- Android : signature sans repli sur la clé debug, R8 actif, `targetSdk 36` épinglé, `.so` alignées 16 Ko, `assetlinks.json` correct, pas de trafic en clair, `AD_ID` / `USE_FULL_SCREEN_INTENT` / `ACCESS_BACKGROUND_LOCATION` retirées.
- `DEPLOYMENT.md` désigne le **bon** keystore (`android/app/diaspo-niger-release.jks`, empreinte confirmée en Console le 09/09).
- Code : aucune route de debug, aucune donnée factice, aucun compte de test en dur ; `ErrorWidget.builder` neutre ; App Check en Play Integrity / App Attest ; divulgation de localisation avant chaque demande système ; L10n fr/en à 5 072 clés, 0 manquante.
- Webhooks `stripeWebhook` / `revenueCatWebhook` et `send-push` échouent fermés ; escalade `is_admin` fermée côté Supabase ; file d'envoi hors ligne bien vidée (`renvoiMessagesEnAttenteProvider`, observé depuis `lib/app.dart:223`).
- Les 17 Edge Functions du dépôt sont déployées, `gif-proxy` comprise (16/09).

---

## 1. Expositions vivantes en production — à fermer sans attendre la release

Ces points ne dépendent d'aucun build : ils sont exploitables aujourd'hui avec
la clé publique que porte chaque APK.

### 1.1 `users` lisible sans compte — e-mails, téléphones, positions GPS **[PROD]**

`users_select` s'applique au rôle `public` avec `NOT is_private` (faux par
défaut) et `anon` garde `SELECT` sur la table. Mesuré en simulant `anon` :
**123 lignes visibles, 85 e-mails, 55 téléphones, 61 positions GPS.**
C'est aussi le fond du motif des cinq refus Play.

**✅ Moitié `anon` FERMÉE le 2026-09-20** — migration `20260920213600`
appliquée (commits `66232fb`, `abd2d0d`). Banc `tools/rls_tests/users_ferme_a_anon.sql`
à 13/13 sur l'état vivant ; une vraie requête HTTP avec la clé publique rend
désormais `401 / 42501`. Non vu sur appareil : le démarrage à froid sur réseau
lent (entrée P0 du suivi).

**⬜ Moitié « compte connecté » OUVERTE.** Tout compte lit encore, chez tout
profil non privé : `email`, `phone_number`, `latitude`, `longitude`,
`fcm_tokens`, `voip_token`, `session_id`, `cart_data`, `ban_reason` — et
`phone_visibility` existe sans que le serveur l'applique. Créer un compte est
gratuit. Un `GRANT SELECT (colonnes)` ne peut **pas** être posé aujourd'hui :
l'app fait dix `select()` sans liste et un `.stream()` sur `users`
(`profile_supabase_datasource.dart:121,141,164,183,233,260,289`,
`auth_remote_datasource.dart:736`, `admin_provider.dart:372,1512`), et sous
droits par colonnes PostgREST refuse la requête **entière** — tous les builds
installés perdraient profil, carte et recherche. Ordre imposé :

1. version cliente qui nomme ses colonnes partout, lit ses propres champs
   privés par une RPC `SECURITY DEFINER` (`mon_profil_prive()`), et la position
   des autres par une RPC qui applique `share_location` et arrondit ;
2. verrou de version minimale **opérant** (aujourd'hui inerte, voir §3) ;
3. seulement alors, `REVOKE SELECT` + `GRANT SELECT (colonnes publiques)`.

**⬜ Toujours OUVERTE au 2026-09-21 — mais ses préalables serveur sont posés.**
Remesurée ce jour : 127 profils, 89 e-mails, 65 positions, 64 jeux de jetons
push, 35 identifiants de session. Et plus précis que ci-dessus : **6 personnes
ayant coupé `share_location` restent localisables**, et 1 téléphone réglé sur
`private` reste lisible. Un filtre `WHERE email = …` suffit à deviner une
adresse sans la lire.

- **Pas 2 (le verrou) : fait.** `VERSION_MINIMALE_APP` manquait à la liste
  blanche d'`app-config` — le verrou lisait une clé jamais servie. Déployée
  (v5), réponse identique octet pour octet, démarrage avant connexion intact.
  Reste à poser le secret, le moment venu.
- **Pas 1, moitié serveur : faite.** Migration `20260921080000` appliquée :
  `mon_profil_prive()`, `positions_partagees()` (le consentement appliqué par
  le serveur), `profils_admin()`. Banc 13 échecs sans, 0 avec.
- **Pas 3 : écrit, répété, NON appliqué** — `supabase/users-colonnes-privees-cible.sql`.
  Répété en production par son banc : les 6 formes du trou fermées, rien
  d'autre ne casse.

Trois rectificatifs à ce paragraphe, mesurés :

- **16 sites, pas 11.** Il manquait le `RETURNING *` de l'upsert de
  `updateProfile`, deux lectures NOMMÉES de `fcm_tokens` sur sa propre ligne
  (l'enregistrement du jeton push — les laisser casser couperait toutes les
  notifications d'un nouvel appareil), celle de `session_id`, et deux
  abonnements temps réel.
- **Le temps réel respecte les droits par colonne**, mesuré en exécutant
  `realtime.apply_rls` elle-même — mais **en retirant la colonne, sans
  erreur**. Les deux abonnements ne casseraient pas : ils se tairaient. La
  carte ne bougerait plus personne ; la révocation de session par un
  administrateur cesserait.
- **Aucune fermeture purement serveur n'existe.** Effacer la position quand
  `share_location` est coupé casserait les notifications d'événements locaux
  (`users_near_point` en a besoin pour qui a gardé `notify_local_events`).
  Une vue masquante à la place de la table : 28 clés étrangères entrantes, un
  abonnement temps réel ne suit pas une vue, et aucune sauvegarde.

Reste, et c'est tout le reste : **la version cliente des 16 sites**, sa
publication, la pose du verrou, puis l'application de la cible.

### 1.2 Amitié forcée → lecture des publications et stories « Amis » **[PROD]**

`firestore.rules:161` autorise l'écriture de `users/{victime}/friends/{moi}`
dès que `friendId == auth.uid`. `mirrorFriendToSupabase` recopie la ligne dans
Postgres avec la clé de service, sans revérifier ; `est_ami_de` lit exactement
ce sens. Le banc `acceptation_ami.mjs:168` mesure ce cas sans l'exiger refusé.

**Matière exposée à ce jour : AUCUNE** (mesuré le 2026-09-20) — 6 publications
et 6 stories, toutes `public` ; 0 contenu en audience « amis » ou « abonnés ».
Table saine : 24 lignes, 12 paires symétriques. Le trou est réel mais sans
butin tant qu'aucune publication « Amis » n'existe.

**✅ Porte directe Postgres FERMÉE le 2026-09-21** — migration
`20260921021300` appliquée (commits `96622af`, `d970cca`). `public.friends`
n'est plus inscriptible par `anon` ni `authenticated` : un compte connecté ne
peut plus se déclarer ami, ni se retirer d'une audience à l'insu de l'autre.
Banc `tools/rls_tests/friends_ecriture_serveur_seul.sql` : 8 échecs avant,
12/12 après ; `POST /rest/v1/friends` rend 401/42501.

**✅ Chemin Firestore FERMÉ le 2026-09-21** (commit `9e7d9e6`, déployé).
La correction ne pouvait pas vivre dans la règle : les règles
Firestore ne font pas de requête, et la preuve du consentement est **détruite**
— `_oublierDemande` supprime la demande juste après l'acceptation
(`friend_remote_datasource.dart:200`). D'où deux déclencheurs :

- `onFriendRequestAccepted` (nouveau) écrit les deux sens à la transition
  `pending → accepted`, que l'événement porte même si le document est supprimé
  ensuite. Seul chemin d'entrée désormais, et **aucun changement client** :
  toutes les versions installées en bénéficient.
- `mirrorFriendToSupabase` reflète toujours un retrait, mais ne reflète un
  ajout que si le sens inverse existe déjà — ce qui, depuis la migration
  ci-dessus, ne peut venir que de la clé de service.

Banc `tools/rules_tests/amitie_consentie.mjs` : 11 cas, 0 échec ; garde
retirée, B3 seul tombe. Déployées une par une, dans l'ordre imposé —
`onFriendRequestAccepted` d'abord, vérifiée en ligne, le miroir ensuite ;
l'inverse aurait ouvert une fenêtre où aucune amitié neuve n'entrait dans
Postgres. **Aucune demande d'ami réelle n'a été jouée** : les données sont
intactes (24 lignes, 12 paires, 0 asymétrie), c'est tout ce qui est vérifié.
Si `onFriendRequestAccepted` ratait, la panne serait **silencieuse** —
l'audience resterait fermée au lieu de s'ouvrir à tort, et invisible tant
qu'aucune publication « Amis » n'existe. Entrée P1 du suivi.

Constaté au passage, confirmant une note ancienne : tout `firebase deploy` de
functions **republie les variables de `functions/.env`** sur les fonctions
visées. Ces deux-là portent donc désormais `TURN_SECRET` (le secret coturn
compromis le 2026-07-16, jamais roté), `STRIPE_WEBHOOK_SECRET` au placeholder
et `STRIPE_SECRET_KEY` en `sk_test` — comme les 74 autres avant elles. Ce
n'est pas une régression, c'est l'état du projet, à traiter au §1.8.

**⬜ Reste après ça** : la liste d'amis Firestore de la victime reste
polluable (nuisance, plus fuite d'audience). Fermer la règle casserait
l'acceptation pour les versions installées — client d'abord.

### 1.3 Insertion de messages dans la conversation d'autrui **[PROD]**

**✅ FERMÉ le 2026-09-20** — migration `20260920214800` appliquée (commits
`e96bf05`, `2c831be`). Banc `tools/rls_tests/messages_insert_participant.sql` :
3 échecs avant (dont « NON participant : ACCEPTÉ » et « EXCLU : ACCEPTÉ », la
faille démontrée sur la production), 11/11 en répétition puis sur l'état
vivant. Non vu sur appareil : l'ordre réel des écritures (entrée P0 du suivi).

`messages_insert` : `WITH CHECK (firebase_uid() = sender_id)`, sans contrôle de
participation (`mls_messages`, lui, exigeait `is_conversation_participant`). Un
membre exclu qui gardait l'id continuait de publier, et les participants
voyaient le message dans leur fil.

**Rectificatif.** La première version de ce rapport disait que « chaque message
pousse une notification à tous ». **C'était faux** — repris d'un sous-agent
sans lire le déclencheur. `notify_recipients_on_message_insert` sort sans rien
créer quand l'expéditeur n'est pas participant. La faille était réelle, mais
silencieuse.

**✅ Anomalie de données RÉPARÉE le 2026-09-21** (migration `20260921110000`
appliquée), et la gravité était surestimée. Le contrôle d'accès porte sur
`participant_ids` (`is_conversation_participant`), pas `group_members`. Les
« 2 personnes » sont en fait **deux comptes DISPARUS** : chaque uid est absent
de `users`, sans un seul message nulle part, hors de `group_members`,
d'`auth_mappings`, d'`amitiés`, présent dans une seule conversation. Personne
ne détient ces identifiants — **aucun accès exploitable**, seulement du résidu
laissé par une suppression antérieure au nettoyage de `purge_account` (qui, lui,
retire aujourd'hui l'uid de `participant_ids`). C'étaient les **seuls** uid
orphelins de toute la base.

Retirés par une migration privilégiée (`session_replication_role = replica`
pour traverser `conversations_guard_admin_fields`), ciblant les deux uid
nommés, avec garde par identifiant (on ne retire que ce qui n'a toujours aucun
compte). Vérifié après : 0 orphelin, `group_members` et les autres
conversations intacts. Banc `tools/rls_tests/participants_orphelins.sql` :
3 échecs sans, 0 avec.

Le « 1 membre manquant » n'est pas un défaut : c'est un vrai membre d'un groupe
**officiel** que `join_group_conversation()` ajoutera à l'ouverture de la
discussion (jointure paresseuse par conception). Laissé tel quel, sur décision.
Aucun garde-fou ajouté : la cause des orphelins est déjà close.

### 1.4 Storage : écrasement du fichier d'autrui **[PROD]**

`storage.rules:76-124` : aucune notion de propriétaire sur `messages`,
`groups`, `events`, `products`, `businesses`, `posts`, `stories` ; `image/.*`
accepte le SVG. L'URL d'un média révèle son chemin.

**✅ Moitié Admin SDK FERMÉE le 2026-09-21** (commit `b2f1d1b`, quatre
fonctions déployées). C'était la plus grave des cinq traitées ce jour-là : la
seule qui DÉTRUIT la donnée d'autrui au lieu de la lire.

Attaque, de bout en bout : `conversations/<uuid neuf>/participants/<mon uid>`
passe (`!data.exists()`) ; `messages/<uuid>/<msg>` n'exige que `senderId`,
`type`, `createdAt` et laisse `fileUrl` libre, champs inconnus compris ; on y
pointe `key_backups/<victime>/backup.enc` et on appelle
`deleteMessageForEveryone`, dont TOUS les contrôles passent — on est bien
l'expéditeur de son propre message, dans le délai d'une heure. Le serveur
effaçait alors l'identité Signal sauvegardée de la victime. Les règles Storage
durcies le même jour n'y pouvaient rien : l'Admin SDK les ignore.

Cinq sites dérivaient ainsi un chemin d'une URL : `deleteMessageForEveryone`
(2), `deleteGroup`, `cleanupExpiredMessages`, `cleanupExpiredMediaFiles` — les
deux dernières **planifiées**, donc déclenchables sans appel. Tous passent par
`cheminStorageSur` (`functions/chemins_storage.js`), qui refuse hors préfixe et
journalise le premier segment seulement. Banc
`tools/rules_tests/chemin_storage.mjs`, 18 cas, sans émulateur : 9 échecs
avant, 0 après.

Corrigé et non supprimé, bien qu'aucune de ces fonctions ne soit appelée par
`lib/` : des APK installés peuvent encore les appeler (même prudence que pour
`sendMessagePush`). **Aucune suppression réelle n'a été jouée** — entrée P0 du
suivi, et le premier passage planifié sur le nouveau code n'a pas encore eu
lieu.

**✅ `deleteConversationForEveryone` FERMÉ le 2026-09-21** (commit `fb36f02`,
déployé). Le défaut n'était pas le chemin — correct — mais l'autorisation :
elle se lisait dans un document Firestore `conversations/<id>` que la règle
déployée laisse créer à quiconque s'y met en `participantIds`, et que plus
rien n'alimente depuis la migration. Le serveur demandait donc à l'attaquant
s'il était autorisé, puis effaçait `messages/<id>/` par préfixe — là où vivent
les médias des conversations VIVANTES. Connaître un identifiant, ce que garde
tout ancien membre, suffisait.

L'autorisation vient désormais de Supabase (`getConversation` étendu à
`created_by` et `data.adminIds`) : participant d'abord, puis créateur ou
administrateur ; une conversation inconnue de Supabase est refusée, ce qui est
exactement le cas du document fabriqué. Banc
`tools/rules_tests/suppression_conversation.mjs`, 13 cas : 6 échecs avant,
0 après. **Aucune suppression réelle n'a été jouée.**

Les cinq fonctions de ce §1.4 ont été corrigées et non supprimées, bien
qu'aucune ne soit appelée par `lib/` : des APK installés peuvent encore les
appeler.

### 1.5 Chaîne de paiement : ouverte, déployée, et inutilisée par l'app **[PROD]** pour les policies

Les fonctions `create-payment-intent`, `verify-order-payment`,
`process-escrow-release`, `process-tip`, `process-room-ticket`,
`stripe-connect-*` sont **ACTIVES** ; `lib/` n'en appelle plus qu'une.

- `orders` : le client fixe `total_amount` ; `orders_update_parties` n'a ni
  `WITH CHECK`, ni restriction de colonnes, ni déclencheur de garde (seul
  `orders_updated_at` existe). Un acheteur passe sa commande en `delivered` /
  `held` puis appelle `process-escrow-release`.
- `verify-order-payment:55-63` accepte n'importe quel PaymentIntent `succeeded`.
- `create-payment-intent:92-96` : `...metadata` étalé **après** `transaction_id`
  et `user_id`, que le webhook croit ensuite sans comparer le montant.
- `creator_profiles` : `FOR ALL` au propriétaire, donc `payout_enabled`,
  `stripe_account_id` et `total_earnings` sont posables à la main.
- `business_boosts` : le client insère `status:'active'`, `amount:0`.
- Côté Firebase, même famille : `creatorProfiles` forgeable + `processPayoutRequest`
  qui recrédite sans avoir débité ; commande forgée → `processEscrowRelease` ;
  lien du tableau de bord Stripe Express d'autrui (`functions/index.js:3428`, `:6668`).

Perte d'argent réel seulement si les secrets Stripe serveur sont en `live`
**[À VÉRIFIER]** — `functions/.env` local est en `sk_test`, mais les Edge
Functions ont bien un `STRIPE_SECRET_KEY` configuré côté Supabase.

**✅ FERMÉE EN ENTIER le 2026-09-21** (commits `94b4c53`, `99e1306`,
`1bb6e72`, `7067e6e` — tout déployé).

Le fait qui a tout décidé : **la chaîne n'a JAMAIS servi**. Mesuré des deux
côtés — 0 commande, 0 transaction, 0 séquestre, 0 pourboire, 0 billet, 0
profil créateur, 0 boost, 0 produit, 0 compte de paiement ; drapeaux
`marketplace`, `audioRooms`, `moneyTransfer` fermés. Fermer était donc gratuit,
et c'était le moment.

- **Douze collections Firestore** passées en écriture cliente interdite : ce
  sont des DÉCLENCHEURS de Cloud Functions agissant en Admin SDK — créer le
  document, c'est ordonner le virement. Banc
  `tools/rules_tests/paiements_fermes.mjs` : 12 échecs avant, 16/16 après.
- **`orders`, des deux côtés** : `allow create`/`allow update` à `if false`
  dans Firestore (où vit le parcours marketplace), et migration
  `20260921034600` côté Supabase — INSERT fermé, UPDATE réservé aux admins et
  limité par GRANT aux six colonnes de litige. Banc
  `tools/rls_tests/orders_ecriture_fermee.sql` : 9 échecs avant, 11/11 après.
- **Trois Edge Functions supprimées** (déploiement + dépôt) :
  `create-payment-intent`, `verify-order-payment`, `process-escrow-release`.
  Jamais référencées par `lib/` dans TOUT l'historique git.

**Deux rectificatifs à ce rapport.** Le `releaseEscrow()` du code Dart, que je
citais comme preuve que le client libérait le séquestre, était déjà **refusé
par les règles déployées** (note BUG-04) : du code mort. Le vrai trou
d'`orders` était la CRÉATION, libre de tout champ.

Et une panne silencieuse trouvée en chemin, **réparée** : la résolution de
litige du back-office touchait 0 ligne sans rien dire — un administrateur
n'est ni acheteur ni vendeur, et un `UPDATE … WHERE` doit passer les policies
de SELECT pour retrouver ses lignes. D'où `orders_select_admin`.

**✅ Les salons audio FERMÉS le 2026-09-21** (commit `ed6bf72`, migration
`20260921054500` appliquée). Et ce paragraphe, tel qu'il était écrit
ci-dessus, était **faux sur les deux moitiés** — la mesure a démenti l'audit.

*Ce que les quatre fonctions font vraiment.* `process-tip` et
`process-room-ticket` sont **CASSÉES**, pas permissives : elles insèrent
`commission_amount`, `recipient_amount`, `message`, `seller_id`,
`seller_amount`, `updated_at` — aucune de ces colonnes n'existe. Rejoué à
l'identique : 42703. Le `PaymentIntent` vient **après** cet insert, donc le
prix dicté par le client **n'a jamais atteint Stripe**. Et `stripe-webhook`
n'écrit que `transactions` : rien ne fait jamais passer un pourboire ou un
billet à `completed`. La monétisation des salons n'a jamais été branchée sur
le schéma réel.

*Où était le vrai trou.* Dans le RLS, et il était plus grave :

- `creator_profiles_own` était `FOR ALL` — le client écrivait son propre
  `stripe_account_id` (`updateCreatorProfile` le fait vraiment). Or
  `stripe-dashboard-link` fait confiance à cette colonne : poser
  l'identifiant d'un compte Connect quelconque et le statut « active » lui
  fait rendre un **lien de connexion au tableau de bord Stripe de ce
  compte**. La fonction est irréprochable ligne à ligne ; c'est la table
  qu'elle relit qui appartenait au client. Fermer la table la referme sans y
  toucher ;
- `tips_insert_own` / `room_tickets_insert_own` laissaient libres le montant
  et le `status`. Or `hasValidTicket` est le portier des salles payantes :
  s'insérer un billet « completed » donnait l'entrée, sans paiement ;
- `audio_rooms_update` était `USING (firebase_uid() IS NOT NULL)`, sans
  restriction de colonnes : n'importe quel compte connecté réécrivait
  n'importe quelle salle — `hostId`, `isPaid`, `ticketPrice`. Le prix du
  billet était bien dicté par le client, mais **par PostgREST, pas par la
  fonction** ;
- et les quatre tables portaient les droits par défaut pour `anon`.

*Ce qui a été posé.* Lecture seule sur `tips`, `room_tickets` et
`creator_profiles` ; `audio_rooms` limitée par GRANT aux **dix** colonnes que
le client écrit vraiment (relevé exhaustif des `.update(` du datasource —
participants et rôles vivent dans RTDB). Rien à casser : 0 pourboire,
0 billet, 0 fiche de créateur, 0 salle, drapeau fermé. Banc
`tools/rls_tests/salons_audio_ecriture_fermee.sql`, 18 cas : 10 échecs sans
la migration, 0 avec, 0 sur l'état vivant.

**⬜ Reste ouvert, et c'est mesuré, pas supposé :**

- `audio_rooms_update` garde `USING (firebase_uid() IS NOT NULL)` : la
  fermeture porte sur les COLONNES, pas sur la LIGNE. Un compte quelconque
  coupe encore le micro d'un intervenant dans la salle d'un autre (cas 17 du
  banc). Refermer la ligne demande des RPC par geste, pas un `REVOKE` ;
- `forceEndRoom` par un administrateur non-membre est **refusé** (42501,
  cas 18). Panne préexistante, ni causée ni réparée ici : Postgres applique
  les policies de SELECT à la **nouvelle** ligne d'un UPDATE, et
  `audio_rooms_select` ne montre une salle terminée qu'à ses membres. Même
  famille que la résolution de litige de `orders`, mais la réparer serait un
  **élargissement** (un administrateur verrait toutes les salles privées) :
  c'est une décision, pas un correctif ;
- les quatre fonctions restent déployées, cassées comme avant. Les réparer,
  c'est construire la fonctionnalité ;
- la valeur de `STRIPE_SECRET_KEY` **déployée** n'est pas celle de
  `functions/.env` (digests différents). Le dépôt est en `sk_test` ; la
  valeur en ligne n'est pas lisible d'ici. À trancher dans le tableau de bord
  Stripe avant toute réouverture ;
**✅ `business_boosts` FERMÉE le 2026-09-21** (commit `ab8322e`, migration
`20260921071500` appliquée, `firestore.rules` déployé et relu par l'API).
Et là encore l'audit visait la petite moitié : **cette table est la
quittance, pas la caisse.**

`businesses_update_owner` n'avait ni `WITH CHECK` ni restriction de colonnes,
donc le propriétaire réécrivait toute sa ligne — `is_boosted`,
`boost_expires_at` et **`is_verified`** compris. Se promouvoir dix ans et se
décerner le badge de confiance ne demandait aucune ruse : c'est le chemin
nominal du code (`updateBusinessBoostStatus` pose `is_boosted` ; `_versLigne`
envoie `is_verified` à chaque enregistrement). Et `business_boosts` portait
le piège du CLAUDE.md en vrai — `GRANT SELECT, INSERT` sans `REVOKE`
préalable n'avait rien restreint : la table gardait tous les droits par
défaut, pour `anon` comme pour `authenticated`.

Fermé par un **déclencheur de garde**, pas par un `REVOKE` : `updateBusiness`
envoie toute la ligne à chaque retouche, donc une restriction par colonnes
aurait fait échouer la moindre modification en 42501 (le piège de l'upsert,
déjà payé sur `mls_messages`). La garde compare les valeurs, pas les colonnes
écrites. Le back-office garde tout par la sortie `is_admin()` — sans elle,
la vérification des fiches aurait cessé de marcher, exactement la panne
trouvée sur `orders` la veille.

Banc `tools/rls_tests/boost_et_badge_verifie.sql`, 17 cas : 9 échecs sans la
migration, 0 avec, 0 sur l'état vivant. 2 entreprises, 0 promue, 0 vérifiée.

⬜ Reste, hors sécurité : `rating` et `review_count` ne sont **calculés par
personne**. Le commentaire du datasource les dit tenus par des « triggers
d'agrégat » qui n'existent pas — l'annuaire affichera 0,00 étoile quoi qu'il
arrive. La garde les protège d'un `PATCH` direct, ce qui ferme la faille mais
pas le défaut.

**Rouvrir sera une décision explicite**, collection par collection, avec un
séquestre tenu par le serveur : prix relu depuis `products`, paiement confirmé
auprès de Stripe, passages à `paid` et `completed` réservés à une fonction.

### 1.6 Push arbitraire vers n'importe quel compte **[PROD]**

`create_user_notification(p_user_id, p_type, p_title, p_body, p_data)` :
champs libres, ni lien avec le destinataire, ni blocage, ni quota. Hameçonnage
par notification `system` — le type que l'app traite comme une annonce de la
plateforme, et qui décide du canal.

**✅ FERMÉ le 2026-09-21** — migration `20260921032400` appliquée (commit
`778e19f`). Trois gardes : type en **liste fermée** (les douze que `lib/`
émet ; les types serveur passent par des déclencheurs, pas par cette RPC),
**blocage respecté** en silence, et **quota horaire** (60 par émetteur, 10 par
couple). Banc `tools/rls_tests/notification_type_et_quota.sql`, 14 cas :
7 échecs avant, 0 après, sur l'état vivant.

Le banc mesure au passage les **81 envois** que son `ROLLBACK` annule :
`net.http_post` passe par la file transactionnelle de pg_net, donc aucun push
ne part. Utile à savoir pour tout banc qui touche `notifications`.

**✅ Texte libre FERMÉ le 2026-09-21** (migration `20260921100000`). `p_title`
et `p_body` restent dans la signature mais ne sont plus lus : le serveur rédige
le texte par type, le nom de l'émetteur vient de `users`, et `p_data` passe par
une liste blanche — ce qui a fermé au passage un faux appel entrant
(`data.type` écrasait le type du push). `report_resolved` réservé aux admins.
Et `send-push` durci (v33) : les clés réservées posées après `data`. Voir 1.6
du suivi.

**✅ `onCallCreated` FERMÉ le 2026-09-21** (déployé) : nom et photo lus dans
Supabase, blocage respecté, règles `calls` bornées. Voir le domaine Appels du
suivi.

### 1.7 Ni sauvegarde, ni schéma reproductible **[PROD]**

Aucun point de restauration Supabase (PITR `false`). Et **47 des 104 tables**
de production n'ont aucun `CREATE TABLE` dans `supabase/migrations/` — dont
`conversations`, `messages`, `notifications`, `payment_accounts`, les tables
`e2ee_*`. `rls_auto_enable` n'y figure pas non plus. Le dépôt ne sait pas
reconstruire la base.

Correction : activer les sauvegardes ; `supabase db dump --linked` (lecture
seule) pour déposer un schéma de référence dans le dépôt.

### 1.8 Ancienne clé `service_role` **[PROD] — RÉSOLU le 2026-09-21**

Le commentaire du `.env` disait « la clé précédemment présente ici a été
exposée → la faire tourner ». C'était une **consigne à faire**, pas un
constat : restait à savoir si elle avait été suivie.

**Réponse : oui.** `supabase projects api-keys` montre que les clés legacy
`anon` et `service_role` **existent toujours** dans le projet — mais une
requête avec chacune d'elles rend `401 Legacy API keys are disabled`. La clé
exposée dans les anciens APK est donc **inerte**. (Une sonde plus naïve ne
tranche pas : avec un JWT forgé, la passerelle répond « Invalid API key »,
exactement comme pour une chaîne quelconque. Il faut essayer les vraies clés
legacy du projet pour obtenir le message qui distingue.)

Au passage, la même sonde confirme le §1.1 : la clé publishable courante rend
`42501 permission denied for table users`.

**Nettoyé dans la foulée** (commit à suivre) :

- `GOOGLE_APPLICATION_CREDENTIALS` **retiré du `.env`** : c'était un chemin
  Windows absolu — nom d'utilisateur, arborescence, nom du fichier de clé
  admin — embarqué en clair dans chaque APK. Son seul lecteur,
  `scripts/creer_compte_test.js`, retrouve la clé tout seul (il balaie la
  racine à la recherche d'un `*-adminsdk-*.json`) ; son branchement `.env` a
  été supprimé pour ne pas réintroduire le motif.
- Le **récit d'incident** sur la `service_role` a quitté le `.env` : il
  décrivait une faille passée à quiconque ouvre l'APK. Remplacé par une ligne
  neutre.
- Garde committée : `test/core/env_embarque_test.dart` refuse désormais une
  variable au nom inconnu, une valeur en forme de secret (JWT, `sk_`,
  `sb_secret_`, `whsec_`, clé privée, AWS, SendGrid, Slack, GitHub) et tout
  chemin absolu de poste. Les trois contrôles ont été vus échouer sur une
  violation plantée, puis repasser. 1 914 tests verts.

**⬜ Reste, sans urgence** : 17 des 22 variables du `.env` ne sont plus lues
par `lib/` (Firebase en dur dans `firebase_options.dart`, reCAPTCHA dans
`main.dart`, identifiant marchand dans `app_config.dart`). Toutes publiques
par nature — du poids mort, pas un risque. La garde les tolère nommément.

**⬜ Reste, et ça compte** : `functions/.env` n'a pas été touché. Il porte
`STRIPE_WEBHOOK_SECRET` au placeholder, `STRIPE_SECRET_KEY` en `sk_test`, et
`TURN_SECRET` — le secret coturn compromis le 2026-07-16, **jamais roté**.
Tout `firebase deploy` de functions republie ces valeurs sur les fonctions
visées ; les deux déclencheurs d'amitié déployés le 2026-09-21 les portent
désormais aussi. Rotation du secret coturn = accès au VPS ; clés Stripe live =
décision du propriétaire.

### 1.9 Surface résiduelle Postgres **[PROD]**

- `anon` garde un droit d'écriture sur **83 tables**, `authenticated` garde
  `TRUNCATE` sur **87** (TRUNCATE ignore le RLS). Aucune migration globale de
  `REVOKE` n'existe.
- 9 fonctions `SECURITY DEFINER` qui écrivent sont appelables par `anon` sans
  contrôle d'identité : `get_or_create_official_group`,
  `update_live_viewer_count(p_delta)`, `increment_*`, `refresh_episode_like_count`.
- 7 `SECURITY DEFINER` sans `search_path` : `firebase_uid` (utilisée par toutes
  les policies), `current_user_id`, `lock_escrow_for_release`,
  `enforce_group_creator`, `increment_post_external_share`,
  `increment_product_view`, `update_live_viewer_count`.
- 16 tables sous RLS **sans aucune policy**, donc vides pour tout client, sans
  erreur. L'app en lit 9 : `stickers`, `sticker_packs`, `user_sticker_packs`,
  `user_favorite_stickers`, `user_recent_stickers`, `business_posts`,
  `admin_audit_logs`, `admin_notifications`, `activity_logs`. À voir sur
  appareil : onglet stickers et publications d'une fiche de l'annuaire.
- `send-phone-otp` : quota par couple utilisateur/numéro (contournable → SMS
  pumping), OTP par `Math.random()`, JWT décodé sans vérification.
- `auth-firebase-exchange:135-160` : rattachement par e-mail sans
  `email_verified`, inscription native ouverte **[À VÉRIFIER]** en prod.
- Fenêtre de modification de 48 h : côté client seulement.

---

## 2. Bloquants pour la soumission Play

1. **« Position approximative uniquement »** (`app_fr.arb:7684`, `app_en.arb:6485`,
   affiché par `profile_config_screen.dart:742` ; aussi `public/index.html:196,252`,
   `public/fonctionnalites.html:87`, `DEPLOYMENT.md:228`) alors que le code lit en
   `LocationAccuracy.high`/`medium` et stocke les coordonnées brutes. Même motif
   que les cinq refus. Aligner aussi le formulaire « Sécurité des données ».
2. **Page `/delete-account`** : réécrite dans le dépôt, non publiée ; la clé
   Firebase de `delete-account.html:718` / `-en.html:577` n'a l'empreinte d'aucune
   autre clé du dépôt et est refusée par Google. Y mettre la clé Web de
   `firebase_options.dart:40`, restreinte par référent.
3. **App ID AdMob de test** dans `AndroidManifest.xml:316-318`
   (`ca-app-pub-3940256099942544~…`) alors que les unités de `ad_config.dart`
   sont de production. iOS porte le bon.
4. **Aucun consentement UMP** : 0 occurrence de `ConsentInformation` ; AdMob
   initialisé sans condition. La diaspora visée vit largement dans l'EEE.
5. **Boost de fiche vendu par Stripe** (bien numérique) :
   `business_repository_impl.dart:240-258`, entrée active. Plus une branche
   « Simulation » qui crée un boost sans paiement (`:264-267`). Masquer avant
   soumission ou passer par la facturation du store.
6. **Clé Stripe de test reprise en silence** : `app_config.dart:99-104` ne prend
   la clé live que si `PRODUCTION=true` **et** `STRIPE_PUBLISHABLE_KEY` sont
   passés ; `BUILD.md:255` et `secrets_production.md:140` en oublient chacun un.
7. **Version** : `pubspec.yaml:4` dit `1.2.1+23`, les documents du 20/09 disent
   `1.2.2+23`, et aucun commit ne porte `1.2.2`. Lire le `versionName` de l'AAB.
   Si `DERNIERE_VERSION_APP=1.2.2+23` est posé sur un binaire 1.2.1, le bandeau
   de mise à jour s'affichera en permanence.
8. **Intent-filter `autoVerify` sans `pathPrefix`** (`AndroidManifest.xml:227-233`) :
   `diasponiger.com/privacy-policy` et `/delete-account` ouvrent l'app sur
   « Page Not Found » (GoRouter sans `errorBuilder`) — y compris pour
   l'examinateur Play.
9. **Fiche Play** : annonce appels, messages épinglés et GIFs ; appels et
   épingles sont en pause.

## 3. Robustesse avant d'ouvrir à plus d'utilisateurs

- **Écran blanc au démarrage** : `main.dart:167,236,257,263` — quatre `await`
  non protégés avant `runApp` ; une boîte Hive corrompue bloque l'app.
- **Mise à jour forcée inopérante** : `VERSION_MINIMALE_APP` absente de la liste
  blanche d'`app-config` ; verrou posé dans le shell seulement
  (`main_shell.dart:94`), donc contourné par `/messages/<id>`. C'est un prérequis
  écrit de la bascule MLS.
- **Logs en release dans les isolates d'arrière-plan** :
  `background_location_service.dart:324-326` écrit latitude et longitude dans
  logcat. La neutralisation (`logs_release.dart`) ne couvre que l'isolate principal.
- **Sauvegarde Android** : seul `files/mls/` est exclu ; les boîtes Hive
  `e2ee_sessions` / `e2ee_sender_keys` et les préférences de
  `flutter_secure_storage` partent en sauvegarde (la clé du Keystore, elle, ne
  se restaure pas → exceptions après restauration **[À VÉRIFIER]**).
- **Rappels programmés muets** : `zonedSchedule(exactAllowWhileIdle)` sans
  permission ni receivers au manifeste ; l'échec est sous `unawaited`. Passer en
  `inexactAllowWhileIdle`.
- **Appels « en pause »** : `/calls/history`, `/calls/:callId`,
  `/group-calls/:callId` restent atteignables par lien profond et lancent un
  vrai appel. Fermer par une constante de compilation.
- **Routes admin sans garde client** : `app_router.dart:791,795,799,1029`. Les
  écritures `embassies` sont bien réservées aux admins côté Postgres ; il
  manque la garde de routeur (modèle : `/ghost`, `:415`).
- **XOF divisé par 100** : `creator_earnings_screen.dart:286,532`,
  `payout_entity.dart:108`, `creator_profile_entity.dart:111`.
- **Clé AES partagée en dur** (`encryption_service.dart:63`, AES-CBC sans MAC) :
  elle chiffre les IBAN/BIC de `payment_accounts`. Ne pas présenter ce champ
  comme « chiffré » ; finir la bascule vers les clés dérivées.
- **Clé Google Maps unique et sans restriction** (manifeste, `AppDelegate.swift:36`,
  appels REST Places). Trois clés restreintes.
- **`finalizeAccountDeletions`** : ni interrupteur d'arrêt, ni plafond journalier,
  ni alerte ; suppression Firebase Auth irréversible, sans sauvegarde derrière.
- **Hébergement** : aucun en-tête de sécurité (`firebase.json`) alors que la page
  de suppression porte un formulaire de mot de passe.
- **RTDB `group_calls`** : auto-inscription dans `participants` puis lecture de
  tout l'appel, `e2ee_key` comprise (`database.rules.json:133`). Appels en pause.
- Admin Firestore : `isAdmin` non protégé entre rôles (`firestore.rules:759-764`) ;
  un admin lit les sauvegardes de session E2EE (`:844-846`).
- Dépendances : toute la famille Firebase a une majeure de retard,
  `google_mobile_ads` 5 → 9, `firebase-functions` 4.9 (gen-1). À ne **pas**
  monter juste avant une release.

## 4. iOS — non soumissible en l'état

1. `CODE_SIGN_ENTITLEMENTS` absent du `project.pbxproj` : ni push, ni liens
   universels, ni « Se connecter avec Apple ».
2. Aucun `PrivacyInfo.xcprivacy` (ITMS-91053).
3. `UIBackgroundModes` : `processing` sans `BGTaskSchedulerPermittedIdentifiers` ;
   `voip`, `audio`, `location` sans fonction visible (2.5.4).
4. Moteur Rust/MLS et extension `NotificationService` jamais compilés ;
   `Podfile.lock` du 01/09 sans `diaspo_mls`.
5. `LSApplicationQueriesSchemes` absent (boutons Appeler / E-mail morts) ;
   textes caméra et micro incomplets ; Mode Voyage inopérant sur iOS.

## 5. Dette de vérification

`TESTS_APPAREIL_A_FAIRE.md` : **1 493 cases ouvertes**, dont 253 en P0 sur 44
entrées — suppression de compte (22 cases, jamais vue sur appareil), fil chiffré
tronqué au redémarrage (défaut ouvert, reproduit deux fois), légende de média
en clair sous l'étiquette « chiffré », chaîne push. MLS : phase 6 (gel) bloquée,
ses trois conditions fausses ; phases 4, 5, 7, 8 partielles.

Documents périmés à rectifier : `DEPLOYMENT.md:197,225-227`,
`PUBLICATION_IOS.md:113` (App Group), `CLAUDE.md` (« `strict-cible` non déployée »
alors que `database.rules.json` lui est identique), `PUBLICATION_IOS.md:22-23`
(adresse postale et téléphone suivis par git).

## 6. Non vérifié

Liste des Cloud Functions réellement déployées ; secrets Stripe serveur (test
ou live) ; règles RTDB déployées ; restrictions des clés en console GCP ;
formulaire « Sécurité des données » ; `npm audit` ; `cargo test`. Aucun des
scénarios d'exploitation n'a été rejoué.
