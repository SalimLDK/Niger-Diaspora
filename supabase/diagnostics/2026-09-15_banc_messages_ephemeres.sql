-- Banc de la purge des messages éphémères (2026-09-15).
--
-- POURQUOI UN BANC POUR TRENTE LIGNES DE SQL
-- Une purge qui ne purge rien ne dit rien. C'est exactement comme ça que la
-- fonction éphémère est morte : l'écran de réglage écrivait, personne ne
-- lisait, et rien nulle part ne signalait le vide. Ce banc a déjà servi deux
-- fois pendant son écriture :
--
--   * il a montré qu'en retirant le garde de forme ISO
--     (`~ '^\d{4}-...'`), **une seule** échéance mal formée fait échouer la
--     purge entière — 22007 sur la table, donc plus rien n'expire pour
--     personne, en silence côté application ;
--   * il a démenti l'hypothèse « `last_message_at` = `created_at` du dernier
--     message » telle qu'écrite au premier jet : un message MLS déclenche
--     `mls_messages_apercu_conversation`, qui repositionne `last_message_at`
--     sur le sien. Les deux sources ne peuvent pas partager la conversation
--     d'essai.
--
-- COMMENT LE LANCER
-- La fonction `public.purger_messages_expires()` doit exister (migration
-- 20260915234500). Tout est enveloppé dans BEGIN/ROLLBACK : le banc écrit
-- dans la vraie base et n'y laisse rien.
--
--   supabase db query --linked -f supabase/diagnostics/2026-09-15_banc_messages_ephemeres.sql
--
-- `supabase db query` ne rend que le DERNIER jeu de résultats : d'où la table
-- de verdicts unique en fin de fichier. Lire la colonne `verdict` ; tout doit
-- être VERT.

BEGIN;

-- ── Jeu d'essai ───────────────────────────────────────────────────────────
--
-- Trois conversations, séparées à dessein. Un message MLS déclenche
-- `mls_messages_apercu_conversation`, qui repositionne `last_message_at` sur
-- SON created_at : mêler legacy et MLS dans la même conversation ferait
-- mentir le contrôle de l'aperçu (constaté au premier jet de ce banc).

-- 1. Legacy, dont le DERNIER message est celui qui expire.
INSERT INTO public.conversations (id, type, participant_ids, data, created_by,
                                  last_message_at)
VALUES ('banc-ephemere', 'individual', ARRAY['u1','u2'],
        '{"autoDeleteAfterSeconds": 86400, "lastMessage": "secret"}'::jsonb, 'u1',
        now() - interval '2 days');

-- 2. Legacy, dont le dernier message N'EST PAS celui qui expire : son aperçu
--    doit rester intact même si un message plus ancien de la conversation
--    expire en même temps.
INSERT INTO public.conversations (id, type, participant_ids, data, created_by,
                                  last_message_at)
VALUES ('banc-intouche', 'individual', ARRAY['u1','u3'],
        '{"autoDeleteAfterSeconds": 86400, "lastMessage": "a garder"}'::jsonb, 'u1',
        now());

-- 3. MLS.
INSERT INTO public.conversations (id, type, participant_ids, data, created_by)
VALUES ('banc-mls', 'individual', ARRAY['u1','u2'], '{}'::jsonb, 'u1');

INSERT INTO public.messages (id, conversation_id, sender_id, type, is_deleted, created_at, data)
VALUES
  -- Le dernier message de 'banc-ephemere', expiré : pierre tombale + aperçu vidé.
  ('banc-expire', 'banc-ephemere', 'u1', 'text', false, now() - interval '2 days',
   jsonb_build_object(
     'content', 'secret',
     'fileUrl', 'https://exemple/blob',
     'encMedia', 'cle-du-media',
     'encAnnexes', 'apercu-de-partage',
     'postData', jsonb_build_object('authorName', 'quelqu''un'),
     'senderName', 'Moi',
     'expiresAt', to_char((now() - interval '1 day') AT TIME ZONE 'UTC',
                          'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"'))),
  -- Pas encore expiré : intact.
  ('banc-vivant', 'banc-ephemere', 'u1', 'text', false, now(),
   jsonb_build_object('content', 'encore la', 'senderName', 'Moi',
     'expiresAt', to_char((now() + interval '1 day') AT TIME ZONE 'UTC',
                          'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"'))),
  -- Sans minuteur : jamais touché.
  ('banc-permanent', 'banc-ephemere', 'u1', 'text', false, now() - interval '9 days',
   jsonb_build_object('content', 'permanent', 'senderName', 'Moi')),
  -- Échéance mal formée : ne doit ni être purgée, ni faire échouer la purge.
  ('banc-malforme', 'banc-ephemere', 'u1', 'text', false, now() - interval '9 days',
   jsonb_build_object('content', 'bancal', 'senderName', 'Moi',
                      'expiresAt', 'pas-une-date')),
  -- Déjà une pierre tombale : ne doit pas être recomptée.
  ('banc-deja-tombe', 'banc-ephemere', 'u1', 'text', true, now() - interval '9 days',
   jsonb_build_object('content', '', 'deletedForEveryone', true,
     'expiresAt', to_char((now() - interval '8 days') AT TIME ZONE 'UTC',
                          'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"'))),
  -- Dans 'banc-intouche' : un message expiré qui n'est PAS le dernier.
  ('banc-vieux-expire', 'banc-intouche', 'u1', 'text', false, now() - interval '5 days',
   jsonb_build_object('content', 'vieux secret', 'senderName', 'Moi',
     'expiresAt', to_char((now() - interval '4 days') AT TIME ZONE 'UTC',
                          'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')));

INSERT INTO public.mls_messages
  (id, conversation_id, sender_id, sender_device_id, epoch, kind, content_type,
   ciphertext, expires_at, created_at)
SELECT gen_random_uuid(), 'banc-mls', 'u1', d.id, 1, 'content', 'text',
       '\xdeadbeef'::bytea, now() - interval '1 hour', now() - interval '2 days'
  FROM public.mls_devices d LIMIT 1;

INSERT INTO public.mls_messages
  (id, conversation_id, sender_id, sender_device_id, epoch, kind, content_type,
   ciphertext, expires_at, created_at)
SELECT gen_random_uuid(), 'banc-mls', 'u1', d.id, 1, 'content', 'text',
       '\xcafe'::bytea, now() + interval '1 hour', now()
  FROM public.mls_devices d LIMIT 1;

-- ── Exécution : deux passages, pour éprouver l'idempotence ────────────────
CREATE TEMP TABLE passage1 AS SELECT * FROM public.purger_messages_expires();
CREATE TEMP TABLE passage2 AS SELECT * FROM public.purger_messages_expires();

-- ── Verdicts ──────────────────────────────────────────────────────────────
SELECT controle, obtenu, attendu,
       CASE WHEN obtenu = attendu THEN 'VERT' ELSE '*** ROUGE ***' END AS verdict
FROM (
  VALUES
    ('1er passage purge 2 messages legacy',
     (SELECT legacy::text FROM passage1), '2'),
    ('1er passage purge 1 message MLS',
     (SELECT mls::text FROM passage1), '1'),
    ('2e passage ne retrouve rien (legacy)',
     (SELECT legacy::text FROM passage2), '0'),
    ('2e passage ne retrouve rien (MLS)',
     (SELECT mls::text FROM passage2), '0'),
    ('expiré : devenu pierre tombale',
     (SELECT is_deleted::text FROM public.messages WHERE id = 'banc-expire'), 'true'),
    ('expiré : contenu vidé',
     (SELECT coalesce(data->>'content', '<absent>') FROM public.messages WHERE id = 'banc-expire'), ''),
    ('expiré : fileUrl retiré',
     (SELECT (data ? 'fileUrl')::text FROM public.messages WHERE id = 'banc-expire'), 'false'),
    ('expiré : clé du média retirée',
     (SELECT (data ? 'encMedia')::text FROM public.messages WHERE id = 'banc-expire'), 'false'),
    ('expiré : aperçu de partage retiré',
     (SELECT (data ? 'encAnnexes')::text FROM public.messages WHERE id = 'banc-expire'), 'false'),
    ('expiré : postData en clair retiré',
     (SELECT (data ? 'postData')::text FROM public.messages WHERE id = 'banc-expire'), 'false'),
    ('expiré : marqué expiredAt (≠ supprimé)',
     (SELECT (data ? 'expiredAt')::text FROM public.messages WHERE id = 'banc-expire'), 'true'),
    ('expiré : auteur conservé (le fil garde sa forme)',
     (SELECT data->>'senderName' FROM public.messages WHERE id = 'banc-expire'), 'Moi'),
    ('pas encore expiré : intact',
     (SELECT data->>'content' FROM public.messages WHERE id = 'banc-vivant'), 'encore la'),
    ('pas encore expiré : pas de tombe',
     (SELECT is_deleted::text FROM public.messages WHERE id = 'banc-vivant'), 'false'),
    ('sans minuteur : jamais touché',
     (SELECT data->>'content' FROM public.messages WHERE id = 'banc-permanent'), 'permanent'),
    ('échéance mal formée : épargnée, pas d''erreur',
     (SELECT data->>'content' FROM public.messages WHERE id = 'banc-malforme'), 'bancal'),
    ('tombe déjà posée : pas recomptée',
     (SELECT (data ? 'expiredAt')::text FROM public.messages WHERE id = 'banc-deja-tombe'), 'false'),
    ('aperçu vidé quand le dernier message expire',
     (SELECT data->>'lastMessage' FROM public.conversations WHERE id = 'banc-ephemere'), ''),
    ('aperçu gardé quand ce n''est PAS le dernier qui expire',
     (SELECT data->>'lastMessage' FROM public.conversations WHERE id = 'banc-intouche'), 'a garder'),
    ('mais ce vieux message-là est bien purgé',
     (SELECT (data ? 'expiredAt')::text FROM public.messages WHERE id = 'banc-vieux-expire'), 'true'),
    ('le minuteur de la conversation survit à la purge',
     (SELECT data->>'autoDeleteAfterSeconds' FROM public.conversations WHERE id = 'banc-ephemere'), '86400'),
    ('MLS expiré : ciphertext vidé',
     (SELECT length(ciphertext)::text FROM public.mls_messages
       WHERE conversation_id = 'banc-mls' AND is_deleted), '0'),
    ('MLS expiré : deleted_at horodaté',
     (SELECT (deleted_at IS NOT NULL)::text FROM public.mls_messages
       WHERE conversation_id = 'banc-mls' AND is_deleted), 'true'),
    ('MLS pas encore expiré : ciphertext intact',
     (SELECT length(ciphertext)::text FROM public.mls_messages
       WHERE conversation_id = 'banc-mls' AND NOT is_deleted), '2'),
    ('notification du message expiré marquée lue',
     (SELECT count(*)::text FROM public.notifications
       WHERE NOT is_read AND data->>'messageId' = 'banc-expire'), '0'),
    ('job cron présent, une seule fois',
     (SELECT count(*)::text FROM cron.job WHERE jobname = 'purger-messages-expires'), '1'),
    ('purge refusée à authenticated',
     (SELECT has_function_privilege('authenticated',
        'public.purger_messages_expires()', 'EXECUTE')::text), 'false'),
    ('purge refusée à anon',
     (SELECT has_function_privilege('anon',
        'public.purger_messages_expires()', 'EXECUTE')::text), 'false')
) AS t(controle, obtenu, attendu);

ROLLBACK;
