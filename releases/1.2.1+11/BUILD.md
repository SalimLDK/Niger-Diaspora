# Build 1.2.1+11 — ce qui a été produit et vérifié

*2026-09-08. Branche `claude/publication-play`, arbre fusionné avec
`origin/wip-jules-2025-12-29T23-58-34-776Z` (`961d188`).*

## Artefacts

Les deux binaires ne sont **pas versionnés** (207 Mo et 167 Mo) :

| Fichier | Taille | md5 | Usage |
|---|---|---|---|
| `build/app/outputs/bundle/release/app-release.aab` | 208,1 Mo | `ad8684c7a3489945fd28d0d28292598b` | **à téléverser sur Play** |
| `build/app/outputs/flutter-apk/app-release.apk` | 168,7 Mo | — | distribution directe / test |

Construits après intégration de `1985efc` (alignement 16 Ko) : un binaire
antérieur à ce commit ne porte pas l'alignement que Play contrôle.

## Vérifié, pas supposé

Relevé avec `aapt2 dump badging` sur l'APK produit :

```
package: name='com.diasponiger.diasponiger' versionCode='11' versionName='1.2.1'
targetSdkVersion:'36'   compileSdkVersion='36'
application-label:'Diaspo Niger'
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


## Alignement 16 Ko — contrôlé

`tools/verifie_alignement_16k.py` (livré par `1985efc`) sur l'AAB produit :

```
16 bibliotheque(s) 64 bits examinee(s), 0 non conforme(s)
```

Toutes à 16 ou 64 Ko, sur `arm64-v8a` et `x86_64`. À rejouer après toute mise
à jour de plugin embarquant des `.so` préconstruites : c'est là que
l'alignement se perd, sans avertissement au build.

## Deux pièges rencontrés en produisant ce build

**1. `BUNDLE-METADATA` gonfle l'AAB sans compter pour Play.** Les 207 Mo
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
