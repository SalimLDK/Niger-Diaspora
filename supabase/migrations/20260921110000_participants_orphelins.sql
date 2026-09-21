-- `conversations.participant_ids` : retrait de deux identifiants orphelins.
--
-- ═══ LE CONSTAT, MESURÉ LE 2026-09-21 ════════════════════════════════════
--
-- L'accès à une conversation de groupe passe par `participant_ids`
-- (`is_conversation_participant` : `firebase_uid() = ANY(participant_ids)`),
-- pas par `group_members`. L'audit signalait « 2 personnes gardent lecture et
-- écriture d'un groupe qu'elles ont quitté ». La mesure corrige la gravité :
--
-- Ces deux identifiants sont des comptes DISPARUS. Pour chacun, vérifié :
-- absent de `users`, 0 message n'importe où, 0 ligne dans `group_members`,
-- 0 amitié, absent d'`auth_mappings`, présent dans une seule conversation.
-- Ils ne référencent aucun compte vivant : personne ne détient ces
-- identifiants, il n'y a donc PAS d'accès exploitable — seulement du résidu.
--
-- ═══ LA CAUSE EST DÉJÀ FERMÉE ════════════════════════════════════════════
--
-- `purge_account` retire aujourd'hui l'uid de `participant_ids`
-- (`array_remove`) à la suppression d'un compte. Ces deux résidus sont
-- antérieurs à ce nettoyage — ce sont les SEULS de toute la base (aucun uid
-- orphelin ailleurs, tous types de conversation confondus). Aucun garde-fou
-- nouveau n'est ajouté : rien n'en recrée.
--
-- ═══ CE QUE FAIT CETTE MIGRATION ═════════════════════════════════════════
--
-- Retire les DEUX identifiants nommés, et EUX SEULS, de toute
-- `participant_ids` qui les contient — avec une garde par identifiant :
-- « absent de `users` » ne prouve pas « compte supprimé » (la ligne `users`
-- est créée paresseusement, un compte actif peut y manquer). On ne retire
-- donc un identifiant que s'il n'a TOUJOURS aucun compte à l'application.
-- Idempotente : un second passage ne retire rien.
--
-- ⚠️ `session_replication_role = replica` : c'est une réparation de données
-- PRIVILÉGIÉE. Le garde applicatif `conversations_guard_admin_fields` refuse
-- une écriture de `participant_ids` par qui n'est pas administrateur du
-- groupe — y compris, selon que `adminIds` est vide ou non, une écriture
-- serveur sans session (sa logique NULL est fragile). On coupe donc tous les
-- déclencheurs applicatifs le temps du retrait, comme le fait une migration
-- de données. `conversations_sync_group_removal` (qui supprimerait de
-- `group_members`) est ainsi inerte aussi — sans conséquence : l'orphelin n'y
-- est pas.
--
-- ⚠️ `BEGIN … COMMIT` explicite : sans lui, `SET LOCAL` en tête de migration
-- est inerte (WARNING 25P01), `db push` n'ouvrant pas toujours de transaction.
--
-- Banc : tools/rls_tests/participants_orphelins.sql

BEGIN;

SET LOCAL session_replication_role = replica;

DO $$
DECLARE
  -- Les deux orphelins, relevés et caractérisés le 2026-09-21. Toute autre
  -- valeur est hors de portée de cette migration.
  c_orphelins constant text[] := ARRAY[
    'ca776bc7-a3f6-4c70-a34f-cb9c87b9c146',
    'd2c15825-bad4-4615-b69e-088d59e82a6e'
  ];
  v_uid   text;
  v_n     int;
  v_total int := 0;
BEGIN
  FOREACH v_uid IN ARRAY c_orphelins LOOP
    -- Garde par identifiant : si un compte a été (re)créé entre-temps, on ne
    -- touche pas à sa participation.
    IF EXISTS (SELECT 1 FROM public.users u WHERE u.id = v_uid) THEN
      RAISE NOTICE 'participants_orphelins: % a désormais un compte, ignoré', v_uid;
      CONTINUE;
    END IF;

    UPDATE public.conversations c
       SET participant_ids = array_remove(c.participant_ids, v_uid)
     WHERE v_uid = ANY(c.participant_ids);
    GET DIAGNOSTICS v_n = ROW_COUNT;
    v_total := v_total + v_n;
  END LOOP;

  RAISE NOTICE 'participants_orphelins: % conversation(s) nettoyée(s)', v_total;
END $$;

COMMIT;
