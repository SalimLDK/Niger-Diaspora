---
name: project_supabase_write_auth_guard
description: Toute écriture Supabase doit appeler ensureAuthenticated() sinon RLS bloque (session expirée → insert en anon)
metadata: 
  node_type: memory
  type: project
  originSessionId: 45fff920-3c6d-4ee4-bd4f-51132c7f28fd
---

Les RLS Supabase comparent `current_user_id()` (= `auth.jwt()->'app_metadata'->>'firebase_uid'`, fallback `sub`) avec le `*_id` de la ligne. La session Supabase est établie par [[project_audit_remediation]] via `SupabaseAuthBridge` (échange du token Firebase) et **expire (~1h)**. Si elle n'est pas rétablie avant une écriture, l'opération s'exécute en `anon` → la RLS rejette → `PostgrestException`.

**Règle :** tout datasource qui écrit dans Supabase doit commencer par :
```dart
if (!await SupabaseAuthBridge.instance.ensureAuthenticated()) {
  throw ServerException('Session Supabase non établie – reconnectez-vous');
}
```
`ensureAuthenticated()` retourne vite si déjà connecté (`if (isAuthenticated) return true;`), donc OK même sur des appels fréquents (toggleLike). Le `ServerException` est capturé par les repositories (`on ServerException` → `Left(ServerFailure)`) et affiché à l'UI.

**Why:** Bug du 25/06/2026 — impossible de publier dans le feed. `feed_supabase_datasource.dart` était le seul chemin d'écriture sans ce garde-fou (messages/groups/calls/auth l'avaient déjà). En plus, `feed_repository_impl.createPost` ne capturait que `ServerException` (pas la `PostgrestException` brute) → l'exception remontait jusqu'à `_publish()` sans try/catch → spinner figé sans message.

**How to apply:** garde-fou ajouté à createPost/deletePost/toggleLike/addComment/deleteComment/toggleFollow/toggleBookmark de `feed_supabase_datasource.dart`; `feed_repository_impl.createPost` a désormais un `catch (e)` générique → `Left`. Vérifier ce pattern lors de l'ajout de tout nouveau datasource d'écriture.

**MAJ 16/07/2026 — friends :** `friend_supabase_datasource.dart` était le dernier datasource d'écriture sans le garde-fou → toutes les demandes d'amis échouaient en anon. Garde-fou ajouté à send/accept/decline/cancel/removeFriend. En plus, bug RLS distinct sur l'acceptation : la policy `friends_own` (firebase_uid() = user_id) interdit au receveur d'insérer la ligne réciproque côté expéditeur (user_id = sender_id). Corrigé via RPC SECURITY DEFINER `accept_friend_request(p_request_id)` (migration `20260716140000`, pattern `insert_group`) — **doit être déployée** (`supabase db push`). **Reste à corriger :** `removeFriend` supprime 2 lignes mais la RLS bloque silencieusement la suppression de la ligne côté ami (user_id = friendId) → relation à moitié supprimée ; nécessiterait aussi une RPC SECURITY DEFINER.
