import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:diaspo_niger/l10n/app_localizations.dart';

import '../../../legal/presentation/providers/legal_provider.dart';
import '../../../legal/presentation/widgets/legal_essentials_card.dart';
import '../../../../core/theme/adaptive_colors.dart';
import '../../../../core/services/support_service.dart';

/// Onglet CGU (§26c), hébergé par `LegalDocumentsScreen` — plus d'écran ni
/// d'AppBar propres, ceux-ci sont partagés entre les 3 documents légaux.
class TermsScreen extends ConsumerWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final termsAsync = ref.watch(termsProvider);

    return termsAsync.when(
      data:
          (terms) => ListView(
            padding: const EdgeInsets.all(20),
            children: [
              LegalEssentialsCard(guarantees: _essentials(context)),
              ...terms.sections.map(
                (section) =>
                    _buildSection(context, section.title, section.content),
              ),
              const SizedBox(height: 20),
              Text(
                '${l10n.versionInfo(terms.version, _formatDate(terms.updatedAt))} · '
                '${legalReadingTimeLabel(terms.sections.map((s) => s.content), l10n)}',
                style: TextStyle(
                  fontSize: 12,
                  color: context.textTertiaryColor,
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              _buildContactFooter(context, ref, l10n),
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
            ref.watch(supportServiceProvider),
          ),
    );
  }

  List<String> _essentials(BuildContext context) {
    final isFrench = Localizations.localeOf(context).languageCode == 'fr';
    return isFrench
        ? const [
          'Vous gardez le contrôle de votre compte et de son contenu',
          'Vous pouvez supprimer votre compte à tout moment',
          'Un usage respectueux est requis de tous les membres',
        ]
        : const [
          'You keep control of your account and its content',
          'You can delete your account at any time',
          'Respectful use is required of all members',
        ];
  }

  Widget _buildContactFooter(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
  ) {
    return Center(
      child: OutlinedButton.icon(
        onPressed: () => ref.read(supportServiceProvider).sendContactEmail(),
        icon: const Icon(Icons.mail_outline, size: 18),
        label: Text(l10n.contactUs),
      ),
    );
  }

  String _formatDate(DateTime date) {
    const months = [
      'Janvier',
      'Février',
      'Mars',
      'Avril',
      'Mai',
      'Juin',
      'Juillet',
      'Août',
      'Septembre',
      'Octobre',
      'Novembre',
      'Décembre',
    ];
    return '${months[date.month - 1]} ${date.year}';
  }

  Widget _buildFallbackContent(
    BuildContext context,
    AppLocalizations l10n,
    SupportService supportService,
  ) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        LegalEssentialsCard(guarantees: _essentials(context)),
        _buildSection(
          context,
          'Bienvenue sur Diaspo Niger',
          'En utilisant notre application, vous acceptez les présentes conditions '
              'd\'utilisation. Veuillez les lire attentivement avant de continuer.',
        ),
        _buildSection(
          context,
          '1. Acceptation des conditions',
          'En accédant à Diaspo Niger ou en l\'utilisant, vous acceptez d\'être '
              'lié par ces conditions d\'utilisation. Si vous n\'acceptez pas ces '
              'conditions, veuillez ne pas utiliser l\'application.',
        ),
        _buildSection(
          context,
          '2. Description du service',
          'Diaspo Niger est une plateforme de mise en relation destinée aux '
              'membres de la diaspora nigérienne à travers le monde. L\'application '
              'permet de :\n\n'
              '- Créer un profil personnel\n'
              '- Rejoindre des groupes thématiques\n'
              '- Participer à des événements\n'
              '- Communiquer avec d\'autres membres\n'
              '- Localiser les membres de la diaspora sur une carte',
        ),
        _buildSection(
          context,
          '3. Inscription et compte',
          'Pour utiliser Diaspo Niger, vous devez créer un compte en fournissant '
              'des informations exactes et à jour. Vous êtes responsable de la '
              'confidentialité de vos identifiants de connexion et de toutes les '
              'activités effectuées sur votre compte.',
        ),
        _buildSection(
          context,
          '4. Règles de conduite',
          'En utilisant Diaspo Niger, vous vous engagez à :\n\n'
              '- Respecter les autres utilisateurs\n'
              '- Ne pas publier de contenu illégal, offensant ou inapproprié\n'
              '- Ne pas harceler ou intimider d\'autres membres\n'
              '- Ne pas usurper l\'identité d\'une autre personne\n'
              '- Ne pas utiliser l\'application à des fins commerciales non autorisées\n'
              '- Respecter les droits de propriété intellectuelle',
        ),
        _buildSection(
          context,
          '5. Contact',
          'Pour toute question concernant ces conditions d\'utilisation, '
              'contactez-nous à : ${supportService.supportEmail}',
        ),
        const SizedBox(height: 20),
        Text(
          'Dernière mise à jour : Décembre 2025',
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
