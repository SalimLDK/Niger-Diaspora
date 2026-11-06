-- Modèles de réponse du support : jeu de départ. Idempotent (un titre déjà présent n'est pas réinséré).
--
--   supabase db query --linked -f tools/seeds/modeles_reponse_support.sql
--
-- Table : public.support_reply_templates (migration 20261019210000). Les modèles se gèrent ensuite dans la console
-- (page « Modèles de réponse ») ou par les fonctions support_template_save / support_template_delete.
--
-- RÈGLES DE CONTENU
--   • Aucun contenu privé : ni nom, ni e-mail, ni téléphone, ni identifiant, ni montant, ni lien personnalisé.
--     Les parties à compléter sont écrites entre crochets : [prénom], [objet de la demande].
--   • Aucun engagement de délai : le délai légal des demandes de données n'est pas encore décidé (voir la fiche
--     des décisions ouvertes). Les modèles disent « nous revenons vers vous », pas « sous X jours ».
--   • Aucune promesse sur une fonction dont l'état n'est pas confirmé (paiements, salons audio : fermés).
--
-- GARDE : le script REFUSE de s'exécuter si un texte ressemble à une adresse e-mail, un numéro de téléphone ou un
-- lien. Il écrit dans la table comme propriétaire (created_by = 'seed') : aucune session d'administrateur requise.

BEGIN;
SET LOCAL lock_timeout = '5s';

CREATE TEMP TABLE _modeles (title text, body text, category text) ON COMMIT DROP;

INSERT INTO _modeles (title, body, category) VALUES
('Accusé de réception',
 E'Bonjour [prénom],\n\nNous avons bien reçu votre demande et nous vous remercions de nous avoir écrit. Un membre de l''équipe la prend en charge et reviendra vers vous dès qu''il aura une réponse.\n\nCordialement,\nL''équipe Diaspo Niger',
 'other'),
('Demande d''informations complémentaires',
 E'Bonjour [prénom],\n\nPour avancer sur votre demande, il nous manque quelques précisions : [précisions attendues].\n\nMerci de répondre directement à ce message. Ne nous envoyez ni mot de passe, ni code reçu par SMS, ni photo d''une pièce d''identité : nous ne vous les demanderons jamais.\n\nCordialement,\nL''équipe Diaspo Niger',
 'other'),
('Connexion impossible : premières vérifications',
 E'Bonjour [prénom],\n\nVoici quelques vérifications pour retrouver l''accès à votre compte :\n1. Assurez-vous d''utiliser la dernière version de l''application.\n2. Utilisez « Mot de passe oublié » sur l''écran de connexion pour recevoir un lien de réinitialisation.\n3. Vérifiez vos courriers indésirables si le message n''arrive pas.\n4. Fermez puis rouvrez complètement l''application.\n\nSi le problème continue, répondez-nous en indiquant le modèle de votre téléphone et le message affiché à l''écran.\n\nCordialement,\nL''équipe Diaspo Niger',
 'account'),
('Compte suspendu : information',
 E'Bonjour [prénom],\n\nVotre compte fait l''objet d''une mesure de modération. Cette décision a été prise au regard des règles de la communauté et n''est pas automatique : elle a été examinée par l''équipe.\n\nSi vous pensez qu''il s''agit d''une erreur, vous pouvez la contester en répondant à ce message et en expliquant votre situation. Votre demande sera examinée par une personne qui n''a pas pris la décision initiale.\n\nCordialement,\nL''équipe Diaspo Niger',
 'account'),
('Changement de pays ou de ville',
 E'Bonjour [prénom],\n\nVous pouvez modifier votre pays et votre ville depuis votre profil, dans les paramètres. Ces informations servent à vous proposer des groupes, des événements et des adresses proches de vous.\n\nSi l''option ne s''affiche pas ou si votre ville est absente de la liste, répondez-nous avec le nom de la ville : nous étudierons son ajout.\n\nCordialement,\nL''équipe Diaspo Niger',
 'account'),
('Notifications absentes : vérifications',
 E'Bonjour [prénom],\n\nSi vous ne recevez pas les notifications, vérifiez :\n1. Que les notifications de Diaspo Niger sont autorisées dans les réglages de votre téléphone.\n2. Que l''économie de batterie ne restreint pas l''application en arrière-plan.\n3. Que la catégorie concernée est activée dans Paramètres, puis Notifications, de l''application.\n\nSi tout est en ordre et que rien n''arrive, dites-nous quel type de notification manque et depuis quand.\n\nCordialement,\nL''équipe Diaspo Niger',
 'technical'),
('Problème technique : informations utiles',
 E'Bonjour [prénom],\n\nMerci de nous avoir signalé ce problème. Pour l''analyser, pouvez-vous nous indiquer :\n- ce que vous essayiez de faire,\n- ce qui s''est passé à la place (message affiché, écran figé…),\n- le modèle de votre téléphone et sa version d''Android ou d''iOS,\n- la version de l''application (dans Paramètres, À propos).\n\nUne capture d''écran qui ne montre aucune information personnelle nous aide beaucoup.\n\nCordialement,\nL''équipe Diaspo Niger',
 'technical'),
('Demande sur mes données : réception',
 E'Bonjour [prénom],\n\nNous avons bien reçu votre demande concernant vos données personnelles. Avant de la traiter, nous devons nous assurer qu''elle vient bien de vous : nous revenons vers vous avec la marche à suivre.\n\nNe nous envoyez pas de document d''identité à ce stade, et ne le transmettez que par le moyen que nous vous indiquerons.\n\nCordialement,\nL''équipe Diaspo Niger',
 'privacy'),
('Suppression du compte : information',
 E'Bonjour [prénom],\n\nLa suppression de votre compte se demande depuis l''application, dans les paramètres du compte. Un délai de réflexion s''applique : pendant ce délai, vous pouvez annuler la suppression en vous reconnectant.\n\nPassé ce délai, la suppression est définitive. Certaines copies techniques peuvent subsister pour une durée limitée, conformément à notre politique de confidentialité.\n\nCordialement,\nL''équipe Diaspo Niger',
 'privacy'),
('Réclamation : prise en compte',
 E'Bonjour [prénom],\n\nNous sommes désolés que votre expérience ne se soit pas passée comme prévu. Votre réclamation concernant [objet de la réclamation] a été enregistrée et sera examinée avec attention.\n\nNous reviendrons vers vous avec notre réponse, ou avec les questions qui nous manquent.\n\nCordialement,\nL''équipe Diaspo Niger',
 'complaint'),
('Contestation d''une décision : réception',
 E'Bonjour [prénom],\n\nNous avons bien reçu votre contestation. Elle sera examinée par un membre de l''équipe qui n''a pas participé à la décision initiale, à partir des éléments dont nous disposons et de ceux que vous nous avez transmis.\n\nVous recevrez la décision et ses motifs par ce même canal.\n\nCordialement,\nL''équipe Diaspo Niger',
 'appeal'),
('Fiche d''annuaire : vérification en cours',
 E'Bonjour [prénom],\n\nVotre fiche est en cours de vérification. Nous contrôlons les informations publiques (catégorie, adresse, coordonnées) et nous pouvons vous demander une source pour les confirmer.\n\nLe badge de vérification est attribué après ce contrôle ; il ne s''obtient pas par un paiement.\n\nCordialement,\nL''équipe Diaspo Niger',
 'directory'),
('Sécurité du compte : conseils',
 E'Bonjour [prénom],\n\nSi vous pensez que votre compte a été utilisé par quelqu''un d''autre, changez immédiatement votre mot de passe depuis « Mot de passe oublié » et déconnectez les autres appareils si l''application le propose.\n\nL''équipe Diaspo Niger ne vous demande jamais votre mot de passe, ni un code reçu par SMS ou par e-mail. Ne les communiquez à personne, y compris à quelqu''un qui se présente comme un membre de l''équipe.\n\nCordialement,\nL''équipe Diaspo Niger',
 'security'),
('Clôture : problème résolu',
 E'Bonjour [prénom],\n\nNous considérons votre demande comme résolue. Si le problème réapparaît, répondez simplement à ce message : nous rouvrirons votre dossier.\n\nMerci de votre patience.\n\nCordialement,\nL''équipe Diaspo Niger',
 'other');

-- Garde : aucun contenu privé dans un texte de modèle.
DO $$
DECLARE m record;
BEGIN
  FOR m IN
    SELECT title FROM _modeles
     WHERE body ~* '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}'     -- adresse e-mail
        OR body ~  '(\+|00)?[0-9][0-9 .()-]{8,}[0-9]'                    -- numéro de téléphone
        OR body ~* '(https?://|www\.)'                                    -- lien
        OR length(btrim(body)) > 4000 OR length(btrim(title)) > 120
  LOOP
    RAISE EXCEPTION 'modèle « % » : contenu refusé (e-mail, téléphone, lien ou longueur)', m.title;
  END LOOP;
END $$;

INSERT INTO public.support_reply_templates (title, body, category, created_by)
SELECT m.title, m.body, m.category, 'seed'
  FROM _modeles m
 WHERE NOT EXISTS (SELECT 1 FROM public.support_reply_templates t WHERE t.title = m.title);

SELECT count(*) AS modeles_au_total,
       count(*) FILTER (WHERE created_by = 'seed') AS poses_par_ce_script
  FROM public.support_reply_templates;

COMMIT;
