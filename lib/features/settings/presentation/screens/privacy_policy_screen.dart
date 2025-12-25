import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:diaspo_niger/l10n/app_localizations.dart';

import '../../../legal/presentation/providers/legal_provider.dart';
import '../../../../core/theme/adaptive_colors.dart';

class PrivacyPolicyScreen extends ConsumerWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context);
    final privacyAsync = ref.watch(privacyPolicyProvider);

    return Scaffold(
      backgroundColor: context.backgroundColor,
      appBar: AppBar(
        title: Text(l10n.privacyPolicy),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: privacyAsync.when(
        data:
            (privacy) => ListView(
              padding: const EdgeInsets.all(20),
              children: [
                ...privacy.sections.map(
                  (section) =>
                      _buildSection(context, section.title, section.content),
                ),
                const SizedBox(height: 20),
                Text(
                  l10n.versionInfo(
                    privacy.version,
                    _formatDate(privacy.updatedAt, locale),
                  ),
                  style: TextStyle(
                    fontSize: 12,
                    color: context.textTertiaryColor,
                    fontStyle: FontStyle.italic,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
              ],
            ),
        loading:
            () => Center(
              child: CircularProgressIndicator(
                color: context.adaptivePrimaryColor,
              ),
            ),
        error: (error, _) => _buildFallbackContent(context, l10n, locale),
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
  ) {
    final fallbackDate = DateTime(2024, 12, 1);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _buildSection(
          context,
          'Introduction',
          'Votre vie privée est importante pour nous. Cette politique de '
              'confidentialité explique quelles données nous collectons, comment '
              'nous les utilisons et comment nous les protégeons.',
        ),
        _buildSection(
          context,
          '1. Données collectées',
          'Nous collectons les types de données suivants :\n\n'
              'Informations de compte :\n'
              '- Nom et prénom\n'
              '- Adresse email\n'
              '- Photo de profil (optionnel)\n'
              '- Ville de résidence actuelle\n'
              '- Profession (optionnel)\n'
              '- Biographie (optionnel)\n\n'
              'Données de localisation :\n'
              '- Position géographique (si vous activez cette fonctionnalité)\n\n'
              'Données d\'utilisation :\n'
              '- Événements auxquels vous participez\n'
              '- Groupes dont vous êtes membre\n'
              '- Messages envoyés dans l\'application',
        ),
        _buildSection(
          context,
          '2. Utilisation des données',
          'Vos données sont utilisées pour :\n\n'
              '- Créer et gérer votre compte\n'
              '- Vous permettre de communiquer avec d\'autres membres\n'
              '- Afficher votre position sur la carte (si activé)\n'
              '- Vous envoyer des notifications pertinentes\n'
              '- Améliorer notre service\n'
              '- Assurer la sécurité de la plateforme',
        ),
        _buildSection(
          context,
          '3. Vos droits',
          'Conformément au RGPD et aux lois applicables, vous disposez des droits suivants :\n\n'
              '- Droit d\'accès : demander une copie de vos données\n'
              '- Droit de rectification : corriger vos données inexactes\n'
              '- Droit à l\'effacement : supprimer votre compte et vos données\n'
              '- Droit à la portabilité : exporter vos données\n'
              '- Droit d\'opposition : vous opposer à certains traitements\n\n'
              'Pour exercer ces droits, contactez-nous à : privacy@diasponiger.com',
        ),
        _buildSection(
          context,
          '4. Contact',
          'Pour toute question concernant cette politique de confidentialité :\n\n'
              'Email : privacy@diasponiger.com\n'
              'Support : support@diasponiger.com',
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
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}
