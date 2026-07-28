---
name: project_gifs_stickers
description: "Architecture GIFs/stickers — Tenor primaire + Giphy repli, réutilisation du transport sticker, et packs Supabase vides"
metadata: 
  node_type: memory
  type: project
  originSessionId: bd6c926c-db71-4fef-84ab-488201f505f0
---

Les stickers du picker (`lib/features/stickers/`) sont adossés aux tables Supabase `sticker_packs`/`stickers`, mais **aucune migration n'insère de pack** : les tables sont vides, donc l'onglet « Stickers » du picker reste vide même après correction du code. `createStickerPack` lève encore `UnimplementedError` (upload dépendant de Firebase Storage).

Décision prise le 2026-07-17 pour fournir du contenu sans rien héberger : onglet **GIFs** alimenté par **Tenor en primaire, Giphy en repli automatique** (`lib/features/gifs/`). `GifRepository` interroge les sources dans l'ordre et bascule silencieusement si l'une échoue (quota, clé invalide, réseau). Clés via `AppConfig.tenorApiKey` / `giphyApiKey` (`--dart-define` puis fallback dotenv) — jamais en dur. Sans clé, l'onglet affiche un état vide explicite au lieu d'une erreur réseau.

**Choix non évident à connaître avant de toucher au code** : un GIF envoyé **réutilise le transport « sticker »** (`sendSticker` avec `stickerPackId = 'tenor' | 'giphy'`, `stickerId` = id du fournisseur, `isAnimated: true`). Il n'existe **pas** de `MessageType.gif`.

**Why:** ajouter une valeur à l'enum `MessageType` impose de traiter 9 sites `case MessageType.sticker` répartis sur 6 fichiers du cœur messagerie (E2EE, updates optimistes, aperçus de réponse) — surface de risque disproportionnée alors que `StickerBubble` rend déjà une image animée depuis une URL, ce qu'est exactement un GIF.

**How to apply:** pour distinguer GIFs et stickers en analytics ou en UI, filtrer sur `stickerPackId` (`tenor`/`giphy` = GIF distant, UUID = pack Supabase). Si un vrai `MessageType.gif` devient nécessaire (tailles/comportements distincts), prévoir les 9 sites ci-dessus — `messages.type` est un TEXT **sans contrainte CHECK**, donc aucune migration SQL n'est requise côté base. Voir [[project_supabase_schema_drift]].
