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
 'other'),
('Signalement reçu : remerciement',
 E'Bonjour [prénom],\n\nMerci d''avoir pris le temps de nous signaler ce contenu. Votre signalement a été enregistré et sera examiné par l''équipe de modération au regard des règles de la communauté.\n\nPar respect de la vie privée de chacun, nous ne détaillons pas les mesures prises à l''encontre d''un membre. Nous vous informerons si votre signalement appelle une suite de votre côté.\n\nCordialement,\nL''équipe Diaspo Niger',
 'complaint'),
('Signalement : aucune infraction constatée',
 E'Bonjour [prénom],\n\nNous avons examiné votre signalement. Au regard des règles de la communauté, le contenu concerné ne les enfreint pas, et aucune mesure n''a été prise.\n\nSi vous disposez d''éléments nouveaux, vous pouvez nous les transmettre en répondant à ce message. Vous pouvez aussi masquer ou bloquer le membre concerné depuis son profil.\n\nCordialement,\nL''équipe Diaspo Niger',
 'complaint'),
('Harcèlement ou menaces : mise en sécurité',
 E'Bonjour [prénom],\n\nNous sommes désolés de ce que vous traversez. En attendant l''examen de votre signalement, vous pouvez bloquer le membre concerné depuis son profil : il ne pourra plus vous écrire.\n\nSi vous craignez pour votre sécurité, contactez les services d''urgence de votre pays. Conservez les éléments utiles (captures d''écran, dates) : ils nous aideront à traiter votre dossier.\n\nCordialement,\nL''équipe Diaspo Niger',
 'security'),
('Tentative d''arnaque : conseils',
 E'Bonjour [prénom],\n\nMerci de nous avoir alertés. Quelques réflexes : ne versez jamais d''argent à une personne que vous n''avez pas rencontrée, méfiez-vous des offres trop avantageuses ou pressantes, et ne communiquez jamais vos codes de connexion ou de paiement.\n\nNous avons enregistré votre signalement pour examen. Vous pouvez aussi bloquer le compte concerné depuis son profil.\n\nCordialement,\nL''équipe Diaspo Niger',
 'security'),
('Messages privés : ce que le support consulte',
 E'Bonjour [prénom],\n\nLe support n''a pas besoin de lire vos conversations privées et n''y accède pas pour traiter votre demande. Pour examiner un signalement, nous nous appuyons uniquement sur les éléments que vous choisissez de nous transmettre.\n\nSi vous rencontrez un problème d''envoi ou d''affichage, décrivez-nous ce que vous voyez, sans recopier le contenu de vos conversations.\n\nCordialement,\nL''équipe Diaspo Niger',
 'privacy'),
('Localisation : comment la gérer',
 E'Bonjour [prénom],\n\nLe partage de votre position est facultatif et se règle depuis les paramètres de l''application. Vous pouvez le désactiver à tout moment, et la position partagée n''est visible que selon vos réglages de confidentialité.\n\nSi vous souhaitez ne plus apparaître sur la carte, désactivez le partage dans les paramètres, puis dites-nous si votre position apparaît encore.\n\nCordialement,\nL''équipe Diaspo Niger',
 'privacy'),
('Événement : organisation et signalement',
 E'Bonjour [prénom],\n\nMerci pour votre message concernant l''événement [nom de l''événement]. Les informations d''un événement (date, lieu, annulation) sont de la responsabilité de son organisateur ; vous pouvez le contacter depuis la page de l''événement.\n\nSi l''événement vous semble contraire aux règles de la communauté, utilisez « Signaler » sur sa page : l''équipe l''examinera.\n\nCordialement,\nL''équipe Diaspo Niger',
 'other'),
('Groupe : rôles et exclusion',
 E'Bonjour [prénom],\n\nLes administrateurs d''un groupe en gèrent les membres et les règles. Si vous avez été retiré d''un groupe, c''est une décision de ses administrateurs : vous pouvez leur écrire pour en comprendre la raison.\n\nL''équipe Diaspo Niger n''intervient dans un groupe privé que pour faire respecter les règles de la communauté, à la suite d''un signalement.\n\nCordialement,\nL''équipe Diaspo Niger',
 'complaint'),
('Fiche d''annuaire : informations à corriger',
 E'Bonjour [prénom],\n\nPour corriger ou compléter votre fiche, modifiez-la depuis votre espace, puis elle sera vérifiée de nouveau. Si une information publique est erronée (horaires, adresse, coordonnées), dites-nous laquelle et indiquez une source qui permet de la confirmer.\n\nCordialement,\nL''équipe Diaspo Niger',
 'directory'),
('Fiche d''annuaire : refus de vérification',
 E'Bonjour [prénom],\n\nNous n''avons pas pu vérifier votre fiche pour le moment : [motif]. Vous pouvez la corriger puis nous écrire pour demander un nouvel examen.\n\nLa vérification porte sur l''exactitude des informations publiques ; elle ne juge pas la qualité des services proposés.\n\nCordialement,\nL''équipe Diaspo Niger',
 'directory'),
('Informations consulaires : à vérifier auprès de la source officielle',
 E'Bonjour [prénom],\n\nLes informations sur les démarches consulaires affichées dans l''application sont fournies à titre d''aide et peuvent évoluer. Avant toute démarche, vérifiez-les auprès de l''ambassade ou du consulat concerné.\n\nSi vous constatez une information erronée ou dépassée, dites-nous laquelle : nous la ferons vérifier à la source.\n\nCordialement,\nL''équipe Diaspo Niger',
 'directory'),
('Pièce jointe ou photo : envoi impossible',
 E'Bonjour [prénom],\n\nSi l''envoi d''une photo ou d''un fichier échoue, vérifiez :\n1. Votre connexion internet (essayez en Wi-Fi).\n2. Que l''application est autorisée à accéder à vos photos ou à l''appareil photo dans les réglages du téléphone.\n3. Que le fichier n''est pas trop volumineux.\n4. Que l''application est à jour.\n\nSi cela ne suffit pas, indiquez le type de fichier et le message d''erreur affiché.\n\nCordialement,\nL''équipe Diaspo Niger',
 'technical'),
('Mise à jour de l''application',
 E'Bonjour [prénom],\n\nCertains problèmes sont corrigés dans les nouvelles versions. Mettez l''application à jour depuis le Play Store ou l''App Store, puis relancez-la complètement.\n\nSi le problème persiste après la mise à jour, répondez-nous en indiquant la version de l''application et le modèle de votre téléphone.\n\nCordialement,\nL''équipe Diaspo Niger',
 'technical'),
('Suggestion : prise en compte',
 E'Bonjour [prénom],\n\nMerci pour votre suggestion. Elle a été transmise à l''équipe. Nous ne pouvons pas promettre qu''elle sera retenue ni à quelle date, mais les retours des membres orientent nos priorités.\n\nCordialement,\nL''équipe Diaspo Niger',
 'other'),
('Demande hors du périmètre du support',
 E'Bonjour [prénom],\n\nMerci de votre message. Cette demande concerne [sujet] et ne relève pas du support de Diaspo Niger : nous ne pouvons pas y répondre directement. Nous vous conseillons de vous adresser à [organisme ou service compétent].\n\nCordialement,\nL''équipe Diaspo Niger',
 'other'),
('Doublon de demande',
 E'Bonjour [prénom],\n\nNous avons déjà une demande ouverte de votre part sur ce sujet. Pour éviter de la traiter deux fois, nous poursuivons l''échange sur la première : vous n''avez rien à refaire.\n\nCordialement,\nL''équipe Diaspo Niger',
 'other'),
('Sans réponse de votre part : clôture prochaine',
 E'Bonjour [prénom],\n\nNous n''avons pas reçu de réponse à notre dernier message. Si votre problème est toujours d''actualité, répondez-nous : nous reprendrons votre dossier là où nous l''avions laissé.\n\nSans nouvelles de votre part, nous clôturerons la demande. Vous pourrez la rouvrir à tout moment en nous écrivant.\n\nCordialement,\nL''équipe Diaspo Niger',
 'other'),
('Compte supprimé : confirmation',
 E'Bonjour [prénom],\n\nNous vous confirmons que la suppression de votre compte a été traitée. Vos informations de profil ne sont plus visibles dans l''application ; certaines copies techniques peuvent subsister pour une durée limitée, conformément à notre politique de confidentialité.\n\nSi vous souhaitez revenir, vous pourrez créer un nouveau compte.\n\nCordialement,\nL''équipe Diaspo Niger',
 'privacy'),
('Contestation : décision confirmée',
 E'Bonjour [prénom],\n\nVotre contestation a été examinée par un membre de l''équipe qui n''avait pas participé à la décision initiale. Après examen, la décision est confirmée pour le motif suivant : [motif].\n\nCette réponse clôt la procédure de contestation. Nous vous remercions d''avoir exposé votre situation.\n\nCordialement,\nL''équipe Diaspo Niger',
 'appeal'),
('Contestation : décision modifiée',
 E'Bonjour [prénom],\n\nVotre contestation a été examinée par un membre de l''équipe qui n''avait pas participé à la décision initiale. Après examen, la décision est modifiée : [mesure retenue].\n\nNous vous remercions d''avoir exposé votre situation et vous prions de nous excuser pour la gêne occasionnée.\n\nCordialement,\nL''équipe Diaspo Niger',
 'appeal');

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
