import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'message_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

part 'typing_indicator_provider.g.dart';

/// Stream of users currently typing in a conversation
/// Returns a map of userId -> isTyping
@riverpod
Stream<Map<String, bool>> typingStatus(Ref ref, String conversationId) {
  return ref
      .read(messageRemoteDataSourceProvider)
      .getTypingStatusStream(conversationId);
}

/// Notifier to manage the current user's typing status
/// Includes debouncing to prevent excessive updates
@riverpod
class TypingIndicatorNotifier extends _$TypingIndicatorNotifier {
  Timer? _debounceTimer;
  Timer? _stopTypingTimer;
  String? _currentConversationId;
  bool _isCurrentlyTyping = false;

  @override
  bool build() {
    // Cleanup on dispose
    ref.onDispose(() {
      _debounceTimer?.cancel();
      _stopTypingTimer?.cancel();
      _clearTypingStatus();
    });
    return false;
  }

  /// Call this when user types in the message field
  /// Uses debouncing to prevent too many writes
  void onUserTyping(String conversationId) {
    _currentConversationId = conversationId;

    // Cancel any pending stop-typing timer
    _stopTypingTimer?.cancel();

    // If not already typing, set typing status immediately
    if (!_isCurrentlyTyping) {
      _setTypingStatus(conversationId, true);
    }

    // Reset the stop-typing timer (auto-stop after 3 seconds of no typing)
    _stopTypingTimer = Timer(const Duration(seconds: 3), () {
      _setTypingStatus(conversationId, false);
    });
  }

  /// Call this when user sends a message or leaves the conversation
  void stopTyping() {
    _debounceTimer?.cancel();
    _stopTypingTimer?.cancel();
    _clearTypingStatus();
  }

  void _setTypingStatus(String conversationId, bool isTyping) async {
    if (_isCurrentlyTyping == isTyping) return;
    _isCurrentlyTyping = isTyping;
    state = isTyping;

    final currentUser = await ref.read(currentUserAsyncProvider.future);
    if (currentUser == null) return;

    try {
      await ref
          .read(messageRemoteDataSourceProvider)
          .setTypingStatus(
            conversationId: conversationId,
            userId: currentUser.id,
            isTyping: isTyping,
          );
    } catch (e) {
      // Silently fail - typing indicator is not critical
    }
  }

  void _clearTypingStatus() {
    if (_currentConversationId != null && _isCurrentlyTyping) {
      _setTypingStatus(_currentConversationId!, false);
    }
    _isCurrentlyTyping = false;
    state = false;
  }
}
