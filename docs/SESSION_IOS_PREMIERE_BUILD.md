# iOS — de « jamais compilé » à une build release

Session du **2026-09-01**, sur macOS 27.0 / Apple Silicon, Xcode 27 beta 6.

La cible iOS existait dans le dépôt depuis le début mais **n'avait jamais été
compilée une seule fois**. Elle l'est désormais : `flutter build ios` aboutit
en debug simulateur comme en release appareil, l'app démarre, s'initialise
(Firebase, Supabase, chiffrement, CallKit) et l'écran de connexion s'affiche.

Ce document dit ce qui a été fait, ce qui a été vérifié, et — surtout — ce qui
ne l'a pas été.

---

## 1. Ce qui empêchait la compilation

Quatre défauts, tous préexistants, aucun visible sans tenter un build.

### `ios/Podfile` n'avait jamais existé

Absent de **tout** l'historique git (`git log --all -- ios/Podfile` : vide).
Sans lui, aucune dépendance native ne peut être résolue.

Créé avec `platform :ios, '15.0'` et les macros `permission_handler`
restreintes aux cinq permissions réellement demandées dans `lib/` : caméra,
micro, photos, notifications, localisation. Le paquet les compile **toutes**
par défaut, y compris celles dont l'`Info.plist` n'a pas la clé
correspondante — ce qui vaut un rejet App Store automatique.

### `project.pbxproj` corrompu

`GoogleService-Info.plist` figurait dans la phase *Resources* comme
`PBXFileReference`, sous un UUID inventé (`ABCDEF1234567890ABCDEF12`), là où
seul un `PBXBuildFile` est valide. CocoaPods refusait de s'exécuter dessus.

Conséquence de fond, indépendante du build : **le fichier de configuration
Firebase n'était pas correctement embarqué dans le bundle**. Corrigé par
l'ajout de l'entrée `PBXBuildFile` manquante ; vérifié après coup, le fichier
est bien présent dans `Runner.app/`.

### `NSPhotoLibraryUsageDescription` absent de l'`Info.plist`

Seule la variante d'écriture (`…AddUsageDescription`) était déclarée. iOS tue
le processus **au moment précis** où l'utilisateur ouvre le sélecteur de
photos — pas d'erreur de compilation, pas d'avertissement. Ajoutée, avec les
clés calendrier (`NSCalendars…`) qu'`add_2_calendar` réclame.

### Conflit `GoogleDataTransport`

`firebase_messaging` l'exige en `~> 10.0`, `mobile_scanner` 5.2.3 le voulait
en `< 10.0` via MLKit 6. Résolution CocoaPods impossible.

Résolu en montant `mobile_scanner` en 7.4.0 — **une** signature à adapter
(`errorBuilder` perd son troisième paramètre). Dans la foulée,
`purchases_flutter` 8 → 10.10.1 : RevenueCat 5.32.0 ne compile pas sous le
Swift d'Xcode 27, et `purchasePackage` devient `purchase(PurchaseParams)`.

### Cible de déploiement

Montée **iOS 12 → 15**. Ce n'est pas un choix : `google_maps_flutter_ios`
dépend de `GoogleMaps >= 8.4, < 10.0`, CocoaPods résout sur la 9.x qui exige
iOS 15. Les 36 plugins Flutter plafonnent eux à iOS 13 — c'est Maps qui fixe
le plancher.

---

## 2. Parité native Swift

`AppDelegate.swift` passe de 15 à 100 lignes, contre 230 pour
`MainActivity.java`. Les quatre canaux natifs d'Android ont été lus un par un ;
**deux seulement méritaient d'être portés**, et les deux autres sont
documentés comme volontairement absents — c'est la partie du travail qui
demandait le plus de discernement.

| Canal Android | Décision |
|---|---|
| `share_intent` / `getInstallationId` | **Porté** via `identifierForVendor` |
| Délégué `UNUserNotificationCenter` | **Ajouté** |
| `lockscreen` | **Non porté** — CallKit gouverne ça sur iOS |
| `deep_link` | **Non porté** — le porter ferait naviguer deux fois |

### Pourquoi `getInstallationId` comptait

Sans lui, `stableDeviceId` retombait sur un UUID aléatoire. Chaque
régénération de clés créait alors une **nouvelle** ligne dans `e2ee_devices`,
et comme tout message destiné au compte doit être chiffré pour *chaque*
appareil actif, les identités mortes s'accumulaient à la charge de l'envoi.
`identifierForVendor` a les mêmes propriétés que le SSAID Android : stable
entre réinstallations, cloisonné par éditeur. L'identifiant brut n'est jamais
transmis — le Dart en publie un condensé SHA-256 salé par le compte.

### Pourquoi `deep_link` ne devait PAS être porté

Côté Android, ce canal contourne un défaut réel : le moteur mis en cache
qu'impose `audio_service` empêche le canal de navigation de l'embedding
d'aboutir. Ce montage n'existe pas sur iOS.

**Vérifié, pas supposé** : `diasponiger:///auth/register` amène bien sur
l'écran de création de compte, et les journaux ne montrent **aucune** trace du
gestionnaire `_bindNativeDeepLinks`. La route est passée par le canal de
l'embedding. Ajouter le canal aurait donc produit une double navigation.

---

## 3. « Se connecter avec Apple »

Apple exige ce fournisseur de toute app proposant déjà un tiers — Google ici.
Son absence est un motif de rejet à la soumission.

Le bouton n'apparaît que sur iOS/macOS : sur Android, `sign_in_with_apple`
bascule sur un parcours web réclamant une configuration Service ID distincte,
absente aujourd'hui.

**Trois pièges propres à ce fournisseur**, tous traités et commentés sur place :

1. **Le nom n'est donné qu'à la première autorisation.** Apple ne renvoie
   `givenName`/`familyName` qu'une seule fois, jamais ensuite, et ne les met
   pas dans le jeton. Sans capture immédiate, le compte reste sans nom pour
   toujours — réinstallation comprise.
2. **Firebase rend une chaîne VIDE, pas `null`**, quand aucun nom n'est posé.
   Un simple `??` ne s'en saisit pas : on aurait écrasé le nom Apple par du
   vide, au seul instant où Apple accepte de le donner.
3. **Le nonce est haché à l'aller, brut au retour.** Apple reçoit le SHA-256,
   Firebase le nonce d'origine et vérifie la correspondance. Le même des deux
   côtés échoue en `invalid-credential`.

⚠️ **Point ouvert.** L'entitlement `com.apple.developer.applesignin` est posé,
mais la capability correspondante **n'est pas cochée sur l'App ID**. Deux
issues : la cocher, ou retirer la fonctionnalité et assumer le risque de rejet.
À trancher avant la première signature.

---

## 4. Pièges de poste de travail

Ces deux-là ont coûté du temps parce qu'ils ressemblent à des bugs de l'app.

### Sans fenêtre de simulateur, Flutter ne dessine rien

L'app se lance, la VM Dart répond, les journaux montrent l'initialisation
complète — et l'écran reste **gris uniforme**. Aucune erreur nulle part. Sans
scène visible, iOS ne fait jamais passer l'app au premier plan.

Xcode 27 n'a plus de `Simulator.app` : c'est **`DeviceHub.app`** qui porte la
fenêtre, et dans `Contents/Applications/`, non plus
`Contents/Developer/Applications/`.

```bash
open /Applications/Xcode-beta.app/Contents/Applications/DeviceHub.app
```

### `pod install` exige une locale UTF-8

```bash
export LANG=en_US.UTF-8
```

Sous Ruby 3.4, CocoaPods appelle `String#unicode_normalize` sur son chemin
d'installation ; avec une locale ASCII-8BIT, Ruby refuse et la commande meurt
sur une trace qui **ne mentionne jamais la locale**. `flutter build ios` n'est
pas concerné, il fixe l'encodage lui-même — le problème ne se voit qu'en
lançant `pod install` à la main.

### Contournement d'un Xcode hors `/Applications`

Tant que `xcode-select` ne pointe pas sur un Xcode complet :

```bash
export DEVELOPER_DIR=/Users/<vous>/Downloads/Xcode-beta.app/Contents/Developer
```

Suffit pour compiler. Ne suffit **pas** au panneau simulateur de Claude Code,
qui échoue à charger `SimulatorKit.framework` depuis une beta.

---

## 5. Ce qui a été vérifié, et comment

| Point | Preuve |
|---|---|
| Build debug simulateur | `✓ Built build/ios/iphonesimulator/Runner.app` |
| Build release appareil | `✓ Built build/ios/iphoneos/Runner.app` (162 Mo, non signé) |
| Écran de connexion | Capture sur iPhone 17 / iOS 26.1 |
| Init Supabase | `***** Supabase init completed *****` |
| Routage GoRouter | `/splash` → redirection `/auth/login` |
| Liens profonds `diasponiger://` | Arrivée effective sur `/auth/register` |
| App Tracking Transparency | Dialogue système affiché |
| `GoogleService-Info.plist` embarqué | Présent dans `Runner.app/` |
| `.env` embarqué | Présent dans `flutter_assets/` |
| `flutter analyze lib/` | Aucun problème |
| Tests auth, E2EE, architecture | Au vert |

### Ce qui n'a PAS été vérifié

- **Le parcours Apple complet** — la feuille système exige la capability sur
  l'App ID, donc un compte développeur.
- **Les notifications push** — App Check échoue en 403 « App attestation
  failed » sur simulateur. Le jeton de debug produit par l'app doit être
  déclaré dans *Firebase Console › App Check › Gérer les jetons de debug*.
  Il change à chaque réinstallation complète.
- **Les Universal Links** — `https://diasponiger.web.app/...` s'ouvre dans
  Safari, pas dans l'app. Normal : l'association de domaine exige une app
  signée. Rien à corriger côté code.
- **Tout ce qui demande un appareil réel** : caméra, micro, WebRTC, CallKit,
  localisation, achats RevenueCat après la montée 8 → 10.

---

## 6. Découvertes hors périmètre iOS

Trois choses trouvées en chemin, qui ne concernent pas iOS mais méritent d'être
regardées.

**Les Edge Functions Supabase répondent toutes 404.** Vérifié au curl :
`/auth/v1/settings` répond 200 et `/rest/v1/` répond 401 sans session
(conforme aux RLS), mais **toutes** les fonctions répondent 404, `gif-proxy`
comme `app-config`. L'app retombe proprement sur le `.env`, donc la
configuration distante n'est pas opérationnelle. Le proxy GIF, les tips, la
billetterie des salons et l'OTP téléphone en dépendent tous. À confirmer avec
`supabase functions list`.

**Le CLI Supabase installé via bun est corrompu** — signature invalide, macOS
le tue au démarrage (SIGKILL). Les `supabase db push` décrits dans le
`CLAUDE.md` échouaient donc forcément. Réinstallé via Homebrew ; l'ancien le
masque encore dans le `PATH` (`rm ~/.bun/bin/supabase` pour régler).

**Les canaux `gsm_state`, `pip` et `proximity` ne sont implémentés sur
AUCUNE plateforme**, alors que `proximity_service` et `pip_service` les
appellent explicitement sur iOS *et* Android. À trancher : implémenter ou
retirer.

---

## 7. État du compte Apple

Valeurs confirmées le 2026-09-01 :

| Champ | Valeur |
|---|---|
| Team ID | `3WM7VK48T3` |
| Bundle ID | `com.diasponiger.diaspoNiger` |
| Apple ID de l'app | `6807607258` |
| UGS | `diasponiger-ios-001` |
| Capabilities App ID | Push Notifications, Associated Domains |
| Clé APNs | `V2L2C994JJ` — Sandbox & Production, importée des deux côtés Firebase |
| Accès API ASC | approuvé, **aucune clé générée** |

Appliqué au dépôt : `DEVELOPMENT_TEAM = 3WM7VK48T3` sur les trois
configurations de `Runner`, `ITSAppUsesNonExemptEncryption` à `true`, et les
deux liens de magasin de `support_service.dart` corrigés — ils étaient
**tous deux morts** (`com.diasponiger.app` n'a jamais existé, `id123456789`
était inventé).

`ITSAppUsesNonExemptEncryption` à `true` est une **déclaration légale**, pas un
réglage : l'app chiffre de bout en bout, pas seulement via le TLS système.
Conséquence assumée, un CCATS ou un ERN sera réclamé avant publication.

---

## 8. Ce qui bloque encore la publication

1. **Capability « Sign In with Apple »** à cocher sur l'App ID — ou retirer la
   fonctionnalité.
2. **Clé API App Store Connect** — l'accès est approuvé mais aucune clé
   n'existe. Alternative sans échange de matériel de clé : ajouter le compte
   Apple dans *Xcode › Settings › Accounts* sur le Mac de build, ce qui permet
   à `xcodebuild -allowProvisioningUpdates` de signer sans qu'aucun `.p8` ne
   change de mains.
3. **Statut DSA** — en attente du code à 6 chiffres envoyé à l'adresse de
   support. Sans lui, pas de distribution dans l'Union européenne.
4. **Fiche App Store** — captures, description, Privacy Labels, compte de
   démonstration pour la revue.
