-- Banc : dans le message d'un autre, chacun ne touche qu'à SA propre entrée
-- (migration 20261005110000).
--
--   supabase db query --linked -f tools/rls_tests/messages_chacun_ses_entrees.sql
--
-- Condition : 0 cas en ÉCHEC. Tout est dans un `BEGIN … ROLLBACK`.
--
-- AVANT `db push` : remplacer la ligne seule `-- @@MIGRATION@@` par le contenu
-- de la migration. APRÈS, lancé tel quel, le banc prouve l'état vivant.
--
-- Sans la migration (garde de 20260916210000), les cas 4 à 9 virent en
-- ÉCHEC : la garde laissait passer toute modification de ces clés. Les cas
-- 1 à 3 et 10 à 12 tiennent les chemins de l'app, qui ne doivent pas casser.
--
-- AUCUNE NOTIFICATION : la conversation, le message et les comptes sont
-- fabriqués ; le message est inséré en `postgres`.

BEGIN;

SET LOCAL lock_timeout = '5s';

CREATE TEMP TABLE resultat(n int, cas text, attendu text, obtenu text, verdict text);
CREATE TEMP TABLE ctx(k text PRIMARY KEY, v text);
GRANT ALL ON resultat, ctx TO anon, authenticated;

INSERT INTO ctx VALUES
  ('conv', 'banc-entrees-' || gen_random_uuid()::text),
  ('msg',  'banc-entrees-m-' || gen_random_uuid()::text);

INSERT INTO public.conversations (id, type, participant_ids, created_by, data)
SELECT v, 'group',
       ARRAY['banc-entrees-moi', 'banc-entrees-auteur', 'banc-entrees-tiers'],
       'banc-entrees-auteur', '{}'::jsonb
  FROM ctx WHERE k = 'conv';

INSERT INTO public.messages (id, conversation_id, sender_id, type, data)
SELECT (SELECT v FROM ctx WHERE k='msg'), (SELECT v FROM ctx WHERE k='conv'),
       'banc-entrees-auteur', 'text',
       '{"content":"bonjour",
         "readBy":["banc-entrees-auteur","banc-entrees-tiers"],
         "readAt":{"banc-entrees-tiers":"2026-10-05T08:00:00Z"},
         "deliveredTo":["banc-entrees-auteur"],
         "reactions":{"banc-entrees-tiers":"👍"},
         "deletedFor":["banc-entrees-tiers"],
         "reportedBy":["banc-entrees-tiers"],
         "starredBy":[]}'::jsonb;

-- @@MIGRATION@@

-- Une tentative : `OK` si l'issue est l'attendue (`accepté` ou `refusé`).
CREATE TEMP TABLE essai(n int, cas text, sql text, attendu text);
GRANT ALL ON essai TO authenticated;
INSERT INTO essai VALUES
  -- Ce que fait l'app : sa propre entrée.
  (1, 'favori : sa propre étoile',
   $q$SELECT basculer_dans_liste_message(%L, 'starredBy', 'banc-entrees-moi')$q$, 'accepté'),
  (2, 'supprimer pour soi : sa propre entrée',
   $q$SELECT fusionner_donnees_message(%L, '{"deletedFor":"banc-entrees-moi"}', true)$q$, 'accepté'),
  (3, 'réaction : la sienne, en direct',
   $q$UPDATE messages SET data = jsonb_set(data, '{reactions,banc-entrees-moi}', '"❤"') WHERE id = %L$q$, 'accepté'),
  -- Les abus : l'entrée d'un autre.
  (4, 'retirer la réaction d''un autre',
   $q$UPDATE messages SET data = data #- '{reactions,banc-entrees-tiers}' WHERE id = %L$q$, 'refusé'),
  (5, 'prêter une réaction à un autre',
   $q$UPDATE messages SET data = jsonb_set(data, '{reactions,banc-entrees-auteur}', '"😡"') WHERE id = %L$q$, 'refusé'),
  (6, 'écrire « Lu » au nom d''un autre',
   $q$UPDATE messages SET data = jsonb_set(data, '{readBy}', (data->'readBy') || '"banc-entrees-x"') WHERE id = %L$q$, 'refusé'),
  (7, 'retirer un autre de deletedFor (son message revient)',
   $q$UPDATE messages SET data = jsonb_set(data, '{deletedFor}', '[]') WHERE id = %L$q$, 'refusé'),
  (8, 'effacer le signalement d''un autre',
   $q$UPDATE messages SET data = jsonb_set(data, '{reportedBy}', '[]') WHERE id = %L$q$, 'refusé'),
  (9, 'antidater la lecture d''un autre',
   $q$UPDATE messages SET data = jsonb_set(data, '{readAt,banc-entrees-tiers}', '"2020-01-01T00:00:00Z"') WHERE id = %L$q$, 'refusé'),
  -- Ce qui était déjà fermé le reste.
  (10, 'réécrire le contenu d''un autre',
   $q$UPDATE messages SET data = jsonb_set(data, '{content}', '"faux"') WHERE id = %L$q$, 'refusé');

SET LOCAL request.jwt.claims =
  '{"sub":"00000000-0000-0000-0000-0000000000f3","app_metadata":{"firebase_uid":"banc-entrees-moi"},"role":"authenticated"}';
SET LOCAL ROLE authenticated;

DO $$
DECLARE e record; issue text;
BEGIN
  FOR e IN SELECT * FROM essai ORDER BY n LOOP
    BEGIN
      EXECUTE format(e.sql, (SELECT v FROM ctx WHERE k='msg'));
      issue := 'accepté';
    EXCEPTION WHEN insufficient_privilege THEN
      issue := 'refusé';
    WHEN OTHERS THEN
      issue := 'ERREUR ' || SQLSTATE || ' ' || SQLERRM;
    END;
    INSERT INTO resultat VALUES (e.n, e.cas, e.attendu, issue,
      CASE WHEN issue = e.attendu THEN 'OK' ELSE 'ÉCHEC' END);
  END LOOP;
END $$;

-- ═══ 11. L'expéditeur garde la main pleine ════════════════════════════════
RESET ROLE;
SET LOCAL request.jwt.claims =
  '{"sub":"00000000-0000-0000-0000-0000000000f4","app_metadata":{"firebase_uid":"banc-entrees-auteur"},"role":"authenticated"}';
SET LOCAL ROLE authenticated;
DO $$
BEGIN
  UPDATE messages SET data = jsonb_set(data, '{content}', '"modifié"')
   WHERE id = (SELECT v FROM ctx WHERE k='msg');
  INSERT INTO resultat VALUES (11, 'l''expéditeur modifie son message', 'accepté', 'accepté', 'OK');
EXCEPTION WHEN OTHERS THEN
  INSERT INTO resultat VALUES (11, 'l''expéditeur modifie son message', 'accepté',
    'ERREUR ' || SQLSTATE, 'ÉCHEC');
END $$;

-- ═══ 12. Les fonctions DEFINER (accusés groupés) passent en `postgres` ════
RESET ROLE;
DO $$
BEGIN
  UPDATE messages SET data = jsonb_set(data, '{deliveredTo}',
           '["banc-entrees-auteur","banc-entrees-tiers","banc-entrees-moi"]')
   WHERE id = (SELECT v FROM ctx WHERE k='msg');
  INSERT INTO resultat VALUES (12, 'chemin de confiance (postgres) : accusés de tous', 'accepté', 'accepté', 'OK');
EXCEPTION WHEN OTHERS THEN
  INSERT INTO resultat VALUES (12, 'chemin de confiance (postgres) : accusés de tous', 'accepté',
    'ERREUR ' || SQLSTATE, 'ÉCHEC');
END $$;

SELECT n, verdict, cas, attendu, obtenu FROM resultat ORDER BY n, cas;

ROLLBACK;
