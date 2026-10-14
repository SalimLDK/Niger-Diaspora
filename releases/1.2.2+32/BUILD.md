# Build 1.2.2+32 — bundle pour la piste de test interne

*2026-10-13, 21:02 → 21:19. Worktree `nice-vaughan-3f7324` à `136bd21e`, tip de
`origin/wip-jules-2025-12-29T23-58-34-776Z` à cet instant, arbre propre.*

## Pourquoi ce build

Le SM A515F porte depuis le 2026-09-23 la version **Play Store** 1.2.2+31
(`installerPackageName=com.android.vending`, signature Google Play App Signing
`46:24:CD:57…`). Aucun build local, debug ou release, ne s'y installe plus sans
désinstaller — donc sans perdre session, cache et clés E2EE. Décision de Salim :
passer par la piste de test interne plutôt que désinstaller.

Le numéro de version est passé en ligne de commande, le `pubspec.yaml` est resté
à `1.2.1+23` — les versions Play ne sont pas suivies dans git (aucun commit ne
porte 1.2.2) :

```bash
flutter clean   # un build debug venait d'être interrompu : cache Gradle suspect
flutter build appbundle --release --build-name=1.2.2 --build-number=32
```

## Artefact

Le bundle n'est **pas versionné** (220 Mo) :

| Fichier | Taille | md5 |
|---|---|---|
| `build/app/outputs/bundle/release/app-release.aab` | 219,6 Mo | `fd4cb26a12e310bece3d383635c4bcf9` |

## Vérifié sur le bundle lui-même

Manifeste protobuf `base/manifest/AndroidManifest.xml`, lu par attributs :

```
package           com.diasponiger.diasponiger
versionName       1.2.2
versionCode       32
minSdkVersion     24
targetSdkVersion  36
```

Les trois permissions qui ont fait refuser les envois précédents sont absentes :
`USE_FULL_SCREEN_INTENT`, `FOREGROUND_SERVICE_MEDIA_PLAYBACK`,
`ACCESS_BACKGROUND_LOCATION`.

Signature (`keytool -printcert -jarfile`) : `CN=Diaspo Niger, OU=Mobile, O=Diaspo
Niger, L=Niamey, ST=Niamey, C=NE`, SHA-256
`DD:A6:5C:3E:BC:08:BD:67:4F:FA:37:26:40:5C:4C:B7:5B:25:3E:DE:55:85:BB:E2:22:DA:34:20:51:94:CF:5D`
— la clé d'upload, `android/app/diaspo-niger-release.jks`.

Alignement 16 Ko (`tools/verifie_alignement_16k.py`) : 18 bibliothèques 64 bits
examinées, 0 non conforme. ABI : arm64-v8a, armeabi-v7a, x86_64.

Le correctif visé est bien dans le code AOT : `libapp.so` (arm64-v8a) contient
`ColonneDefilante` et `messageErreurContextuel` — voir `a0c1f811`.

## Ce que ce build contient de plus que 1.2.2+31

Tout ce qui a été poussé sur la branche partagée entre le build Play du 23/09 et
`136bd21e`, dont :

- `a0c1f811` — un champ obligatoire défilé hors écran ne part plus vide (13
  formulaires), et la création d'entreprise dit quand l'écriture échoue ;
- `a5ebec7f`, `39fbc862` — plus aucune `PostgrestException` ne traverse un
  dépôt ; passerelle 5xx classée panne réseau.

## Reste à faire dans la console (main de Salim)

1. Play Console → Tests → Test interne → Créer une release → importer
   `app-release.aab` ; la console doit afficher **1.2.2 (32)**.
2. Si elle refuse « signed with the wrong key » : Intégrité de l'application →
   Signature, comparer la clé de téléversement à `DD:A6:5C:3E…` ci-dessus.
3. Déployer ; sur le SM A515F, mettre à jour depuis le Play Store (testeur
   interne). Puis dérouler l'entrée « Formulaires défilants : un champ
   obligatoire hors écran ne part plus vide » de `TESTS_APPAREIL_A_FAIRE.md`.
