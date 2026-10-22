import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:diaspo_niger/l10n/app_localizations.dart';

import '../../core/responsive/responsive_service.dart';
import '../../core/theme/adaptive_colors.dart';
import '../../core/theme/design_kit.dart';
import '../../features/groups/presentation/providers/group_request_provider.dart';
import '../../features/messages/presentation/providers/message_provider.dart';

/// Les deux vues de l'onglet « Discussions ».
enum DiscussionsView { messages, groups }

/// Bascule « Messages / Groupes » posée sous l'en-tête des deux écrans.
///
/// Messages et Groupes sont deux routes sœurs d'une même branche du shell
/// (voir `app_router.dart`) : le segment navigue de l'une à l'autre avec `go`,
/// sans transition, et la branche retient la dernière vue ouverte.
///
/// Chaque moitié porte son compteur : les conversations non lues pour
/// Messages, les invitations de groupe en attente pour Groupes. Ainsi un
/// message de groupe ne passe pas inaperçu derrière les conversations privées,
/// et inversement.
class DiscussionsSegment extends ConsumerWidget {
  const DiscussionsSegment({super.key, required this.current});

  final DiscussionsView current;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final unread = ref.watch(totalUnreadCountProvider);
    final invites =
        ref.watch(receivedGroupInvitesProvider).valueOrNull?.length ?? 0;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        context.horizontalPadding,
        12,
        context.horizontalPadding,
        0,
      ),
      child: Row(
        children: [
          Expanded(
            child: _Entry(
              label: l10n.messages,
              count: unread,
              isSelected: current == DiscussionsView.messages,
              onTap: () => _go(context, DiscussionsView.messages, '/messages'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _Entry(
              label: l10n.homeGroups,
              count: invites,
              isSelected: current == DiscussionsView.groups,
              onTap: () => _go(context, DiscussionsView.groups, '/groups'),
            ),
          ),
        ],
      ),
    );
  }

  void _go(BuildContext context, DiscussionsView target, String path) {
    if (target == current) return;
    context.go(path);
  }
}

class _Entry extends StatelessWidget {
  const _Entry({
    required this.label,
    required this.count,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fill = context.textPrimaryColor;
    final foreground = isSelected ? context.backgroundColor : fill;
    return Material(
      color: isSelected ? fill : context.surfaceColor,
      borderRadius: BorderRadius.circular(kDesignPillRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(kDesignPillRadius),
        child: Container(
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(kDesignPillRadius),
            border: Border.all(color: isSelected ? fill : context.borderColor),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: foreground,
                  ),
                ),
              ),
              if (count > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.all(Radius.circular(9)),
                  ),
                  child: Text(
                    count > 99 ? '99+' : '$count',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      height: 1,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
