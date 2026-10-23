# Build 1.2.2+33 — bundle pour le partage interne d'application

*2026-10-22, 20:41 → 20:53 (714 s de Gradle). Dépôt principal fast-forwardé à
`000c89ea`, tip de `origin/wip-jules-2025-12-29T23-58-34-776Z` à cet instant,
arbre sans modification suivie.*

## Pourquoi ce build

Le dépôt principal était resté sur `136bd21e` (13/10), **188 commits derrière
`origin`** : les corrections livrées depuis n'étaient dans aucun build. Après le
fast-forward (`git merge --ff-only` par PowerShell), ce bundle les embarque.

Le numéro est passé en ligne de commande, `pubspec.yaml` est resté à
`1.2.1+23` — les versions Play ne sont pas suivies dans git :

```bash
export PATH="$HOME/.cargo/bin:$PATH"
flutter clean
flutter build appbundle --release --build-name=1.2.2 --build-number=33
```

## Artefact

Non versionné (220 Mo), copié sur le Bureau :

| Fichier | Taille | md5 |
|---|---|---|
| `DiaspoNiger-1.2.2+33.aab` | 219,7 Mo | `b74c100a0854f5e5774a2a442ed4d73d` |

## Vérifié sur le bundle lui-même

- `USE_FULL_SCREEN_INTENT`, `FOREGROUND_SERVICE_MEDIA_PLAYBACK`,
  `ACCESS_BACKGROUND_LOCATION` : **absentes** du manifeste.
- Signature (`keytool -printcert -jarfile`) : `CN=Diaspo Niger, OU=Mobile,
  O=Diaspo Niger, L=Niamey`, SHA-256 `DD:A6:5C:3E:BC:08:BD:67:4F:FA:37:26:40:5C:4C:B7:5B:25:3E:DE:55:85:BB:E2:22:DA:34:20:51:94:CF:5D`
  — la clé d'upload attendue.
- `libapp.so` (arm64-v8a) contient `ColonneDefilante`.

**Non vérifié** : `versionCode` relu dans le manifeste protobuf, alignement
16 Ko (`tools/verifie_alignement_16k.py`).

## ⚠️ Numéros déjà pris côté Play

Le partage interne contenait un **+40 importé le 22/10 à 19:59** (origine
inconnue), au-dessus de ce +33. Un téléphone qui a installé le +40 refuse le
+33 sans désinstallation. Un **+41**, construit du même arbre (md5
`322feaa925a8ee9084ba2943385bb691`, `DiaspoNiger-1.2.2+41.aab`), existe pour ce
cas.

## Pour l'envoyer

Partage interne d'application : glisser l'AAB dans la zone de dépôt, copier le
lien. Google re-signe avec son propre certificat : **désinstaller l'app avant**.
