import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../legal/presentation/providers/legal_provider.dart';
import '../../../../core/theme/adaptive_colors.dart';

class TermsScreen extends ConsumerWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final termsAsync = ref.watch(termsProvider);

    return Scaffold(
      backgroundColor: context.backgroundColor,
      appBar: AppBar(
        title: const Text('Conditions d\'utilisation'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: termsAsync.when(
        data:
            (terms) => ListView(
              padding: const EdgeInsets.all(20),
              children: [
                ...terms.sections.map(
                  (section) =>
                      _buildSection(context, section.title, section.content),
                ),
                const SizedBox(height: 20),
                Text(
                  'Version ${terms.version} - Dernière mise à jour : ${_formatDate(terms.updatedAt)}',
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
        error: (error, _) => _buildFallbackContent(context),
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

  Widget _buildFallbackContent(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _buildSection(
          context,
          'Bienvenue sur Niger Diaspora',
          'En utilisant notre application, vous acceptez les présentes conditions '
              'd\'utilisation. Veuillez les lire attentivement avant de continuer.',
        ),
        _buildSection(
          context,
          '1. Acceptation des conditions',
          'En accédant à Niger Diaspora ou en l\'utilisant, vous acceptez d\'être '
              'lié par ces conditions d\'utilisation. Si vous n\'acceptez pas ces '
              'conditions, veuillez ne pas utiliser l\'application.',
        ),
        _buildSection(
          context,
          '2. Description du service',
          'Niger Diaspora est une plateforme de mise en relation destinée aux '
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
          'Pour utiliser Niger Diaspora, vous devez créer un compte en fournissant '
              'des informations exactes et à jour. Vous êtes responsable de la '
              'confidentialité de vos identifiants de connexion et de toutes les '
              'activités effectuées sur votre compte.',
        ),
        _buildSection(
          context,
          '4. Règles de conduite',
          'En utilisant Niger Diaspora, vous vous engagez à :\n\n'
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
              'contactez-nous à : support@diasponiger.com',
        ),
        const SizedBox(height: 20),
        Text(
          'Dernière mise à jour : Décembre 2024',
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
