---
name: project_message_dedup_typing
description: Correctifs doublons messages + auto-écho E2EE + « écrit… » dans la liste + cadenas retiré ; décision de ne PAS propager clientMessageId aux stickers/localisation
metadata: 
  node_type: memory
  type: project
  originSessionId: a981bbca-80fb-4694-ae49-68df5da7f2b3
---

Le 2026-07-17, refonte de la fiabilité messagerie ([[project_e2ee_status]], [[project_audit_remediation]]).

**Doublons + auto-écho E2EE** — dans `message_provider.dart` `_listenForNewMessages` :
- Le matcher Priority 1 matche désormais par `clientMessageId` **sans** exiger le préfixe `temp_` (fermait la course « INSERT temps réel arrive juste après le retour de send() »).
- Nouveau helper `_reconcileEcho(local, incoming)` : quand l'écho temps réel d'un message qu'on a envoyé est illisible (`''` ou `🔐 Message chiffré` — l'expéditeur ne peut pas re-déchiffrer son propre Signal), on garde le texte clair local et on n'adopte que l'id/métadonnées serveur.
- Fenêtre temporelle du fallback heuristique élargie 5 s → 15 s.

**Décision non-évidente :** on n'a **pas** propagé `clientMessageId` aux datasources sticker/localisation (aurait touché l'interface + les 2 impls Supabase actif *et* Firebase legacy + le repository). À la place, la fenêtre 15 s couvre ces types (envois AES rapides). Si des doublons de stickers/GIF/localisation réapparaissent sous réseau très lent, la vraie correction reste : `clientMessageId` universel côté datasource.

**« en train d'écrire… » dans la liste** — `conversation_item.dart` watch maintenant `typingStatusProvider(conversation.id)` et remplace l'aperçu du dernier message par `typingOneName`/`typingSomeone`. Coût : un canal presence Supabase par conversation visible (provider non-autoDispose) — à surveiller si la liste devient longue.

**Cadenas E2EE retiré** du chat : suppression des deux `IconButton` cadenas (app bar individuel + groupe), de `_showEncryptionInfo`, et de l'import `messaging_e2ee_service.dart` dans `conversation_screen.dart`.
