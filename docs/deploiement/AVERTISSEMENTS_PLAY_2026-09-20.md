# Play Console — avertissements de la version 1.2.2+23

*État au 2026-09-20. Copie du doc de synthèse rédigé pendant l'analyse (lien privé : <https://claude.ai/code/artifact/59f56a17-8412-46b0-903e-36bc09a773a2>). Rien n'a été modifié dans le code pour l'établir.*

## Verdict

Aucun des trois avertissements ne bloque la publication de la 1.2.2+23, et aucun n'est nouveau avec elle : la 22 fait la même taille et la 18 a le même manifeste.

| Avertissement | Cause mesurée | Action |
| --- | --- | --- |
| 1 306 appareils perdus | minSdk 23 → 24, imposé par une douzaine de plugins ; `camera.any` exigé sans que ce soit voulu | Relâcher `camera.any` si la Console le confirme |
| Forte hausse de taille | environ 47 Mo par appareil arm64 ; le moteur Rust n'en ajoute que 2 | Aucune |
| Optimisation : obscurcissement à 36 % | 34 453 classes sur 48 121 gardent leur nom, à cause de règles `-keep` trop larges | Retirer la règle Stripe |

Recommandation : publier la 23 telle quelle. Si vous faites les deux correctifs, ils partent ensemble dans un bundle 1.2.2+24 (section « Plan proposé »).

## Appareils perdus : 1 306

La cause principale est le passage de minSdk 23 à 24, déjà documenté et non réversible ; le moteur Rust n'a retiré aucun appareil.

`minSdk = flutter.minSdkVersion` suit le SDK Flutter du poste (24 avec Flutter 3.44). Une douzaine de plugins exigent 24, dont `webview_flutter_android`, `video_player_android`, `google_maps_flutter_android`, `flutter_secure_storage`, `google_sign_in_android`, `flutter_local_notifications` et `image_picker_android`. Revenir à 23 imposerait de tous les rétrograder. La 1.1.1 est en API 23.

À la 16, Play annonçait 1 137 appareils perdus sur 19 117. Le passage 23 → 24 en explique l'essentiel ; le passage de 4 à 3 ABI environ 116 (source : notes de la 1.2.1+17, §7).

Les AAB 18 et 23 sont identiques pour tout ce que Play filtre :

| Élément | 1.2.1+18 | 1.2.2+23 |
| --- | --- | --- |
| minSdk / targetSdk | 24 / 36 | 24 / 36 |
| Permissions | 49 | 49, mêmes noms |
| Composants | 95 | 95, mêmes noms |
| `uses-feature` | 4 | 4, mêmes |
| ABI | arm64-v8a, armeabi-v7a, x86_64 | idem |

Deux points restent ouverts :

- Les 169 appareils de plus que les 1 137 de la 16 ne s'expliquent par rien dans l'artefact : catalogue Play ou base de comparaison.
- `android.hardware.camera.any` est exigé, car il est déclaré sans attribut `required`, donc vrai par défaut. Il vient de `camera_android_camerax`, alors que le manifeste de l'app déclare `camera` et `autofocus` en `required=false`. Les appareils sans aucune caméra sont donc exclus sans que ce soit voulu. Gain non chiffré.

## Taille : environ 47 Mo par appareil arm64

Le moteur Rust ajoute 2 Mo compressés par architecture ; l'essentiel du poids vient de ce qui s'est accumulé depuis la 1.1.1, et la 22 pèse exactement autant que la 23 (229,87 Mo).

Play sert le module de base et le seul lot natif de l'architecture de l'appareil. Tailles compressées dans l'AAB pour arm64-v8a, en Mo :

| Poste | 1.2.1+18 | 1.2.2+23 |
| --- | --- | --- |
| Base hors natifs (dex 15,4 ; assets ; ressources) | 20,4 | 21,8 |
| `libapp.so` (Dart compilé) | 9,8 | 10,2 |
| `libflutter.so` | 5,4 | 5,4 |
| `libjingle_peerconnection_so.so` (WebRTC) | 5,4 | 5,4 |
| `libbarhopper_v3.so` (QR, ML Kit) | 2,1 | 2,1 |
| `libdiaspo_mls.so` (OpenMLS) | absent | 2,0 |
| Total arm64 | 43,1 | 46,9 |

Sur armeabi-v7a le total est d'environ 45 Mo, sur x86_64 d'environ 47,5 Mo. Les 133 Mo de `BUNDLE-METADATA` (symboles natifs, mapping R8) ne sont jamais envoyés aux appareils.

Les 1,4 Mo d'assets en plus depuis la 18 sont les polices Inter embarquées (`assets/google_fonts`, commit `f6e85f4`). `libdiaspo_mls.so` est déjà strippé (`strip = true`, `opt-level = "z"`, LTO).

L'avertissement se mesure contre la version précédente de la Console, pas contre la 22. Aucun de ces postes ne justifie à lui seul un nouveau bundle. Les leviers connus, du plus net au plus lourd :

- Retirer Stripe : 8 755 classes pour des modules masqués (section suivante). Gain en Mo non mesuré.
- ML Kit non groupé : environ 2,1 Mo par architecture ; disponibilité et compatibilité avec `mobile_scanner` 7.x à vérifier, puis test du scanner QR.
- WebRTC et LiveKit : 5,4 Mo par architecture, plus le dex de LiveKit, seulement si les appels restent en pause ; décision produit.

## Optimisation R8 : obscurcissement à 36 %

Play affiche 36 % d'obscurcissement ; sur le mapping de la 23, seules 28 % des classes sont renommées, parce que des règles `-keep class X.** { *; }` figent des paquets entiers.

Play formule sa mesure autrement, donc les deux chiffres ne coïncident pas. Optimisation et minification s'affichent « - » : la cause est inconnue.

Mesuré dans le `proguard.map` de l'AAB 23 : 48 121 classes, dont 34 453 au nom inchangé ; 1,40 million de membres, dont 54,9 % renommés. La configuration R8 fusionnée ne contient ni `-dontobfuscate`, ni `-dontoptimize`, ni `-dontshrink` : seules des règles `keep` sont en cause. Chacune interdit à R8 de renommer, d'élaguer et d'optimiser le paquet qu'elle cite.

| Règle | Classes inchangées | Origine |
| --- | --- | --- |
| `com.google.android.gms.**` | 13 824 | notre règle (`proguard-rules.pro:23`) ; firebase-auth 23.2.1 garde aussi `gms.internal.**` |
| `com.stripe.**` | 8 202 (106 000 membres) | notre règle (`proguard-rules.pro:19`) |
| `com.revenuecat.**` | 2 780 | règle de la bibliothèque |
| `com.google.firebase.**` | 2 465 | notre règle |
| `com.google.crypto.tink.**` | 1 496 | notre règle |
| `io.flutter.plugins.**` | 1 330 | notre règle, parmi 5 règles `io.flutter.*` |
| `com.fasterxml.**` | 842 | règle de `flutter_callkit_incoming` |

Sous `gms`, 5 731 classes sont `internal.ads` (AdMob), 1 186 `firebase-auth-api` et environ 1 850 ML Kit. Retirer notre règle `gms.**` ne libère presque rien d'essentiel : la règle de firebase-auth ne se surcharge pas depuis le dépôt, et seules au moins 1 100 classes hors `internal` seraient concernées.

Les 5 règles `io.flutter.*` viennent toutes de notre fichier. `io.flutter.**` couvre les quatre autres : en retirer seulement quatre ne change rien. Flutter fournit sa propre règle conditionnelle pour les plugins (`flutter_proguard_rules.pro`), mais toucher à ce groupe revient à toucher au moteur, pour un gain d'environ 1 700 classes.

Stripe est le levier le plus net. `flutter_stripe` n'est appelé que par `stripe_service.dart`, lui-même utilisé par `send_tip_bottom_sheet.dart` (salons audio) et `podcast_detail_screen.dart` (podcasts, désactivés par `kPodcastsSupportesParCeBuild = false`). Les 8 755 classes Stripe sont embarquées pour des modules masqués. RevenueCat et Amazon, environ 3 100 classes, sont dans le même cas.

## Plan proposé : bundle 1.2.2+24

Rien n'est lancé : un bundle 1.2.2+24 regrouperait deux correctifs et attend l'accord de Salim.

| Changement | Fichier | Gain attendu | Risque |
| --- | --- | --- | --- |
| Version portée à 1.2.2+24 | `pubspec.yaml` | — | aucun |
| `camera.any` en `required="false"` (`tools:node="replace"`) | `android/app/src/main/AndroidManifest.xml` | appareils sans caméra récupérés, non chiffré | aucun à l'exécution : ne change que le filtrage Play |
| Retirer `-keep class com.stripe.** { *; }` | `android/app/proguard-rules.pro` | jusqu'à 8 202 classes renommées ou élaguées | moyen : le plugin Stripe s'enregistre au démarrage |
| Ne pas toucher : Tink, Firebase, `gms.**`, `io.flutter.*` | `android/app/proguard-rules.pro` | — | Tink protège `flutter_secure_storage` : une erreur déconnecterait les utilisateurs |

Vérification, dans un worktree comme l'exige le dépôt :

1. Copier `.env`, `android/key.properties` et le keystore, puis `flutter pub get` avant le premier `flutter analyze`.
2. Vérifier qu'aucun autre build Gradle ne tourne, puis `flutter build appbundle --release` avec `~/.cargo/bin` dans le PATH (environ 25 minutes, Rust compris).
3. Relire `camera.any` dans le manifeste du bundle produit, et comparer son `proguard.map` à celui de la 23 avec le même script.
4. Installer le build release : sur le A515F, la signature diffère du build debug, donc désinstallation, données effacées et reconnexion par Salim ; ou partage interne sur le Pixel, comme pour les bundles précédents.
5. Démarrer à froid pour exercer l'enregistrement du plugin Stripe, puis parcourir connexion, messagerie, scanner QR et carte.

Une entrée est à ajouter à `TESTS_APPAREIL_A_FAIRE.md` : démarrage à froid du build release après le retrait de la règle Stripe, car R8 ne tourne pas en debug.

Deux options plus larges demandent une décision : retirer complètement `flutter_stripe` et `purchases_flutter` tant que les podcasts et les salons audio restent masqués (gain de taille réel mais non mesuré, code Dart à modifier), ou laisser les SDK en l'état.

## Non vérifié

La Console n'a pas été lue, faute de Chrome connecté : tout ce qui suit est mesuré sur les AAB du Bureau et sur le dépôt, et aucun code n'a été modifié.

- La raison d'exclusion de chaque appareil, le total du catalogue et la version que Play appelle « précédente ». Le lien « modifications apportées à vos appareils pris en charge » les donne.
- L'origine des 169 appareils de plus que les 1 137 de la 16.
- Le gain de `camera.any` en nombre d'appareils.
- Le poids en Mo de Stripe : seules ses classes et ses membres sont comptés.
- Pourquoi optimisation et minification affichent « - », et le score que Play affichera après correction. Retirer les règles Stripe, Firebase et `io.flutter.*` libérerait en théorie environ la moitié des classes, comme borne haute et non comme promesse.

Pour reproduire les mesures : décoder `base/manifest/AndroidManifest.xml` de l'AAB (protobuf, sans bundletool) pour le manifeste et les ABI ; lire `BUNDLE-METADATA/com.android.tools.build.obfuscation/proguard.map` et compter les classes dont le nom d'origine égale le nom obscurci ; lire `build/app/outputs/mapping/release/configuration.txt` d'un worktree ayant construit en release pour attribuer chaque règle à sa source. Les trois scripts sont jetables et ne sont pas dans le dépôt.
