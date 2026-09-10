import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:diaspo_niger/shared/widgets/app_icon.dart';
import '../../../../core/theme/adaptive_colors.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/sheet_handle.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
import '../../domain/entities/conversation_entity.dart';
import '../providers/message_provider.dart';

/// Une conversation résolue en « ce que l'utilisateur lit » : le nom et
/// l'avatar réellement affichés.
///
/// Un 1:1 n'a ni `name` ni `imageUrl` en base — les deux vivent sur l'autre
/// participant. Chaque sélecteur de conversation refaisait cette résolution
/// dans sa tuile, mais filtrait la recherche sur `conversation.name`, resté
/// nul : taper le nom d'un contact faisait disparaître TOUTES les discussions
/// privées, et sans recherche elles s'affichaient sous « Conversation » avec
/// un avatar « ? », donc indistinguables les unes des autres. Partager vers un
/// 1:1 était de fait impossible. La résolution vit ici, une fois, pour tous
/// les sélecteurs.
class ResolvedConversation {
  const ResolvedConversation({
    required this.conversation,
    required this.displayName,
    this.avatarUrl,
    this.isSelfNotes = false,
  });

  final ConversationEntity conversation;
  final String displayName;
  final String? avatarUrl;
  final bool isSelfNotes;

  String get id => conversation.id;
  bool get isGroup => conversation.isGroup;

  bool matches(String query) {
    if (query.isEmpty) return true;
    return displayName.toLowerCase().contains(query.toLowerCase());
  }
}

/// Résout une liste de conversations pour l'affichage.
///
/// À appeler depuis un `build` : la fonction `watch` le profil de l'autre
/// participant de chaque 1:1, donc l'écran se reconstruit quand un nom arrive.
List<ResolvedConversation> resolveConversations(
  WidgetRef ref,
  List<ConversationEntity> conversations, {
  required String? currentUserId,
  required AppLocalizations l10n,
}) {
  return conversations.map((conversation) {
    if (currentUserId != null && conversation.isSelfNotesFor(currentUserId)) {
      return ResolvedConversation(
        conversation: conversation,
        displayName: l10n.messagesMyNotes,
        avatarUrl: conversation.imageUrl,
        isSelfNotes: true,
      );
    }

    var displayName = conversation.name ?? l10n.conversation;
    var avatarUrl = conversation.imageUrl;

    if (conversation.isIndividual && currentUserId != null) {
      final otherUserId = conversation.getOtherParticipantId(currentUserId);
      if (otherUserId.isNotEmpty) {
        final other = ref.watch(userStreamProvider(otherUserId)).valueOrNull;
        if (other != null) {
          displayName = other.displayName ?? displayName;
          avatarUrl = other.photoUrl ?? avatarUrl;
        }
      }
    }

    return ResolvedConversation(
      conversation: conversation,
      displayName: displayName,
      avatarUrl: avatarUrl,
    );
  }).toList();
}

/// Tuile d'une conversation dans un sélecteur (partage, transfert, contenu
/// reçu d'une autre app).
class ConversationPickerTile extends StatelessWidget {
  const ConversationPickerTile({
    super.key,
    required this.resolved,
    required this.onTap,
    this.isSending = false,
    this.isSent = false,
    this.isSelected = false,
    this.showCheckbox = false,
  });

  final ResolvedConversation resolved;
  final VoidCallback onTap;
  final bool isSending;
  final bool isSent;
  final bool isSelected;
  final bool showCheckbox;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final avatarUrl = resolved.avatarUrl;
    final hasAvatar = avatarUrl != null && avatarUrl.isNotEmpty;

    return ListTile(
      onTap: isSending ? null : onTap,
      tileColor:
          isSelected
              ? context.adaptivePrimaryColor.withValues(alpha: 0.1)
              : null,
      leading: Stack(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor:
                resolved.isGroup
                    ? context.adaptiveSecondaryColor.withValues(alpha: 0.2)
                    : context.adaptivePrimaryColor.withValues(alpha: 0.2),
            backgroundImage:
                hasAvatar ? CachedNetworkImageProvider(avatarUrl) : null,
            child:
                hasAvatar
                    ? null
                    : AppIcon(
                      resolved.isSelfNotes
                          ? AppIcon.chatBubble
                          : resolved.isGroup
                          ? AppIcon.groups
                          : AppIcon.person,
                      color:
                          resolved.isGroup
                              ? context.adaptiveSecondaryColor
                              : context.adaptivePrimaryColor,
                    ),
          ),
          if (isSelected)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: context.adaptivePrimaryColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: context.surfaceColor, width: 2),
                ),
                child: const AppIcon(
                  AppIcon.check,
                  size: 12,
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
      title: Text(
        resolved.displayName,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: context.textPrimaryColor,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        resolved.isSelfNotes
            ? l10n.messagesMyNotesSubtitle
            : resolved.isGroup
            ? l10n.group
            : l10n.privateMessage,
        style: TextStyle(fontSize: 13, color: context.textSecondaryColor),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: _buildTrailing(context),
    );
  }

  Widget _buildTrailing(BuildContext context) {
    if (isSending) {
      return SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: context.adaptivePrimaryColor,
        ),
      );
    }

    if (isSent) {
      return AppIcon(
        AppIcon.checkCircle,
        size: 20,
        color: context.adaptivePrimaryColor,
      );
    }

    if (showCheckbox) {
      return Checkbox(
        value: isSelected,
        onChanged: (_) => onTap(),
        activeColor: context.adaptivePrimaryColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      );
    }

    return AppIcon(AppIcon.send, size: 20, color: context.adaptivePrimaryColor);
  }
}

/// Feuille « choisir une ou plusieurs discussions », partagée par tous les
/// partages internes : post, groupe, profil, événement, transfert de message,
/// contenu reçu d'une autre application.
///
/// L'appelant ne fournit que l'en-tête, l'aperçu de ce qui part, et [onSend].
class ConversationPickerSheet extends ConsumerStatefulWidget {
  const ConversationPickerSheet({
    super.key,
    required this.title,
    required this.onSend,
    this.subtitle,
    this.leading,
    this.preview,
    this.badge,
    this.heightFactor = 0.8,
    this.successMessage,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;

  /// Aperçu de ce qui est sur le point d'être envoyé.
  final Widget? preview;

  /// Pastille à droite de l'en-tête (« 3 messages », « 2 fichiers »…).
  final Widget? badge;

  final double heightFactor;

  /// Envoie vers les conversations choisies et retourne le nombre d'envois
  /// réussis — c'est lui qui décide du message de confirmation.
  final Future<int> Function(List<ConversationEntity> targets) onSend;

  /// Confirmation affichée quand tout est parti.
  final String Function(int targetCount)? successMessage;

  /// Ouvre la feuille. Retourne `true` si au moins un envoi a réussi.
  static Future<bool?> show(
    BuildContext context, {
    required String title,
    required Future<int> Function(List<ConversationEntity> targets) onSend,
    String? subtitle,
    Widget? leading,
    Widget? preview,
    Widget? badge,
    double heightFactor = 0.8,
    String Function(int targetCount)? successMessage,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (_) => ConversationPickerSheet(
            title: title,
            subtitle: subtitle,
            leading: leading,
            preview: preview,
            badge: badge,
            heightFactor: heightFactor,
            successMessage: successMessage,
            onSend: onSend,
          ),
    );
  }

  @override
  ConsumerState<ConversationPickerSheet> createState() =>
      _ConversationPickerSheetState();
}

class _ConversationPickerSheetState
    extends ConsumerState<ConversationPickerSheet> {
  String _searchQuery = '';
  bool _isSending = false;
  String? _sendingToConversationId;
  bool _isSelectionMode = false;
  final Set<String> _selectedConversationIds = {};

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final conversationsAsync = ref.watch(conversationsProvider);
    final currentUser = ref.watch(currentUserProvider).valueOrNull;

    return Container(
      height: MediaQuery.of(context).size.height * widget.heightFactor,
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          const SheetHandle(),
          const SizedBox(height: 16),
          _buildHeader(l10n),
          if (widget.preview != null) ...[
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: widget.preview!,
            ),
          ],
          const SizedBox(height: 12),
          _buildSearchField(l10n),
          const SizedBox(height: 8),
          Expanded(
            child: conversationsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error:
                  (_, __) => Center(
                    child: Text(
                      l10n.loadingError,
                      style: TextStyle(color: context.textSecondaryColor),
                    ),
                  ),
              data: (conversations) {
                final resolved = resolveConversations(
                  ref,
                  conversations,
                  currentUserId: currentUser?.id,
                  l10n: l10n,
                );
                final filtered =
                    resolved.where((r) => r.matches(_searchQuery)).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Text(
                      l10n.noConversationFound,
                      style: TextStyle(color: context.textSecondaryColor),
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final item = filtered[index];
                    return ConversationPickerTile(
                      resolved: item,
                      isSending: _sendingToConversationId == item.id,
                      isSelected: _selectedConversationIds.contains(item.id),
                      showCheckbox: _isSelectionMode,
                      onTap: () {
                        if (_isSelectionMode) {
                          _toggleSelection(item.id);
                        } else {
                          _send([item.conversation]);
                        }
                      },
                    );
                  },
                );
              },
            ),
          ),
          if (_isSelectionMode) _buildSendButton(l10n),
        ],
      ),
    );
  }

  Widget _buildHeader(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          if (widget.leading != null) ...[
            widget.leading!,
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: context.textPrimaryColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  _isSelectionMode
                      ? l10n.pickerSelectConversations
                      : widget.subtitle ?? l10n.pickerTapToSend,
                  style: TextStyle(
                    fontSize: 11,
                    color: context.textTertiaryColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (widget.badge != null && !_isSelectionMode) widget.badge!,
          const SizedBox(width: 8),
          TextButton(
            onPressed: _isSending ? null : _toggleSelectionMode,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              backgroundColor:
                  _isSelectionMode
                      ? Colors.red.withValues(alpha: 0.1)
                      : context.adaptivePrimaryColor.withValues(alpha: 0.1),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              _isSelectionMode ? l10n.cancel : l10n.selectAction,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color:
                    _isSelectionMode ? Colors.red : context.adaptivePrimaryColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: TextField(
        onChanged: (value) => setState(() => _searchQuery = value),
        decoration: InputDecoration(
          hintText: l10n.searchConversation,
          prefixIcon: AppIcon(AppIcon.search, color: context.textTertiaryColor),
          filled: true,
          fillColor: context.surfaceVariantColor,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 10,
          ),
        ),
      ),
    );
  }

  Widget _buildSendButton(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed:
                _isSending || _selectedConversationIds.isEmpty
                    ? null
                    : _sendToSelected,
            style: ElevatedButton.styleFrom(
              backgroundColor: context.adaptivePrimaryColor,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_isSending)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                else
                  const AppIcon(AppIcon.send, color: Colors.white),
                const SizedBox(width: 8),
                Text(
                  _isSending
                      ? l10n.adminSending
                      : l10n.sendToConversations(
                        _selectedConversationIds.length,
                      ),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _toggleSelectionMode() {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      if (!_isSelectionMode) _selectedConversationIds.clear();
    });
  }

  void _toggleSelection(String conversationId) {
    setState(() {
      if (!_selectedConversationIds.remove(conversationId)) {
        _selectedConversationIds.add(conversationId);
      }
    });
  }

  Future<void> _sendToSelected() {
    final conversations = ref.read(conversationsProvider).valueOrNull ?? [];
    final targets =
        conversations
            .where((c) => _selectedConversationIds.contains(c.id))
            .toList();
    return _send(targets);
  }

  Future<void> _send(List<ConversationEntity> targets) async {
    if (_isSending || targets.isEmpty) return;

    setState(() {
      _isSending = true;
      _sendingToConversationId = targets.length == 1 ? targets.first.id : null;
    });

    final l10n = AppLocalizations.of(context)!;
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final primaryColor = context.adaptivePrimaryColor;

    int successCount = 0;
    try {
      successCount = await widget.onSend(targets);
    } catch (_) {
      successCount = 0;
    }

    if (!mounted) return;

    setState(() {
      _isSending = false;
      _sendingToConversationId = null;
    });

    navigator.pop(successCount > 0);

    final allSent = successCount >= targets.length;
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          successCount == 0
              ? l10n.shareError
              : allSent
              ? widget.successMessage?.call(targets.length) ??
                  l10n.pickerContentSent
              : l10n.pickerContentPartiallySent,
        ),
        backgroundColor:
            successCount == 0
                ? Colors.red
                : allSent
                ? primaryColor
                : Colors.orange,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
