-- `write_admin_audit` ne s'appelle plus que depuis le serveur. NON APPLIQUÉE.
--
-- À APPLIQUER APRÈS le déploiement du panneau Flutter qui passe par `admin_audit_client`
-- (voir l'ordre en tête de 20261029120000). Avant, l'écriture d'audit du panneau est coupée.
--
-- Les fonctions serveur (SECURITY DEFINER, propriétaire postgres) continuent d'appeler `write_admin_audit` :
-- le REVOKE ne vise que les rôles de connexion. Ce qui change : un administrateur — l'auditeur compris — ne peut
-- plus écrire une ligne de journal arbitraire en appelant la fonction directement.

SET lock_timeout = '5s';

REVOKE ALL ON FUNCTION public.write_admin_audit(text, text, text, text, text, text, jsonb)
  FROM PUBLIC, anon, authenticated;

NOTIFY pgrst, 'reload schema';
