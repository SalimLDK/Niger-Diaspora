-- Banc : retrait des deux participants orphelins (migration 20260921110000).
--
--   supabase db query --linked -f tools/rls_tests/participants_orphelins.sql
--
-- Condition : 0 cas en ÉCHEC. Tout est dans un `BEGIN … ROLLBACK`.
--
-- ⚠️ ORDRE PARTICULIER. La migration agit sur des lignes RÉELLES, pas sur des
-- fixtures : le marqueur `-- @@MIGRATION@@` est donc APRÈS les fixtures (la
-- migration doit nettoyer ce qu'on vient de poser). Lancé tel quel (marqueur
-- en commentaire), les cas de retrait ÉCHOUENT — c'est la preuve qu'il sait
-- échouer. Avec la migration injectée, tout passe.
--
-- Ce banc pose ses propres fixtures ET touche l'état vivant : la migration
-- retire les deux vrais orphelins de leurs vraies conversations aussi, mais le
-- `ROLLBACK` annule tout. Rien n'est écrit.

BEGIN;

SET LOCAL lock_timeout = '5s';
-- Comme la migration : réparation privilégiée, gardes applicatifs coupés. Sans
-- ça, les fixtures ci-dessous (conversations à `adminIds` vide) feraient lever
-- `conversations_guard_admin_fields` sur les array_remove des cas 5 et 6.
SET LOCAL session_replication_role = replica;

CREATE TEMP TABLE resultat(n int, cas text, attendu text, obtenu text, verdict text);

-- Un des deux orphelins réels, et une conversation-fixture qui le contient
-- aux côtés d'un participant VALIDE (qui, lui, a une ligne `users`).
INSERT INTO public.users (id, display_name) VALUES ('banc-orph-valide', 'Valide');

-- Groupe et conversation d'essai. `group_id` non-uuid → le déclencheur de
-- synchronisation le traite comme un groupe hérité et ne touche pas
-- `group_members` (on vérifie ce no-op au cas 4 avec un vrai groupe).
INSERT INTO public.conversations (id, type, group_id, participant_ids)
VALUES (gen_random_uuid(), 'group', 'banc-groupe-fixture',
        ARRAY['ca776bc7-a3f6-4c70-a34f-cb9c87b9c146', 'banc-orph-valide']);

-- @@MIGRATION@@

-- ═══ 1. L'orphelin a quitté la conversation-fixture ════════════════════════
INSERT INTO resultat
SELECT 1, 'l''orphelin est retiré de la conversation-fixture', 'absent',
       CASE WHEN 'ca776bc7-a3f6-4c70-a34f-cb9c87b9c146' = ANY(participant_ids)
            THEN 'ENCORE PRÉSENT' ELSE 'absent' END,
       CASE WHEN 'ca776bc7-a3f6-4c70-a34f-cb9c87b9c146' = ANY(participant_ids)
            THEN 'ÉCHEC' ELSE 'OK' END
  FROM public.conversations WHERE group_id = 'banc-groupe-fixture';

-- ═══ 2. Le participant valide reste ════════════════════════════════════════
INSERT INTO resultat
SELECT 2, 'le participant valide (avec compte) est conservé', 'présent',
       CASE WHEN 'banc-orph-valide' = ANY(participant_ids)
            THEN 'présent' ELSE 'RETIRÉ À TORT' END,
       CASE WHEN 'banc-orph-valide' = ANY(participant_ids) THEN 'OK' ELSE 'ÉCHEC' END
  FROM public.conversations WHERE group_id = 'banc-groupe-fixture';

-- ═══ 3. Plus AUCUN orphelin dans toute la base ═════════════════════════════
-- Les deux vrais compris : la migration les a retirés (annulé par le ROLLBACK).
INSERT INTO resultat
SELECT 3, 'plus aucun uid orphelin dans participant_ids (toute la base)', '0',
       count(*)::text,
       CASE WHEN count(*) = 0 THEN 'OK' ELSE 'ÉCHEC' END
  FROM (
    SELECT p FROM public.conversations c, unnest(c.participant_ids) p
     WHERE p IN ('ca776bc7-a3f6-4c70-a34f-cb9c87b9c146',
                 'd2c15825-bad4-4615-b69e-088d59e82a6e')
  ) s;

-- ═══ 4. Un vrai membre de groupe n'est PAS touché ══════════════════════════
-- Garde : la migration ne retire que ses deux uids nommés. On pose un membre
-- ordinaire (avec compte) dans une conversation et on vérifie qu'il reste.
DO $$
DECLARE cid text := gen_random_uuid()::text;
BEGIN
  INSERT INTO public.users (id, display_name) VALUES ('banc-membre-ok', 'Membre');
  INSERT INTO public.conversations (id, type, group_id, participant_ids)
  VALUES (cid, 'group', 'banc-groupe-2', ARRAY['banc-membre-ok']);
  INSERT INTO resultat
  SELECT 4, 'un participant hors de la liste des orphelins est intact', 'présent',
         CASE WHEN 'banc-membre-ok' = ANY(participant_ids) THEN 'présent' ELSE 'RETIRÉ' END,
         CASE WHEN 'banc-membre-ok' = ANY(participant_ids) THEN 'OK' ELSE 'ÉCHEC' END
    FROM public.conversations WHERE id = cid;
END $$;

-- ═══ 5. Idempotence : réappliquer le cœur de la migration ne retire rien ═══
DO $$
DECLARE v_uid text; v_total int := 0; v_n int;
BEGIN
  FOREACH v_uid IN ARRAY ARRAY['ca776bc7-a3f6-4c70-a34f-cb9c87b9c146',
                               'd2c15825-bad4-4615-b69e-088d59e82a6e'] LOOP
    IF EXISTS (SELECT 1 FROM public.users u WHERE u.id = v_uid) THEN CONTINUE; END IF;
    UPDATE public.conversations c SET participant_ids = array_remove(c.participant_ids, v_uid)
     WHERE v_uid = ANY(c.participant_ids);
    GET DIAGNOSTICS v_n = ROW_COUNT; v_total := v_total + v_n;
  END LOOP;
  INSERT INTO resultat VALUES (5, 'un second passage ne retire plus rien (idempotence)',
    '0 ligne', v_total::text || ' ligne(s)', CASE WHEN v_total = 0 THEN 'OK' ELSE 'ÉCHEC' END);
END $$;

-- ═══ 6. La garde par identifiant : un orphelin redevenu compte est épargné ═
DO $$
DECLARE cid text := gen_random_uuid()::text;
BEGIN
  -- On donne un compte à l'un des deux uids, puis on rejoue le cœur.
  INSERT INTO public.users (id, display_name)
  VALUES ('d2c15825-bad4-4615-b69e-088d59e82a6e', 'Revenu');
  INSERT INTO public.conversations (id, type, group_id, participant_ids)
  VALUES (cid, 'group', 'banc-groupe-3', ARRAY['d2c15825-bad4-4615-b69e-088d59e82a6e']);
  DECLARE v_uid text;
  BEGIN
    FOREACH v_uid IN ARRAY ARRAY['d2c15825-bad4-4615-b69e-088d59e82a6e'] LOOP
      IF EXISTS (SELECT 1 FROM public.users u WHERE u.id = v_uid) THEN CONTINUE; END IF;
      UPDATE public.conversations c SET participant_ids = array_remove(c.participant_ids, v_uid)
       WHERE v_uid = ANY(c.participant_ids);
    END LOOP;
  END;
  INSERT INTO resultat
  SELECT 6, 'un uid redevenu compte n''est PAS retiré (garde par identifiant)', 'présent',
         CASE WHEN 'd2c15825-bad4-4615-b69e-088d59e82a6e' = ANY(participant_ids)
              THEN 'présent' ELSE 'RETIRÉ À TORT' END,
         CASE WHEN 'd2c15825-bad4-4615-b69e-088d59e82a6e' = ANY(participant_ids)
              THEN 'OK' ELSE 'ÉCHEC' END
    FROM public.conversations WHERE id = cid;
END $$;

-- ═══ Rapport ═══════════════════════════════════════════════════════════════
SELECT n, verdict, cas, attendu, obtenu FROM resultat ORDER BY n;

ROLLBACK;
