import 'dart:async';
import 'dart:collection';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../shared/widgets/in_app_notification_banner.dart';

/// State pour les notifications in-app
class InAppNotificationState {
  /// Notification actuellement affich├®e (null si aucune)
  final InAppNotificationData? currentNotification;

  /// File d'attente des notifications en attente
  final Queue<InAppNotificationData> queue;

  /// ID de la conversation actuellement ouverte (pour filtrer)
  final String? currentOpenConversationId;

  /// Si les notifications in-app sont activ├®es globalement
  final bool enabled;

  /// Si le son est activ├®
  final bool soundEnabled;

  /// Si la vibration est activ├®e
  final bool vibrationEnabled;

  const InAppNotificationState({
    this.currentNotification,
    Queue<InAppNotificationData>? queue,
    this.currentOpenConversationId,
    this.enabled = true,
    this.soundEnabled = true,
    this.vibrationEnabled = true,
  }) : queue = queue ?? const _EmptyQueue();

  InAppNotificationState copyWith({
    InAppNotificationData? currentNotification,
    Queue<InAppNotificationData>? queue,
    String? currentOpenConversationId,
    bool? enabled,
    bool? soundEnabled,
    bool? vibrationEnabled,
    bool clearCurrentNotification = false,
    bool clearCurrentConversation = false,
  }) {
    return InAppNotificationState(
      currentNotification:
          clearCurrentNotification ? null : currentNotification ?? this.currentNotification,
      queue: queue ?? this.queue,
      currentOpenConversationId: clearCurrentConversation
          ? null
          : currentOpenConversationId ?? this.currentOpenConversationId,
      enabled: enabled ?? this.enabled,
      soundEnabled: soundEnabled ?? this.soundEnabled,
      vibrationEnabled: vibrationEnabled ?? this.vibrationEnabled,
    );
  }
}

/// Queue vide constante pour ├®viter les cr├®ations inutiles
class _EmptyQueue<T> implements Queue<T> {
  const _EmptyQueue();

  @override
  void add(T value) => throw UnsupportedError('Cannot modify const queue');

  @override
  void addAll(Iterable<T> iterable) => throw UnsupportedError('Cannot modify const queue');

  @override
  void addFirst(T value) => throw UnsupportedError('Cannot modify const queue');

  @override
  void addLast(T value) => throw UnsupportedError('Cannot modify const queue');

  @override
  void clear() {}

  @override
  bool remove(Object? value) => false;

  @override
  T removeFirst() => throw StateError('No element');

  @override
  T removeLast() => throw StateError('No element');

  @override
  T get first => throw StateError('No element');

  @override
  T get last => throw StateError('No element');

  @override
  bool get isEmpty => true;

  @override
  bool get isNotEmpty => false;

  @override
  int get length => 0;

  @override
  T get single => throw StateError('No element');

  @override
  Iterator<T> get iterator => <T>[].iterator;

  @override
  T elementAt(int index) => throw RangeError.index(index, this);

  @override
  Iterable<T> skip(int count) => const [];

  @override
  Iterable<T> take(int count) => const [];

  @override
  List<T> toList({bool growable = true}) => [];

  @override
  Set<T> toSet() => {};

  @override
  bool removeWhere(bool Function(T element) test) => false;

  @override
  bool retainWhere(bool Function(T element) test) => false;

  @override
  bool any(bool Function(T element) test) => false;

  @override
  bool every(bool Function(T element) test) => true;

  @override
  bool contains(Object? element) => false;

  @override
  T singleWhere(bool Function(T element) test, {T Function()? orElse}) =>
      orElse?.call() ?? (throw StateError('No element'));

  @override
  T firstWhere(bool Function(T element) test, {T Function()? orElse}) =>
      orElse?.call() ?? (throw StateError('No element'));

  @override
  T lastWhere(bool Function(T element) test, {T Function()? orElse}) =>
      orElse?.call() ?? (throw StateError('No element'));

  @override
  Iterable<T> where(bool Function(T element) test) => const [];

  @override
  Iterable<R> whereType<R>() => const [];

  @override
  String join([String separator = '']) => '';

  @override
  Iterable<R> map<R>(R Function(T element) toElement) => const [];

  @override
  Iterable<R> expand<R>(Iterable<R> Function(T element) toElements) => const [];

  @override
  T reduce(T Function(T value, T element) combine) => throw StateError('No element');

  @override
  R fold<R>(R initialValue, R Function(R previousValue, T element) combine) => initialValue;

  @override
  void forEach(void Function(T element) action) {}

  @override
  Iterable<T> skipWhile(bool Function(T value) test) => const [];

  @override
  Iterable<T> takeWhile(bool Function(T value) test) => const [];

  @override
  Iterable<T> followedBy(Iterable<T> other) => other;

  @override
  Queue<R> cast<R>() => Queue<R>();
}

/// Provider pour g├®rer les notifications in-app
final inAppNotificationProvider =
    NotifierProvider<InAppNotificationNotifier, InAppNotificationState>(
  InAppNotificationNotifier.new,
);

class InAppNotificationNotifier extends Notifier<InAppNotificationState> {
  Timer? _displayTimer;

  @override
  InAppNotificationState build() {
    // Charger les pr├®f├®rences
    _loadPreferences();
    return const InAppNotificationState();
  }

  Future<void> _loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final soundEnabled = prefs.getBool('notification_sound') ?? true;
      final vibrationEnabled = prefs.getBool('notification_vibration') ?? true;
      final messagesEnabled = prefs.getBool('notify_messages') ?? true;

      state = state.copyWith(
        enabled: messagesEnabled,
        soundEnabled: soundEnabled,
        vibrationEnabled: vibrationEnabled,
      );
    } catch (_) {
      // Utiliser les valeurs par d├®faut en cas d'erreur
    }
  }

  /// D├®finir la conversation actuellement ouverte
  /// Les notifications pour cette conversation ne seront pas affich├®es
  void setCurrentConversation(String? conversationId) {
    state = state.copyWith(
      currentOpenConversationId: conversationId,
      clearCurrentConversation: conversationId == null,
    );
  }

  /// Afficher une notification in-app
  /// Retourne false si la notification a ├®t├® filtr├®e (conversation ouverte, mute, etc.)
  bool showNotification(InAppNotificationData notification) {
    // V├®rifier si les notifications sont activ├®es
    if (!state.enabled) {
      return false;
    }

    // Filtrer si c'est la conversation actuellement ouverte
    if (state.currentOpenConversationId != null &&
        notification.conversationId == state.currentOpenConversationId) {
      return false;
    }

    // Si une notification est d├®j├á affich├®e, ajouter ├á la queue
    if (state.currentNotification != null) {
      final newQueue = Queue<InAppNotificationData>.from(state.queue);
      newQueue.add(notification);
      state = state.copyWith(queue: newQueue);
      return true;
    }

    // Afficher la notification
    state = state.copyWith(currentNotification: notification);
    return true;
  }

  /// Afficher une notification depuis les donn├®es FCM
  bool showFromFcmData(Map<String, dynamic> data) {
    final notification = InAppNotificationData.fromFcmData(data);
    return showNotification(notification);
  }

  /// Dismiss la notification actuelle
  void dismissCurrent() {
    _displayTimer?.cancel();

    // V├®rifier s'il y a des notifications en attente
    if (state.queue.isNotEmpty) {
      final newQueue = Queue<InAppNotificationData>.from(state.queue);
      final nextNotification = newQueue.removeFirst();

      state = state.copyWith(
        currentNotification: nextNotification,
        queue: newQueue,
      );
    } else {
      state = state.copyWith(clearCurrentNotification: true);
    }
  }

  /// Dismiss toutes les notifications
  void dismissAll() {
    _displayTimer?.cancel();
    state = state.copyWith(
      clearCurrentNotification: true,
      queue: Queue<InAppNotificationData>(),
    );
  }

  /// V├®rifier si une conversation est mut├®e
  Future<bool> isConversationMuted(String conversationId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final mutedConversations = prefs.getStringList('muted_conversations') ?? [];
      return mutedConversations.contains(conversationId);
    } catch (_) {
      return false;
    }
  }
}

/// Provider simple pour acc├®der ├á l'ID de conversation ouverte
final currentOpenConversationProvider = Provider<String?>((ref) {
  return ref.watch(inAppNotificationProvider).currentOpenConversationId;
});
