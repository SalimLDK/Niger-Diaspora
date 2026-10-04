-- Banc : un appareil MLS révoqué ne publie plus (migration 20261004110000).
--
--   supabase db query --linked -f tools/rls_tests/mls_appareil_revoque_n_ecrit_plus.sql
--
-- Condition : 0 cas en ÉCHEC. Tout est dans un `BEGIN … ROLLBACK`.
--
-- AVANT `db push` : remplacer la ligne seule `-- @@MIGRATION@@` par le contenu
-- de la migration. APRÈS, lancé tel quel, le banc prouve l'état vivant.
--
-- Sans la migration, les cas 1 et 3 tombent (vérifié sur un PostgreSQL 16
-- local le 2026-10-04 ; pas encore contre la production). Le cas 2 est le
-- témoin : un appareil actif publie toujours.
--
-- `mls_messages` n'est vérifié qu'au catalogue (cas 1) : l'insérer déclenche
-- `mls_notify_recipients_trg`. `mls_commits` n'a aucun déclencheur
-- d'insertion, d'où l'essai réel (cas 2 et 3), sur une conversation et deux
-- appareils fabriqués ici.

BEGIN;

SET LOCAL lock_timeout = '5s';

CREATE TEMP TABLE resultat(n int, cas text, attendu text, obtenu text, verdict text);
CREATE TEMP TABLE ctx(k text PRIMARY KEY, v text);
GRANT ALL ON resultat, ctx TO anon, authenticated;

INSERT INTO ctx VALUES
  ('moi',     'banc-revoque-moi'),
  ('conv',    'banc-revoque-' || gen_random_uuid()::text),
  ('actif',   gen_random_uuid()::text),
  ('revoque', gen_random_uuid()::text);

INSERT INTO public.conversations (id, type, participant_ids, created_by)
SELECT v, 'individual', ARRAY[(SELECT v FROM ctx WHERE k='moi')], (SELECT v FROM ctx WHERE k='moi')
  FROM ctx WHERE k = 'conv';

INSERT INTO public.mls_devices (id, user_id, stable_id, name, platform, mls_identity,
                                signature_key, credential, revoked_at)
VALUES
  ((SELECT v FROM ctx WHERE k='actif')::uuid, 'banc-revoque-moi', 'banc-actif', 'Banc actif',
   'android', 'banc-revoque-moi:actif', '\x01'::bytea, '\x01'::bytea, NULL),
  ((SELECT v FROM ctx WHERE k='revoque')::uuid, 'banc-revoque-moi', 'banc-revoque', 'Banc volé',
   'android', 'banc-revoque-moi:revoque', '\x02'::bytea, '\x02'::bytea, now());

-- @@MIGRATION@@

-- ═══ 1. Catalogue ═══════════════════════════════════════════════════════════
INSERT INTO resultat
SELECT 1, 'les deux policies d''insertion exigent revoked_at IS NULL', '2',
       count(*)::text,
       CASE WHEN count(*) = 2 THEN 'OK' ELSE 'ÉCHEC' END
  FROM pg_policies
 WHERE schemaname = 'public'
   AND (tablename, policyname) IN (
         ('mls_commits', 'mls_commits: publier depuis son appareil'),
         ('mls_messages', 'mls_messages: emettre depuis son appareil'))
   AND with_check ~ 'revoked_at IS NULL';

SET LOCAL request.jwt.claims =
  '{"sub":"00000000-0000-0000-0000-0000000000f9","app_metadata":{"firebase_uid":"banc-revoque-moi"},"role":"authenticated"}';
SET LOCAL ROLE authenticated;

-- ═══ 2. Témoin : l'appareil actif publie ═══════════════════════════════════
DO $$
BEGIN
  INSERT INTO public.mls_commits (conversation_id, epoch, sender_device_id, commit)
  VALUES ((SELECT v FROM ctx WHERE k='conv'), 0, (SELECT v FROM ctx WHERE k='actif')::uuid, '\x00'::bytea);
  INSERT INTO resultat VALUES (2, 'témoin : un appareil actif publie un commit', 'accepté', 'accepté', 'OK');
EXCEPTION WHEN OTHERS THEN
  INSERT INTO resultat VALUES (2, 'témoin : un appareil actif publie un commit', 'accepté',
    'REFUSÉ ' || SQLSTATE || ' ' || SQLERRM, 'ÉCHEC');
END $$;

-- ═══ 3. L'appareil révoqué ne publie plus (le commit externe du voleur) ═════
DO $$
BEGIN
  INSERT INTO public.mls_commits (conversation_id, epoch, sender_device_id, commit)
  VALUES ((SELECT v FROM ctx WHERE k='conv'), 1, (SELECT v FROM ctx WHERE k='revoque')::uuid, '\x00'::bytea);
  INSERT INTO resultat VALUES (3, 'appareil révoqué : commit refusé', 'refusé 42501', 'ACCEPTÉ', 'ÉCHEC');
EXCEPTION WHEN insufficient_privilege THEN
  INSERT INTO resultat VALUES (3, 'appareil révoqué : commit refusé', 'refusé 42501', 'refusé 42501', 'OK');
END $$;

RESET ROLE;
SELECT n, verdict, cas, attendu, obtenu FROM resultat ORDER BY n, cas;

ROLLBACK;
