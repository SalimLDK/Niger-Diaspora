# Publication iOS — état réel et marche à suivre

État constaté **le 2026-09-01**, en lisant directement le compte Apple
(developer.apple.com + App Store Connect), pas en supposant.

Résumé : le compte existe et le contrat gratuit est actif. **Les étapes 3 et
6 (App ID et fiche App Store Connect) ont été faites le 2026-09-01** ; tout
le reste attend, et les points bloquants relèvent de décisions ou de secrets
qui ne peuvent pas être délégués.

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
| Bundle ID | `com.diasponiger.diaspoNiger` |
| **Apple ID de l'app** | `6807607258` |
| UGS (SKU) | `diasponiger-ios-001` |

« Personne physique » a une conséquence visible : **le nom vendeur affiché
sur l'App Store sera le nom civil**, pas « Diaspo Niger ». Basculer en
organisation exige un numéro D-U-N-S et prend des semaines — à décider
maintenant, pas après la première publication.

## 2. Ce qui est vide

| Ressource | État (mis à jour 2026-09-01, après création) |
|---|---|
| Apps dans App Store Connect | ✅ « Diaspo Niger », iOS 1.0, à finaliser |
| Identifiers (App IDs) | ✅ créé, Push + Associated Domains |
| Keys (clés APNs) | ✅ `V2L2C994JJ` — `Sandbox & Production`, Team Scoped, importée dans les deux emplacements Firebase |
| Certificates | **aucun** |
| Accès API App Store Connect | ✅ **clé `M5WX9RLU5D` créée** le 2026-09-01 — `.p8` rangé hors dépôt |
| Contrat applications gratuites | ✅ actif, 1 sept. 2026 → 7 janv. 2027 |
| Contrat applications payantes | ❌ « Nouveau » — non signé |
| Statut de commerçant (DSA) | ❌ non fourni |
| Carte bancaire sur le compte | ❌ aucune |

---

## 3. Marche à suivre, dans l'ordre

L'ordre compte : chaque étape dépend de la précédente. Aucune ne peut être
faite par un agent — ce sont des créations de compte, des réglages et des
déclarations légales.

### ⬜ Étape 1 — Carte bancaire sur le compte développeur

developer.apple.com → Compte → « Ajouter une carte ».

À faire en premier parce que c'est le seul point qui a une **échéance
externe** : sans carte, le renouvellement du 8 janvier 2027 échoue, et à
l'expiration les apps publiées sortent de l'App Store. Ça ne bloque rien
aujourd'hui, et c'est précisément pour ça que ça s'oublie.

### ⬜ Étape 2 — Statut de commerçant (DSA)

App Store Connect → Business → bandeau rouge → « Compléter les exigences de
conformité ».

Sans ça, **pas de distribution dans l'Union européenne**. Pour une app de
diaspora nigérienne, la France, la Belgique et l'Italie sont une part
importante de la cible : c'est un blocage de fond, pas une formalité.
Les coordonnées saisies ici sont **publiées sur la fiche App Store** — en
personne physique, ce sera l'adresse personnelle. À regarder avant de la
saisir.

### ✅ Étape 3 — App ID (faite le 2026-09-01)

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
| ~~Sign In with Apple~~ | **vérifié : non utilisé**, donc non coché — aucun paquet `sign_in_with_apple`, le seul `apple.com` du code était une URL App Store en dur | — |

Ne rien cocher d'autre. Une capability activée mais non utilisée fait
échouer la revue Apple si l'app n'en montre pas l'usage.

**Apple Pay et App Group ne sont pas concernés** : aucune trace de
`merchant.` dans le projet, et l'app n'a qu'une seule cible (`Runner`) — pas
de Share Extension. Ces deux lignes tombent tant que ça n'existe pas.

### ✅ Étape 4 — Clé APNs (faite le 2026-09-01, des deux côtés)

Certificates, Identifiers & Profiles → Keys → « Create a key », cocher
**Apple Push Notifications service (APNs)**.

**Deux pièges, tous deux définitifs.**

**1. L'environnement par défaut est `Sandbox`, et il n'est pas modifiable
après enregistrement.** Cocher APNs fait apparaître un bouton *Configure*
et l'avertissement « The APNs configuration for accessible environment and
key restriction type can't be changed once saved ». Laissé sur `Sandbox`,
tout marche en debug et **rien ne part sur une build App Store ou
TestFlight** — sans la moindre erreur. Mettre **`Sandbox & Production`**.

Apple recommande à cet endroit d'utiliser des clés distinctes par
environnement. Ça vaut pour une équipe avec des workflows séparés ; ici
Firebase n'accepte qu'un projet, donc une clé combinée est le bon choix.

**2. `Key Restriction` doit rester `Team Scoped (All Topics)`** : la clé
sert alors tous les bundle IDs de l'équipe et survit à l'ajout d'une
extension. `Topic Specific` la fige sur une liste de topics.

Autre détail : le champ **Key Name refuse les caractères spéciaux, tiret
compris** — `Diaspo Niger APNs` passe, `diaspo-niger-apns` non.

⚠️ **Le fichier `AuthKey_XXXXXXXXXX.p8` ne se télécharge qu'une seule fois.**
Perdu, il faut révoquer la clé et recommencer. Le stocker hors du dépôt
(`android/key.properties` et `*.jks` sont déjà gitignorés ; le `.p8` ne doit
pas non plus y entrer).

**Côté Firebase** — Console → Paramètres du projet → Cloud Messaging →
Configuration de l'application Apple. La section « Clé d'authentification
APNs » a **deux emplacements distincts, développement et production**. Avec
une clé `Sandbox & Production`, **le même fichier va dans les deux**, sinon
un des deux environnements reste muet. Chaque import demande :

- le fichier `.p8`
- **ID de clé** : les 10 caractères du nom de fichier
- **ID d'équipe** : `3WM7VK48T3`

**État au 2026-09-01, vérifié dans la console** : projet `diaspo-niger`,
app `com.diasponiger.diaspoNiger`, FCM V1 actif, et les **deux** lignes
renseignées avec `V2L2C994JJ` / `3WM7VK48T3` :

| Emplacement Firebase | ID de clé | ID d'équipe |
|---|---|---|
| APNs développement | `V2L2C994JJ` | `3WM7VK48T3` |
| APNs production | `V2L2C994JJ` | `3WM7VK48T3` |

⚠️ **Configuré n'est pas vérifié.** Aucune notification n'a jamais traversé
cette chaîne : il n'existe aucune build iOS, et aucun appareil iOS n'est
disponible. Ce qui est établi, c'est que la configuration est complète et
cohérente des deux côtés — pas qu'une notification arrive. La preuve
attendra une build sur un vrai iPhone.

### ◐ Étape 5 — Clé API App Store Connect (créée le 2026-09-01, Issuer ID à relever)

**L'accès a été demandé et approuvé le 2026-09-01.** L'approbation a été
immédiate : la mention « les organisations recevront leur accès avant les
utilisateurs individuels » n'a rien retardé ici, alors que le compte est en
personne physique.

**La clé a été générée dans la foulée : `M5WX9RLU5D`.** Son `.p8` est rangé
hors du dépôt, avec celui d'APNs, dans `~/.secrets/apple/` — il ne se
télécharge qu'une fois, et le périmètre d'une clé est **figé à la
création** : elle ne peut pas être élargie après coup à d'autres services.

**Ce qui manque encore pour s'en servir : l'Issuer ID.** C'est un UUID, et
il n'apparaît sur la page qu'**une fois la première clé créée** — donc
maintenant, et pas avant. Le relever sur App Store Connect → Utilisateurs et
accès → Intégrations → API App Store Connect, en tête de la liste des clés,
et le consigner en section 1. Le `.p8` seul ne signe aucune requête : le JWT
d'App Store Connect porte le Key ID **et** l'Issuer ID, les deux vont par
paire.

L'engagement accepté au moment de la demande limite l'usage de l'API au
développement, aux tests et aux rapports internes : interdiction de fournir
des services à des tiers, et de partager les identifiants d'autorisation
hors de l'équipe.

### ✅ Étape 6 — Fiche de l'app (créée le 2026-09-01)

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

### ⬜ Étape 7 — Compte de démonstration pour la revue

Apple a besoin d'un compte fonctionnel. Créer un **compte jetable dédié**,
jamais un compte réel : les identifiants transitent dans App Store Connect
et restent visibles aux relecteurs.

Notes de revue à prévoir, parce que trois fonctions de l'app ne sont pas
auto-explicables : comment déclencher un appel (il faut deux comptes),
comment atteindre la messagerie chiffrée, et le fait que les paiements
Stripe sont en gabarit (voir `project_env_three_files_apk_leak`).

### ⬜ Étape 8 — Confidentialité et export

- **Privacy Nutrition Labels** : l'app utilise AdMob et demande l'ATT
  (`NSUserTrackingUsageDescription` présent dans `Info.plist`). Le suivi
  publicitaire doit être déclaré, sinon rejet.
- **Conformité export** : `ITSAppUsesNonExemptEncryption` est désormais
  présent dans `Info.plist`, à `<true/>` — voir §4.

### ⬜ Étape 9 — Contrat applications payantes (seulement si abonnements)

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

---

## 7. Ce qui a réellement été créé le 2026-09-01

| Élément | Valeur |
|---|---|
| App ID | `com.diasponiger.diaspoNiger` (explicit), préfixe `3WM7VK48T3` |
| Capabilities cochées | Push Notifications, Associated Domains — **rien d'autre** |
| Fiche App Store Connect | « Diaspo Niger », iOS, français (fr-FR), accès complet |
| Apple ID de l'app | `6807607258` |
| UGS | `diasponiger-ios-001` |
| Clé API App Store Connect | `M5WX9RLU5D` — `.p8` hors dépôt, Issuer ID pas encore relevé |

Conséquence directe dans le code : `lib/core/services/support_service.dart`
pointait sur `id123456789`, un identifiant inventé. Corrigé avec le vrai.
Le lien Play Store de la même paire de constantes était faux aussi
(`com.diasponiger.app` alors que l'`applicationId` réel est
`com.diasponiger.diasponiger`) — corrigé dans la foulée.

## 8. Ce qui n'a pas été fait, et pourquoi

| Étape | Raison |
|---|---|
| Carte bancaire (étape 1) | saisie de coordonnées bancaires — jamais délégable |
| Clé APNs (étape 4) | le `.p8` ne se télécharge **qu'une fois** ; un secret à usage unique se génère et se range soi-même |
| Clé API ASC (étape 5) | idem — créée par toi le 2026-09-01 (`M5WX9RLU5D`), le `.p8` étant un secret à usage unique |
| Statut DSA (étape 2) | saisie de données personnelles qui seront **publiées** sur la fiche App Store |
| Contrat payantes (étape 9) | signature d'un accord juridique |

Ces quatre-là ne sont pas des oublis : ce sont les seuls points de la liste
qui engagent de l'argent, un secret, une donnée personnelle publiée ou une
signature.
