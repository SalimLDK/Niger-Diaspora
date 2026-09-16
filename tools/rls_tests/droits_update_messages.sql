-- Banc des droits d'écriture sur `public.messages`.
--
--   supabase db query --linked -f tools/rls_tests/droits_update_messages.sql
--
-- Condition : 20 cas, 0 en échec. Tout est dans un `BEGIN … ROLLBACK` — le
-- banc écrit sur de vraies lignes de production puis annule tout.
--
-- POURQUOI `SET LOCAL ROLE authenticated` EST INDISPENSABLE ICI
-- `supabase db query --linked` se connecte en `postgres`, qui est propriétaire
-- des tables : il contourne la RLS *et* les privilèges de colonne. Un banc
-- écrit sans cette bascule passe au vert sur une base grande ouverte. Le JWT
-- se simule par `request.jwt.claims` — `firebase_uid()` lit
-- `app_metadata->>'firebase_uid'`, et `sub` doit rester un UUID valide sous
-- peine de 22P02 dans `auth.uid()`.
--
-- CE QUE LE BANC TIENT (migration 20260916210000)
--   · un participant ne réécrit pas le message d'un autre — ni son contenu,
--     ni son expéditeur, ni sa date, ni sa conversation ;
--   · il garde ce dont l'app a besoin : favori, suppression pour soi,
--     signalement, réaction ;
--   · les accusés de lecture et de livraison continuent de passer. C'est la
--     régression la plus dangereuse du lot, parce qu'elle est MUETTE : le
--     « Lu » cesse simplement d'arriver, sans erreur nulle part ;
--   · l'expéditeur garde « Modifier le message » ;
--   · un admin de groupe peut supprimer le message d'un membre (modération)
--     mais pas le réécrire, et la porte se referme après la suppression.
--
-- Un banc qui ne sait pas échouer ne prouve rien : retirer le déclencheur
-- `messages_garde_update_trg` doit faire tomber 10 cas sur 20.
--
-- Les identifiants ci-dessous sont ceux d'une vraie conversation de groupe
-- (24 participants). Si elle disparaît, les relever à nouveau ainsi :
--   SELECT m.id, m.conversation_id, m.sender_id FROM messages m
--     JOIN conversations c ON c.id = m.conversation_id
--    WHERE array_length(c.participant_ids,1) >= 2 AND NOT m.is_deleted
--    ORDER BY m.created_at DESC LIMIT 3;
-- en prenant soin que le « simple membre » n'ait PAS le rôle admin/owner
-- dans `group_members` — sinon la branche de modération le laisse passer et
-- quatre cas d'abus virent au vert à tort. C'est arrivé à l'écriture du banc.

BEGIN;

CREATE TEMP TABLE resultat(n int, cas text, attendu text, obtenu text, verdict text);
GRANT ALL ON resultat TO authenticated;

-- ── Données réelles ────────────────────────────────────────────────────────
-- conversation ffd4f06e… (24 participants)
--   message 19f41e09…, expéditeur TeGcb1GRvOh2aWJgkQJuewXVjsV2
--   autre participant, simple membre : 1X5F6RKlrTgyxZFSTvS6lXBx8C32





-- ═══ LA MIGRATION, telle qu'elle sera poussée ═══════════════════════════════
-- (la migration 20260916210000 est supposée appliquée)

-- ═══ Vérification préalable : où s'exécute une fonction SECURITY DEFINER ════
CREATE OR REPLACE FUNCTION pg_temp.qui_suis_je() RETURNS text
LANGUAGE sql SECURITY DEFINER AS $$ SELECT current_user::text $$;

-- ═══ Bascule en rôle applicatif ═════════════════════════════════════════════
SET LOCAL request.jwt.claims =
  '{"sub":"00000000-0000-0000-0000-0000000000aa","app_metadata":{"firebase_uid":"1X5F6RKlrTgyxZFSTvS6lXBx8C32"},"role":"authenticated"}';
SET LOCAL ROLE authenticated;

INSERT INTO resultat VALUES (0, 'rôle effectif du banc', 'authenticated', current_user,
  CASE WHEN current_user = 'authenticated' THEN 'OK' ELSE 'ÉCHEC' END);

-- ── 1. La faille signalée : réécrire le contenu du message d'un autre ──────
DO $$
BEGIN
  UPDATE messages SET data = jsonb_set(data, '{content}', '"REECRIT"')
   WHERE id = '19f41e09-a256-4b03-930c-d4dc1aebc2d0';
  INSERT INTO resultat VALUES (1, 'non-expéditeur réécrit content', 'refusé', 'ACCEPTÉ', 'ÉCHEC');
EXCEPTION WHEN insufficient_privilege THEN
  INSERT INTO resultat VALUES (1, 'non-expéditeur réécrit content', 'refusé', 'refusé 42501', 'OK');
END $$;

-- ── 2. Attribuer le message de quelqu'un à un tiers ────────────────────────
DO $$
BEGIN
  UPDATE messages SET sender_id = '1X5F6RKlrTgyxZFSTvS6lXBx8C32'
   WHERE id = '19f41e09-a256-4b03-930c-d4dc1aebc2d0';
  INSERT INTO resultat VALUES (2, 'non-expéditeur réécrit sender_id', 'refusé', 'ACCEPTÉ', 'ÉCHEC');
EXCEPTION WHEN insufficient_privilege THEN
  INSERT INTO resultat VALUES (2, 'non-expéditeur réécrit sender_id', 'refusé', 'refusé 42501', 'OK');
END $$;

-- ── 3. Déplacer le message dans une autre conversation ─────────────────────
DO $$
BEGIN
  UPDATE messages SET conversation_id = 'autre'
   WHERE id = '19f41e09-a256-4b03-930c-d4dc1aebc2d0';
  INSERT INTO resultat VALUES (3, 'non-expéditeur déplace le message', 'refusé', 'ACCEPTÉ', 'ÉCHEC');
EXCEPTION WHEN insufficient_privilege THEN
  INSERT INTO resultat VALUES (3, 'non-expéditeur déplace le message', 'refusé', 'refusé 42501', 'OK');
END $$;

-- ── 4. Supprimer pour tout le monde sans être admin ni expéditeur ──────────
DO $$
BEGIN
  UPDATE messages
     SET is_deleted = true,
         data = jsonb_set(jsonb_set(data,'{deletedForEveryone}','true'),'{content}','""')
   WHERE id = '19f41e09-a256-4b03-930c-d4dc1aebc2d0';
  INSERT INTO resultat VALUES (4, 'simple membre supprime pour tous', 'refusé', 'ACCEPTÉ', 'ÉCHEC');
EXCEPTION WHEN insufficient_privilege THEN
  INSERT INTO resultat VALUES (4, 'simple membre supprime pour tous', 'refusé', 'refusé 42501', 'OK');
END $$;

-- ── 5..8. Ce qu'un participant DOIT garder ─────────────────────────────────
DO $$
DECLARE v text;
BEGIN
  UPDATE messages
     SET data = jsonb_set(COALESCE(data,'{}'::jsonb), '{starredBy}',
           COALESCE(data->'starredBy','[]'::jsonb) || '"1X5F6RKlrTgyxZFSTvS6lXBx8C32"')
   WHERE id = '19f41e09-a256-4b03-930c-d4dc1aebc2d0';
  SELECT (data->'starredBy')::text INTO v FROM messages
   WHERE id = '19f41e09-a256-4b03-930c-d4dc1aebc2d0';
  INSERT INTO resultat VALUES (5, 'participant met en favori (starredBy)', 'accepté',
    'accepté → ' || COALESCE(v,'∅'), 'OK');
EXCEPTION WHEN OTHERS THEN
  INSERT INTO resultat VALUES (5, 'participant met en favori (starredBy)', 'accepté',
    'REFUSÉ ' || SQLSTATE || ' ' || SQLERRM, 'ÉCHEC');
END $$;

DO $$
DECLARE v text;
BEGIN
  UPDATE messages
     SET data = jsonb_set(COALESCE(data,'{}'::jsonb), '{deletedFor}',
           COALESCE(data->'deletedFor','[]'::jsonb) || '"1X5F6RKlrTgyxZFSTvS6lXBx8C32"')
   WHERE id = '19f41e09-a256-4b03-930c-d4dc1aebc2d0';
  SELECT (data->'deletedFor')::text INTO v FROM messages
   WHERE id = '19f41e09-a256-4b03-930c-d4dc1aebc2d0';
  INSERT INTO resultat VALUES (6, 'participant supprime pour lui (deletedFor)', 'accepté',
    'accepté → ' || COALESCE(v,'∅'), 'OK');
EXCEPTION WHEN OTHERS THEN
  INSERT INTO resultat VALUES (6, 'participant supprime pour lui (deletedFor)', 'accepté',
    'REFUSÉ ' || SQLSTATE || ' ' || SQLERRM, 'ÉCHEC');
END $$;

DO $$
DECLARE v text;
BEGIN
  UPDATE messages
     SET data = jsonb_set(COALESCE(data,'{}'::jsonb), '{reportedBy}',
           COALESCE(data->'reportedBy','[]'::jsonb) || '"1X5F6RKlrTgyxZFSTvS6lXBx8C32"')
   WHERE id = '19f41e09-a256-4b03-930c-d4dc1aebc2d0';
  SELECT (data->'reportedBy')::text INTO v FROM messages
   WHERE id = '19f41e09-a256-4b03-930c-d4dc1aebc2d0';
  INSERT INTO resultat VALUES (7, 'participant signale (reportedBy)', 'accepté',
    'accepté → ' || COALESCE(v,'∅'), 'OK');
EXCEPTION WHEN OTHERS THEN
  INSERT INTO resultat VALUES (7, 'participant signale (reportedBy)', 'accepté',
    'REFUSÉ ' || SQLSTATE || ' ' || SQLERRM, 'ÉCHEC');
END $$;

-- Le repli direct `_setReactionLegacy`, qui n'utilise pas la RPC.
DO $$
DECLARE v text;
BEGIN
  UPDATE messages
     SET data = jsonb_set(COALESCE(data,'{}'::jsonb), '{reactions}',
           COALESCE(data->'reactions','{}'::jsonb)
           || jsonb_build_object('1X5F6RKlrTgyxZFSTvS6lXBx8C32','👍'))
   WHERE id = '19f41e09-a256-4b03-930c-d4dc1aebc2d0';
  SELECT (data->'reactions')::text INTO v FROM messages
   WHERE id = '19f41e09-a256-4b03-930c-d4dc1aebc2d0';
  INSERT INTO resultat VALUES (8, 'participant réagit en direct (repli legacy)', 'accepté',
    'accepté → ' || COALESCE(v,'∅'), 'OK');
EXCEPTION WHEN OTHERS THEN
  INSERT INTO resultat VALUES (8, 'participant réagit en direct (repli legacy)', 'accepté',
    'REFUSÉ ' || SQLSTATE || ' ' || SQLERRM, 'ÉCHEC');
END $$;

-- ── 9. Le piège du signalement : glisser un content dans le même UPDATE ────
DO $$
BEGIN
  UPDATE messages
     SET data = jsonb_set(
           jsonb_set(COALESCE(data,'{}'::jsonb), '{starredBy}', '["1X5F6RKlrTgyxZFSTvS6lXBx8C32"]'),
           '{content}', '"REECRIT EN DOUCE"')
   WHERE id = '19f41e09-a256-4b03-930c-d4dc1aebc2d0';
  INSERT INTO resultat VALUES (9, 'favori + content dans le même UPDATE', 'refusé', 'ACCEPTÉ', 'ÉCHEC');
EXCEPTION WHEN insufficient_privilege THEN
  INSERT INTO resultat VALUES (9, 'favori + content dans le même UPDATE', 'refusé', 'refusé 42501', 'OK');
END $$;

-- ── 10. Retirer une clé de l'expéditeur (fileUrl) ──────────────────────────
DO $$
BEGIN
  UPDATE messages SET data = data - 'content'
   WHERE id = '19f41e09-a256-4b03-930c-d4dc1aebc2d0';
  INSERT INTO resultat VALUES (10, 'non-expéditeur RETIRE la clé content', 'refusé', 'ACCEPTÉ', 'ÉCHEC');
EXCEPTION WHEN insufficient_privilege THEN
  INSERT INTO resultat VALUES (10, 'non-expéditeur RETIRE la clé content', 'refusé', 'refusé 42501', 'OK');
END $$;

-- ── 11. LES ACCUSÉS DE LECTURE (la régression muette à ne pas causer) ──────
DO $$
DECLARE v jsonb;
BEGIN
  PERFORM public.mark_messages_as_read(
    'ffd4f06e-862d-4416-9a67-9f8478f0bea1', '1X5F6RKlrTgyxZFSTvS6lXBx8C32');
  SELECT data->'readBy' INTO v FROM messages
   WHERE id = '19f41e09-a256-4b03-930c-d4dc1aebc2d0';
  INSERT INTO resultat VALUES (11, 'RPC mark_messages_as_read', 'accepté, readBy posé',
    CASE WHEN v ? '1X5F6RKlrTgyxZFSTvS6lXBx8C32'
         THEN 'accepté, readBy contient le lecteur'
         ELSE 'accepté MAIS readBy = ' || COALESCE(v::text,'∅') END,
    CASE WHEN v ? '1X5F6RKlrTgyxZFSTvS6lXBx8C32' THEN 'OK' ELSE 'ÉCHEC' END);
EXCEPTION WHEN OTHERS THEN
  INSERT INTO resultat VALUES (11, 'RPC mark_messages_as_read', 'accepté, readBy posé',
    'REFUSÉ ' || SQLSTATE || ' ' || SQLERRM, 'ÉCHEC');
END $$;

-- ── 12. LES ACCUSÉS DE LIVRAISON ──────────────────────────────────────────
DO $$
DECLARE v jsonb;
BEGIN
  PERFORM public.mark_messages_as_delivered(
    'ffd4f06e-862d-4416-9a67-9f8478f0bea1', '1X5F6RKlrTgyxZFSTvS6lXBx8C32');
  SELECT data->'deliveredTo' INTO v FROM messages
   WHERE id = '19f41e09-a256-4b03-930c-d4dc1aebc2d0';
  INSERT INTO resultat VALUES (12, 'RPC mark_messages_as_delivered', 'accepté, deliveredTo posé',
    CASE WHEN v ? '1X5F6RKlrTgyxZFSTvS6lXBx8C32'
         THEN 'accepté, deliveredTo contient le destinataire'
         ELSE 'accepté MAIS deliveredTo = ' || COALESCE(v::text,'∅') END,
    CASE WHEN v ? '1X5F6RKlrTgyxZFSTvS6lXBx8C32' THEN 'OK' ELSE 'ÉCHEC' END);
EXCEPTION WHEN OTHERS THEN
  INSERT INTO resultat VALUES (12, 'RPC mark_messages_as_delivered', 'accepté, deliveredTo posé',
    'REFUSÉ ' || SQLSTATE || ' ' || SQLERRM, 'ÉCHEC');
END $$;

-- ── 13. LA RÉACTION PAR RPC ───────────────────────────────────────────────
DO $$
DECLARE v jsonb;
BEGIN
  v := public.set_message_reaction('19f41e09-a256-4b03-930c-d4dc1aebc2d0', '🎉');
  INSERT INTO resultat VALUES (13, 'RPC set_message_reaction', 'accepté',
    'accepté → ' || COALESCE(v::text,'∅'),
    CASE WHEN v ? '1X5F6RKlrTgyxZFSTvS6lXBx8C32' THEN 'OK' ELSE 'ÉCHEC' END);
EXCEPTION WHEN OTHERS THEN
  INSERT INTO resultat VALUES (13, 'RPC set_message_reaction', 'accepté',
    'REFUSÉ ' || SQLSTATE || ' ' || SQLERRM, 'ÉCHEC');
END $$;

-- ═══ L'EXPÉDITEUR : « Modifier le message » ════════════════════════════════
SET LOCAL request.jwt.claims =
  '{"sub":"00000000-0000-0000-0000-0000000000bb","app_metadata":{"firebase_uid":"TeGcb1GRvOh2aWJgkQJuewXVjsV2"},"role":"authenticated"}';

DO $$
DECLARE v text;
BEGIN
  UPDATE messages
     SET data = jsonb_set(jsonb_set(data,'{content}','"TEXTE MODIFIE PAR SON AUTEUR"'),
                          '{editedAt}', to_jsonb(now()::text))
   WHERE id = '19f41e09-a256-4b03-930c-d4dc1aebc2d0';
  SELECT data->>'content' INTO v FROM messages
   WHERE id = '19f41e09-a256-4b03-930c-d4dc1aebc2d0';
  INSERT INTO resultat VALUES (14, 'EXPÉDITEUR modifie son propre content', 'accepté',
    'accepté → ' || COALESCE(v,'∅'),
    CASE WHEN v = 'TEXTE MODIFIE PAR SON AUTEUR' THEN 'OK' ELSE 'ÉCHEC' END);
EXCEPTION WHEN OTHERS THEN
  INSERT INTO resultat VALUES (14, 'EXPÉDITEUR modifie son propre content', 'accepté',
    'REFUSÉ ' || SQLSTATE || ' ' || SQLERRM, 'ÉCHEC');
END $$;

DO $$
DECLARE v boolean;
BEGIN
  UPDATE messages
     SET is_deleted = true,
         data = jsonb_set(jsonb_set(data,'{deletedForEveryone}','true'),'{content}','""')
   WHERE id = '19f41e09-a256-4b03-930c-d4dc1aebc2d0';
  SELECT is_deleted INTO v FROM messages WHERE id = '19f41e09-a256-4b03-930c-d4dc1aebc2d0';
  INSERT INTO resultat VALUES (15, 'EXPÉDITEUR supprime pour tout le monde', 'accepté',
    'accepté → is_deleted=' || v, CASE WHEN v THEN 'OK' ELSE 'ÉCHEC' END);
EXCEPTION WHEN OTHERS THEN
  INSERT INTO resultat VALUES (15, 'EXPÉDITEUR supprime pour tout le monde', 'accepté',
    'REFUSÉ ' || SQLSTATE || ' ' || SQLERRM, 'ÉCHEC');
END $$;

-- L'expéditeur non plus ne peut pas se réattribuer un message : le REVOKE de
-- colonne vaut pour tout le monde.
DO $$
BEGIN
  UPDATE messages SET created_at = now()
   WHERE id = '19f41e09-a256-4b03-930c-d4dc1aebc2d0';
  INSERT INTO resultat VALUES (16, 'EXPÉDITEUR antidate created_at', 'refusé', 'ACCEPTÉ', 'ÉCHEC');
EXCEPTION WHEN insufficient_privilege THEN
  INSERT INTO resultat VALUES (16, 'EXPÉDITEUR antidate created_at', 'refusé', 'refusé 42501', 'OK');
END $$;

-- ═══ L'ADMIN DU GROUPE : modération ════════════════════════════════════════
-- czk5… est `owner` du groupe d5518298… et créateur de la conversation.
SET LOCAL request.jwt.claims =
  '{"sub":"00000000-0000-0000-0000-0000000000cc","app_metadata":{"firebase_uid":"czk5UoUclLOFmbRtUIZ5XYLYKo52"},"role":"authenticated"}';

-- 17. L'admin ne doit PAS pouvoir réécrire le message d'un membre.
DO $$
BEGIN
  UPDATE messages SET data = jsonb_set(data, '{content}', '"L''ADMIN A PARLE A MA PLACE"')
   WHERE id = '2a6bddb8-812f-4c46-8681-d52332a37574';
  INSERT INTO resultat VALUES (17, 'ADMIN réécrit le content d''un membre', 'refusé', 'ACCEPTÉ', 'ÉCHEC');
EXCEPTION WHEN insufficient_privilege THEN
  INSERT INTO resultat VALUES (17, 'ADMIN réécrit le content d''un membre', 'refusé', 'refusé 42501', 'OK');
END $$;

-- 18. Mais il DOIT pouvoir supprimer pour tout le monde (modération).
DO $$
DECLARE v boolean;
BEGIN
  UPDATE messages
     SET is_deleted = true,
         data = jsonb_set(jsonb_set(data,'{deletedForEveryone}','true'),'{content}','""')
   WHERE id = '2a6bddb8-812f-4c46-8681-d52332a37574';
  SELECT is_deleted INTO v FROM messages WHERE id = '2a6bddb8-812f-4c46-8681-d52332a37574';
  INSERT INTO resultat VALUES (18, 'ADMIN supprime pour tous (modération)', 'accepté',
    'accepté → is_deleted=' || v, CASE WHEN v THEN 'OK' ELSE 'ÉCHEC' END);
EXCEPTION WHEN OTHERS THEN
  INSERT INTO resultat VALUES (18, 'ADMIN supprime pour tous (modération)', 'accepté',
    'REFUSÉ ' || SQLSTATE || ' ' || SQLERRM, 'ÉCHEC');
END $$;

-- 19. Et la porte se REFERME : le message est supprimé, `content` est vide —
--     sans le `NOT OLD.is_deleted`, l'admin garderait la main sur `data`.
DO $$
BEGIN
  UPDATE messages SET data = jsonb_set(data, '{fileUrl}', '"https://exfil.example/x"')
   WHERE id = '2a6bddb8-812f-4c46-8681-d52332a37574';
  INSERT INTO resultat VALUES (19, 'ADMIN écrit encore après suppression', 'refusé', 'ACCEPTÉ', 'ÉCHEC');
EXCEPTION WHEN insufficient_privilege THEN
  INSERT INTO resultat VALUES (19, 'ADMIN écrit encore après suppression', 'refusé', 'refusé 42501', 'OK');
END $$;

RESET ROLE;

-- ═══ Rapport ═══════════════════════════════════════════════════════════════
SELECT n, verdict, cas, attendu, obtenu FROM resultat ORDER BY n;

ROLLBACK;
