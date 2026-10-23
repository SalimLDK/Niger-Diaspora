-- Banc : modération de l'annuaire (migration 20261018190000).
--
--   supabase db query --linked -f tools/rls_tests/annuaire_moderation.sql
--
-- Condition : 0 cas en ÉCHEC. Tout est dans un `BEGIN … ROLLBACK`.
-- AVANT `db push` : injecter la migration à la place de `-- @@CIBLE@@`
-- (python tools/rls_tests/repeter_cible.py <banc> <migration> <sortie>).
--
-- CE QU'IL VÉRIFIE. Le danger est qu'un badge « vérifié » ou une promotion
-- payante soit posé par quelqu'un qui n'en a pas le droit (un propriétaire,
-- un administrateur sans le droit, ou par une écriture directe), sans base ni
-- motif ni trace ; qu'une fiche retirée par l'administration se réactive
-- d'elle-même ; et que l'historique se réécrive. Il vérifie aussi que le
-- propriétaire garde la main sur sa fiche (y compris la réécriture « à
-- l'identique » que fait l'application).

BEGIN;

SET LOCAL lock_timeout = '5s';

CREATE TEMP TABLE resultat(n int, cas text, attendu text, obtenu text, verdict text);
GRANT ALL ON resultat TO anon, authenticated;

CREATE FUNCTION pg_temp.essai(n int, cas text, attendu text, q text) RETURNS void
LANGUAGE plpgsql AS $f$
DECLARE obtenu text;
BEGIN
  EXECUTE q;
  obtenu := 'OK';
  INSERT INTO resultat VALUES (n, cas, attendu, obtenu,
    CASE WHEN obtenu = attendu THEN 'OK' ELSE 'ÉCHEC' END);
EXCEPTION WHEN OTHERS THEN
  INSERT INTO resultat VALUES (n, cas, attendu, SQLSTATE,
    CASE WHEN SQLSTATE = attendu THEN 'OK' ELSE 'ÉCHEC' END);
END $f$;

CREATE FUNCTION pg_temp.moi(uid text) RETURNS void
LANGUAGE sql AS $f$
  SELECT set_config('request.jwt.claims', jsonb_build_object('role','authenticated',
    'app_metadata', jsonb_build_object('firebase_uid', uid))::text, true)
$f$;

CREATE FUNCTION pg_temp.verifie(n int, cas text, attendu text, obtenu text) RETURNS void
LANGUAGE sql AS $f$
  INSERT INTO resultat VALUES (n, cas, attendu, obtenu,
    CASE WHEN attendu = obtenu THEN 'OK' ELSE 'ÉCHEC' END)
$f$;

-- @@CIBLE@@

INSERT INTO public.users (id, display_name, email, is_admin, admin_role) VALUES
  ('banc-ann-super',   'Super',    'ann-super@banc.test',   true,  'superAdmin'),
  ('banc-ann-biz',     'BizMod',   'ann-biz@banc.test',     true,  'businessMod'),
  ('banc-ann-content', 'Content',  'ann-content@banc.test', true,  'contentMod'),
  ('banc-ann-finance', 'Finance',  'ann-fin@banc.test',     true,  'financeMod'),
  ('banc-ann-owner',   'Proprio',  'ann-owner@banc.test',   false, NULL),
  ('banc-ann-ordi',    'Ordi',     'ann-ordi@banc.test',    false, NULL);

INSERT INTO public.businesses (id, owner_id, name, description, category, city, country_code) VALUES
  ('00000000-0000-0000-0000-0000000000b1', 'banc-ann-owner', 'b1 à vérifier',  'd', 'restaurant', 'Niamey', 'Niger'),
  ('00000000-0000-0000-0000-0000000000b2', 'banc-ann-owner', 'b2 à supprimer', 'd', 'other',      'Niamey', 'Niger'),
  ('00000000-0000-0000-0000-0000000000b3', 'banc-ann-owner', 'b3 à archiver',  'd', 'other',      'carte',  'Mali'),
  ('00000000-0000-0000-0000-0000000000b4', 'banc-ann-owner', 'b4 du proprio',  'd', 'other',      'Zinder', 'Niger'),
  ('00000000-0000-0000-0000-0000000000b5', 'banc-ann-biz',   'b5 d''un admin', 'd', 'other',      'Niamey', 'Niger');

-- ═══ 1. Catalogue ══════════════════════════════════════════════════════════
SELECT pg_temp.verifie(1, 'archive au catalogue ; businessMod porte view/approve/boost/delete/archive ; contentMod aucune', 'true/5/0',
  (SELECT (count(*) = 1)::text FROM public.admin_permissions WHERE key = 'directory.listings.archive') || '/' ||
  (SELECT count(*) FROM public.admin_role_permissions WHERE role = 'businessMod' AND permission LIKE 'directory.listings.%') || '/' ||
  (SELECT count(*) FROM public.admin_role_permissions WHERE role IN ('contentMod', 'financeMod') AND permission LIKE 'directory.%'));
SELECT pg_temp.verifie(2, 'anon n''exécute aucune des six RPC', 'false',
  (has_function_privilege('anon', 'public.business_admin_verify(uuid,text,timestamptz)', 'EXECUTE')
   OR has_function_privilege('anon', 'public.business_admin_unverify(uuid,text)', 'EXECUTE')
   OR has_function_privilege('anon', 'public.business_admin_archive(uuid,text)', 'EXECUTE')
   OR has_function_privilege('anon', 'public.business_admin_restore(uuid,text)', 'EXECUTE')
   OR has_function_privilege('anon', 'public.business_admin_set_boost(uuid,boolean,integer,text)', 'EXECUTE')
   OR has_function_privilege('anon', 'public.business_admin_delete(uuid,text)', 'EXECUTE'))::text);

-- ═══ 2. Vérifier : refus ═══════════════════════════════════════════════════
SELECT pg_temp.moi('banc-ann-owner');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(10, 'propriétaire : se vérifier par la RPC REFUSÉ', '42501',
  $q$SELECT public.business_admin_verify('00000000-0000-0000-0000-0000000000b1', 'Je suis vérifié')$q$);
RESET ROLE;
SELECT pg_temp.moi('banc-ann-content');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(11, 'contentMod : vérifier REFUSÉ', '42501',
  $q$SELECT public.business_admin_verify('00000000-0000-0000-0000-0000000000b1', 'Registre du commerce consulté')$q$);
RESET ROLE;
SELECT pg_temp.moi('banc-ann-finance');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(12, 'financeMod : vérifier REFUSÉ', '42501',
  $q$SELECT public.business_admin_verify('00000000-0000-0000-0000-0000000000b1', 'Registre du commerce consulté')$q$);
RESET ROLE;

SELECT pg_temp.moi('banc-ann-biz');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(13, 'businessMod : vérifier sans base → 22023', '22023',
  $q$SELECT public.business_admin_verify('00000000-0000-0000-0000-0000000000b1', '  ')$q$);
SELECT pg_temp.essai(14, 'businessMod : révision dans le passé → 22023', '22023',
  $q$SELECT public.business_admin_verify('00000000-0000-0000-0000-0000000000b1', 'Registre du commerce consulté', now() - interval '1 day')$q$);
SELECT pg_temp.essai(15, 'businessMod : fiche introuvable → P0002', 'P0002',
  $q$SELECT public.business_admin_verify('00000000-0000-0000-0000-0000000000ff', 'Registre du commerce consulté')$q$);
SELECT pg_temp.essai(16, 'businessMod : vérifie b1 avec sa base et une révision', 'OK',
  $q$SELECT public.business_admin_verify('00000000-0000-0000-0000-0000000000b1', 'Registre du commerce consulté le 18/10', now() + interval '365 days')$q$);
SELECT pg_temp.essai(17, 'businessMod : vérifier b1 une seconde fois → 55000', '55000',
  $q$SELECT public.business_admin_verify('00000000-0000-0000-0000-0000000000b1', 'Registre du commerce consulté le 18/10')$q$);
RESET ROLE;

SELECT pg_temp.verifie(18, 'b1 : vérifiée, par qui, sur quelle base, à réviser', 'true/banc-ann-biz/Registre du commerce consulté le 18/10/true',
  (SELECT is_verified::text || '/' || verified_by || '/' || verification_source || '/' || (verified_at IS NOT NULL AND next_review_at IS NOT NULL)::text
     FROM public.businesses WHERE id = '00000000-0000-0000-0000-0000000000b1'));

-- ═══ 3. Aucune écriture directe n'atteint le badge ═════════════════════════
SELECT pg_temp.moi('banc-ann-owner');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(20, 'propriétaire : poser is_verified sur b4 REFUSÉ', '42501',
  $q$UPDATE public.businesses SET is_verified = true WHERE id = '00000000-0000-0000-0000-0000000000b4'$q$);
SELECT pg_temp.essai(21, 'propriétaire : poser verification_source REFUSÉ', '42501',
  $q$UPDATE public.businesses SET verification_source = 'moi' WHERE id = '00000000-0000-0000-0000-0000000000b4'$q$);
SELECT pg_temp.essai(22, 'propriétaire : se promouvoir REFUSÉ', '42501',
  $q$UPDATE public.businesses SET is_boosted = true WHERE id = '00000000-0000-0000-0000-0000000000b4'$q$);
SELECT pg_temp.essai(23, 'propriétaire : s''archiver lui-même sans raison REFUSÉ (colonne serveur)', '42501',
  $q$UPDATE public.businesses SET archived_at = now() WHERE id = '00000000-0000-0000-0000-0000000000b4'$q$);
SELECT pg_temp.essai(24, 'propriétaire : réécrire sa fiche à l''identique (comme l''application)', 'OK',
  $q$UPDATE public.businesses SET name = name, is_verified = is_verified, is_boosted = is_boosted, boost_expires_at = boost_expires_at, rating = rating WHERE id = '00000000-0000-0000-0000-0000000000b4'$q$);
SELECT pg_temp.essai(25, 'propriétaire : changer sa ville et son nom', 'OK',
  $q$UPDATE public.businesses SET city = 'Maradi', name = 'b4 renommée' WHERE id = '00000000-0000-0000-0000-0000000000b4'$q$);
SELECT pg_temp.essai(26, 'propriétaire : créer une fiche normale', 'OK',
  $q$INSERT INTO public.businesses (owner_id, name, description, category) VALUES ('banc-ann-owner', 'neuve', 'd', 'other')$q$);
SELECT pg_temp.essai(27, 'propriétaire : créer une fiche DÉJÀ vérifiée REFUSÉ', '42501',
  $q$INSERT INTO public.businesses (owner_id, name, description, category, is_verified) VALUES ('banc-ann-owner', 'faux badge', 'd', 'other', true)$q$);
RESET ROLE;

-- Un administrateur n'a plus de voie d'écriture directe.
SELECT pg_temp.moi('banc-ann-super');
SET LOCAL ROLE authenticated;
UPDATE public.businesses SET name = 'écrasé par un admin' WHERE id = '00000000-0000-0000-0000-0000000000b4';
DELETE FROM public.businesses WHERE id = '00000000-0000-0000-0000-0000000000b4';
RESET ROLE;
SELECT pg_temp.moi('banc-ann-biz');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(30, 'businessMod, PROPRIÉTAIRE de b5 : poser is_verified sur sa propre fiche REFUSÉ (plus d''exemption admin)', '42501',
  $q$UPDATE public.businesses SET is_verified = true WHERE id = '00000000-0000-0000-0000-0000000000b5'$q$);
RESET ROLE;
SELECT pg_temp.verifie(31, 'UPDATE / DELETE directs d''un admin sur la fiche d''autrui : b4 intacte', 'b4 renommée/Maradi/false',
  (SELECT name || '/' || city || '/' || is_verified::text FROM public.businesses WHERE id = '00000000-0000-0000-0000-0000000000b4'));

-- ═══ 4. Retirer le badge ═══════════════════════════════════════════════════
SELECT pg_temp.moi('banc-ann-biz');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(40, 'businessMod : retirer le badge sans motif → 22023', '22023',
  $q$SELECT public.business_admin_unverify('00000000-0000-0000-0000-0000000000b1', '')$q$);
SELECT pg_temp.essai(41, 'businessMod : retirer le badge d''une fiche non vérifiée → 55000', '55000',
  $q$SELECT public.business_admin_unverify('00000000-0000-0000-0000-0000000000b3', 'Plus à jour')$q$);
SELECT pg_temp.essai(42, 'businessMod : retire le badge de b1', 'OK',
  $q$SELECT public.business_admin_unverify('00000000-0000-0000-0000-0000000000b1', 'Le registre a été radié')$q$);
RESET ROLE;
SELECT pg_temp.verifie(43, 'b1 : badge et provenance effacés', 'false/vide',
  (SELECT is_verified::text || '/' || coalesce(verified_by, 'vide') FROM public.businesses WHERE id = '00000000-0000-0000-0000-0000000000b1'));

-- ═══ 5. Archiver / restaurer ═══════════════════════════════════════════════
SELECT pg_temp.moi('banc-ann-content');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(50, 'contentMod : archiver REFUSÉ', '42501',
  $q$SELECT public.business_admin_archive('00000000-0000-0000-0000-0000000000b3', 'Nom incohérent')$q$);
RESET ROLE;
SELECT pg_temp.moi('banc-ann-biz');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(51, 'businessMod : promouvoir b3 pour 30 jours', 'OK',
  $q$SELECT public.business_admin_set_boost('00000000-0000-0000-0000-0000000000b3', true, 30, 'Partenaire')$q$);
SELECT pg_temp.essai(52, 'businessMod : archiver sans motif → 22023', '22023',
  $q$SELECT public.business_admin_archive('00000000-0000-0000-0000-0000000000b3', '')$q$);
SELECT pg_temp.essai(53, 'businessMod : archive b3', 'OK',
  $q$SELECT public.business_admin_archive('00000000-0000-0000-0000-0000000000b3', 'Ville et nom incohérents')$q$);
SELECT pg_temp.essai(54, 'businessMod : archiver une seconde fois → 55000', '55000',
  $q$SELECT public.business_admin_archive('00000000-0000-0000-0000-0000000000b3', 'Ville et nom incohérents')$q$);
SELECT pg_temp.essai(55, 'businessMod : promouvoir une fiche archivée → 55000', '55000',
  $q$SELECT public.business_admin_set_boost('00000000-0000-0000-0000-0000000000b3', true, 30, 'Partenaire')$q$);
SELECT pg_temp.essai(56, 'businessMod : vérifier une fiche archivée → 55000', '55000',
  $q$SELECT public.business_admin_verify('00000000-0000-0000-0000-0000000000b3', 'Registre du commerce consulté')$q$);
RESET ROLE;
SELECT pg_temp.verifie(57, 'b3 archivée : inactive, raison conservée, promotion arrêtée', 'false/Ville et nom incohérents/false',
  (SELECT is_active::text || '/' || archived_reason || '/' || is_boosted::text FROM public.businesses WHERE id = '00000000-0000-0000-0000-0000000000b3'));

SELECT pg_temp.moi('banc-ann-owner');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(58, 'propriétaire : réactiver lui-même sa fiche archivée REFUSÉ', '42501',
  $q$UPDATE public.businesses SET is_active = true WHERE id = '00000000-0000-0000-0000-0000000000b3'$q$);
SELECT pg_temp.verifie(59, 'propriétaire : voit sa fiche archivée (et pourquoi)', '1',
  (SELECT count(*)::text FROM public.businesses WHERE id = '00000000-0000-0000-0000-0000000000b3' AND archived_reason IS NOT NULL));
RESET ROLE;
SELECT pg_temp.moi('banc-ann-ordi');
SET LOCAL ROLE authenticated;
SELECT pg_temp.verifie(60, 'un membre ne voit pas la fiche archivée', '0',
  (SELECT count(*)::text FROM public.businesses WHERE id = '00000000-0000-0000-0000-0000000000b3'));
RESET ROLE;
SELECT pg_temp.moi('banc-ann-biz');
SET LOCAL ROLE authenticated;
SELECT pg_temp.verifie(61, 'businessMod (directory.listings.view) la voit', '1',
  (SELECT count(*)::text FROM public.businesses WHERE id = '00000000-0000-0000-0000-0000000000b3'));
SELECT pg_temp.essai(62, 'businessMod : restaurer sans motif → 22023', '22023',
  $q$SELECT public.business_admin_restore('00000000-0000-0000-0000-0000000000b3', '')$q$);
SELECT pg_temp.essai(63, 'businessMod : restaurer une fiche non archivée → 55000', '55000',
  $q$SELECT public.business_admin_restore('00000000-0000-0000-0000-0000000000b4', 'Erreur de ma part')$q$);
SELECT pg_temp.essai(64, 'businessMod : restaure b3', 'OK',
  $q$SELECT public.business_admin_restore('00000000-0000-0000-0000-0000000000b3', 'Nom corrigé par le propriétaire')$q$);
RESET ROLE;
SELECT pg_temp.verifie(65, 'b3 restaurée : active, plus archivée', 'true/vide',
  (SELECT is_active::text || '/' || coalesce(archived_reason, 'vide') FROM public.businesses WHERE id = '00000000-0000-0000-0000-0000000000b3'));

-- ═══ 6. Promotion ══════════════════════════════════════════════════════════
SELECT pg_temp.moi('banc-ann-biz');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(70, 'businessMod : promotion sans durée → 22023', '22023',
  $q$SELECT public.business_admin_set_boost('00000000-0000-0000-0000-0000000000b4', true, NULL, 'Partenaire')$q$);
SELECT pg_temp.essai(71, 'businessMod : promotion de 400 jours → 22023', '22023',
  $q$SELECT public.business_admin_set_boost('00000000-0000-0000-0000-0000000000b4', true, 400, 'Partenaire')$q$);
SELECT pg_temp.essai(72, 'businessMod : retirer la promotion d''une fiche non promue → 55000', '55000',
  $q$SELECT public.business_admin_set_boost('00000000-0000-0000-0000-0000000000b4', false, NULL, 'Fin du partenariat')$q$);
RESET ROLE;
SELECT pg_temp.moi('banc-ann-finance');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(73, 'financeMod : promouvoir REFUSÉ', '42501',
  $q$SELECT public.business_admin_set_boost('00000000-0000-0000-0000-0000000000b4', true, 30, 'Partenaire')$q$);
RESET ROLE;

-- ═══ 7. Supprimer ══════════════════════════════════════════════════════════
SELECT pg_temp.moi('banc-ann-content');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(80, 'contentMod : supprimer REFUSÉ', '42501',
  $q$SELECT public.business_admin_delete('00000000-0000-0000-0000-0000000000b2', 'Fiche frauduleuse')$q$);
RESET ROLE;
SELECT pg_temp.moi('banc-ann-biz');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(81, 'businessMod : supprimer sans motif → 22023', '22023',
  $q$SELECT public.business_admin_delete('00000000-0000-0000-0000-0000000000b2', '')$q$);
SELECT pg_temp.essai(82, 'businessMod : supprime b2 avec motif', 'OK',
  $q$SELECT public.business_admin_delete('00000000-0000-0000-0000-0000000000b2', 'Fiche frauduleuse')$q$);
SELECT pg_temp.essai(83, 'businessMod : supprimer b2 de nouveau → P0002', 'P0002',
  $q$SELECT public.business_admin_delete('00000000-0000-0000-0000-0000000000b2', 'Fiche frauduleuse')$q$);
RESET ROLE;

-- ═══ 8. L'historique ═══════════════════════════════════════════════════════
SELECT pg_temp.verifie(90, 'b1 : vérification puis retrait du badge, par un admin, avec la base / le motif', '2/admin/Registre du commerce consulté le 18/10',
  (SELECT count(*) || '/' || min(actor_role) || '/' ||
          max(reason) FILTER (WHERE changes -> 'is_verified' ->> 'to' = 'true')
     FROM public.business_history WHERE business_id = '00000000-0000-0000-0000-0000000000b1'));
SELECT pg_temp.verifie(91, 'b4 : renommage par le propriétaire consigné (nom et ville), rôle owner', '1/owner/true',
  (SELECT count(*) || '/' || min(actor_role) || '/' || bool_and(changes ? 'name' AND changes ? 'city')::text
     FROM public.business_history WHERE business_id = '00000000-0000-0000-0000-0000000000b4'));
SELECT pg_temp.verifie(92, 'b2 : suppression consignée avec instantané et motif', 'deleted/admin/Fiche frauduleuse/b2 à supprimer',
  (SELECT kind || '/' || actor_role || '/' || reason || '/' || (changes ->> 'name')
     FROM public.business_history WHERE business_id = '00000000-0000-0000-0000-0000000000b2'));
SELECT pg_temp.verifie(93, 'le tampon de réécriture « à l''identique » n''a rien consigné de plus sur b4', '1',
  (SELECT count(*)::text FROM public.business_history WHERE business_id = '00000000-0000-0000-0000-0000000000b4'));

SELECT pg_temp.moi('banc-ann-biz');
SET LOCAL ROLE authenticated;
SELECT pg_temp.verifie(94, 'businessMod lit l''historique', 'true',
  ((SELECT count(*) FROM public.business_history) >= 6)::text);
RESET ROLE;
SELECT pg_temp.moi('banc-ann-owner');
SET LOCAL ROLE authenticated;
SELECT pg_temp.verifie(95, 'le propriétaire ne lit pas le journal', '0', (SELECT count(*)::text FROM public.business_history));
RESET ROLE;
SELECT pg_temp.essai(96, 'UPDATE de l''historique REFUSÉ (même pour le propriétaire)', '42501',
  $q$UPDATE public.business_history SET reason = 'réécrit'$q$);
SELECT pg_temp.essai(97, 'DELETE de l''historique REFUSÉ', '42501',
  $q$DELETE FROM public.business_history$q$);

-- ═══ 9. Audit ══════════════════════════════════════════════════════════════
SELECT pg_temp.verifie(100, 'audit : b1 vérifiée + badge retiré ; b3 promue, archivée, restaurée ; b2 supprimée', '1/1/1/1/1/1',
  (SELECT count(*) FILTER (WHERE action = 'LISTING_VERIFIED' AND target_id = '00000000-0000-0000-0000-0000000000b1') || '/' ||
          count(*) FILTER (WHERE action = 'LISTING_UNVERIFIED' AND target_id = '00000000-0000-0000-0000-0000000000b1') || '/' ||
          count(*) FILTER (WHERE action = 'LISTING_BOOST_CHANGED' AND target_id = '00000000-0000-0000-0000-0000000000b3') || '/' ||
          count(*) FILTER (WHERE action = 'LISTING_ARCHIVED' AND target_id = '00000000-0000-0000-0000-0000000000b3') || '/' ||
          count(*) FILTER (WHERE action = 'LISTING_RESTORED' AND target_id = '00000000-0000-0000-0000-0000000000b3') || '/' ||
          count(*) FILTER (WHERE action = 'LISTING_DELETED' AND target_id = '00000000-0000-0000-0000-0000000000b2')
     FROM public.admin_audit_logs));
SELECT pg_temp.verifie(101, 'audit : aucune ligne pour b4 (tous les refus)', '0',
  (SELECT count(*)::text FROM public.admin_audit_logs WHERE target_id = '00000000-0000-0000-0000-0000000000b4'));

-- ═══ Rapport ═══════════════════════════════════════════════════════════════
SELECT n, verdict, cas, attendu, obtenu FROM resultat ORDER BY n;

ROLLBACK;
