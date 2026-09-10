import 'package:flutter/material.dart';

import '../../core/theme/adaptive_colors.dart';
import '../../features/messages/presentation/widgets/share_to_chat_sheet.dart';
import '../../l10n/app_localizations.dart';
import '../utils/external_share.dart';
import 'app_icon.dart';
import 'sheet_handle.dart';

enum _ShareChoice { chat, whatsApp, facebook, x, system }

/// Feuille « Partager » des écrans qui n'en avaient pas : un événement, un
/// salon audio, un podcast, un épisode partaient jusqu'ici directement dans la
/// feuille système, sans jamais proposer une discussion comme destination.
///
/// L'action choisie est exécutée **après** la fermeture de la feuille : ouvrir
/// le sélecteur de discussions par-dessus une feuille modale empilerait deux
/// modales.
class ShareOptionsSheet {
  const ShareOptionsSheet._();

  static Future<void> show(
    BuildContext context, {
    required ChatShareContent chatContent,
    required String externalText,
    required String url,
    String? subject,
  }) async {
    final choice = await showModalBottomSheet<_ShareChoice>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => const _ShareOptionsSheetBody(),
    );

    if (choice == null || !context.mounted) return;

    switch (choice) {
      case _ShareChoice.chat:
        await ShareToChatSheet.show(context, content: chatContent);
      case _ShareChoice.whatsApp:
        await ExternalShare.whatsApp(externalText);
      case _ShareChoice.facebook:
        await ExternalShare.facebook(url);
      case _ShareChoice.x:
        await ExternalShare.x(externalText);
      case _ShareChoice.system:
        await ExternalShare.system(text: externalText, subject: subject);
    }
  }
}

class _ShareOptionsSheetBody extends StatelessWidget {
  const _ShareOptionsSheetBody();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            const SheetHandle(),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  l10n.share,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: context.textPrimaryColor,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              onTap: () => Navigator.pop(context, _ShareChoice.chat),
              leading: CircleAvatar(
                backgroundColor: context.adaptivePrimaryColor.withValues(
                  alpha: 0.15,
                ),
                child: Icon(
                  Icons.forum_rounded,
                  color: context.adaptivePrimaryColor,
                ),
              ),
              title: Text(
                l10n.shareToChatTitle,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: context.textPrimaryColor,
                ),
              ),
              subtitle: Text(
                l10n.shareToChatSubtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: context.textSecondaryColor,
                ),
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  l10n.shareVia,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: context.textSecondaryColor,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _ShareChoiceButton(
                    asset: AppIcon.whatsapp,
                    color: const Color(0xFF25D366),
                    label: l10n.whatsApp,
                    choice: _ShareChoice.whatsApp,
                  ),
                  _ShareChoiceButton(
                    asset: AppIcon.facebook,
                    color: const Color(0xFF1877F2),
                    label: l10n.facebook,
                    choice: _ShareChoice.facebook,
                  ),
                  _ShareChoiceButton(
                    asset: AppIcon.x,
                    color: isDark ? Colors.white : const Color(0xFF14171A),
                    label: l10n.xTwitter,
                    choice: _ShareChoice.x,
                  ),
                  _ShareChoiceButton(
                    icon: Icons.more_horiz_rounded,
                    color: context.adaptivePrimaryColor,
                    label: l10n.more,
                    choice: _ShareChoice.system,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShareChoiceButton extends StatelessWidget {
  const _ShareChoiceButton({
    this.icon,
    this.asset,
    required this.color,
    required this.label,
    required this.choice,
  }) : assert(icon != null || asset != null);

  final IconData? icon;
  final String? asset;
  final Color color;
  final String label;
  final _ShareChoice choice;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.pop(context, choice),
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 68,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child:
                  asset != null
                      ? AppIcon(asset!, color: color, size: 24)
                      : Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(fontSize: 11, color: context.textSecondaryColor),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
