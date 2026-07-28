---
name: project-share-feature
description: "État du partage externe (feed) — liens profonds /feed/:id, hôte canonique diasponiger.web.app, tracking external_share_count, et dettes restantes (iOS universal links, web fallback)"
metadata: 
  node_type: memory
  type: project
  originSessionId: 6e290746-aead-4381-af41-4a0c8b9decff
---

Refonte du « Partager via » des posts du feed (2026-07-16) :
- Hôte canonique des deep links = `https://diasponiger.web.app` (vérifié Android via assetlinks.json déployé). L'ancien défaut `diaspo-niger.web.app` (avec tiret) était FAUX — corrigé dans `deep_link_service.dart`, `.env` et `.env.example`.
- Liens post = `/feed/<postId>` → route go_router existante `PostDetailScreen` (charge à froid par id). Pas besoin de `parseDeepLink` (toujours sans appelant).
- Helper partagé `lib/shared/utils/external_share.dart` (WhatsApp wa.me / Facebook sharer / X intent/post / feuille système) — utilisé par `share_post_sheet.dart` et `share_group_modal.dart`. Retourne `bool` succès pour le tracking.
- Tracking : `posts.external_share_count` (distinct de `share_count` = reposts) + RPC `increment_post_external_share` (migration `20260716130000`), et `SocialActionType.share` via AnalyticsService. Chaîne : FeedNotifier.trackExternalShare → repo → datasource (avec ensureAuthenticated, cf. [[project-supabase-write-auth-guard]]).

Itération 2 (2026-07-16, vérifiée sur téléphone) :
- `FeedScreen`/`PostDetailScreen` : `leading` AppBar avec repli `canPop ? pop : go('/home')` (les routes `/feed*` sont hors du shell → sans ça, entrée deep link = piégé).
- Icônes de marque : `assets/icons/icon_whatsapp|facebook|x.svg` (Simple Icons CC0, monochromes teintés via AppIcon) utilisées dans share_post_sheet et share_group_modal.
- Suivre depuis le fil : `FollowButton` inséré dans `_PostHeader` (post_card.dart) si non-auteur + tap avatar/nom → `/profile/:userId`. L'écran de profil public n'a toujours PAS de bouton suivre (follow-up).
- Confirmé sur device : le redirect splash avale la cible du deep link même connecté sur démarrage À FROID (à chaud ça marche) — renforce le besoin du « return-to ».

Itération 3 (2026-07-16) — retours UI :
- Bandeau épinglés `group_pinned_banner.dart` refait façon Telegram : ligne unique fine (~44px, `_PinnedRow`), toujours visible (ne plus masquer au clavier), compteur `i/n` + tap pour faire défiler plusieurs épingles. Contenu réel du message résolu via `messagesProvider(messageConversationId)` (param passé depuis conversation_screen) ; event/poll via leurs providers. NB : pas de scroll-to-message au tap (dette).
- Overflows conversation : modal options rendu scrollable (`SingleChildScrollView` + maxHeight 85%) ; l'ancienne solution « masquer le bandeau au clavier » a été REMPLACÉE par le bandeau mono-ligne.
- Carte : barre de recherche repeinte APRÈS les chips profession (z-order) pour que les suggestions recouvrent les filtres.
- Sondages/événements : rangée ajoutée au menu « + » du composer (`message_input.dart` onCreateEvent/onCreatePoll). Sondage = groupes only (PollContextType n'a pas de DM — dette backend).
- Profils supprimés : vraie cause = FK `posts.author_id → users` ABSENTE au distant (drift). Migration `20260716170000` : purge orphelins + FK ON DELETE CASCADE. Requêtes bookmarks/reposts utilisent embed `users!posts_author_id_fkey!inner`. Voir [[project-supabase-schema-drift]].

**Dettes restantes (hors périmètre, non faites)** :
- iOS : pas d'Associated Domains (universal links) — les liens https n'ouvrent pas l'app iOS ; entitlement Xcode requis.
- Redirect auth : un non-connecté cliquant un deep link perd la cible (pas de return-to après login).
- Web : `/feed/<id>` 404 en navigateur desktop (pas de rewrite firebase.json / page interstitielle).
- Piège : les timestamps de migrations peuvent collisionner (deux fichiers `20260716120000_*` ont existé) — vérifier `supabase migration list` avant de créer.
