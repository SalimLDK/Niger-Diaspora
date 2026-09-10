import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:diaspo_niger/l10n/app_localizations.dart';
import '../../../../core/theme/adaptive_colors.dart';
import '../../../../shared/widgets/app_icon.dart';
import '../providers/group_link_preview_provider.dart';
import '../providers/group_request_provider.dart';

/// Ce qu'on montre au bout d'un lien vers un groupe qu'on n'a pas le droit de
/// lire.
///
/// Avant, c'était une impasse : « Ce groupe est privé ou n'existe plus. » et un
/// bouton Retour. Décision de Salim le 2026-09-10 — celui qui reçoit le lien
/// doit pouvoir **demander à rejoindre**.
///
/// L'aperçu (`group_link_preview`, cf. `20260910060000`) ne rend que le nom,
/// l'avatar et le nombre de membres. Il permet aussi la seule distinction que
/// `getGroupById` ne sait pas faire : `null` = le groupe n'existe pas, une
/// ligne = il existe mais reste fermé.
class GroupLinkGate extends ConsumerStatefulWidget {
  final String groupId;

  const GroupLinkGate({super.key, required this.groupId});

  @override
  ConsumerState<GroupLinkGate> createState() => _GroupLinkGateState();
}

class _GroupLinkGateState extends ConsumerState<GroupLinkGate> {
  bool _envoi = false;
  bool _demandeEnvoyee = false;

  void _sortir() =>
      context.canPop() ? context.pop() : context.go('/home');

  Future<void> _demander(GroupLinkPreview apercu) async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _envoi = true);
    final ok = await ref
        .read(groupRequestNotifierProvider.notifier)
        .requestToJoin(
          groupId: apercu.id,
          groupName: apercu.name,
          groupImageUrl: apercu.avatarUrl,
        );
    if (!mounted) return;
    setState(() {
      _envoi = false;
      _demandeEnvoyee = ok;
    });

    // Le refus le plus courant n'est pas une panne : on est déjà membre, ou la
    // demande existe déjà. Le datasource le dit dans son message, on le relaie
    // tel quel plutôt que d'inventer une cause.
    final erreur = ref.read(groupRequestNotifierProvider).error;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok ? l10n.requestSent : (erreur?.toString() ?? l10n.loadingError),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final apercu = ref.watch(groupLinkPreviewProvider(widget.groupId));

    return Scaffold(
      backgroundColor: context.backgroundColor,
      appBar: AppBar(
        leading: IconButton(
          icon: const AppIcon(AppIcon.arrowBack),
          onPressed: _sortir,
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: apercu.when(
            loading: () => CircularProgressIndicator(
              color: context.adaptivePrimaryColor,
            ),
            // Un aperçu illisible ne doit pas faire un écran rouge : on
            // retombe sur le message d'origine, qui reste vrai.
            error: (_, __) => _impasse(context, l10n),
            data: (a) =>
                a == null ? _impasse(context, l10n) : _porte(context, l10n, a),
          ),
        ),
      ),
    );
  }

  Widget _impasse(BuildContext context, AppLocalizations l10n) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      AppIcon(AppIcon.error, size: 48, color: context.textSecondaryColor),
      const SizedBox(height: 16),
      Text(
        l10n.groupUnavailableOrPrivate,
        textAlign: TextAlign.center,
        style: TextStyle(color: context.textPrimaryColor),
      ),
      const SizedBox(height: 16),
      ElevatedButton(onPressed: _sortir, child: Text(l10n.back)),
    ],
  );

  Widget _porte(
    BuildContext context,
    AppLocalizations l10n,
    GroupLinkPreview a,
  ) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      CircleAvatar(
        radius: 40,
        backgroundColor: context.adaptivePrimaryColor.withValues(alpha: 0.15),
        backgroundImage: (a.avatarUrl != null && a.avatarUrl!.isNotEmpty)
            ? NetworkImage(a.avatarUrl!)
            : null,
        child: (a.avatarUrl == null || a.avatarUrl!.isEmpty)
            ? AppIcon(
                AppIcon.groups,
                size: 36,
                color: context.adaptivePrimaryColor,
              )
            : null,
      ),
      const SizedBox(height: 16),
      Text(
        a.name,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: context.textPrimaryColor,
        ),
      ),
      const SizedBox(height: 6),
      Text(
        '${a.isPrivate ? l10n.privateGroup : l10n.publicGroup} · '
        '${l10n.members(a.memberCount)}',
        style: TextStyle(color: context.textSecondaryColor),
      ),
      const SizedBox(height: 24),
      SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: (_envoi || _demandeEnvoyee) ? null : () => _demander(a),
          style: ElevatedButton.styleFrom(
            backgroundColor: context.adaptivePrimaryColor,
            foregroundColor: context.onPrimaryColor,
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
          child: _envoi
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(
                  _demandeEnvoyee ? l10n.requestSent : l10n.requestToJoin,
                ),
        ),
      ),
      const SizedBox(height: 8),
      TextButton(onPressed: _sortir, child: Text(l10n.back)),
    ],
  );
}
