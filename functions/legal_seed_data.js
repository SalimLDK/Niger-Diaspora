/**
 * Legal Content Seed Data
 *
 * This file contains all legal documents for Diaspo Niger.
 * The content is structured for Firestore's legal_content collection.
 *
 * Documents comply with:
 * - Quebec Law 25 (Loi 25 sur la protection des renseignements personnels)
 * - GDPR (for European users)
 * - LPRPDE/PIPEDA (Canadian federal privacy law)
 *
 * Version: 1.1
 * Last Updated: January 2025
 */

const legalSeedData = {
    // ============================================================================
    // CONDITIONS GENERALES D'UTILISATION (Terms of Service)
    // ============================================================================
    terms: {
        id: "terms",
        type: "terms",
        title: "Conditions Generales d'Utilisation",
        version: "1.1",
        summary: "Mise a jour pour la conformite Loi 25 (Quebec) et RGPD",
        sections: [
            {
                title: "Preambule",
                content: `Les presentes Conditions Generales d'Utilisation (ci-apres "CGU") regissent l'acces et l'utilisation de l'application mobile Diaspo Niger et de l'ensemble des services associes (ci-apres "la Plateforme" ou "les Services").

La Plateforme est editee et exploitee par Diaspo Niger, societe par actions du Quebec.

Siege social : Montreal, Quebec, Canada
Email : contact@diasponiger.com

Hebergeur : Google Cloud Platform / Firebase (Google LLC, Mountain View, CA, Etats-Unis)`,
                order: 0
            },
            {
                title: "Article 1 - Definitions",
                content: `Dans les presentes CGU, les termes suivants ont la signification suivante :

- Utilisateur : Toute personne physique inscrite sur la Plateforme
- Compte : Espace personnel cree par l'Utilisateur sur la Plateforme
- Contenu : Tout element publie par un Utilisateur (texte, image, audio, video)
- Createur : Utilisateur proposant des contenus payants (podcasts, salons audio)
- Vendeur : Utilisateur proposant des produits ou services sur la Marketplace
- Acheteur : Utilisateur achetant des produits ou services sur la Marketplace
- Groupe : Communaute creee par des Utilisateurs autour d'un theme
- Evenement : Rassemblement organise via la Plateforme
- Salon Audio : Espace de discussion audio en direct
- Podcast : Contenu audio enregistre disponible a la demande
- Marketplace : Espace de vente entre Utilisateurs
- Transfert : Envoi d'argent vers un beneficiaire`,
                order: 1
            },
            {
                title: "Article 2 - Objet et Acceptation",
                content: `2.1 Objet

Les presentes CGU ont pour objet de definir les conditions d'acces et d'utilisation de la Plateforme Diaspo Niger, qui propose :
- Un reseau social pour la diaspora nigerienne
- Des services de messagerie et de communication
- Des groupes et evenements communautaires
- Une marketplace de produits et services
- Des services de transfert d'argent
- Une plateforme de podcasts et de salons audio
- Un annuaire d'entreprises et d'ambassades

2.2 Acceptation

L'utilisation de la Plateforme implique l'acceptation pleine et entiere des presentes CGU.

En creant un Compte, vous declarez :
- Avoir lu et compris les presentes CGU
- Les accepter sans reserve
- Etre juridiquement capable de vous engager
- Avoir au moins 16 ans

2.3 Documents Contractuels

Les presentes CGU sont completees par la Politique de Confidentialite et le Code de Conduite.`,
                order: 2
            },
            {
                title: "Article 3 - Acces a la Plateforme",
                content: `3.1 Conditions Techniques

L'acces a la Plateforme necessite :
- Un smartphone compatible (iOS 12+ ou Android 6+)
- Une connexion Internet
- Un numero de telephone valide
- Une adresse email valide

3.2 Disponibilite

Nous nous efforcons d'assurer une disponibilite de la Plateforme 24h/24 et 7j/7. Toutefois, l'acces peut etre interrompu pour :
- Maintenance technique (preventive ou corrective)
- Mises a jour de l'application
- Cas de force majeure
- Problemes techniques independants de notre volonte

Nous ne garantissons pas une disponibilite ininterrompue des Services.`,
                order: 3
            },
            {
                title: "Article 4 - Inscription et Compte",
                content: `4.1 Creation de Compte

Pour utiliser les Services, vous devez creer un Compte en fournissant :
- Une adresse email valide
- Un numero de telephone valide
- Un mot de passe securise
- Votre nom et prenom

Vous pouvez egalement vous inscrire via votre compte Google.

4.2 Veracite des Informations

Vous vous engagez a :
- Fournir des informations exactes et a jour
- Mettre a jour vos informations en cas de changement
- Ne pas usurper l'identite d'un tiers
- Utiliser votre veritable identite

Toute fausse declaration pourra entrainer la suspension ou la suppression de votre Compte.

4.3 Securite du Compte

Vous etes responsable de :
- La confidentialite de vos identifiants
- Toutes les activites effectuees depuis votre Compte
- Nous informer immediatement en cas d'utilisation non autorisee

Nous vous recommandons d'utiliser un mot de passe unique et complexe.

4.4 Unicite du Compte

Chaque Utilisateur ne peut detenir qu'un seul Compte. La creation de comptes multiples est interdite, sauf autorisation expresse.`,
                order: 4
            },
            {
                title: "Article 5 - Services Proposes",
                content: `5.1 Services Gratuits

Les services suivants sont accessibles gratuitement :
- Profil : Creation et personnalisation de votre profil
- Messagerie : Conversations privees avec d'autres Utilisateurs
- Groupes : Creation et participation a des groupes communautaires
- Evenements : Creation et participation a des evenements
- Salons Audio : Participation aux salons audio publics gratuits
- Recherche : Recherche d'Utilisateurs, groupes, entreprises
- Annuaire : Consultation des entreprises et ambassades

5.2 Services Payants

Certains services sont payants :
- Marketplace : Vente et achat de produits (commission sur ventes)
- Transferts d'argent : Envoi d'argent vers le Niger (frais de transfert)
- Abonnements Createurs : Acces aux contenus premium (prix fixe par le Createur)
- Salons Audio Payants : Acces aux salons premium (prix fixe par l'organisateur)
- Boost Entreprise : Mise en avant d'une entreprise (tarif selon duree)`,
                order: 5
            },
            {
                title: "Article 6 - Regles d'Utilisation",
                content: `6.1 Obligations de l'Utilisateur

En utilisant la Plateforme, vous vous engagez a :

Respecter la legalite :
- Ne pas publier de contenus illicites
- Respecter les droits d'autrui (propriete intellectuelle, vie privee)
- Ne pas diffuser de contenus diffamatoires ou injurieux
- Ne pas promouvoir d'activites illegales

Respecter les autres Utilisateurs :
- Adopter un comportement respectueux
- Ne pas harceler ou menacer
- Ne pas discriminer
- Respecter le Code de Conduite

Respecter la Plateforme :
- Ne pas tenter de compromettre la securite
- Ne pas utiliser de robots ou scripts automatises
- Ne pas contourner les mesures de protection
- Ne pas creer de faux comptes

6.2 Interdictions

Contenus prohibes :
- Contenus a caractere pedopornographique
- Incitation a la haine ou a la violence
- Apologie du terrorisme
- Contenus pornographiques non signales
- Contenus violents extremes
- Desinformation deliberee
- Spam et publicite non autorisee

Comportements prohibes :
- Usurpation d'identite
- Harcelement sous toutes ses formes
- Escroquerie et fraude
- Blanchiment d'argent
- Manipulation de la Plateforme`,
                order: 6
            },
            {
                title: "Article 7 - Contenus des Utilisateurs",
                content: `7.1 Responsabilite des Contenus

Vous etes seul responsable des Contenus que vous publiez sur la Plateforme.

Diaspo Niger agit en qualite d'hebergeur et n'exerce pas de controle editorial prealable sur les Contenus.

7.2 Licence Accordee

En publiant un Contenu, vous accordez a Diaspo Niger une licence non exclusive, mondiale, gratuite et transferable pour :
- Heberger et stocker le Contenu
- Le reproduire et l'afficher sur la Plateforme
- Le distribuer aux autres Utilisateurs
- Le modifier techniquement (format, compression)

Cette licence est accordee pour la duree de presence du Contenu sur la Plateforme et prend fin a sa suppression.

7.3 Propriete des Contenus

Vous conservez l'entiere propriete intellectuelle de vos Contenus. Diaspo Niger ne revendique aucun droit de propriete sur vos creations.`,
                order: 7
            },
            {
                title: "Article 8 - Marketplace",
                content: `8.1 Fonctionnement

La Marketplace permet aux Utilisateurs de vendre et d'acheter des produits et services. Diaspo Niger agit en qualite d'intermediaire et n'est pas partie aux transactions.

8.2 Commission et Paiements

- Commission standard : 19% du prix de vente
- Commission artisanat : 10% du prix de vente
- Produits alimentaires : Exoneres de commission
- Paiement : Via Stripe (securise)
- Versement au Vendeur : Apres confirmation de reception

8.3 Systeme d'Escrow (Sequestre)

Pour proteger les parties :
1. L'Acheteur paie le prix
2. Les fonds sont conserves en sequestre
3. Le Vendeur expedie le produit
4. L'Acheteur confirme la reception
5. Les fonds sont liberes au Vendeur

8.4 Produits Interdits

Sont interdits a la vente : produits contrefaits, armes et munitions, drogues et substances illicites, produits voles, animaux vivants (sauf exceptions), produits dangereux, tout produit illegal.`,
                order: 8
            },
            {
                title: "Article 9 - Services de Paiement et Transferts",
                content: `9.1 Nature des Services

Diaspo Niger propose des services de transfert d'argent vers le Niger et d'autres pays, en partenariat avec des prestataires de services de paiement agrees.

Important : Diaspo Niger n'est pas un etablissement de paiement agree. Les services de paiement sont fournis par Stripe Payments.

9.2 Verification d'Identite (KYC)

Conformement aux obligations legales de lutte contre le blanchiment (LCB-FT) et aux exigences de FINTRAC/CANAFE, vous devez fournir :
- Une piece d'identite valide
- Un justificatif de domicile (selon montants)
- Des informations sur l'origine des fonds (selon montants)

9.3 Frais et Taux de Change

- Frais de transfert : Affiches avant confirmation
- Taux de change : Taux du marche + marge
- Frais bancaires destinataire : Variables selon le pays

Les frais sont clairement affiches avant toute validation de transfert.

9.4 Limites et Plafonds

Des plafonds de transfert s'appliquent conformement a la reglementation canadienne et internationale.`,
                order: 9
            },
            {
                title: "Article 10 - Economie des Createurs",
                content: `10.1 Statut de Createur

Les Createurs sont des Utilisateurs qui monetisent leurs contenus via :
- Des abonnements a leurs podcasts
- Des salons audio payants
- Des pourboires (tips) de leur audience

10.2 Revenus et Commission

- Abonnements : 20% commission Diaspo Niger, 80% part Createur
- Tickets salons payants : 20% commission, 80% Createur
- Pourboires : 20% commission, 80% Createur

10.3 Versements

- Frequence : Mensuelle
- Seuil minimum : 15 CAD / 10 EUR / 5 000 XOF
- Moyen : Virement bancaire (Stripe Connect)
- Delai : J+7 apres la fin du mois

10.4 Obligations Fiscales

Vous etes seul responsable de vos obligations fiscales au Canada et dans votre pays de residence :
- Declaration des revenus percus (T4A, Releve 1 au Quebec)
- Paiement des impots et cotisations
- Facturation si applicable`,
                order: 10
            },
            {
                title: "Article 11 - Propriete Intellectuelle",
                content: `11.1 Droits de Diaspo Niger

La Plateforme et ses elements (logo, nom, design, code, fonctionnalites) sont proteges par les droits de propriete intellectuelle.

Sont la propriete exclusive de Diaspo Niger :
- La marque "Diaspo Niger" et le logo
- Le design et l'interface de l'application
- Le code source et les algorithmes
- Les bases de donnees (structure)

11.2 Licence d'Utilisation

Nous vous accordons une licence personnelle, non exclusive, non transferable et revocable pour utiliser la Plateforme conformement aux presentes CGU.

Cette licence ne vous autorise pas a :
- Copier ou reproduire la Plateforme
- Modifier ou creer des oeuvres derivees
- Desassembler ou decompiler le code
- Utiliser la marque Diaspo Niger`,
                order: 11
            },
            {
                title: "Article 12 - Donnees Personnelles",
                content: `Le traitement de vos donnees personnelles est regi par notre Politique de Confidentialite, qui fait partie integrante des presentes CGU.

Points cles :
- Responsable du traitement : Diaspo Niger
- Responsable vie privee (Quebec) : privacy@diasponiger.com
- DPO (Union Europeenne) : dpo@diasponiger.com
- Droits : acces, rectification, effacement, portabilite

Lois applicables :
- Loi 25 du Quebec sur la protection des renseignements personnels
- LPRPDE/PIPEDA (loi federale canadienne)
- RGPD (pour les utilisateurs de l'Union Europeenne)

Reclamations :
- Quebec : Commission d'acces a l'information (CAI) - cai.gouv.qc.ca
- Canada : Commissariat a la protection de la vie privee - priv.gc.ca
- France : CNIL - cnil.fr`,
                order: 12
            },
            {
                title: "Article 13 - Responsabilites",
                content: `13.1 Responsabilite de Diaspo Niger

En tant qu'hebergeur, Diaspo Niger n'est pas responsable des Contenus publies par les Utilisateurs, sous reserve de retirer promptement les contenus manifestement illicites signales.

Limites de responsabilite :
- Nous ne garantissons pas la disponibilite ininterrompue des Services
- Nous ne sommes pas responsables des dommages indirects
- Notre responsabilite est limitee aux montants percus dans les 12 derniers mois

Exclusions : Force majeure, fait d'un tiers, faute de l'Utilisateur

13.2 Responsabilite des Utilisateurs

Vous etes responsable de :
- Vos Contenus et leur legalite
- Vos transactions sur la Marketplace
- L'utilisation de votre Compte
- Les dommages causes a Diaspo Niger ou a des tiers`,
                order: 13
            },
            {
                title: "Article 14 - Moderation et Sanctions",
                content: `14.1 Moderation

Diaspo Niger met en oeuvre des mesures de moderation pour garantir le respect des presentes CGU :
- Moderation automatique (filtres, IA)
- Moderation humaine (equipe dediee)
- Moderation communautaire (signalements)

14.2 Echelle des Sanctions

- Mineure : Avertissement (premier manquement mineur)
- Moderee : Suspension temporaire 1-30 jours (recidive, contenu inapproprie)
- Grave : Suspension longue 30-90 jours (harcelement, fraude)
- Tres grave : Bannissement definitif (contenus illicites graves)

14.3 Recours

En cas de contestation d'une sanction :
1. Envoyez un email a : recours@diasponiger.com
2. Expliquez les raisons de votre contestation
3. Nous examinerons votre demande sous 15 jours
4. La decision vous sera notifiee par email`,
                order: 14
            },
            {
                title: "Article 15 - Modifications",
                content: `15.1 Modifications des Services

Nous pouvons modifier, suspendre ou interrompre tout ou partie des Services a tout moment. Pour les services payants, un preavis de 30 jours sera respecte sauf urgence technique.

15.2 Modifications des CGU

Nous pouvons modifier les presentes CGU. En cas de modification substantielle :
- Notification dans l'application
- Email aux Utilisateurs
- Delai de 30 jours avant entree en vigueur

Votre utilisation continue des Services apres modification vaut acceptation des nouvelles CGU.`,
                order: 15
            },
            {
                title: "Article 16 - Resiliation",
                content: `16.1 Resiliation par l'Utilisateur

Vous pouvez supprimer votre Compte a tout moment :
- Via Parametres > Compte > Supprimer mon compte
- Par email a : support@diasponiger.com

Effets de la suppression :
- Acces aux Services revoque
- Contenus supprimes (delai technique)
- Donnees conservees selon obligations legales
- Transactions en cours finalisees

16.2 Resiliation par Diaspo Niger

Nous pouvons resilier votre Compte :
- En cas de violation des CGU
- En cas de fraude averee
- En cas d'inactivite prolongee (24 mois)
- Pour tout motif legitime avec preavis de 30 jours`,
                order: 16
            },
            {
                title: "Article 17 - Mediation et Litiges",
                content: `17.1 Reglement Amiable

En cas de differend, nous vous invitons a nous contacter d'abord pour tenter de resoudre le probleme a l'amiable :
- Email : support@diasponiger.com
- Formulaire de contact dans l'application

17.2 Protection du Consommateur

Au Quebec, vous beneficiez de la protection de la Loi sur la protection du consommateur (LPC). Pour toute question ou plainte :
- Office de la protection du consommateur : opc.gouv.qc.ca

Pour les utilisateurs europeens, vous pouvez utiliser la plateforme europeenne de reglement en ligne des litiges : https://ec.europa.eu/consumers/odr

17.3 Juridiction Competente

A defaut de resolution amiable, les litiges seront soumis aux tribunaux competents du district judiciaire de Montreal, Quebec, Canada, sauf disposition legale contraire.

Droit applicable : Lois du Quebec et du Canada`,
                order: 17
            },
            {
                title: "Article 18 - Dispositions Generales",
                content: `18.1 Integralite

Les presentes CGU, ainsi que les documents auxquels elles font reference, constituent l'accord complet entre vous et Diaspo Niger.

18.2 Nullite Partielle

Si une disposition des CGU est declaree nulle ou inapplicable, les autres dispositions restent en vigueur.

18.3 Langue

Les presentes CGU sont redigees en francais. En cas de traduction, seule la version francaise fait foi, conformement a la Charte de la langue francaise du Quebec.

18.4 Contact

Pour toute question concernant ces CGU :

Diaspo Niger
Montreal, Quebec, Canada
Email : legal@diasponiger.com

Service Client :
Email : support@diasponiger.com
Dans l'application : Parametres > Aide > Nous contacter`,
                order: 18
            }
        ]
    },

    // ============================================================================
    // POLITIQUE DE CONFIDENTIALITE (Privacy Policy)
    // ============================================================================
    privacy: {
        id: "privacy",
        type: "privacy",
        title: "Politique de Confidentialite",
        version: "1.1",
        summary: "Double conformite Loi 25 (Quebec) et RGPD (Union Europeenne)",
        sections: [
            {
                title: "Introduction",
                content: `Votre vie privee est importante pour nous. Cette Politique de Confidentialite explique comment Diaspo Niger collecte, utilise, partage et protege vos renseignements personnels.

Cette politique est conforme a :
- La Loi 25 du Quebec sur la protection des renseignements personnels dans le secteur prive
- La Loi sur la protection des renseignements personnels et les documents electroniques (LPRPDE/PIPEDA)
- Le Reglement General sur la Protection des Donnees (RGPD) pour les utilisateurs europeens

Responsable du traitement :
Diaspo Niger
Montreal, Quebec, Canada
Email : privacy@diasponiger.com

Pour les utilisateurs de l'Union Europeenne :
Delegue a la Protection des Donnees (DPO) : dpo@diasponiger.com`,
                order: 0
            },
            {
                title: "1. Renseignements Collectes",
                content: `1.1 Renseignements que vous nous fournissez :

Informations de compte :
- Nom et prenom
- Adresse courriel
- Numero de telephone
- Photo de profil (optionnel)
- Ville de residence actuelle
- Region d'origine au Niger (optionnel)
- Profession (optionnel)
- Biographie (optionnel)

Informations de verification (KYC) :
- Piece d'identite
- Justificatif de domicile
- Informations bancaires (pour les createurs et vendeurs)

1.2 Renseignements collectes automatiquement :

- Adresse IP et donnees de connexion
- Type d'appareil et systeme d'exploitation
- Identifiants d'appareil
- Donnees d'utilisation de l'application
- Journaux de connexion

1.3 Renseignements de tiers :

- Informations de votre compte Google (si connexion Google)
- Donnees de verification via nos partenaires`,
                order: 1
            },
            {
                title: "2. Utilisation des Renseignements",
                content: `Nous utilisons vos renseignements pour :

Fourniture des services :
- Creer et gerer votre compte
- Permettre la communication entre membres
- Afficher votre position sur la carte (si active)
- Traiter vos transactions et transferts
- Gerer vos abonnements et paiements

Amelioration et securite :
- Ameliorer nos services
- Assurer la securite de la plateforme
- Prevenir la fraude et le blanchiment d'argent
- Respecter nos obligations legales

Communications :
- Envoyer des notifications pertinentes
- Vous informer des mises a jour importantes
- Repondre a vos demandes de support

Bases legales (RGPD - utilisateurs UE) :
- Execution du contrat
- Obligations legales (LCB-FT, fiscalite)
- Interets legitimes (securite, amelioration des services)
- Consentement (communications marketing)`,
                order: 2
            },
            {
                title: "3. Partage des Renseignements",
                content: `Nous partageons vos renseignements avec :

Autres utilisateurs (selon vos parametres) :
- Votre profil public
- Vos publications et contenus
- Votre position geographique (si activee)

Prestataires de services :
- Firebase/Google Cloud (hebergement)
- Stripe (paiements)
- Prestataires d'envoi de notifications

Autorites :
- Autorites fiscales (revenus des createurs/vendeurs)
- FINTRAC/CANAFE (conformite LCB-FT)
- Autorites judiciaires (sur ordonnance)

Nous ne vendons jamais vos donnees personnelles.

Transferts internationaux :
Vos donnees peuvent etre traitees aux Etats-Unis (Google, Stripe). Ces transferts sont encadres par des clauses contractuelles types ou d'autres mecanismes de transfert conformes.`,
                order: 3
            },
            {
                title: "4. Vos Droits",
                content: `Vous disposez des droits suivants sur vos renseignements personnels :

Droits communs (Loi 25 et RGPD) :
- Droit d'acces : Obtenir une copie de vos renseignements
- Droit de rectification : Corriger vos renseignements inexacts
- Droit a l'effacement : Demander la suppression de vos renseignements
- Droit a la portabilite : Recevoir vos renseignements dans un format structure

Droits specifiques RGPD (utilisateurs UE) :
- Droit d'opposition : Vous opposer a certains traitements
- Droit a la limitation : Limiter le traitement de vos renseignements
- Droit de retirer votre consentement a tout moment

Droits specifiques Loi 25 (utilisateurs Quebec) :
- Droit a la desindexation
- Droit a la cessation de la diffusion
- Droit d'etre informe en cas d'incident de confidentialite

Pour exercer vos droits :
- Dans l'app : Parametres > Confidentialite > Mes donnees
- Par courriel : privacy@diasponiger.com (Quebec/Canada) ou dpo@diasponiger.com (UE)
- Delai de reponse : 30 jours maximum`,
                order: 4
            },
            {
                title: "5. Conservation des Renseignements",
                content: `Nous conservons vos renseignements selon les durees suivantes :

Compte actif :
- Renseignements de profil : Duree du compte
- Messages : Duree du compte (suppression possible)
- Contenus publies : Duree du compte

Apres suppression du compte :
- Renseignements de base : 30 jours (periode de grace)
- Donnees de transaction : 7 ans (obligations fiscales)
- Journaux de securite : 1 an
- Donnees KYC : 5 ans apres la fin de la relation (obligation LCB-FT)

Comptes inactifs :
- Notification apres 12 mois d'inactivite
- Suppression automatique apres 24 mois (sauf obligations legales)`,
                order: 5
            },
            {
                title: "6. Securite",
                content: `Nous mettons en oeuvre des mesures de securite appropriees pour proteger vos renseignements :

Mesures techniques :
- Chiffrement des donnees en transit (TLS/SSL)
- Chiffrement des donnees au repos
- Chiffrement de bout en bout pour les messages prives
- Authentification a deux facteurs disponible
- Surveillance des acces et des anomalies

Mesures organisationnelles :
- Acces limite aux employes autorises
- Formation a la protection des donnees
- Politique de securite interne
- Evaluations de securite regulieres

En cas d'incident de confidentialite :
Conformement a la Loi 25 et au RGPD, nous vous notifierons dans les meilleurs delais si un incident presente un risque serieux de prejudice pour vous.`,
                order: 6
            },
            {
                title: "7. Temoins (Cookies)",
                content: `Nous utilisons des temoins et technologies similaires pour :

Temoins essentiels (toujours actifs) :
- Authentification et securite
- Preferences de langue
- Fonctionnement de base de l'app

Temoins analytiques (avec consentement) :
- Firebase Analytics : Comprendre l'utilisation de l'app
- Mesure de performance

Temoins marketing (avec consentement) :
- Non utilises actuellement

Gestion des temoins :
Vous pouvez gerer vos preferences de temoins dans :
Parametres > Confidentialite > Temoins et traceurs

Pour les utilisateurs UE, une banniere de consentement s'affiche au premier lancement.`,
                order: 7
            },
            {
                title: "8. Mineurs",
                content: `Diaspo Niger est destine aux personnes de 16 ans et plus.

Nous ne collectons pas sciemment de renseignements aupres de personnes de moins de 16 ans. Si vous etes parent ou tuteur et que vous pensez que votre enfant nous a fourni des renseignements personnels, contactez-nous a privacy@diasponiger.com.

Pour les utilisateurs de 16 a 18 ans, nous recommandons l'accompagnement d'un parent ou tuteur.`,
                order: 8
            },
            {
                title: "9. Modifications",
                content: `Nous pouvons modifier cette Politique de Confidentialite.

En cas de modification substantielle :
- Notification dans l'application
- Courriel aux utilisateurs
- Delai de 30 jours avant entree en vigueur

Vous pouvez consulter l'historique des versions dans l'application.

Votre utilisation continue apres notification vaut acceptation des modifications.`,
                order: 9
            },
            {
                title: "10. Contact et Reclamations",
                content: `Pour toute question ou demande concernant vos renseignements personnels :

Responsable vie privee (Quebec/Canada) :
Email : privacy@diasponiger.com

Delegue a la Protection des Donnees (UE) :
Email : dpo@diasponiger.com

Support general :
Email : support@diasponiger.com
Dans l'app : Parametres > Aide > Nous contacter

Autorites de controle :

Quebec :
Commission d'acces a l'information du Quebec (CAI)
cai.gouv.qc.ca

Canada :
Commissariat a la protection de la vie privee du Canada
priv.gc.ca

France :
Commission Nationale de l'Informatique et des Libertes (CNIL)
cnil.fr

Belgique :
Autorite de protection des donnees (APD)
dataprotectionauthority.be`,
                order: 10
            }
        ]
    },

    // ============================================================================
    // CODE DE CONDUITE (Code of Conduct)
    // ============================================================================
    conduct: {
        id: "conduct",
        type: "conduct",
        title: "Code de Conduite Communautaire",
        version: "1.0",
        summary: "Regles de vie commune pour une communaute respectueuse",
        sections: [
            {
                title: "Notre Vision",
                content: `Diaspo Niger est une plateforme communautaire concue pour connecter les Nigeriens du monde entier. Notre mission est de creer un espace bienveillant, respectueux et inclusif ou chaque membre peut :

- Se connecter avec sa communaute
- Echanger librement et respectueusement
- Partager sa culture et ses traditions
- Developper des opportunites professionnelles
- Maintenir des liens avec le pays d'origine

Ce Code de Conduite definit les comportements attendus pour maintenir cet environnement positif.`,
                order: 0
            },
            {
                title: "Nos Valeurs Fondamentales",
                content: `1. Respect (Mutunci)
Traiter chaque membre avec dignite, quel que soit son origine, sa region, son statut ou ses opinions.

2. Solidarite (Taimako)
Entraide et soutien mutuel au sein de la diaspora, dans l'esprit de la communaute nigerienne.

3. Authenticite (Gaskiya)
Etre vrai et sincere dans ses interactions, sans tromperie ni manipulation.

4. Diversite (Bambancin)
Celebrer la richesse de nos differences regionales, ethniques et culturelles.

5. Responsabilite (Nauyi)
Assumer la responsabilite de ses paroles et de ses actes sur la plateforme.`,
                order: 1
            },
            {
                title: "Comportements Attendus",
                content: `Dans les Conversations et Messages :
- Communication respectueuse : Utiliser un langage poli et constructif
- Ecoute active : Considerer les points de vue differents
- Debat constructif : Argumenter sur les idees, pas sur les personnes
- Bienveillance : Accueillir les nouveaux membres
- Entraide : Repondre aux questions et partager ses connaissances

Dans les Groupes et Communautes :
- Contribution positive : Partager du contenu pertinent et utile
- Respect du theme : Rester dans le sujet du groupe
- Moderation : Aider a maintenir un environnement sain
- Inclusion : Integrer tous les membres, meme les moins actifs

Dans les Salons Audio :
- Prise de parole ordonnee : Lever la main et attendre son tour
- Ecoute respectueuse : Ne pas interrompre les autres
- Moderation du ton : Eviter les eclats de voix et l'agressivite
- Respect du temps : Ne pas monopoliser la parole

Sur la Marketplace :
- Honnetete : Decrire fidelement les produits
- Communication claire : Repondre aux questions des acheteurs
- Respect des engagements : Livrer dans les delais annonces
- Resolution amiable : Gerer les problemes de maniere constructive`,
                order: 2
            },
            {
                title: "Comportements Interdits - Tolerance Zero",
                content: `Les comportements suivants entrainent un bannissement immediat :

- Exploitation des mineurs : Tout contenu ou comportement impliquant des mineurs de maniere inappropriee
- Terrorisme : Apologie, promotion ou organisation d'actes terroristes
- Traite des etres humains : Organisation ou promotion de la traite
- Vente de substances illicites : Drogues, medicaments detournes
- Menaces de mort : Menaces directes contre la vie d'une personne`,
                order: 3
            },
            {
                title: "Comportements Interdits - Sanctions Severes",
                content: `Ces comportements entrainent des sanctions severes (suspension ou bannissement) :

Harcelement et Intimidation :
- Harcelement moral : Messages repetes non sollicites, pression psychologique
- Harcelement sexuel : Avances non desirees, commentaires a caractere sexuel
- Cyberharcelement : Campagnes de denigrement, diffusion de rumeurs
- Intimidation : Menaces, chantage, pression
- Doxxing : Revelation d'informations personnelles sans consentement

Discrimination et Haine :
- Discrimination ethnique : Insultes ou moqueries basees sur l'ethnie ou la region
- Discrimination religieuse : Attaques contre les croyances religieuses
- Discrimination de genre : Sexisme, misogynie, homophobie
- Xenophobie : Rejet ou insultes envers d'autres nationalites
- Discours de haine : Propos visant a deshumaniser un groupe

Fraude et Tromperie :
- Escroquerie : Fausses promesses pour obtenir de l'argent
- Usurpation d'identite : Se faire passer pour quelqu'un d'autre
- Arnaques : Ventes frauduleuses, faux services
- Manipulation : Fausses informations pour manipuler les membres
- Phishing : Tentatives de vol d'identifiants

Contenus Inappropries :
- Pornographie : Contenus sexuellement explicites non signales
- Violence graphique : Images ou videos de violence extreme
- Gore : Contenus montrant des blessures graves, mutilations
- Desinformation : Fausses informations presentees comme vraies
- Spam : Messages repetitifs, publicite non sollicitee`,
                order: 4
            },
            {
                title: "Regles des Salons de Ceremonie",
                content: `Ces espaces meritent un respect particulier :

Mariages :
- Felicitations sinceres, joie partagee, respect de l'intimite

Baptemes :
- Bienveillance envers les nouveaux parents

Deuils :
- Condoleances respectueuses, soutien, pas de conflits

Ceremonies religieuses :
- Respect des pratiques, pas de proselytisme

Comportements interdits dans ces espaces :
- Commentaires deplaces ou irrespectueux
- Conflits familiaux exposes publiquement
- Demandes d'argent non sollicitees
- Enregistrements non autorises`,
                order: 5
            },
            {
                title: "Echelle des Sanctions",
                content: `Niveau 1 - Avertissement :
Premier manquement mineur

Niveau 2 - Restriction temporaire (24-72h) :
Recidive, propos inappropries

Niveau 3 - Suspension courte (7-14 jours) :
Harcelement leger, fraude mineure

Niveau 4 - Suspension longue (30-90 jours) :
Harcelement grave, recidive

Niveau 5 - Bannissement definitif :
Violations graves, multirecidive`,
                order: 6
            },
            {
                title: "Signalement et Recours",
                content: `Comment signaler :
1. Dans l'application : Bouton "Signaler" sur chaque contenu/profil
2. Par courriel : moderation@diasponiger.com
3. Formulaire : Parametres > Aide > Signaler un probleme

Delais de traitement :
- Urgences (menaces, exploitation mineurs) : < 1 heure
- Harcelement, fraude : < 24 heures
- Contenus inappropries : < 48 heures
- Autres signalements : < 7 jours

Droit de recours :
Si vous contestez une sanction :
1. Delai : 15 jours apres notification
2. Courriel : recours@diasponiger.com
3. Contenu : Explication detaillee, preuves eventuelles
4. Delai de reponse : 15 jours ouvres`,
                order: 7
            },
            {
                title: "Engagement Mutuel",
                content: `Notre engagement envers vous :
- Appliquer ce Code de facon equitable
- Repondre aux signalements rapidement
- Proteger votre vie privee
- Ameliorer continuellement nos outils de moderation
- Ecouter vos retours

Votre engagement envers la communaute :
- Respecter ce Code de Conduite
- Traiter les autres avec respect
- Signaler les comportements problematiques
- Contribuer positivement a la communaute
- Accepter les decisions de moderation

Ensemble, construisons une communaute dont nous pouvons etre fiers.

"Hadin kai yana kawo nasara" - L'union fait la force`,
                order: 8
            },
            {
                title: "Contact",
                content: `Questions sur ce Code :
- Courriel : conduct@diasponiger.com
- Dans l'application : Parametres > Aide > Code de Conduite

Signalements :
- Courriel : moderation@diasponiger.com
- Bouton "Signaler" dans l'application

Fraude/arnaque :
- Courriel : fraude@diasponiger.com

Support general :
- Courriel : support@diasponiger.com`,
                order: 9
            }
        ]
    }
};

module.exports = legalSeedData;
