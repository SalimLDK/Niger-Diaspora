-- Banc de la suppression de compte par phases.
--
-- SE JOUE APRÈS LA MIGRATION 20260918224100, DANS LA MÊME TRANSACTION (les
-- fonctions n'existent pas encore en production tant qu'elle n'est pas
-- appliquée) :
--
--   { echo "BEGIN;"; \
--     cat supabase/migrations/20260918224100_suppression_de_compte_par_phases.sql; \
--     cat tools/rls_tests/suppression_compte.sql; \
--     echo "ROLLBACK;"; } > /tmp/suppression_compte_banc.sql
--   supabase db query --linked -o csv -f /tmp/suppression_compte_banc.sql
--
-- Une fois la migration appliquée, ce fichier se joue seul entre `BEGIN;` et
-- `ROLLBACK;`. Condition : 0 cas en ÉCHEC — la dernière ligne le dit.
--
-- CE QUE LE BANC ÉTABLIT
-- Il fabrique un petit monde fictif (comptes `zz_del_*`, jamais un vrai
-- uid) puis fait passer le compte A par toute la chaîne : demande →
-- désactivation → annulation → nouvelle demande → échéance → réclamation →
-- purge. Il mesure, famille par famille, ce qui reste :
--   · les décisions du 2026-09-18 (1:1 supprimés, groupes anonymisés, MLS
--     vidés, événements et commerces supprimés, groupes transmis ou dissous) ;
--   · ce qui n'a AUCUNE clé étrangère (messages, group_members, friends…) ;
--   · l'identité Supabase (auth.users, auth_mappings) ;
--   · le masquage pendant le délai, vu depuis un autre compte SOUS RLS ;
--   · les droits (le client ne doit pas pouvoir réclamer ni purger).
--
-- Tout est dans la transaction annulée. Les seuls comptes touchés sont
-- fictifs : les déclencheurs de notification n'y trouvent aucun jeton FCM, et
-- pg_net n'envoie rien qui n'ait été validé.

CREATE TEMP TABLE resultat(n int, cas text, attendu text, obtenu text, verdict text);
CREATE TEMP TABLE ctx(k text PRIMARY KEY, v text);
CREATE TEMP TABLE purge_out(j jsonb);
GRANT ALL ON resultat, ctx, purge_out TO authenticated, anon;

-- Créée AVANT tout SET ROLE : une fonction créée après appartiendrait au rôle
-- courant (voir project_rls_testing_bypass_pitfall).
CREATE FUNCTION pg_temp.verifie(p_n int, p_cas text, p_attendu text, p_obtenu text)
RETURNS void LANGUAGE sql AS $$
  INSERT INTO resultat VALUES (p_n, p_cas, p_attendu, p_obtenu,
    CASE WHEN p_attendu IS NOT DISTINCT FROM p_obtenu THEN 'OK' ELSE 'ÉCHEC' END)
$$;

-- Usurpe un compte pour les vérifications sous RLS.
CREATE FUNCTION pg_temp.moi(p_uid text, p_sub uuid) RETURNS void LANGUAGE sql AS $$
  SELECT set_config('request.jwt.claims',
    jsonb_build_object('sub', p_sub, 'role', 'authenticated',
                       'app_metadata', jsonb_build_object('firebase_uid', p_uid))::text, true)
$$;

-- ═══ Le monde fictif ════════════════════════════════════════════════════════
-- Identifiants fixes, pour que chaque contrôle dise ce qu'il mesure.
--   A  zz_del_a : le compte qui se supprime
--   B  zz_del_b : son ami, futur propriétaire du groupe G1
--   C  zz_del_c : simple membre
--   D  zz_del_d : propriétaire d'un groupe OFFICIEL (doit être refusé)

INSERT INTO public.users (id, email, display_name) VALUES
  ('zz_del_a', 'zz_a@example.invalid', 'Alice Test'),
  ('zz_del_b', 'zz_b@example.invalid', 'Basile Test'),
  ('zz_del_c', 'zz_c@example.invalid', 'Carine Test'),
  ('zz_del_d', 'zz_d@example.invalid', 'Didier Test');

INSERT INTO auth.users (id, email) VALUES
  ('a0000000-0000-4000-8000-00000000000a', 'zz_a@example.invalid'),
  ('a0000000-0000-4000-8000-00000000000b', 'zz_b@example.invalid'),
  ('a0000000-0000-4000-8000-00000000000d', 'zz_d@example.invalid');
INSERT INTO public.auth_mappings (supabase_id, firebase_uid) VALUES
  ('a0000000-0000-4000-8000-00000000000a', 'zz_del_a'),
  ('a0000000-0000-4000-8000-00000000000b', 'zz_del_b'),
  ('a0000000-0000-4000-8000-00000000000d', 'zz_del_d');
INSERT INTO auth.sessions (id, user_id) VALUES
  ('a1000000-0000-4000-8000-000000000001', 'a0000000-0000-4000-8000-00000000000a');

-- Groupes. `enforce_group_creator` (BEFORE INSERT) refuse sans identité et
-- écrase `creator_id` par celle de l'appelant : on s'annonce d'abord.
SELECT pg_temp.moi('zz_del_a', 'a0000000-0000-4000-8000-00000000000a');
INSERT INTO public.groups (id, name, creator_id) VALUES
  ('c0000000-0000-4000-8000-0000000000a1', 'Groupe fictif G1', 'zz_del_a'),
  ('c0000000-0000-4000-8000-0000000000a2', 'Groupe fictif G2 (seul)', 'zz_del_a');
SELECT pg_temp.moi('zz_del_d', 'a0000000-0000-4000-8000-00000000000d');
INSERT INTO public.groups (id, name, creator_id) VALUES
  ('c0000000-0000-4000-8000-0000000000a3', 'Groupe fictif G3 (officiel)', 'zz_del_d');
SELECT set_config('request.jwt.claims', '', true);
-- Sans identité, `guard_group_official` laisse passer (chemin migration).
-- Un seul groupe officiel par pays (`uniq_groupe_officiel_par_pays`) et le
-- déclencheur pose « Niger » par défaut : on prend un pays qui n'existe pas.
UPDATE public.groups SET is_official = true, country_code = 'Zzland'
 WHERE id = 'c0000000-0000-4000-8000-0000000000a3';

INSERT INTO public.group_members (group_id, user_id, role, joined_at) VALUES
  ('c0000000-0000-4000-8000-0000000000a1', 'zz_del_a', 'owner',  now() - interval '30 days'),
  ('c0000000-0000-4000-8000-0000000000a1', 'zz_del_b', 'member', now() - interval '20 days'),
  ('c0000000-0000-4000-8000-0000000000a1', 'zz_del_c', 'member', now() - interval '10 days'),
  ('c0000000-0000-4000-8000-0000000000a2', 'zz_del_a', 'owner',  now() - interval '30 days'),
  ('c0000000-0000-4000-8000-0000000000a3', 'zz_del_d', 'owner',  now() - interval '30 days');
INSERT INTO public.group_pinned_items (group_id, item_type, item_id, pinned_by)
VALUES ('c0000000-0000-4000-8000-0000000000a1', 'message', 'zz-msg-g1-b', 'zz_del_a');

-- Conversations : 1:1 A–B, groupe G1 (adossé à un groupe), groupe G2 (A seul),
-- et un groupe « ad hoc » (type group, sans group_id).
INSERT INTO public.conversations (id, type, participant_ids, created_by, group_id, data) VALUES
  ('zz-conv-ab', 'individual', ARRAY['zz_del_a','zz_del_b'], 'zz_del_a', NULL, '{}'::jsonb),
  ('zz-conv-g1', 'group', ARRAY['zz_del_a','zz_del_b','zz_del_c'], 'zz_del_a',
     'c0000000-0000-4000-8000-0000000000a1',
     '{"adminIds":["zz_del_a"],"unreadCount":{"zz_del_a":2,"zz_del_b":0},"lastMessageReadBy":["zz_del_a","zz_del_b"],"lastMessageSenderId":"zz_del_a"}'::jsonb),
  ('zz-conv-g2', 'group', ARRAY['zz_del_a'], 'zz_del_a',
     'c0000000-0000-4000-8000-0000000000a2', '{"adminIds":["zz_del_a"]}'::jsonb),
  ('zz-conv-adhoc', 'group', ARRAY['zz_del_a','zz_del_b','zz_del_c'], 'zz_del_a', NULL,
     '{"adminIds":["zz_del_a"]}'::jsonb);
UPDATE public.conversations SET last_message_sender_id = 'zz_del_a' WHERE id = 'zz-conv-g1';

-- Messages en clair.
INSERT INTO public.messages (id, conversation_id, sender_id, data) VALUES
  ('zz-msg-ab-1', 'zz-conv-ab', 'zz_del_a', '{"content":"salut","senderName":"Alice Test"}'),
  ('zz-msg-g1-a', 'zz-conv-g1', 'zz_del_a',
     '{"content":"bonjour le groupe","senderName":"Alice Test","senderPhotoUrl":"https://ex.invalid/a.jpg","editedAt":"2026-01-01T00:00:00Z","editHistory":[{"content":"version 1"}],"readBy":["zz_del_b"]}'),
  ('zz-msg-g1-b', 'zz-conv-g1', 'zz_del_b',
     '{"content":"réponse de B","senderName":"Basile Test","readBy":["zz_del_a","zz_del_b"],"deliveredTo":["zz_del_a"],"readAt":{"zz_del_a":"2026-01-01T00:00:00Z","zz_del_c":"2026-01-02T00:00:00Z"},"deliveredAt":{"zz_del_a":"2026-01-01T00:00:00Z"},"reactions":{"zz_del_a":"👍","zz_del_c":"❤️"},"replyToMessageData":{"id":"zz-msg-g1-a","senderId":"zz_del_a","senderName":"Alice Test","content":"bonjour le groupe","type":"text"}}');

-- MLS : deux appareils de A, l'un cité par un message de groupe, l'autre non.
INSERT INTO public.mls_devices (id, user_id, stable_id, name, platform, mls_identity, signature_key, credential) VALUES
  ('d0000000-0000-4000-8000-000000000001', 'zz_del_a', 'zz_stable_1', 'Pixel de A', 'android', 'zz_del_a:zz_stable_1', '\x01', '\x02'),
  ('d0000000-0000-4000-8000-000000000002', 'zz_del_a', 'zz_stable_2', 'Tablette de A', 'android', 'zz_del_a:zz_stable_2', '\x01', '\x02');
INSERT INTO public.mls_messages (id, conversation_id, sender_id, sender_device_id, epoch, kind, content_type, ciphertext)
VALUES ('e0000000-0000-4000-8000-000000000001', 'zz-conv-g1', 'zz_del_a',
        'd0000000-0000-4000-8000-000000000001', 1, 'content', 'text', '\xdeadbeef');

-- Événement et commerce de A ; participation de B ; avis de B ; boost de A.
INSERT INTO public.events (id, organizer_id, title, starts_at, visibility)
VALUES ('f0000000-0000-4000-8000-000000000001', 'zz_del_a', 'Événement fictif', now() - interval '3 days', 'public');
INSERT INTO public.event_attendees (event_id, user_id)
VALUES ('f0000000-0000-4000-8000-000000000001', 'zz_del_b');
-- `businesses_description_non_vide` : la description par défaut est vide.
INSERT INTO public.businesses (id, owner_id, name, description, is_active)
VALUES ('b0000000-0000-4000-8000-000000000001', 'zz_del_a', 'Commerce fictif', 'Un commerce pour le banc', true);
INSERT INTO public.business_reviews (business_id, user_id, rating, content)
VALUES ('b0000000-0000-4000-8000-000000000001', 'zz_del_b', 5, 'très bien');
INSERT INTO public.business_boosts (business_id, user_id, amount, start_date, end_date)
VALUES ('b0000000-0000-4000-8000-000000000001', 'zz_del_a', 1, now(), now() + interval '1 day');

-- Publications : une de B (A y commente et aime), une de A (doit être masquée).
INSERT INTO public.posts (id, author_id, visibility) VALUES
  ('90000000-0000-4000-8000-0000000000b1', 'zz_del_b', 'public'),
  ('90000000-0000-4000-8000-0000000000a1', 'zz_del_a', 'public');
INSERT INTO public.post_comments (post_id, author_id, content)
VALUES ('90000000-0000-4000-8000-0000000000b1', 'zz_del_a', 'commentaire de A');
INSERT INTO public.post_likes (post_id, user_id)
VALUES ('90000000-0000-4000-8000-0000000000b1', 'zz_del_a');

-- Graphe social.
INSERT INTO public.friends (user_id, friend_id) VALUES ('zz_del_a', 'zz_del_b'), ('zz_del_b', 'zz_del_a');
INSERT INTO public.friend_requests (sender_id, receiver_id) VALUES ('zz_del_c', 'zz_del_a');
INSERT INTO public.user_follows (follower_id, following_id) VALUES ('zz_del_b', 'zz_del_a');

-- Notifications : celle que A reçoit ; celle que A a déclenchée chez B.
INSERT INTO public.notifications (user_id, type, title, body, data) VALUES
  ('zz_del_a', 'info', 't', 'reçue par A', '{}'),
  ('zz_del_b', 'info', 't', 'déclenchée par A', '{"actor_id":"zz_del_a","senderName":"Alice Test"}');

-- Posés EN DERNIER : les INSERT de messages (plain et MLS) déclenchent des
-- écritures d'aperçu sur la conversation (`lastMessageReadBy` remis à []), et
-- `member_count` part de 1 par défaut avant que les INSERT directs de
-- `group_members` l'incrémentent.
UPDATE public.groups SET member_count = 3 WHERE id = 'c0000000-0000-4000-8000-0000000000a1';
UPDATE public.conversations
   SET data = '{"adminIds":["zz_del_a"],"unreadCount":{"zz_del_a":2,"zz_del_b":0},"lastMessageReadBy":["zz_del_a","zz_del_b"],"lastMessageSenderId":"zz_del_a"}'::jsonb,
       last_message_sender_id = 'zz_del_a'
 WHERE id = 'zz-conv-g1';

-- Compteurs de départ, pour prouver que le banc voit bien les lignes.
SELECT pg_temp.verifie(0, 'préalable : le monde fictif est en place',
  '4 comptes, 3 groupes, 4 conversations',
  (SELECT count(*) FROM public.users WHERE id LIKE 'zz_del_%')::text || ' comptes, '
  || (SELECT count(*) FROM public.groups WHERE name LIKE 'Groupe fictif%')::text || ' groupes, '
  || (SELECT count(*) FROM public.conversations WHERE id LIKE 'zz-conv-%')::text || ' conversations');

-- ═══ Droits ═════════════════════════════════════════════════════════════════
SELECT pg_temp.verifie(1, 'droits : le client demande et annule, jamais réclame ni purge',
  'req=true/true can=true/true claim=false/false/true comp=false/false/true purge=false/false',
  'req=' || has_function_privilege('authenticated','public.request_account_deletion()','EXECUTE')::text
      || '/' || (NOT has_function_privilege('anon','public.request_account_deletion()','EXECUTE'))::text
  || ' can=' || has_function_privilege('authenticated','public.cancel_account_deletion()','EXECUTE')::text
      || '/' || (NOT has_function_privilege('anon','public.cancel_account_deletion()','EXECUTE'))::text
  || ' claim=' || has_function_privilege('authenticated','public.claim_due_account_deletions(integer)','EXECUTE')::text
      || '/' || has_function_privilege('anon','public.claim_due_account_deletions(integer)','EXECUTE')::text
      || '/' || has_function_privilege('service_role','public.claim_due_account_deletions(integer)','EXECUTE')::text
  || ' comp=' || has_function_privilege('authenticated','public.complete_account_deletion(text)','EXECUTE')::text
      || '/' || has_function_privilege('anon','public.complete_account_deletion(text)','EXECUTE')::text
      || '/' || has_function_privilege('service_role','public.complete_account_deletion(text)','EXECUTE')::text
  || ' purge=' || has_function_privilege('authenticated','private.purge_account(text)','EXECUTE')::text
      || '/' || has_function_privilege('anon','private.purge_account(text)','EXECUTE')::text);

SELECT pg_temp.verifie(2, 'droits : la table ne s''écrit pas depuis le client et cache ses colonnes internes',
  'insert=false update=false delete=false last_error=false restore=false status=true',
  'insert=' || has_table_privilege('authenticated','public.account_deletion_requests','INSERT')::text
  || ' update=' || has_table_privilege('authenticated','public.account_deletion_requests','UPDATE')::text
  || ' delete=' || has_table_privilege('authenticated','public.account_deletion_requests','DELETE')::text
  || ' last_error=' || has_column_privilege('authenticated','public.account_deletion_requests','last_error','SELECT')::text
  || ' restore=' || has_column_privilege('authenticated','public.account_deletion_requests','restore','SELECT')::text
  || ' status=' || has_column_privilege('authenticated','public.account_deletion_requests','status','SELECT')::text);

-- ═══ Publications visibles avant la demande (sous RLS, vu par B) ════════════
SET LOCAL ROLE authenticated;
SELECT pg_temp.moi('zz_del_b', 'a0000000-0000-4000-8000-00000000000b');
SELECT pg_temp.verifie(3, 'avant : B voit la publication et le profil de A',
  'post=1 profil=1',
  'post=' || (SELECT count(*) FROM public.posts WHERE id = '90000000-0000-4000-8000-0000000000a1')::text
  || ' profil=' || (SELECT count(*) FROM public.users WHERE id = 'zz_del_a')::text);

-- ═══ Demande (A) ════════════════════════════════════════════════════════════
SELECT pg_temp.moi('zz_del_a', 'a0000000-0000-4000-8000-00000000000a');
INSERT INTO ctx SELECT 'execute_at_1', public.request_account_deletion()::text;
INSERT INTO ctx SELECT 'execute_at_2', public.request_account_deletion()::text;

SELECT pg_temp.verifie(4, 'demande : idempotente, la date ne glisse pas',
  'true', ((SELECT v FROM ctx WHERE k = 'execute_at_1') = (SELECT v FROM ctx WHERE k = 'execute_at_2'))::text);

SELECT pg_temp.verifie(5, 'demande : échéance dans ~30 jours',
  'true',
  ((SELECT v::timestamptz FROM ctx WHERE k = 'execute_at_1') BETWEEN now() + interval '29 days 23 hours' AND now() + interval '30 days 1 hour')::text);

RESET ROLE;
SELECT pg_temp.verifie(6, 'demande : profil masqué, invisible, hors ligne, sans jeton',
  'private=true visible=false online=false tokens=[]',
  (SELECT 'private=' || u.is_private::text || ' visible=' || u.is_visible::text
       || ' online=' || u.is_online::text || ' tokens=' || u.fcm_tokens::text
     FROM public.users u WHERE u.id = 'zz_del_a'));
SELECT pg_temp.verifie(7, 'demande : commerce dépublié, sessions Supabase révoquées',
  'actif=false sessions=0',
  'actif=' || (SELECT is_active::text FROM public.businesses WHERE id = 'b0000000-0000-4000-8000-000000000001')
  || ' sessions=' || (SELECT count(*) FROM auth.sessions WHERE user_id = 'a0000000-0000-4000-8000-00000000000a')::text);

SET LOCAL ROLE authenticated;
SELECT pg_temp.moi('zz_del_b', 'a0000000-0000-4000-8000-00000000000b');
SELECT pg_temp.verifie(8, 'pendant le délai : B ne voit plus ni la publication ni le profil de A',
  'post=0 profil=0',
  'post=' || (SELECT count(*) FROM public.posts WHERE id = '90000000-0000-4000-8000-0000000000a1')::text
  || ' profil=' || (SELECT count(*) FROM public.users WHERE id = 'zz_del_a')::text);
SELECT pg_temp.moi('zz_del_a', 'a0000000-0000-4000-8000-00000000000a');
SELECT pg_temp.verifie(9, 'pendant le délai : A voit toujours sa propre publication',
  'post=1', 'post=' || (SELECT count(*) FROM public.posts WHERE id = '90000000-0000-4000-8000-0000000000a1')::text);
SELECT pg_temp.verifie(10, 'A lit sa demande (colonnes accordées seulement)',
  'pending', (SELECT status FROM public.account_deletion_requests WHERE user_id = 'zz_del_a'));
SELECT pg_temp.moi('zz_del_b', 'a0000000-0000-4000-8000-00000000000b');
SELECT pg_temp.verifie(11, 'B ne lit pas la demande de A',
  '0', (SELECT count(*) FROM public.account_deletion_requests WHERE user_id = 'zz_del_a')::text);

-- ═══ Annulation, puis nouvelle demande ══════════════════════════════════════
SELECT pg_temp.moi('zz_del_a', 'a0000000-0000-4000-8000-00000000000a');
SELECT public.cancel_account_deletion();
RESET ROLE;
SELECT pg_temp.verifie(12, 'annulation : visibilité et commerce remis comme avant',
  'private=false visible=true actif=true statut=cancelled',
  (SELECT 'private=' || u.is_private::text || ' visible=' || u.is_visible::text FROM public.users u WHERE u.id = 'zz_del_a')
  || ' actif=' || (SELECT is_active::text FROM public.businesses WHERE id = 'b0000000-0000-4000-8000-000000000001')
  || ' statut=' || (SELECT status FROM public.account_deletion_requests WHERE user_id = 'zz_del_a'));
SET LOCAL ROLE authenticated;
SELECT pg_temp.moi('zz_del_b', 'a0000000-0000-4000-8000-00000000000b');
SELECT pg_temp.verifie(13, 'annulation : B revoit la publication de A',
  'post=1', 'post=' || (SELECT count(*) FROM public.posts WHERE id = '90000000-0000-4000-8000-0000000000a1')::text);

-- Une annulation sans demande en cours lève, elle ne « réussit » pas à vide.
SELECT pg_temp.moi('zz_del_c', 'a0000000-0000-4000-8000-00000000000c');
DO $$
DECLARE v text := 'aucune erreur';
BEGIN
  BEGIN
    PERFORM public.cancel_account_deletion();
  EXCEPTION WHEN OTHERS THEN
    v := SQLERRM;
  END;
  PERFORM pg_temp.verifie(14, 'annuler sans demande : une erreur, pas un succès à vide',
    'aucune_suppression_a_annuler', v);
END $$;

-- Le compte plateforme (propriétaire d'un groupe officiel) est refusé.
SELECT pg_temp.moi('zz_del_d', 'a0000000-0000-4000-8000-00000000000d');
DO $$
DECLARE v text := 'aucune erreur';
BEGIN
  BEGIN
    PERFORM public.request_account_deletion();
  EXCEPTION WHEN OTHERS THEN
    v := SQLERRM;
  END;
  PERFORM pg_temp.verifie(15, 'compte propriétaire d''un groupe officiel : demande refusée',
    'compte_plateforme', v);
END $$;

-- Nouvelle demande de A (chemin ON CONFLICT sur une ligne cancelled).
SELECT pg_temp.moi('zz_del_a', 'a0000000-0000-4000-8000-00000000000a');
SELECT public.request_account_deletion();
RESET ROLE;
SELECT pg_temp.verifie(16, 'redemande après annulation : pending de nouveau, tentatives à 0',
  'pending/0', (SELECT status || '/' || attempts::text FROM public.account_deletion_requests WHERE user_id = 'zz_del_a'));

-- ═══ Échéance, réclamation, purge ═══════════════════════════════════════════
SELECT pg_temp.moi('zz_del_a', 'a0000000-0000-4000-8000-00000000000a');  -- le claim ne doit pas en dépendre
SELECT set_config('request.jwt.claims', '', true);

SELECT pg_temp.verifie(17, 'avant l''échéance : rien à réclamer',
  '0', (SELECT count(*) FROM public.claim_due_account_deletions(10))::text);

UPDATE public.account_deletion_requests SET execute_at = now() - interval '1 minute' WHERE user_id = 'zz_del_a';
SELECT pg_temp.verifie(18, 'à l''échéance : A est réclamé, et lui seul',
  'zz_del_a', (SELECT string_agg(uid, ',') FROM public.claim_due_account_deletions(10)));
SELECT pg_temp.verifie(19, 'réclamé : deleting, une tentative',
  'deleting/1', (SELECT status || '/' || attempts::text FROM public.account_deletion_requests WHERE user_id = 'zz_del_a'));

INSERT INTO purge_out SELECT public.complete_account_deletion('zz_del_a');
SELECT pg_temp.verifie(20, 'purge : ok=true',
  'true', (SELECT (j->>'ok') FROM purge_out));
SELECT pg_temp.verifie(21, 'purge : la demande reste en pierre tombale, sans contenu',
  'completed/{}/aucune erreur',
  (SELECT status || '/' || restore::text || '/' || COALESCE(last_error, 'aucune erreur')
     FROM public.account_deletion_requests WHERE user_id = 'zz_del_a'));

-- ── Ce qui doit avoir disparu
SELECT pg_temp.verifie(22, 'identité : users, auth.users, auth_mappings, sessions',
  'users=0 auth=0 map=0',
  'users=' || (SELECT count(*) FROM public.users WHERE id = 'zz_del_a')::text
  || ' auth=' || (SELECT count(*) FROM auth.users WHERE id = 'a0000000-0000-4000-8000-00000000000a')::text
  || ' map=' || (SELECT count(*) FROM public.auth_mappings WHERE firebase_uid = 'zz_del_a')::text);

SELECT pg_temp.verifie(23, 'conversation à deux supprimée entièrement, messages compris',
  'conv=0 msgs=0',
  'conv=' || (SELECT count(*) FROM public.conversations WHERE id = 'zz-conv-ab')::text
  || ' msgs=' || (SELECT count(*) FROM public.messages WHERE conversation_id = 'zz-conv-ab')::text);

SELECT pg_temp.verifie(24, 'groupe où A était seul : dissous (groupe, membres, conversation)',
  'groupe=0 membres=0 conv=0',
  'groupe=' || (SELECT count(*) FROM public.groups WHERE id = 'c0000000-0000-4000-8000-0000000000a2')::text
  || ' membres=' || (SELECT count(*) FROM public.group_members WHERE group_id = 'c0000000-0000-4000-8000-0000000000a2')::text
  || ' conv=' || (SELECT count(*) FROM public.conversations WHERE id = 'zz-conv-g2')::text);

SELECT pg_temp.verifie(25, 'groupe G1 : survit, B (plus ancien membre) en devient propriétaire',
  'creator=zz_del_b role=owner membres=2 count=2',
  'creator=' || (SELECT creator_id FROM public.groups WHERE id = 'c0000000-0000-4000-8000-0000000000a1')
  || ' role=' || (SELECT role FROM public.group_members WHERE group_id = 'c0000000-0000-4000-8000-0000000000a1' AND user_id = 'zz_del_b')
  || ' membres=' || (SELECT count(*) FROM public.group_members WHERE group_id = 'c0000000-0000-4000-8000-0000000000a1')::text
  || ' count=' || (SELECT member_count FROM public.groups WHERE id = 'c0000000-0000-4000-8000-0000000000a1')::text);

SELECT pg_temp.verifie(26, 'groupe G1 : A a quitté sa conversation, B en est administrateur, `created_by` suit',
  'participants=zz_del_b,zz_del_c admins=["zz_del_b"] created_by=zz_del_b',
  'participants=' || (SELECT array_to_string(participant_ids, ',') FROM public.conversations WHERE id = 'zz-conv-g1')
  || ' admins=' || (SELECT data->'adminIds' FROM public.conversations WHERE id = 'zz-conv-g1')::text
  || ' created_by=' || (SELECT created_by FROM public.conversations WHERE id = 'zz-conv-g1'));

SELECT pg_temp.verifie(27, 'groupe G1 : aucune trace de A dans les métadonnées de la conversation',
  'unread=null readby=["zz_del_b"] lastSender=compte_supprime col=compte_supprime',
  'unread=' || COALESCE((SELECT data->'unreadCount'->>'zz_del_a' FROM public.conversations WHERE id = 'zz-conv-g1'), 'null')
  || ' readby=' || (SELECT data->'lastMessageReadBy' FROM public.conversations WHERE id = 'zz-conv-g1')::text
  || ' lastSender=' || (SELECT data->>'lastMessageSenderId' FROM public.conversations WHERE id = 'zz-conv-g1')
  || ' col=' || (SELECT last_message_sender_id FROM public.conversations WHERE id = 'zz-conv-g1'));

SELECT pg_temp.verifie(28, 'groupe « ad hoc » : A sorti de la liste, sans promotion',
  'participants=zz_del_b,zz_del_c created_by=zz_del_b',
  'participants=' || (SELECT array_to_string(participant_ids, ',') FROM public.conversations WHERE id = 'zz-conv-adhoc')
  || ' created_by=' || (SELECT created_by FROM public.conversations WHERE id = 'zz-conv-adhoc'));

SELECT pg_temp.verifie(29, 'épingle de A réattribuée au nouveau propriétaire',
  'zz_del_b', (SELECT pinned_by FROM public.group_pinned_items WHERE item_id = 'zz-msg-g1-b'));

SELECT pg_temp.verifie(30, 'message de A dans le groupe : texte gardé, identité retirée',
  'sender=compte_supprime nom=Compte supprimé photo=null hist=null editedAt=gardé texte=bonjour le groupe',
  (SELECT 'sender=' || m.sender_id
       || ' nom=' || (m.data->>'senderName')
       || ' photo=' || COALESCE(m.data->>'senderPhotoUrl', 'null')
       || ' hist=' || COALESCE(m.data->>'editHistory', 'null')
       || ' editedAt=' || CASE WHEN m.data ? 'editedAt' THEN 'gardé' ELSE 'perdu' END
       || ' texte=' || (m.data->>'content')
     FROM public.messages m WHERE m.id = 'zz-msg-g1-a'));

-- `readAt` et `deliveredAt` sont des OBJETS indexés par uid en production (167
-- messages sur 167, relevé le 2026-09-18) : la fixture leur donne cette forme.
SELECT pg_temp.verifie(31, 'message de B : les traces de A (lu par, remis à, horodatages, réaction) sont parties, celles de C restent',
  'readBy=["zz_del_b"] deliveredTo=[] readAt={"zz_del_c": "2026-01-02T00:00:00Z"} deliveredAt={} reactions={"zz_del_c": "❤️"}',
  (SELECT 'readBy=' || (m.data->'readBy')::text || ' deliveredTo=' || (m.data->'deliveredTo')::text
       || ' readAt=' || (m.data->'readAt')::text || ' deliveredAt=' || (m.data->'deliveredAt')::text
       || ' reactions=' || (m.data->'reactions')::text
     FROM public.messages m WHERE m.id = 'zz-msg-g1-b'));

SELECT pg_temp.verifie(32, 'la citation du message de A, chez B, ne nomme plus A',
  'compte_supprime/Compte supprimé',
  (SELECT (m.data->'replyToMessageData'->>'senderId') || '/' || (m.data->'replyToMessageData'->>'senderName')
     FROM public.messages m WHERE m.id = 'zz-msg-g1-b'));

SELECT pg_temp.verifie(33, 'MLS : message de groupe vidé (« supprimer pour tous »), ligne gardée',
  'is_deleted=true ciphertext=0 octets sender=compte_supprime',
  (SELECT 'is_deleted=' || is_deleted::text || ' ciphertext=' || length(ciphertext)::text || ' octets sender=' || sender_id
     FROM public.mls_messages WHERE id = 'e0000000-0000-4000-8000-000000000001'));

SELECT pg_temp.verifie(34, 'MLS : appareil non cité supprimé ; appareil cité gardé en pierre tombale sans identité',
  'inutile=0 cite=1 revoque=true identite=compte_supprime:d0000000-0000-4000-8000-000000000001 nom=Appareil supprimé',
  'inutile=' || (SELECT count(*) FROM public.mls_devices WHERE id = 'd0000000-0000-4000-8000-000000000002')::text
  || ' cite=' || (SELECT count(*) FROM public.mls_devices WHERE id = 'd0000000-0000-4000-8000-000000000001')::text
  || ' revoque=' || (SELECT (revoked_at IS NOT NULL)::text FROM public.mls_devices WHERE id = 'd0000000-0000-4000-8000-000000000001')
  || ' identite=' || (SELECT mls_identity FROM public.mls_devices WHERE id = 'd0000000-0000-4000-8000-000000000001')
  || ' nom=' || (SELECT name FROM public.mls_devices WHERE id = 'd0000000-0000-4000-8000-000000000001'));

SELECT pg_temp.verifie(35, 'événement créé supprimé, avec la participation de B',
  'evt=0 participations=0',
  'evt=' || (SELECT count(*) FROM public.events WHERE id = 'f0000000-0000-4000-8000-000000000001')::text
  || ' participations=' || (SELECT count(*) FROM public.event_attendees WHERE event_id = 'f0000000-0000-4000-8000-000000000001')::text);

SELECT pg_temp.verifie(36, 'commerce supprimé, avec son boost (NO ACTION) et ses avis',
  'commerce=0 boost=0 avis=0',
  'commerce=' || (SELECT count(*) FROM public.businesses WHERE id = 'b0000000-0000-4000-8000-000000000001')::text
  || ' boost=' || (SELECT count(*) FROM public.business_boosts WHERE business_id = 'b0000000-0000-4000-8000-000000000001')::text
  || ' avis=' || (SELECT count(*) FROM public.business_reviews WHERE business_id = 'b0000000-0000-4000-8000-000000000001')::text);

SELECT pg_temp.verifie(37, 'publication de A supprimée (cascade) ; commentaire et like de A chez B supprimés',
  'post=0 commentaires=0 likes=0',
  'post=' || (SELECT count(*) FROM public.posts WHERE id = '90000000-0000-4000-8000-0000000000a1')::text
  || ' commentaires=' || (SELECT count(*) FROM public.post_comments WHERE author_id = 'zz_del_a')::text
  || ' likes=' || (SELECT count(*) FROM public.post_likes WHERE user_id = 'zz_del_a')::text);

SELECT pg_temp.verifie(38, 'graphe social supprimé dans les deux sens',
  'amis=0 demandes=0 follows=0',
  'amis=' || (SELECT count(*) FROM public.friends WHERE user_id IN ('zz_del_a') OR friend_id IN ('zz_del_a'))::text
  || ' demandes=' || (SELECT count(*) FROM public.friend_requests WHERE sender_id = 'zz_del_a' OR receiver_id = 'zz_del_a')::text
  || ' follows=' || (SELECT count(*) FROM public.user_follows WHERE follower_id = 'zz_del_a' OR following_id = 'zz_del_a')::text);

SELECT pg_temp.verifie(39, 'notifications : reçues par A, et déclenchées par A chez les autres',
  'recues=0 declenchees=0',
  'recues=' || (SELECT count(*) FROM public.notifications WHERE user_id = 'zz_del_a')::text
  || ' declenchees=' || (SELECT count(*) FROM public.notifications
        WHERE data->>'actor_id' = 'zz_del_a' OR data->>'senderId' = 'zz_del_a' OR data->>'sender_id' = 'zz_del_a')::text);

-- ── Ce qui ne doit PAS avoir bougé
SELECT pg_temp.verifie(40, 'les autres comptes et le groupe officiel sont intacts',
  'B,C,D=3 G3=1 conv-g1=1',
  'B,C,D=' || (SELECT count(*) FROM public.users WHERE id IN ('zz_del_b','zz_del_c','zz_del_d'))::text
  || ' G3=' || (SELECT count(*) FROM public.groups WHERE id = 'c0000000-0000-4000-8000-0000000000a3')::text
  || ' conv-g1=' || (SELECT count(*) FROM public.conversations WHERE id = 'zz-conv-g1')::text);

-- ── Rejouable : une seconde purge ne lève rien et ne change rien
SELECT pg_temp.verifie(41, 'complete rejoué : idempotent',
  'true/true', (public.complete_account_deletion('zz_del_a')->>'ok') || '/' || (public.complete_account_deletion('zz_del_a')->>'deja_fait'));
SELECT pg_temp.verifie(42, 'la purge elle-même rejouée sur un compte vide ne lève rien',
  'true', (private.purge_account('zz_del_a') IS NOT NULL)::text);

-- ── Un compte inconnu ou non réclamé n'est pas purgé
SELECT pg_temp.verifie(43, 'complete refuse une demande non réclamée',
  'aucune_demande', (public.complete_account_deletion('zz_del_inconnu')->>'error'));

-- ═══ Blocage à l'échéance, échec de purge, reprise ═════════════════════════
-- Un compte qui devient bloquant PENDANT le délai ne doit pas être réclamé
-- (sinon la Cloud Function supprimerait son compte Firebase pour rien).
INSERT INTO public.account_deletion_requests (user_id, status, execute_at)
VALUES ('zz_del_d', 'pending', now() - interval '1 minute');
-- L'appel et la lecture de son effet dans DEUX instructions : une même
-- instruction lit l'état d'AVANT l'UPDATE du claim (snapshot de la requête).
INSERT INTO ctx SELECT 'reclames_44', count(*)::text FROM public.claim_due_account_deletions(10);
SELECT pg_temp.verifie(44, 'à l''échéance : un compte devenu bloquant n''est pas réclamé mais passé en blocked',
  'reclames=0 statut=blocked motif=compte_plateforme',
  'reclames=' || (SELECT v FROM ctx WHERE k = 'reclames_44')
  || ' statut=' || (SELECT status FROM public.account_deletion_requests WHERE user_id = 'zz_del_d')
  || ' motif=' || (SELECT last_error FROM public.account_deletion_requests WHERE user_id = 'zz_del_d'));

-- Un compte E dont la purge ÉCHOUE au dernier moment (le DELETE sur users lève).
-- Tout ce que la purge avait déjà fait doit être annulé : jamais à moitié effacé.
INSERT INTO public.users (id, email, display_name) VALUES ('zz_del_e', 'zz_e@example.invalid', 'Eva Test');
INSERT INTO public.friends (user_id, friend_id) VALUES ('zz_del_e', 'zz_del_b'), ('zz_del_b', 'zz_del_e');
INSERT INTO public.account_deletion_requests (user_id, status, execute_at, started_at, attempts)
VALUES ('zz_del_e', 'deleting', now() - interval '2 hours', now() - interval '31 minutes', 1);

CREATE FUNCTION pg_temp.boom() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN RAISE EXCEPTION 'boum du banc' USING ERRCODE = 'P0001'; END $$;
CREATE TRIGGER zz_boom BEFORE DELETE ON public.users
  FOR EACH ROW WHEN (OLD.id = 'zz_del_e') EXECUTE FUNCTION pg_temp.boom();

INSERT INTO purge_out SELECT public.complete_account_deletion('zz_del_e');
SELECT pg_temp.verifie(45, 'purge en échec : ok=false, l''erreur est dite',
  'false/true',
  (SELECT (j->>'ok') || '/' || ((j->>'error') LIKE '%boum du banc%')::text FROM purge_out ORDER BY ctid DESC LIMIT 1));
SELECT pg_temp.verifie(46, 'purge en échec : atomique — l''ami de E est toujours là, la demande reste deleting avec son erreur',
  'amis=2 statut=deleting erreur=true',
  'amis=' || (SELECT count(*) FROM public.friends WHERE user_id = 'zz_del_e' OR friend_id = 'zz_del_e')::text
  || ' statut=' || (SELECT status FROM public.account_deletion_requests WHERE user_id = 'zz_del_e')
  || ' erreur=' || (SELECT (last_error LIKE '%boum du banc%')::text FROM public.account_deletion_requests WHERE user_id = 'zz_del_e'));

-- Reprise : une purge restée en route depuis plus de 30 minutes est réclamée
-- de nouveau (tentative 2), puis aboutit quand l'obstacle est levé.
INSERT INTO ctx SELECT 'reclames_47', string_agg(uid, ',') FROM public.claim_due_account_deletions(10);
SELECT pg_temp.verifie(47, 'reprise : un deleting vieux de 31 min est réclamé de nouveau, tentative 2',
  'zz_del_e/2',
  (SELECT v FROM ctx WHERE k = 'reclames_47') || '/'
  || (SELECT attempts::text FROM public.account_deletion_requests WHERE user_id = 'zz_del_e'));
DROP TRIGGER zz_boom ON public.users;
INSERT INTO purge_out SELECT public.complete_account_deletion('zz_del_e');
SELECT pg_temp.verifie(48, 'reprise : la purge aboutit, E et ses liens ont disparu',
  'ok=true users=0 amis=0 statut=completed',
  'ok=' || (SELECT (j->>'ok') FROM purge_out ORDER BY ctid DESC LIMIT 1)
  || ' users=' || (SELECT count(*) FROM public.users WHERE id = 'zz_del_e')::text
  || ' amis=' || (SELECT count(*) FROM public.friends WHERE user_id = 'zz_del_e' OR friend_id = 'zz_del_e')::text
  || ' statut=' || (SELECT status FROM public.account_deletion_requests WHERE user_id = 'zz_del_e'));

-- ═══ Verdict ════════════════════════════════════════════════════════════════
-- Une seule requête : la sortie CSV du CLI ne rend que la dernière.
SELECT n, cas, attendu, obtenu, verdict FROM resultat
UNION ALL
SELECT 9999, 'BILAN', '0 échec',
       count(*) FILTER (WHERE verdict <> 'OK')::text || ' échec(s) sur ' || count(*)::text,
       CASE WHEN count(*) FILTER (WHERE verdict <> 'OK') = 0 THEN 'OK' ELSE 'ÉCHEC' END
  FROM resultat
ORDER BY 1;
