-- Banc : la date d'un message écrit par le client est celle du serveur
-- (migration 20261004090000).
--
--   supabase db query --linked -f tools/rls_tests/messages_dates_par_le_serveur.sql
--
-- Condition : 0 cas en ÉCHEC. Tout est dans un `BEGIN … ROLLBACK`.
--
-- AVANT `db push` : remplacer la ligne seule `-- @@MIGRATION@@` par le contenu
-- de la migration — c'est la répétition. APRÈS, lancé tel quel, le banc prouve
-- l'état vivant.
--
-- Un banc qui ne sait pas échouer ne prouve rien : sans la migration, les cas
-- 1 et 2 tombent (vérifié sur un PostgreSQL 16 local le 2026-10-04, pas
-- encore contre la production). Le cas 3 est le témoin : une écriture serveur
-- garde sa date.
--
-- AUCUNE NOTIFICATION N'EST CRÉÉE : l'unique conversation fabriquée n'a que
-- l'expéditeur pour participant — `notify_recipients_on_message_insert` saute
-- l'expéditeur (le cas « Mes notes »).

BEGIN;

SET LOCAL lock_timeout = '5s';

CREATE TEMP TABLE resultat(n int, cas text, attendu text, obtenu text, verdict text);
CREATE TEMP TABLE ctx(k text PRIMARY KEY, v text);
GRANT ALL ON resultat, ctx TO anon, authenticated;

INSERT INTO ctx VALUES
  ('moi',  'banc-dates-moi'),
  ('conv', 'banc-dates-' || gen_random_uuid()::text);

INSERT INTO public.conversations (id, type, participant_ids, created_by)
SELECT v, 'individual', ARRAY[(SELECT v FROM ctx WHERE k = 'moi')],
       (SELECT v FROM ctx WHERE k = 'moi')
  FROM ctx WHERE k = 'conv';

-- @@MIGRATION@@

-- ═══ 1. Catalogue ═══════════════════════════════════════════════════════════
INSERT INTO resultat
SELECT 1, 'déclencheur messages_date_du_serveur présent', 'présent',
       COALESCE((SELECT 'présent' FROM pg_trigger
                  WHERE tgrelid = 'public.messages'::regclass
                    AND tgname = 'messages_date_du_serveur'
                    AND NOT tgisinternal), '<absent>'),
       CASE WHEN EXISTS (SELECT 1 FROM pg_trigger
                          WHERE tgrelid = 'public.messages'::regclass
                            AND tgname = 'messages_date_du_serveur'
                            AND NOT tgisinternal)
            THEN 'OK' ELSE 'ÉCHEC' END;

-- ═══ 2. Le client envoie une date fausse ════════════════════════════════════
SET LOCAL request.jwt.claims =
  '{"sub":"00000000-0000-0000-0000-0000000000d1","app_metadata":{"firebase_uid":"banc-dates-moi"},"role":"authenticated"}';
SET LOCAL ROLE authenticated;

DO $$
BEGIN
  INSERT INTO public.messages (id, conversation_id, sender_id, type, created_at, data)
  VALUES ('banc-dates-m2', (SELECT v FROM ctx WHERE k = 'conv'),
          (SELECT v FROM ctx WHERE k = 'moi'), 'text',
          '2020-01-01T00:00:00Z', '{"content":"banc"}'::jsonb);
EXCEPTION WHEN OTHERS THEN
  INSERT INTO resultat VALUES (2, 'client : une date d''horloge fausse est remplacée',
    'date du serveur', 'INSERT REFUSÉ ' || SQLSTATE || ' ' || SQLERRM, 'ÉCHEC');
END $$;

RESET ROLE;

INSERT INTO resultat
SELECT 2, 'client : une date d''horloge fausse est remplacée',
       'date du serveur (now())', created_at::text,
       CASE WHEN created_at = now() THEN 'OK' ELSE 'ÉCHEC' END
  FROM public.messages WHERE id = 'banc-dates-m2';

-- ═══ 3. Témoin : une écriture serveur garde sa date ═════════════════════════
INSERT INTO public.messages (id, conversation_id, sender_id, type, created_at, data)
VALUES ('banc-dates-m3', (SELECT v FROM ctx WHERE k = 'conv'),
        (SELECT v FROM ctx WHERE k = 'moi'), 'text',
        '2021-06-01T12:00:00Z', '{"content":"banc"}'::jsonb);

INSERT INTO resultat
SELECT 3, 'témoin : une écriture serveur (définisseur) garde sa date',
       '2021-06-01 12:00:00+00', created_at::text,
       CASE WHEN created_at = timestamptz '2021-06-01T12:00:00Z' THEN 'OK' ELSE 'ÉCHEC' END
  FROM public.messages WHERE id = 'banc-dates-m3';

SELECT n, verdict, cas, attendu, obtenu FROM resultat ORDER BY n, cas;

ROLLBACK;
