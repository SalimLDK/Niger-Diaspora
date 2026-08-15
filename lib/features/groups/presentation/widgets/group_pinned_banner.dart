import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Fonctionnalité épingle mise en pause (2026-08-14) : plus aucun de ces
// imports n'est utilisé par du code actif dans ce fichier — tout ce qui les
// consommait (`_PinnedRow` et les accents/motifs ci-dessous) est commenté
// plus bas. Les réactiver en même temps que ce bloc.
// import 'package:go_router/go_router.dart';
// import '../../../../core/theme/adaptive_colors.dart';
// import '../../../messages/domain/entities/message_entity.dart';
// import '../../../messages/presentation/providers/message_provider.dart';
// import '../../../polls/presentation/providers/poll_provider.dart';
// import '../../domain/entities/group_pinned_item_entity.dart';
// import '../providers/group_pinned_providers.dart';
// import '../../../events/presentation/providers/event_by_id_provider.dart';

// const _pollAccent = Color(0xFF6B5CE0);
// const _pinAccent = Color(0xFF2F9E6E);

// /// Filet de sécurité : un contenu chiffré « iv:ciphertext » en base64 ne doit
// /// jamais être affiché tel quel dans le bandeau (repli sur un libellé générique).
// final _kCiphertextPattern = RegExp(
//   r'^[A-Za-z0-9+/]{16,}={0,2}:[A-Za-z0-9+/]{16,}={0,2}$',
// );

/// Ligne sans bandeau : rien n'est épinglé, ou l'épingle n'est pas (encore)
/// résoluble. La pastille (bascule ÉCO, fiche 6b) reste alignée à droite —
/// elle ne doit JAMAIS disparaître de l'écran, sinon la bascule s'évapore dès
/// qu'une épingle est orpheline ou en cours de chargement.
Widget _trailingOnlyRow(Widget? trailing) {
  if (trailing == null) return const SizedBox.shrink();
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    child: Row(children: [const Spacer(), trailing]),
  );
}

/// Bandeau des éléments épinglés en tête d'une conversation (1-à-1 ou de
/// groupe — les épingles sont toujours indexées par `conversation_id`, voir
/// `_pinMessage` dans `conversation_screen.dart`), façon Telegram : une seule
/// ligne fine fixée sous l'en-tête, toujours visible. Quand plusieurs
/// éléments sont épinglés, un compteur « i/n » permet de les faire défiler
/// en tapant.
///
/// **Fonctionnalité mise en pause (2026-08-14)** : le contenu épinglé n'est
/// plus rendu (voir `_GroupPinnedBannerState.build`) — le widget ne montre
/// plus que sa pastille `trailing` (bascule ÉCO), qui n'a rien à voir avec
/// l'épinglage et doit rester visible. Les épingles existantes restent en
/// base, prêtes à réapparaître en réactivant le bloc commenté ci-dessous.
class GroupPinnedBanner extends ConsumerStatefulWidget {
  final String conversationId;

  /// Conversation dont les messages sont chargés, pour résoudre le texte d'un
  /// message épinglé (le contenu réel plutôt qu'un libellé générique).
  final String? messageConversationId;

  /// Tap sur un message épinglé : navigue vers le message (scroll + highlight).
  final void Function(String messageId)? onOpenMessage;

  /// Pastille posée à droite de la ligne (fiche 6b : la bascule ÉCO y vit).
  ///
  /// Elle reste affichée **même quand rien n'est épinglé** : sinon la bascule
  /// disparaîtrait de l'écran dès qu'il n'y a pas d'épingle, ce qui est le cas
  /// courant. La ligne se réduit alors à la seule pastille, alignée à droite.
  final Widget? trailing;

  const GroupPinnedBanner({
    super.key,
    required this.conversationId,
    this.messageConversationId,
    this.onOpenMessage,
    this.trailing,
  });

  @override
  ConsumerState<GroupPinnedBanner> createState() => _GroupPinnedBannerState();
}

class _GroupPinnedBannerState extends ConsumerState<GroupPinnedBanner> {
  // Champs utilisés par le rendu réel (paramètre du bloc commenté ci-dessous
  // dans `build`) : plus lus/écrits tant que la pause dure.
  // int _index = 0;
  // List<GroupPinnedItemEntity> _lastItems = const [];

  @override
  Widget build(BuildContext context) {
    // Fonctionnalité épingle mise en pause : le bandeau ne montre plus que
    // sa pastille de droite (ÉCO), jamais le contenu épinglé. Voir aussi
    // `canPin` dans conversation_screen.dart et `_GroupInfoCard` dans
    // group_detail_screen.dart pour le reste de la pause.
    //
    // final itemsAsync = ref.watch(
    //   conversationPinnedItemsProvider(widget.conversationId),
    // );
    //
    // // Met à jour le cache dès qu'une vraie valeur arrive (data), sinon garde
    // // la dernière connue pendant loading/error.
    // if (itemsAsync.hasValue) _lastItems = itemsAsync.value!;
    // final items = itemsAsync.valueOrNull ?? _lastItems;
    //
    // if (items.isEmpty) return _trailingOnlyRow(widget.trailing);
    // final index = _index % items.length;
    // return _PinnedRow(
    //   item: items[index],
    //   index: index,
    //   total: items.length,
    //   messageConversationId: widget.messageConversationId,
    //   onOpenMessage: widget.onOpenMessage,
    //   trailing: widget.trailing,
    //   onCycle:
    //       items.length > 1
    //           ? () => setState(() => _index = (index + 1) % items.length)
    //           : null,
    // );
    return _trailingOnlyRow(widget.trailing);
  }
}

/* Fonctionnalité épingle mise en pause (2026-08-14) : `_PinnedRow` ne sert
   plus qu'à `_GroupPinnedBannerState.build`, qui ne l'instancie plus (voir
   ci-dessus). Gardé en commentaire pour réactivation plutôt que supprimé.

class _PinnedRow extends ConsumerWidget {
  final GroupPinnedItemEntity item;
  final int index;
  final int total;
  final String? messageConversationId;
  final void Function(String messageId)? onOpenMessage;
  final VoidCallback? onCycle;
  final Widget? trailing;

  const _PinnedRow({
    required this.item,
    required this.index,
    required this.total,
    this.messageConversationId,
    this.onOpenMessage,
    this.onCycle,
    this.trailing,
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
          orElse: () => _trailingOnlyRow(trailing),
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
          orElse: () => _trailingOnlyRow(trailing),
        );
      case GroupPinnedItemType.message:
        if (messageConversationId == null) return _trailingOnlyRow(trailing);
        // Résolution : d'abord la fenêtre de messages chargée, sinon fetch
        // ciblé (déchiffré) — un message épinglé ancien hors fenêtre doit
        // quand même s'afficher (sinon le bandeau disparaissait dès qu'une
        // seule épingle sortait de la pagination).
        final loaded =
            ref
                .watch(messagesProvider(messageConversationId!))
                .valueOrNull
                ?.where((m) => m.id == item.itemId)
                .firstOrNull;
        final msg =
            loaded ??
            ref
                .watch(
                  messageByIdProvider((
                    conversationId: messageConversationId!,
                    messageId: item.itemId,
                  )),
                )
                .valueOrNull;
        if (msg == null || msg.deletedForEveryone) {
          return _unresolvedRow(context);
        }
        // Aperçu selon le type — un message épinglé peut être de TOUT type :
        // texte, média, ou porteur d'un sondage / événement / publication /
        // produit. On affiche le libellé le plus parlant.
        final text = msg.content.trim();
        final looksEncrypted =
            text.startsWith('gcm:') || _kCiphertextPattern.hasMatch(text);
        final preview = _messagePreview(msg, text, looksEncrypted);
        return _row(
          context,
          accent: _pinAccent,
          label: total > 1 ? 'Message épinglé ${index + 1}' : 'Message épinglé',
          title: preview,
          // Tap : navigue vers le message épinglé, et passe à l'épingle
          // suivante s'il y en a plusieurs (comportement Telegram).
          onOpen:
              onOpenMessage == null
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
    if (total <= 1) return _trailingOnlyRow(trailing);
    return _row(
      context,
      accent: context.textTertiaryColor,
      label: total > 1 ? 'Épingle ${index + 1}' : 'Épingle',
      title: 'Élément indisponible',
      onOpen: onCycle,
    );
  }

  /// Aperçu le plus parlant pour un message épinglé, quel que soit son type.
  String _messagePreview(MessageEntity msg, String text, bool looksEncrypted) {
    // Contenus interactifs attachés (prioritaires sur le type brut).
    if (msg.hasEvent) {
      final t = (msg.eventData?['title'] as String?)?.trim();
      return '📅 ${t != null && t.isNotEmpty ? t : 'Événement'}';
    }
    if (msg.hasProduct) {
      final t = (msg.productData?['title'] as String?)?.trim();
      return '🛍️ ${t != null && t.isNotEmpty ? t : 'Produit'}';
    }
    if (msg.hasPost) {
      final c = (msg.postData?['content'] as String?)?.trim();
      return '🔗 ${c != null && c.isNotEmpty ? c : 'Publication'}';
    }
    if (msg.isText) {
      // Texte lisible (déchiffré) : on l'affiche tel quel.
      if (text.isNotEmpty && !looksEncrypted) return text;
      // Illisible sur cet appareil (clés E2EE absentes) : le dire. Sans ça, le
      // repli générique répétait mot pour mot le libellé de la ligne — le
      // bandeau affichait « Message épinglé 1 » au-dessus de « Message
      // épinglé », soit deux fois rien.
      return text.isEmpty ? 'Message' : '🔐 Message chiffré';
    }
    // Sinon, libellé par type de média.
    return _mediaLabel(msg.type);
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
      case MessageType.text:
        return 'Message';
      default:
        return 'Message';
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

    // Fiche 6b : le bandeau et la pastille (ÉCO) se partagent la ligne, en
    // deux blocs distincts — le bandeau prend la place qui reste.
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: _banner(
              context,
              accent: accent,
              label: label,
              title: title,
              onTap: (onOpen != null || onCycle != null) ? handleTap : null,
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 8), trailing!],
        ],
      ),
    );
  }

  Widget _banner(
    BuildContext context, {
    required Color accent,
    required String label,
    required String title,
    required VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
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
    );
  }
}
*/
