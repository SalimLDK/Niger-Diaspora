-- Banc : registre MLS servi aux seuls interlocuteurs, KeyPackages réclamables
-- par eux seuls (migration 20261008090000).
--
--   supabase db query --linked -f tools/rls_tests/mls_registre_entre_interlocuteurs.sql
--
-- Condition : 0 cas en ÉCHEC. Tout est dans un `BEGIN … ROLLBACK`.
--
-- AVANT `db push` : remplacer la ligne seule `-- @@MIGRATION@@` par le contenu
-- de la migration. APRÈS, lancé tel quel, le banc prouve l'état vivant.
-- Sans la migration, les cas 3, 5 et 7 sont en ÉCHEC (lecture et
-- réclamation ouvertes à tous).
--
-- AUCUNE NOTIFICATION : comptes, conversation, appareils et paquets sont
-- fabriqués ; rien n'insère dans `messages` ni `notifications`.

BEGIN;

SET LOCAL lock_timeout = '5s';

CREATE TEMP TABLE resultat(n int, cas text, attendu text, obtenu text, verdict text);
GRANT ALL ON resultat TO authenticated;

-- A et B partagent une conversation ; C est un inconnu pour A.
INSERT INTO public.conversations (id, type, participant_ids, created_by, data)
VALUES ('banc-reg-conv', 'individual', ARRAY['banc-reg-a', 'banc-reg-b'], 'banc-reg-a', '{}');

INSERT INTO public.mls_devices (id, user_id, stable_id, name, platform, mls_identity,
                                signature_key, credential)
VALUES
  ('00000000-0000-0000-0000-0000000000a1', 'banc-reg-a', 'a', 'Pixel de A', 'android', 'banc-reg-a:a', '\x01', '\x01'),
  ('00000000-0000-0000-0000-0000000000b1', 'banc-reg-b', 'b', 'Pixel de B', 'android', 'banc-reg-b:b', '\x02', '\x02'),
  ('00000000-0000-0000-0000-0000000000c1', 'banc-reg-c', 'c', 'Pixel de C', 'android', 'banc-reg-c:c', '\x03', '\x03');

INSERT INTO public.mls_key_packages (device_id, key_package, cipher_suite, expires_at)
SELECT d, '\x0a'::bytea, 'banc', now() + interval '1 day'
  FROM unnest(ARRAY[
    '00000000-0000-0000-0000-0000000000a1'::uuid,
    '00000000-0000-0000-0000-0000000000b1'::uuid,
    '00000000-0000-0000-0000-0000000000c1'::uuid]) AS d;

-- @@MIGRATION@@

SET LOCAL request.jwt.claims =
  '{"sub":"00000000-0000-0000-0000-0000000000f5","app_metadata":{"firebase_uid":"banc-reg-a"},"role":"authenticated"}';
SET LOCAL ROLE authenticated;

-- ═══ 1-3. mls_devices ══════════════════════════════════════════════════════
INSERT INTO resultat
SELECT 1, 'A voit ses appareils', '1', count(*)::text,
       CASE WHEN count(*) = 1 THEN 'OK' ELSE 'ÉCHEC' END
  FROM mls_devices WHERE user_id = 'banc-reg-a';
INSERT INTO resultat
SELECT 2, 'A voit ceux de B (conversation commune)', '1', count(*)::text,
       CASE WHEN count(*) = 1 THEN 'OK' ELSE 'ÉCHEC' END
  FROM mls_devices WHERE user_id = 'banc-reg-b';
INSERT INTO resultat
SELECT 3, 'A ne voit pas ceux de C (inconnu)', '0', count(*)::text,
       CASE WHEN count(*) = 0 THEN 'OK' ELSE 'ÉCHEC' END
  FROM mls_devices WHERE user_id = 'banc-reg-c';

-- ═══ 4-5. claim_key_package ════════════════════════════════════════════════
DO $$
DECLARE r record;
BEGIN
  SELECT * INTO r FROM claim_key_package('00000000-0000-0000-0000-0000000000b1');
  INSERT INTO resultat VALUES (4, 'A réclame un paquet de B', 'un paquet',
    COALESCE(r.id::text, 'rien'), CASE WHEN r.id IS NOT NULL THEN 'OK' ELSE 'ÉCHEC' END);
EXCEPTION WHEN OTHERS THEN
  INSERT INTO resultat VALUES (4, 'A réclame un paquet de B', 'un paquet',
    'ERREUR ' || SQLSTATE || ' ' || SQLERRM, 'ÉCHEC');
END $$;

DO $$
DECLARE r record;
BEGIN
  SELECT * INTO r FROM claim_key_package('00000000-0000-0000-0000-0000000000c1');
  INSERT INTO resultat VALUES (5, 'A ne vide pas les paquets de C', 'refusé 42501',
    'ACCEPTÉ ' || COALESCE(r.id::text, 'rien'), 'ÉCHEC');
EXCEPTION WHEN insufficient_privilege THEN
  INSERT INTO resultat VALUES (5, 'A ne vide pas les paquets de C', 'refusé 42501', 'refusé 42501', 'OK');
END $$;

-- ═══ 6-7. mls_key_packages ═════════════════════════════════════════════════
INSERT INTO resultat
SELECT 6, 'A lit ses propres paquets', '1', count(*)::text,
       CASE WHEN count(*) = 1 THEN 'OK' ELSE 'ÉCHEC' END
  FROM mls_key_packages WHERE device_id = '00000000-0000-0000-0000-0000000000a1';
INSERT INTO resultat
SELECT 7, 'A ne lit pas ceux des autres', '0', count(*)::text,
       CASE WHEN count(*) = 0 THEN 'OK' ELSE 'ÉCHEC' END
  FROM mls_key_packages WHERE device_id <> '00000000-0000-0000-0000-0000000000a1'
   AND device_id IN ('00000000-0000-0000-0000-0000000000b1', '00000000-0000-0000-0000-0000000000c1');

RESET ROLE;
SELECT n, verdict, cas, attendu, obtenu FROM resultat ORDER BY n;

ROLLBACK;
