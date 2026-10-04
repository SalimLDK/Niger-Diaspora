-- Banc : reconstruction du groupe MLS d'une conversation bloquée
-- (migration 20261004120000).
--
--   supabase db query --linked -f tools/rls_tests/mls_reconstruction_du_groupe.sql
--
-- Condition : 0 cas en ÉCHEC. Tout est dans un `BEGIN … ROLLBACK`.
--
-- AVANT `db push` : remplacer la ligne seule `-- @@MIGRATION@@` par le contenu
-- de la migration. APRÈS, lancé tel quel, le banc prouve l'état vivant.
-- Sans la migration, le banc s'interrompt au premier appel (fonction ou
-- colonne inexistante) : il ne peut pas passer à tort.
--
-- Aucune notification : le banc n'écrit ni `messages` ni `mls_messages`.
-- `mls_commits`, `mls_welcomes` et `conversation_devices` n'ont pas de
-- déclencheur d'insertion. Tout porte sur des conversations et des appareils
-- fabriqués ici.

BEGIN;

SET LOCAL lock_timeout = '5s';

CREATE TEMP TABLE resultat(n int, cas text, attendu text, obtenu text, verdict text);
CREATE TEMP TABLE ctx(k text PRIMARY KEY, v text);
GRANT ALL ON resultat, ctx TO anon, authenticated;

INSERT INTO ctx VALUES
  ('admin',  'banc-recon-admin'),
  ('membre', 'banc-recon-membre'),
  ('tiers',  'banc-recon-tiers'),
  ('groupe', gen_random_uuid()::text),
  ('conv_g', 'banc-recon-g-' || gen_random_uuid()::text),
  ('conv_1', 'banc-recon-1-' || gen_random_uuid()::text),
  ('dev',    gen_random_uuid()::text);

INSERT INTO public.conversations (id, type, group_id, participant_ids, created_by, data, mls_since)
SELECT c.v, 'group', g.v,
       ARRAY['banc-recon-admin', 'banc-recon-membre'], 'banc-recon-admin',
       '{"adminIds":["banc-recon-admin"]}'::jsonb, now() - interval '1 day'
  FROM ctx c, ctx g WHERE c.k = 'conv_g' AND g.k = 'groupe';

INSERT INTO public.conversations (id, type, participant_ids, created_by, data, mls_since)
SELECT v, 'individual', ARRAY['banc-recon-membre', 'banc-recon-tiers'],
       'banc-recon-tiers', '{}'::jsonb, now() - interval '1 day'
  FROM ctx WHERE k = 'conv_1';

INSERT INTO public.mls_devices (id, user_id, stable_id, name, platform, mls_identity,
                                signature_key, credential)
SELECT v::uuid, 'banc-recon-admin', 'banc-recon', 'Banc', 'android',
       'banc-recon-admin:banc', '\x01'::bytea, '\x01'::bytea
  FROM ctx WHERE k = 'dev';

-- Un arbre « empoisonné » : trois epochs, dont le dernier illisible pour tous.
INSERT INTO public.mls_commits (conversation_id, epoch, sender_device_id, commit)
SELECT (SELECT v FROM ctx WHERE k='conv_g'), e, (SELECT v FROM ctx WHERE k='dev')::uuid, '\x00'::bytea
  FROM generate_series(0, 2) e;
INSERT INTO public.mls_welcomes (conversation_id, recipient_device_id, epoch, welcome)
SELECT (SELECT v FROM ctx WHERE k='conv_g'), (SELECT v FROM ctx WHERE k='dev')::uuid, 1, '\x00'::bytea;
INSERT INTO public.conversation_devices (conversation_id, device_id, status, epoch_added)
SELECT (SELECT v FROM ctx WHERE k='conv_g'), (SELECT v FROM ctx WHERE k='dev')::uuid, 'active', 0;
UPDATE public.conversations SET mls_group_info = '\x01'::bytea
 WHERE id = (SELECT v FROM ctx WHERE k='conv_g');

-- @@MIGRATION@@

-- ═══ 1. Un simple membre ne reconstruit pas un groupe ══════════════════════
SET LOCAL request.jwt.claims =
  '{"sub":"00000000-0000-0000-0000-0000000000a1","app_metadata":{"firebase_uid":"banc-recon-membre"},"role":"authenticated"}';
SET LOCAL ROLE authenticated;
DO $$
BEGIN
  PERFORM reconstruire_groupe_mls((SELECT v FROM ctx WHERE k='conv_g'));
  INSERT INTO resultat VALUES (1, 'groupe : un simple membre ne reconstruit pas', 'refusé 42501', 'ACCEPTÉ', 'ÉCHEC');
EXCEPTION WHEN insufficient_privilege THEN
  INSERT INTO resultat VALUES (1, 'groupe : un simple membre ne reconstruit pas', 'refusé 42501', 'refusé 42501', 'OK');
END $$;

-- ═══ 4. Ni ne pose la marque à la main ═════════════════════════════════════
DO $$
BEGIN
  UPDATE public.conversations SET mls_rebuilt_at = now()
   WHERE id = (SELECT v FROM ctx WHERE k='conv_g');
  INSERT INTO resultat VALUES (4, 'client : mls_rebuilt_at ne s''écrit pas directement', 'refusé 42501', 'ACCEPTÉ', 'ÉCHEC');
EXCEPTION WHEN insufficient_privilege THEN
  INSERT INTO resultat VALUES (4, 'client : mls_rebuilt_at ne s''écrit pas directement', 'refusé 42501', 'refusé 42501', 'OK');
END $$;

-- ═══ 5. Hors groupe : un participant reconstruit ═══════════════════════════
DO $$
DECLARE t timestamptz;
BEGIN
  t := reconstruire_groupe_mls((SELECT v FROM ctx WHERE k='conv_1'));
  INSERT INTO resultat VALUES (5, '1:1 : un participant reconstruit', 'date rendue', t::text,
    CASE WHEN t IS NOT NULL THEN 'OK' ELSE 'ÉCHEC' END);
EXCEPTION WHEN OTHERS THEN
  INSERT INTO resultat VALUES (5, '1:1 : un participant reconstruit', 'date rendue',
    'REFUSÉ ' || SQLSTATE || ' ' || SQLERRM, 'ÉCHEC');
END $$;

-- ═══ 2. L'administrateur reconstruit : tout le transport repart de zéro ════
RESET ROLE;
SET LOCAL request.jwt.claims =
  '{"sub":"00000000-0000-0000-0000-0000000000a2","app_metadata":{"firebase_uid":"banc-recon-admin"},"role":"authenticated"}';
SET LOCAL ROLE authenticated;
DO $$
DECLARE t timestamptz;
BEGIN
  t := reconstruire_groupe_mls((SELECT v FROM ctx WHERE k='conv_g'));
  INSERT INTO resultat VALUES (2, 'groupe : l''administrateur reconstruit', 'date rendue', t::text,
    CASE WHEN t IS NOT NULL THEN 'OK' ELSE 'ÉCHEC' END);
EXCEPTION WHEN OTHERS THEN
  INSERT INTO resultat VALUES (2, 'groupe : l''administrateur reconstruit', 'date rendue',
    'REFUSÉ ' || SQLSTATE || ' ' || SQLERRM, 'ÉCHEC');
END $$;

-- ═══ 3. Pas deux fois en cinq minutes ══════════════════════════════════════
DO $$
BEGIN
  PERFORM reconstruire_groupe_mls((SELECT v FROM ctx WHERE k='conv_g'));
  INSERT INTO resultat VALUES (3, 'deuxième reconstruction immédiate', 'refusé 55P03', 'ACCEPTÉ', 'ÉCHEC');
EXCEPTION WHEN lock_not_available THEN
  INSERT INTO resultat VALUES (3, 'deuxième reconstruction immédiate', 'refusé 55P03', 'refusé 55P03', 'OK');
END $$;

-- ═══ 6. Un non-participant n'y touche pas ══════════════════════════════════
RESET ROLE;
SET LOCAL request.jwt.claims =
  '{"sub":"00000000-0000-0000-0000-0000000000a3","app_metadata":{"firebase_uid":"banc-recon-tiers"},"role":"authenticated"}';
SET LOCAL ROLE authenticated;
DO $$
BEGIN
  PERFORM reconstruire_groupe_mls((SELECT v FROM ctx WHERE k='conv_g'));
  INSERT INTO resultat VALUES (6, 'non-participant : refusé', 'refusé 42501', 'ACCEPTÉ', 'ÉCHEC');
EXCEPTION WHEN insufficient_privilege THEN
  INSERT INTO resultat VALUES (6, 'non-participant : refusé', 'refusé 42501', 'refusé 42501', 'OK');
END $$;

-- ═══ 7. Ce que la reconstruction a laissé (vu en postgres) ═════════════════
RESET ROLE;
INSERT INTO resultat
SELECT 7, 'transport remis à zéro, chiffrement maintenu',
       'commits=0 welcomes=0 appareils=pending arbre=null since=posé rebuilt=posé',
       format('commits=%s welcomes=%s appareils=%s arbre=%s since=%s rebuilt=%s',
         (SELECT count(*) FROM mls_commits  WHERE conversation_id = c.id),
         (SELECT count(*) FROM mls_welcomes WHERE conversation_id = c.id),
         (SELECT string_agg(status, ',') FROM conversation_devices WHERE conversation_id = c.id),
         COALESCE(c.mls_group_info::text, 'null'),
         CASE WHEN c.mls_since IS NULL THEN 'nul' ELSE 'posé' END,
         CASE WHEN c.mls_rebuilt_at IS NULL THEN 'nul' ELSE 'posé' END),
       CASE WHEN (SELECT count(*) FROM mls_commits  WHERE conversation_id = c.id) = 0
             AND (SELECT count(*) FROM mls_welcomes WHERE conversation_id = c.id) = 0
             AND (SELECT bool_and(status = 'pending') FROM conversation_devices WHERE conversation_id = c.id)
             AND c.mls_group_info IS NULL
             AND c.mls_since IS NOT NULL
             AND c.mls_rebuilt_at IS NOT NULL
            THEN 'OK' ELSE 'ÉCHEC' END
  FROM conversations c WHERE c.id = (SELECT v FROM ctx WHERE k='conv_g');

SELECT n, verdict, cas, attendu, obtenu FROM resultat ORDER BY n, cas;

ROLLBACK;
