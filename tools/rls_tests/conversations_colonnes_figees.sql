-- Banc : `id`, `type`, `group_id`, `created_by` d'une conversation ne se
-- réécrivent plus depuis le client, et hors groupe ses participants non plus
-- (migration 20261003120000).
--
--   supabase db query --linked -f tools/rls_tests/conversations_colonnes_figees.sql
--
-- Condition : 0 cas en ÉCHEC. Tout est dans un `BEGIN … ROLLBACK`.
--
-- AVANT `db push` : remplacer la ligne seule `-- @@MIGRATION@@` par le contenu
-- de la migration — c'est la répétition. APRÈS, lancé tel quel, le banc prouve
-- l'état vivant.
--
-- Un banc qui ne sait pas échouer ne prouve rien : sans la migration, les cas
-- 1, 3, 4, 5, 7 et 8 tombent. Vérifié le 2026-10-03 sur un PostgreSQL 16
-- local minimal (rôles anon/authenticated, `firebase_uid()`, `conversations`
-- avec les policies de 20260715120000 et la garde de 20260909234500) : six
-- ÉCHEC sans la migration, 0 avec. PAS encore contre la production — c'est le
-- premier lancement `--linked` qui le dira. Les cas 2, 6, 9 et 10 sont les
-- témoins : un participant règle toujours sa conversation, un administrateur
-- reconnu par la garde existante exclut toujours, et une écriture serveur
-- (propriétaire, comme une RPC SECURITY DEFINER) n'est pas concernée.
--
-- Aucune donnée réelle n'est touchée : le banc fabrique ses trois
-- conversations, avec un `group_id` qui ne désigne aucun groupe — aucun
-- `group_members` à synchroniser, aucun destinataire de notification.

BEGIN;

SET LOCAL lock_timeout = '5s';

CREATE TEMP TABLE resultat(n int, cas text, attendu text, obtenu text, verdict text);
CREATE TEMP TABLE ctx(k text PRIMARY KEY, v text);
GRANT ALL ON resultat, ctx TO anon, authenticated;

INSERT INTO ctx VALUES
  ('moi',     'banc-figees-moi'),
  ('autre',   'banc-figees-autre'),
  ('admin',   'banc-figees-admin'),
  ('tiers',   'banc-figees-tiers'),
  ('groupe',  gen_random_uuid()::text),
  ('conv_g',  'banc-figees-g-'  || gen_random_uuid()::text),
  ('conv_g2', 'banc-figees-g2-' || gen_random_uuid()::text),
  ('conv_1',  'banc-figees-1-'  || gen_random_uuid()::text);

-- Conversation de groupe : `admin` est administrateur (data.adminIds), `moi`
-- simple membre. Créée par `admin`.
INSERT INTO public.conversations (id, type, group_id, participant_ids, created_by, data)
SELECT c.v, 'group', g.v,
       ARRAY[(SELECT v FROM ctx WHERE k='admin'), (SELECT v FROM ctx WHERE k='moi'), (SELECT v FROM ctx WHERE k='autre')],
       (SELECT v FROM ctx WHERE k='admin'),
       jsonb_build_object('adminIds', jsonb_build_array((SELECT v FROM ctx WHERE k='admin')))
  FROM ctx c, ctx g WHERE c.k = 'conv_g' AND g.k = 'groupe';

-- Seconde conversation de groupe, même forme : celle du témoin admin (cas 9),
-- pour que l'exclusion ne change pas les participants des autres cas.
INSERT INTO public.conversations (id, type, group_id, participant_ids, created_by, data)
SELECT c.v, 'group', g.v,
       ARRAY[(SELECT v FROM ctx WHERE k='admin'), (SELECT v FROM ctx WHERE k='moi'), (SELECT v FROM ctx WHERE k='autre')],
       (SELECT v FROM ctx WHERE k='admin'),
       jsonb_build_object('adminIds', jsonb_build_array((SELECT v FROM ctx WHERE k='admin')))
  FROM ctx c, ctx g WHERE c.k = 'conv_g2' AND g.k = 'groupe';

-- Conversation 1:1 entre `moi` et `autre`, créée par `autre`.
INSERT INTO public.conversations (id, type, participant_ids, created_by, data)
SELECT v, 'individual',
       ARRAY[(SELECT v FROM ctx WHERE k='moi'), (SELECT v FROM ctx WHERE k='autre')],
       (SELECT v FROM ctx WHERE k='autre'), '{}'::jsonb
  FROM ctx WHERE k = 'conv_1';

-- @@MIGRATION@@

-- ═══ 1. Catalogue ═══════════════════════════════════════════════════════════
INSERT INTO resultat
SELECT 1, 'déclencheur conversations_colonnes_figees présent, BEFORE UPDATE',
       'présent',
       COALESCE((SELECT 'présent' FROM pg_trigger t
                  WHERE t.tgrelid = 'public.conversations'::regclass
                    AND t.tgname = 'conversations_colonnes_figees'
                    AND NOT t.tgisinternal), '<absent>'),
       CASE WHEN EXISTS (SELECT 1 FROM pg_trigger t
                          WHERE t.tgrelid = 'public.conversations'::regclass
                            AND t.tgname = 'conversations_colonnes_figees'
                            AND NOT t.tgisinternal)
            THEN 'OK' ELSE 'ÉCHEC' END;

-- ═══ Simple membre du groupe, participant de la 1:1 ═════════════════════════
SET LOCAL request.jwt.claims =
  '{"sub":"00000000-0000-0000-0000-0000000000f1","app_metadata":{"firebase_uid":"banc-figees-moi"},"role":"authenticated"}';
SET LOCAL ROLE authenticated;

INSERT INTO resultat VALUES (0, 'rôle effectif du banc', 'authenticated', current_user,
  CASE WHEN current_user = 'authenticated' THEN 'OK' ELSE 'ÉCHEC' END);

-- 2. Témoin : régler sa conversation (sourdine) passe toujours.
DO $$
DECLARE n int;
BEGIN
  UPDATE public.conversations SET data = data || '{"banc":"sourdine"}'::jsonb
   WHERE id = (SELECT v FROM ctx WHERE k='conv_g');
  GET DIAGNOSTICS n = ROW_COUNT;
  INSERT INTO resultat VALUES (2, 'témoin : un membre règle sa conversation de groupe (data)',
    '1 ligne', n || ' ligne(s)', CASE WHEN n = 1 THEN 'OK' ELSE 'ÉCHEC' END);
EXCEPTION WHEN OTHERS THEN
  INSERT INTO resultat VALUES (2, 'témoin : un membre règle sa conversation de groupe (data)',
    '1 ligne', 'REFUSÉ ' || SQLSTATE || ' ' || left(SQLERRM, 80), 'ÉCHEC');
END $$;

-- 3. Le contournement : group_id → NULL pour sauter la garde admin, en se
--    nommant admin et en retirant `autre` dans le même UPDATE.
DO $$
BEGIN
  UPDATE public.conversations
     SET group_id = NULL,
         participant_ids = array_remove(participant_ids, (SELECT v FROM ctx WHERE k='autre')),
         data = jsonb_set(data, '{adminIds}', jsonb_build_array((SELECT v FROM ctx WHERE k='moi')))
   WHERE id = (SELECT v FROM ctx WHERE k='conv_g');
  INSERT INTO resultat VALUES (3, 'membre : group_id → NULL + se nomme admin + exclut', 'refusé 42501', 'ACCEPTÉ', 'ÉCHEC');
EXCEPTION WHEN insufficient_privilege THEN
  INSERT INTO resultat VALUES (3, 'membre : group_id → NULL + se nomme admin + exclut', 'refusé 42501', 'refusé 42501', 'OK');
END $$;

-- 4. created_by → moi, prélude au DELETE en cascade de tout l'historique.
DO $$
BEGIN
  UPDATE public.conversations SET created_by = (SELECT v FROM ctx WHERE k='moi')
   WHERE id = (SELECT v FROM ctx WHERE k='conv_g');
  INSERT INTO resultat VALUES (4, 'membre : s''approprie created_by', 'refusé 42501', 'ACCEPTÉ', 'ÉCHEC');
EXCEPTION WHEN insufficient_privilege THEN
  INSERT INTO resultat VALUES (4, 'membre : s''approprie created_by', 'refusé 42501', 'refusé 42501', 'OK');
END $$;

-- 5. type réécrit.
DO $$
BEGIN
  UPDATE public.conversations SET type = 'individual'
   WHERE id = (SELECT v FROM ctx WHERE k='conv_g');
  INSERT INTO resultat VALUES (5, 'membre : réécrit type', 'refusé 42501', 'ACCEPTÉ', 'ÉCHEC');
EXCEPTION WHEN insufficient_privilege THEN
  INSERT INTO resultat VALUES (5, 'membre : réécrit type', 'refusé 42501', 'refusé 42501', 'OK');
END $$;

-- 6. Témoin 1:1 : régler la conversation passe toujours.
DO $$
DECLARE n int;
BEGIN
  UPDATE public.conversations SET data = data || '{"banc":"epingle"}'::jsonb
   WHERE id = (SELECT v FROM ctx WHERE k='conv_1');
  GET DIAGNOSTICS n = ROW_COUNT;
  INSERT INTO resultat VALUES (6, 'témoin : un participant règle sa 1:1 (data)',
    '1 ligne', n || ' ligne(s)', CASE WHEN n = 1 THEN 'OK' ELSE 'ÉCHEC' END);
EXCEPTION WHEN OTHERS THEN
  INSERT INTO resultat VALUES (6, 'témoin : un participant règle sa 1:1 (data)',
    '1 ligne', 'REFUSÉ ' || SQLSTATE || ' ' || left(SQLERRM, 80), 'ÉCHEC');
END $$;

-- 7. 1:1 : faire entrer un tiers, qui lirait tout l'historique.
DO $$
BEGIN
  UPDATE public.conversations
     SET participant_ids = participant_ids || ARRAY[(SELECT v FROM ctx WHERE k='tiers')]
   WHERE id = (SELECT v FROM ctx WHERE k='conv_1');
  INSERT INTO resultat VALUES (7, '1:1 : un participant ajoute un tiers', 'refusé 42501', 'ACCEPTÉ', 'ÉCHEC');
EXCEPTION WHEN insufficient_privilege THEN
  INSERT INTO resultat VALUES (7, '1:1 : un participant ajoute un tiers', 'refusé 42501', 'refusé 42501', 'OK');
END $$;

-- 8. 1:1 : s'approprier created_by, puis DELETE (cascade).
DO $$
BEGIN
  UPDATE public.conversations SET created_by = (SELECT v FROM ctx WHERE k='moi')
   WHERE id = (SELECT v FROM ctx WHERE k='conv_1');
  INSERT INTO resultat VALUES (8, '1:1 : s''approprie created_by', 'refusé 42501', 'ACCEPTÉ', 'ÉCHEC');
EXCEPTION WHEN insufficient_privilege THEN
  INSERT INTO resultat VALUES (8, '1:1 : s''approprie created_by', 'refusé 42501', 'refusé 42501', 'OK');
END $$;

-- ═══ Administrateur du groupe ═══════════════════════════════════════════════
RESET ROLE;
SET LOCAL request.jwt.claims =
  '{"sub":"00000000-0000-0000-0000-0000000000f2","app_metadata":{"firebase_uid":"banc-figees-admin"},"role":"authenticated"}';
SET LOCAL ROLE authenticated;

-- 9. Témoin : l'admin exclut toujours un membre (garde existante inchangée).
DO $$
DECLARE n int;
BEGIN
  UPDATE public.conversations
     SET participant_ids = array_remove(participant_ids, (SELECT v FROM ctx WHERE k='autre'))
   WHERE id = (SELECT v FROM ctx WHERE k='conv_g2');
  GET DIAGNOSTICS n = ROW_COUNT;
  INSERT INTO resultat VALUES (9, 'témoin : l''admin exclut un membre du groupe',
    '1 ligne', n || ' ligne(s)', CASE WHEN n = 1 THEN 'OK' ELSE 'ÉCHEC' END);
EXCEPTION WHEN OTHERS THEN
  INSERT INTO resultat VALUES (9, 'témoin : l''admin exclut un membre du groupe',
    '1 ligne', 'REFUSÉ ' || SQLSTATE || ' ' || left(SQLERRM, 80), 'ÉCHEC');
END $$;

-- ═══ 10. Écriture serveur (propriétaire, comme une RPC SECURITY DEFINER) ════
RESET ROLE;
DO $$
DECLARE n int;
BEGIN
  UPDATE public.conversations SET created_by = (SELECT v FROM ctx WHERE k='moi')
   WHERE id = (SELECT v FROM ctx WHERE k='conv_1');
  GET DIAGNOSTICS n = ROW_COUNT;
  INSERT INTO resultat VALUES (10, 'témoin : le serveur réécrit created_by (purge de compte)',
    '1 ligne', n || ' ligne(s)', CASE WHEN n = 1 THEN 'OK' ELSE 'ÉCHEC' END);
EXCEPTION WHEN OTHERS THEN
  INSERT INTO resultat VALUES (10, 'témoin : le serveur réécrit created_by (purge de compte)',
    '1 ligne', 'REFUSÉ ' || SQLSTATE || ' ' || left(SQLERRM, 80), 'ÉCHEC');
END $$;

SELECT n, verdict, cas, attendu, obtenu FROM resultat ORDER BY n, cas;

ROLLBACK;
