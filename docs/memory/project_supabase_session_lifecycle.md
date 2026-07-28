---
name: project-supabase-session-lifecycle
description: "Cycle de vie session Supabase (bridge Firebase→Supabase) — causes des 401 magic link et InvalidJWTToken realtime, et les 3 protections en place dans supabase_auth_bridge.dart"
metadata: 
  node_type: memory
  type: project
  originSessionId: 6e290746-aead-4381-af41-4a0c8b9decff
---

La session Supabase est mintée par échange Firebase→Supabase (`supabase_auth_bridge.dart` + edge function `auth-firebase-exchange` qui fait generateLink magiclink + verifyOtp). Trois pièges structurels, tous corrigés le 2026-07-16 dans le bridge :

1. **Syncs concurrents = 401 « Email link is invalid or has expired »** : chaque `generateLink` invalide le magic link précédent du même utilisateur (usage unique). Protection : déduplication `_inFlightSync` (les appels concurrents partagent le même Future).
2. **Session expirée passait `ensureAuthenticated()`** : le test était `currentSession != null`. Protection : `hasValidSession` (marge 60 s sur `expiresAt`).
3. **Realtime gardait le JWT mort** (« InvalidJWTToken: Token has expired » en boucle, feed/messages) : personne n'appelait `realtime.setAuth`. Protections : `realtime.setAuth(accessToken)` après chaque sync + timer `_renewTimer` qui re-mint ~5 min avant expiration (le refresh token du magic link n'est pas fiable pour l'auto-refresh gotrue).

À savoir : le redirect splash avale la cible d'un deep link sur démarrage à froid (pas de « return-to ») ; les `.subscribe()` realtime n'ont aucun callback d'erreur applicatif (le RealtimeClient interne reconnecte seul — OK tant que setAuth est tenu à jour). Voir [[project-supabase-write-auth-guard]] et [[project-share-feature]].

Bugs annexes corrigés en passant : assertion Riverpod `SelectedBusinessLocationNotifier.build` → `Future.microtask` (business_provider.dart) ; `@pragma('vm:entry-point')` manquant sur la classe `BackgroundLocationService`. Bruit connu non-bug : AppCheck 403 en debug (debug token non enregistré), spam Samsung `SurfaceSyncer`.
