---
name: project_supabase_over_firebase
description: Direction affirmée le 2026-07-27 — Salim préfère Supabase à Firebase ; viser la migration progressive du backend Firebase functions vers les edge functions
metadata:
  type: project
---

Salim a explicitement indiqué préférer **Supabase** à Firebase comme backend cible. À prendre comme direction d'architecture par défaut : à choix égal, proposer la solution Supabase, et traiter tout nouveau code backend comme devant naître côté Supabase plutôt que dans `functions/index.js`.

État du terrain au 2026-07-27 :

- **74 fonctions Firebase déployées.** Réparties en 37 HTTPS (callable/onRequest), 33 triggers Firestore, 3 triggers RTDB, 1 trigger auth.
- Les **37 HTTPS sont portables immédiatement** — aucune donnée à migrer, ce sont de simples endpoints.
- Les **33 triggers Firestore ne peuvent pas bouger avant leur donnée** : une edge function Supabase n'est pas déclenchable par une écriture Firestore. Ils suivent la migration des collections, pas l'inverse.
- Le schéma Supabase contient **déjà** `transactions`, `orders`, `tips`, `room_tickets` (`20260522223150_initial_schema.sql`).
- Le push FCM est **déjà entièrement piloté depuis Supabase** (`send-push` + triggers DB) : le motif est prouvé.

**Why:** l'obstacle à la migration n'est pas le runtime mais le couplage au stockage. Raisonner « quelle donnée bouge » avant « quelle fonction bouge ».

**How to apply:** cible naturelle en premier = la pile paiement, tant que Stripe est en mode test (`sk_test_`) — migrer un système de paiement après avoir encaissé de l'argent réel est bien plus risqué. La moitié Supabase existe déjà (`create-payment-intent`, `stripe-webhook`, `process-tip`, `process-room-ticket`, `process-escrow-release`). Écarts à combler : pourboires et billets absents du webhook Supabase, automate d'états divergent (`processing` côté Firebase vs `completed` côté Supabase), conventions de métadonnées incompatibles (camelCase vs snake_case), et le module `functions/partners/` (Mynita/Wave/carte, CommonJS) à porter en Deno. Voir [[project_firebase_functions_deploy_blocked]].
