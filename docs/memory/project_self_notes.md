---
name: project_self_notes
description: "Fonction « Mes notes » (self-chat/Saved Messages) dans la messagerie — architecture, détection, chiffrement AES vers soi, brouillon de sondage"
metadata: 
  node_type: memory
  type: project
  originSessionId: 38560c9e-b059-4a5c-8f51-bd877fa23f4d
---

« Mes notes » = conversation avec soi-même (style Telegram Saved Messages), ajoutée le 2026-07-18. Sert de brouillon/scratchpad : notes texte, médias, notes vocales, localisation, favoris + brouillon de sondage.

**Détection** : `ConversationEntity.isSelfNotesFor(userId)` = `participantIds.length == 1 && participantIds.first == userId`. Type DB = `individual`, `participant_ids = [me]`, data flag `isSelfNotes: true`. Get-or-create via `getOrCreateSelfConversation` (datasource/repo) + providers `selfNotesConversationProvider` (lecture) et `ensureSelfNotesProvider` (get-or-create au tap).

**Liste messages** : exclu du flux normal (`_filterConversations`), affiché via une tuile épinglée dédiée `_buildSelfNotesTile` / `_selfNotesSlivers()` en haut, seulement dans la vue par défaut (`_shouldShowSelfNotes` : ni archives, ni recherche, ni filtre).

**Chiffrement vers soi (le point délicat)** : seul le TEXTE passe par Signal (`_encryptContent`), qui refuse un destinataire vide. Fix = param `selfNote` propagé provider→repo→datasource→`_encryptContent`, qui force l'AES global via `encryptGroup(plaintext, groupId: null)`. Relecture : Format 4 AES de `MessageCryptoService.decrypt` (clé globale partagée multi-appareils). Médias/voix/localisation/stickers utilisent DÉJÀ l'AES directement (`encryptionLevel: 'aes'`), donc marchent sans changement. Voir [[project_e2ee_status]].

**Écran de conversation** : param `ConversationScreen.isSelfNotes` (passé via router `extra['isSelfNotes']`). Garde-fous : titre « Mes notes », avatar `Icons.bookmark_rounded`, pas de boutons d'appel, pas de présence/online, pas d'événement. Le reste dégrade tout seul car `otherUserId` est null.

**Sondage dans les notes** = brouillon uniquement (choix produit v1), PAS de vote. `note_poll_draft_sheet.dart` compose une note texte structurée (📊 + question + `◻️ options`) envoyée comme message texte normal. Les vrais sondages restent groupes-only (cf. [[project_polls_events_scope]]). Pour rendre les sondages votables dans les notes il faudrait changer la contrainte DB `PollContextType` + traiter la self-conv comme contexte groupe.

**À vérifier au runtime** (non testé sur device) : que la RLS Supabase autorise l'INSERT d'une conversation à un seul participant (même politique que createGroupConversation, devrait passer).
