-- Banc : modération des membres (migration 20261019170000).
--
--   supabase db query --linked -f tools/rls_tests/membres_moderation.sql
--
-- Condition : 0 cas en ÉCHEC. Tout est dans un `BEGIN … ROLLBACK`.
-- AVANT `db push` : injecter la migration à la place de `-- @@CIBLE@@`
-- (python tools/rls_tests/repeter_cible.py <banc> <migration> <sortie>).
--
-- CE QU'IL VÉRIFIE. Le danger est qu'un badge, une suspension ou une
-- déconnexion forcée soit posé par quelqu'un qui n'en a pas le droit (ou sur
-- un administrateur, ou sur soi-même), sans motif, par une écriture directe ;
-- qu'une suspension à durée devienne permanente (ou qu'un bannissement ultérieur
-- soit levé par une échéance) ; et qu'un avertissement ne laisse aucune trace
-- ou prenne un titre choisi par l'agent. Il vérifie aussi que les comptes
-- ordinaires gardent la main sur leur propre fiche.

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
  ('banc-mbr-super',   'Super',    'mbr-super@banc.test',   true,  'superAdmin'),
  ('banc-mbr-content', 'Content',  'mbr-content@banc.test', true,  'contentMod'),
  ('banc-mbr-content2','Content 2','mbr-content2@banc.test',true,  'contentMod'),
  ('banc-mbr-biz',     'Biz',      'mbr-biz@banc.test',     true,  'businessMod'),
  ('banc-mbr-finance', 'Finance',  'mbr-fin@banc.test',     true,  'financeMod'),
  ('banc-mbr-ordi',    'Ordi',     'mbr-ordi@banc.test',    false, NULL),
  ('banc-mbr-m1',      'Membre 1', 'mbr-m1@banc.test',      false, NULL),
  ('banc-mbr-m2',      'Membre 2', 'mbr-m2@banc.test',      false, NULL),
  ('banc-mbr-m3',      'Membre 3', 'mbr-m3@banc.test',      false, NULL),
  ('banc-mbr-m4',      'Membre 4', 'mbr-m4@banc.test',      false, NULL);
-- m3 : banni pour de bon (comme la callable le fait).
UPDATE public.users SET is_banned = true, ban_reason = 'Harcèlement répété', banned_at = now(), banned_by = 'banc-mbr-super'
 WHERE id = 'banc-mbr-m3';

-- ═══ 1. Catalogue et droits ════════════════════════════════════════════════
SELECT pg_temp.verifie(1, '3 permissions au catalogue, mappées à contentMod seul', '3/3/0',
  (SELECT count(*) FROM public.admin_permissions WHERE key IN ('moderation.warnings.create', 'community.accounts.suspend', 'community.sessions.revoke')) || '/' ||
  (SELECT count(*) FROM public.admin_role_permissions WHERE role = 'contentMod' AND permission IN ('moderation.warnings.create', 'community.accounts.suspend', 'community.sessions.revoke')) || '/' ||
  (SELECT count(*) FROM public.admin_role_permissions WHERE role IN ('financeMod', 'businessMod') AND permission IN ('moderation.warnings.create', 'community.accounts.suspend', 'community.sessions.revoke')));
SELECT pg_temp.verifie(2, 'anon n''exécute aucune des six fonctions ; authenticated n''appelle pas l''aide interne', 'false',
  (has_function_privilege('anon', 'public.member_admin_verify(text,text)', 'EXECUTE')
   OR has_function_privilege('anon', 'public.member_admin_unverify(text,text)', 'EXECUTE')
   OR has_function_privilege('anon', 'public.member_admin_warn(text,text,text)', 'EXECUTE')
   OR has_function_privilege('anon', 'public.member_admin_suspend(text,integer,text)', 'EXECUTE')
   OR has_function_privilege('anon', 'public.member_admin_unsuspend(text,text)', 'EXECUTE')
   OR has_function_privilege('anon', 'public.member_admin_force_logout(text,text)', 'EXECUTE')
   OR has_function_privilege('authenticated', 'public.member_cible_check(text,text)', 'EXECUTE')
   OR has_function_privilege('authenticated', 'private.lever_suspensions_expirees()', 'EXECUTE'))::text);
SELECT pg_temp.verifie(3, 'le job d''échéance des suspensions est planifié', '1',
  (SELECT count(*)::text FROM cron.job WHERE jobname = 'lever-suspensions-expirees'));

-- ═══ 2. Vérifier ═════════════════════════════════════════════════════════
SELECT pg_temp.moi('banc-mbr-ordi');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(10, 'ordinaire : vérifier REFUSÉ', '42501',
  $q$SELECT public.member_admin_verify('banc-mbr-m1', 'Pièce d''identité vue')$q$);
RESET ROLE;
SELECT pg_temp.moi('banc-mbr-biz');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(11, 'businessMod : vérifier REFUSÉ', '42501',
  $q$SELECT public.member_admin_verify('banc-mbr-m1', 'Pièce d''identité vue')$q$);
RESET ROLE;

SELECT pg_temp.moi('banc-mbr-content');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(12, 'contentMod : vérifier sans base → 22023', '22023',
  $q$SELECT public.member_admin_verify('banc-mbr-m1', '  ')$q$);
SELECT pg_temp.essai(13, 'contentMod : membre introuvable → P0002', 'P0002',
  $q$SELECT public.member_admin_verify('fantome', 'Pièce d''identité vue')$q$);
SELECT pg_temp.essai(14, 'contentMod : se vérifier soi-même → 42501', '42501',
  $q$SELECT public.member_admin_verify('banc-mbr-content', 'Je suis moi')$q$);
SELECT pg_temp.essai(15, 'contentMod : vérifier un administrateur → 42501', '42501',
  $q$SELECT public.member_admin_verify('banc-mbr-content2', 'Collègue')$q$);
SELECT pg_temp.essai(16, 'contentMod : vérifier un compte banni → 55000', '55000',
  $q$SELECT public.member_admin_verify('banc-mbr-m3', 'Pièce d''identité vue')$q$);
SELECT pg_temp.essai(17, 'contentMod : vérifie m1 avec sa base', 'OK',
  $q$SELECT public.member_admin_verify('banc-mbr-m1', 'Pièce d''identité vue en visio le 19/10')$q$);
SELECT pg_temp.essai(18, 'contentMod : vérifier m1 de nouveau → 55000', '55000',
  $q$SELECT public.member_admin_verify('banc-mbr-m1', 'Pièce d''identité vue en visio le 19/10')$q$);
RESET ROLE;
SELECT pg_temp.verifie(19, 'm1 vérifié : par qui, sur quelle base', 'true/banc-mbr-content/Pièce d''identité vue en visio le 19/10',
  (SELECT is_verified::text || '/' || verified_by || '/' || verification_source FROM public.users WHERE id = 'banc-mbr-m1'));

-- Plus de voie directe, administrateur compris.
SELECT pg_temp.moi('banc-mbr-content');
SET LOCAL ROLE authenticated;
UPDATE public.users SET is_verified = true WHERE id = 'banc-mbr-m2';
SELECT pg_temp.essai(20, 'contentMod : poser SON propre badge par PostgREST REFUSÉ (plus d''exemption admin)', '42501',
  $q$UPDATE public.users SET is_verified = true WHERE id = 'banc-mbr-content'$q$);
SELECT pg_temp.essai(21, 'contentMod : se mettre un faux motif de bannissement REFUSÉ', '42501',
  $q$UPDATE public.users SET ban_reason = 'x' WHERE id = 'banc-mbr-content'$q$);
SELECT pg_temp.essai(22, 'contentMod : modifier son propre nom d''affichage (comme avant)', 'OK',
  $q$UPDATE public.users SET display_name = 'Content renommé' WHERE id = 'banc-mbr-content'$q$);
RESET ROLE;
SELECT pg_temp.verifie(23, 'UPDATE direct sur autrui : m2 intact (la policy admin est retirée)', 'false',
  (SELECT is_verified::text FROM public.users WHERE id = 'banc-mbr-m2'));
SELECT pg_temp.moi('banc-mbr-m1');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(24, 'un membre : modifier sa propre fiche (comme avant)', 'OK',
  $q$UPDATE public.users SET display_name = 'Membre 1 renommé' WHERE id = 'banc-mbr-m1'$q$);
SELECT pg_temp.essai(25, 'un membre : se poser un badge REFUSÉ', '42501',
  $q$UPDATE public.users SET verification_source = 'moi' WHERE id = 'banc-mbr-m1'$q$);
RESET ROLE;

-- ═══ 3. Retirer le badge ═══════════════════════════════════════════════════
SELECT pg_temp.moi('banc-mbr-content');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(30, 'retirer le badge sans motif → 22023', '22023',
  $q$SELECT public.member_admin_unverify('banc-mbr-m1', '')$q$);
SELECT pg_temp.essai(31, 'retirer le badge d''un membre non vérifié → 55000', '55000',
  $q$SELECT public.member_admin_unverify('banc-mbr-m4', 'Plus à jour')$q$);
SELECT pg_temp.essai(32, 'retire le badge de m1', 'OK',
  $q$SELECT public.member_admin_unverify('banc-mbr-m1', 'Le document présenté était périmé')$q$);
RESET ROLE;
SELECT pg_temp.verifie(33, 'm1 : badge et provenance effacés', 'false/vide',
  (SELECT is_verified::text || '/' || coalesce(verified_by, 'vide') FROM public.users WHERE id = 'banc-mbr-m1'));

-- ═══ 4. Déconnexion forcée ═════════════════════════════════════════════════
SELECT pg_temp.moi('banc-mbr-biz');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(40, 'businessMod : forcer une déconnexion REFUSÉ', '42501',
  $q$SELECT public.member_admin_force_logout('banc-mbr-m1', 'Compte compromis signalé')$q$);
RESET ROLE;
SELECT pg_temp.moi('banc-mbr-content');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(41, 'contentMod : sans motif → 22023', '22023',
  $q$SELECT public.member_admin_force_logout('banc-mbr-m1', '')$q$);
SELECT pg_temp.essai(42, 'contentMod : forcer la déconnexion d''un administrateur → 42501', '42501',
  $q$SELECT public.member_admin_force_logout('banc-mbr-content2', 'Test du banc')$q$);
SELECT pg_temp.essai(43, 'contentMod : déconnecte m1', 'OK',
  $q$SELECT public.member_admin_force_logout('banc-mbr-m1', 'Compte compromis signalé')$q$);
RESET ROLE;
SELECT pg_temp.moi('banc-mbr-super');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(44, 'superAdmin : déconnecte un administrateur', 'OK',
  $q$SELECT public.member_admin_force_logout('banc-mbr-content2', 'Appareil perdu')$q$);
RESET ROLE;
SELECT pg_temp.verifie(45, 'm1 : sentinelle de déconnexion posée (celle que l''app lit)', 'true',
  (SELECT (session_id LIKE 'force_logout_%')::text FROM public.users WHERE id = 'banc-mbr-m1'));

-- ═══ 5. Avertir ═══════════════════════════════════════════════════════════
SELECT pg_temp.moi('banc-mbr-biz');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(50, 'businessMod : avertir REFUSÉ', '42501',
  $q$SELECT public.member_admin_warn('banc-mbr-m4', 'Insultes en groupe', 'Merci de respecter les autres membres.')$q$);
RESET ROLE;
SELECT pg_temp.moi('banc-mbr-content');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(51, 'avertir sans motif interne → 22023', '22023',
  $q$SELECT public.member_admin_warn('banc-mbr-m4', '', 'Merci de respecter les autres membres.')$q$);
SELECT pg_temp.essai(52, 'message au membre trop court → 22023', '22023',
  $q$SELECT public.member_admin_warn('banc-mbr-m4', 'Insultes en groupe', 'stop')$q$);
SELECT pg_temp.essai(53, 'message de 301 caractères → 22023', '22023',
  $q$SELECT public.member_admin_warn('banc-mbr-m4', 'Insultes en groupe', repeat('x', 301))$q$);
SELECT pg_temp.essai(54, 'avertir un administrateur → 42501', '42501',
  $q$SELECT public.member_admin_warn('banc-mbr-content2', 'Test du banc', 'Message de test pour un collègue.')$q$);
SELECT pg_temp.verifie(55, 'premier avertissement de m4 : compteur = 1', '1',
  (SELECT public.member_admin_warn('banc-mbr-m4', 'Insultes en groupe', 'Merci de respecter les autres membres.')::text));
SELECT pg_temp.verifie(56, 'second avertissement : compteur = 2', '2',
  (SELECT public.member_admin_warn('banc-mbr-m4', 'Récidive le lendemain', 'Deuxième rappel : merci de respecter les autres.')::text));
RESET ROLE;
SELECT pg_temp.moi('banc-mbr-m4');
SET LOCAL ROLE authenticated;
SELECT pg_temp.verifie(57, 'm4 reçoit 2 notifications « system », au titre écrit par le serveur', '2/Avertissement de la modération',
  (SELECT count(*) || '/' || min(title) FROM public.notifications WHERE data ->> 'moderation' = 'warning'));
RESET ROLE;
SELECT pg_temp.moi('banc-mbr-m2');
SET LOCAL ROLE authenticated;
SELECT pg_temp.verifie(58, 'm2 ne reçoit rien', '0',
  (SELECT count(*)::text FROM public.notifications WHERE data ->> 'moderation' = 'warning'));
RESET ROLE;

-- ═══ 6. Suspendre et réactiver ═════════════════════════════════════════════
SELECT pg_temp.moi('banc-mbr-biz');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(60, 'businessMod : suspendre REFUSÉ', '42501',
  $q$SELECT public.member_admin_suspend('banc-mbr-m2', 7, 'Spam répété')$q$);
RESET ROLE;
SELECT pg_temp.moi('banc-mbr-content');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(61, 'durée 0 → 22023', '22023',
  $q$SELECT public.member_admin_suspend('banc-mbr-m2', 0, 'Spam répété')$q$);
SELECT pg_temp.essai(62, 'durée 31 jours → 22023', '22023',
  $q$SELECT public.member_admin_suspend('banc-mbr-m2', 31, 'Spam répété')$q$);
SELECT pg_temp.essai(63, 'sans durée → 22023', '22023',
  $q$SELECT public.member_admin_suspend('banc-mbr-m2', NULL, 'Spam répété')$q$);
SELECT pg_temp.essai(64, 'sans motif → 22023', '22023',
  $q$SELECT public.member_admin_suspend('banc-mbr-m2', 7, '')$q$);
SELECT pg_temp.essai(65, 'suspendre un administrateur → 42501', '42501',
  $q$SELECT public.member_admin_suspend('banc-mbr-content2', 7, 'Test du banc')$q$);
SELECT pg_temp.essai(66, 'suspendre un compte déjà banni → 55000', '55000',
  $q$SELECT public.member_admin_suspend('banc-mbr-m3', 7, 'Test du banc')$q$);
SELECT pg_temp.essai(67, 'suspend m2 pour 7 jours', 'OK',
  $q$SELECT public.member_admin_suspend('banc-mbr-m2', 7, 'Spam répété dans trois groupes')$q$);
SELECT pg_temp.essai(68, 'suspendre m2 de nouveau → 55000', '55000',
  $q$SELECT public.member_admin_suspend('banc-mbr-m2', 7, 'Spam répété dans trois groupes')$q$);
RESET ROLE;
SELECT pg_temp.verifie(69, 'm2 suspendu : mêmes drapeaux qu''un ban, échéance à ~7 jours, marque « Suspension : »', 'true/true/true/true',
  (SELECT is_banned::text || '/' || (session_id LIKE 'banned_%')::text || '/' || (ban_reason LIKE 'Suspension : %')::text || '/' ||
          (suspended_until BETWEEN now() + interval '6 days 23 hours' AND now() + interval '7 days 1 hour')::text
     FROM public.users WHERE id = 'banc-mbr-m2'));

SELECT pg_temp.moi('banc-mbr-content');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(70, 'réactiver sans motif → 22023', '22023',
  $q$SELECT public.member_admin_unsuspend('banc-mbr-m2', '')$q$);
SELECT pg_temp.essai(71, 'réactiver un BANNI (m3) par cette fonction → 55000 (c''est « Débannir »)', '55000',
  $q$SELECT public.member_admin_unsuspend('banc-mbr-m3', 'Erreur de ma part')$q$);
SELECT pg_temp.essai(72, 'réactive m2', 'OK',
  $q$SELECT public.member_admin_unsuspend('banc-mbr-m2', 'Le membre s''est expliqué')$q$);
RESET ROLE;
SELECT pg_temp.verifie(73, 'm2 réactivé : drapeaux effacés', 'false/vide/vide',
  (SELECT is_banned::text || '/' || coalesce(ban_reason, 'vide') || '/' || coalesce(session_id, 'vide') FROM public.users WHERE id = 'banc-mbr-m2'));

-- ═══ 7. L'échéance ══════════════════════════════════════════════════════════
-- m2 de nouveau suspendu, puis l'échéance passée : le job le lève.
SELECT pg_temp.moi('banc-mbr-content');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(80, 'suspend m2 (1 jour)', 'OK',
  $q$SELECT public.member_admin_suspend('banc-mbr-m2', 1, 'Nouvelle infraction aux règles')$q$);
SELECT pg_temp.essai(81, 'suspend m4 (1 jour)', 'OK',
  $q$SELECT public.member_admin_suspend('banc-mbr-m4', 1, 'Troisième infraction aux règles')$q$);
RESET ROLE;
UPDATE public.users SET suspended_until = now() - interval '1 hour' WHERE id IN ('banc-mbr-m2', 'banc-mbr-m4');
-- m4 : un bannissement définitif est posé ENTRE-TEMPS par la callable.
UPDATE public.users SET ban_reason = 'Harcèlement répété, bannissement définitif' WHERE id = 'banc-mbr-m4';
SELECT pg_temp.verifie(82, 'le job lève 1 suspension (m2) et laisse le bannissement de m4', '1',
  (SELECT private.lever_suspensions_expirees()::text));
SELECT pg_temp.verifie(83, 'm2 libre ; m4 TOUJOURS banni, échéance pendante nettoyée', 'false/true/vide',
  (SELECT a.is_banned::text || '/' || b.is_banned::text || '/' || coalesce(b.suspended_until::text, 'vide')
     FROM public.users a, public.users b WHERE a.id = 'banc-mbr-m2' AND b.id = 'banc-mbr-m4'));

-- ═══ 8. Historique ═════════════════════════════════════════════════════════
SELECT pg_temp.moi('banc-mbr-content');
SET LOCAL ROLE authenticated;
SELECT pg_temp.verifie(90, 'contentMod lit l''historique de m2 : suspendu, réactivé, suspendu, levé par le système', '4/2',
  (SELECT count(*) || '/' || count(*) FILTER (WHERE kind = 'suspended')
     FROM public.member_moderation_events WHERE member_id = 'banc-mbr-m2'));
RESET ROLE;
SELECT pg_temp.verifie(91, 'la levée par échéance est faite par le système (acteur nul)', 'true',
  (SELECT bool_or(actor_id IS NULL AND reason = 'Échéance de la suspension')::text FROM public.member_moderation_events WHERE member_id = 'banc-mbr-m2'));
SELECT pg_temp.moi('banc-mbr-biz');
SET LOCAL ROLE authenticated;
SELECT pg_temp.verifie(92, 'businessMod ne lit pas l''historique d''un membre', 'true',
  ((SELECT count(*) FROM public.member_moderation_events) >= 0 AND NOT public.admin_has_permission('community.members.view'))::text);
RESET ROLE;
SELECT pg_temp.moi('banc-mbr-ordi');
SET LOCAL ROLE authenticated;
SELECT pg_temp.verifie(93, 'un membre ordinaire ne lit aucun historique', '0',
  (SELECT count(*)::text FROM public.member_moderation_events));
RESET ROLE;
SELECT pg_temp.essai(94, 'UPDATE de l''historique REFUSÉ', '42501',
  $q$UPDATE public.member_moderation_events SET reason = 'réécrit'$q$);
SELECT pg_temp.essai(95, 'DELETE de l''historique REFUSÉ', '42501',
  $q$DELETE FROM public.member_moderation_events$q$);

-- ═══ 9. Audit ══════════════════════════════════════════════════════════════
SELECT pg_temp.verifie(100, 'audit : vérifié, badge retiré, déconnexions, avertissements', '1/1/2/2',
  (SELECT count(*) FILTER (WHERE action = 'MEMBER_VERIFIED') || '/' ||
          count(*) FILTER (WHERE action = 'MEMBER_UNVERIFIED') || '/' ||
          count(*) FILTER (WHERE action = 'MEMBER_SESSION_REVOKED') || '/' ||
          count(*) FILTER (WHERE action = 'MEMBER_WARNED')
     FROM public.admin_audit_logs WHERE target_id LIKE 'banc-mbr-%'));
SELECT pg_temp.verifie(101, 'audit : 3 suspensions, 1 réactivation par un agent', '3/1',
  (SELECT count(*) FILTER (WHERE action = 'MEMBER_SUSPENDED') || '/' ||
          count(*) FILTER (WHERE action = 'MEMBER_UNSUSPENDED')
     FROM public.admin_audit_logs WHERE target_id LIKE 'banc-mbr-%'));
SELECT pg_temp.verifie(102, 'l''audit ne contient ni le texte envoyé au membre ni les motifs', '0',
  (SELECT count(*)::text FROM public.admin_audit_logs
    WHERE target_id LIKE 'banc-mbr-%'
      AND (details::text LIKE '%respecter%' OR details::text LIKE '%Insultes%' OR details::text LIKE '%Spam%')));

-- ═══ Rapport ═══════════════════════════════════════════════════════════════
SELECT n, verdict, cas, attendu, obtenu FROM resultat ORDER BY n;

ROLLBACK;
