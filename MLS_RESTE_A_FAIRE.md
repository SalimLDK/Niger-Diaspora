# MLS — ce qui reste, et ce qui bloque quoi

**Écrit le 2026-09-16.** Mémo de reprise : à lire d'abord quand on revient sur
le chantier après une pause. Le plan complet est dans
[CHIFFREMENT_MLS_PLAN.md](CHIFFREMENT_MLS_PLAN.md) ; ce fichier-ci ne dit que
**ce qui n'est pas fait**, et **pourquoi**.

La distinction qui compte partout ci-dessous :

- **bloqué** — la machine ou le calendrier l'interdit, ce n'est pas un oubli ;
- **différé** — techniquement possible aujourd'hui, mais le faire maintenant
  serait une faute ;
- **à décider** — attend une décision, pas du code.

---

## Vue d'ensemble

| # | Chantier | État | Ce qui le débloque |
|---|---|---|---|
| 1 | [Extension de notification iOS](#1-extension-de-notification-ios) | **bloqué** — jamais compilé | un Mac avec Xcode |
| 2 | [Ouvrir le drapeau au-delà d'un compte](#2-ouvrir-le-drapeau-au-delà-dun-compte) | **à décider** | votre décision, après la passe appareil |
| 3 | [Multi-appareil](#3-multi-appareil-phase-7) | **à décider** — par compte, pas globalement | un compte de test + l'écran de scan |
| 4 | [Vérifications appareil](#4-vérifications-appareil--43-cases-ouvertes) | ouvert — **43 cases** | du temps sur les deux téléphones |
| 5 | [Clé maître du Keystore (§ 7.4)](#5-clé-maître-du-keystore--74) | **bloqué** — 3 obstacles mesurés | Strawberry Perl + nasm, ou un autre angle |
| 6 | [Démantèlement (phase 10)](#6-démantèlement-phase-10) | **différé par choix** | 100 % du trafic en MLS, plusieurs semaines |

**L'ordre utile**, si vous ne faites qu'une chose : **4**. C'est la passe
appareil qui a trouvé sept défauts réels jusqu'ici — aucun par relecture.

---

## 1. Extension de notification iOS

*Livré le 2026-09-16 (`4dd2073`). État : tout le code existe, **rien n'a jamais
été compilé**.*

### Pourquoi iOS ne peut pas réutiliser le code Android

Le serveur ne connaît plus le texte d'un message chiffré : il envoie un repli
générique et le ciphertext, et l'appareil reconstruit l'aperçu.

Sur Android c'est un **isolate Dart** : il a le pont Flutter Rust Bridge et
partage le bac à sable de l'app. iOS n'a rien de tel. Une **Notification
Service Extension** est un binaire séparé, **sans Flutter, sans Dart, avec son
propre bac à sable**. D'où deux conséquences dont tout le reste découle :

1. il faut une **seconde porte** vers le moteur — une ABI C, pas le pont Dart ;
2. il faut un **terrain commun** entre les deux processus — le conteneur du
   groupe d'application.

### Les trois conditions, et leur point commun

Aucune des trois ne fait de bruit quand elle manque. Le symptôme est toujours
le même : **la notification s'affiche, générique, sans erreur et sans journal.**
C'est pourquoi elles sont listées ensemble.

| # | Condition | Si elle manque |
|---|---|---|
| 1 | la base du moteur vit dans le conteneur du **groupe** sur iOS | l'extension ouvre un fichier absent |
| 2 | compte + identifiant d'appareil déposés dans les `UserDefaults` **du groupe** | l'extension ne sait pas pour qui déchiffrer |
| 3 | `mutable-content: 1` sur les pushs MLS | iOS **n'invoque jamais** l'extension |

Deux pièges qui ont coûté une correction chacun :

- **la base se DÉPLACE, elle ne se copie pas.** Deux copies de l'état MLS, ce
  sont deux cliquets qui avancent séparément : la conversation devient
  illisible d'un côté, sans qu'aucune erreur ne le dise ;
- **`SharedPreferences` ne convient pas** pour le dépôt : le greffon Flutter
  préfixe toutes ses clés par `flutter.`, et une extension qui lit
  `currentUserId` ne trouverait rien.

### Ce qui reste à faire, et qui demande un Mac

`ios/Runner.xcodeproj/project.pbxproj` **n'est délibérément pas modifié à la
main** : format à identifiants générés, une cible ajoutée à l'aveugle casse
l'ouverture du projet sans rien dire. Tant que la cible n'existe pas,
`ios/NotificationService/` n'entre dans **aucune** build — l'app ne risque rien.

Les six étapes sont détaillées dans
[ios/NotificationService/README.md](ios/NotificationService/README.md) :

1. créer la cible *Notification Service Extension* et y rattacher les fichiers ;
2. renseigner le *bridging header* ;
3. lier `libdiaspo_mls.a` (`-force_load`) + dépendance vers le pod `diaspo_mls` ;
4. **App Groups sur les DEUX App ID**, puis régénérer les profils ;
5. identifiant de bundle préfixé par celui de l'app ;
6. versions identiques à celles du Runner (sinon l'archive est refusée).

### ⚠️ Le piège de diagnostic à connaître

**Tant que l'étape 4 n'est pas faite, `containerURL` rend nil**, le Dart reste
sur `Application Support`, et l'aperçu retombe sur le texte générique — c'est
le repli, il est voulu. **Ne concluez pas « l'extension ne marche pas » avant
d'avoir vérifié le provisionnement du groupe.** C'est le premier endroit où
regarder, pas le dernier.

### Trois risques que ce poste ne peut pas mesurer

- **Mémoire** : une NSE est coupée vers 24 Mo. Le coût du `VACUUM INTO`
  d'OpenMLS n'a **jamais** été mesuré.
- **Édition de liens** : le `-force_load` tire la glu FRB. Elle ne devrait pas
  réclamer la VM Dart au lien — à prouver.
- **Taille** : l'extension embarque sa propre copie du moteur.

### Ce qui remplace le compilateur Swift

`test/core/crypto/mls_apercu_ios_parite_test.dart` (15 cas) **lit les fichiers
source** et compare ce qui est écrit en deux ou trois langages : identifiant du
groupe, forme du chemin, AAD, table d'étiquettes, signature de l'ABI, et que
toute méthode appelée sur le pont **existe**. Vérifié en cassant trois valeurs.

C'est ce banc qui a rattrapé les deux défauts trouvés en écrivant :

- `preview_without_state` rend le **payload** (JSON : citation, mentions,
  identifiants), **pas un texte** — le Swift le posait tel quel dans la
  bannière, c'est-à-dire tout le contenu sur l'écran verrouillé ;
- une méthode du pont supprimée en même temps que son commentaire, alors que
  le service l'appelle.

**Aucun des deux ne se serait vu avant une première compilation.**

---

## 2. Ouvrir le drapeau au-delà d'un compte

*État : **à décider**. Dernier état vérifié le 2026-09-15 —
`featureFlags.mlsMessagesComptes` porte **un seul compte**.*

Le drapeau est **par compte**, pas global : `mlsMessagesComptes` est une liste
d'uid dans `app_config/settings` (Firestore). C'est ce qui permet d'éprouver
MLS en production sans l'imposer à personne.

**Ce que l'ouverture engage, et qu'on ne peut pas reprendre** : basculer une
conversation pose `mls_since`, et c'est **irréversible** — un trigger
(`conversations_garde_mls_since`) empêche le retour à NULL. Une conversation
basculée ne redevient jamais lisible en clair. Ouvrir le drapeau à un compte,
c'est accepter ça pour toutes ses conversations à venir.

**À faire avant d'ouvrir** : la passe appareil (chantier 4). Deux conversations
de production sont déjà **définitivement abîmées** — 8 messages illisibles pour
le second compte — par deux défauts qu'aucune relecture n'avait vus.

> ⚠️ **L'écriture du drapeau est refusée au classificateur de permissions.**
> C'est vous qui lancez la commande, pas moi.

---

## 3. Multi-appareil (phase 7)

*État : **à décider**. Le code de sécurité est fait ; l'écran de scan ne l'est
pas.*

**Ce qui est fait** (2026-09-15) : `MlsCodeSecurite` — empreinte d'un appareil,
code à 60 chiffres comparable de vive voix, charge QR et son analyseur, mémoire
locale des vérifications **avec détection du changement de clé**. Affiché sous
chaque ligne du registre MLS.

**La bonne nouvelle** : la décision n'a plus à être prise globalement.
`featureFlags.multiAppareilComptes` ouvre le multi-session **par compte**, même
motif que `mlsMessagesComptes`. On peut donc l'éprouver sur un compte de test
sans toucher à la posture de sécurité de qui que ce soit.

**Les deux choses à ne pas oublier avant d'ouvrir** :

- la session unique protège peut-être contre le **partage de comptes** —
  question produit, pas technique ;
- **`KeyTransferService` en dépend** : l'ancien téléphone dépose ses clés
  **avant** que le neuf ne se connecte, précisément parce que se connecter
  l'éjecterait. Lever la session unique change ce scénario.

**Reste à écrire** : l'écran de scan du code de sécurité.

---

## 4. Vérifications appareil — 43 cases ouvertes

*État : ouvert. **43 cases** dans les 8 entrées dont le titre porte « MLS »
(12 cochées). En comptant tout ce qui touche au chiffrement : **245 ouvertes**
sur 48 entrées.*

> *(Correction d'un chiffre donné à l'oral : j'avais dit « ~100 ». Le compte
> réel est 43 pour MLS au sens strict, 245 pour tout le chiffrement.)*

Tout est dans [TESTS_APPAREIL_A_FAIRE.md](TESTS_APPAREIL_A_FAIRE.md), domaines
« 4. Chiffrement » et « 6. Notifications ». Répartition :

| Cases | Entrée |
|---|---|
| 10 | Aperçu des notifications MLS reconstruit sur l'appareil (phase 4, Android) |
| 9 | Aperçu des notifications MLS sur iOS (chantier 1 ci-dessus) |
| 8 | Code de sécurité d'un appareil MLS (phase 7) |
| 4 | MLS ouvert pour un seul compte (phase 5) |
| 4 | L'appartenance MLS se réconcilie au moment du changement (phase 8) |
| 3 | Registre d'appareils MLS (phase 2) |
| 3 | L'état MLS ne quitte plus l'appareil (sauvegardes) |
| 2 | Banc MLS bout en bout contre la vraie base (phase 3) |

### Les trois qui comptent d'abord

Ce sont des correctifs **livrés mais jamais vus tourner**, et chacun corrige un
défaut qui était muet :

1. **« Supprimer pour tous » efface vraiment le contenu** (5 cases). Le
   ciphertext restait en base ; la fonction serveur le vide désormais
   (`ciphertext = '\x'`). Un « supprimé » qui ne supprime pas est le pire des
   défauts silencieux.
2. **`marquerMlsSince`** — *« Une conversation ne bascule plus sans ses
   participants »* (3 cases) et *« Ouvrir une discussion ne la bascule plus »*
   (3 cases). Deux défauts combinés : **lire** une conversation la basculait
   (prouvé par les horodatages), et elle basculait **sans l'appareil de
   l'autre**, en silence total. Les deux sont corrigés ; le dégât déjà fait
   n'est pas réparable.
3. **La vidéo entre dans le chiffrement** (4 cases). La vidéo était exclue
   faute de déchiffrement par morceaux. Elle ne l'est plus.

### Pourquoi cette passe passe avant tout le reste

Sept défauts réels ont été trouvés jusqu'ici en observant l'app qui tourne ou
la vraie base. **Zéro par lecture de code.** Le bandeau fantôme de non-lus, la
bascule sans participants, la lecture qui basculait, les réactions qui ne
s'effaçaient jamais, la suppression qui laissait le ciphertext, le
`marquerMlsSince` qui ne vérifiait pas, le plafond de 10 Mo sur les médias
chiffrés — tous trouvés sur appareil ou en base.

---

## 5. Clé maître du Keystore (§ 7.4)

*État : **bloqué**, avec trois obstacles mesurés le 2026-09-15. Ce n'est pas un
oubli — c'est une impasse documentée.*

**Ce dont il s'agit** : la base SQLite du moteur porte la **clé privée de
signature de l'appareil**, les secrets d'epoch et les arbres de groupe. Elle est
**en clair** sur le disque. Le plan la veut chiffrée sous une clé maître du
Keystore / Keychain.

**Les trois obstacles, à ne pas redécouvrir :**

1. **SQLCipher ne compile pas sur ce poste.** `openssl-sys` échoue : le `perl`
   de Git Bash ne convient pas au `Configure` d'OpenSSL pour `VC-WIN64A`, et
   `nasm` est absent. Il faudrait Strawberry Perl. Conséquence immédiate : le
   banc Rust de la phase 3 ne tournerait plus ici.
2. **Chiffrer les valeurs par le `Codec` casserait les lectures.** Dans
   `openmls_sqlite_storage`, les **clés de recherche** passent par le même
   `Codec::to_vec` que les entités et servent de **critère d'égalité en SQL**.
   Un AES-GCM à nonce aléatoire rendrait toute ligne introuvable. Il faudrait
   un chiffrement déterministe (AES-SIV), plus faible — et le `Codec` n'ayant
   que des méthodes **statiques**, la clé devrait vivre dans un global de
   processus.
3. **L'isolate de notification n'a pas de `MethodChannel`** sans liaison
   explicite, et doit pourtant rouvrir cette base. Il ne peut donc pas lire le
   Keystore comme l'app. **Chiffrer sans résoudre ce point casserait l'aperçu
   des notifications, déjà livré.**

**Ce qui a été fait à la place**, et qui ferme le chemin le plus réaliste : la
base **ne quitte plus l'appareil**. Android l'exclut de la sauvegarde Google et
du transfert d'appareil à appareil (deux fichiers de règles — Android 12 a
séparé les deux et ignore `fullBackupContent` dès l'API 31 ; n'en corriger
qu'un laisse la moitié du chemin ouverte). iOS pose
`NSURLIsExcludedFromBackupKey` à l'ouverture.

C'était le seul chemin d'exfiltration ne demandant ni root ni accès physique,
et il est fermé. Verrouillé par
`test/core/crypto/etat_mls_hors_sauvegarde_test.dart`.

> ⚠️ **Ne PAS déplacer la base vers `Library/Caches`** pour éviter le code
> natif : le système peut la vider quand il veut, et un état MLS effacé sans
> prévenir rend illisibles **toutes** les conversations basculées.

---

## 6. Démantèlement (phase 10)

*État : **différé par choix**. Le faire maintenant serait une faute, pas un
gain.*

**Ce que c'est** : supprimer l'ancien chiffrement une fois MLS partout —
`lib/core/services/e2ee/` (**9 481 lignes** au 2026-09-16 ; le plan en comptait
8 608 deux jours plus tôt, le dossier grossit encore), les 5 tables `e2ee_*`,
la fonction `crypto-keys`, `decrypt_aes_fallback`,
`EncryptionService._sharedKeyString`, `encAnnexes`.

**Les deux conditions, aucune remplie** :

1. **100 % du trafic en MLS pendant plusieurs semaines.** On en est loin : au
   comptage du 2026-09-15 consigné au § 9 du plan, 13 messages chiffrés contre
   122 en clair — et le drapeau n'est ouvert que pour un compte. *(À recompter
   avant toute décision : ce chiffre vieillit.)*
2. **La purge annoncée** des anciens messages (décision H du plan).

**Pourquoi c'est différé et non oublié** : tant qu'un seul message ancien
existe, retirer le lecteur legacy le rend illisible **pour toujours**. Le
démantèlement est la seule étape du plan qui ne se rattrape pas.

Et il dépend de la phase 6 (le gel), elle-même **bloquée par la publication** :
MLS est au versionCode 19, le Play Store en est au 18 après cinq refus. Tant
qu'aucun build portant MLS n'est publié, poser `VERSION_MINIMALE_APP` ne fait
rien, le délai de mise à jour ne peut pas commencer, et le gel reste hors de
portée. **La phase 6 est bloquée par la publication, pas par le code.**

Preuve de fin, le jour venu : `select count(*) from messages` = 0, puis
`drop table`.

---

## Où retrouver le détail

| Sujet | Fichier |
|---|---|
| Le plan complet, les 10 phases, les décisions | [CHIFFREMENT_MLS_PLAN.md](CHIFFREMENT_MLS_PLAN.md) |
| Les étapes Xcode et leurs risques | [ios/NotificationService/README.md](ios/NotificationService/README.md) |
| Toutes les cases de vérification | [TESTS_APPAREIL_A_FAIRE.md](TESTS_APPAREIL_A_FAIRE.md) |
| Le chiffrement des pièces jointes (C4) | [CHIFFREMENT_MEDIAS_PLAN.md](CHIFFREMENT_MEDIAS_PLAN.md) |
