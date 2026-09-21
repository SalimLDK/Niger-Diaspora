-- Banc de PRÉPARATION : la cible `supabase/users-colonnes-privees-cible.sql`
-- (fermeture 1.1b de l'audit — un compte connecté lit e-mail, téléphone,
-- position et jetons push d'autrui).
--
-- DEUX USAGES, ET ILS DISENT DES CHOSES DIFFÉRENTES.
--
--   · Tel quel, sur l'état vivant :
--       supabase db query --linked -f tools/rls_tests/users_colonnes_privees_cible.sql
--     La section A ÉCHOUE — c'est le trou, mesuré. B tient. C rend
--     « accepté » : les builds installés marchent.
--
--   · En répétition de la cible, ce qui ne se fait QUE par l'outil :
--       python tools/rls_tests/repeter_cible.py \
--         tools/rls_tests/users_colonnes_privees_cible.sql \
--         supabase/users-colonnes-privees-cible.sql  <sortie.sql>
--       supabase db query --linked -f <sortie.sql>
--     A doit passer (la cible ferme), B doit passer (rien d'autre ne casse),
--     et C rend « refusé » : c'est la JAUGE de ce que les builds installés
--     perdraient. Tant que C refuse, la cible ne s'applique pas — la version
--     cliente doit d'abord cesser de faire ce que C mesure.
--
-- Ne JAMAIS injecter la cible à la main : l'outil refuse un texte qui
-- contient `COMMIT`, qui validerait la fermeture en production au milieu de
-- la répétition.
--
-- LES PROFILS D'ESSAI sont posés près du pôle Nord et annulés par le
-- `ROLLBACK`, pays et ville vides pour que les déclencheurs de groupe de
-- ville n'aient rien à faire.

BEGIN;

SET LOCAL lock_timeout = '5s';

CREATE TEMP TABLE resultat(n text, cas text, attendu text, obtenu text, verdict text);
CREATE TEMP TABLE ctx(k text PRIMARY KEY, v text);
GRANT ALL ON resultat, ctx TO anon, authenticated;

INSERT INTO ctx SELECT 'admin', id FROM public.users WHERE is_admin LIMIT 1;

INSERT INTO public.users
       (id, display_name, email, phone_number, phone_visibility,
        share_location, is_visible, is_private,
        latitude, longitude, location_updated_at,
        fcm_tokens, session_id)
VALUES
  ('banc-cible-moi',   'Moi',   'moi@banc',   '+22790000001', 'private',
   true,  true, false, 89.00, 179.00, now(), '["jeton-moi"]'::jsonb,   'session-moi'),
  ('banc-cible-tiers', 'Tiers', 'tiers@banc', '+22790000002', 'private',
   false, true, false, 89.01, 179.01, now(), '["jeton-tiers"]'::jsonb, 'session-tiers');

-- @@CIBLE@@

-- ═══ Catalogue ═════════════════════════════════════════════════════════════
INSERT INTO resultat
SELECT 'A0', 'authenticated ne lit AUCUNE des 14 colonnes sensibles',
       '(aucune)',
       coalesce(string_agg(c, ',' ORDER BY c), '(aucune)'),
       CASE WHEN count(*) = 0 THEN 'OK' ELSE 'ÉCHEC' END
  FROM unnest(ARRAY['email','phone_number','latitude','longitude',
                    'location_updated_at','fcm_tokens','voip_token',
                    'last_token_update','session_id','cart_data',
                    'ban_reason','banned_at','banned_by','admin_role']) c
 WHERE has_column_privilege('authenticated', 'public.users', c, 'SELECT');

-- La contrainte qu'il ne faut jamais oublier : deux policies d'AUTRES tables
-- lisent `id` et `is_admin` sous le rôle de l'appelant.
INSERT INTO resultat
SELECT 'B0', 'id et is_admin restent accordés (content_reports, mls_diagnostics)',
       'les deux',
       concat_ws(',',
         CASE WHEN has_column_privilege('authenticated','public.users','id','SELECT')       THEN 'id' END,
         CASE WHEN has_column_privilege('authenticated','public.users','is_admin','SELECT') THEN 'is_admin' END),
       CASE WHEN has_column_privilege('authenticated','public.users','id','SELECT')
             AND has_column_privilege('authenticated','public.users','is_admin','SELECT')
            THEN 'OK' ELSE 'ÉCHEC' END;

-- ═══ Sous l'identité d'un compte ordinaire ═════════════════════════════════
SELECT set_config('request.jwt.claims',
  jsonb_build_object('role', 'authenticated', 'app_metadata',
    jsonb_build_object('firebase_uid', 'banc-cible-moi'))::text, true);
SET LOCAL ROLE authenticated;

-- ── A. Ce que la cible FERME ───────────────────────────────────────────────
-- Chaque cas lit la ligne d'un TIERS. Sur l'état vivant, tous réussissent :
-- c'est le trou.
DO $$
DECLARE v text;
BEGIN
  SELECT email INTO v FROM public.users WHERE id = 'banc-cible-tiers';
  INSERT INTO resultat VALUES ('A1', 'l''e-mail d''un tiers', 'refusé 42501',
    'LU : ' || coalesce(v, '∅'), 'ÉCHEC');
EXCEPTION WHEN insufficient_privilege THEN
  INSERT INTO resultat VALUES ('A1', 'l''e-mail d''un tiers', 'refusé 42501', 'refusé 42501', 'OK');
END $$;

DO $$
DECLARE v text;
BEGIN
  SELECT latitude::text || ',' || longitude::text INTO v
    FROM public.users WHERE id = 'banc-cible-tiers';
  INSERT INTO resultat VALUES ('A2',
    'la position d''un tiers QUI A COUPÉ LE PARTAGE', 'refusé 42501',
    'LU : ' || coalesce(v, '∅'), 'ÉCHEC');
EXCEPTION WHEN insufficient_privilege THEN
  INSERT INTO resultat VALUES ('A2',
    'la position d''un tiers QUI A COUPÉ LE PARTAGE', 'refusé 42501', 'refusé 42501', 'OK');
END $$;

DO $$
DECLARE v text;
BEGIN
  SELECT fcm_tokens::text INTO v FROM public.users WHERE id = 'banc-cible-tiers';
  INSERT INTO resultat VALUES ('A3', 'les jetons push d''un tiers', 'refusé 42501',
    'LU : ' || coalesce(v, '∅'), 'ÉCHEC');
EXCEPTION WHEN insufficient_privilege THEN
  INSERT INTO resultat VALUES ('A3', 'les jetons push d''un tiers', 'refusé 42501', 'refusé 42501', 'OK');
END $$;

DO $$
DECLARE v text;
BEGIN
  SELECT session_id INTO v FROM public.users WHERE id = 'banc-cible-tiers';
  INSERT INTO resultat VALUES ('A4', 'l''identifiant de session d''un tiers', 'refusé 42501',
    'LU : ' || coalesce(v, '∅'), 'ÉCHEC');
EXCEPTION WHEN insufficient_privilege THEN
  INSERT INTO resultat VALUES ('A4', 'l''identifiant de session d''un tiers', 'refusé 42501', 'refusé 42501', 'OK');
END $$;

-- L'oracle : sans lire l'e-mail, le DEVINER par un filtre. Un droit de
-- colonne couvre aussi le WHERE — sinon on énumérerait les adresses une à une.
DO $$
DECLARE n bigint;
BEGIN
  SELECT count(*) INTO n FROM public.users WHERE email = 'tiers@banc';
  INSERT INTO resultat VALUES ('A5', 'deviner un e-mail par filtre (WHERE email = …)',
    'refusé 42501', 'répond : ' || n::text || ' ligne(s)', 'ÉCHEC');
EXCEPTION WHEN insufficient_privilege THEN
  INSERT INTO resultat VALUES ('A5', 'deviner un e-mail par filtre (WHERE email = …)',
    'refusé 42501', 'refusé 42501', 'OK');
END $$;

-- ── B. Ce qui doit TENIR ───────────────────────────────────────────────────
DO $$
DECLARE n bigint;
BEGIN
  SELECT count(*) INTO n FROM (
    SELECT id, display_name, avatar_url, city, is_admin, is_banned,
           share_location, phone_visibility, is_online
      FROM public.users WHERE id = 'banc-cible-tiers') s;
  INSERT INTO resultat VALUES ('B1', 'le profil PUBLIC d''un tiers se lit toujours',
    '1', n::text, CASE WHEN n = 1 THEN 'OK' ELSE 'ÉCHEC' END);
EXCEPTION WHEN OTHERS THEN
  INSERT INTO resultat VALUES ('B1', 'le profil PUBLIC d''un tiers se lit toujours',
    '1', 'REFUSÉ ' || SQLSTATE, 'ÉCHEC');
END $$;

-- L'hypothèse dont tout dépend : une fonction SECURITY DEFINER qui rend
-- `SETOF users` sert les colonnes révoquées à son appelant.
DO $$
DECLARE mel text; ses text;
BEGIN
  SELECT email, session_id INTO mel, ses FROM public.mon_profil_prive();
  INSERT INTO resultat VALUES ('B2',
    'mon_profil_prive() rend SES colonnes révoquées (e-mail, session)',
    'moi@banc · session-moi', coalesce(mel,'∅') || ' · ' || coalesce(ses,'∅'),
    CASE WHEN mel = 'moi@banc' AND ses = 'session-moi' THEN 'OK' ELSE 'ÉCHEC' END);
EXCEPTION WHEN OTHERS THEN
  INSERT INTO resultat VALUES ('B2',
    'mon_profil_prive() rend SES colonnes révoquées (e-mail, session)',
    'moi@banc · session-moi', 'REFUSÉ ' || SQLSTATE || ' ' || SQLERRM, 'ÉCHEC');
END $$;

DO $$
DECLARE ids text;
BEGIN
  SELECT string_agg(id, ',' ORDER BY id) INTO ids
    FROM public.positions_partagees(88.9, 89.1, 178.9, 179.1);
  INSERT INTO resultat VALUES ('B3',
    'positions_partagees() : soi seul — le tiers a coupé le partage',
    'banc-cible-moi', coalesce(ids, '(rien)'),
    CASE WHEN ids = 'banc-cible-moi' THEN 'OK' ELSE 'ÉCHEC' END);
EXCEPTION WHEN OTHERS THEN
  INSERT INTO resultat VALUES ('B3',
    'positions_partagees() : soi seul — le tiers a coupé le partage',
    'banc-cible-moi', 'REFUSÉ ' || SQLSTATE, 'ÉCHEC');
END $$;

-- Deux tables AILLEURS dont une policy lit `users` sous le rôle de l'appelant.
DO $$
DECLARE a bigint; b bigint;
BEGIN
  SELECT count(*) INTO a FROM public.content_reports;
  SELECT count(*) INTO b FROM public.mls_diagnostics;
  INSERT INTO resultat VALUES ('B4',
    'content_reports et mls_diagnostics se lisent toujours (policies sur users)',
    'sans refus', 'lu (' || a::text || ' / ' || b::text || ')', 'OK');
EXCEPTION WHEN OTHERS THEN
  INSERT INTO resultat VALUES ('B4',
    'content_reports et mls_diagnostics se lisent toujours (policies sur users)',
    'sans refus', 'REFUSÉ ' || SQLSTATE || ' ' || SQLERRM, 'ÉCHEC');
END $$;

-- Ce que la cible garde accordé EXPRÈS : l'éjection des bannis et l'onboarding.
DO $$
DECLARE b boolean; o boolean;
BEGIN
  SELECT is_banned, has_seen_onboarding INTO b, o
    FROM public.users WHERE id = 'banc-cible-moi';
  INSERT INTO resultat VALUES ('B5',
    'is_banned et has_seen_onboarding de sa ligne se lisent toujours',
    'sans refus', 'lu', 'OK');
EXCEPTION WHEN OTHERS THEN
  INSERT INTO resultat VALUES ('B5',
    'is_banned et has_seen_onboarding de sa ligne se lisent toujours',
    'sans refus', 'REFUSÉ ' || SQLSTATE, 'ÉCHEC');
END $$;

-- ── C. La JAUGE : ce que les builds installés font, et perdraient ──────────
-- Ces cas MESURENT. « accepté » = le build installé marche encore ;
-- « refusé » = il casserait. La cible ne s'applique que quand la version
-- cliente a cessé de faire tout ce qui est listé ici.
DO $$
BEGIN
  PERFORM * FROM public.users WHERE id = 'banc-cible-moi';
  INSERT INTO resultat VALUES ('C1', 'MESURE — select() nu sur sa propre ligne (getProfile, 11 sites)',
    '-', 'accepté', 'MESURE');
EXCEPTION WHEN insufficient_privilege THEN
  INSERT INTO resultat VALUES ('C1', 'MESURE — select() nu sur sa propre ligne (getProfile, 11 sites)',
    '-', 'REFUSÉ 42501', 'MESURE');
END $$;

-- En CTE : c'est d'ailleurs la forme que PostgREST émet pour un upsert suivi
-- de `.select()`. (Un `INSERT` en sous-requête `FROM` est une erreur de
-- SYNTAXE, levée à la compilation du bloc — aucun `EXCEPTION` ne l'attrape, et
-- la première version de ce banc s'est arrêtée net dessus.)
DO $$
DECLARE n bigint;
BEGIN
  WITH r AS (
    INSERT INTO public.users (id, display_name) VALUES ('banc-cible-moi', 'Moi retouché')
    ON CONFLICT (id) DO UPDATE SET display_name = EXCLUDED.display_name
    RETURNING *)
  SELECT count(*) INTO n FROM r;
  INSERT INTO resultat VALUES ('C2', 'MESURE — upsert … RETURNING * (updateProfile)',
    '-', 'accepté', 'MESURE');
EXCEPTION WHEN insufficient_privilege THEN
  INSERT INTO resultat VALUES ('C2', 'MESURE — upsert … RETURNING * (updateProfile)',
    '-', 'REFUSÉ 42501', 'MESURE');
END $$;

DO $$
BEGIN
  PERFORM fcm_tokens FROM public.users WHERE id = 'banc-cible-moi';
  INSERT INTO resultat VALUES ('C3', 'MESURE — ses jetons push (enregistrement FCM, 2 sites)',
    '-', 'accepté', 'MESURE');
EXCEPTION WHEN insufficient_privilege THEN
  INSERT INTO resultat VALUES ('C3', 'MESURE — ses jetons push (enregistrement FCM, 2 sites)',
    '-', 'REFUSÉ 42501', 'MESURE');
END $$;

DO $$
BEGIN
  PERFORM session_id, is_banned FROM public.users WHERE id = 'banc-cible-moi';
  INSERT INTO resultat VALUES ('C4', 'MESURE — sa session (session_service.dart:300)',
    '-', 'accepté', 'MESURE');
EXCEPTION WHEN insufficient_privilege THEN
  INSERT INTO resultat VALUES ('C4', 'MESURE — sa session (session_service.dart:300)',
    '-', 'REFUSÉ 42501', 'MESURE');
END $$;

-- ── D. Ce que la NOUVELLE version cliente émet ─────────────────────────────
-- Commit da15fbc : chaque forme de requête que l'app envoie désormais sur
-- `users`, reproduite telle que PostgREST l'émet. Ces cas doivent passer SUR
-- L'ÉTAT VIVANT ET SOUS LA CIBLE — c'est la preuve que la version cliente
-- survivra à la fermeture. (C mesure l'ancienne version ; D, la nouvelle.)
DO $$
DECLARE n bigint;
BEGIN
  SELECT count(*) INTO n FROM (
    SELECT id, firebase_uid, display_name, display_name_lower, handle,
           avatar_url, bio, profession, country_code, city, ville_id,
           current_region, origin_region, origin_city,
           is_private, is_visible, is_verified, is_admin, is_banned,
           follower_count, following_count, post_count,
           connections_count, groups_count, events_count,
           interests, skills, languages,
           is_online, last_seen_at, last_active_at, show_online_status,
           share_location, phone_visibility, is_phone_verified,
           notifications_enabled, notify_local_events, show_message_preview,
           notification_prefs,
           has_seen_onboarding, has_seen_coach_marks, has_given_consent,
           consent_date, profile_config_complete,
           created_at, updated_at
      FROM public.users WHERE id = 'banc-cible-tiers') s;
  INSERT INTO resultat VALUES ('D1', 'selectPublicUsers sur la ligne d''un tiers (46 colonnes)',
    '1', n::text, CASE WHEN n = 1 THEN 'OK' ELSE 'ÉCHEC' END);
EXCEPTION WHEN OTHERS THEN
  INSERT INTO resultat VALUES ('D1', 'selectPublicUsers sur la ligne d''un tiers (46 colonnes)',
    '1', 'REFUSÉ ' || SQLSTATE || ' ' || SQLERRM, 'ÉCHEC');
END $$;

-- getProfilesByCountry : filtre et tri sur des colonnes accordées seulement.
DO $$
DECLARE n bigint;
BEGIN
  SELECT count(*) INTO n FROM (
    SELECT id FROM public.users
     WHERE country_code IS NULL AND is_visible
     ORDER BY last_active_at DESC NULLS LAST LIMIT 50) s;
  INSERT INTO resultat VALUES ('D2', 'mode pays : filtre pays, tri last_active_at',
    'sans refus', 'lu (' || n::text || ')', 'OK');
EXCEPTION WHEN OTHERS THEN
  INSERT INTO resultat VALUES ('D2', 'mode pays : filtre pays, tri last_active_at',
    'sans refus', 'REFUSÉ ' || SQLSTATE || ' ' || SQLERRM, 'ÉCHEC');
END $$;

DO $$
DECLARE ids text;
BEGIN
  SELECT string_agg(id, ',' ORDER BY id) INTO ids
    FROM public.positions_partagees_par_ids(ARRAY['banc-cible-moi', 'banc-cible-tiers']);
  INSERT INTO resultat VALUES ('D3', 'positions_partagees_par_ids() : soi seul (le tiers a coupé)',
    'banc-cible-moi', coalesce(ids, '(rien)'),
    CASE WHEN ids = 'banc-cible-moi' THEN 'OK' ELSE 'ÉCHEC' END);
EXCEPTION WHEN OTHERS THEN
  INSERT INTO resultat VALUES ('D3', 'positions_partagees_par_ids() : soi seul (le tiers a coupé)',
    'banc-cible-moi', 'REFUSÉ ' || SQLSTATE, 'ÉCHEC');
END $$;

-- LE site le plus dangereux : l'enregistrement du jeton push.
DO $$
DECLARE j jsonb;
BEGIN
  PERFORM public.ajouter_jeton_push('jeton-neuf');
  PERFORM public.retirer_jeton_push('jeton-moi');
  SELECT fcm_tokens INTO j FROM public.mon_profil_prive();
  INSERT INTO resultat VALUES ('D4', 'jeton push : ajouter puis retirer, sans jamais le relire',
    '["jeton-neuf"]', coalesce(j::text, '∅'),
    CASE WHEN j = '["jeton-neuf"]'::jsonb THEN 'OK' ELSE 'ÉCHEC' END);
EXCEPTION WHEN OTHERS THEN
  INSERT INTO resultat VALUES ('D4', 'jeton push : ajouter puis retirer, sans jamais le relire',
    '["jeton-neuf"]', 'REFUSÉ ' || SQLSTATE || ' ' || SQLERRM, 'ÉCHEC');
END $$;

-- LA QUESTION QUI ÉTAIT OUVERTE, TRANCHÉE ICI LE 2026-09-21 : OUI.
-- PostgREST émet un upsert en `ON CONFLICT (id) DO UPDATE SET col =
-- EXCLUDED.col` pour CHAQUE colonne du corps, et évaluer `EXCLUDED.col`
-- exige le droit de LIRE la colonne. Sous la cible, ces deux formes tombent
-- en 42501 — celles de da15fbc, qui cassaient la connexion et
-- l'enregistrement du profil. Une sonde a isolé la cause : ni l'écriture,
-- ni `RETURNING id`, ni `INSERT` simple ; seulement la référence
-- `EXCLUDED.<colonne révoquée>`. Elles restent ici en MESURE.
DO $$
DECLARE n bigint;
BEGIN
  WITH r AS (
    INSERT INTO public.users AS u (id, display_name, avatar_url, phone_number,
                                   bio, is_visible, share_location,
                                   phone_visibility, updated_at)
    VALUES ('banc-cible-moi', 'Moi retouché', NULL, '+22790000009',
            'bio', true, true, 'private', now())
    ON CONFLICT (id) DO UPDATE SET
      id = EXCLUDED.id, display_name = EXCLUDED.display_name,
      avatar_url = EXCLUDED.avatar_url, phone_number = EXCLUDED.phone_number,
      bio = EXCLUDED.bio, is_visible = EXCLUDED.is_visible,
      share_location = EXCLUDED.share_location,
      phone_visibility = EXCLUDED.phone_visibility,
      updated_at = EXCLUDED.updated_at
    RETURNING u.id)
  SELECT count(*) INTO n FROM r;
  INSERT INTO resultat VALUES ('C5',
    'MESURE — upsert écrivant phone_number (da15fbc, abandonné)',
    '1', n::text, 'MESURE');
EXCEPTION WHEN OTHERS THEN
  INSERT INTO resultat VALUES ('C5',
    'MESURE — upsert écrivant phone_number (da15fbc, abandonné)',
    '1', 'REFUSÉ ' || SQLSTATE || ' ' || SQLERRM, 'MESURE');
END $$;

-- La connexion (`_upsertUserToSupabase`) : e-mail et téléphone, sans RETURNING.
DO $$
BEGIN
  INSERT INTO public.users AS u (id, email, display_name, avatar_url, phone_number, updated_at)
  VALUES ('banc-cible-moi', 'moi@banc', 'Moi', NULL, '+22790000001', now())
  ON CONFLICT (id) DO UPDATE SET
    id = EXCLUDED.id, email = EXCLUDED.email,
    display_name = EXCLUDED.display_name, avatar_url = EXCLUDED.avatar_url,
    phone_number = EXCLUDED.phone_number, updated_at = EXCLUDED.updated_at;
  INSERT INTO resultat VALUES ('C6', 'MESURE — upsert écrivant e-mail + téléphone (da15fbc, abandonné)',
    '-', 'accepté', 'MESURE');
EXCEPTION WHEN OTHERS THEN
  INSERT INTO resultat VALUES ('C6', 'MESURE — upsert écrivant e-mail + téléphone (da15fbc, abandonné)',
    '-', 'REFUSÉ ' || SQLSTATE, 'MESURE');
END $$;

-- CE QUE LE CLIENT FAIT À LA PLACE (`ecrireSaLigneUsers`) : un UPDATE de sa
-- ligne, puis un INSERT simple si elle n'existe pas encore. Aucune des deux
-- formes ne lit les colonnes qu'elle écrit.
DO $$
DECLARE n bigint;
BEGIN
  WITH r AS (
    UPDATE public.users
       SET display_name = 'Moi retouché', phone_number = '+22790000009',
           email = 'moi@banc', bio = 'bio', updated_at = now()
     WHERE id = 'banc-cible-moi'
    RETURNING id)
  SELECT count(*) INTO n FROM r;
  INSERT INTO resultat VALUES ('D5',
    'ecrireSaLigneUsers : UPDATE (e-mail, téléphone) … RETURNING id',
    '1', n::text, CASE WHEN n = 1 THEN 'OK' ELSE 'ÉCHEC' END);
EXCEPTION WHEN OTHERS THEN
  INSERT INTO resultat VALUES ('D5',
    'ecrireSaLigneUsers : UPDATE (e-mail, téléphone) … RETURNING id',
    '1', 'REFUSÉ ' || SQLSTATE || ' ' || SQLERRM, 'ÉCHEC');
END $$;

-- Les écritures ciblées de colonnes révoquées : session, VoIP, position.
DO $$
DECLARE n bigint; total bigint := 0;
BEGIN
  UPDATE public.users SET session_id = 'session-neuve' WHERE id = 'banc-cible-moi';
  GET DIAGNOSTICS n = ROW_COUNT; total := total + n;
  UPDATE public.users SET voip_token = 'voip', last_token_update = now()
   WHERE id = 'banc-cible-moi';
  GET DIAGNOSTICS n = ROW_COUNT; total := total + n;
  UPDATE public.users SET latitude = 89.005, longitude = 179.005,
                          location_updated_at = now()
   WHERE id = 'banc-cible-moi';
  GET DIAGNOSTICS n = ROW_COUNT; total := total + n;
  INSERT INTO resultat VALUES ('D7',
    'session, jeton VoIP et position : UPDATE ciblés de colonnes révoquées',
    '3 lignes', total::text || ' ligne(s)', CASE WHEN total = 3 THEN 'OK' ELSE 'ÉCHEC' END);
EXCEPTION WHEN OTHERS THEN
  INSERT INTO resultat VALUES ('D7',
    'session, jeton VoIP et position : UPDATE ciblés de colonnes révoquées',
    '3 lignes', 'REFUSÉ ' || SQLSTATE || ' ' || SQLERRM, 'ÉCHEC');
END $$;

-- Le guetteur de session relit sa décision par la RPC, projection comprise.
DO $$
DECLARE ses text;
BEGIN
  SELECT session_id INTO ses
    FROM (SELECT id, session_id, is_banned FROM public.mon_profil_prive()) s;
  INSERT INTO resultat VALUES ('D8', 'guetteur de session : mon_profil_prive() → session_id',
    'session-neuve', coalesce(ses, '∅'),
    CASE WHEN ses = 'session-neuve' THEN 'OK' ELSE 'ÉCHEC' END);
EXCEPTION WHEN OTHERS THEN
  INSERT INTO resultat VALUES ('D8', 'guetteur de session : mon_profil_prive() → session_id',
    'session-neuve', 'REFUSÉ ' || SQLSTATE, 'ÉCHEC');
END $$;

RESET ROLE;

-- D6 : le premier enregistrement d'un compte neuf — INSERT simple de SA
-- ligne, e-mail et téléphone compris, sous sa propre identité.
SELECT set_config('request.jwt.claims',
  jsonb_build_object('role', 'authenticated', 'app_metadata',
    jsonb_build_object('firebase_uid', 'banc-cible-neuf'))::text, true);
SET LOCAL ROLE authenticated;

DO $$
DECLARE n bigint;
BEGIN
  WITH r AS (
    INSERT INTO public.users (id, email, display_name, phone_number, updated_at)
    VALUES ('banc-cible-neuf', 'neuf@banc', 'Neuf', '+22790000010', now())
    RETURNING id)
  SELECT count(*) INTO n FROM r;
  INSERT INTO resultat VALUES ('D6',
    'ecrireSaLigneUsers : INSERT d''un compte neuf (e-mail, tél.) RETURNING id',
    '1', n::text, CASE WHEN n = 1 THEN 'OK' ELSE 'ÉCHEC' END);
EXCEPTION WHEN OTHERS THEN
  INSERT INTO resultat VALUES ('D6',
    'ecrireSaLigneUsers : INSERT d''un compte neuf (e-mail, tél.) RETURNING id',
    '1', 'REFUSÉ ' || SQLSTATE || ' ' || SQLERRM, 'ÉCHEC');
END $$;

RESET ROLE;

-- ═══ Le back-office ════════════════════════════════════════════════════════
SELECT set_config('request.jwt.claims',
  jsonb_build_object('role', 'authenticated', 'app_metadata',
    jsonb_build_object('firebase_uid',
      coalesce((SELECT v FROM ctx WHERE k = 'admin'), 'aucun-admin')))::text, true);
SET LOCAL ROLE authenticated;

DO $$
DECLARE n bigint; mel bigint;
BEGIN
  SELECT count(*), count(email) INTO n, mel FROM public.profils_admin(20);
  INSERT INTO resultat VALUES ('B6', 'admin : profils_admin() sert les e-mails malgré le REVOKE',
    '20 · e-mails présents', n::text || ' · ' || mel::text || ' e-mails',
    CASE WHEN n = 20 AND mel > 0 THEN 'OK' ELSE 'ÉCHEC' END);
EXCEPTION WHEN OTHERS THEN
  INSERT INTO resultat VALUES ('B6', 'admin : profils_admin() sert les e-mails malgré le REVOKE',
    '20 · e-mails présents', 'REFUSÉ ' || SQLSTATE, 'ÉCHEC');
END $$;

RESET ROLE;

-- ═══ Rapport ═══════════════════════════════════════════════════════════════
SELECT n, verdict, cas, attendu, obtenu FROM resultat ORDER BY n;

ROLLBACK;
