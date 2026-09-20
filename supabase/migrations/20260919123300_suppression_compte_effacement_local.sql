-- Suppression de compte : dire à un téléphone DÉCONNECTÉ si la suppression est menée à terme.
--
-- LE PROBLÈME
-- La base MLS d'un téléphone (un fichier par compte, en clair) et ses clés locales
-- ne sont détruites par AUCUNE étape : ni la déconnexion, ni la demande de
-- suppression, ni la suppression définitive. Pendant le délai de grâce, les
-- conserver est voulu — une annulation les perdrait. Mais après la suppression
-- définitive, plus rien ne les détruit, et le téléphone n'est pas joignable : la
-- personne est déconnectée, son jeton de notification est retiré, aucun canal ne
-- va vers lui.
--
-- LA SOLUTION (décision de Salim, 2026-09-19) : un effacement DIFFÉRÉ, décidé par
-- le téléphone lui-même et CONFIRMÉ par le serveur.
--   1. La demande pose un marqueur local (uid + échéance).
--   2. Aux démarrages suivants, une fois l'échéance + 1 jour passée, le téléphone
--      demande au serveur — sans compte, il est déconnecté — si la suppression est
--      MENÉE À TERME.
--   3. Seulement si oui, il efface la base MLS et les clés de ce compte.
-- La confirmation serveur est ce qui protège d'une annulation faite ailleurs : sur
-- un autre appareil, le compte reste actif ; sans elle, ce téléphone effacerait les
-- clés d'un compte VIVANT.
--
-- CE QUE LA FONCTION RÉVÈLE
-- Un booléen, et un seul : la suppression de CET uid est-elle `completed` ? Jamais
-- `pending`, `deleting`, `blocked` ni `cancelled` — un compte en délai de grâce est
-- indiscernable d'un compte qui n'a rien demandé. Elle est appelable sans compte
-- (le téléphone n'en a plus) ; quelqu'un qui connaît un uid apprend seulement que
-- ce compte a été supprimé, ce que la disparition de son contenu lui apprend déjà.
-- Les uid sont des chaînes aléatoires de 28 caractères : pas d'énumération utile.
--
-- CE QUE CETTE FONCTION NE PEUT PAS FAIRE
-- Elle ne dit rien d'une restauration de sauvegarde qui aurait perdu la ligne
-- `completed` : la réponse est alors `false` et le téléphone réessaie à chaque
-- démarrage ; `replay_account_deletion` (20260919094300) la recrée, et le téléphone
-- efface au démarrage suivant.

CREATE OR REPLACE FUNCTION public.account_deletion_completed(p_uid text)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $function$
  SELECT EXISTS (
    SELECT 1 FROM public.account_deletion_requests r
     WHERE r.user_id = p_uid AND r.status = 'completed'
  )
$function$;

-- Un GRANT n'enlève rien : révoquer d'abord. Puis, exception voulue et unique de
-- cette famille de fonctions, `anon` — le téléphone n'a plus de session.
REVOKE ALL ON FUNCTION public.account_deletion_completed(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.account_deletion_completed(text) TO anon, authenticated, service_role;

COMMENT ON FUNCTION public.account_deletion_completed(text) IS
  'Appelable sans compte : la suppression de cet uid est-elle menée à terme (completed) ? Un booléen, jamais l''état intermédiaire. Sert à un téléphone déconnecté à décider d''effacer sa base MLS et ses clés locales.';

NOTIFY pgrst, 'reload schema';
