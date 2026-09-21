-- Salons audio : l'argent et l'identité repassent au serveur.
--
-- Dernière pièce de la chaîne de paiement, après les douze collections
-- Firestore et `orders` du même jour.
--
-- ═══ CE QUI ÉTAIT OUVERT, ET CE QUI NE L'ÉTAIT PAS ════════════════════════
--
-- L'audit visait « quatre fonctions qui prennent le prix et le vendeur dans
-- le corps de la requête ». Mesuré le 2026-09-21, c'est inexact sur les deux
-- moitiés : les deux fonctions payantes ne PEUVENT PAS marcher, et le vrai
-- trou est dans les tables qu'elles lisent.
--
-- 1. `process-tip` et `process-room-ticket` sont CASSÉES. Elles insèrent
--    `commission_amount`, `recipient_amount`, `message`, `seller_id`,
--    `seller_amount`, `updated_at` — aucune de ces colonnes n'existe.
--    Rejoué ici à l'identique : 42703 « column "commission_amount" of
--    relation "tips" does not exist », 42703 « column "seller_id" of relation
--    "room_tickets" does not exist ». Le `PaymentIntent` vient APRÈS cet
--    insert : le prix dicté par le client n'a jamais atteint Stripe.
--    `stripe-webhook` n'écrit que `transactions` — rien ne fait jamais passer
--    un pourboire ou un billet à `completed`. La chaîne n'a jamais été
--    branchée sur le schéma réel.
--
-- 2. Le trou vivant était dans le RLS, et il est plus grave que la fonction :
--
--    · `creator_profiles_own` était `FOR ALL` — un compte connecté écrivait
--      sa propre fiche, `stripe_account_id` et `stripe_account_status`
--      compris (`updateCreatorProfile`, monetization_supabase_datasource.dart
--      :265, le fait vraiment). Or `stripe-dashboard-link` fait confiance à
--      cette colonne : poser l'identifiant d'un compte Connect quelconque et
--      le statut « active » lui fait rendre un LIEN DE CONNEXION au tableau
--      de bord Stripe de ce compte. La fonction est irréprochable ligne à
--      ligne ; c'est la table qu'elle relit qui appartenait au client.
--      `total_earnings` et `pending_payout` s'écrivaient de la même façon.
--
--    · `tips_insert_own` et `room_tickets_insert_own` ne vérifiaient que
--      l'identité de l'émetteur. Montant, devise, `stripe_payment_intent_id`
--      et surtout `status` étaient libres. Et `hasValidTicket`
--      (même fichier, :69) est le portier des salles payantes : il cherche un
--      billet `completed` ou `active`. S'insérer un billet « completed »
--      donnait l'entrée, sans paiement.
--
--    · `audio_rooms_update` était `USING (firebase_uid() IS NOT NULL)`, sans
--      `WITH CHECK` ni restriction de colonnes : n'importe quel compte
--      connecté réécrivait N'IMPORTE QUELLE salle — `hostId`, `isPaid`,
--      `ticketPrice`, `allowedUserIds`, `blockedUserIds`. Le prix du billet
--      était donc bien dicté par le client, mais par PostgREST, pas par la
--      fonction.
--
--    · et les quatre tables portaient les droits par défaut de Supabase pour
--      `anon` — INSERT, UPDATE, DELETE, TRUNCATE compris. Inerte aujourd'hui
--      (les clés legacy sont désactivées), même forme que `users` avant le
--      2026-09-20.
--
-- ═══ PERSONNE N'EN DÉPEND ═════════════════════════════════════════════════
--
-- Mesuré le 2026-09-21 : 0 pourboire, 0 billet, 0 fiche de créateur, 0 salle.
-- Le drapeau `audioRooms` est fermé (`app_config/settings`), donc le routeur
-- refuse déjà `/audio-rooms`. `STRIPE_SECRET_KEY` du dépôt est en `sk_test`
-- (la valeur DÉPLOYÉE est une autre, non vérifiable d'ici — voir le suivi).
--
-- ═══ CE QUE ÇA LAISSE ═════════════════════════════════════════════════════
--
-- Toutes les lectures. `stripe-connect-onboarding` et `stripe-connect-webhook`
-- écrivent `creator_profiles` sous le rôle de service, qui ignore le RLS :
-- le chemin légitime de création d'une fiche reste entier. Les fonctions
-- payantes restent déployées, cassées comme avant — les réparer, c'est
-- construire la fonctionnalité, pas la fermer.
--
-- Sur `audio_rooms`, le client garde les DIX colonnes qu'il écrit vraiment.
-- Relevé exhaustivement dans `audio_room_remote_datasource.dart` (tous les
-- `.update(` du fichier) : participants, rôles, mains levées et micros vivent
-- dans RTDB (`audioRooms/$roomId/participants`), pas dans ces colonnes.
-- `hostId` et `ticketPrice` ne sont donc jamais réécrits après la création —
-- les retirer ne coûte rien et les rend infalsifiables. La restriction par
-- colonnes est un GRANT, pas une policy : le RLS filtre des lignes, jamais
-- des colonnes.
--
-- ⚠️ CE QUI CHANGE POUR LE CLIENT, derrière le drapeau fermé :
-- `getOrCreateCreatorProfile` et `enableMonetization` (insert client d'une
-- fiche) échoueront désormais en 42501 au lieu de réussir. C'est voulu — la
-- fiche naît côté serveur, à l'embarquement Stripe. `markTicketUsed`
-- échouait déjà (aucune policy d'UPDATE sur `room_tickets`) ; il échouera
-- plus tôt et plus clairement.
--
-- Rouvrir la monétisation demandera : le prix relu depuis
-- `audio_rooms.ticketPrice`, le vendeur depuis `hostId`, le passage à
-- `completed` réservé au webhook, et `creator_profiles.stripe_account_id`
-- écrit par le seul embarquement Stripe.
--
-- Banc : tools/rls_tests/salons_audio_ecriture_fermee.sql

REVOKE ALL ON public.creator_profiles FROM anon;
REVOKE ALL ON public.tips             FROM anon;
REVOKE ALL ON public.room_tickets     FROM anon;
REVOKE ALL ON public.audio_rooms      FROM anon;

-- ── creator_profiles : lecture de sa propre fiche, et rien d'autre ─────────
REVOKE INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER
  ON public.creator_profiles FROM authenticated;

DROP POLICY IF EXISTS creator_profiles_own ON public.creator_profiles;

CREATE POLICY creator_profiles_select_own ON public.creator_profiles
  FOR SELECT TO authenticated
  USING ((SELECT public.firebase_uid()) = user_id);

-- ── tips / room_tickets : lecture seule ───────────────────────────────────
REVOKE INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER
  ON public.tips FROM authenticated;

DROP POLICY IF EXISTS tips_insert_own ON public.tips;
ALTER POLICY tips_parties ON public.tips TO authenticated;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER
  ON public.room_tickets FROM authenticated;

DROP POLICY IF EXISTS room_tickets_insert_own ON public.room_tickets;
ALTER POLICY room_tickets_own ON public.room_tickets TO authenticated;

-- ── audio_rooms : les dix colonnes que le client écrit, et elles seules ────
REVOKE UPDATE, TRUNCATE, REFERENCES, TRIGGER
  ON public.audio_rooms FROM authenticated;

GRANT UPDATE (
  status, "startedAt", "endedAt",
  "isRecordingEnabled", "isVideoEnabled", "isPrivate",
  "mutedSpeakers", "adminWarnings", "endedByAdmin", "endReason"
) ON public.audio_rooms TO authenticated;

-- Les quatre policies restaient offertes à `public`, donc à `anon`.
ALTER POLICY audio_rooms_select ON public.audio_rooms TO authenticated;
ALTER POLICY audio_rooms_insert ON public.audio_rooms TO authenticated;
ALTER POLICY audio_rooms_update ON public.audio_rooms TO authenticated;
ALTER POLICY audio_rooms_delete ON public.audio_rooms TO authenticated;
