---
name: project_polls_events_scope
description: "Sondages = groupes uniquement (contrainte DB), événements = groupes + DM ; le compte de test a 0 groupe d'où l'invisibilité des sondages"
metadata: 
  node_type: memory
  type: project
  originSessionId: 6e290746-aead-4381-af41-4a0c8b9decff
---

Portée réelle des sondages et événements dans les conversations (vérifié sur appareil le 2026-07-17) :

| | Groupe | DM (1-à-1) |
|---|---|---|
| Événement | ✅ | ✅ |
| Sondage | ✅ | ❌ bloqué en base |

- **Sondages bloqués en DM par le schéma** : la table des sondages (migration `20260712120000_group_events_polls_pins.sql`) porte `CHECK (((post_id IS NOT NULL)::int + (group_id IS NOT NULL)::int) = 1)` — un sondage appartient à un post OU un groupe, jamais à une conversation. `PollContextType` ne connaît que `{post, group}`. La migration `20260713090000_extend_pin_and_events_to_dm.sql` a étendu **épingles et événements** aux DM, mais pas les sondages.
- **Décision utilisateur (2026-07-17)** : garder les sondages en groupe uniquement, ne pas les étendre aux DM.
- **Piège de diagnostic** : le compte de test (Sim A) a **0 groupe** → les sondages lui sont structurellement invisibles partout. Avant de conclure à un bug « je ne vois pas les sondages », vérifier le nombre de groupes sur l'accueil.
- Les options Événement/Sondage vivent dans la 3ᵉ rangée du menu trombone (`message_input.dart`, `_showAttachmentOptions`) et n'apparaissent que si `onCreateEvent`/`onCreatePoll` sont non-nuls (`conversation_screen.dart` ~950-968). Défauts de permission groupe = `allMembers`, donc visibles pour tous les membres.

Voir [[project_pinned_banner_telegram]].
