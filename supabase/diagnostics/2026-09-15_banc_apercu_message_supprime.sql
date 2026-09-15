-- Banc de l'aperçu qui dit pourquoi il est vide (2026-09-15).
--
-- CE QU'IL ÉPROUVE
-- `conversations.data->>'lastMessage'` porte le dernier message **en clair**.
-- Trois choses peuvent le vider ou le réécrire, et aucune ne se voit depuis
-- l'application quand elle échoue :
--
--   * « supprimer pour tout le monde » (client, `_viderApercuSiDernier`) ;
--   * la purge des messages éphémères (`purger_messages_expires()`) ;
--   * le trigger d'aperçu MLS (`mls_messages_apercu_conversation()`), qui
--     retire `lastMessage` à chaque message chiffré.
--
-- Depuis qu'elles sont deux à vider, le libellé affiché ne peut plus se
-- deviner : deux marques le disent, `lastMessageDeleted` et
-- `lastMessageExpired`. Ce banc vérifie qu'elles sont posées où il faut et
-- — surtout — **effacées partout ailleurs**. Une marque oubliée sous un
-- aperçu neuf ferait dire « Message supprimé » à une conversation vivante,
-- pour toujours, sans une ligne de journal.
--
-- COMMENT LE LANCER
-- La migration 20260915235900 doit être appliquée. Tout est enveloppé dans
-- BEGIN/ROLLBACK : le banc écrit dans la vraie base et n'y laisse rien.
--
--   supabase db query --linked -f supabase/diagnostics/2026-09-15_banc_apercu_message_supprime.sql
--
-- Pour l'éprouver AVANT de déployer, concaténer la migration et ce fichier
-- (la migration en premier, sans son propre BEGIN) : le DDL de PostgreSQL est
-- transactionnel, le ROLLBACK final rend aussi les anciennes fonctions.
--
-- `supabase db query` ne rend que le DERNIER jeu de résultats : d'où la table
-- de verdicts unique en fin de fichier. Lire la colonne `verdict` ; tout doit
-- être VERT.
--
-- ⚠️ Identités : `db query --linked` se connecte en `postgres`, qui contourne
-- RLS. Le geste du client passe donc par `SET LOCAL ROLE authenticated` +
-- `request.jwt.claims` — sans quoi le banc prouverait seulement que
-- `postgres` sait écrire, ce dont personne ne doute.

BEGIN;

-- ── Jeu d'essai ───────────────────────────────────────────────────────────
--
-- Trois conversations séparées. Un message MLS déclenche le trigger d'aperçu,
-- qui repositionne `last_message_at` sur SON created_at : mêler legacy et MLS
-- dans la même conversation ferait mentir tous les contrôles d'aperçu.

-- 1. Legacy, dont le dernier message va expirer. Elle porte DÉJÀ la marque
--    « supprimé » — un cas réel : le dernier message avait été supprimé, un
--    autre est parti depuis, et celui-là expire. La purge doit laisser la
--    marque « expiré » SEULE.
INSERT INTO public.conversations (id, type, participant_ids, data, created_by,
                                  last_message_at)
VALUES ('banc-ap-expire', 'individual', ARRAY['banc-u1','banc-u2'],
        '{"lastMessage": "secret expire", "lastMessageDeleted": true}'::jsonb,
        'banc-u1', now() - interval '2 days');

-- 2. MLS, portant les DEUX marques et un aperçu en clair hérité de son passé
--    legacy. Le premier message chiffré doit tout emporter.
INSERT INTO public.conversations (id, type, participant_ids, data, created_by)
VALUES ('banc-ap-mls', 'individual', ARRAY['banc-u1','banc-u2'],
        '{"lastMessage": "clair d''avant la bascule",
          "lastMessageDeleted": true, "lastMessageExpired": true}'::jsonb,
        'banc-u1');

-- 3. Groupe legacy : le geste du client, joué sous l'identité d'un
--    participant ordinaire. C'est là que `conversations_guard_admin_fields`
--    pourrait refuser l'écriture — il ne doit pas, `adminIds` et
--    `participant_ids` restant intacts. Un refus ici (42501) ferait échouer
--    « supprimer pour tout le monde » côté application.
INSERT INTO public.conversations (id, type, group_id, participant_ids, data,
                                  created_by, last_message_at)
VALUES ('banc-ap-groupe', 'group', 'banc-groupe-legacy',
        ARRAY['banc-u1','banc-u2'],
        '{"lastMessage": "a supprimer", "adminIds": ["banc-u2"]}'::jsonb,
        'banc-u2', now());

INSERT INTO public.messages (id, conversation_id, sender_id, type, is_deleted,
                             created_at, data)
VALUES
  ('banc-ap-msg-expire', 'banc-ap-expire', 'banc-u1', 'text', false,
   now() - interval '2 days',
   jsonb_build_object('content', 'secret expire', 'senderName', 'Moi',
     'expiresAt', to_char((now() - interval '1 day') AT TIME ZONE 'UTC',
                          'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')));

-- ── A. La purge : « expiré » posé, « supprimé » retiré ────────────────────
SELECT public.purger_messages_expires();

-- ── B. Le trigger MLS : tout emporté, marques comprises ──────────────────
INSERT INTO public.mls_messages
  (id, conversation_id, sender_id, sender_device_id, epoch, kind, content_type,
   ciphertext, created_at)
SELECT gen_random_uuid(), 'banc-ap-mls', 'banc-u1', d.id, 1, 'content', 'text',
       '\xdeadbeef'::bytea, now()
  FROM public.mls_devices d LIMIT 1;

-- ── C. Le geste du client, sous l'identité d'un participant ordinaire ────
-- Exactement ce qu'écrit `_viderApercuSiDernier` : l'aperçu vidé, la marque
-- « supprimé » posée, l'autre retirée — et rien d'autre.
SET LOCAL ROLE authenticated;
-- `sub` doit être un UUID : `firebase_uid()` est une fonction SQL inlinée,
-- donc PostgreSQL évalue AUSSI la branche de repli (`auth.uid()`, qui caste
-- `sub` en uuid) même quand `app_metadata.firebase_uid` suffirait. Un `sub`
-- non-UUID fait échouer la fonction entière — 22P02 « during startup » — et
-- l'erreur ne parle ni de RLS ni de la requête qu'on croyait tester.
SET LOCAL request.jwt.claims TO '{"role":"authenticated","sub":"44444444-4444-4444-4444-444444444444","app_metadata":{"firebase_uid":"banc-u1"}}';

DO $t$
DECLARE v_touchees integer;
BEGIN
  UPDATE public.conversations
     SET data = (data - 'lastMessageExpired')
                || '{"lastMessage": "", "lastMessageDeleted": true}'::jsonb
   WHERE id = 'banc-ap-groupe';
  GET DIAGNOSTICS v_touchees = ROW_COUNT;
  IF v_touchees <> 1 THEN
    RAISE EXCEPTION
      'ECHEC C : un participant ordinaire ne peut pas vider l''apercu (% lignes)',
      v_touchees;
  END IF;
END
$t$;

RESET ROLE;

-- ── Verdicts ──────────────────────────────────────────────────────────────
SELECT controle, obtenu, attendu,
       CASE WHEN obtenu = attendu THEN 'VERT' ELSE '*** ROUGE ***' END AS verdict
FROM (
  VALUES
    -- A. la purge
    ('purge : aperçu vidé',
     (SELECT coalesce(data->>'lastMessage', '<absent>') FROM public.conversations
       WHERE id = 'banc-ap-expire'), ''),
    ('purge : marque « expiré » posée',
     (SELECT coalesce(data->>'lastMessageExpired', '<absent>') FROM public.conversations
       WHERE id = 'banc-ap-expire'), 'true'),
    ('purge : marque « supprimé » retirée (elles s''excluent)',
     (SELECT (data ? 'lastMessageDeleted')::text FROM public.conversations
       WHERE id = 'banc-ap-expire'), 'false'),
    ('purge : la pierre tombale est bien posée',
     (SELECT is_deleted::text FROM public.messages
       WHERE id = 'banc-ap-msg-expire'), 'true'),

    -- B. le trigger MLS
    ('MLS : aperçu en clair emporté',
     (SELECT (data ? 'lastMessage')::text FROM public.conversations
       WHERE id = 'banc-ap-mls'), 'false'),
    ('MLS : marque « supprimé » emportée avec lui',
     (SELECT (data ? 'lastMessageDeleted')::text FROM public.conversations
       WHERE id = 'banc-ap-mls'), 'false'),
    ('MLS : marque « expiré » emportée avec lui',
     (SELECT (data ? 'lastMessageExpired')::text FROM public.conversations
       WHERE id = 'banc-ap-mls'), 'false'),
    ('MLS : le type prend la place du texte',
     (SELECT data->>'lastMessageType' FROM public.conversations
       WHERE id = 'banc-ap-mls'), 'text'),

    -- C. le geste du client
    ('client : aperçu vidé par un participant ordinaire',
     (SELECT coalesce(data->>'lastMessage', '<absent>') FROM public.conversations
       WHERE id = 'banc-ap-groupe'), ''),
    ('client : marque « supprimé » posée',
     (SELECT coalesce(data->>'lastMessageDeleted', '<absent>') FROM public.conversations
       WHERE id = 'banc-ap-groupe'), 'true'),
    ('client : adminIds intact (le garde ne s''est pas fâché)',
     (SELECT data->'adminIds'->>0 FROM public.conversations
       WHERE id = 'banc-ap-groupe'), 'banc-u2'),

    -- La purge reste hors de portée des clients
    ('purge refusée à authenticated',
     (SELECT has_function_privilege('authenticated',
        'public.purger_messages_expires()', 'EXECUTE')::text), 'false'),
    ('purge refusée à anon',
     (SELECT has_function_privilege('anon',
        'public.purger_messages_expires()', 'EXECUTE')::text), 'false')
) AS t(controle, obtenu, attendu);

ROLLBACK;
