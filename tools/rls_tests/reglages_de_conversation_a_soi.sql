-- Banc : un participant ne coupe plus les notifications d'un autre, ni ne lui
-- archive, épingle ou efface la conversation (migration 20261014200000).
--
--   supabase db query --linked -f tools/rls_tests/reglages_de_conversation_a_soi.sql
--
-- Condition : 0 cas en ÉCHEC. Tout est dans un `BEGIN … ROLLBACK`.
--
-- AVANT `db push` : remplacer la ligne seule `-- @@MIGRATION@@` par le contenu
-- de la migration — c'est la répétition. APRÈS, lancé tel quel, le banc prouve
-- l'état vivant.
--
-- Sans la migration, les cas 1 à 4 et 6 tombent — le 6 est la course d'une
-- version installée qui lit `data`, puis le réécrit en entier : elle effaçait
-- la sourdine posée entre-temps par l'autre participant. Vérifié le
-- 2026-10-14 sur un PostgreSQL 16 local : cinq ÉCHEC sans la migration, 0
-- avec. PAS encore contre la production. Les cas 5 et 7 sont les témoins :
-- chacun règle toujours sa propre sourdine, et le reste de `data` (le nom)
-- change toujours.

BEGIN;

SET LOCAL lock_timeout = '5s';

CREATE TEMP TABLE resultat(n int, cas text, attendu text, obtenu text, verdict text);
CREATE TEMP TABLE ctx(k text PRIMARY KEY, v text);
GRANT ALL ON resultat, ctx TO anon, authenticated;

INSERT INTO ctx VALUES
  ('victime',  'banc-reglage-victime'),
  ('autre',    'banc-reglage-autre'),
  ('conv',     'banc-reglage-conv-' || gen_random_uuid());

INSERT INTO public.conversations (id, type, participant_ids, created_by, data)
SELECT (SELECT v FROM ctx WHERE k='conv'), 'individual',
       ARRAY[(SELECT v FROM ctx WHERE k='victime'), (SELECT v FROM ctx WHERE k='autre')],
       (SELECT v FROM ctx WHERE k='autre'),
       jsonb_build_object('pinnedBy', jsonb_build_object((SELECT v FROM ctx WHERE k='victime'), true));

-- @@MIGRATION@@

CREATE FUNCTION pg_temp.etre(p text) RETURNS void LANGUAGE sql AS $$
  SELECT set_config('request.jwt.claims',
    json_build_object('sub', '00000000-0000-0000-0000-0000000000fb',
                      'role', 'authenticated',
                      'app_metadata', json_build_object('firebase_uid',
                        (SELECT v FROM pg_temp.ctx WHERE k = p)))::text, true);
$$;
CREATE FUNCTION pg_temp.donnees() RETURNS jsonb LANGUAGE sql SECURITY DEFINER AS $$
  SELECT data FROM public.conversations WHERE id = (SELECT v FROM pg_temp.ctx WHERE k = 'conv');
$$;
CREATE FUNCTION pg_temp.de(cle text, u text) RETURNS text LANGUAGE sql AS $$
  SELECT COALESCE(pg_temp.donnees() -> cle ->> (SELECT v FROM pg_temp.ctx WHERE k = u), '∅');
$$;
-- L'autre pose une entrée au nom de la victime, comme `fusionner_donnees_conversation`.
CREATE FUNCTION pg_temp.poser_pour(cle text, u text, valeur jsonb) RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  UPDATE public.conversations
     SET data = jsonb_set(COALESCE(data, '{}'::jsonb), ARRAY[cle],
                  COALESCE(CASE WHEN jsonb_typeof(data -> cle) = 'object' THEN data -> cle END, '{}'::jsonb)
                  || jsonb_build_object((SELECT v FROM pg_temp.ctx WHERE k = u), valeur))
   WHERE id = (SELECT v FROM pg_temp.ctx WHERE k = 'conv');
END $$;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA pg_temp TO authenticated;

SET LOCAL ROLE authenticated;

INSERT INTO resultat VALUES (0, 'rôle effectif du banc', 'authenticated', current_user,
  CASE WHEN current_user = 'authenticated' THEN 'OK' ELSE 'ÉCHEC' END);

-- 1. L'autre met la victime en sourdine pour toujours.
DO $$
BEGIN
  PERFORM pg_temp.etre('autre');
  PERFORM pg_temp.poser_pour('mutedBy', 'victime', '"forever"');
  INSERT INTO resultat VALUES (1, 'sourdine posée au nom d''un autre', '∅', pg_temp.de('mutedBy', 'victime'),
    CASE WHEN pg_temp.de('mutedBy', 'victime') = '∅' THEN 'OK' ELSE 'ÉCHEC' END);
END $$;

-- 2. … lui efface la conversation.
DO $$
BEGIN
  PERFORM pg_temp.etre('autre');
  PERFORM pg_temp.poser_pour('deletedBy', 'victime', to_jsonb(now()::text));
  INSERT INTO resultat VALUES (2, 'conversation effacée au nom d''un autre', '∅', pg_temp.de('deletedBy', 'victime'),
    CASE WHEN pg_temp.de('deletedBy', 'victime') = '∅' THEN 'OK' ELSE 'ÉCHEC' END);
END $$;

-- 3. … l'archive.
DO $$
BEGIN
  PERFORM pg_temp.etre('autre');
  PERFORM pg_temp.poser_pour('archivedBy', 'victime', 'true');
  INSERT INTO resultat VALUES (3, 'conversation archivée au nom d''un autre', '∅', pg_temp.de('archivedBy', 'victime'),
    CASE WHEN pg_temp.de('archivedBy', 'victime') = '∅' THEN 'OK' ELSE 'ÉCHEC' END);
END $$;

-- 4. … lui retire son épingle (en écrasant la carte entière).
DO $$
BEGIN
  PERFORM pg_temp.etre('autre');
  UPDATE public.conversations SET data = data - 'pinnedBy'
   WHERE id = (SELECT v FROM ctx WHERE k='conv');
  INSERT INTO resultat VALUES (4, 'épingle d''un autre retirée', 'true', pg_temp.de('pinnedBy', 'victime'),
    CASE WHEN pg_temp.de('pinnedBy', 'victime') = 'true' THEN 'OK' ELSE 'ÉCHEC' END);
END $$;

-- 5. Témoin : chacun règle sa propre sourdine.
DO $$
BEGIN
  PERFORM pg_temp.etre('victime');
  PERFORM pg_temp.poser_pour('mutedBy', 'victime', '"8h"');
  PERFORM pg_temp.etre('autre');
  PERFORM pg_temp.poser_pour('mutedBy', 'autre', '"forever"');
  INSERT INTO resultat VALUES (5, 'témoin : chacun sa sourdine', '8h, forever',
    pg_temp.de('mutedBy', 'victime') || ', ' || pg_temp.de('mutedBy', 'autre'),
    CASE WHEN pg_temp.de('mutedBy', 'victime') = '8h' AND pg_temp.de('mutedBy', 'autre') = 'forever'
         THEN 'OK' ELSE 'ÉCHEC' END);
END $$;

-- 6. Une réécriture complète, lue avant le réglage de la victime, ne l'efface
--    pas (version installée qui lit puis réécrit `data`).
DO $$
DECLARE lu jsonb := pg_temp.donnees() #- ARRAY['mutedBy', (SELECT v FROM ctx WHERE k='victime')];
BEGIN
  PERFORM pg_temp.etre('autre');
  UPDATE public.conversations SET data = jsonb_set(lu, ARRAY['mutedBy', (SELECT v FROM ctx WHERE k='autre')], '"1h"'::jsonb)
   WHERE id = (SELECT v FROM ctx WHERE k='conv');
  INSERT INTO resultat VALUES (6, 'réécriture complète : le réglage de l''autre tient', '8h, 1h',
    pg_temp.de('mutedBy', 'victime') || ', ' || pg_temp.de('mutedBy', 'autre'),
    CASE WHEN pg_temp.de('mutedBy', 'victime') = '8h' AND pg_temp.de('mutedBy', 'autre') = '1h'
         THEN 'OK' ELSE 'ÉCHEC' END);
END $$;

-- 7. Témoin : le reste de `data` change toujours.
DO $$
BEGIN
  PERFORM pg_temp.etre('autre');
  UPDATE public.conversations SET data = data || '{"name":"Renommée"}'::jsonb
   WHERE id = (SELECT v FROM ctx WHERE k='conv');
  INSERT INTO resultat VALUES (7, 'témoin : le nom change toujours', 'Renommée',
    COALESCE(pg_temp.donnees() ->> 'name', '∅'),
    CASE WHEN pg_temp.donnees() ->> 'name' = 'Renommée' THEN 'OK' ELSE 'ÉCHEC' END);
END $$;

RESET ROLE;

SELECT n, verdict, cas, attendu, obtenu FROM resultat ORDER BY n, cas;

ROLLBACK;
