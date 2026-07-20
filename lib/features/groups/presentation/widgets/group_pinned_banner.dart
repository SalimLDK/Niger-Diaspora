import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/adaptive_colors.dart';
import '../../../events/presentation/providers/event_provider.dart';
import '../../../messages/domain/entities/message_entity.dart';
import '../../../messages/presentation/providers/message_provider.dart';
import '../../../polls/presentation/providers/poll_provider.dart';
import '../../domain/entities/group_pinned_item_entity.dart';
import '../providers/group_provider.dart';

const _pollAccent = Color(0xFF6B5CE0);
const _pinAccent = Color(0xFF2F9E6E);

/// Bandeau des éléments épinglés en tête d'un groupe OU d'une conversation
/// 1-à-1, façon Telegram : une seule ligne fine fixée sous l'en-tête,
/// toujours visible. Quand plusieurs éléments sont épinglés, un compteur
/// « i/n » permet de les faire défiler en tapant. Fournir groupId OU
/// conversationId (pas les deux).
class GroupPinnedBanner extends ConsumerStatefulWidget {
  final String? groupId;
  final String? conversationId;

  /// Conversation dont les messages sont chargés, pour résoudre le texte d'un
  /// message épinglé (le contenu réel plutôt qu'un libellé générique).
  final String? messageConversationId;

  /// Tap sur un message épinglé : navigue vers le message (scroll + highlight).
  final void Function(String messageId)? onOpenMessage;

  const GroupPinnedBanner({
    super.key,
    this.groupId,
    this.conversationId,
    this.messageConversationId,
    this.onOpenMessage,
  }) : assert(groupId != null || conversationId != null);

  @override
  ConsumerState<GroupPinnedBanner> createState() => _GroupPinnedBannerState();
}

class _GroupPinnedBannerState extends ConsumerState<GroupPinnedBanner> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final itemsAsync =
        widget.groupId != null
            ? ref.watch(groupPinnedItemsProvider(widget.groupId!))
            : ref.watch(
              conversationPinnedItemsProvider(widget.conversationId!),
            );

    return itemsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (items) {
        if (items.isEmpty) return const SizedBox.shrink();
        final index = _index % items.length;
        return _PinnedRow(
          item: items[index],
          index: index,
          total: items.length,
          messageConversationId: widget.messageConversationId,
          onOpenMessage: widget.onOpenMessage,
          onCycle:
              items.length > 1
                  ? () => setState(() => _index = (index + 1) % items.length)
                  : null,
        );
      },
    );
  }
}

class _PinnedRow extends ConsumerWidget {
  final GroupPinnedItemEntity item;
  final int index;
  final int total;
  final String? messageConversationId;
  final void Function(String messageId)? onOpenMessage;
  final VoidCallback? onCycle;

  const _PinnedRow({
    required this.item,
    required this.index,
    required this.total,
    this.messageConversationId,
    this.onOpenMessage,
    this.onCycle,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    switch (item.itemType) {
      case GroupPinnedItemType.event:
        final eventAsync = ref.watch(eventByIdProvider(item.itemId));
        return eventAsync.maybeWhen(
          data:
              (event) =>
                  event == null
                      ? _unresolvedRow(context)
                      : _row(
                        context,
                        accent: context.adaptivePrimaryColor,
                        label: 'Événement épinglé',
                        title: event.title,
                        onOpen:
                            () => context.push(
                              '/events/${event.id}',
                              extra: event,
                            ),
                      ),
          orElse: () => const SizedBox.shrink(),
        );
      case GroupPinnedItemType.poll:
        final pollAsync = ref.watch(pollStreamProvider(item.itemId));
        return pollAsync.maybeWhen(
          data:
              (poll) =>
                  poll == null
                      ? _unresolvedRow(context)
                      : _row(
                        context,
                        accent: _pollAccent,
                        label: 'Sondage épinglé',
                        title: poll.question,
                        onOpen: () => context.push('/polls/${poll.id}/results'),
                      ),
          orElse: () => const SizedBox.shrink(),
        );
      case GroupPinnedItemType.message:
        if (messageConversationId == null) return const SizedBox.shrink();
        // Résolution : d'abord la fenêtre de messages chargée, sinon fetch
        // ciblé (déchiffré) — un message épinglé ancien hors fenêtre doit
        // quand même s'afficher (sinon le bandeau disparaissait dès qu'une
        // seule épingle sortait de la pagination).
        final loaded = ref
            .watch(messagesProvider(messageConversationId!))
            .valueOrNull
            ?.where((m) => m.id == item.itemId)
            .firstOrNull;
        final msg = loaded ??
            ref
                .watch(messageByIdProvider((
                  conversationId: messageConversationId!,
                  messageId: item.itemId,
                )))
                .valueOrNull;
        if (msg == null || msg.deletedForEveryone) {
          return _unresolvedRow(context);
        }
        // Jamais de contenu chiffré dans le bandeau : libellé générique.
        final text = msg.content.trim();
        final looksEncrypted =
            text.startsWith('🔐') || text.startsWith('gcm:');
        final preview = msg.isText && text.isNotEmpty && !looksEncrypted
            ? text
            : _mediaLabel(msg.type);
        return _row(
          context,
          accent: _pinAccent,
          label: total > 1 ? 'Message épinglé ${index + 1}' : 'Message épinglé',
          title: preview,
          // Tap : navigue vers le message épinglé, et passe à l'épingle
          // suivante s'il y en a plusieurs (comportement Telegram).
          onOpen: onOpenMessage == null
              ? onCycle
              : () {
                  onOpenMessage!(item.itemId);
                  onCycle?.call();
                },
        );
    }
  }

  /// Élément épinglé introuvable (supprimé, ou hors de portée des permissions
  /// de lecture) : sans cette ligne, le bandeau redevenait entièrement vide
  /// et — s'il y avait d'autres épingles valides — impossible à faire
  /// défiler puisque aucun contenu tapable n'était rendu pour cet index.
  Widget _unresolvedRow(BuildContext context) {
    if (total <= 1) return const SizedBox.shrink();
    return _row(
      context,
      accent: context.textTertiaryColor,
      label: total > 1 ? 'Épingle ${index + 1}' : 'Épingle',
      title: 'Élément indisponible',
      onOpen: onCycle,
    );
  }

  String _mediaLabel(MessageType type) {
    switch (type) {
      case MessageType.image:
        return '📷 Photo';
      case MessageType.video:
        return '🎥 Vidéo';
      case MessageType.audio:
      case MessageType.voiceNote:
        return '🎤 Message vocal';
      case MessageType.file:
        return '📎 Document';
      case MessageType.location:
        return '📍 Position';
      case MessageType.sticker:
        return 'Sticker';
      default:
        return 'Message épinglé';
    }
  }

  Widget _row(
    BuildContext context, {
    required Color accent,
    required String label,
    required String title,
    VoidCallback? onOpen,
  }) {
    // Tap sur le bandeau : ouvre l'élément (event/poll) ; s'il y a plusieurs
    // épingles, chaque tap fait aussi défiler vers le suivant.
    void handleTap() {
      onOpen?.call();
      if (onOpen == null) onCycle?.call();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: (onOpen != null || onCycle != null) ? handleTap : null,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Container(
                  width: 3,
                  height: 26,
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: accent,
                        ),
                      ),
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: context.textPrimaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
                if (total > 1) ...[
                  const SizedBox(width: 8),
                  Text(
                    '${index + 1}/$total',
                    style: TextStyle(
                      fontSize: 11,
                      color: context.textTertiaryColor,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
