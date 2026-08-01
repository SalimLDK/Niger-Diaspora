# Doublons non utilisés

Fichiers déplacés hors de `lib/` le 2026-07-31 après un audit exhaustif
(recherche des écrans/modales jamais référencés en dehors de leur propre
fichier — ni route, ni `Navigator.push`, ni `showModalBottomSheet`/`showDialog`,
ni construction directe par un autre widget).

Chacun de ces fichiers est un **doublon abandonné** d'une implémentation
équivalente qui, elle, est réellement câblée dans l'app :

| Fichier archivé | Remplacé par |
|---|---|
| `events/events_screen_with_tabs.dart` (`EventsScreen`) | `lib/features/events/presentation/screens/events_screen.dart` (routé dans `app_router.dart`) |
| `podcasts/save_as_podcast_sheet.dart` (`SaveAsPodcastSheet`) | `lib/features/audio_rooms/presentation/screens/save_as_podcast_screen.dart` (routé `/audio-rooms/:roomId/podcast`) |
| `audio_rooms/collection_progress_widget.dart` (`CollectionProgressWidget`/`ContributeBottomSheet`/`CollectionBadge`) | `lib/features/audio_rooms/presentation/widgets/_shared/collection_progress_bar.dart` (`CollectionProgressBar`, utilisé dans `audio_room_screen.dart`) |
| `admin/admin_content_screen.dart` (`AdminContentScreen`) | `AdminModerationScreen` (onglet du dashboard admin) |
| `admin/admin_users_screen.dart` (`AdminUsersScreen`) | `AdminUsersManagementScreen` (onglet du dashboard admin) |

Conservés hors de `lib/` (pas supprimés) au cas où du code y serait encore
utile à reprendre, mais retirés du build/analyze actif.

**Non inclus dans cet archivage** (trouvés par le même audit mais PAS des
doublons — des fonctionnalités inachevées, une décision à prendre avant
d'agir) : `HeritageLibraryScreen`, `StickerPacksScreen`/`CreateStickerPackScreen`,
les sélecteurs `content_pickers.dart` (audio rooms), `LegalUpdateDialog`,
`SimpleMapTestScreen` (écran de debug), et le système `PermissionGuard`
admin. Voir la conversation du 2026-07-31 pour le détail.
