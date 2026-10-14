part of 'conversation_screen.dart';

/// Séparateurs, libellés de date, texte surligné de la recherche.
extension _AffichageConversation on _ConversationScreenState {
  // Get date separator label
  String _getDateLabel(DateTime date, AppLocalizations l10n) {
    final l10n = AppLocalizations.of(context)!;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final messageDate = DateTime(date.year, date.month, date.day);

    if (messageDate == today) {
      return l10n.today('');
    } else if (messageDate == yesterday) {
      return l10n.yesterday('');
    } else if (now.difference(date).inDays < 7) {
      return DateFormat.EEEE(
        LocaleHelper.getDateFormatLocale(context),
      ).format(date);
    } else {
      return DateFormat.yMMMd(
        LocaleHelper.getDateFormatLocale(context),
      ).format(date);
    }
  }

  // Check if we need a date separator for reversed list
  // In reversed list, index 0 = newest, higher index = older
  // Date separator should appear ABOVE (after in reversed index) the first message of a new date
  bool _needsDateSeparatorReversed(List<MessageEntity> messages, int index) {
    // Last item (oldest message) always needs separator
    if (index == messages.length - 1) {
      return true;
    }

    final currentMessage = messages[index];
    final olderMessage = messages[index + 1]; // Next index = older message

    final currentDate = DateTime(
      currentMessage.createdAt.year,
      currentMessage.createdAt.month,
      currentMessage.createdAt.day,
    );
    final olderDate = DateTime(
      olderMessage.createdAt.year,
      olderMessage.createdAt.month,
      olderMessage.createdAt.day,
    );

    return currentDate != olderDate;
  }

  // Get message group position for reversed list
  MessageGroupPosition _getMessageGroupPositionReversed(
    List<MessageEntity> messages,
    int index,
    String? currentUserId, {
    required bool hasDateBreak,
    required bool hasNextDateBreak,
  }) => positionDansRafale(
    messages,
    index,
    hasDateBreak: hasDateBreak,
    hasNextDateBreak: hasNextDateBreak,
  );

  /// Quitte la conversation. `context.pop()` seul produisait un écran noir
  /// lorsque l'écran avait été ouvert par lien profond ou par notification :
  /// sa route est alors seule dans la pile et le pop ne laisse rien derrière.
  void _leaveConversation() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(_fallbackRoute);
    }
  }

  /// Séparateur de jour : filet plein et pastille plate.
  ///
  /// Les dégradés en fondu, la bordure et l'ombre portée ont sauté : le fil de
  /// discussion est posé sur le fond crème, un repère de date n'a pas à se
  /// détacher du fond comme un élément cliquable.
  Widget _buildDateSeparator(DateTime date, AppLocalizations l10n) {
    return _buildThreadSeparator(
      label: _getDateLabel(date, l10n),
      background: context.surfaceVariantColor,
      foreground: context.textSecondaryColor,
      rule: context.dividerColor,
    );
  }

  /// Gabarit commun aux repères posés dans le fil (date, non-lus) : un filet
  /// de part et d'autre, une pastille au centre.
  Widget _buildThreadSeparator({
    required String label,
    required Color background,
    required Color foreground,
    required Color rule,
  }) {
    final trait = Expanded(child: Container(height: 1, color: rule));
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Row(
        children: [
          trait,
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(kDesignPillRadius),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: foreground,
                letterSpacing: 0.3,
              ),
            ),
          ),
          trait,
        ],
      ),
    );
  }

  Widget _buildUnreadSeparator(int unreadCount) {
    final label =
        unreadCount == 1 ? '1 message non lu' : '$unreadCount messages non lus';

    // Même gabarit que le séparateur de date, mais en terracotta plein : c'est
    // le seul repère du fil qui doit accrocher l'œil.
    return _buildThreadSeparator(
      label: label,
      background: context.adaptivePrimaryColor,
      foreground: context.onPrimaryColor,
      rule: context.adaptivePrimaryColor.withValues(alpha: 0.35),
    );
  }

  /// Start a call with the other user
  // Appels 1-à-1 mis en pause avec _handleCallBack ci-dessus (même
  // correctif) : plus aucun appelant, code conservé pour réactivation.
  // TODO(appels): réactiver après vérification à deux vrais téléphones.
  // Future<void> _startCall({required bool isVideo}) async {
  //   if (_effectiveOtherUserId == null) return;
  //
  //   final l10n = AppLocalizations.of(context)!;
  //
  //   // Get other user info from watched data
  //   final otherUserAsync = ref.read(userStreamProvider(_effectiveOtherUserId!));
  //   final otherUser = otherUserAsync.valueOrNull;
  //
  //   final calleeName =
  //       otherUser?.displayName ?? widget.conversationName ?? l10n.user;
  //   final calleePhotoUrl = otherUser?.photoUrl ?? widget.conversationImageUrl;
  //
  //   // Vérifier si le destinataire peut recevoir des notifications (en ligne OU a un token FCM)
  //   final isCalleeOnline = otherUser?.canReceiveNotifications ?? false;
  //
  //   // Create the call in Firestore via CurrentCall provider
  //   final call = await ref
  //       .read(currentCallProvider.notifier)
  //       .initiateCall(
  //         calleeId: _effectiveOtherUserId!,
  //         calleeName: calleeName,
  //         calleePhotoUrl: calleePhotoUrl,
  //         type: isVideo ? CallType.video : CallType.audio,
  //       );
  //
  //   if (call == null) {
  //     if (mounted) {
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         SnackBar(
  //           content: Text(l10n.unableToStartCall),
  //           backgroundColor: Colors.red,
  //         ),
  //       );
  //     }
  //     return;
  //   }
  //
  //   // Navigate to call screen with the real call ID from Firestore
  //   if (mounted) {
  //     Navigator.of(context).push(
  //       MaterialPageRoute(
  //         builder:
  //             (context) => CallScreen(
  //               callId: call.id,
  //               isInitiator: true,
  //               isVideo: isVideo,
  //               calleeName: calleeName,
  //               calleePhotoUrl: calleePhotoUrl,
  //               isCalleeOnline: isCalleeOnline,
  //             ),
  //       ),
  //     );
  //   }
  //
  //   // Log analytics
  //   AnalyticsService.instance.logEvent(
  //     name: 'start_call',
  //     parameters: {
  //       'call_type': isVideo ? 'video' : 'audio',
  //       'callee_id': _effectiveOtherUserId!,
  //     },
  //   );
  // }

  /// Obtenir les initiales du nom
  String _getInitials(String? name) {
    if (name == null || name.isEmpty) return '?';
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name[0].toUpperCase();
  }

  Widget _buildHighlightedText(
    BuildContext context,
    String text,
    String query,
  ) {
    if (query.isEmpty) {
      return Text(
        text,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 13, color: context.textSecondaryColor),
      );
    }

    final lowerText = text.toLowerCase();
    final lowerQuery = query.toLowerCase();
    final matchIndex = lowerText.indexOf(lowerQuery);

    if (matchIndex == -1) {
      return Text(
        text,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 13, color: context.textSecondaryColor),
      );
    }

    // Show context around the match
    final start = (matchIndex - 20).clamp(0, text.length);
    final end = (matchIndex + query.length + 40).clamp(0, text.length);
    final snippet = text.substring(start, end);
    final snippetMatchStart = matchIndex - start;

    return Text.rich(
      TextSpan(
        children: [
          if (start > 0) const TextSpan(text: '...'),
          TextSpan(
            text: snippet.substring(0, snippetMatchStart),
            style: TextStyle(fontSize: 13, color: context.textSecondaryColor),
          ),
          TextSpan(
            text: snippet.substring(
              snippetMatchStart,
              snippetMatchStart + query.length,
            ),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: context.adaptivePrimaryColor,
            ),
          ),
          TextSpan(
            text: snippet.substring(snippetMatchStart + query.length),
            style: TextStyle(fontSize: 13, color: context.textSecondaryColor),
          ),
          if (end < text.length) const TextSpan(text: '...'),
        ],
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }
}

