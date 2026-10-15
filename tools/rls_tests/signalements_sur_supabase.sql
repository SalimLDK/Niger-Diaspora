-- Banc : les signalements écrits dans Supabase (migration 20261015100000).
--
--   supabase db query --linked -f tools/rls_tests/signalements_sur_supabase.sql
--
-- Condition : 0 cas en ÉCHEC. Tout est dans un `BEGIN … ROLLBACK`.
--
-- AVANT `db push` : remplacer la ligne seule `-- @@MIGRATION@@` par le
-- contenu de la migration (elle n'a ni BEGIN ni COMMIT). C'est la répétition.
-- APRÈS, lancé tel quel, le banc prouve l'état vivant.
--
-- Comptes RÉELS (jeton simulé par les claims) ; le ROLLBACK efface les
-- signalements d'essai. Aucun déclencheur de `reports` n'envoie de
-- notification.

BEGIN;
SET LOCAL lock_timeout = '5s';

CREATE TEMP TABLE resultat(n int, cas text, attendu text, obtenu text, verdict text);
CREATE TEMP TABLE ctx(k text PRIMARY KEY, v text);
GRANT ALL ON resultat, ctx TO anon, authenticated;

INSERT INTO ctx
SELECT 'u' || row_number() OVER (ORDER BY id), id
  FROM (SELECT id FROM public.users WHERE NOT coalesce(is_admin, false)
         ORDER BY id LIMIT 3) x;
INSERT INTO ctx SELECT 'admin', id FROM public.users WHERE is_admin ORDER BY id LIMIT 1;

CREATE FUNCTION pg_temp.v(p text) RETURNS text LANGUAGE sql STABLE AS
  $$ SELECT v FROM ctx WHERE k = p $$;
CREATE FUNCTION pg_temp.qui(p text) RETURNS void LANGUAGE sql AS $$
  SELECT set_config('request.jwt.claims',
    jsonb_build_object('role', 'authenticated', 'app_metadata',
      jsonb_build_object('firebase_uid', pg_temp.v(p)))::text, true);
$$;
CREATE FUNCTION pg_temp.essai(p_n int, p_cas text, p_attendu text, p_sql text)
RETURNS void LANGUAGE plpgsql AS $$
DECLARE n bigint; o text;
BEGIN
  BEGIN
    EXECUTE p_sql; GET DIAGNOSTICS n = ROW_COUNT; o := 'accepté ' || n;
  EXCEPTION WHEN OTHERS THEN o := 'refusé ' || SQLSTATE;
  END;
  INSERT INTO resultat VALUES (p_n, p_cas, p_attendu, o,
    CASE WHEN o = p_attendu THEN 'OK' ELSE 'ÉCHEC' END);
END $$;
CREATE FUNCTION pg_temp.constat(p_n int, p_cas text, p_attendu text, p_obtenu text)
RETURNS void LANGUAGE sql AS $$
  INSERT INTO resultat VALUES (p_n, p_cas, p_attendu, coalesce(p_obtenu, '(null)'),
    CASE WHEN p_obtenu IS NOT DISTINCT FROM p_attendu THEN 'OK' ELSE 'ÉCHEC' END);
$$;

-- @@MIGRATION@@

-- ═══ 1. Catalogue ══════════════════════════════════════════════════════════
SELECT pg_temp.constat(1, 'anon : aucun droit sur reports', '(aucun)',
  coalesce((SELECT string_agg(p, ',') FROM unnest(ARRAY['SELECT','INSERT','UPDATE','DELETE','TRUNCATE']) p
            WHERE has_table_privilege('anon', 'public.reports', p)), '(aucun)'));
SELECT pg_temp.constat(2, 'authenticated : ni INSERT, ni DELETE, ni TRUNCATE', '(aucun)',
  coalesce((SELECT string_agg(p, ',') FROM unnest(ARRAY['INSERT','DELETE','TRUNCATE']) p
            WHERE has_table_privilege('authenticated', 'public.reports', p)), '(aucun)'));
SELECT pg_temp.constat(3, 'authenticated : UPDATE réservé aux six colonnes de traitement',
  'action_taken,admin_note,reported_user_notified,reviewed_at,reviewed_by,status',
  (SELECT string_agg(column_name, ',' ORDER BY column_name)
     FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'reports'
      AND has_column_privilege('authenticated', 'public.reports', column_name, 'UPDATE')));
SELECT pg_temp.constat(4, 'signalement_creer : authenticated oui, anon non', 'true / false',
  has_function_privilege('authenticated', 'public.signalement_creer(text,text,text,text,text,text,text,jsonb)', 'EXECUTE')
  || ' / ' ||
  has_function_privilege('anon', 'public.signalement_creer(text,text,text,text,text,text,text,jsonb)', 'EXECUTE'));

-- ═══ 2. Dépôt ══════════════════════════════════════════════════════════════
SET LOCAL ROLE authenticated;
SELECT pg_temp.qui('u1');
SELECT pg_temp.essai(5, 'u1 signale un message', 'accepté 1',
  $$SELECT public.signalement_creer('message', 'msg-1', 'spam', 'desc', 'conv-1')$$);
SELECT pg_temp.essai(6, 'u1 signale deux fois le même contenu', 'refusé 23505',
  $$SELECT public.signalement_creer('message', 'msg-1', 'spam')$$);
SELECT pg_temp.essai(7, 'u1 signale un utilisateur (uid texte)', 'accepté 1',
  format($f$SELECT public.signalement_creer('user', %L, 'harassment', NULL, NULL, %L)$f$,
         pg_temp.v('u2'), pg_temp.v('u2')));
SELECT pg_temp.essai(8, 'u1 ne peut pas se signaler', 'refusé 22023',
  format($f$SELECT public.signalement_creer('user', %L, 'spam')$f$, pg_temp.v('u1')));
SELECT pg_temp.essai(9, 'cible inconnue refusée par la contrainte', 'refusé 23514',
  $$SELECT public.signalement_creer('galaxie', 'x', 'spam')$$);
SELECT pg_temp.essai(10, 'conversation acceptée', 'accepté 1',
  $$SELECT public.signalement_creer('conversation', 'conv-9', 'spam')$$);
SELECT pg_temp.essai(11, 'motif vide refusé', 'refusé 22023',
  $$SELECT public.signalement_creer('message', 'msg-2', '  ')$$);

-- Le signalant ne forge rien : plus d'INSERT direct, plus d'UPDATE.
SELECT pg_temp.essai(12, 'INSERT direct refusé', 'refusé 42501',
  format($f$INSERT INTO public.reports (reporter_id, target_type, target_id, reason, status)
            VALUES (%L, 'message', 'forge', 'x', 'resolved')$f$, pg_temp.v('u1')));
SELECT pg_temp.essai(13, 'UPDATE du statut par le signalant : zéro ligne (RLS)', 'accepté 0',
  $$UPDATE public.reports SET status = 'resolved'$$);
SELECT pg_temp.essai(14, 'DELETE refusé', 'refusé 42501', $$DELETE FROM public.reports$$);

-- ═══ 3. Lecture ════════════════════════════════════════════════════════════
SELECT pg_temp.essai(15, 'u1 lit ses 3 signalements', 'accepté 3', $$SELECT * FROM public.reports$$);
SELECT pg_temp.qui('u3');
SELECT pg_temp.essai(16, 'u3 ne lit rien de ceux de u1', 'accepté 0', $$SELECT * FROM public.reports$$);
SELECT pg_temp.essai(17, 'u3 : UPDATE sans effet (RLS)', 'accepté 0',
  $$UPDATE public.reports SET status = 'dismissed'$$);

-- ═══ 4. L'administrateur ═══════════════════════════════════════════════════
SELECT pg_temp.qui('admin');
SELECT pg_temp.essai(18, 'l''admin lit tout', 'accepté 3', $$SELECT * FROM public.reports$$);
SELECT pg_temp.essai(19, 'l''admin traite : 3 lignes', 'accepté 3',
  $$UPDATE public.reports SET status = 'resolved', admin_note = 'ok',
      action_taken = 'dismissed', reviewed_by = 'admin', reviewed_at = now()
      WHERE reporter_id = (SELECT v FROM ctx WHERE k = 'u1')$$);
SELECT pg_temp.essai(20, 'l''admin ne touche pas au motif du signalant', 'refusé 42501',
  $$UPDATE public.reports SET reason = 'autre'$$);
SELECT pg_temp.essai(21, 'l''admin ne supprime pas', 'refusé 42501', $$DELETE FROM public.reports$$);

RESET ROLE;
SELECT n, cas, attendu, obtenu, verdict FROM resultat ORDER BY n;
SELECT count(*) FILTER (WHERE verdict = 'ÉCHEC') AS echecs, count(*) AS total FROM resultat;
ROLLBACK;
