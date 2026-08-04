import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Centralized service for managing all app preferences using SharedPreferences.
/// Provides type-safe access to all settings and preferences.
class PreferencesService {
  static PreferencesService? _instance;
  static PreferencesService get instance {
    _instance ??= PreferencesService._();
    return _instance!;
  }

  PreferencesService._();

  SharedPreferences? _prefs;

  static const int _currentPrefsVersion = 2;
  static const String _keyPrefsVersion = 'prefs_version';

  /// Initialize the service. Must be called before accessing preferences.
  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    await _checkAndMigrate();
  }

  Future<void> _checkAndMigrate() async {
    final int savedVersion = _prefs?.getInt(_keyPrefsVersion) ?? 0;

    if (savedVersion < _currentPrefsVersion) {
      await _performMigration(savedVersion);
      await _prefs?.setInt(_keyPrefsVersion, _currentPrefsVersion);
    }
  }

  Future<void> _performMigration(int oldVersion) async {
    // Example migration: Clear old keys or rename them
    if (oldVersion < 1) {
      // Initial migration
      // await _prefs?.remove('old_deprecated_key');
    }
    if (oldVersion < 2) {
      await _migrateSinglePostDraftToList();
    }
  }

  /// v1 → v2 : le brouillon de publication unique (`post_draft`, une simple
  /// chaîne) devient une liste (`post_drafts`). Le brouillon en cours de
  /// l'utilisateur est conservé — il devient le premier de la liste.
  Future<void> _migrateSinglePostDraftToList() async {
    final p = _prefs;
    if (p == null) return;
    final legacy = p.getString(_keyPostDraft);
    await p.remove(_keyPostDraft);
    if (legacy == null || legacy.trim().isEmpty) return;
    if ((p.getString(_keyPostDrafts) ?? '').isNotEmpty) return;
    await p.setString(
      _keyPostDrafts,
      jsonEncode([
        {
          'id': 'legacy-post-draft',
          'text': legacy,
          'updatedAt': DateTime.now().millisecondsSinceEpoch,
        },
      ]),
    );
  }

  SharedPreferences get prefs {
    if (_prefs == null) {
      throw StateError(
        'PreferencesService not initialized. Call initialize() first.',
      );
    }
    return _prefs!;
  }

  // ============================
  // PREFERENCE KEYS
  // ============================

  // Onboarding & First-Time Experience
  static const String _keyHasSeenOnboarding = 'has_seen_onboarding';
  static const String _keyHasSeenCoachMarks = 'has_seen_coach_marks';
  static const String _keyAppFirstLaunch = 'app_first_launch';
  static const String _keyAppVersion = 'app_version';

  // App Settings
  static const String _keyThemeMode = 'theme_mode';
  static const String _keyLocale = 'app_locale';

  // Notification Preferences
  static const String _keyNotificationsEnabled = 'notifications_enabled';
  static const String _keyNotifyMessages = 'notify_messages';
  static const String _keyNotifyEvents = 'notify_events';
  static const String _keyNotifyFriendRequests = 'notify_friend_requests';
  static const String _keyNotifyGroups = 'notify_groups';
  static const String _keyNotifyEventReminders = 'notify_event_reminders';
  static const String _keyNotifyLocalEvents = 'notify_local_events';
  static const String _keyNotifySystemMessages = 'notify_system_messages';
  static const String _keyNotifyAudioRoomReminders = 'notify_audio_room_reminders';
  static const String _keyNotifyPodcastEpisodes = 'notify_podcast_episodes';
  static const String _keyNotifyTransferReminders = 'notify_transfer_reminders';
  static const String _keyNotificationSound = 'notification_sound';
  static const String _keyNotificationVibration = 'notification_vibration';
  static const String _keyQuietHoursEnabled = 'quiet_hours_enabled';
  static const String _keyQuietHoursStartHour = 'quiet_hours_start_hour';
  static const String _keyQuietHoursStartMinute = 'quiet_hours_start_minute';
  static const String _keyQuietHoursEndHour = 'quiet_hours_end_hour';
  static const String _keyQuietHoursEndMinute = 'quiet_hours_end_minute';
  static const String _keyShowMessagePreview = 'show_message_preview';

  // Media Preferences
  static const String _keyAutoDownloadImages = 'auto_download_images';
  static const String _keyAutoDownloadVideos = 'auto_download_videos';
  static const String _keyDataSaverMode = 'data_saver_mode';
  // Auto-download mode keys: 'always' | 'wifi_only' | 'never'
  static const String _keyAutoDownloadImagesMode = 'auto_dl_images_mode';
  static const String _keyAutoDownloadAudioMode = 'auto_dl_audio_mode';
  static const String _keyAutoDownloadVideoMode = 'auto_dl_video_mode';
  static const String _keyAutoDownloadFilesMode = 'auto_dl_files_mode';

  // Privacy & Security
  static const String _keyBiometricEnabled = 'biometric_enabled';
  static const String _keyAnalyticsOptOut = 'analytics_opt_out';
  static const String _keyNearbyMembersEnabled = 'nearby_members_enabled';
  static const String _keyMapBusinessesLayerVisible =
      'map_businesses_layer_visible';
  static const String _keyMapMembersPanelHidden = 'map_members_panel_hidden';
  static const String _keySessionId = 'session_id'; // Internal session tracking

  // Chat Background Customization
  static const String _keyDefaultChatBackground = 'default_chat_background';
  static const String _keyCustomChatBackgrounds = 'custom_chat_backgrounds';

  // Call Settings
  static const String _keyNoiseSuppressionEnabled = 'noise_suppression_enabled';

  // Message Drafts
  static const String _keyMessageDrafts = 'message_drafts';

  // Post Drafts (§5a "Mon espace", §5b cartes brouillon — liste locale)
  static const String _keyPostDrafts = 'post_drafts';
  // Ancienne clé du brouillon unique, migrée vers _keyPostDrafts en v2.
  static const String _keyPostDraft = 'post_draft';
  // Garde-fou : au-delà, les plus anciens brouillons sont oubliés.
  static const int _maxPostDrafts = 20;

  // Followed Hashtags (§5a "Mon espace" — suivi local, aucun modèle serveur)
  static const String _keyFollowedHashtags = 'followed_hashtags';

  // Voice Notes — local "listened" state driving the unheard dot
  static const String _keyPlayedVoiceNotes = 'played_voice_notes';
  // Cap the list so it can't grow without bound; keep the most recent ids.
  static const int _maxPlayedVoiceNotes = 1000;

  // ============================
  // SESSION
  // ============================

  String? get sessionId => prefs.getString(_keySessionId);
  Future<void> setSessionId(String id) => prefs.setString(_keySessionId, id);
  Future<void> clearSessionId() => prefs.remove(_keySessionId);

  // ============================
  // ONBOARDING & FIRST-TIME
  // ============================

  bool get hasSeenOnboarding => prefs.getBool(_keyHasSeenOnboarding) ?? false;
  Future<void> setOnboardingComplete() =>
      prefs.setBool(_keyHasSeenOnboarding, true);

  bool get hasSeenCoachMarks => prefs.getBool(_keyHasSeenCoachMarks) ?? false;
  Future<void> setCoachMarksComplete() =>
      prefs.setBool(_keyHasSeenCoachMarks, true);

  bool get isFirstLaunch => prefs.getBool(_keyAppFirstLaunch) ?? true;
  Future<void> setNotFirstLaunch() => prefs.setBool(_keyAppFirstLaunch, false);

  String? get appVersion => prefs.getString(_keyAppVersion);
  Future<void> setAppVersion(String version) =>
      prefs.setString(_keyAppVersion, version);

  // ============================
  // APP SETTINGS
  // ============================

  String? get themeMode => prefs.getString(_keyThemeMode);
  Future<void> setThemeMode(String mode) =>
      prefs.setString(_keyThemeMode, mode);

  String? get locale => prefs.getString(_keyLocale);
  Future<void> setLocale(String localeCode) =>
      prefs.setString(_keyLocale, localeCode);

  static const String _keyThemeColor = 'theme_color';
  String? get themeColor => prefs.getString(_keyThemeColor);
  Future<void> setThemeColor(String color) =>
      prefs.setString(_keyThemeColor, color);

  // ============================
  // NOTIFICATION PREFERENCES
  // ============================

  bool get notificationsEnabled =>
      prefs.getBool(_keyNotificationsEnabled) ?? true;
  Future<void> setNotificationsEnabled(bool enabled) =>
      prefs.setBool(_keyNotificationsEnabled, enabled);

  bool get notifyMessages => prefs.getBool(_keyNotifyMessages) ?? true;
  Future<void> setNotifyMessages(bool enabled) =>
      prefs.setBool(_keyNotifyMessages, enabled);

  bool get notifyEvents => prefs.getBool(_keyNotifyEvents) ?? true;
  Future<void> setNotifyEvents(bool enabled) =>
      prefs.setBool(_keyNotifyEvents, enabled);

  bool get notifyFriendRequests =>
      prefs.getBool(_keyNotifyFriendRequests) ?? true;
  Future<void> setNotifyFriendRequests(bool enabled) =>
      prefs.setBool(_keyNotifyFriendRequests, enabled);

  bool get notifyGroups => prefs.getBool(_keyNotifyGroups) ?? true;
  Future<void> setNotifyGroups(bool enabled) =>
      prefs.setBool(_keyNotifyGroups, enabled);

  bool get notifyEventReminders =>
      prefs.getBool(_keyNotifyEventReminders) ?? true;
  Future<void> setNotifyEventReminders(bool enabled) =>
      prefs.setBool(_keyNotifyEventReminders, enabled);

  bool get notifyLocalEvents => prefs.getBool(_keyNotifyLocalEvents) ?? true;
  Future<void> setNotifyLocalEvents(bool enabled) =>
      prefs.setBool(_keyNotifyLocalEvents, enabled);

  bool get notifyAudioRoomReminders =>
      prefs.getBool(_keyNotifyAudioRoomReminders) ?? true;
  Future<void> setNotifyAudioRoomReminders(bool enabled) =>
      prefs.setBool(_keyNotifyAudioRoomReminders, enabled);

  bool get notifyPodcastEpisodes =>
      prefs.getBool(_keyNotifyPodcastEpisodes) ?? true;
  Future<void> setNotifyPodcastEpisodes(bool enabled) =>
      prefs.setBool(_keyNotifyPodcastEpisodes, enabled);

  bool get notifyTransferReminders =>
      prefs.getBool(_keyNotifyTransferReminders) ?? true;
  Future<void> setNotifyTransferReminders(bool enabled) =>
      prefs.setBool(_keyNotifyTransferReminders, enabled);

  bool get notifySystemMessages =>
      prefs.getBool(_keyNotifySystemMessages) ?? false;
  Future<void> setNotifySystemMessages(bool enabled) =>
      prefs.setBool(_keyNotifySystemMessages, enabled);

  bool get notificationSound => prefs.getBool(_keyNotificationSound) ?? true;
  Future<void> setNotificationSound(bool enabled) =>
      prefs.setBool(_keyNotificationSound, enabled);

  bool get notificationVibration =>
      prefs.getBool(_keyNotificationVibration) ?? true;
  Future<void> setNotificationVibration(bool enabled) =>
      prefs.setBool(_keyNotificationVibration, enabled);

  // Quiet Hours
  bool get quietHoursEnabled => prefs.getBool(_keyQuietHoursEnabled) ?? false;
  Future<void> setQuietHoursEnabled(bool enabled) =>
      prefs.setBool(_keyQuietHoursEnabled, enabled);

  int get quietHoursStartHour =>
      prefs.getInt(_keyQuietHoursStartHour) ?? 22; // Default 22:00
  Future<void> setQuietHoursStartHour(int hour) =>
      prefs.setInt(_keyQuietHoursStartHour, hour);

  int get quietHoursStartMinute => prefs.getInt(_keyQuietHoursStartMinute) ?? 0;
  Future<void> setQuietHoursStartMinute(int minute) =>
      prefs.setInt(_keyQuietHoursStartMinute, minute);

  int get quietHoursEndHour =>
      prefs.getInt(_keyQuietHoursEndHour) ?? 8; // Default 08:00
  Future<void> setQuietHoursEndHour(int hour) =>
      prefs.setInt(_keyQuietHoursEndHour, hour);

  int get quietHoursEndMinute => prefs.getInt(_keyQuietHoursEndMinute) ?? 0;
  Future<void> setQuietHoursEndMinute(int minute) =>
      prefs.setInt(_keyQuietHoursEndMinute, minute);

  // Message Preview in Notifications (Privacy)
  bool get showMessagePreview => prefs.getBool(_keyShowMessagePreview) ?? true;
  Future<void> setShowMessagePreview(bool show) =>
      prefs.setBool(_keyShowMessagePreview, show);

  // ============================
  // MEDIA PREFERENCES
  // ============================

  bool get autoDownloadImages => prefs.getBool(_keyAutoDownloadImages) ?? true;
  Future<void> setAutoDownloadImages(bool enabled) =>
      prefs.setBool(_keyAutoDownloadImages, enabled);

  bool get autoDownloadVideos => prefs.getBool(_keyAutoDownloadVideos) ?? false;
  Future<void> setAutoDownloadVideos(bool enabled) =>
      prefs.setBool(_keyAutoDownloadVideos, enabled);

  bool get dataSaverMode => prefs.getBool(_keyDataSaverMode) ?? false;
  Future<void> setDataSaverMode(bool enabled) =>
      prefs.setBool(_keyDataSaverMode, enabled);

  // Auto-download modes per media type
  String get autoDownloadImagesMode =>
      prefs.getString(_keyAutoDownloadImagesMode) ?? 'always';
  Future<void> setAutoDownloadImagesMode(String mode) =>
      prefs.setString(_keyAutoDownloadImagesMode, mode);

  String get autoDownloadAudioMode =>
      prefs.getString(_keyAutoDownloadAudioMode) ?? 'always';
  Future<void> setAutoDownloadAudioMode(String mode) =>
      prefs.setString(_keyAutoDownloadAudioMode, mode);

  String get autoDownloadVideoMode =>
      prefs.getString(_keyAutoDownloadVideoMode) ?? 'wifi_only';
  Future<void> setAutoDownloadVideoMode(String mode) =>
      prefs.setString(_keyAutoDownloadVideoMode, mode);

  String get autoDownloadFilesMode =>
      prefs.getString(_keyAutoDownloadFilesMode) ?? 'wifi_only';
  Future<void> setAutoDownloadFilesMode(String mode) =>
      prefs.setString(_keyAutoDownloadFilesMode, mode);

  // ============================
  // PRIVACY & SECURITY
  // ============================

  bool get biometricEnabled => prefs.getBool(_keyBiometricEnabled) ?? false;
  Future<void> setBiometricEnabled(bool enabled) =>
      prefs.setBool(_keyBiometricEnabled, enabled);

  bool get analyticsOptOut => prefs.getBool(_keyAnalyticsOptOut) ?? false;
  Future<void> setAnalyticsOptOut(bool optOut) =>
      prefs.setBool(_keyAnalyticsOptOut, optOut);

  /// Whether the "Nearby Members" feature is enabled.
  /// Defaults to `false` (private mode by default): nearby members are hidden
  /// on the home screen and the map, AND the user's own location is not
  /// uploaded to Firestore until the user explicitly opts in.
  bool get nearbyMembersEnabled =>
      prefs.getBool(_keyNearbyMembersEnabled) ?? false;
  Future<void> setNearbyMembersEnabled(bool enabled) =>
      prefs.setBool(_keyNearbyMembersEnabled, enabled);

  /// Whether the "businesses" layer is shown on the map (default: true).
  bool get mapBusinessesLayerVisible =>
      prefs.getBool(_keyMapBusinessesLayerVisible) ?? true;
  Future<void> setMapBusinessesLayerVisible(bool visible) =>
      prefs.setBool(_keyMapBusinessesLayerVisible, visible);

  /// Whether the "Membres à proximité" panel is hidden on the map (default: false).
  bool get mapMembersPanelHidden =>
      prefs.getBool(_keyMapMembersPanelHidden) ?? false;
  Future<void> setMapMembersPanelHidden(bool hidden) =>
      prefs.setBool(_keyMapMembersPanelHidden, hidden);

  // ============================
  // CALL SETTINGS
  // ============================

  /// Whether noise suppression is enabled for calls (default: true)
  /// Recommended for Sahel regions with variable audio environments
  bool get noiseSuppressionEnabled =>
      prefs.getBool(_keyNoiseSuppressionEnabled) ?? true;
  Future<void> setNoiseSuppressionEnabled(bool enabled) =>
      prefs.setBool(_keyNoiseSuppressionEnabled, enabled);

  // ============================
  // CHAT BACKGROUND CUSTOMIZATION
  // ============================

  /// Get the default chat background (applies to all conversations)
  String? get defaultChatBackground =>
      prefs.getString(_keyDefaultChatBackground);

  /// Set the default chat background (JSON encoded ChatBackgroundModel)
  Future<void> setDefaultChatBackground(String backgroundJson) =>
      prefs.setString(_keyDefaultChatBackground, backgroundJson);

  /// Remove the default chat background
  Future<void> clearDefaultChatBackground() =>
      prefs.remove(_keyDefaultChatBackground);

  /// Get custom backgrounds for specific conversations (`Map<conversationId, backgroundJson>`)
  Map<String, String> get customChatBackgrounds {
    final jsonString = prefs.getString(_keyCustomChatBackgrounds);
    if (jsonString == null || jsonString.isEmpty) return {};

    try {
      final Map<String, dynamic> decoded = Map<String, dynamic>.from(
        jsonDecode(jsonString),
      );
      return decoded.map((key, value) => MapEntry(key, value.toString()));
    } catch (e) {
      return {};
    }
  }

  /// Set a custom background for a specific conversation
  Future<void> setCustomChatBackground(
    String conversationId,
    String backgroundJson,
  ) async {
    final current = customChatBackgrounds;
    current[conversationId] = backgroundJson;
    await prefs.setString(_keyCustomChatBackgrounds, jsonEncode(current));
  }

  /// Remove custom background for a specific conversation
  Future<void> removeCustomChatBackground(String conversationId) async {
    final current = customChatBackgrounds;
    current.remove(conversationId);
    if (current.isEmpty) {
      await prefs.remove(_keyCustomChatBackgrounds);
    } else {
      await prefs.setString(_keyCustomChatBackgrounds, jsonEncode(current));
    }
  }

  /// Get background for a specific conversation (returns null if using default)
  String? getConversationBackground(String conversationId) {
    final custom = customChatBackgrounds;
    return custom[conversationId];
  }

  // ============================
  // MESSAGE DRAFTS
  // ============================

  /// Get all message drafts (`Map<conversationId, draftText>`)
  Map<String, String> get _messageDrafts {
    final jsonString = prefs.getString(_keyMessageDrafts);
    if (jsonString == null || jsonString.isEmpty) return {};

    try {
      final Map<String, dynamic> decoded = Map<String, dynamic>.from(
        jsonDecode(jsonString),
      );
      return decoded.map((key, value) => MapEntry(key, value.toString()));
    } catch (e) {
      return {};
    }
  }

  /// Get draft for a specific conversation
  String? getMessageDraft(String conversationId) {
    return _messageDrafts[conversationId];
  }

  /// Save draft for a specific conversation
  Future<void> saveMessageDraft(String conversationId, String draft) async {
    if (draft.trim().isEmpty) {
      await clearMessageDraft(conversationId);
      return;
    }
    final current = _messageDrafts;
    current[conversationId] = draft;
    await prefs.setString(_keyMessageDrafts, jsonEncode(current));
  }

  /// Clear draft for a specific conversation
  Future<void> clearMessageDraft(String conversationId) async {
    final current = _messageDrafts;
    current.remove(conversationId);
    if (current.isEmpty) {
      await prefs.remove(_keyMessageDrafts);
    } else {
      await prefs.setString(_keyMessageDrafts, jsonEncode(current));
    }
  }

  /// Clear all drafts
  Future<void> clearAllMessageDrafts() async {
    await prefs.remove(_keyMessageDrafts);
  }

  // ============================
  // POST DRAFTS (carte "Brouillons" de Mon espace §5a, cartes brouillon §5b)
  // ============================

  /// Brouillons de publication, du plus récemment modifié au plus ancien.
  /// Chaque entrée : `{id, text, updatedAt}` (`updatedAt` en ms epoch).
  List<Map<String, dynamic>> get postDrafts {
    final raw = prefs.getString(_keyPostDrafts);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .where((e) => (e['id'] as String?)?.isNotEmpty ?? false)
          .toList();
    } catch (_) {
      // Contenu illisible : on repart d'une liste vide plutôt que de crasher
      // au démarrage de l'écran.
      return const [];
    }
  }

  /// Crée ou met à jour le brouillon [id]. Un texte vide supprime l'entrée,
  /// comme pour les brouillons de message.
  Future<void> savePostDraft(String id, String text) async {
    if (text.trim().isEmpty) {
      await deletePostDraft(id);
      return;
    }
    final drafts = postDrafts.where((e) => e['id'] != id).toList()
      ..insert(0, {
        'id': id,
        'text': text,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      });
    await _writePostDrafts(drafts);
  }

  Future<void> deletePostDraft(String id) async {
    final drafts = postDrafts;
    final remaining = drafts.where((e) => e['id'] != id).toList();
    if (remaining.length == drafts.length) return;
    await _writePostDrafts(remaining);
  }

  Future<void> clearPostDrafts() => prefs.remove(_keyPostDrafts);

  Future<void> _writePostDrafts(List<Map<String, dynamic>> drafts) async {
    final capped =
        drafts.length > _maxPostDrafts
            ? drafts.sublist(0, _maxPostDrafts)
            : drafts;
    if (capped.isEmpty) {
      await prefs.remove(_keyPostDrafts);
      return;
    }
    await prefs.setString(_keyPostDrafts, jsonEncode(capped));
  }

  // ============================
  // FOLLOWED HASHTAGS (carte "Hashtags suivis" de Mon espace, §5a)
  // ============================

  /// Hashtags suivis localement (sans `#`), les plus récents en tête.
  List<String> get followedHashtags {
    return prefs.getStringList(_keyFollowedHashtags) ?? const [];
  }

  bool isHashtagFollowed(String hashtag) =>
      followedHashtags.contains(hashtag.toLowerCase());

  Future<void> toggleFollowedHashtag(String hashtag) async {
    final tag = hashtag.toLowerCase();
    final current = List<String>.from(followedHashtags);
    if (current.contains(tag)) {
      current.remove(tag);
    } else {
      current.insert(0, tag);
    }
    await prefs.setStringList(_keyFollowedHashtags, current);
  }

  Future<void> unfollowHashtag(String hashtag) async {
    final current = List<String>.from(followedHashtags)
      ..remove(hashtag.toLowerCase());
    await prefs.setStringList(_keyFollowedHashtags, current);
  }

  // ============================
  // VOICE NOTES ("listened" state)
  // ============================

  /// Whether the local user has already played this voice note. Drives the
  /// green "unheard" dot on [AudioMessageBubble] and persists across rebuilds
  /// and app restarts. Returns `false` before the service is initialized.
  bool isVoiceNotePlayed(String messageId) {
    if (_prefs == null) return false;
    final played = _prefs!.getStringList(_keyPlayedVoiceNotes);
    return played != null && played.contains(messageId);
  }

  /// Mark a voice note as played by the local user. No-op if already recorded
  /// or if the service isn't initialized yet.
  Future<void> markVoiceNotePlayed(String messageId) async {
    if (_prefs == null) return;
    final current = _prefs!.getStringList(_keyPlayedVoiceNotes) ?? <String>[];
    if (current.contains(messageId)) return;
    current.add(messageId);
    // Keep only the most recent ids to bound storage growth.
    if (current.length > _maxPlayedVoiceNotes) {
      current.removeRange(0, current.length - _maxPlayedVoiceNotes);
    }
    await _prefs!.setStringList(_keyPlayedVoiceNotes, current);
  }

  // ============================
  // UTILITY METHODS
  // ============================

  /// Efface ce qui appartient à la **personne**, à la déconnexion et à la
  /// suppression de compte. Les réglages de l'**appareil** survivent.
  ///
  /// Aucune de ces clés ne porte d'identifiant d'utilisateur : sans cette
  /// purge, le compte suivant sur le même téléphone héritait des brouillons du
  /// précédent — l'écran « Mes publications » affichait littéralement son
  /// brouillon de post.
  ///
  /// Volontairement conservés, parce que les purger **dégraderait** le retour
  /// du même utilisateur sans rien protéger :
  /// - thème, couleur, langue, réglages de notification et heures calmes ;
  /// - mode économie de données et téléchargement automatique ;
  /// - `analytics_opt_out` : l'effacer réactiverait la télémétrie pour qui
  ///   l'avait refusée ;
  /// - `biometric_enabled` : le déverrouillage utilise l'empreinte de qui tient
  ///   le téléphone, il n'expose rien du compte précédent ;
  /// - onboarding et coach marks, qui décrivent l'appareil ;
  /// - le consentement, déjà cloisonné par utilisateur
  ///   (`has_given_consent_<uid>`, cf. `OnboardingLocalDataSource`).
  Future<void> clearUserData() async {
    const personnelles = <String>[
      _keyMessageDrafts, // texte écrit par l'utilisateur
      _keyPostDrafts, // idem
      _keyPostDraft, // ancien brouillon unique, encore lu à la migration
      _keyFollowedHashtags, // centres d'intérêt
      _keyPlayedVoiceNotes, // historique d'écoute
      _keyDefaultChatBackground,
      _keyCustomChatBackgrounds, // images ajoutées par l'utilisateur
      _keySessionId, // suivi de session interne
      // Exposition sur la carte des membres : choix de la personne, et
      // `false` par défaut — l'effacer va donc dans le sens protecteur.
      _keyNearbyMembersEnabled,
    ];
    for (final cle in personnelles) {
      await prefs.remove(cle);
    }
  }

  /// Clear all preferences (use with caution)
  Future<void> clearAll() => prefs.clear();

  /// Remove a specific preference
  Future<void> remove(String key) => prefs.remove(key);

  /// Check if a preference exists
  bool containsKey(String key) => prefs.containsKey(key);
}
