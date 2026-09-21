-- Banc : le temps réel de Supabase respecte-t-il les droits par COLONNE ?
--
--   supabase db query --linked -f tools/rls_tests/temps_reel_droits_colonnes.sql
--
-- POURQUOI CE BANC EXISTE. L'exposition 1.1b de l'audit (un compte connecté
-- lit e-mail, téléphone, position et jetons push de tout profil non privé)
-- ne se ferme que par `REVOKE SELECT` + `GRANT SELECT (colonnes publiques)`
-- sur `users`. Mais l'app lit `users` par DEUX abonnements temps réel
-- (`watchProfileLocationUpdates`, qui écoute la table ENTIÈRE sans filtre, et
-- `session_service.dart:281`). Si le temps réel ignorait les droits par
-- colonne, le REVOKE fermerait PostgREST et laisserait tout passer par le
-- websocket : il faudrait remplacer ces abonnements, pas les filtrer.
--
-- CE QU'IL FAIT. Il n'ouvre aucun websocket et ne demande aucun jeton : il
-- exécute la fonction même que le serveur temps réel appelle pour chaque
-- changement, `realtime.apply_rls(wal)`, sur un WAL fabriqué à la main. C'est
-- le code qui décide de ce qui part vers un abonné — on le fait tourner, on
-- ne le lit pas.
--
-- Il ne touche PAS `users`. Une table jetable, `banc_rt_colonnes`, porte une
-- colonne `secret`. Deux abonnés `authenticated` sur deux tables jumelles :
--
--   · TÉMOIN   — `secret` accordé : c'est `users` aujourd'hui. Le secret doit
--                ARRIVER. S'il n'arrivait pas, le banc mentirait sur tout le
--                reste — c'est ce cas qui lui permet d'échouer ;
--   · CIBLE    — `secret` révoqué : c'est `users` après le REVOKE.
--
-- Tout est dans un `BEGIN … ROLLBACK` : la table, les abonnements et le WAL
-- disparaissent. Une ligne de `realtime.subscription` non validée est
-- invisible au serveur temps réel, qui tourne dans une autre session.

BEGIN;

SET LOCAL lock_timeout = '5s';

CREATE TEMP TABLE resultat(n int, cas text, attendu text, obtenu text, verdict text);

-- ── Deux tables jumelles, RLS actif, lecture ouverte à `authenticated` ─────
CREATE TABLE public.banc_rt_temoin (id text PRIMARY KEY, public_col text, secret text);
CREATE TABLE public.banc_rt_cible  (id text PRIMARY KEY, public_col text, secret text);

ALTER TABLE public.banc_rt_temoin ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.banc_rt_cible  ENABLE ROW LEVEL SECURITY;

CREATE POLICY lecture ON public.banc_rt_temoin FOR SELECT TO authenticated USING (true);
CREATE POLICY lecture ON public.banc_rt_cible  FOR SELECT TO authenticated USING (true);

-- Le témoin : tous les droits, comme `users` aujourd'hui.
REVOKE ALL ON public.banc_rt_temoin FROM anon, authenticated;
GRANT SELECT ON public.banc_rt_temoin TO authenticated;

-- La cible : `secret` retiré, comme `users` après le REVOKE visé.
REVOKE ALL ON public.banc_rt_cible FROM anon, authenticated;
GRANT SELECT (id, public_col) ON public.banc_rt_cible TO authenticated;

-- ── Deux abonnés, un par table ─────────────────────────────────────────────
-- `claims` est le JWT que la policy verra ; `claims_role`, le rôle de travail
-- d'`apply_rls`, en est DÉRIVÉ (colonne générée depuis `claims ->> 'role'`) —
-- on ne peut pas le poser, et c'est heureux : le banc ne peut pas tricher.
INSERT INTO realtime.subscription (subscription_id, entity, filters, claims)
VALUES
  ('00000000-0000-0000-0000-00000000a001', 'public.banc_rt_temoin'::regclass, '{}',
   '{"role":"authenticated","sub":"banc","app_metadata":{"firebase_uid":"banc"}}'),
  ('00000000-0000-0000-0000-00000000a002', 'public.banc_rt_cible'::regclass, '{}',
   '{"role":"authenticated","sub":"banc","app_metadata":{"firebase_uid":"banc"}}');

-- ── La ligne doit EXISTER ──────────────────────────────────────────────────
-- Le routage vers un abonné est un `SELECT EXISTS(… WHERE pk = valeur)`
-- exécuté SOUS SON RÔLE (`realtime.build_prepared_statement_sql`). Un WAL qui
-- décrit une ligne absente de la table n'est routé vers personne : la
-- première version de ce banc l'a fait, et rendait « 0 abonné » sur les deux
-- tables — un parcours tronqué qui aurait pu passer pour une réponse.
INSERT INTO public.banc_rt_temoin VALUES ('ligne-1', 'visible', 'e-mail@prive');
INSERT INTO public.banc_rt_cible  VALUES ('ligne-1', 'visible', 'e-mail@prive');

-- ── Un UPDATE, au format wal2json que le serveur temps réel reçoit ─────────
CREATE TEMP TABLE sortie(tbl text, wal jsonb, abonnes uuid[], erreurs text[]);

INSERT INTO sortie
SELECT t, r.wal, r.subscription_ids, r.errors
  FROM unnest(ARRAY['banc_rt_temoin', 'banc_rt_cible']) t,
       LATERAL realtime.apply_rls(jsonb_build_object(
         'action', 'U',
         'schema', 'public',
         'table',  t,
         'columns', jsonb_build_array(
            jsonb_build_object('name','id',         'type','text','typeoid',25,'value','ligne-1'),
            jsonb_build_object('name','public_col', 'type','text','typeoid',25,'value','visible'),
            jsonb_build_object('name','secret',     'type','text','typeoid',25,'value','e-mail@prive')),
         'identity', jsonb_build_array(
            jsonb_build_object('name','id',         'type','text','typeoid',25,'value','ligne-1'),
            jsonb_build_object('name','public_col', 'type','text','typeoid',25,'value','ancien'),
            jsonb_build_object('name','secret',     'type','text','typeoid',25,'value','ancien@prive')),
         'pk', jsonb_build_array(
            jsonb_build_object('name','id','type','text','typeoid',25))
       )) r;

-- ═══ Verdicts ══════════════════════════════════════════════════════════════
-- Le témoin d'abord : s'il ne voit pas le secret, rien de ce qui suit ne vaut.
INSERT INTO resultat
SELECT 1, 'TÉMOIN — la ligne part bien vers l''abonné', 'abonné servi',
       coalesce(array_length(abonnes, 1), 0)::text || ' abonné(s), erreurs=' || coalesce(erreurs::text,'{}'),
       CASE WHEN array_length(abonnes, 1) = 1 AND coalesce(cardinality(erreurs),0) = 0 THEN 'OK' ELSE 'ÉCHEC' END
  FROM sortie WHERE tbl = 'banc_rt_temoin';

INSERT INTO resultat
SELECT 2, 'TÉMOIN — colonne accordée : le secret ARRIVE (c''est users aujourd''hui)',
       'secret présent',
       coalesce(wal -> 'record' ->> 'secret', '(absent)'),
       CASE WHEN wal -> 'record' ? 'secret' THEN 'OK' ELSE 'ÉCHEC' END
  FROM sortie WHERE tbl = 'banc_rt_temoin';

INSERT INTO resultat
SELECT 3, 'CIBLE — la ligne part toujours vers l''abonné (pas de 401)', 'abonné servi',
       coalesce(array_length(abonnes, 1), 0)::text || ' abonné(s), erreurs=' || coalesce(erreurs::text,'{}'),
       CASE WHEN array_length(abonnes, 1) = 1 AND coalesce(cardinality(erreurs),0) = 0 THEN 'OK' ELSE 'ÉCHEC' END
  FROM sortie WHERE tbl = 'banc_rt_cible';

INSERT INTO resultat
SELECT 4, 'CIBLE — colonne révoquée : le secret N''ARRIVE PAS (nouvelle valeur)',
       '(absent)',
       coalesce(wal -> 'record' ->> 'secret', '(absent)'),
       CASE WHEN NOT (wal -> 'record' ? 'secret') THEN 'OK' ELSE 'ÉCHEC' END
  FROM sortie WHERE tbl = 'banc_rt_cible';

INSERT INTO resultat
SELECT 5, 'CIBLE — ni l''ancienne valeur (old_record, REPLICA IDENTITY FULL)',
       '(absent)',
       coalesce(wal -> 'old_record' ->> 'secret', '(absent)'),
       CASE WHEN NOT coalesce(wal -> 'old_record' ? 'secret', false) THEN 'OK' ELSE 'ÉCHEC' END
  FROM sortie WHERE tbl = 'banc_rt_cible';

INSERT INTO resultat
SELECT 6, 'CIBLE — la colonne publique arrive toujours', 'visible',
       coalesce(wal -> 'record' ->> 'public_col', '(absent)'),
       CASE WHEN wal -> 'record' ->> 'public_col' = 'visible' THEN 'OK' ELSE 'ÉCHEC' END
  FROM sortie WHERE tbl = 'banc_rt_cible';

-- ═══ Rapport ═══════════════════════════════════════════════════════════════
SELECT n, verdict, cas, attendu, obtenu FROM resultat ORDER BY n;

ROLLBACK;
