# Passer la messagerie à MLS — état des lieux et plan (2026-09-14)

Plan d'intégration de l'architecture MLS (Flutter + Rust/OpenMLS + Supabase),
écrit à partir de l'état **mesuré** de la production, pas de l'état supposé.

---

# 1. Ce qu'il y a vraiment en production

Relevé le 2026-09-14 sur le projet Supabase de l'app (`zyrfkcjjrhddpfxcgezo`),
en lecture seule, sans jamais lire le contenu d'un message.

| Mesure | Valeur |
|---|---|
| Messages | **115** (dont 2 supprimés) |
| Conversations touchées | 9 (sur 18 existantes : 12 individuelles, 6 groupes) |
| Auteurs distincts | 14 |
| Période | 2026-08-15 → 2026-09-14 (depuis la purge du 2026-08-14) |
| Messages en `encryptionLevel = 'aes'` | **105** |
| Messages en `encryptionLevel = 'e2ee'` | **0** |
| Messages portant `e2eePayloads` (Signal 1:1) | **0** |
| Messages portant `senderKeyPayload` (Signal groupe) | **0** |
| Lignes dans `e2ee_sender_key_distributions` | **0** |
| Appareils enregistrés dans `e2ee_devices` | 49 |
| Clés utilisateur `e2ee_user_keys` | 39 |
| Prékeys à usage unique publiées | **4 581** |

## Les deux faits qui commandent tout le reste

### Fait 1 — Il n'y a aucun corpus chiffré à migrer

Les 115 messages de production sont **tous lisibles par le serveur**, par
construction. La clé du repli AES est dérivée côté serveur par l'Edge Function
`crypto-keys`, dont la racine ne quitte jamais Supabase, et Postgres possède
`decrypt_aes_fallback()` — écrite exprès pour les aperçus de notification
(`supabase/migrations/20260813160000_real_plaintext_push_preview.sql`).

Conséquence directe : **« il existe des messages en production » n'est pas un
problème de cryptographie, c'est un problème de continuité d'affichage.** Il
n'y a rien à re-chiffrer. Il y a 115 bulles qui ne doivent pas disparaître de
l'écran de 14 personnes.

### Fait 2 — Le chantier E2EE précédent n'a jamais transporté un seul message

`lib/core/services/e2ee/` fait **8 608 lignes** : X3DH, Double Ratchet, Sender
Keys, sauvegarde de clés, transfert par QR, liste de mots EFF. L'infrastructure
serveur est déployée et peuplée — 49 appareils, 39 jeux de clés, 4 581 prékeys.

Le compteur qui compte vaut **0**.

Le code est complet, testé, jamais emprunté. Même famille que
`MediaEncryptionService` (0 appelant, cf. `CHIFFREMENT_MEDIAS_PLAN.md`).

### Et la cause n'est pas cryptographique — c'est un cycle de vie Riverpod

Établi par instrumentation sur appareil le 2026-09-14 (commit `7bb2e78`, motif
écrit en base) : `encrypt1to1` rapporte **`e2ee_non_initialise`**. Il saute
donc tout le bloc Signal sans même regarder les clés du destinataire — ce qui
explique que les clés soient parfaitement publiées pendant que rien ne tente
jamais Signal.

Mécanisme : `messagingE2EEServiceProvider` est un `Provider` simple, mais qui
**observe** `keyManagerServiceProvider` et `secureKeyStorageProvider`.
L'invalidation de l'un reconstruit le service, `_isInitialized` repart à
`false`, et personne ne le rejoue — `E2EEBackupCoordinator.bootstrap` pose son
garde `_bootstrappedFor` **avant** son `try` et sort immédiatement aux appels
suivants. Un garde jamais remis fige l'état, sans journal.

**C'est la leçon la plus transposable de tout ce document, et elle vaut plus
que le choix du protocole.** Le chiffrement n'a pas échoué : il n'a jamais été
appelé. Aucun test unitaire ne pouvait le voir, aucune revue de code non plus,
et `debugPrint` ne remonte pas dans logcat sur un build release — il a fallu
écrire le motif de repli **en base** pour l'apprendre.

Trois règles en découlent pour le moteur MLS, à poser dès la première ligne :

1. **Le moteur MLS ne doit pas être un `Provider` qui en observe d'autres.**
   Une instance longue durée, ou un rattrapage au point d'usage — comme
   `EncryptionService._ensureInitialized` le fait déjà.
2. **Un repli silencieux est interdit.** Si MLS ne peut pas chiffrer, l'envoi
   échoue visiblement. C'est le repli muet qui a rendu la panne invisible
   pendant des semaines : tout marchait, en clair.
3. **Le motif d'échec s'écrit en base, pas dans les journaux.** La colonne de
   diagnostic fait partie du schéma `mls_messages` dès la phase 5, pas d'un
   correctif ultérieur.

**C'est le risque numéro un du chantier MLS, avant tout risque technique :**
construire, en plus gros et en Rust, une seconde infrastructure que le chemin
réel contournera. Toute la structure de ce plan en découle — chaque phase se
termine par une **preuve de vie mesurable en production**, pas par « le code
est écrit ».

---

# 2. Les trois décisions à prendre avant d'écrire une ligne

## Décision A — Que faire des 115 messages

### A1. Gel + coexistence — **recommandé**

`messages` passe en lecture seule (`REVOKE INSERT`), une nouvelle table
`mls_messages` reçoit tout le trafic. L'historique reste lisible par le chemin
AES client existant, figé, avec un séparateur visible dans la conversation :

```text
─────── Messages d'avant le chiffrement de bout en bout ───────
```

Coût réel, et il est plus faible qu'il n'y paraît : une fois `messages` gelée,
elle n'est plus qu'un **historique statique**. Pas d'abonnement temps réel
dessus, une seule lecture paginée mise en cache dans Hive. Le flux temps réel
ne porte que MLS. C'est important, parce que `.stream()` de Supabase ne sait
ni joindre ni lire deux tables : deux sources auraient été coûteuses si les
deux étaient vivantes. Une seule l'est.

Bénéfice non évident : `REVOKE INSERT` est une garantie **auditable**. Après le
gel, il est impossible de créer un message lisible par le serveur, et ça se
vérifie en une requête — pas en relisant 45 000 lignes de Dart.

### A2. Purge

Comme le 2026-08-14. Gratuit, honnête, immédiat. Détruit l'historique de
9 conversations réelles. À garder comme repli si la fusion des deux sources
s'avère plus chère que prévu à l'usage.

### A3. Ré-encapsulation de l'historique en MLS — **à écarter explicitement**

C'est la réponse que produit spontanément « migrons les données », et elle ne
tient pas :

- produire un ciphertext MLS exige d'être **membre du groupe à l'epoch
  courant**. Un script serveur qui le ferait aurait les clés — exactement ce
  qu'on supprime ;
- un client pourrait ré-émettre l'historique comme des messages neufs, mais
  les horodatages, les auteurs et les accusés de lecture deviendraient faux.
  On aurait détruit l'historique en croyant le sauver.

À noter noir sur blanc pour que personne ne repose la question dans six mois.

## Décision B — Mise à jour minimale imposée

Un message MLS est illisible par tout build antérieur. Même conclusion que
`CHIFFREMENT_MEDIAS_PLAN.md` § 2 : **c'est une décision produit, pas
technique.**

La machinerie existe déjà (`lib/core/services/mise_a_jour_service.dart`, et
l'arbitrage des deux bandeaux couvert par `c84a693`). La réutiliser, ne pas la
réécrire. Le gel de `messages` (phase 6) ne peut pas précéder l'expiration du
délai de mise à jour.

## Décision C — Ce qu'on **n'adopte pas** de l'architecture proposée

L'architecture décrite est générique et correcte. Quatre de ses éléments
coûteraient ici beaucoup plus qu'ils ne rapportent.

### C1. Le monorepo (`apps/`, `packages/`, melos) — non

Deux agents travaillent sur `wip-jules-…`. Déplacer `lib/` entier rend tout
merge impossible pendant des jours et emporte le travail en cours de l'autre.
Le gain est nul : il y a une seule application. **Garder `lib/features/…`.**

### C2. SQLite local pour les messages — pas dans ce chantier

Le cache applicatif est Hive (`lib/core/services/cache_service.dart`), et
`features/messages` fait **81 fichiers / 45 558 lignes** qui lisent ce chemin.

Ne pas confondre deux bases qui portent le même nom :

- l'**état MLS** est en SQLite **côté Rust** (`openmls_sqlite_storage`),
  invisible de Dart — celle-là est obligatoire ;
- le **cache d'affichage** reste Hive. Une migration Hive → SQLite est un
  chantier légitime, mais séparé. L'embarquer ici double le risque sans rien
  ajouter à la confidentialité.

### C3. Les appels (WebRTC E2EE, SFU, clé dérivée de MLS) — hors périmètre

Les appels tournent sur Firestore + RTDB + coturn, avec leur banc de règles et
leur propre histoire de pannes (`tools/rules_tests/signalisation_appels.mjs`).
Les coupler à MLS met deux chantiers à risque l'un de l'autre.

Seul lien à préserver : prévoir un point d'extension pour exporter un secret de
groupe MLS plus tard, sans le câbler.

### C4. Les pièces jointes — avant MLS, pas dedans

Les médias sont sur **Firebase** Storage, **en clair**, et
`CHIFFREMENT_MEDIAS_PLAN.md` a déjà fait l'inventaire du coût : 38
consommations d'URL réseau sur 21 fichiers, pas de mode flux, plafond à 100 Mo,
`MessageModel` sans champ pour la clé de fichier.

Ce chantier-là **ne dépend pas de MLS** : il peut se faire avec le repli AES
actuel et livrer un gain de confidentialité réel tout de suite. C'est même le
meilleur ordre — il valide le transport d'une clé dans le corps du message,
qui est exactement le mécanisme dont MLS aura besoin ensuite.

---

# 3. Ce que MLS casse, et qu'il faut regarder en face

## L'aperçu des notifications

C'est la plus grosse perte fonctionnelle du chantier, et elle est structurelle.

**Aujourd'hui**, l'aperçu s'affiche partout — premier plan, arrière-plan, app
tuée — parce que **Postgres déchiffre** dans le trigger
`notify_recipients_on_message_insert` et écrit le vrai texte dans
`notifications.body`, qui part tel quel dans le payload FCM.

**Après MLS**, le serveur ne peut plus rien lire. L'aperçu doit être reconstruit
sur l'appareil, et les deux plateformes ne sont pas au même point.

### Android — praticable, déjà à moitié fait

`supabase/functions/send-push/index.ts:330` envoie déjà les messages en
**data-only**, sans bloc `notification` : le commentaire du fichier documente
la vérification sur SM A515F (`adb logcat`, 2026-08-13) — avec un bloc
`notification`, le système affiche lui-même la bannière et **Dart ne s'exécute
jamais**. Sans lui, `onBackgroundMessage` est bien invoqué.

Le chemin existe donc : isolate background → lib Rust → déchiffrement →
notification locale.

### iOS — à construire entièrement

`ios/` ne contient que `Runner` et `RunnerTests` : **il n'y a pas de
Notification Service Extension.** Aujourd'hui `aps.alert` porte le texte en
clair, affiché par le système sans exécuter de code applicatif.

Il faut donc créer une NSE, y embarquer la lib Rust, et partager l'état MLS
entre l'app et l'extension via un App Group.

### Le piège le plus subtil de tout le chantier

**Deux processus ne peuvent pas faire avancer le même cliquet.**

Déchiffrer un message MLS consomme une génération dans l'arbre de secrets. Si
la NSE (ou l'isolate background Android) déchiffre **et persiste** l'état,
puis que l'app déchiffre le même message depuis un état devenu périmé, les deux
états divergent — et la conversation devient illisible, silencieusement.

Conception à valider au spike, pas à découvrir en production :

- un **seul écrivain** de l'état MLS ;
- l'extension / l'isolate déchiffre sur une **copie de travail** qu'elle jette,
  n'écrit qu'un cache d'aperçu en clair, et laisse l'app faire le traitement
  qui fait foi ;
- coût : double déchiffrement du même message. Acceptable. La divergence
  d'état, non.

Sur Android, la même règle vaut entre l'isolate background et l'isolate UI, qui
peuvent tourner en même temps.

## Les métadonnées, à accepter consciemment

L'architecture proposée accepte que le serveur voie « qui écrit à qui, quand,
depuis quel appareil ». Pour une application de diaspora, ce graphe social
horodaté n'est pas une métadonnée anodine : c'est souvent plus sensible que le
contenu.

MLS ne le résout pas. Ce plan ne le résout pas non plus. Ce qui est demandé
ici, c'est de **l'écrire** au lieu de le laisser implicite, et de ne pas
présenter le résultat comme une confidentialité totale dans l'interface.

## Les journaux

~920 appels `debugPrint` écrivent dans `logcat` en release
(cf. `project_logs_release_debugprint`).

**Règle dure du chantier : aucune ligne de journal ne doit approcher un
plaintext, une clé, un KeyPackage privé ou un état de groupe.** Un chiffrement
de bout en bout qui recopie le message clair dans logcat est pire que pas de
chiffrement du tout — il ment.

---

# 4. Les phases

Chaque phase se termine par une **preuve de vie** : une requête SQL sur la
production, ou une case cochée dans `TESTS_APPAREIL_A_FAIRE.md`. Pas « le code
est écrit ».

## Phase 0 — Décider (quelques jours, zéro code)

Trancher A, B, C. Écrire les décisions en tête de ce document.

> **Preuve** : ce fichier, mis à jour et committé.

## Phase 1 — Spike jetable (≈ 2 semaines, branche à jeter)

Aucun code de production, aucune table, aucun écran. Cinq questions dont trois
peuvent tuer l'architecture.

1. **La chaîne de build tient-elle ?** `cargo build` → `.so` arm64-v8a et
   armeabi-v7a, intégrées au Gradle existant (NDK 27.0.12077973 déjà épinglé).
   **Et alignées sur 16 Ko** — le projet a déjà payé ce problème une fois
   (`tools/verifie_alignement_16k.py`, deux `.so` corrigées par résolution
   Gradle). Une lib Rust non alignée bloque la publication Play, et ça ne se
   voit qu'à la soumission.
2. **Combien pèse l'APK ?** OpenMLS + provider crypto + SQLite, par ABI.
3. **Combien de millisecondes pour déchiffrer à froid dans l'isolate
   background ?** Ouverture de la base Rust + chargement de l'état de groupe +
   déchiffrement. Budget : notification affichée en moins de 2 s après le push.
   **À mesurer sur SM A515F (4 Go), pas sur l'émulateur.**
4. **La NSE iOS est-elle faisable ?** Extension créée, lib Rust embarquée, App
   Group partagé, déchiffrement en copie de travail sans écriture d'état.
5. **Le build release signé démarre-t-il ?** Pas « compile » — démarre, sur
   l'appareil. (`:app:packageRelease` tombe au tout dernier moment quand
   `key.properties` manque ; un APK stale peut aussi donner un build
   « réussi » qui n'est pas le vôtre.)

OpenMLS classe Android ARM64 et iOS ARM64 en *« unsupported, but built on
CI »*. C'est précisément ce que ce spike vérifie.

> **Preuve** : un GO/NO-GO écrit, avec des chiffres — Mo d'APK, ms à froid,
> verdict NSE. En cas de NO-GO, on l'apprend en 2 semaines au lieu de 6 mois.

## Phase 2 — Registre d'appareils (avant toute crypto de message)

Tables `devices` et `mls_key_packages` + RLS. Écran « Mes appareils »,
révocation, nommage.

Cette phase vient en premier parce que c'est exactement là que le chantier
Signal s'est arrêté sans que personne ne le remarque : 49 appareils
enregistrés, 0 message. Un registre d'appareils qui n'est pas **vivant** rend
MLS multi-appareil fictif.

> **Preuve** : `select count(*) from devices where last_seen_at > now() -
> interval '7 days'` > 0, sur des comptes réels, pas le compte de test.

## Phase 3 — Le banc bout en bout, sans interface

Deux clients sans écran : A crée le groupe, publie son KeyPackage, ajoute B,
envoie ; B reçoit le Welcome, déchiffre. Contre une vraie base Supabase.

Puis les cas méchants, qui sont le vrai contenu de cette phase :

- message reçu **deux fois** (le projet connaît déjà le problème :
  `clientMessageId` + `_reconcileEcho`) ;
- messages **hors ordre**, message d'un **epoch périmé** ;
- **commit perdu**, appareil qui rate un changement d'appartenance ;
- appareil **retiré**, puis qui rejoue un vieux message ;
- **réinstallation** de l'app : état MLS perdu, que voit l'utilisateur ;
- reconnexion après coupure — le **rattrapage temps réel** (≈ 15 s, vérifié
  device) doit continuer de fonctionner sur le flux MLS ;
- **le moteur détruit et recréé au milieu d'une session** — le cas exact qui a
  tué le chantier Signal (§ 1). Le banc doit invalider le moteur entre deux
  envois et vérifier que le second part quand même en MLS, ou échoue
  visiblement. Jamais qu'il retombe en clair.

C'est la phase qui fait la différence avec le chantier Signal. Elle doit exister
**avant le premier écran**.

> **Preuve** : le banc tourne en CI, et il échoue quand on casse un cas
> exprès.

## Phase 4 — Notifications (avant l'ouverture du flag, pas après)

- Android : déchiffrement dans l'isolate background, verrou d'écrivain unique.
- iOS : NSE + App Group + copie de travail.
- Le trigger `notify_recipients_on_message_insert` cesse de tenter le
  déchiffrement pour les messages MLS : `notifications.body` devient générique
  côté serveur, remplacé localement.

Cette phase est **avant** l'ouverture du flag, sinon chaque conversation
basculée perd silencieusement son aperçu et personne ne saura dire quand ça a
commencé.

> **Preuve** : sur SM A515F **et** sur un iPhone, app tuée, push reçu, aperçu
> réel affiché. Tant que les deux cases ne sont pas cochées dans
> `TESTS_APPAREIL_A_FAIRE.md`, le flag reste fermé.

## Phase 5 — 1:1 derrière un flag, en coexistence

Table `mls_messages` (`ciphertext bytea`, `epoch bigint`, `sender_device_id
uuid`) + RLS. `messages` est encore ouverte en écriture — le flag est fermé.

Le repository fusionne une lecture paginée du legacy et le flux MLS, avec le
séparateur visible.

Attention : `messages.id` et `conversation_id` sont des **TEXT** (identifiants
Firestore hérités), pas des uuid. Le schéma cible en uuid ne peut pas
référencer le legacy. C'est une raison de plus pour une table séparée plutôt
qu'une colonne `protocol` ajoutée à l'existante.

> **Preuve** : `select count(*) from mls_messages` > 0, entre deux comptes
> réels, sur deux appareils réels.

## Phase 6 — Gel du legacy (point de non-retour)

1. Délai de mise à jour minimale expiré (décision B).
2. `REVOKE INSERT ON public.messages FROM authenticated`.
3. `decrypt_aes_fallback()` retirée des **triggers**.

À ne pas faire trop vite : **l'Edge Function `crypto-keys` ne peut pas être
éteinte** tant que l'historique legacy doit rester lisible — c'est elle qui
donne au client la clé de déchiffrement des 115 messages. Elle ne s'éteindra
qu'après une purge, si purge il y a un jour.

> **Preuve** : un `insert` dans `messages` avec `SET LOCAL ROLE authenticated`
> échoue. (Sans le `SET LOCAL ROLE`, `db query --linked` tourne en `postgres`
> et le test ment.)

## Phase 7 — Multi-appareil

Ajout d'un second appareil, vérification par QR, retrait d'un appareil perdu →
`Remove` + commit + nouvel epoch. Aujourd'hui la contrainte est « une seule
session par compte » ; c'est le gain produit le plus visible de MLS.

> **Preuve** : deux appareils d'un même compte affichent la même conversation,
> et un troisième révoqué ne déchiffre plus les messages suivants.

## Phase 8 — Groupes

À rappeler : les groupes ne sont **pas** chiffrés aujourd'hui
(`e2ee_sender_key_distributions` = 0). Ce n'est donc pas une migration, c'est
du neuf.

Le coût caché est ailleurs que dans la crypto : **chaque chemin d'appartenance
devient une opération cryptographique qui peut échouer.** Invitations, liens
d'invitation, exclusions, départs consentis, groupes de ville, groupe officiel
rejoint automatiquement selon la ville du profil — tout cela doit maintenant
produire un commit MLS, et un commit raté doit être rattrapable.

Prévoir le cas du **groupe officiel** : ajouts en masse, donc Welcome par
membre.

> **Preuve** : `select count(*) from mls_messages m join conversations c
> on … where c.type='group'` > 0.

## Phase 9 — Pièces jointes

Si C4 a été suivi, l'essentiel est déjà fait avec le repli AES ; il ne reste
qu'à déplacer le transport de la clé de fichier dans le payload MLS.

## Phase 10 — Démantèlement

Seulement après que MLS ait porté **100 % du trafic pendant plusieurs
semaines** :

- les 8 608 lignes de `lib/core/services/e2ee/` ;
- les tables `e2ee_devices`, `e2ee_user_keys`, `e2ee_one_time_prekeys` (4 581
  lignes pour rien), `e2ee_sender_key_distributions`, `e2ee_key_transfers` ;
- `EncryptionService._sharedKeyString`, la clé codée en dur.

Le faire trop tôt supprime le seul chemin qui marche.

---

# 5. Règles de chantier propres à ce dépôt

- **Worktree obligatoire.** Le chantier touche `features/messages` (81
  fichiers), où l'autre agent travaille aussi (refonte Fil/Discussion). Avant
  chaque livraison : `git -C <dépôt-principal> diff -U0 -- <fichier> | grep
  '^@@'`. Si les zones se chevauchent, consigner et attendre.
- **Jamais `dart format`** (500 lignes de bruit et un conflit garanti).
- **`uniq -d` sur les préfixes de migration** après chaque merge.
- **RLS testée avec `SET LOCAL ROLE authenticated`**, jamais en `postgres`.
- **`TESTS_APPAREIL_A_FAIRE.md` au fil de l'eau**, dans le même commit. Le
  chantier va y ajouter beaucoup : notification app tuée, réinstallation, perte
  d'appareil, second appareil, sortie de groupe, aperçu iOS.
- **Aucun journal ne doit approcher un plaintext ou une clé** (§ 3).

---

# 6. Ordre de grandeur

Pour un développeur seul, à temps partiel, en supposant que le spike passe :

| Phase | Ordre de grandeur |
|---|---|
| 0 — Décider | quelques jours |
| 1 — Spike | 2 semaines |
| 2 — Registre d'appareils | 2–3 semaines |
| 3 — Banc bout en bout | 3–4 semaines |
| 4 — Notifications | 3–4 semaines (dont l'essentiel côté iOS) |
| 5 — 1:1 en coexistence | 4–6 semaines |
| 6 — Gel | 1 semaine |
| 7 — Multi-appareil | 3–4 semaines |
| 8 — Groupes | 5–8 semaines |
| 9 — Pièces jointes | 2 semaines si C4 suivi, 6 sinon |
| 10 — Démantèlement | 1–2 semaines |

Soit **6 à 9 mois** en tout. C'est un ordre de grandeur, pas un engagement, et
il ne vaut que si les phases 1 à 4 sont faites dans cet ordre.

Le chemin le plus court vers un gain réel n'est pas MLS : c'est **C4** — chiffrer
les pièces jointes avec le repli existant. Deux semaines, aucun risque
d'architecture, et le mécanisme de transport de clé est validé pour la suite.
