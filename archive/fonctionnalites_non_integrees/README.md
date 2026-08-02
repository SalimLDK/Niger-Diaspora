# Fonctionnalités non intégrées

Fichiers déplacés hors de `lib/` le 2026-07-31, distincts des
[doublons](../doublons_non_utilises/README.md) : ce ne sont **pas** des
implémentations dupliquées, mais du code sans doublon fonctionnel qui n'a
jamais été câblé à l'app (ni route, ni `Navigator.push`, ni
`showModalBottomSheet`/`showDialog`, ni construction directe par un autre
widget) et qui n'avait plus été touché depuis fin décembre 2025 au moment de
l'audit — signe d'un abandon plutôt que d'un chantier en cours.

| Fichier archivé | Contenu |
|---|---|
| `legal/legal_update_dialog.dart` | `LegalUpdateDialog` — dialogue de notification de mise à jour des CGU/politique, jamais affiché nulle part |
| `map/simple_map_test_screen.dart` | `SimpleMapTestScreen` — écran de test/debug pour une intégration carte, jamais routé |

Conservés hors de `lib/` (pas supprimés) au cas où le code y serait encore
utile à reprendre.

**Non archivés** (trouvés par le même audit, modifiés récemment — juillet
2026 — donc probablement des fonctionnalités en cours de finalisation, pas
abandonnées) : `HeritageLibraryScreen`, `StickerPacksScreen`/
`CreateStickerPackScreen`, les sélecteurs `content_pickers.dart` (audio
rooms), le système `PermissionGuard` admin.
