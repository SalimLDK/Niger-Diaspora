# ADR — Source de vérité de la messagerie (Supabase vs Firebase RTDB)

Statut : **Acté** (2026-07-15) · Décision de cadrage pré-prod

## Contexte

La messagerie s'appuie historiquement sur Firebase Realtime Database (RTDB).
La migration vers Supabase a déplacé le **stockage et le temps réel des messages**
vers Postgres, mais certaines opérations annexes écrivent encore dans RTDB. Il
faut trancher la source de vérité pour éviter un « split-brain ».

## État réel du code (constat, pas supposition)

Autorité **Supabase** (source de vérité) :
- `MessageSupabaseDataSource` (`lib/features/messages/data/datasources/message_supabase_datasource.dart`)
  gère envoi, liste, pagination et temps réel via `onPostgresChanges` / `.stream()`.
- Câblé à l'UI : `messageRemoteDataSourceProvider` et `messageRepositoryProvider`
  (`message_provider.dart:36`) retournent l'implémentation Supabase.

Encore sur **RTDB** (état secondaire, écrit en direct) :
- Réactions & favoris : `message_action_service.dart` (branché : `message_info_sheet.dart:58`).
- Suppressions : `message_deletion_service.dart` (branché : `conversation_screen.dart:613`).
- Accusés de lecture : `read_receipt_service.dart`.
- Notifications / réponse rapide : `notification_service.dart`, `background_reply_service.dart`.

**Code mort RTDB** (défini mais aucun consommateur — vérifié par recherche) :
- `MessageRemoteDataSourceImpl` (ancien datasource RTDB complet,
  `message_remote_datasource.dart:418`).
- `MessageStreamService` + providers `conversationMessagesStreamProvider`,
  `typingIndicatorsProvider` (`message_stream_service.dart`).

## Décision

1. **Supabase est l'unique source de vérité** pour le contenu, la liste et le
   temps réel des messages. Toute nouvelle fonctionnalité messagerie écrit dans
   Supabase.
2. **Réactions, favoris, suppressions et accusés de lecture doivent migrer vers
   Supabase** (colonnes/tables dédiées + realtime) pour supprimer la dépendance
   RTDB résiduelle. Tant que cette migration n'est pas faite, ces états restent
   en RTDB et NE sont PAS considérés comme faisant autorité pour l'audit/RGPD.
3. **Supprimer le code mort RTDB** (`MessageRemoteDataSourceImpl`,
   `MessageStreamService` et ses providers) une fois la non-régression confirmée.

## Conséquences

- Court terme (avant go-live) : documenter que RTDB porte encore l'état
  réactions/lecture. L'export RGPD (voir `docs/ROLLBACK_AND_DATA.md`) doit donc
  agréger Supabase **et** ces nœuds RTDB tant que la migration n'est pas faite.
- Moyen terme : ticket de migration réactions/read-receipts → Supabase, puis
  purge du code mort. Réduit la surface (deux backends temps réel → un seul).

## Ce qui n'est PAS fait dans ce commit

Aucune suppression de code ni migration de données : les services RTDB portent
des fonctionnalités actives (réactions, lecture) sans équivalent Supabase à ce
jour. Les retirer sans backend de remplacement casserait ces fonctions. Cette
ADR fige la décision ; l'implémentation fait l'objet de tickets dédiés.
