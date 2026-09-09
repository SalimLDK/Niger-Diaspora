# Build 1.2.1+16 — ce qui a été produit et vérifié

*2026-09-08. Branche `claude/publication-play`, arbre fusionné avec
`origin/wip-jules-2025-12-29T23-58-34-776Z` (`c5e6342`).*

## Artefacts

Le bundle n'est **pas versionné** (210 Mo) :

| Fichier | Taille | md5 |
|---|---|---|
| `build/app/outputs/bundle/release/app-release.aab` | 210,5 Mo | `6ad68fdc83597845e7852e1bd6e50da4` |

Construit après intégration de deux commits sans lesquels il ne faut **pas**
téléverser :

- `1985efc` — alignement 16 Ko, que Play contrôle ;
- `e1011d4` — **AGP 8.10.1 et Gradle 8.13**, montée rendue nécessaire par celle
  de `mobile_scanner` : sans elle la branche ne compilait plus. Un bundle
  produit avant ce commit vient d'un arbre qui ne construisait pas.

## Vérifié, pas supposé

Relevé dans `base/manifest/AndroidManifest.xml` du bundle lui-même (protobuf,
lu par étiquettes) — donc sur l'artefact téléversé, pas sur un APK voisin :

```
package           com.diasponiger.diasponiger
versionName       1.2.1
versionCode       16
minSdkVersion     24
targetSdkVersion  36
compileSdkVersion 36
```

Signature (`apksigner` sur l'APK, `keytool -printcert -jarfile` sur l'AAB) :

```
CN=Diaspo Niger, OU=Mobile, O=Diaspo Niger, L=Niamey, ST=Niamey, C=NE
SHA-256 : DD:A6:5C:3E:BC:08:BD:67:4F:FA:37:26:40:5C:4C:B7:5B:25:3E:DE:55:85:BB:E2:22:DA:34:20:51:94:CF:5D
```

Identique à l'empreinte du keystore `android/app/diaspo-niger-release.jks`
(alias `diaspo-niger`), valide jusqu'au 12/05/2053.

## ⚠️ À vérifier avant de téléverser : est-ce la bonne clé ?

Le dépôt contient **deux** keystores, et la documentation en désigne un autre
que la configuration de build :

| Fichier | Alias | Désigné par | Ouvrable avec le mot de passe de `key.properties` |
|---|---|---|---|
| `android/app/diaspo-niger-release.jks` | `diaspo-niger` | `android/key.properties` — **c'est celui qui signe** | oui |
| `android/upload-keystore.jks` | `upload` | `docs/deploiement/DEPLOYMENT.md` §2 | **non** — mot de passe différent |

Si un bundle a déjà été téléversé signé avec `upload-keystore.jks`, Play
refusera celui-ci : « Your Android App Bundle is signed with the wrong key ».
Le refus est propre et sans dégât, mais il fait perdre un aller-retour.

**Contrôle, 30 secondes :** Play Console → l'app → *Intégrité de l'application*
→ *Signature de l'application* → comparer l'empreinte SHA-256 de la **clé de
téléversement** avec `DD:A6:5C:3E…` ci-dessus. Si elle diffère, c'est
`upload-keystore.jks` qu'il faut, et son mot de passe est à retrouver.

`docs/deploiement/DEPLOYMENT.md` §2 décrit encore `upload-keystore.jks` /
alias `upload` / `storeFile=../upload-keystore.jks`, ce qui ne correspond pas
au `key.properties` réel. À corriger une fois la bonne clé identifiée — la
documentation ne doit pas désigner une clé qui ne signe rien.



## Pourquoi 15, et pas 11

L'explorateur de bundles de la console (relevé le 2026-09-09) donne l'historique
réel des téléversements :

| Code | Nom | Importé | État |
|---|---|---|---|
| 14 | 1.2.0 | 25 juin 2026 | Inactif |
| 13 | 1.2.0 | 1 juin 2026 | Inactif |
| 12 | 1.2.0 | 10 mars 2026 | Inactif |
| 11 | 1.2.0 | 10 mars 2026 | Inactif |
| 9 | 1.1.1 | 31 déc. 2025 | **Actif** (production) |
| 8 | 1.1.0 | 31 déc. 2025 | Actif |

Le **11 était déjà pris** : un bundle signé sur ce code aurait été rejeté à
l'import. Le plus haut étant 14, on passe à **15**.

Ce tableau corrige aussi une note du dépôt : `releases/1.2.0+14/` n'est **pas**
un nom de dossier erroné hérité d'une renumérotation oubliée — la version 14
existe bel et bien. `docs/ops/PUBLICATION_IOS.md` §6 affirme le contraire ; à
corriger.

Et surtout : les quatre bundles 11 à 14 sont **tous inactifs**. Aucun n'a
jamais atteint la production. La cause est ci-dessous.

## ⚠️ `USE_FULL_SCREEN_INTENT` — la vraie raison du blocage

Le centre de conformité porte un refus daté du **11 mars 2026** :

> Politique relative à l'autorisation d'afficher les intentions en plein écran :
> l'utilisation des autorisations n'est pas directement liée à l'objectif
> principal de votre appli.

La permission n'est pas déclarée par l'app : elle est **fusionnée depuis
`flutter_callkit_incoming` 2.5.8**. Le manifeste la mentionnait en commentaire
depuis longtemps, sans jamais la retirer — d'où quatre bundles refusés d'affilée
sans que la cause soit rattachée au bon endroit.

La consigne de Google est explicite et ne laisse pas d'alternative : *retirer
l'autorisation de tous les codes de version de la soumission, sous-ensembles de
test compris*. Elle est donc neutralisée par `tools:node="remove"` dans
`android/app/src/main/AndroidManifest.xml`, et vérifiée absente du bundle
produit.

**Ce que ça coûte :** un appel entrant n'ouvre plus d'écran plein sur un
téléphone verrouillé ; il arrive en notification prioritaire. Android dégrade
seul, sans plantage ni erreur à traiter. Ne pas rétablir sans accord écrit de
Google.


## ⚠️ `FOREGROUND_SERVICE_MEDIA_PLAYBACK` — retirée aussi (2026-09-09)

L'écran « Prévisualiser et confirmer » refusait d'enregistrer la release tant
que la déclaration « Autorisations pour le service de premier plan » était
incomplète. Localisation et VoIP y étaient déjà renseignées avec leur vidéo de
démonstration ; il manquait la lecture multimédia.

Or cocher « Lecture de contenus multimédias » réclame **une vidéo montrant la
fonctionnalité** — et le seul consommateur du service est le lecteur de
podcasts (`PodcastAudioHandler` via `AudioService.init`), commenté dans
`home_screen_widgets.dart`. Fonctionnalité injoignable donc infilmable : la
déclaration ne pouvait pas être remplie honnêtement.

Retirée du manifeste. Rien de livré n'en dépend : les messages vocaux passent par
`just_audio` en direct (`audio_message_bubble.dart`). À rétablir avec les
podcasts, vidéo à l'appui.

## Ce qui a été envoyé pour examen le 2026-09-09

| Élément | Description |
|---|---|
| Production | **16 (1.2.1)** — lancer le déploiement complet |
| Pays/Régions | Ajouter 176 pays/régions, puis le reste du monde |
| Contenu de l'application | Déclaration d'intent plein écran |

Plus, pris en compte à l'examen sans être publiés : les déclarations « Services
de premier plan » et « Autorisations liées aux photos et vidéos ».

**Deux avertissements acceptés**, non bloquants :

- **1 137 appareils perdus** par rapport à la version précédente (sur 19 117).
  Le bundle passe de 4 ABI à 3. Ces appareils ne recevront plus de mise à jour
  et l'app n'y sera plus installable — à vérifier si c'est voulu.
- Forte augmentation de la taille téléchargée, attendue depuis la 1.1.1.

## ✅ La clé de signature est la bonne — vérifié

Doute levé le 2026-09-09 dans la console (Protégé avec Play → Signature
d'application). L'empreinte SHA-256 du **certificat de clé d'importation**
attendu par Play est :

```
DD:A6:5C:3E:BC:08:BD:67:4F:FA:37:26:40:5C:4C:B7:5B:25:3E:DE:55:85:BB:E2:22:DA:34:20:51:94:CF:5D
```

Identique à celle de `android/app/diaspo-niger-release.jks`. **C'est donc bien
`key.properties` qui a raison**, et `docs/deploiement/DEPLOYMENT.md` §6 qui
désigne une clé (`upload-keystore.jks`, alias `upload`) ne servant à rien.

## Alignement 16 Ko — contrôlé

`tools/verifie_alignement_16k.py` (livré par `1985efc`) sur l'AAB produit :

```
16 bibliotheque(s) 64 bits examinee(s), 0 non conforme(s)
```

Toutes à 16 ou 64 Ko, sur `arm64-v8a` et `x86_64`. À rejouer après toute mise
à jour de plugin embarquant des `.so` préconstruites : c'est là que
l'alignement se perd, sans avertissement au build.

## Deux pièges rencontrés en produisant ce build

**1. `BUNDLE-METADATA` gonfle l'AAB sans compter pour Play.** Les 208 Mo
alarment à tort : 112 Mo de symboles natifs (`debugSymbolLevel = FULL`) et
11 Mo de mapping R8 vivent dans `BUNDLE-METADATA/`, que Google n'empaquette
pas dans les APK livrés. Le contenu réel fait ~84 Mo répartis sur trois ABI,
dont un appareil ne reçoit qu'une. La limite Play porte sur la **taille
téléchargée compressée** du module de base — 500 Mo. Rien à réduire.

**2. Interrompre un build corrompt `build/` en silence.** Voir
`TESTS_APPAREIL_A_FAIRE.md` et la mémoire projet : un build tué laisse des
fichiers à la bonne taille remplis de `\0` (708 mesurés ici). Le build suivant
échoue sur `mergeReleaseResources` avec « Content is not allowed in prolog »,
qui ne désigne pas la cause. Après toute interruption : `rm -rf build` **avant**
de relancer — un `flutter clean` passé *avant* l'interruption ne protège de
rien.

## Commande de reproduction

```bash
flutter build appbundle --release --dart-define=PRODUCTION=true
```

`STRIPE_PUBLISHABLE_KEY` n'est **pas** passé en `--dart-define` : la clé se
résout via la configuration distante `app-config`, et figer un gabarit
`pk_live_…` dans le binaire produirait une valeur morte non modifiable sans
republier.
