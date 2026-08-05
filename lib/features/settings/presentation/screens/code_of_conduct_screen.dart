import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:diaspo_niger/l10n/app_localizations.dart';

import '../../../legal/presentation/providers/legal_provider.dart';
import '../../../legal/presentation/widgets/legal_essentials_card.dart';
import '../../../../core/theme/adaptive_colors.dart';
import '../../../../core/services/support_service.dart';

/// Onglet Code de conduite (§26c), hébergé par `LegalDocumentsScreen` — plus
/// d'écran ni d'AppBar propres, ceux-ci sont partagés entre les 3 documents.
class CodeOfConductScreen extends ConsumerWidget {
  const CodeOfConductScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context);
    final conductAsync = ref.watch(codeOfConductProvider);

    return conductAsync.when(
      data:
          (conduct) => ListView(
            padding: const EdgeInsets.all(20),
            children: [
              LegalEssentialsCard(guarantees: _essentials(locale)),
              ...conduct.sections.map(
                (section) =>
                    _buildSection(context, section.title, section.content),
              ),
              const SizedBox(height: 20),
              Text(
                '${l10n.versionInfo(conduct.version, _formatDate(conduct.updatedAt, locale))} · '
                '${legalReadingTimeLabel(conduct.sections.map((s) => s.content), l10n)}',
                style: TextStyle(
                  fontSize: 12,
                  color: context.textTertiaryColor,
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              _buildContactFooter(ref, l10n),
              const SizedBox(height: 32),
            ],
          ),
      loading:
          () => Center(
            child: CircularProgressIndicator(
              color: context.adaptivePrimaryColor,
            ),
          ),
      error:
          (error, _) => _buildFallbackContent(
            context,
            l10n,
            locale,
            ref.watch(supportServiceProvider),
          ),
    );
  }

  List<String> _essentials(Locale locale) {
    final isFrench = locale.languageCode == 'fr';
    return isFrench
        ? const [
          'Respect et bienveillance obligatoires entre tous les membres',
          'Les signalements sont traités de façon confidentielle',
          'Sanctions graduées en cas de manquement (avertissement à suppression)',
        ]
        : const [
          'Respect and kindness are mandatory between all members',
          'Reports are handled confidentially',
          'Graduated sanctions for violations (warning to account deletion)',
        ];
  }

  Widget _buildContactFooter(WidgetRef ref, AppLocalizations l10n) {
    return Center(
      child: OutlinedButton.icon(
        onPressed: () => ref.read(supportServiceProvider).sendContactEmail(),
        icon: const Icon(Icons.mail_outline, size: 18),
        label: Text(l10n.contactUs),
      ),
    );
  }

  String _formatDate(DateTime date, Locale locale) {
    return DateFormat.yMMMM(locale.languageCode).format(date);
  }

  Widget _buildFallbackContent(
    BuildContext context,
    AppLocalizations l10n,
    Locale locale,
    SupportService supportService,
  ) {
    final isFrench = locale.languageCode == 'fr';
    final fallbackDate = DateTime(2025, 1, 1);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        LegalEssentialsCard(guarantees: _essentials(locale)),
        _buildSection(
          context,
          isFrench
              ? 'Bienvenue dans notre communaute'
              : 'Welcome to our community',
          isFrench
              ? 'Diaspo Niger est une plateforme de mise en relation pour la diaspora nigerienne. '
                  'Ce code de conduite definit les regles de vie commune pour garantir un espace '
                  'respectueux, securise et bienveillant pour tous les membres.'
              : 'Diaspo Niger is a networking platform for the Nigerien diaspora. '
                  'This code of conduct defines the community guidelines to ensure a respectful, '
                  'safe and welcoming space for all members.',
        ),
        _buildSection(
          context,
          isFrench ? '1. Respect et bienveillance' : '1. Respect and kindness',
          isFrench
              ? 'En tant que membre de la diaspora nigerienne, vous vous engagez a :\n\n'
                  '- Traiter tous les membres avec respect et dignite\n'
                  '- Valoriser la diversite des parcours et des opinions\n'
                  '- Communiquer de maniere constructive et courtoise\n'
                  '- Eviter tout propos discriminatoire base sur l\'origine, la religion, '
                  'le genre, l\'orientation sexuelle ou tout autre critere\n'
                  '- Respecter les differentes cultures et traditions representees'
              : 'As a member of the Nigerien diaspora, you commit to:\n\n'
                  '- Treat all members with respect and dignity\n'
                  '- Value diversity of backgrounds and opinions\n'
                  '- Communicate constructively and courteously\n'
                  '- Avoid any discriminatory remarks based on origin, religion, '
                  'gender, sexual orientation or any other criteria\n'
                  '- Respect the different cultures and traditions represented',
        ),
        _buildSection(
          context,
          isFrench
              ? '2. Communications et messagerie'
              : '2. Communications and messaging',
          isFrench
              ? 'Dans vos echanges via l\'application, vous devez :\n\n'
                  '- Ne pas envoyer de messages non sollicites ou de spam\n'
                  '- Ne pas harceler ou intimider d\'autres membres\n'
                  '- Ne pas partager de contenu a caractere sexuel ou violent\n'
                  '- Respecter le souhait des membres qui ne veulent pas etre contactes\n'
                  '- Ne pas partager les conversations privees sans consentement\n'
                  '- Signaler tout comportement inapproprie via le systeme de signalement'
              : 'In your exchanges via the application, you must:\n\n'
                  '- Not send unsolicited messages or spam\n'
                  '- Not harass or intimidate other members\n'
                  '- Not share sexual or violent content\n'
                  '- Respect members who do not wish to be contacted\n'
                  '- Not share private conversations without consent\n'
                  '- Report any inappropriate behavior through the reporting system',
        ),
        _buildSection(
          context,
          isFrench ? '3. Groupes et evenements' : '3. Groups and events',
          isFrench
              ? 'Lors de votre participation aux groupes et evenements :\n\n'
                  '- Respectez les regles specifiques de chaque groupe\n'
                  '- Contribuez de maniere positive aux discussions\n'
                  '- N\'utilisez pas les groupes a des fins de promotion personnelle non autorisee\n'
                  '- Honorez vos inscriptions aux evenements ou annulez a l\'avance\n'
                  '- Ne creez pas d\'evenements fictifs ou trompeurs\n'
                  '- Respectez les organisateurs et les autres participants'
              : 'When participating in groups and events:\n\n'
                  '- Respect the specific rules of each group\n'
                  '- Contribute positively to discussions\n'
                  '- Do not use groups for unauthorized self-promotion\n'
                  '- Honor your event registrations or cancel in advance\n'
                  '- Do not create fictitious or misleading events\n'
                  '- Respect organizers and other participants',
        ),
        _buildSection(
          context,
          isFrench
              ? '4. Marketplace et transactions'
              : '4. Marketplace and transactions',
          isFrench
              ? 'Pour les activites commerciales sur la plateforme :\n\n'
                  '- Decrivez vos produits et services de maniere honnete et precise\n'
                  '- N\'affichez pas de prix trompeurs\n'
                  '- Ne vendez pas de produits illegaux, contrefaits ou dangereux\n'
                  '- Respectez vos engagements de livraison et de qualite\n'
                  '- Repondez aux reclamations de maniere professionnelle\n'
                  '- Ne sollicitez pas d\'avis frauduleux'
              : 'For commercial activities on the platform:\n\n'
                  '- Describe your products and services honestly and accurately\n'
                  '- Do not display misleading prices\n'
                  '- Do not sell illegal, counterfeit or dangerous products\n'
                  '- Honor your delivery and quality commitments\n'
                  '- Respond to complaints professionally\n'
                  '- Do not solicit fraudulent reviews',
        ),
        _buildSection(
          context,
          isFrench ? '5. Transferts d\'argent' : '5. Money transfers',
          isFrench
              ? 'Concernant les fonctionnalites de transfert :\n\n'
                  '- Utilisez les transferts uniquement a des fins legales\n'
                  '- Ne participez pas a des activites de blanchiment d\'argent\n'
                  '- Verifiez l\'identite des destinataires avant d\'envoyer des fonds\n'
                  '- Signalez toute tentative de fraude ou d\'arnaque\n'
                  '- Protegez vos informations de paiement\n'
                  '- N\'utilisez pas la plateforme pour des transactions suspectes'
              : 'Regarding transfer features:\n\n'
                  '- Use transfers only for legal purposes\n'
                  '- Do not participate in money laundering activities\n'
                  '- Verify the identity of recipients before sending funds\n'
                  '- Report any attempted fraud or scam\n'
                  '- Protect your payment information\n'
                  '- Do not use the platform for suspicious transactions',
        ),
        _buildSection(
          context,
          isFrench
              ? '6. Entreprises et annuaires'
              : '6. Businesses and directories',
          isFrench
              ? 'Pour les professionnels et entreprises :\n\n'
                  '- Fournissez des informations exactes sur votre entreprise\n'
                  '- Ne revendiquez pas de fausses certifications ou qualifications\n'
                  '- Maintenez a jour vos horaires et coordonnees\n'
                  '- Repondez aux avis de maniere professionnelle\n'
                  '- Ne creez pas de faux profils d\'entreprise\n'
                  '- Respectez les regles de publicite de la plateforme'
              : 'For professionals and businesses:\n\n'
                  '- Provide accurate information about your business\n'
                  '- Do not claim false certifications or qualifications\n'
                  '- Keep your hours and contact information up to date\n'
                  '- Respond to reviews professionally\n'
                  '- Do not create fake business profiles\n'
                  '- Follow the platform\'s advertising rules',
        ),
        _buildSection(
          context,
          isFrench ? '7. Protection de la vie privee' : '7. Privacy protection',
          isFrench
              ? 'Respectez la vie privee des autres membres :\n\n'
                  '- Ne partagez pas les informations personnelles d\'autrui sans consentement\n'
                  '- N\'utilisez pas les donnees de localisation pour traquer quelqu\'un\n'
                  '- Respectez les parametres de confidentialite des membres\n'
                  '- Ne capturez pas d\'ecran des conversations privees\n'
                  '- Ne creez pas de faux profils ou n\'usurpez pas l\'identite d\'autrui'
              : 'Respect the privacy of other members:\n\n'
                  '- Do not share others\' personal information without consent\n'
                  '- Do not use location data to track someone\n'
                  '- Respect members\' privacy settings\n'
                  '- Do not screenshot private conversations\n'
                  '- Do not create fake profiles or impersonate others',
        ),
        _buildSection(
          context,
          isFrench ? '8. Contenu interdit' : '8. Prohibited content',
          isFrench
              ? 'Les contenus suivants sont strictement interdits :\n\n'
                  '- Incitation a la haine ou a la violence\n'
                  '- Propos diffamatoires ou calomnieux\n'
                  '- Pornographie ou contenu sexuellement explicite\n'
                  '- Apologie du terrorisme ou d\'activites criminelles\n'
                  '- Arnaques, phishing ou tentatives de fraude\n'
                  '- Violation des droits d\'auteur ou de propriete intellectuelle\n'
                  '- Fausses informations pouvant nuire a la communaute'
              : 'The following content is strictly prohibited:\n\n'
                  '- Incitement to hatred or violence\n'
                  '- Defamatory or slanderous remarks\n'
                  '- Pornography or sexually explicit content\n'
                  '- Glorification of terrorism or criminal activities\n'
                  '- Scams, phishing or fraud attempts\n'
                  '- Copyright or intellectual property violations\n'
                  '- Misinformation that could harm the community',
        ),
        _buildSection(
          context,
          isFrench
              ? '9. Signalement et moderation'
              : '9. Reporting and moderation',
          isFrench
              ? 'Notre systeme de moderation :\n\n'
                  '- Utilisez le bouton "Signaler" pour tout comportement inapproprie\n'
                  '- Les signalements sont traites de maniere confidentielle\n'
                  '- Ne faites pas de signalements abusifs ou malveillants\n'
                  '- Les faux signalements peuvent entrainer des sanctions\n'
                  '- Cooperez avec l\'equipe de moderation si necessaire'
              : 'Our moderation system:\n\n'
                  '- Use the "Report" button for any inappropriate behavior\n'
                  '- Reports are handled confidentially\n'
                  '- Do not make abusive or malicious reports\n'
                  '- False reports may result in sanctions\n'
                  '- Cooperate with the moderation team if necessary',
        ),
        _buildSection(
          context,
          isFrench ? '10. Sanctions' : '10. Sanctions',
          isFrench
              ? 'En cas de non-respect de ce code de conduite :\n\n'
                  '- Avertissement pour les infractions mineures\n'
                  '- Suspension temporaire du compte\n'
                  '- Restriction d\'acces a certaines fonctionnalites\n'
                  '- Suppression definitive du compte en cas de violations graves ou repetees\n'
                  '- Signalement aux autorites competentes si necessaire\n\n'
                  'Les decisions de moderation peuvent faire l\'objet d\'un appel '
                  'aupres de notre equipe support.'
              : 'In case of non-compliance with this code of conduct:\n\n'
                  '- Warning for minor infractions\n'
                  '- Temporary account suspension\n'
                  '- Restricted access to certain features\n'
                  '- Permanent account deletion for serious or repeated violations\n'
                  '- Reporting to competent authorities if necessary\n\n'
                  'Moderation decisions can be appealed to our support team.',
        ),
        _buildSection(
          context,
          isFrench ? '11. Contact' : '11. Contact',
          isFrench
              ? 'Pour toute question concernant ce code de conduite ou pour signaler '
                  'un probleme :\n\n'
                  'Email : ${supportService.moderationEmail}\n'
                  'Support : ${supportService.supportEmail}\n\n'
                  'Ensemble, construisons une communaute solidaire et respectueuse !'
              : 'For any questions about this code of conduct or to report an issue:\n\n'
                  'Email: ${supportService.moderationEmail}\n'
                  'Support: ${supportService.supportEmail}\n\n'
                  'Together, let\'s build a supportive and respectful community!',
        ),
        const SizedBox(height: 20),
        Text(
          l10n.versionInfo('1.0', _formatDate(fallbackDate, locale)),
          style: TextStyle(
            fontSize: 12,
            color: context.textTertiaryColor,
            fontStyle: FontStyle.italic,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        Center(
          child: OutlinedButton.icon(
            onPressed: () => supportService.sendContactEmail(),
            icon: const Icon(Icons.mail_outline, size: 18),
            label: Text(l10n.contactUs),
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildSection(BuildContext context, String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: context.textPrimaryColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: TextStyle(
              fontSize: 14,
              color: context.textSecondaryColor,
              height: 1.65,
            ),
          ),
        ],
      ),
    );
  }
}
