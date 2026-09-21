-- Banc : salons audio — l'écriture d'argent et d'identité fermée au client
-- (migration 20260921054500).
--
--   supabase db query --linked -f tools/rls_tests/salons_audio_ecriture_fermee.sql
--
-- Condition : 0 cas en ÉCHEC. Tout est dans un `BEGIN … ROLLBACK`.
--
-- AVANT `db push` : remplacer la ligne seule `-- @@MIGRATION@@` par le contenu
-- de la migration — c'est la répétition. APRÈS, lancé tel quel, le banc prouve
-- l'état vivant.
--
-- Un banc qui ne sait pas échouer ne prouve rien. Le compte de ce qui tombe
-- sans la migration est relevé ci-dessous, pas deviné.
--
-- Les quatre tables sont VIDES en production, et le banc les laisse vides :
-- ses lignes d'essai sont posées sous le rôle propriétaire puis annulées par
-- le `ROLLBACK`. Aucun déclencheur de notification n'existe sur ces tables
-- (seul `creator_profiles_updated_at`), donc rien ne part.

BEGIN;

SET LOCAL lock_timeout = '5s';

CREATE TEMP TABLE resultat(n int, cas text, attendu text, obtenu text, verdict text);
CREATE TEMP TABLE ctx(k text PRIMARY KEY, v text);
GRANT ALL ON resultat, ctx TO anon, authenticated;

INSERT INTO ctx VALUES
  ('hote',     '1X5F6RKlrTgyxZFSTvS6lXBx8C32'),
  ('intrus',   'hMGnFMEpKfhvmsm8Y1wL5Iuh4X13'),
  ('salle',    gen_random_uuid()::text);

-- @@MIGRATION@@

-- Une salle payante d'essai, posée par le propriétaire (hors RLS).
INSERT INTO public.audio_rooms (id, title, "hostId", "hostName", status,
                                "isPaid", "ticketPrice", "ticketCurrency")
SELECT (SELECT v FROM ctx WHERE k = 'salle')::uuid,
       'Salle du banc', (SELECT v FROM ctx WHERE k = 'hote'), 'Hôte',
       'live', true, 500000, 'xof';

-- Une fiche de créateur pour l'hôte, comme l'embarquement Stripe la pose.
INSERT INTO public.creator_profiles (user_id, stripe_account_id, stripe_account_status)
SELECT (SELECT v FROM ctx WHERE k = 'hote'), 'acct_HOTE', 'active';

-- ═══ 1. Catalogue ══════════════════════════════════════════════════════════
INSERT INTO resultat
SELECT 1, 'anon : aucun droit de table sur les 4 tables', '(aucun)',
       coalesce(string_agg(t || ':' || p, ',' ORDER BY t, p), '(aucun)'),
       CASE WHEN count(*) = 0 THEN 'OK' ELSE 'ÉCHEC' END
  FROM unnest(ARRAY['audio_rooms','tips','room_tickets','creator_profiles']) t,
       unnest(ARRAY['SELECT','INSERT','UPDATE','DELETE','TRUNCATE','REFERENCES','TRIGGER']) p
 WHERE has_table_privilege('anon', 'public.' || t, p);

INSERT INTO resultat
SELECT 2, 'authenticated : aucune écriture sur tips / room_tickets / creator_profiles',
       '(aucune)',
       coalesce(string_agg(t || ':' || p, ',' ORDER BY t, p), '(aucune)'),
       CASE WHEN count(*) = 0 THEN 'OK' ELSE 'ÉCHEC' END
  FROM unnest(ARRAY['tips','room_tickets','creator_profiles']) t,
       unnest(ARRAY['INSERT','UPDATE','DELETE','TRUNCATE','REFERENCES','TRIGGER']) p
 WHERE has_table_privilege('authenticated', 'public.' || t, p);

INSERT INTO resultat
SELECT 3, 'audio_rooms : UPDATE limité aux 10 colonnes du client', '10 colonnes',
       count(*)::text || ' colonne(s) : '
         || coalesce(string_agg(column_name, ',' ORDER BY column_name), ''),
       CASE WHEN count(*) = 10 THEN 'OK' ELSE 'ÉCHEC' END
  FROM information_schema.column_privileges
 WHERE table_schema = 'public' AND table_name = 'audio_rooms'
   AND grantee = 'authenticated' AND privilege_type = 'UPDATE';

INSERT INTO resultat
SELECT 4, 'audio_rooms : hostId et ticketPrice hors du GRANT', '(absents)',
       coalesce(string_agg(column_name, ',' ORDER BY column_name), '(absents)'),
       CASE WHEN count(*) = 0 THEN 'OK' ELSE 'ÉCHEC' END
  FROM information_schema.column_privileges
 WHERE table_schema = 'public' AND table_name = 'audio_rooms'
   AND grantee = 'authenticated' AND privilege_type = 'UPDATE'
   AND column_name IN ('hostId', 'isPaid', 'ticketPrice', 'ticketCurrency',
                       'allowedUserIds', 'blockedUserIds');

INSERT INTO resultat
SELECT 5, 'plus de policy d''écriture cliente sur l''argent', '(aucune)',
       coalesce(string_agg(policyname, ',' ORDER BY policyname), '(aucune)'),
       CASE WHEN count(*) = 0 THEN 'OK' ELSE 'ÉCHEC' END
  FROM pg_policies
 WHERE schemaname = 'public'
   AND policyname IN ('creator_profiles_own', 'tips_insert_own',
                      'room_tickets_insert_own');

-- ═══ 2. L'intrus ═══════════════════════════════════════════════════════════
SELECT set_config('request.jwt.claims',
  jsonb_build_object('role', 'authenticated', 'app_metadata',
    jsonb_build_object('firebase_uid', (SELECT v FROM ctx WHERE k = 'intrus')))::text, true);
SET LOCAL ROLE authenticated;

-- LA FAILLE QUI ARMAIT `stripe-dashboard-link`.
DO $$
BEGIN
  INSERT INTO public.creator_profiles (user_id, stripe_account_id, stripe_account_status)
  VALUES ((SELECT v FROM ctx WHERE k = 'intrus'), 'acct_VICTIME', 'active');
  INSERT INTO resultat VALUES (6,
    'LA FAILLE — l''intrus se donne le compte Stripe d''autrui (dashboard-link)',
    'refusé 42501', 'ACCEPTÉ', 'ÉCHEC');
EXCEPTION WHEN insufficient_privilege THEN
  INSERT INTO resultat VALUES (6,
    'LA FAILLE — l''intrus se donne le compte Stripe d''autrui (dashboard-link)',
    'refusé 42501', 'refusé 42501', 'OK');
END $$;

-- LA FAILLE QUI OUVRAIT LES SALLES PAYANTES : `hasValidTicket` cherche un
-- billet « completed » ou « active ».
DO $$
BEGIN
  INSERT INTO public.room_tickets (room_id, user_id, amount, currency, status)
  VALUES ((SELECT v FROM ctx WHERE k = 'salle'),
          (SELECT v FROM ctx WHERE k = 'intrus'), 0, 'xof', 'completed');
  INSERT INTO resultat VALUES (7,
    'LA FAILLE — l''intrus s''offre un billet « completed » à 0',
    'refusé 42501', 'ACCEPTÉ', 'ÉCHEC');
EXCEPTION WHEN insufficient_privilege THEN
  INSERT INTO resultat VALUES (7,
    'LA FAILLE — l''intrus s''offre un billet « completed » à 0',
    'refusé 42501', 'refusé 42501', 'OK');
END $$;

DO $$
BEGIN
  INSERT INTO public.tips (room_id, sender_id, recipient_id, amount, currency, status)
  VALUES ((SELECT v FROM ctx WHERE k = 'salle'),
          (SELECT v FROM ctx WHERE k = 'intrus'),
          (SELECT v FROM ctx WHERE k = 'hote'), 9999999, 'xof', 'completed');
  INSERT INTO resultat VALUES (8,
    'LA FAILLE — l''intrus fabrique un pourboire « completed »',
    'refusé 42501', 'ACCEPTÉ', 'ÉCHEC');
EXCEPTION WHEN insufficient_privilege THEN
  INSERT INTO resultat VALUES (8,
    'LA FAILLE — l''intrus fabrique un pourboire « completed »',
    'refusé 42501', 'refusé 42501', 'OK');
END $$;

-- LA FAILLE DU PRIX : c'est PostgREST qui la portait, pas la fonction.
DO $$
BEGIN
  UPDATE public.audio_rooms SET "ticketPrice" = 1
   WHERE id = (SELECT v FROM ctx WHERE k = 'salle')::uuid;
  INSERT INTO resultat VALUES (9,
    'LA FAILLE — l''intrus met le billet d''autrui à 1',
    'refusé 42501', 'ACCEPTÉ', 'ÉCHEC');
EXCEPTION WHEN insufficient_privilege THEN
  INSERT INTO resultat VALUES (9,
    'LA FAILLE — l''intrus met le billet d''autrui à 1',
    'refusé 42501', 'refusé 42501', 'OK');
END $$;

DO $$
BEGIN
  UPDATE public.audio_rooms SET "hostId" = (SELECT v FROM ctx WHERE k = 'intrus')
   WHERE id = (SELECT v FROM ctx WHERE k = 'salle')::uuid;
  INSERT INTO resultat VALUES (10,
    'LA FAILLE — l''intrus se fait hôte de la salle d''autrui',
    'refusé 42501', 'ACCEPTÉ', 'ÉCHEC');
EXCEPTION WHEN insufficient_privilege THEN
  INSERT INTO resultat VALUES (10,
    'LA FAILLE — l''intrus se fait hôte de la salle d''autrui',
    'refusé 42501', 'refusé 42501', 'OK');
END $$;

-- L'intrus ne voit pas la fiche de créateur de l'hôte (non-régression).
DO $$
DECLARE n bigint;
BEGIN
  SELECT count(*) INTO n FROM public.creator_profiles
   WHERE user_id = (SELECT v FROM ctx WHERE k = 'hote');
  INSERT INTO resultat VALUES (11, 'l''intrus ne lit pas la fiche Stripe de l''hôte',
    '0', n::text, CASE WHEN n = 0 THEN 'OK' ELSE 'ÉCHEC' END);
EXCEPTION WHEN OTHERS THEN
  INSERT INTO resultat VALUES (11, 'l''intrus ne lit pas la fiche Stripe de l''hôte',
    '0', 'REFUSÉ ' || SQLSTATE, 'ÉCHEC');
END $$;

-- ═══ 3. Non-régression : l'hôte tient sa salle ═════════════════════════════
RESET ROLE;

-- REMISE D'APLOMB, ET ELLE N'EST PAS COSMÉTIQUE. Sans la migration, les cas
-- 9 et 10 RÉUSSISSENT : la salle sort de la section précédente avec un prix
-- à 1 et l'intrus pour hôte. Le cas 12 mesurerait alors autre chose que ce
-- qu'il annonce — et il échouerait pour une raison trompeuse, détaillée au
-- cas 12 bis. On repose donc l'état de départ, sous le rôle propriétaire.
UPDATE public.audio_rooms
   SET "hostId" = (SELECT v FROM ctx WHERE k = 'hote'),
       "ticketPrice" = 500000, status = 'live'
 WHERE id = (SELECT v FROM ctx WHERE k = 'salle')::uuid;

SELECT set_config('request.jwt.claims',
  jsonb_build_object('role', 'authenticated', 'app_metadata',
    jsonb_build_object('firebase_uid', (SELECT v FROM ctx WHERE k = 'hote')))::text, true);
SET LOCAL ROLE authenticated;

DO $$
DECLARE n bigint;
BEGIN
  UPDATE public.audio_rooms
     SET status = 'ended', "endedAt" = now(),
         "endedByAdmin" = false, "endReason" = 'banc'
   WHERE id = (SELECT v FROM ctx WHERE k = 'salle')::uuid;
  GET DIAGNOSTICS n = ROW_COUNT;
  INSERT INTO resultat VALUES (12, 'l''hôte ferme sa salle (status/endedAt/endReason)',
    '1 ligne', n::text || ' ligne(s)', CASE WHEN n = 1 THEN 'OK' ELSE 'ÉCHEC' END);
EXCEPTION WHEN OTHERS THEN
  INSERT INTO resultat VALUES (12, 'l''hôte ferme sa salle (status/endedAt/endReason)',
    '1 ligne', 'REFUSÉ ' || SQLSTATE || ' ' || SQLERRM, 'ÉCHEC');
END $$;

DO $$
DECLARE n bigint;
BEGIN
  UPDATE public.audio_rooms SET "mutedSpeakers" = '{"x":"now"}'::jsonb
   WHERE id = (SELECT v FROM ctx WHERE k = 'salle')::uuid;
  GET DIAGNOSTICS n = ROW_COUNT;
  INSERT INTO resultat VALUES (13, 'le micro coupé passe toujours (mutedSpeakers)',
    '1 ligne', n::text || ' ligne(s)', CASE WHEN n = 1 THEN 'OK' ELSE 'ÉCHEC' END);
EXCEPTION WHEN OTHERS THEN
  INSERT INTO resultat VALUES (13, 'le micro coupé passe toujours (mutedSpeakers)',
    '1 ligne', 'REFUSÉ ' || SQLSTATE || ' ' || SQLERRM, 'ÉCHEC');
END $$;

DO $$
DECLARE n bigint;
BEGIN
  SELECT count(*) INTO n FROM public.creator_profiles
   WHERE user_id = (SELECT v FROM ctx WHERE k = 'hote');
  INSERT INTO resultat VALUES (14, 'l''hôte lit toujours SA fiche de créateur',
    '1', n::text, CASE WHEN n = 1 THEN 'OK' ELSE 'ÉCHEC' END);
EXCEPTION WHEN OTHERS THEN
  INSERT INTO resultat VALUES (14, 'l''hôte lit toujours SA fiche de créateur',
    '1', 'REFUSÉ ' || SQLSTATE, 'ÉCHEC');
END $$;

DO $$
DECLARE n bigint;
BEGIN
  INSERT INTO public.audio_rooms (title, "hostId", "hostName", status)
  VALUES ('Salle neuve du banc', (SELECT v FROM ctx WHERE k = 'hote'), 'Hôte', 'scheduled');
  GET DIAGNOSTICS n = ROW_COUNT;
  INSERT INTO resultat VALUES (15, 'l''hôte crée toujours une salle',
    '1 ligne', n::text || ' ligne(s)', CASE WHEN n = 1 THEN 'OK' ELSE 'ÉCHEC' END);
EXCEPTION WHEN OTHERS THEN
  INSERT INTO resultat VALUES (15, 'l''hôte crée toujours une salle',
    '1 ligne', 'REFUSÉ ' || SQLSTATE || ' ' || SQLERRM, 'ÉCHEC');
END $$;

RESET ROLE;

-- ═══ 3 bis. Ce que la fermeture PAR COLONNES ne couvre pas ═════════════════
-- Ces deux cas MESURENT au lieu d'affirmer : ils rendent « MESURE », jamais
-- « ÉCHEC ». Ils existent pour que l'état réel soit écrit noir sur blanc, et
-- relu le jour où le drapeau `audioRooms` s'ouvrira.
--
-- REMISE D'APLOMB, ENCORE, et pour une raison qui vaut d'être écrite : le cas
-- 12 vient de passer la salle à 'ended', et une salle terminée est INVISIBLE
-- à qui n'en est pas. Sans ce reset, les deux cas ci-dessous ne touchent
-- aucune ligne et rendent « ACCEPTÉ » — une réussite à vide, qui ment dans le
-- sens rassurant. C'est pourquoi ils comptent tous deux leurs lignes.
UPDATE public.audio_rooms
   SET status = 'live', "isPrivate" = false, "endedByAdmin" = false
 WHERE id = (SELECT v FROM ctx WHERE k = 'salle')::uuid;

SELECT set_config('request.jwt.claims',
  jsonb_build_object('role', 'authenticated', 'app_metadata',
    jsonb_build_object('firebase_uid', (SELECT v FROM ctx WHERE k = 'intrus')))::text, true);
SET LOCAL ROLE authenticated;

-- `audio_rooms_update` reste `USING (firebase_uid() IS NOT NULL)` : la
-- restriction posée est celle des COLONNES, pas celle de la LIGNE. Un compte
-- quelconque peut donc encore remuer les dix colonnes autorisées sur la salle
-- d'autrui — nuisance, plus argent. Refermer la ligne demande des RPC par
-- geste (rejoindre, couper un micro, avertir), pas un `REVOKE`.
--
-- La colonne choisie compte, et c'est instructif : `isPrivate`, comme le
-- passage à 'ended', est REFUSÉ à l'intrus — non par une garde voulue, mais
-- par effet de bord de `audio_rooms_select` (mécanisme au cas 18).
-- `mutedSpeakers` n'apparaît dans aucune policy : il reste grand ouvert, et
-- couper le micro d'un intervenant dans la salle d'un autre est précisément
-- le geste qu'on redoute.
DO $$
DECLARE n bigint;
BEGIN
  UPDATE public.audio_rooms SET "mutedSpeakers" = '{"victime":"now"}'::jsonb
   WHERE id = (SELECT v FROM ctx WHERE k = 'salle')::uuid;
  GET DIAGNOSTICS n = ROW_COUNT;
  INSERT INTO resultat VALUES (17,
    'MESURE — l''intrus remue encore une colonne autorisée de la salle d''autrui',
    'connu : accepté', n::text || ' ligne(s) touchée(s)', 'MESURE');
EXCEPTION WHEN OTHERS THEN
  INSERT INTO resultat VALUES (17,
    'MESURE — l''intrus remue encore une colonne autorisée de la salle d''autrui',
    'connu : accepté', 'refusé ' || SQLSTATE, 'MESURE');
END $$;

-- PANNE PRÉEXISTANTE, ni causée ni réparée par la migration, et de la même
-- famille que la résolution de litige de `orders` (2026-09-21) : Postgres
-- applique les policies de SELECT à la NOUVELLE ligne d'un UPDATE, pour
-- qu'on ne puisse pas pousser une ligne hors de sa propre vue.
-- `audio_rooms_select` ne montre une salle terminée qu'à l'hôte, aux
-- co-hôtes, aux modérateurs et aux invités. Donc `forceEndRoom`
-- (audio_room_remote_datasource.dart:575), qui pose `status='ended'`, est
-- REFUSÉ à tout administrateur qui n'est pas de la salle — et il n'y a
-- aucune branche `is_admin()` dans cette policy.
-- Vérifié à part : le même compte passant la salle à 'scheduled' est accepté.
DO $$
DECLARE n bigint;
BEGIN
  UPDATE public.audio_rooms SET status = 'ended', "endedByAdmin" = true
   WHERE id = (SELECT v FROM ctx WHERE k = 'salle')::uuid;
  GET DIAGNOSTICS n = ROW_COUNT;
  INSERT INTO resultat VALUES (18,
    'MESURE — forceEndRoom par un non-membre (panne préexistante)',
    'connu : refusé 42501', 'ACCEPTÉ, ' || n::text || ' ligne(s)', 'MESURE');
EXCEPTION WHEN OTHERS THEN
  INSERT INTO resultat VALUES (18,
    'MESURE — forceEndRoom par un non-membre (panne préexistante)',
    'connu : refusé 42501', 'refusé ' || SQLSTATE, 'MESURE');
END $$;

RESET ROLE;

-- ═══ 4. Le serveur garde tout ══════════════════════════════════════════════
-- `stripe-connect-onboarding` et `stripe-connect-webhook` écrivent sous le
-- rôle de service, qui ignore le RLS : le chemin légitime reste entier.
DO $$
DECLARE n bigint;
BEGIN
  UPDATE public.creator_profiles
     SET stripe_account_status = 'active', total_earnings = 42
   WHERE user_id = (SELECT v FROM ctx WHERE k = 'hote');
  GET DIAGNOSTICS n = ROW_COUNT;
  INSERT INTO resultat VALUES (16, 'le serveur écrit toujours la fiche de créateur',
    '1 ligne', n::text || ' ligne(s)', CASE WHEN n = 1 THEN 'OK' ELSE 'ÉCHEC' END);
EXCEPTION WHEN OTHERS THEN
  INSERT INTO resultat VALUES (16, 'le serveur écrit toujours la fiche de créateur',
    '1 ligne', 'REFUSÉ ' || SQLSTATE || ' ' || SQLERRM, 'ÉCHEC');
END $$;

-- ═══ Rapport ═══════════════════════════════════════════════════════════════
SELECT n, verdict, cas, attendu, obtenu FROM resultat ORDER BY n;

ROLLBACK;
