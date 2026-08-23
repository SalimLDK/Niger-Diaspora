import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'message_provider.dart';
import '../../data/datasources/message_remote_datasource.dart';
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
///
/// **Doit rester observé (`ref.watch`) par l'écran de conversation.**
/// Il ne l'était pas : chaque frappe faisait un `ref.read(...notifier)` sur un
/// provider `autoDispose` que personne n'écoutait. Riverpod le créait, exécutait
/// `onUserTyping`, puis le détruisait aussitôt — et `ref.onDispose` appelait
/// `_clearTypingStatus()`. La présence était donc posée puis retirée dans le
/// même tour de boucle : l'autre appareil ne voyait jamais rien, et la bulle
/// « écrit… » ne s'affichait pas. `ConversationScreen` l'observe désormais dans
/// son `build`, ce qui le maintient vivant tant que l'écran l'est — et le
/// détruit (donc efface la présence) quand on quitte la discussion.
@riverpod
class TypingIndicatorNotifier extends _$TypingIndicatorNotifier {
  Timer? _stopTypingTimer;
  String? _currentConversationId;
  bool _isCurrentlyTyping = false;

  /// Capturés à la construction : `ref.read` n'est plus utilisable une fois le
  /// notifier détruit, or c'est précisément là qu'il faut effacer la présence.
  MessageRemoteDataSource? _dataSource;
  String? _userId;

  @override
  bool build() {
    _dataSource = ref.read(messageRemoteDataSourceProvider);
    ref
        .read(currentUserAsyncProvider.future)
        .then((user) => _userId = user?.id)
        .catchError((_) => null);

    ref.onDispose(() {
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
      unawaited(_setTypingStatus(conversationId, true));
    }

    // Reset the stop-typing timer (auto-stop after 3 seconds of no typing)
    _stopTypingTimer = Timer(const Duration(seconds: 3), () {
      unawaited(_setTypingStatus(conversationId, false));
    });
  }

  /// Call this when user sends a message or leaves the conversation
  void stopTyping() {
    _stopTypingTimer?.cancel();
    _clearTypingStatus();
  }

  Future<void> _setTypingStatus(String conversationId, bool isTyping) async {
    if (_isCurrentlyTyping == isTyping) return;
    _isCurrentlyTyping = isTyping;
    // `state` n'est plus assignable une fois le notifier détruit — or c'est
    // exactement le moment où l'on repasse la présence à false.
    try {
      state = isTyping;
    } catch (_) {}

    final dataSource = _dataSource;
    final userId = _userId;
    if (dataSource == null || userId == null) return;

    try {
      await dataSource.setTypingStatus(
        conversationId: conversationId,
        userId: userId,
        isTyping: isTyping,
      );
    } catch (e) {
      // Silently fail - typing indicator is not critical. Le drapeau local est
      // remis à false pour qu'une frappe suivante retente la pose de présence
      // au lieu de se croire déjà annoncée.
      if (isTyping) _isCurrentlyTyping = false;
    }
  }

  void _clearTypingStatus() {
    final conversationId = _currentConversationId;
    if (conversationId != null && _isCurrentlyTyping) {
      unawaited(_setTypingStatus(conversationId, false));
    }
    _isCurrentlyTyping = false;
  }
}
