# Publication iOS — état réel et marche à suivre

État constaté **le 2026-09-01**, en lisant directement le compte Apple
(developer.apple.com + App Store Connect), pas en supposant.

Résumé : le compte existe et le contrat gratuit est actif, mais **rien n'a
jamais été créé côté Apple**. Ce n'est pas une collecte d'informations qui
manque, c'est un chantier à démarrer.

---

## 1. Valeurs du compte — à recopier telles quelles

| Champ | Valeur |
|---|---|
| Team ID | `3WM7VK48T3` |
| Nom / entité | Salim Laouali Dan Kobo |
| Type d'inscription | **Personne physique** (pas une organisation) |
| Programme | Apple Developer Program |
| Renouvellement | 8 janvier 2027 — C$119 |
| Adresse | 10455 Avenue Oscar, Montréal-Nord, QC H1H 5J6, Canada |
| Téléphone | 1-514-970-3811 |
| N° de compte ASC | 93923218 — 175 pays/régions |
| Bundle ID (dépôt) | `com.diasponiger.diaspoNiger` |

« Personne physique » a une conséquence visible : **le nom vendeur affiché
sur l'App Store sera le nom civil**, pas « Diaspo Niger ». Basculer en
organisation exige un numéro D-U-N-S et prend des semaines — à décider
maintenant, pas après la première publication.

## 2. Ce qui est vide

| Ressource | État au 2026-09-01 |
|---|---|
| Apps dans App Store Connect | **aucune** |
| Identifiers (App IDs) | **aucun** — `com.diasponiger.diaspoNiger` n'existe pas chez Apple |
| Keys (clés APNs) | **aucune** |
| Certificates | **aucun** |
| Accès API App Store Connect | **non accordé** (bouton « Demander l'accès ») |
| Contrat applications gratuites | ✅ actif, 1 sept. 2026 → 7 janv. 2027 |
| Contrat applications payantes | ❌ « Nouveau » — non signé |
| Statut de commerçant (DSA) | ❌ non fourni |
| Carte bancaire sur le compte | ❌ aucune |

---

## 3. Marche à suivre, dans l'ordre

L'ordre compte : chaque étape dépend de la précédente. Aucune ne peut être
faite par un agent — ce sont des créations de compte, des réglages et des
déclarations légales.

### Étape 1 — Carte bancaire sur le compte développeur

developer.apple.com → Compte → « Ajouter une carte ».

À faire en premier parce que c'est le seul point qui a une **échéance
externe** : sans carte, le renouvellement du 8 janvier 2027 échoue, et à
l'expiration les apps publiées sortent de l'App Store. Ça ne bloque rien
aujourd'hui, et c'est précisément pour ça que ça s'oublie.

### Étape 2 — Statut de commerçant (DSA)

App Store Connect → Business → bandeau rouge → « Compléter les exigences de
conformité ».

Sans ça, **pas de distribution dans l'Union européenne**. Pour une app de
diaspora nigérienne, la France, la Belgique et l'Italie sont une part
importante de la cible : c'est un blocage de fond, pas une formalité.
Les coordonnées saisies ici sont **publiées sur la fiche App Store** — en
personne physique, ce sera l'adresse personnelle. À regarder avant de la
saisir.

### Étape 3 — App ID

developer.apple.com → Certificates, Identifiers & Profiles → Identifiers →
« Register an App ID » → App IDs → App.

- Description : `Diaspo Niger`
- Bundle ID : **Explicit** → `com.diasponiger.diaspoNiger`

Capabilities à cocher — la liste vient de ce que le dépôt déclare déjà, pas
d'une supposition :

| Capability | Pourquoi | Source dans le dépôt |
|---|---|---|
| **Push Notifications** | sinon `getAPNSToken()` renvoie nil et aucun token FCM n'est enregistré | `ios/Runner/Runner.entitlements` (`aps-environment`) |
| **Associated Domains** | liens profonds `applinks:diasponiger.web.app` et `applinks:diasponiger.com` | `ios/Runner/Runner.entitlements` |
| **Sign In with Apple** | uniquement si la connexion Apple est proposée dans l'app | à confirmer côté `lib/features/auth` |

Ne rien cocher d'autre. Une capability activée mais non utilisée fait
échouer la revue Apple si l'app n'en montre pas l'usage.

**Apple Pay et App Group ne sont pas concernés** : aucune trace de
`merchant.` dans le projet, et l'app n'a qu'une seule cible (`Runner`) — pas
de Share Extension. Ces deux lignes tombent tant que ça n'existe pas.

### Étape 4 — Clé APNs

Certificates, Identifiers & Profiles → Keys → « Create a key ».

- Nom : `Diaspo Niger APNs`
- Cocher **Apple Push Notifications service (APNs)**

⚠️ **Le fichier `AuthKey_XXXXXXXXXX.p8` ne se télécharge qu'une seule fois.**
Perdu, il faut révoquer la clé et recommencer. Le stocker hors du dépôt
(`android/key.properties` et `*.jks` sont déjà gitignorés ; le `.p8` ne doit
pas non plus y entrer).

Ensuite, Firebase Console → Paramètres du projet → Cloud Messaging →
Configuration iOS → téléverser le `.p8` avec :
- **Key ID** : les 10 caractères du nom de fichier
- **Team ID** : `3WM7VK48T3`

Sans ce téléversement, la chaîne push documentée dans
`project_push_pipeline` s'arrête à la frontière iOS, en silence.

### Étape 5 — Accès API App Store Connect (facultatif mais recommandé)

App Store Connect → Utilisateurs et accès → Intégrations → API App Store
Connect → **« Demander l'accès »**.

Une fois accordé, générer une clé de rôle **App Manager**. Ça donne
l'Issuer ID (UUID) et un second `.p8` — également téléchargeable une seule
fois. C'est ce qui permet ensuite d'automatiser les téléversements
(`fastlane`, CI) au lieu de tout faire à la main dans Xcode.

### Étape 6 — Fiche de l'app

App Store Connect → Apps → « Ajouter des apps ». Demandera :
plateformes (iOS + iPadOS — le projet déclare le support iPad), nom,
langue principale, bundle ID (celui de l'étape 3), SKU.

Les éléments de la fiche que **seul toi peux produire** :
nom affiché (30 car.), sous-titre (30 car.), mots-clés (100 car.),
description, nouveautés, catégories, URL de politique de confidentialité,
URL d'assistance, coordonnées de contact revue, classification d'âge.

Attention : le dépôt référence déjà `diasponiger.com/privacy` et
`diasponiger.com/terms` comme valeurs par défaut dans
`lib/features/admin/data/models/app_settings_model.dart`. **Vérifier que ces
deux URL répondent réellement** avant de les déclarer — une URL de
confidentialité morte est un motif de rejet classique.

### Étape 7 — Compte de démonstration pour la revue

Apple a besoin d'un compte fonctionnel. Créer un **compte jetable dédié**,
jamais un compte réel : les identifiants transitent dans App Store Connect
et restent visibles aux relecteurs.

Notes de revue à prévoir, parce que trois fonctions de l'app ne sont pas
auto-explicables : comment déclencher un appel (il faut deux comptes),
comment atteindre la messagerie chiffrée, et le fait que les paiements
Stripe sont en gabarit (voir `project_env_three_files_apk_leak`).

### Étape 8 — Confidentialité et export

- **Privacy Nutrition Labels** : l'app utilise AdMob et demande l'ATT
  (`NSUserTrackingUsageDescription` présent dans `Info.plist`). Le suivi
  publicitaire doit être déclaré, sinon rejet.
- **Conformité export** : `ITSAppUsesNonExemptEncryption` est désormais
  présent dans `Info.plist`, à `<true/>` — voir §4.

### Étape 9 — Contrat applications payantes (seulement si abonnements)

RevenueCat est câblé dans l'app (`lib/core/services/revenue_cat_service.dart`).
Tant que le contrat « applications payantes » reste à l'état « Nouveau »,
**aucun abonnement ne peut exister**, et App Store Connect n'affichera même
pas la section achats intégrés.

Il faut, dans l'ordre : mettre à jour l'entité juridique (App Store Connect
le réclame explicitement sur la page Contrats), signer le contrat, puis
renseigner coordonnées bancaires et fiscales.

À noter : les identifiants de produits ne sont **pas dans le dépôt** — le
code lit les *offerings* distants de RevenueCat. La liste des produits à
déclarer devra venir du tableau de bord RevenueCat.

---

## 4. Le point de conformité export — décision à valider

`ios/Runner/Info.plist` déclare maintenant :

```xml
<key>ITSAppUsesNonExemptEncryption</key>
<true/>
```

**Ce n'est pas un réglage technique, c'est une déclaration légale**, et la
valeur retenue est un choix conservateur, pas une certitude :

- L'app fait du chiffrement de bout en bout (protocole Signal), pas
  seulement du TLS système. La lecture honnête est donc « chiffrement non
  exempté » → `true`.
- Conséquence : App Store Connect réclamera un CCATS ou un numéro
  d'auto-classification (ERN) déposé auprès du BIS américain.
- `false` ferait passer les téléversements sans question, mais serait une
  fausse déclaration si l'exemption n'est pas réellement établie.

Sur-déclarer coûte de la paperasse ; sous-déclarer est une fausse
déclaration à un régulateur. D'où `true`. **À faire valider** — et à basculer
à `false` seulement si l'exemption est formellement confirmée.

---

## 5. Ce qui a été corrigé dans le dépôt

- `ios/Runner.xcodeproj/project.pbxproj` : `DEVELOPMENT_TEAM = 3WM7VK48T3`
  ajouté sur les trois configurations de la cible `Runner` (Debug, Release,
  Profile). Sans ça, la signature automatique n'a pas d'équipe à utiliser.
- `ios/Runner/Info.plist` : `ITSAppUsesNonExemptEncryption` ajouté (§4).

**Aucune de ces deux modifications n'a pu être compilée** : le poste de
travail est sous Windows, un build iOS exige macOS + Xcode. Elles sont
correctes à la lecture (le plist est validé par `plistlib`, l'insertion
pbxproj suit la syntaxe existante), mais non prouvées.

## 6. Faux problème écarté

`releases/1.2.0+14/` porte `+14` dans son nom, mais son contenu dit
« Code de version: 10 » et « Version application: 1.2.0+10 » — ce qui
correspond exactement à `pubspec.yaml`. **Il n'y a pas d'écart de version** :
c'est le nom du dossier qui est faux, hérité d'une release préparée le
2026-01-01 et jamais renumérotée. Rien à corriger dans le code.

Pour un premier téléversement iOS, `1.2.0+10` convient : le numéro de build
doit seulement être unique et croissant **par rapport aux téléversements
précédents**, et il n'y en a aucun.
