-- Banc du rejeu d'une suppression après restauration de sauvegarde.
--
-- Suppose la migration 20260918224100 APPLIQUÉE (elle l'est depuis le 2026-09-19)
-- et joue la migration 20260919094300 dans la même transaction :
--
--   { echo "BEGIN;"; \
--     cat supabase/migrations/20260919094300_suppression_compte_rejeu_apres_restauration.sql; \
--     cat tools/rls_tests/suppression_compte_rejeu.sql; \
--     echo "ROLLBACK;"; } > /tmp/rejeu_banc.sql
--   supabase db query --linked -o csv -f /tmp/rejeu_banc.sql
--
-- Une fois cette migration appliquée, ce fichier se joue seul entre `BEGIN;` et
-- `ROLLBACK;`. Condition : 0 cas en ÉCHEC — la dernière ligne le dit.
--
-- CE QUE LE BANC ÉTABLIT
-- Une restauration ramène la base à un instant passé. On simule ce qu'elle fait
-- à des comptes supprimés depuis :
--   · R : sa demande est `completed` (la pierre tombale a survécu) MAIS ses
--     données sont revenues — profil, identité Supabase, groupe, message, amis,
--     appareil MLS, notification ;
--   · S : la demande a disparu ET le profil est revenu ;
--   · T : une purge est déjà en vol (`deleting`) au moment du rejeu ;
--   · P : le compte plateforme — même si une pierre tombale le désignait, il ne
--     doit JAMAIS être purgé.
-- Le banc mesure : ce que `account_deletion_residue` voit avant et après, ce que
-- le rejeu efface, ce qu'il refuse, et qu'il est idempotent.
--
-- Tout est dans la transaction annulée ; les comptes sont fictifs (`zz_rej_*`).

CREATE TEMP TABLE resultat(n int, cas text, attendu text, obtenu text, verdict text);
CREATE TEMP TABLE ctx(k text PRIMARY KEY, v text);
GRANT ALL ON resultat, ctx TO authenticated, anon;

-- Créée AVANT tout SET ROLE (voir project_rls_testing_bypass_pitfall).
CREATE FUNCTION pg_temp.verifie(p_n int, p_cas text, p_attendu text, p_obtenu text)
RETURNS void LANGUAGE sql AS $$
  INSERT INTO resultat VALUES (p_n, p_cas, p_attendu, p_obtenu,
    CASE WHEN p_attendu IS NOT DISTINCT FROM p_obtenu THEN 'OK' ELSE 'ÉCHEC' END)
$$;

CREATE FUNCTION pg_temp.moi(p_uid text, p_sub uuid) RETURNS void LANGUAGE sql AS $$
  SELECT set_config('request.jwt.claims',
    jsonb_build_object('sub', p_sub, 'role', 'authenticated',
                       'app_metadata', jsonb_build_object('firebase_uid', p_uid))::text, true)
$$;

-- ═══ Le monde « restauré » ══════════════════════════════════════════════════
INSERT INTO public.users (id, email, display_name) VALUES
  ('zz_rej_r', 'zz_rej_r@example.invalid', 'Rita Test'),
  ('zz_rej_b', 'zz_rej_b@example.invalid', 'Basile Test'),
  ('zz_rej_s', 'zz_rej_s@example.invalid', 'Simone Test'),
  ('zz_rej_t', 'zz_rej_t@example.invalid', 'Tom Test'),
  ('zz_rej_p', 'zz_rej_p@example.invalid', 'Plateforme Test');

INSERT INTO auth.users (id, email) VALUES
  ('b0000000-0000-4000-8000-0000000000a1', 'zz_rej_r@example.invalid');
INSERT INTO public.auth_mappings (supabase_id, firebase_uid)
VALUES ('b0000000-0000-4000-8000-0000000000a1', 'zz_rej_r');

-- Groupe de R (avec B) ; groupe officiel de P. `enforce_group_creator` exige une
-- identité et écrase `creator_id` par celle de l'appelant.
SELECT pg_temp.moi('zz_rej_r', 'b0000000-0000-4000-8000-0000000000a1');
INSERT INTO public.groups (id, name, creator_id)
VALUES ('c1000000-0000-4000-8000-0000000000a1', 'Groupe fictif du rejeu', 'zz_rej_r');
SELECT pg_temp.moi('zz_rej_p', 'b0000000-0000-4000-8000-0000000000a9');
INSERT INTO public.groups (id, name, creator_id)
VALUES ('c1000000-0000-4000-8000-0000000000a9', 'Groupe officiel fictif du rejeu', 'zz_rej_p');
SELECT set_config('request.jwt.claims', '', true);
UPDATE public.groups SET is_official = true, country_code = 'Zzland2'
 WHERE id = 'c1000000-0000-4000-8000-0000000000a9';

INSERT INTO public.group_members (group_id, user_id, role, joined_at) VALUES
  ('c1000000-0000-4000-8000-0000000000a1', 'zz_rej_r', 'owner',  now() - interval '30 days'),
  ('c1000000-0000-4000-8000-0000000000a1', 'zz_rej_b', 'member', now() - interval '20 days'),
  ('c1000000-0000-4000-8000-0000000000a9', 'zz_rej_p', 'owner',  now() - interval '30 days');
UPDATE public.groups SET member_count = 2 WHERE id = 'c1000000-0000-4000-8000-0000000000a1';

INSERT INTO public.conversations (id, type, participant_ids, created_by, group_id, data) VALUES
  ('zz-rej-conv-g1', 'group', ARRAY['zz_rej_r', 'zz_rej_b'], 'zz_rej_r',
     'c1000000-0000-4000-8000-0000000000a1', '{"adminIds":["zz_rej_r"]}'::jsonb);
INSERT INTO public.messages (id, conversation_id, sender_id, data)
VALUES ('zz-rej-msg-1', 'zz-rej-conv-g1', 'zz_rej_r', '{"content":"revenu de la restauration","senderName":"Rita Test"}');
UPDATE public.conversations SET data = '{"adminIds":["zz_rej_r"]}'::jsonb WHERE id = 'zz-rej-conv-g1';

INSERT INTO public.friends (user_id, friend_id) VALUES ('zz_rej_r', 'zz_rej_b'), ('zz_rej_b', 'zz_rej_r');
INSERT INTO public.notifications (user_id, type, title, body) VALUES ('zz_rej_r', 'info', 't', 'revenue de la restauration');
INSERT INTO public.mls_devices (id, user_id, stable_id, name, platform, mls_identity, signature_key, credential)
VALUES ('d1000000-0000-4000-8000-0000000000a1', 'zz_rej_r', 'zz_rej_stable', 'Pixel de R', 'android',
        'zz_rej_r:zz_rej_stable', '\x01', '\x02');

-- Les demandes : R `completed` (la tombstone a survécu), S sans demande, T en vol,
-- P désigné à tort (le compte plateforme n'a jamais de demande valide).
INSERT INTO public.account_deletion_requests (user_id, status, execute_at, started_at, completed_at, attempts)
VALUES
  ('zz_rej_r', 'completed', now() - interval '3 days', now() - interval '3 days', now() - interval '3 days', 1),
  ('zz_rej_t', 'deleting',  now() - interval '1 hour', now() - interval '5 minutes', NULL, 5);

SELECT pg_temp.verifie(0, 'préalable : le monde restauré est en place',
  '5 comptes, 2 groupes, 1 conversation',
  (SELECT count(*) FROM public.users WHERE id LIKE 'zz_rej_%')::text || ' comptes, '
  || (SELECT count(*) FROM public.groups WHERE name LIKE '%du rejeu')::text || ' groupes, '
  || (SELECT count(*) FROM public.conversations WHERE id LIKE 'zz-rej-conv-%')::text || ' conversation');

-- ═══ Droits ═════════════════════════════════════════════════════════════════
SELECT pg_temp.verifie(1, 'droits : service_role seulement, ni le client ni l''anonyme',
  'residue=false/false/true replay=false/false/true',
  'residue=' || has_function_privilege('authenticated','public.account_deletion_residue(text)','EXECUTE')::text
      || '/' || has_function_privilege('anon','public.account_deletion_residue(text)','EXECUTE')::text
      || '/' || has_function_privilege('service_role','public.account_deletion_residue(text)','EXECUTE')::text
  || ' replay=' || has_function_privilege('authenticated','public.replay_account_deletion(text)','EXECUTE')::text
      || '/' || has_function_privilege('anon','public.replay_account_deletion(text)','EXECUTE')::text
      || '/' || has_function_privilege('service_role','public.replay_account_deletion(text)','EXECUTE')::text);

-- ═══ Ce que la restauration a ramené ════════════════════════════════════════
INSERT INTO ctx SELECT 'residu_r_avant', public.account_deletion_residue('zz_rej_r')::text;
SELECT pg_temp.verifie(2, 'résidu de R avant : tout est revenu, comptages seulement',
  '{"users": 1, "friends": 2, "messages": 1, "mls_devices": 1, "auth_mappings": 1, "conversations": 1, "group_members": 1, "notifications": 1}',
  (SELECT v FROM ctx WHERE k = 'residu_r_avant'));
SELECT pg_temp.verifie(3, 'résidu d''un uid inconnu : des zéros, pas une erreur',
  '{"users": 0, "friends": 0, "messages": 0, "mls_devices": 0, "auth_mappings": 0, "conversations": 0, "group_members": 0, "notifications": 0}',
  public.account_deletion_residue('zz_rej_inconnu')::text);

-- ═══ Le rejeu de R (demande `completed`, données revenues) ═══════════════════
INSERT INTO ctx SELECT 'rejeu_r', public.replay_account_deletion('zz_rej_r')::text;
SELECT pg_temp.verifie(4, 'rejeu de R : ok, et la demande repasse par deleting puis completed (tentative 2)',
  'ok=true statut=completed attempts=2',
  'ok=' || ((SELECT v FROM ctx WHERE k = 'rejeu_r')::jsonb->>'ok')
  || ' statut=' || (SELECT status FROM public.account_deletion_requests WHERE user_id = 'zz_rej_r')
  || ' attempts=' || (SELECT attempts::text FROM public.account_deletion_requests WHERE user_id = 'zz_rej_r'));
SELECT pg_temp.verifie(5, 'rejeu de R : plus rien ne subsiste',
  '{"users": 0, "friends": 0, "messages": 0, "mls_devices": 0, "auth_mappings": 0, "conversations": 0, "group_members": 0, "notifications": 0}',
  public.account_deletion_residue('zz_rej_r')::text);
SELECT pg_temp.verifie(6, 'rejeu de R : le groupe survit, B en devient propriétaire ; l''auth Supabase est partie',
  'creator=zz_rej_b membres=1 auth=0',
  'creator=' || (SELECT creator_id FROM public.groups WHERE id = 'c1000000-0000-4000-8000-0000000000a1')
  || ' membres=' || (SELECT count(*) FROM public.group_members WHERE group_id = 'c1000000-0000-4000-8000-0000000000a1')::text
  || ' auth=' || (SELECT count(*) FROM auth.users WHERE id = 'b0000000-0000-4000-8000-0000000000a1')::text);

-- ═══ Le rejeu de S (la demande a disparu, le profil est revenu) ═════════════
SELECT pg_temp.verifie(7, 'S avant : profil revenu, aucune demande',
  'users=1 demandes=0',
  'users=' || (SELECT count(*) FROM public.users WHERE id = 'zz_rej_s')::text
  || ' demandes=' || (SELECT count(*) FROM public.account_deletion_requests WHERE user_id = 'zz_rej_s')::text);
INSERT INTO ctx SELECT 'rejeu_s', public.replay_account_deletion('zz_rej_s')::text;
SELECT pg_temp.verifie(8, 'rejeu de S : la demande est recréée, le profil est purgé',
  'ok=true statut=completed users=0',
  'ok=' || ((SELECT v FROM ctx WHERE k = 'rejeu_s')::jsonb->>'ok')
  || ' statut=' || (SELECT status FROM public.account_deletion_requests WHERE user_id = 'zz_rej_s')
  || ' users=' || (SELECT count(*) FROM public.users WHERE id = 'zz_rej_s')::text);

-- ═══ Une purge déjà en vol n'est pas piétinée ═══════════════════════════════
INSERT INTO ctx SELECT 'rejeu_t', public.replay_account_deletion('zz_rej_t')::text;
SELECT pg_temp.verifie(9, 'T était en vol (deleting, tentative 5) : le rejeu aboutit sans réinitialiser la demande',
  'ok=true statut=completed attempts=5 users=0',
  'ok=' || ((SELECT v FROM ctx WHERE k = 'rejeu_t')::jsonb->>'ok')
  || ' statut=' || (SELECT status FROM public.account_deletion_requests WHERE user_id = 'zz_rej_t')
  || ' attempts=' || (SELECT attempts::text FROM public.account_deletion_requests WHERE user_id = 'zz_rej_t')
  || ' users=' || (SELECT count(*) FROM public.users WHERE id = 'zz_rej_t')::text);

-- ═══ Les refus ══════════════════════════════════════════════════════════════
INSERT INTO ctx SELECT 'rejeu_p', public.replay_account_deletion('zz_rej_p')::text;
SELECT pg_temp.verifie(10, 'le compte plateforme n''est JAMAIS purgé, même désigné par une pierre tombale',
  '{"ok": false, "error": "compte_plateforme"} users=1 groupe=1 demandes=0',
  (SELECT v FROM ctx WHERE k = 'rejeu_p')
  || ' users=' || (SELECT count(*) FROM public.users WHERE id = 'zz_rej_p')::text
  || ' groupe=' || (SELECT count(*) FROM public.groups WHERE id = 'c1000000-0000-4000-8000-0000000000a9')::text
  || ' demandes=' || (SELECT count(*) FROM public.account_deletion_requests WHERE user_id = 'zz_rej_p')::text);
SELECT pg_temp.verifie(11, 'un uid vide est refusé, pas purgé',
  '{"ok": false, "error": "uid_manquant"}', public.replay_account_deletion('')::text);
-- L'appel et la lecture de son effet dans DEUX instructions : une même
-- instruction lit l'état d'AVANT (snapshot de la requête).
INSERT INTO ctx SELECT 'rejeu_inconnu', public.replay_account_deletion('zz_rej_inconnu')::text;
SELECT pg_temp.verifie(12, 'un uid inconnu : ok, une demande completed, aucun dégât',
  'ok=true statut=completed',
  'ok=' || ((SELECT v FROM ctx WHERE k = 'rejeu_inconnu')::jsonb->>'ok')
  || ' statut=' || (SELECT status FROM public.account_deletion_requests WHERE user_id = 'zz_rej_inconnu'));

-- ═══ Idempotence ════════════════════════════════════════════════════════════
INSERT INTO ctx SELECT 'rejeu_r2', public.replay_account_deletion('zz_rej_r')::text;
SELECT pg_temp.verifie(13, 'rejouer R une seconde fois : ok, toujours rien, tentative 3',
  'ok=true attempts=3 residu=0',
  'ok=' || ((SELECT v FROM ctx WHERE k = 'rejeu_r2')::jsonb->>'ok')
  || ' attempts=' || (SELECT attempts::text FROM public.account_deletion_requests WHERE user_id = 'zz_rej_r')
  || ' residu=' || (SELECT sum(value::int)::text FROM jsonb_each_text(public.account_deletion_residue('zz_rej_r'))));

-- ═══ Ce qui ne doit PAS avoir bougé ═════════════════════════════════════════
SELECT pg_temp.verifie(14, 'B, et le groupe de B, sont intacts',
  'B=1 notif_de_B=0',
  'B=' || (SELECT count(*) FROM public.users WHERE id = 'zz_rej_b')::text
  || ' notif_de_B=' || (SELECT count(*) FROM public.notifications WHERE user_id = 'zz_rej_b')::text);

-- ═══ Verdict ════════════════════════════════════════════════════════════════
-- Une seule requête : la sortie CSV du CLI ne rend que la dernière.
SELECT n, cas, attendu, obtenu, verdict FROM resultat
UNION ALL
SELECT 9999, 'BILAN', '0 échec',
       count(*) FILTER (WHERE verdict <> 'OK')::text || ' échec(s) sur ' || count(*)::text,
       CASE WHEN count(*) FILTER (WHERE verdict <> 'OK') = 0 THEN 'OK' ELSE 'ÉCHEC' END
  FROM resultat
ORDER BY 1;
