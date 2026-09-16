# Extension de notification iOS — aperçu des messages MLS

## ⚠️ Rien de ce dossier n'a jamais été compilé

Ce poste n'a pas de Mac. Le Swift est écrit, relu et aligné sur le Dart et le
Rust par des tests qui lisent les fichiers — il n'est **ni compilé, ni signé,
ni exécuté**. Tant que les étapes Xcode ci-dessous ne sont pas faites, la
cible n'existe pas dans le projet et **rien de ce dossier n'entre dans une
build**. L'application, elle, fonctionne : elle ignore simplement ce dossier.

## Pourquoi une extension, alors qu'Android n'en a pas besoin

Le serveur ne connaît plus le texte des messages chiffrés : il n'envoie qu'un
repli générique et le ciphertext. L'aperçu est reconstruit sur l'appareil.

Sur Android, c'est un **isolate Dart** (`MlsNotificationPreview`) : il a le
pont Flutter Rust Bridge et partage le bac à sable de l'app. iOS n'offre pas
ça — une Notification Service Extension est un **binaire séparé**, sans moteur
Flutter, sans Dart, et avec **son propre bac à sable**. D'où les trois pièces
de ce dossier :

| Pièce | Rôle |
|---|---|
| `NotificationService.swift` | le point d'entrée iOS ; décide, et retombe toujours sur le contenu générique en cas de doute |
| `MlsPontNatif.swift` | le pont : chemin de la base, contexte partagé, AAD, appel du moteur, résumé |
| `NotificationService-Bridging-Header.h` | rend `diaspo_mls_apercu` (C) visible du Swift |
| `Info.plist` / `NotificationService.entitlements` | déclaration de l'extension et du groupe d'application |

Le moteur est appelé par une **ABI C** (`rust/src/ffi.rs`, `diaspo_mls_apercu`),
pas par le pont Dart. L'appelant fournit le tampon : rien n'est alloué côté
Rust qui devrait être libéré côté Swift.

## Ce qui a déjà été fait côté Dart, et qui est indispensable

Deux changements de l'application conditionnent tout le reste. Ils sont livrés
et ne coûtent rien tant que l'extension n'existe pas.

1. **La base du moteur a déménagé dans le conteneur du groupe**
   (`mls_chemin_base.dart`). Laissée dans `Application Support`, elle serait
   invisible pour l'extension — un autre processus, un autre bac à sable. Une
   base restée à l'ancien emplacement est **déplacée** au premier démarrage
   (déplacée, pas copiée : deux copies de l'état MLS, ce sont deux cliquets qui
   avancent séparément, donc une conversation illisible d'un côté).
2. **Le compte courant et l'identifiant d'appareil sont déposés dans les
   `UserDefaults` du groupe** (`mls_partage_extension_ios.dart`, écrit par
   `AppDelegate.deposerContexteMls`). Pas par `SharedPreferences` : le greffon
   Flutter préfixe toutes ses clés par `flutter.`, et une extension qui lit
   `"currentUserId"` ne trouverait rien — sans erreur et sans journal.

Et côté serveur : `send-push` pose `mutable-content: 1` sur les messages MLS
(`supabase/functions/send-push/index.ts`). **Sans ce drapeau, iOS n'invoque
jamais l'extension** — quoi qu'on fasse ici.

## Les étapes Xcode, qui demandent un Mac

Aucune ne peut être faite depuis ce dépôt. `project.pbxproj` n'est
**délibérément pas modifié à la main** : c'est un format à identifiants
générés, et une cible ajoutée à l'aveugle casse l'ouverture du projet sans que
rien ne dise pourquoi.

1. **Créer la cible.** File > New > Target > *Notification Service Extension*,
   nom `NotificationService`, langue Swift. Xcode génère un dossier : le
   **supprimer** (Move to Trash) et ajouter à la place les fichiers de ce
   dossier-ci, cible `NotificationService` cochée, cible `Runner` **décochée**.
2. **Bridging header.** Build Settings de la cible `NotificationService` >
   *Objective-C Bridging Header* =
   `NotificationService/NotificationService-Bridging-Header.h`.
3. **Lier le moteur Rust.** cargokit produit `libdiaspo_mls.a` dans
   `${BUILT_PRODUCTS_DIR}` (cf. `rust_builder/ios/diaspo_mls.podspec`), et
   seule la cible `Runner` la charge aujourd'hui. Ajouter à
   *Other Linker Flags* de la cible `NotificationService` :
   `-force_load ${BUILT_PRODUCTS_DIR}/libdiaspo_mls.a`, et une dépendance de
   build vers la cible du pod `diaspo_mls` pour que la phase de script ait
   tourné avant l'édition de liens.
4. **App Group, sur les deux cibles.** Signing & Capabilities > + Capability >
   *App Groups*, valeur `group.com.diasponiger.diasponiger` pour `Runner`
   **et** pour `NotificationService`. Puis activer la capability sur les deux
   App ID dans le portail développeur et **régénérer les profils de
   provisionnement** — sans ça la signature échoue.
5. **Identifiant de bundle.** Celui de l'extension doit être préfixé par celui
   de l'app : `com.diasponiger.diaspoNiger.NotificationService`.
6. **Version.** `CFBundleShortVersionString` et `CFBundleVersion` de
   l'extension doivent être **identiques** à ceux du Runner, sinon l'App Store
   refuse l'archive. Le `Info.plist` fourni utilise `$(FLUTTER_BUILD_NAME)` et
   `$(FLUTTER_BUILD_NUMBER)`, comme le Runner.

## Trois risques réels, non levés faute de machine

- **Mémoire.** Une NSE est coupée au-delà d'environ 24 Mo. OpenMLS ouvre une
  base SQLite et recopie l'état par `VACUUM INTO` : le coût n'a **jamais été
  mesuré**. Si le plafond est atteint, iOS tue l'extension et affiche le
  contenu générique du serveur — dégradé, pas cassé, mais à vérifier avant de
  compter dessus.
- **Édition de liens.** `-force_load` sur toute la bibliothèque tire aussi la
  glu Flutter Rust Bridge. Elle n'a pas besoin de la VM Dart au lien
  (`dart_api_dl` est résolu à l'exécution), mais ça reste à prouver sur la
  vraie chaîne.
- **Taille.** L'extension embarque sa propre copie du moteur : l'IPA grossit
  d'autant, à chiffrer sur une vraie archive.

## Ce qui garde l'ensemble cohérent sans Mac

Quatre valeurs sont écrites dans plusieurs langages et **doivent** rester
identiques ; aucune divergence ne produirait d'erreur, seulement un aperçu
générique sans explication. Elles sont comparées par
`test/core/crypto/mls_apercu_ios_parite_test.dart`, qui lit les fichiers
source :

- l'identifiant du groupe d'application (Dart, Swift, deux `.entitlements`) ;
- la forme du chemin de la base (`mls/<uid assaini>.sqlite`) ;
- la forme de l'AAD (`dn-mls/1|conv|msg|appareil|kind`) ;
- la table des étiquettes d'aperçu (« Photo », « Vidéo », …), écrite deux fois :
  `MlsNotificationPreview.resume` en Dart, `MlsPontNatif.resume` en Swift.

## Vérifier, le jour où un Mac est disponible

Dans l'ordre, parce que chaque étape suppose la précédente :

1. l'archive se construit et se signe (App Group provisionné) ;
2. un push MLS arrive avec `mutable-content: 1` — visible côté serveur ;
3. l'extension est bien invoquée (un `NSLog` au début de `didReceive` suffit) ;
4. `MlsPontNatif.cheminBase` désigne un fichier qui **existe** — c'est le point
   où tout se joue, et le symptôme d'un échec est l'aperçu générique ;
5. le texte affiché est le bon, et **pas** du JSON : voir `resume`.

Les entrées correspondantes sont dans `TESTS_APPAREIL_A_FAIRE.md`.
