import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:diaspo_niger/l10n/app_localizations.dart';

import '../../../../core/theme/adaptive_colors.dart';
import '../../../settings/presentation/screens/code_of_conduct_screen.dart';
import '../../../settings/presentation/screens/privacy_policy_screen.dart';
import '../../../settings/presentation/screens/terms_screen.dart';

/// Les 3 documents légaux, présentés en onglets d'un même écran (§26c) au
/// lieu de 3 écrans séparés sans lien entre eux.
enum LegalTab { terms, privacy, conduct }

class LegalDocumentsScreen extends StatefulWidget {
  final LegalTab initialTab;

  const LegalDocumentsScreen({super.key, required this.initialTab});

  @override
  State<LegalDocumentsScreen> createState() => _LegalDocumentsScreenState();
}

class _LegalDocumentsScreenState extends State<LegalDocumentsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTab.index,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: context.backgroundColor,
      appBar: AppBar(
        title: Text(l10n.legalDocumentsTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: [
            Tab(text: l10n.termsOfService),
            Tab(text: l10n.privacyPolicy),
            Tab(text: l10n.codeOfConduct),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          TermsScreen(),
          PrivacyPolicyScreen(),
          CodeOfConductScreen(),
        ],
      ),
    );
  }
}
