// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get callControlMic => 'Mic';

  @override
  String get callControlMicOff => 'Mic off';

  @override
  String get callControlSpeaker => 'Speaker';

  @override
  String get callControlEarpiece => 'Earpiece';

  @override
  String get callControlCamera => 'Camera';

  @override
  String get callControlVideo => 'Video';

  @override
  String get callControlFlip => 'Flip';

  @override
  String get callControlHold => 'Hold';

  @override
  String get callControlResume => 'Resume';

  @override
  String get hangUp => 'Hang up';

  @override
  String get supportPromptHeader => 'Where to start?';

  @override
  String get supportPromptTransfer => 'A transfer is stuck';

  @override
  String get supportPromptAccount => 'I can\'t access my account';

  @override
  String get supportPromptBug => 'A technical problem';

  @override
  String get supportAutoAttached => 'Automatically attached';

  @override
  String get appTitle => 'Diaspo Niger';

  @override
  String get you => 'You';

  @override
  String get welcomeTitle => 'Welcome';

  @override
  String get welcomeBackTitle => 'Welcome back';

  @override
  String get createMyAccount => 'Create my account';

  @override
  String get passwordStrengthWeak => 'Weak';

  @override
  String get passwordStrengthOk => 'Good';

  @override
  String get passwordStrengthStrong => 'Strong';

  @override
  String get loginSubtitle =>
      'Find the Nigerien community again: encrypted messages, local support, transfers home.';

  @override
  String get emailAddressLabel => 'Email address';

  @override
  String get forgotShort => 'Forgot?';

  @override
  String get passwordMinHelper => 'At least 6 characters';

  @override
  String get e2eeFooterNote => 'Your messages are end-to-end encrypted.';

  @override
  String get joinDiaspora => 'Join the Nigerien diaspora';

  @override
  String get continueWithGoogle => 'Continue with Google';

  @override
  String get or => 'or';

  @override
  String get password => 'Password';

  @override
  String get confirmPassword => 'Confirm password';

  @override
  String get signIn => 'Sign in';

  @override
  String get signUp => 'Sign up';

  @override
  String get noAccount => 'Don\'t have an account?';

  @override
  String get alreadyHaveAccount => 'Already have an account?';

  @override
  String get createAccount => 'Create account';

  @override
  String get joinCommunity => 'Join the Nigerien community';

  @override
  String get enterEmail => 'Please enter your email';

  @override
  String get invalidEmail => 'Invalid email';

  @override
  String get emailMissingAt => 'Add the @, e.g. name@example.com';

  @override
  String get emailMissingDomain => 'The address ending is missing, e.g. .com';

  @override
  String get enterPassword => 'Please enter your password';

  @override
  String get enterAPassword => 'Please enter a password';

  @override
  String get passwordTooShort => 'Password must be at least 6 characters';

  @override
  String get enterName => 'Please enter your name';

  @override
  String get nameTooShort => 'Name must be at least 2 characters';

  @override
  String get confirmPasswordRequired => 'Please confirm your password';

  @override
  String get passwordsDoNotMatch => 'Passwords do not match';

  @override
  String get termsAgreement =>
      'By signing up, you agree to our Terms of Service and Privacy Policy.';

  @override
  String get settings => 'Settings';

  @override
  String get account => 'Account';

  @override
  String get editProfile => 'Edit profile';

  @override
  String get myProfile => 'My profile';

  @override
  String get email => 'Email';

  @override
  String get notDefined => 'Not defined';

  @override
  String get notifications => 'Notifications';

  @override
  String get pushNotifications => 'Push notifications';

  @override
  String get receiveNotifications => 'Receive notifications';

  @override
  String get notificationPreferences => 'Notification preferences';

  @override
  String get messages => 'Messages';

  @override
  String get newEvents => 'New events';

  @override
  String get groupActivity => 'Group activity';

  @override
  String get eventReminders => 'Event reminders';

  @override
  String get privacy => 'Privacy';

  @override
  String get visibleProfile => 'Visible profile';

  @override
  String get appearInSearches => 'Appear in searches';

  @override
  String get shareLocation => 'Share my location';

  @override
  String get appearOnMap => 'Appear on map';

  @override
  String get blockedUsers => 'Blocked users';

  @override
  String get noBlockedUsers => 'No blocked users';

  @override
  String get blockedUsersConsequences =>
      'The blocked person can no longer send you messages, or see your location or online status. They are not notified of the block.';

  @override
  String get unblock => 'Unblock';

  @override
  String get blockUser => 'Block user';

  @override
  String get userBlocked => 'User blocked';

  @override
  String get userUnblocked => 'User unblocked';

  @override
  String blockedOn(String date) {
    return 'Blocked on $date';
  }

  @override
  String get security => 'Security';

  @override
  String get keyBackup => 'Key backup';

  @override
  String get keyBackupSubtitle => 'Protect your encrypted messages';

  @override
  String get connectedDevices => 'Connected devices';

  @override
  String get connectedDevicesSubtitle => 'Manage your devices (max 5)';

  @override
  String get endToEndEncryption => 'End-to-end encryption';

  @override
  String get e2eeDescription =>
      'Your messages are end-to-end encrypted. Only you and your recipients can read them.';

  @override
  String get createBackup => 'Create backup';

  @override
  String get restoreBackup => 'Restore backup';

  @override
  String get passphrase => 'Passphrase';

  @override
  String get passphraseHint => 'Minimum 8 characters';

  @override
  String get confirmPassphrase => 'Confirm passphrase';

  @override
  String get generatePassphrase => 'Generate secure passphrase';

  @override
  String get passphraseStrength => 'Strength';

  @override
  String get weak => 'Weak';

  @override
  String get medium => 'Medium';

  @override
  String get strong => 'Strong';

  @override
  String get backupCreated => 'Backup created successfully';

  @override
  String get backupRestored => 'Keys restored successfully';

  @override
  String get invalidPassphrase => 'Invalid passphrase';

  @override
  String get noBackupFound => 'No backup found';

  @override
  String get deleteBackup => 'Delete backup';

  @override
  String get deleteBackupWarning =>
      'This action is irreversible. If you lose your keys and don\'t have a backup, you won\'t be able to read your old messages.';

  @override
  String get existingBackup => 'Existing backup';

  @override
  String get backupActive => 'Backup active';

  @override
  String get restoreOnDevice => 'Restore on this device';

  @override
  String get enterPassphrase => 'Enter your passphrase to restore your keys';

  @override
  String get passphraseWarning =>
      'Don\'t forget your passphrase! Without it, your keys cannot be restored.';

  @override
  String get deviceManagement => 'Device management';

  @override
  String get deviceManagementInfo =>
      'You can have up to 5 devices connected simultaneously. Each device has its own encryption keys.';

  @override
  String get noDevices => 'No registered devices';

  @override
  String get noDevicesDescription =>
      'Devices using end-to-end encryption will appear here.';

  @override
  String get thisDevice => 'This device';

  @override
  String get renameDevice => 'Rename';

  @override
  String get revokeDevice => 'Revoke';

  @override
  String get revokeDeviceTitle => 'Revoke device?';

  @override
  String get revokeDeviceWarning =>
      'This device will no longer be able to send or receive encrypted messages. The keys for this device will be deleted.';

  @override
  String get deviceRenamed => 'Device renamed';

  @override
  String get deviceRevoked => 'Device revoked';

  @override
  String get deviceLimitReached => 'Limit reached';

  @override
  String get fingerprint => 'Fingerprint';

  @override
  String get online => 'Online';

  @override
  String get application => 'Application';

  @override
  String get theme => 'Theme';

  @override
  String get light => 'Light';

  @override
  String get dark => 'Dark';

  @override
  String get system => 'System';

  @override
  String get chooseTheme => 'Choose theme';

  @override
  String get language => 'Language';

  @override
  String get french => 'Français';

  @override
  String get english => 'English';

  @override
  String get chooseLanguage => 'Choose language';

  @override
  String get helpAndSupport => 'Help & Support';

  @override
  String get contactUs => 'Contact us';

  @override
  String get reportBug => 'Report a bug';

  @override
  String get giveFeedback => 'Give feedback';

  @override
  String get bugReportTitle => 'Report a bug';

  @override
  String get bugDescription => 'Bug description';

  @override
  String get bugDescriptionHint => 'Describe the issue you encountered...';

  @override
  String get stepsToReproduce => 'Steps to reproduce (optional)';

  @override
  String get stepsHint => '1. Open the app\n2. ...';

  @override
  String get send => 'Send';

  @override
  String get bugReportSent => 'Bug report sent';

  @override
  String get feedbackSent => 'Thank you for your feedback!';

  @override
  String get about => 'About';

  @override
  String get version => 'Version';

  @override
  String get lastUpdate => 'Last update';

  @override
  String versionInfo(String version, String date) {
    return 'Version $version - Last update: $date';
  }

  @override
  String get appDescription => 'A platform connecting the Nigerien diaspora.';

  @override
  String get termsOfService => 'Terms of Service';

  @override
  String get privacyPolicy => 'Privacy Policy';

  @override
  String get codeOfConduct => 'Code of Conduct';

  @override
  String get legalDocumentsTitle => 'Legal documents';

  @override
  String get legalEssentialsTitle => 'The essentials';

  @override
  String legalReadingTime(int minutes) {
    return '≈ $minutes min read';
  }

  @override
  String get legalUpdateTitle => 'Terms update';

  @override
  String get legalUpdateDescription =>
      'Our terms of service and/or privacy policy have been updated. Please read and accept them to continue using the app.';

  @override
  String get summaryOfChanges => 'Summary of changes:';

  @override
  String get iAcceptThe => 'I accept the ';

  @override
  String get iAccept => 'I accept the ';

  @override
  String get acceptAndContinue => 'Accept and continue';

  @override
  String get dangerZone => 'Account actions';

  @override
  String get logout => 'Logout';

  @override
  String get deleteAccount => 'Delete my account';

  @override
  String get confirmLogout => 'Do you really want to log out?';

  @override
  String get confirmDeleteAccount => 'Delete account';

  @override
  String get deleteAccountWarning =>
      'This action is irreversible. All your data will be permanently deleted.\n\nThis includes:\n• Your profile and personal information\n• Your conversations and messages\n• Your created events\n• Your group memberships';

  @override
  String unreadConversations(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count unread',
      one: '1 unread',
      zero: 'No unread',
    );
    return '$_temp0';
  }

  @override
  String get exportMyData => 'Export my data';

  @override
  String get exportMyDataSubtitle => 'Download a copy of your data (GDPR)';

  @override
  String get exportMyDataPreparing => 'Preparing your export…';

  @override
  String get exportMyDataFailed => 'Export failed';

  @override
  String get continueAction => 'Continue';

  @override
  String get finalConfirmation => 'Final confirmation';

  @override
  String get typeDeleteToConfirm =>
      'To confirm deletion, type \"DELETE\" below:';

  @override
  String get deleteKeyword => 'DELETE';

  @override
  String get deletePermanently => 'Delete permanently';

  @override
  String get deletingAccount => 'Deleting account...';

  @override
  String get accountDeleted => 'Your account has been successfully deleted';

  @override
  String get deleteError =>
      'Error during deletion. Please log in again and retry.';

  @override
  String get cancel => 'Cancel';

  @override
  String get confirm => 'Confirm';

  @override
  String get save => 'Save';

  @override
  String get close => 'Close';

  @override
  String get error => 'Error';

  @override
  String get success => 'Success';

  @override
  String get history => 'History';

  @override
  String get loading => 'Loading...';

  @override
  String get conversationOptions => 'Conversation options';

  @override
  String get mute => 'Mute';

  @override
  String get unmute => 'Unmute';

  @override
  String get muteConversation => 'Conversation muted';

  @override
  String get unmuteConversation => 'Notifications enabled';

  @override
  String get archive => 'Archive';

  @override
  String get unarchive => 'Unarchive';

  @override
  String get archiveConversation => 'Conversation archived';

  @override
  String get unarchiveConversation => 'Conversation unarchived';

  @override
  String get deleteConversation => 'Delete conversation';

  @override
  String get deleteConversations => 'Delete conversations';

  @override
  String get confirmDeleteConversation =>
      'Do you really want to delete this conversation? This action cannot be undone.';

  @override
  String confirmDeleteMultipleConversations(int count) {
    return 'Do you really want to delete $count conversations? This action cannot be undone.';
  }

  @override
  String selectedCount(int count) {
    return '$count selected';
  }

  @override
  String conversationsDeleted(int count) {
    return '$count conversation(s) deleted';
  }

  @override
  String get select => 'Select';

  @override
  String get deleteForMe => 'Delete for me';

  @override
  String get deleteForEveryone => 'Delete for everyone';

  @override
  String get conversationDeleted => 'Conversation deleted';

  @override
  String get changeWallpaper => 'Change wallpaper';

  @override
  String get blockUserTitle => 'Block user';

  @override
  String get unblockUserTitle => 'Unblock user';

  @override
  String confirmBlockUser(String userName) {
    return 'Do you really want to block $userName? You will no longer receive messages from them.';
  }

  @override
  String confirmUnblockUser(String userName) {
    return 'Do you really want to unblock $userName?';
  }

  @override
  String get block => 'Block';

  @override
  String get unblockUser => 'Unblock user';

  @override
  String get blockError => 'Error while blocking';

  @override
  String get unblockError => 'Error while unblocking';

  @override
  String get reportConversation => 'Report';

  @override
  String get reportReason => 'Reason for report';

  @override
  String get spam => 'Spam';

  @override
  String get harassment => 'Harassment';

  @override
  String get inappropriateContent => 'Inappropriate content';

  @override
  String get other => 'Other';

  @override
  String get reportSent => 'Report sent';

  @override
  String get reportDescription => 'Description (optional)';

  @override
  String get messagesTitle => 'Messages';

  @override
  String get archives => 'Archives';

  @override
  String get searchPlaceholder => 'Search...';

  @override
  String get noConversation => 'No conversation';

  @override
  String get startChatting => 'Start chatting with diaspora members';

  @override
  String get newConversation => 'New conversation';

  @override
  String noResults(String query) {
    return 'No results for \"$query\"';
  }

  @override
  String get noArchivedConversation => 'No archived conversation';

  @override
  String get noUnreadMessages => 'No unread messages';

  @override
  String get noGroupConversations => 'No group conversations';

  @override
  String get showAllConversations => 'Show all conversations';

  @override
  String get messageRequests => 'Requests';

  @override
  String get wantsToMessageYou => 'wants to message you';

  @override
  String get acceptRequest => 'Accept';

  @override
  String get declineRequest => 'Decline';

  @override
  String get requestPending => 'Request pending';

  @override
  String get requestAccepted => 'Request accepted';

  @override
  String get requestDeclined => 'Request declined';

  @override
  String get commonGroups => 'Groups in common';

  @override
  String get noCommonGroups => 'No groups in common';

  @override
  String get unknownCaller => 'Unknown caller';

  @override
  String get callerNotInContacts => 'This caller is not in your contacts';

  @override
  String get sendMessageRequest => 'Send message request?';

  @override
  String get personNotInContacts =>
      'This person is not in your contacts. They will need to accept your request before seeing your messages.';

  @override
  String get noMessageRequests => 'No message requests';

  @override
  String get loadingError => 'Loading error';

  @override
  String get retry => 'Retry';

  @override
  String get messageNotSent => 'Not sent';

  @override
  String get receiptSent => 'Sent';

  @override
  String get receiptDelivered => 'Delivered';

  @override
  String get receiptRead => 'Read';

  @override
  String get receiptSending => 'Sending…';

  @override
  String seenByCount(int count) {
    return 'Seen by $count';
  }

  @override
  String get noMessages => 'No messages';

  @override
  String get sendFirstMessage => 'Send the first message!';

  @override
  String get group => 'Group';

  @override
  String get conversation => 'Conversation';

  @override
  String get newConversationTitle => 'New conversation';

  @override
  String get start => 'Start';

  @override
  String get searchMember => 'Search for a member...';

  @override
  String createGroupWith(int count) {
    return 'Create a group with $count members';
  }

  @override
  String get groupName => 'Group name';

  @override
  String get enterGroupName => 'Enter group name';

  @override
  String get create => 'Create';

  @override
  String get searchAMember => 'Search for a member';

  @override
  String get enterAtLeast2Chars => 'Enter at least 2 characters';

  @override
  String get user => 'User';

  @override
  String get eventsTitle => 'Events';

  @override
  String get upcoming => 'Upcoming';

  @override
  String get past => 'Past';

  @override
  String get noPastEvents => 'No past events';

  @override
  String get all => 'All';

  @override
  String get noUpcomingEvents => 'No upcoming events';

  @override
  String get eventsNearMe => 'Near me';

  @override
  String get eventsOnline => 'Online';

  @override
  String get eventsFree => 'Free';

  @override
  String participants(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count participants',
      one: '1 participant',
      zero: 'No participants',
    );
    return '$_temp0';
  }

  @override
  String get seeMore => 'See more';

  @override
  String get createEvent => 'Create event';

  @override
  String get eventDetails => 'Event details';

  @override
  String get join => 'Join';

  @override
  String get leave => 'Leave';

  @override
  String get joined => 'Joined';

  @override
  String get organizedBy => 'Organized by';

  @override
  String get organizer => 'Organizer';

  @override
  String get aboutEvent => 'About';

  @override
  String startingFrom(String time) {
    return 'Starting from $time';
  }

  @override
  String get noParticipantsYet => 'No participants yet';

  @override
  String othersMore(int count) {
    return '+$count others';
  }

  @override
  String get delete => 'Delete';

  @override
  String get edit => 'Edit';

  @override
  String get participate => 'Participate';

  @override
  String get full => 'Full';

  @override
  String get eventFree => 'Free';

  @override
  String get eventPaid => 'Paid';

  @override
  String get eventPriceOptional => 'Ticket price (optional)';

  @override
  String get eventPriceHint => '0 = free';

  @override
  String get eventPriceFreeHelper => 'Leave at 0 for a free event';

  @override
  String get registrationConfirmed => 'Registration confirmed!';

  @override
  String get registered => 'Registered';

  @override
  String get cancelParticipation => 'Cancel participation';

  @override
  String get cancelParticipationConfirm =>
      'Do you really want to cancel your participation?';

  @override
  String get no => 'No';

  @override
  String get yesCancel => 'Yes, cancel';

  @override
  String get participationCancelled => 'Participation cancelled';

  @override
  String get deleteEvent => 'Delete event';

  @override
  String get deleteEventConfirm =>
      'Do you really want to delete this event? This action cannot be undone.';

  @override
  String get eventDeleted => 'Event deleted';

  @override
  String get addedToCalendar => 'Event added to calendar';

  @override
  String get cannotAddToCalendar => 'Cannot add to calendar';

  @override
  String get calendar => 'Calendar';

  @override
  String get eventCategoryCultural => 'Cultural';

  @override
  String get eventCategoryProfessional => 'Professional';

  @override
  String get eventCategorySocial => 'Social';

  @override
  String get eventCategorySport => 'Sport';

  @override
  String get eventCategoryOther => 'Other';

  @override
  String get groupsTitle => 'Groups';

  @override
  String get noGroups => 'No groups';

  @override
  String get myGroups => 'My groups';

  @override
  String get searchGroup => 'Search for a group...';

  @override
  String get noJoinedGroups => 'You haven\'t joined any group';

  @override
  String get faqEncryptionQ => 'Are my messages protected?';

  @override
  String get faqEncryptionA =>
      'Yes. Your conversations are end-to-end encrypted: only you and your correspondents can read them.';

  @override
  String get faqLocationQ => 'Who sees my location on the map?';

  @override
  String get faqLocationA =>
      'Only members whose location you also see (reciprocity). You can turn it off at any time, and blocked accounts never see you.';

  @override
  String get faqReportQ => 'How do I report content?';

  @override
  String get faqReportA =>
      'Open the menu of a message or post, then \"Report\". Your report is anonymous.';

  @override
  String get faqTransferQ => 'How long does a transfer take?';

  @override
  String get faqTransferA =>
      'Transfers are usually available within 24h. Fees are shown before you confirm.';

  @override
  String get pinnedSection => 'Pinned';

  @override
  String get otherConversations => 'Others';

  @override
  String get emptyMessagesJoinGroup => 'Join a group in your city';

  @override
  String get emptyGroupsUsage =>
      'Groups bring the diaspora together by city, interest or project. Join one or create your own.';

  @override
  String get noGroupsToDiscover => 'No new groups to discover';

  @override
  String get groupsNoneInYourAreaTitle => 'Nothing in your area yet';

  @override
  String get groupsNoneInYourAreaBody =>
      'No group matches your country of residence or your region of origin yet. You can start the first one, or widen your search.';

  @override
  String get groupsBrowseAll => 'Browse all groups';

  @override
  String searchNoResultsFor(String query) {
    return 'No results for “$query”';
  }

  @override
  String get searchTipsTitle => 'A few things to try';

  @override
  String get searchTipSpelling => 'Check the spelling';

  @override
  String get searchTipFewerWords => 'Try fewer words, or a broader term';

  @override
  String get searchTipRemoveFilters =>
      'Clear active filters to widen the search';

  @override
  String get searchClearFilters => 'Clear filters';

  @override
  String get marketplaceSellItem => 'Sell an item';

  @override
  String get mapEmptyAreaTitle => 'Nothing in this area';

  @override
  String get mapEmptyAreaBody =>
      'No members, businesses or embassies to show here. Widen the view or turn on another layer.';

  @override
  String get mapZoomOut => 'Zoom out';

  @override
  String get mapShowEmbassies => 'Show embassies';

  @override
  String scheduleRoomOnDate(String date, String time) {
    return '📅 Schedule for $date at $time';
  }

  @override
  String get scheduleRoomTitleLabel => 'Room title';

  @override
  String get scheduleRoomTitleHint => 'What will you talk about?';

  @override
  String get audioRoomTicketAction => 'Ticket';

  @override
  String ghostModerationHeader(String duration) {
    return 'MODERATION · $duration';
  }

  @override
  String get ghostWarnHost => 'Warn the host';

  @override
  String get audioRoomPrivateRoomHint =>
      'Only invited people will be able to enter.';

  @override
  String get audioRoomVideoEnabledHint =>
      'Speakers will be able to turn their camera on.';

  @override
  String get audioRoomEnableRecordingHint =>
      'The room can be republished as a podcast afterwards.';

  @override
  String get audioRoomPaidRoomHint => 'Entry requires buying a ticket.';

  @override
  String get audioRoomEnableFundraisingHint =>
      'A fundraising bar is shown during the room.';

  @override
  String get audioRoomHeritageContentHint =>
      'The room is archived in the heritage library.';

  @override
  String get audioRoomScheduleAction => 'Schedule';

  @override
  String get scheduleRoomIntro =>
      'Pick a slot that works for everyone: the time is converted into each member\'s own timezone.';

  @override
  String get scheduleMembersLocalTime => 'MEMBERS\' LOCAL TIME';

  @override
  String get scheduleRemindMe => 'Remind me';

  @override
  String get scheduleRemindMeHint => 'Notification 15 min before it starts.';

  @override
  String get scheduleSlotEvening => 'Good time · evening';

  @override
  String get scheduleSlotMidday => 'Midday · during the day';

  @override
  String get scheduleSlotMorning => 'Morning · just waking up';

  @override
  String get scheduleSlotNight => 'Late · likely night';

  @override
  String get audioRoomHeritageArchivedNote => 'this room will be archived';

  @override
  String get audioRoomInviteCoHostTitle => 'Name a co-host';

  @override
  String audioRoomCoHostAdded(String name) {
    return '$name is now a co-host';
  }

  @override
  String get audioRoomHandsRaisedLabel => 'Raised hands';

  @override
  String get audioRoomStatsLiveNote => 'Current values — no history is kept.';

  @override
  String heritageRecordingsCount(int count) {
    return '$count RECORDINGS';
  }

  @override
  String get heritageDownloadHint =>
      'Download before a trip: recordings stay listenable without a connection.';

  @override
  String get homeSeeOnlineEvents => 'See online events';

  @override
  String get homeCreateEvent => 'Create';

  @override
  String get podcastsSortRecent => 'Newest first';

  @override
  String get podcastsSortOldest => 'Oldest first';

  @override
  String get savePodcastHeritageNote =>
      'A heritage room also stays in the heritage library, even once published as a podcast.';

  @override
  String podcastsHomeSubtitle(int subscriptions, int inProgress) {
    return '$subscriptions subscriptions · $inProgress in progress';
  }

  @override
  String get audioRoomSeeAllListeners => 'See all';

  @override
  String audioRoomHandsRaisedCount(int count) {
    return '$count hands raised';
  }

  @override
  String audioRoomElapsedMinutes(int minutes) {
    return '$minutes MIN';
  }

  @override
  String audioRoomElapsedHours(int hours, int minutes) {
    return '$hours H $minutes MIN';
  }

  @override
  String podcastFrequencyAndPrice(String frequency, String price) {
    return '$frequency · $price/month';
  }

  @override
  String get podcastViewSheet => 'View page';

  @override
  String get podcastsDiasporaVoicesTitle => 'Voices from the diaspora';

  @override
  String get podcastsPopularInDiaspora => 'POPULAR IN THE DIASPORA';

  @override
  String get podcastsCreateMine => 'Create my podcast';

  @override
  String marketplaceSearchEverywhere(int count) {
    return 'Search everywhere · $count';
  }

  @override
  String get marketplaceAlertMe => 'Alert me if it shows up';

  @override
  String marketplaceAlertSaved(String query) {
    return 'Alert saved for “$query”. You\'ll get a notification as soon as an item matches.';
  }

  @override
  String get marketplaceNoProductsTitle => 'Nothing on sale yet';

  @override
  String get marketplaceNoProductsHint =>
      'Be the first to offer something to the diaspora.';

  @override
  String get myProductsEmptyHint => 'Pick a category to get started:';

  @override
  String get ordersEmptyEscrowNote =>
      'Payments are held in escrow until delivery is confirmed.';

  @override
  String groupsSeeSuggested(int count) {
    return 'See the $count suggested groups';
  }

  @override
  String searchCreateNamed(String query) {
    return 'Create “$query”';
  }

  @override
  String get reconnectedTitle => 'Back online';

  @override
  String reconnectedAfter(String duration) {
    return 'Outage of $duration';
  }

  @override
  String get reconnectedSentSection => 'Sent first';

  @override
  String get reconnectedReceivedSection => 'Received while you were away';

  @override
  String get reconnectedOutcomeSent => 'Sent';

  @override
  String get reconnectedOutcomeRetrying => 'Will be resent';

  @override
  String get reconnectedOutcomeAbandoned => 'Given up after 3 attempts';

  @override
  String reconnectedAbandonedWarning(int count) {
    return '$count item(s) could not be sent and were given up. You\'ll need to redo them by hand.';
  }

  @override
  String reconnectedUnreadMessages(int count) {
    return '$count unread message(s)';
  }

  @override
  String reconnectedUnreadNotifications(int count) {
    return '$count notification(s)';
  }

  @override
  String get reconnectedNothingReceived => 'Nothing new.';

  @override
  String get reconnectedActionCreate => 'Creation';

  @override
  String get reconnectedActionUpdate => 'Update';

  @override
  String get reconnectedActionDelete => 'Deletion';

  @override
  String get feedPostNotSent => 'Post not sent';

  @override
  String get feedPostNotSentHint => 'Your text is kept here. Nothing is lost.';

  @override
  String get feedPostDiscard => 'Discard';

  @override
  String get feedErrorNoConnectionTitle => 'No connection';

  @override
  String get feedErrorNoConnectionBody =>
      'Your phone isn\'t on any network. The feed will reload as soon as the connection is back.';

  @override
  String get feedErrorServerTitle => 'Our servers aren\'t responding';

  @override
  String get feedErrorServerBody =>
      'This is on us, not on you. Retrying automatically.';

  @override
  String feedErrorServerCountdown(int seconds) {
    return 'Retrying in $seconds s';
  }

  @override
  String get feedErrorSlowTitle => 'Network too slow';

  @override
  String get feedErrorSlowBody =>
      'The connection didn\'t hold long enough to load the feed. Try again, or wait for a better network.';

  @override
  String get feedErrorUnknownTitle => 'The feed couldn\'t load';

  @override
  String get feedErrorUnknownBody => 'An unexpected error occurred.';

  @override
  String feedCachedNotice(String when) {
    return 'Offline feed · last updated $when';
  }

  @override
  String get feedCachedNoticeUnknownTime =>
      'Offline feed · posts already loaded';

  @override
  String audioRoomsLiveAndScheduled(int live, int scheduled) {
    return '$live live · $scheduled scheduled';
  }

  @override
  String get audioRoomOpenRoom => 'Open a room';

  @override
  String get audioRoomOpenRoomHint =>
      'Start a live conversation, alone or with others.';

  @override
  String get heritageOralTitle => 'Oral heritage';

  @override
  String get heritageOralHint =>
      'Tales, proverbs and memory, listenable even offline.';

  @override
  String get transferFailOperatorBlockedTitle => 'Blocked by the operator';

  @override
  String get transferFailOperatorBlockedDesc =>
      'The recipient\'s operator refused to credit the account (limit reached, missing ID documents, or frozen account).';

  @override
  String get transferFailDuplicateTitle => 'Duplicate prevented';

  @override
  String get transferFailDuplicateDesc =>
      'An identical transfer was already in progress. This one was stopped before any charge so you are not billed twice.';

  @override
  String get transferFailInvalidRecipientTitle => 'Recipient not found';

  @override
  String get transferFailInvalidRecipientDesc =>
      'The number or wallet you entered does not exist at the operator.';

  @override
  String get transferFailDeclinedTitle => 'Payment declined';

  @override
  String get transferFailDeclinedDesc =>
      'Your bank declined the payment. This refusal comes from the card issuer, not from the app.';

  @override
  String get transferFailInsufficientTitle => 'Insufficient funds';

  @override
  String get transferFailInsufficientDesc =>
      'The payment method did not have enough funds to cover the amount and the fee.';

  @override
  String get transferFailTimeoutTitle => 'Processing interrupted';

  @override
  String get transferFailTimeoutDesc =>
      'The connection dropped during processing. The outcome is not known yet.';

  @override
  String get transferDebitNotCharged => 'Nothing was charged.';

  @override
  String get transferDebitCharged =>
      'The amount was charged and has not been returned yet.';

  @override
  String get transferDebitUncertain =>
      'We don\'t know yet whether you were charged — don\'t resend the transfer before checking.';

  @override
  String get transferActionFixRecipient => 'Fix the recipient';

  @override
  String get audioRoomReconnecting => 'Reconnecting…';

  @override
  String get audioRoomReconnectingHint =>
      'Audio is off while we find the room again.';

  @override
  String get audioRoomAudioLost => 'Audio connection lost';

  @override
  String get audioRoomAudioLostHint =>
      'You are still in the room, but you can\'t hear anyone.';

  @override
  String get podcastRecordMicTitle => 'Record with the mic';

  @override
  String get podcastRecordMicHint => 'Or record straight from the phone.';

  @override
  String get podcastRecordStart => 'Record';

  @override
  String get podcastRecordStop => 'Finish';

  @override
  String get podcastRecordPause => 'Pause';

  @override
  String get podcastRecordResume => 'Resume';

  @override
  String get podcastRecordDiscard => 'Discard recording';

  @override
  String get podcastRecordPermissionDenied =>
      'Microphone access denied. Allow the microphone in your phone settings.';

  @override
  String get podcastRecordFailed => 'The recording could not be saved.';

  @override
  String get podcastRecordedFileName => 'Mic recording';

  @override
  String get podcastStatsTitle => 'Statistics';

  @override
  String get podcastStatsTotalPlays => 'Plays';

  @override
  String get podcastStatsSubscribers => 'Subscribers';

  @override
  String get podcastStatsEpisodes => 'Episodes';

  @override
  String get podcastStatsTotalDuration => 'Published duration';

  @override
  String get podcastStatsEngagementTitle => 'Engagement';

  @override
  String get podcastStatsLikes => 'Likes';

  @override
  String get podcastStatsShares => 'Shares';

  @override
  String get podcastStatsDownloads => 'Downloads';

  @override
  String get podcastStatsAvgPlaysPerEpisode => 'Average per episode';

  @override
  String get podcastStatsTopEpisodesTitle => 'Most played episodes';

  @override
  String get podcastStatsRhythmTitle => 'Publishing rhythm';

  @override
  String get podcastStatsLastEpisode => 'Latest episode';

  @override
  String get podcastStatsAvgInterval => 'Average interval';

  @override
  String podcastStatsIntervalDays(int days) {
    return '$days days';
  }

  @override
  String get podcastStatsNoData =>
      'No episode published yet — nothing to measure.';

  @override
  String get podcastStatsNoHistoryNote =>
      'These are cumulative totals. The app does not keep dated history, so no change over time can be shown.';

  @override
  String podcastStatsPlaysCount(int count) {
    return '$count plays';
  }

  @override
  String get groupJoined => 'You have joined the group';

  @override
  String get leaveGroupTitle => 'Leave group';

  @override
  String get leaveGroupConfirm => 'Do you really want to leave this group?';

  @override
  String get groupLeft => 'You have left the group';

  @override
  String get member => 'Member';

  @override
  String get joinGroup => 'Join';

  @override
  String get shareGroup => 'Share group';

  @override
  String get shareVia => 'Share via';

  @override
  String get scanToJoin => 'Scan to join';

  @override
  String joinGroupInvite(String groupName, String link) {
    return 'Join the group \"$groupName\" on Diaspo Niger: $link';
  }

  @override
  String get deletedUser => 'Deleted user';

  @override
  String sharePostMessage(String authorName, String preview, String link) {
    return '$authorName on Diaspo Niger:\n\n$preview\n\n$link';
  }

  @override
  String get leaveGroup => 'Leave';

  @override
  String members(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count members',
      one: '1 member',
      zero: 'No members',
    );
    return '$_temp0';
  }

  @override
  String get createGroup => 'Create group';

  @override
  String get groupDetails => 'Group details';

  @override
  String get groupDescription => 'Group description';

  @override
  String get admins => 'Admins';

  @override
  String get private => 'Private';

  @override
  String get public => 'Public';

  @override
  String get access => 'Access';

  @override
  String get aboutGroup => 'About';

  @override
  String createdBy(String name) {
    return 'Created by $name';
  }

  @override
  String get creator => 'Creator';

  @override
  String get noOtherMembers => 'No other members yet';

  @override
  String get discussion => 'Discussion';

  @override
  String get joinTheGroup => 'Join the group';

  @override
  String get errorOpeningDiscussion => 'Error opening discussion';

  @override
  String get friendsTitle => 'Friends';

  @override
  String get friends => 'Friends';

  @override
  String get received => 'Received';

  @override
  String get sent => 'Sent';

  @override
  String get noFriends => 'No friends';

  @override
  String get noFriendsHint => 'Start adding friends to see them here';

  @override
  String get noRequests => 'No requests';

  @override
  String get receivedRequestsHint =>
      'Received friend requests will appear here';

  @override
  String get sentRequestsHint => 'Sent friend requests will appear here';

  @override
  String get sendMessage => 'Send message';

  @override
  String get cancelRequest => 'Cancel request';

  @override
  String get removeFriend => 'Remove friend';

  @override
  String get removeFriendConfirm =>
      'Do you really want to remove this person from your friends?';

  @override
  String get friendRemoved => 'Friend removed';

  @override
  String get requestCancelled => 'Request cancelled';

  @override
  String get profileTitle => 'Profile';

  @override
  String get editProfileTitle => 'Edit profile';

  @override
  String get firstName => 'First name';

  @override
  String get lastName => 'Last name';

  @override
  String get bio => 'Bio';

  @override
  String get profession => 'Profession';

  @override
  String get city => 'City';

  @override
  String get country => 'Country';

  @override
  String get phoneNumber => 'Phone number';

  @override
  String get saveChanges => 'Save changes';

  @override
  String get profileUpdated => 'Profile updated';

  @override
  String get profileUpdatedSuccess => 'Profile updated successfully';

  @override
  String get changePhoto => 'Change photo';

  @override
  String get basicInfo => 'Basic information';

  @override
  String get fullName => 'Full name';

  @override
  String get enterYourName => 'Please enter your name';

  @override
  String get phone => 'Phone';

  @override
  String get location => 'Location';

  @override
  String get currentCity => 'Current city';

  @override
  String get originCity => 'City of origin in Niger';

  @override
  String get interests => 'Interests';

  @override
  String get spokenLanguages => 'Spoken languages';

  @override
  String get spokenLanguagesEmptyAction => 'Choose my languages';

  @override
  String get interestsEmptyAction => 'Choose my interests';

  @override
  String get otherMembersCanSee => 'Other members can see your profile';

  @override
  String get connections => 'Connections';

  @override
  String get myLocation => 'My location';

  @override
  String get preferences => 'Preferences';

  @override
  String get darkTheme => 'Dark theme';

  @override
  String get disabled => 'Disabled';

  @override
  String get helpFaq => 'Help & FAQ';

  @override
  String get homeTitle => 'Home';

  @override
  String get discover => 'Discover';

  @override
  String get welcome => 'Welcome';

  @override
  String get hello => 'Hello';

  @override
  String get membersLabel => 'Members';

  @override
  String get membersNearby => 'Members nearby';

  @override
  String get aroundYou => 'Around you';

  @override
  String get theMap => 'The map';

  @override
  String get noMembersNearby => 'No members nearby';

  @override
  String get enableNearbyMembers => 'Enable nearby members';

  @override
  String get disableNearbyMembers => 'Disable nearby members';

  @override
  String get nearbyMembersDisabled => 'Private mode enabled';

  @override
  String get nearbyMembersDisabledHint =>
      'Turn on to see nearby members and appear on their map';

  @override
  String get searchMembersGroups => 'Search for a member, a group…';

  @override
  String get createOrJoinEvents => 'Create or join events';

  @override
  String get upcomingEvents => 'Upcoming events';

  @override
  String get popularGroups => 'Popular groups';

  @override
  String get recentMembers => 'Recent members';

  @override
  String get seeAll => 'See all';

  @override
  String get mapTitle => 'Map';

  @override
  String get searchTitle => 'Search';

  @override
  String get notificationsTitle => 'Notifications';

  @override
  String get noNotifications => 'No notifications';

  @override
  String get noNotificationsHint => 'You will be notified of new activities';

  @override
  String get markAllAsRead => 'Mark all as read';

  @override
  String get deleteAll => 'Delete all';

  @override
  String get deleteAllNotifications => 'Delete all notifications';

  @override
  String get deleteAllNotificationsConfirm =>
      'Do you really want to delete all your notifications?';

  @override
  String get justNow => 'Just now';

  @override
  String secondsAgo(int count) {
    return '$count s ago';
  }

  @override
  String minutesAgo(int count) {
    return '$count minute(s) ago';
  }

  @override
  String hoursAgo(int count) {
    return '$count hour(s) ago';
  }

  @override
  String daysAgo(int count) {
    return '$count day(s) ago';
  }

  @override
  String weeksAgo(int count) {
    return '$count week(s) ago';
  }

  @override
  String monthsAgo(int count) {
    return '$count month(s) ago';
  }

  @override
  String yearsAgo(int count) {
    return '$count year(s) ago';
  }

  @override
  String get participantsTitle => 'Participants';

  @override
  String get errorNetwork =>
      'No internet connection. Check your connection and try again.';

  @override
  String get errorServer => 'Server error. Please try again later.';

  @override
  String get errorCache => 'Error reading local data.';

  @override
  String get errorAuth => 'Authentication error. Please sign in again.';

  @override
  String get errorTimeout => 'Request timed out. Please try again.';

  @override
  String get errorUnknown => 'An unexpected error occurred.';

  @override
  String get offlineMode => 'Offline mode';

  @override
  String get offlineBannerMessage =>
      'You are offline. Some features may be limited.';

  @override
  String get syncingLabel => 'Syncing…';

  @override
  String pendingSyncCount(int count) {
    return '$count pending';
  }

  @override
  String retryIn(int seconds) {
    return 'Retry in ${seconds}s';
  }

  @override
  String get connectionRestored => 'Connection restored';

  @override
  String get eventTitle => 'Event title';

  @override
  String get eventTitleRequired => 'Event title *';

  @override
  String get eventTitleHint => 'Ex: Niger entrepreneurs meetup';

  @override
  String get eventTitleRequiredError => 'Title is required';

  @override
  String get eventTitleTooShort => 'Title must be at least 5 characters';

  @override
  String get description => 'Description';

  @override
  String get descriptionRequired => 'Description is required';

  @override
  String get descriptionHint => 'Describe your event...';

  @override
  String get descriptionRequiredError => 'Please enter a description';

  @override
  String get descriptionTooShort =>
      'Description must be at least 20 characters';

  @override
  String get category => 'Category';

  @override
  String get startDateTime => 'Start date and time *';

  @override
  String get endDateTimeOptional => 'End date and time (optional)';

  @override
  String get endDate => 'End date';

  @override
  String get endTime => 'End time';

  @override
  String get onlineEvent => 'Online event';

  @override
  String get onlineEventDescription =>
      'The event takes place via video conference';

  @override
  String get videoConferenceLink => 'Video conference link';

  @override
  String get videoConferenceLinkHint => 'Ex: https://zoom.us/j/...';

  @override
  String get locationRequired => 'Location *';

  @override
  String get locationHint => 'Ex: Paris, France';

  @override
  String get locationRequiredError => 'Location is required';

  @override
  String get addressOptional => 'Address (optional)';

  @override
  String get addressHint => 'Ex: 123 Peace Street';

  @override
  String get maxAttendeesOptional => 'Max attendees (optional)';

  @override
  String get maxAttendeesHint => 'Ex: 50';

  @override
  String get unlimitedAttendees => 'Leave empty for unlimited';

  @override
  String get createEventButton => 'Create event';

  @override
  String get editEvent => 'Edit event';

  @override
  String get saveModifications => 'Save modifications';

  @override
  String get eventCreatedSuccess => 'Event created successfully';

  @override
  String get eventCreationError => 'Error creating event';

  @override
  String get eventUpdatedSuccess => 'Event updated successfully';

  @override
  String get eventUpdateError => 'Error updating event';

  @override
  String get youAreHere => 'You are here';

  @override
  String get viewProfile => 'View profile';

  @override
  String get message => 'Message';

  @override
  String get searchRadius => 'Search radius';

  @override
  String get searchRadiusDescription =>
      'Select maximum distance to find members';

  @override
  String get wholeCountry => 'Whole country';

  @override
  String get everywhere => 'Global';

  @override
  String get everywhereLabel => 'Global';

  @override
  String get countryLabel => 'Country';

  @override
  String get filterAll => 'All';

  @override
  String get filterEntrepreneurs => 'Entrepreneurs';

  @override
  String get filterStudents => 'Students';

  @override
  String get filterProfessionals => 'Professionals';

  @override
  String get filterArtists => 'Artists';

  @override
  String get enableLocationServices => 'Enable location services';

  @override
  String get locationPermissionDenied => 'Location permission denied';

  @override
  String get unableToGetLocation => 'Unable to get location';

  @override
  String get settingsLabel => 'Settings';

  @override
  String get modifyYourInfo => 'Modify your information';

  @override
  String get myFriends => 'My friends';

  @override
  String get manageConnections => 'Manage your connections';

  @override
  String get callHistoryTitle => 'Call history';

  @override
  String get callHistorySubtitle => 'Your past and missed calls';

  @override
  String get shareMyProfile => 'Share my profile';

  @override
  String get qrCodeAndShareLink => 'QR code and share link';

  @override
  String get myNotifications => 'My notifications';

  @override
  String get myNotificationsSubtitle => 'See the alerts you received';

  @override
  String get manageAlerts => 'Manage notifications';

  @override
  String get appearInSearchesDesc => 'Appear in searches';

  @override
  String get appearOnMapDesc => 'Appear on map';

  @override
  String get receiveNotificationsDesc => 'Receive notifications';

  @override
  String get supportEmail => 'support@diasponiger.com';

  @override
  String get helpUsImprove => 'Help us improve the app';

  @override
  String get rateUsOnStore => 'Rate us on the store';

  @override
  String get deleteAccountTitle => 'Delete account';

  @override
  String get filterUnread => 'Unread';

  @override
  String get filterFriends => 'Friends';

  @override
  String get notificationSettings => 'Notification settings';

  @override
  String get notificationsDisabled => 'Notifications disabled';

  @override
  String get notificationsDisabledDesc =>
      'Enable notifications to receive alerts for messages and calls.';

  @override
  String get notificationContent => 'Content';

  @override
  String get notificationAlerts => 'Alerts';

  @override
  String get notificationAdvanced => 'Advanced';

  @override
  String get notifyMessages => 'Messages';

  @override
  String get notifyEvents => 'Events';

  @override
  String get notifyFriendRequests => 'Friend requests';

  @override
  String get notifyGroups => 'Groups';

  @override
  String get notifyEventReminders => 'Event reminders';

  @override
  String get notificationSound => 'Sound';

  @override
  String get notificationVibration => 'Vibration';

  @override
  String get quietHours => 'Quiet hours';

  @override
  String get quietHoursDesc => 'Do not disturb during these hours';

  @override
  String get quietHoursStart => 'Start';

  @override
  String get quietHoursEnd => 'End';

  @override
  String get notificationDetail => 'Notification detail';

  @override
  String get open => 'Open';

  @override
  String get markAsRead => 'Mark as read';

  @override
  String get accountDeletedSuccess =>
      'Your account has been successfully deleted';

  @override
  String get errorDeletingAccount => 'Error deleting account';

  @override
  String get allRightsReserved => '© 2025 Diaspo Niger. All rights reserved.';

  @override
  String get mobileAppDescription =>
      'Mobile platform connecting the Nigerien diaspora.';

  @override
  String get currentCountry => 'Current country';

  @override
  String get originRegion => 'Origin region in Niger (optional)';

  @override
  String get skills => 'Skills';

  @override
  String get languagesSpoken => 'Languages';

  @override
  String get profileNotFound =>
      'Profile not found. Please restart the application.';

  @override
  String get deletedProfile => 'Deleted profile';

  @override
  String get accountNoLongerExists => 'This account no longer exists';

  @override
  String livingIn(String city, String country) {
    return 'Lives in $city, $country';
  }

  @override
  String fromRegion(String region) {
    return 'From $region';
  }

  @override
  String fromCity(String city) {
    return 'From $city';
  }

  @override
  String get scanQRCode => 'Scan QR code';

  @override
  String get scanQRCodeTitle => 'Scan a profile';

  @override
  String get scanQRCodeDescription => 'Place the QR code in the frame to scan';

  @override
  String get qrCodeScanned => 'QR code scanned successfully';

  @override
  String get invalidQRCode => 'Invalid QR code';

  @override
  String get cameraPermissionDenied =>
      'Camera access was denied. Please enable it in app settings.';

  @override
  String get enableFlash => 'Enable flash';

  @override
  String get disableFlash => 'Disable flash';

  @override
  String get switchCamera => 'Switch camera';

  @override
  String systemMessageUserJoined(String userName) {
    return '$userName joined the group';
  }

  @override
  String systemMessageUserLeft(String userName) {
    return '$userName left the group';
  }

  @override
  String systemMessageUserRemoved(String userName) {
    return '$userName was removed from the group';
  }

  @override
  String systemMessageUserPromoted(String userName) {
    return '$userName is now an administrator';
  }

  @override
  String systemMessageUserDemoted(String userName) {
    return '$userName is no longer an administrator';
  }

  @override
  String systemMessageGroupRenamed(String newName) {
    return 'The group has been renamed to $newName';
  }

  @override
  String get audioRoomsTitle => 'Audio Rooms';

  @override
  String get createAudioRoom => 'Create a room';

  @override
  String get scheduleAudioRoom => 'Schedule a room';

  @override
  String get audioRoomTitle => 'Room title *';

  @override
  String get audioRoomTitleHint => 'Ex: Discussion on entrepreneurship';

  @override
  String get audioRoomTitleRequired => 'Please enter a title';

  @override
  String get audioRoomDescription => 'Description';

  @override
  String get audioRoomDescriptionHint => 'What will you talk about?';

  @override
  String get audioRoomCategory => 'Category';

  @override
  String get audioRoomMode => 'Room mode';

  @override
  String get audioRoomPrivate => 'Private room';

  @override
  String get audioRoomPrivateDesc => 'Only invited people can join';

  @override
  String get audioRoomRecording => 'Record the room';

  @override
  String get audioRoomRecordingDesc => 'Allow recording for replay';

  @override
  String get audioRoomPaid => 'Paid room';

  @override
  String get audioRoomPaidDesc => 'Participants must purchase a ticket';

  @override
  String get audioRoomTags => 'Tags';

  @override
  String get audioRoomCreatedSuccess => 'Room created successfully!';

  @override
  String get audioRoomCreationError => 'Error creating room';

  @override
  String audioRoomScheduledSuccess(String date) {
    return 'Room scheduled for $date';
  }

  @override
  String get audioRoomScheduleError => 'Error scheduling room';

  @override
  String get audioRoomDateMustBeFuture => 'The date must be in the future';

  @override
  String get audioRoomOptions => 'Room options';

  @override
  String get audioRoomShare => 'Share room';

  @override
  String get audioRoomCopyLink => 'Copy link';

  @override
  String get audioRoomLinkCopied => 'Link copied to clipboard';

  @override
  String get audioRoomManageRecording => 'Manage recording';

  @override
  String get audioRoomSettings => 'Room settings';

  @override
  String get audioRoomEndRoom => 'End room';

  @override
  String get audioRoomEndRoomConfirm => 'End the room?';

  @override
  String get audioRoomEndRoomWarning =>
      'This action will end the room for all participants. This action cannot be undone.';

  @override
  String get audioRoomReport => 'Report room';

  @override
  String get audioRoomReportSent => 'Report coming soon';

  @override
  String get audioRoomSettingsComingSoon => 'Settings coming soon';

  @override
  String get audioRoomRecordingComingSoon => 'Recording management coming soon';

  @override
  String get audioRoomShareComingSoon => 'Sharing feature coming soon';

  @override
  String get audioRoomLive => 'LIVE';

  @override
  String get audioRoomScheduled => 'Scheduled';

  @override
  String get audioRoomEnded => 'Ended';

  @override
  String audioRoomParticipants(int count) {
    return '$count participants';
  }

  @override
  String audioRoomHostedBy(String name) {
    return 'Hosted by $name';
  }

  @override
  String get audioRoomJoinUs => 'Join us!';

  @override
  String get audioRoomCategoryGeneral => 'General';

  @override
  String get audioRoomCategoryGriot => 'Griot / Stories';

  @override
  String get audioRoomCategorySpirituality => 'Spirituality';

  @override
  String get audioRoomCategoryNews => 'News';

  @override
  String get audioRoomCategoryBusiness => 'Business';

  @override
  String get audioRoomCategoryMentorship => 'Mentorship';

  @override
  String get audioRoomCategoryFamily => 'Family';

  @override
  String get audioRoomCategoryOfficial => 'Official';

  @override
  String get audioRoomCategoryCulture => 'Culture';

  @override
  String get audioRoomCategoryEducation => 'Education';

  @override
  String get audioRoomModeNormal => 'Normal';

  @override
  String get audioRoomModeCeremony => 'Ceremony';

  @override
  String get audioRoomModeRadio => 'Radio';

  @override
  String get audioRoomModeHeritage => 'Heritage';

  @override
  String get audioRoomCollection => 'Collection';

  @override
  String get audioRoomCollectionNone => 'No collection';

  @override
  String get audioRoomCollectionFamilyEvent => 'Family event';

  @override
  String get audioRoomCollectionEmergency => 'Emergency aid';

  @override
  String get audioRoomCollectionCommunityProject => 'Community project';

  @override
  String get audioRoomCollectionAssociationDues => 'Association dues';

  @override
  String get audioRoomCollectionCustom => 'Custom';

  @override
  String get audioRoomCollectionGoal => 'Collection goal';

  @override
  String get audioRoomCollectionDescription => 'Collection description';

  @override
  String get audioRoomCollectionBeneficiary => 'Beneficiary';

  @override
  String get audioRoomHeritageContent => 'Heritage content';

  @override
  String get audioRoomHeritageContentDesc =>
      'Mark as cultural content to preserve';

  @override
  String get audioRoomHeritageLanguage => 'Content language';

  @override
  String get audioRoomHeritageRegion => 'Region of origin';

  @override
  String get audioRoomLinkedContent => 'Link this room to:';

  @override
  String get audioRoomLinkedEvent => 'Event';

  @override
  String get audioRoomLinkedEventNone => 'No linked event';

  @override
  String get audioRoomLinkedGroup => 'Group';

  @override
  String get audioRoomLinkedGroupNone => 'No linked group';

  @override
  String get audioRoomLinkedEmbassy => 'Embassy/Consulate';

  @override
  String get audioRoomLinkedEmbassyNone => 'No linked embassy';

  @override
  String get audioRoomSearchEvent => 'Search for an event...';

  @override
  String get audioRoomSearchGroup => 'Search for a group...';

  @override
  String get audioRoomSearchEmbassy => 'Search for an embassy...';

  @override
  String get audioRoomLinkEvent => 'Link an event';

  @override
  String get audioRoomLinkGroup => 'Link a group';

  @override
  String get audioRoomLinkEmbassy => 'Link an embassy/consulate';

  @override
  String get audioRoomNoEventFound => 'No event found';

  @override
  String get audioRoomNoGroupFound => 'No group found';

  @override
  String get audioRoomNoEmbassyFound => 'No embassy found';

  @override
  String get audioRoomRemove => 'Remove';

  @override
  String get audioRoomSpeakers => 'SPEAKERS';

  @override
  String get audioRoomListeners => 'LISTENERS';

  @override
  String get audioRoomHandsRaised => 'Hands raised';

  @override
  String get audioRoomRaiseHand => 'Raise hand';

  @override
  String get audioRoomLowerHand => 'Lower hand';

  @override
  String get audioRoomLeave => 'Leave';

  @override
  String get audioRoomMute => 'Mute';

  @override
  String get audioRoomUnmute => 'Unmute';

  @override
  String get audioRoomVerified => 'Verified';

  @override
  String get audioRoomNotVerified => 'Not verified';

  @override
  String get audioRoomEmbassy => 'Embassy';

  @override
  String get audioRoomConsulate => 'Consulate';

  @override
  String get audioRoomHeritageLibrary => 'Heritage library';

  @override
  String get audioRoomHeritageDiscover => 'Discover';

  @override
  String get audioRoomHeritageCategories => 'Categories';

  @override
  String get audioRoomHeritageSaved => 'Saved';

  @override
  String get audioRoomBack => 'Back';

  @override
  String get audioRoomAudioRoom => 'Audio Room';

  @override
  String audioRoomPromoteUser(String userName) {
    return 'Promote $userName';
  }

  @override
  String get audioRoomPromoteQuestion =>
      'Do you want to give speaking rights to this user?';

  @override
  String get audioRoomPromote => 'Promote';

  @override
  String get audioRoomEnd => 'End';

  @override
  String get audioRoomCreateRoom => 'Create a room';

  @override
  String get audioRoomBasicInfo => 'Basic information';

  @override
  String get audioRoomTitleLabel => 'Room title *';

  @override
  String get audioRoomTitleHintExample => 'Ex: Niger Tech Discussion';

  @override
  String get audioRoomEnterTitle => 'Please enter a title';

  @override
  String get audioRoomTitleMinLength => 'Title must be at least 3 characters';

  @override
  String get audioRoomPleaseFixErrors =>
      'Please fix the errors before continuing';

  @override
  String get audioRoomDescriptionLabel => 'Description';

  @override
  String get audioRoomDescriptionHintWhat => 'What will you talk about?';

  @override
  String get audioRoomCategoryLabel => 'Category';

  @override
  String get audioRoomModeLabel => 'Room mode';

  @override
  String get audioRoomTagsOptional => 'Tags (optional)';

  @override
  String get audioRoomMaxTags => 'Maximum 3 tags';

  @override
  String get audioRoomFundraising => 'Fundraising';

  @override
  String get audioRoomCulturalHeritage => 'Cultural heritage';

  @override
  String get audioRoomLinks => 'Links';

  @override
  String get audioRoomSettingsLabel => 'Settings';

  @override
  String get audioRoomPrivateRoom => 'Private room';

  @override
  String get audioRoomPrivateRoomDesc => 'Only invited people can join';

  @override
  String get audioRoomEnableRecording => 'Enable recording';

  @override
  String get audioRoomEnableRecordingDesc => 'Room will be recorded for replay';

  @override
  String get audioRoomPaidRoom => 'Paid room';

  @override
  String get audioRoomPaidRoomDesc => 'Participants must purchase a ticket';

  @override
  String get audioRoomCurrencyLabel => 'Currency';

  @override
  String get audioRoomTicketPriceLabel => 'Ticket price';

  @override
  String get audioRoomTicketPriceRequired => 'Please enter the ticket price';

  @override
  String get audioRoomTicketPriceInvalid => 'Price must be a valid number';

  @override
  String get audioRoomMinPrice => 'Minimum price is';

  @override
  String get audioRoomMaxPrice => 'Maximum price is';

  @override
  String get audioRoomCommissionInfoTitle => 'Platform commission';

  @override
  String get audioRoomCommissionLabel => 'Commission';

  @override
  String get audioRoomYouReceive => 'You receive';

  @override
  String get audioRoomEstimatedEarnings => 'Estimated earnings';

  @override
  String get audioRoomCreating => 'Creating...';

  @override
  String get audioRoomStartRoom => 'Start room';

  @override
  String get audioRoomScheduleForLater => 'Schedule for later';

  @override
  String get audioRoomCreatedSuccessfully => 'Room created successfully!';

  @override
  String get audioRoomCreationErrorGeneric => 'Error during creation';

  @override
  String get audioRoomCategoryDiscussion => 'Discussion';

  @override
  String get audioRoomCategoryGriotStory => 'Griot/Story';

  @override
  String get audioRoomCategorySpiritualityLabel => 'Spirituality';

  @override
  String get audioRoomCategoryNewsLabel => 'News';

  @override
  String get audioRoomCategoryBusinessLabel => 'Business';

  @override
  String get audioRoomCategoryMentorshipLabel => 'Mentorship';

  @override
  String get audioRoomCategoryFamilyLabel => 'Family';

  @override
  String get audioRoomCategoryOfficialLabel => 'Official';

  @override
  String get audioRoomCategoryCultureLabel => 'Culture';

  @override
  String get audioRoomCategoryEducationLabel => 'Education';

  @override
  String get audioRoomModeNormalLabel => 'Normal';

  @override
  String get audioRoomModeCeremonyLabel => 'Ceremony';

  @override
  String get audioRoomModeRadioLabel => 'Radio';

  @override
  String get audioRoomModeHeritageLabel => 'Heritage';

  @override
  String get audioRoomCollectionTypeNone => 'None';

  @override
  String get audioRoomCollectionFamilyEventLabel => 'Family event';

  @override
  String get audioRoomCollectionEmergencyAid => 'Emergency aid';

  @override
  String get audioRoomCollectionCommunityProjectLabel => 'Community project';

  @override
  String get audioRoomCollectionDues => 'Dues';

  @override
  String get audioRoomCollectionCustomLabel => 'Custom';

  @override
  String get audioRoomCollectionGoalLabel => 'Goal (XOF)';

  @override
  String get audioRoomCollectionGoalHint => 'Ex: 100000';

  @override
  String get audioRoomCollectionEnterGoal => 'Please enter a goal';

  @override
  String get audioRoomCollectionInvalidAmount => 'Invalid amount';

  @override
  String get audioRoomCollectionBeneficiaryLabel => 'Beneficiary';

  @override
  String get audioRoomCollectionBeneficiaryHint => 'Name of beneficiary';

  @override
  String get audioRoomCollectionDescriptionLabel => 'Collection description';

  @override
  String get audioRoomHeritageContentLabel => 'Heritage content';

  @override
  String get audioRoomHeritageLanguageLabel => 'Language';

  @override
  String get audioRoomHeritageRegionLabel => 'Region of origin';

  @override
  String get audioRoomLinkTo => 'Link this room to:';

  @override
  String get audioRoomEventLabel => 'Event';

  @override
  String get audioRoomNoLinkedEvent => 'No linked event';

  @override
  String get audioRoomGroupLabel => 'Group';

  @override
  String get audioRoomNoLinkedGroup => 'No linked group';

  @override
  String get audioRoomEmbassyConsulate => 'Embassy/Consulate';

  @override
  String get audioRoomNoLinkedEmbassy => 'No linked embassy';

  @override
  String get audioRoomScheduleRoom => 'Schedule a room';

  @override
  String get audioRoomTitleWeeklyExample => 'Ex: Weekly Tech Discussion';

  @override
  String get audioRoomDateAndTime => 'Date and time';

  @override
  String get audioRoomDate => 'Date';

  @override
  String get audioRoomTime => 'Time';

  @override
  String get audioRoomSendReminders => 'Send reminders';

  @override
  String get audioRoomSendRemindersDesc => 'Notify participants 15 min before';

  @override
  String get audioRoomScheduling => 'Scheduling...';

  @override
  String get audioRoomScheduleTheRoom => 'Schedule the room';

  @override
  String get audioRoomPreview => 'Preview';

  @override
  String get audioRoomDateMustBeFutureError => 'Date must be in the future';

  @override
  String audioRoomScheduleSuccessDate(String date) {
    return 'Room scheduled for $date';
  }

  @override
  String get audioRoomScheduleErrorGeneric => 'Error during scheduling';

  @override
  String get audioRoomListTitle => 'Audio Rooms';

  @override
  String get audioRoomCreateTooltip => 'Create a room';

  @override
  String get audioRoomLiveTab => 'Live';

  @override
  String get audioRoomScheduledTab => 'Scheduled';

  @override
  String get audioRoomStartARoom => 'Start a room';

  @override
  String get audioRoomNoLiveRooms => 'No live rooms';

  @override
  String get audioRoomBeFirstToStart => 'Be the first to start a room!';

  @override
  String get audioRoomNoScheduledRooms => 'No scheduled rooms';

  @override
  String get audioRoomScheduleRoomForLater => 'Schedule a room for later';

  @override
  String get audioRoomLoadingError => 'Loading error';

  @override
  String get heritageLibraryTitle => 'Cultural Library';

  @override
  String get heritageLibraryNotAvailable =>
      'The cultural library is not available at the moment.';

  @override
  String get heritageLibraryPreserve =>
      'Preserving our heritage for future generations';

  @override
  String get heritageLibrarySearch => 'Search...';

  @override
  String get heritageLibraryLanguageFilter => 'Language';

  @override
  String get heritageLibraryAllLanguages => 'All languages';

  @override
  String get heritageLibraryRegionFilter => 'Region';

  @override
  String get heritageLibraryAllRegions => 'All regions';

  @override
  String get heritageLibraryDiscoverTab => 'Discover';

  @override
  String get heritageLibraryCategoriesTab => 'Categories';

  @override
  String get heritageLibrarySavedTab => 'Saved';

  @override
  String get heritageLibraryPopular => 'Popular';

  @override
  String get heritageLibraryNoPopularRecordings => 'No popular recordings';

  @override
  String get heritageLibraryRecent => 'Recent';

  @override
  String get heritageLibraryNoRecordingsFound => 'No recordings found';

  @override
  String get heritageLibrarySeeAll => 'See all';

  @override
  String get heritageLibraryNoCategoryRecordings =>
      'No recordings in this category';

  @override
  String get heritageLibraryNoSavedRecordings => 'No saved recordings';

  @override
  String get heritageLibrarySaveHint => 'Tap the bookmark icon to save';

  @override
  String get heritageContentTypeStories => 'Stories';

  @override
  String get heritageContentTypeProverbs => 'Proverbs';

  @override
  String get heritageContentTypeHistory => 'History';

  @override
  String get heritageContentTypeCeremonies => 'Ceremonies';

  @override
  String get heritageContentTypeLanguage => 'Language';

  @override
  String get heritageContentTypeCraft => 'Craft';

  @override
  String get heritageContentTypeRecipes => 'Recipes';

  @override
  String get heritageContentTypeMedicine => 'Medicine';

  @override
  String get heritageContentTypeOther => 'Other';

  @override
  String get callTitle => 'Call';

  @override
  String get callCalling => 'Calling...';

  @override
  String get callConnecting => 'Connecting...';

  @override
  String get callUnableToStart => 'Unable to start the call';

  @override
  String get callMute => 'Mute';

  @override
  String get callUnmute => 'Unmute';

  @override
  String get callSpeaker => 'Speaker';

  @override
  String get callCamera => 'Camera';

  @override
  String get callFlipCamera => 'Flip';

  @override
  String get callHangUp => 'Hang up';

  @override
  String get callEnable => 'Enable';

  @override
  String get callEarpiece => 'Earpiece';

  @override
  String get incomingVideoCall => 'Incoming video call';

  @override
  String get incomingAudioCall => 'Incoming audio call';

  @override
  String get incomingCallStatus => 'Incoming call...';

  @override
  String get callDecline => 'Decline';

  @override
  String get callAccept => 'Accept';

  @override
  String get answerAudioOnly => 'Answer as audio';

  @override
  String get callSwitchToVideo => 'Video';

  @override
  String videoUpgradeRequest(String name) {
    return '$name wants to switch to video';
  }

  @override
  String get videoUpgradeWaiting =>
      'Waiting for the other party to accept video...';

  @override
  String get videoUpgradeDeclined => 'Video request declined';

  @override
  String get buyTicket => 'Buy a ticket';

  @override
  String get buyTicketAcceptTerms => 'Please accept the terms';

  @override
  String get buyTicketPurchaseSuccess => 'Ticket purchased successfully!';

  @override
  String get buyTicketAcceptTermsCheckbox =>
      'I accept the terms of use and refund policy';

  @override
  String buyTicketPay(String price) {
    return 'Pay $price';
  }

  @override
  String get buyTicketSecurePayment => 'Secure payment by Stripe';

  @override
  String get buyTicketTicketPrice => 'Ticket price';

  @override
  String get buyTicketTotal => 'Total to pay';

  @override
  String buyTicketHostedBy(String name) {
    return 'Hosted by $name';
  }

  @override
  String get buyTicketFree => 'Free';

  @override
  String get sendTip => 'Send a tip';

  @override
  String get sendTipChooseAmount => 'Choose an amount';

  @override
  String get sendTipCustomAmount => 'Custom amount';

  @override
  String get sendTipMessageOptional => 'Message (optional)';

  @override
  String get sendTipMessageHint => 'Add a message...';

  @override
  String sendTipSend(String amount) {
    return 'Send $amount';
  }

  @override
  String get sendTipSelectAmount => 'Select an amount';

  @override
  String sendTipSuccess(String amount) {
    return 'Tip of $amount sent!';
  }

  @override
  String get sendTipOther => 'Other';

  @override
  String get sendTipRoleHost => 'Host';

  @override
  String get sendTipRoleCoHost => 'Co-host';

  @override
  String get sendTipRoleSpeaker => 'Speaker';

  @override
  String get sendTipRoleListener => 'Listener';

  @override
  String get shareRoomLiveStatus => 'LIVE';

  @override
  String get shareRoomScheduledStatus => 'Scheduled room';

  @override
  String get shareRoomOnDiaspoNiger => 'on Diaspo Niger';

  @override
  String shareRoomHostedBy(String name) {
    return 'Hosted by $name';
  }

  @override
  String shareRoomParticipantsCount(int count) {
    return '$count participants';
  }

  @override
  String get shareRoomJoinUs => 'Join us!';

  @override
  String get shareRoomLinkCopied => 'Link copied to clipboard';

  @override
  String get podcastsTitle => 'Podcasts';

  @override
  String get podcastsDiscover => 'Discover';

  @override
  String get podcastsCategories => 'Categories';

  @override
  String get podcastsSubscriptions => 'Subscriptions';

  @override
  String get podcastsTrending => 'Trending';

  @override
  String get podcastsLatestEpisodes => 'Latest episodes';

  @override
  String get podcastsAllPodcasts => 'All podcasts';

  @override
  String get podcastsSearch => 'Search podcasts...';

  @override
  String get podcastsNoResults => 'No podcasts found';

  @override
  String get podcastsNoSubscriptions => 'No subscriptions';

  @override
  String get podcastsNoSubscriptionsDesc =>
      'Subscribe to podcasts so you never miss an episode';

  @override
  String get podcastsSubscribe => 'Subscribe';

  @override
  String get podcastsSubscribed => 'Subscribed';

  @override
  String get podcastsUnsubscribe => 'Unsubscribe';

  @override
  String podcastsSubscribers(int count) {
    return '$count subscribers';
  }

  @override
  String podcastsEpisodes(int count) {
    return '$count episodes';
  }

  @override
  String podcastsPlays(int count) {
    return '$count plays';
  }

  @override
  String get podcastsCreatePodcast => 'Create a podcast';

  @override
  String get podcastsMyPodcasts => 'My podcasts';

  @override
  String get podcastsNoPodcasts => 'You don\'t have any podcasts yet';

  @override
  String get podcastsNoPodcastsDesc =>
      'Create your first podcast and share your voice with the community!';

  @override
  String get podcastsCreateFirst => 'Create my first podcast';

  @override
  String get podcastsNewPodcast => 'New podcast';

  @override
  String get podcastsPodcastTitle => 'Podcast title *';

  @override
  String get podcastsPodcastTitleHint => 'Ex: Tech Niger';

  @override
  String get podcastsPodcastTitleRequired => 'Please enter a title';

  @override
  String get podcastsPodcastDescription => 'Description';

  @override
  String get podcastsPodcastDescriptionHint => 'What is your podcast about?';

  @override
  String get podcastsCoverImage => 'Cover image *';

  @override
  String get podcastsSelectCover => 'Select an image';

  @override
  String get podcastsChangeCover => 'Change image';

  @override
  String get podcastsCategory => 'Category';

  @override
  String get podcastsLanguage => 'Primary language';

  @override
  String get podcastsTags => 'Tags';

  @override
  String get podcastsTagsHint => 'Add tags to improve discoverability';

  @override
  String get podcastsExplicitContent => 'Explicit content';

  @override
  String get podcastsExplicitContentDesc =>
      'This podcast contains adult content';

  @override
  String get podcastsEpisodeFrequency => 'Publication frequency';

  @override
  String get podcastsFrequencyWeekly => 'Weekly';

  @override
  String get podcastsFrequencyBiweekly => 'Biweekly';

  @override
  String get podcastsFrequencyMonthly => 'Monthly';

  @override
  String get podcastsFrequencyVariable => 'Variable';

  @override
  String get podcastsCreateButton => 'Create podcast';

  @override
  String get podcastsCreating => 'Creating...';

  @override
  String get podcastsCreatedSuccess => 'Podcast created successfully!';

  @override
  String get podcastsCreationError => 'Error creating podcast';

  @override
  String get podcastsNewEpisode => 'New episode';

  @override
  String get podcastsRecordEpisode => 'Record an episode';

  @override
  String get podcastsUploadAudio => 'Upload audio file';

  @override
  String get podcastsSelectAudio => 'Select an audio file';

  @override
  String get podcastsAudioSelected => 'File selected';

  @override
  String podcastsEstimatedDuration(String duration) {
    return 'Estimated duration: $duration';
  }

  @override
  String get podcastsEpisodeTitle => 'Episode title *';

  @override
  String get podcastsEpisodeTitleRequired => 'Please enter a title';

  @override
  String get podcastsEpisodeDescription => 'Description / Notes';

  @override
  String get podcastsChapters => 'Chapters';

  @override
  String get podcastsAddChapter => 'Add chapter';

  @override
  String get podcastsChapterTitle => 'Chapter title';

  @override
  String get podcastsChapterTime => 'Start time';

  @override
  String get podcastsNoChapters => 'No chapters added';

  @override
  String get podcastsPremiumEpisode => 'Premium episode';

  @override
  String get podcastsPremiumEpisodeDesc => 'Reserved for paid subscribers';

  @override
  String get podcastsPublishEpisode => 'Publish episode';

  @override
  String get podcastsPublishing => 'Publishing...';

  @override
  String get podcastsPublishedSuccess => 'Episode published successfully!';

  @override
  String get podcastsPublishError => 'Error during publication';

  @override
  String get podcastsSelectAudioFirst => 'Please select an audio file';

  @override
  String get podcastsEpisodeDetail => 'Episode details';

  @override
  String get podcastsPlay => 'Play';

  @override
  String get podcastsPause => 'Pause';

  @override
  String get podcastsDownload => 'Download';

  @override
  String get podcastsDownloading => 'Downloading...';

  @override
  String get podcastsShare => 'Share';

  @override
  String get podcastsLike => 'Like';

  @override
  String get podcastsLiked => 'Liked';

  @override
  String get podcastsSleepTimer => 'Sleep timer';

  @override
  String get podcastsSleepTimerOff => 'Off';

  @override
  String podcastsSleepTimerMinutes(int minutes) {
    return '$minutes minutes';
  }

  @override
  String get podcastsSleepTimerEndOfEpisode => 'End of episode';

  @override
  String get podcastsPlaybackSpeed => 'Playback speed';

  @override
  String get podcastsFromLiveRoom =>
      'This episode was recorded during a live audio room';

  @override
  String get podcastsTranscription => 'Transcription';

  @override
  String get podcastsReport => 'Report';

  @override
  String get podcastsReportSent => 'Report sent';

  @override
  String get podcastsCategoryNews => 'News';

  @override
  String get podcastsCategoryCulture => 'Culture';

  @override
  String get podcastsCategorySpirituality => 'Spirituality';

  @override
  String get podcastsCategoryBusiness => 'Business';

  @override
  String get podcastsCategoryEntertainment => 'Entertainment';

  @override
  String get podcastsCategoryEducation => 'Education';

  @override
  String get podcastsCategoryStorytelling => 'Storytelling';

  @override
  String get podcastsCategorySports => 'Sports';

  @override
  String get podcastsCategoryPolitics => 'Politics';

  @override
  String get podcastsCategoryTechnology => 'Technology';

  @override
  String get podcastsCategoryHealth => 'Health';

  @override
  String get podcastsCategoryOther => 'Other';

  @override
  String get podcastsStatusDraft => 'Draft';

  @override
  String get podcastsStatusPublished => 'Published';

  @override
  String get podcastsStatusPaused => 'Paused';

  @override
  String get podcastsStatusArchived => 'Archived';

  @override
  String get podcastsStatusScheduled => 'Scheduled';

  @override
  String get podcastsDeletePodcast => 'Delete podcast';

  @override
  String get podcastsDeletePodcastConfirm =>
      'Are you sure you want to delete this podcast and all its episodes?';

  @override
  String get podcastsDeletedSuccess => 'Podcast deleted';

  @override
  String get podcastsEdit => 'Edit';

  @override
  String get podcastsStats => 'Statistics';

  @override
  String get podcastsViewAll => 'View all';

  @override
  String get callHistory => 'Call history';

  @override
  String get clearHistory => 'Clear history';

  @override
  String get clearHistoryConfirmation =>
      'Are you sure you want to clear all call history?';

  @override
  String get clear => 'Clear';

  @override
  String get noCallHistory => 'No calls';

  @override
  String get noCallHistoryDescription =>
      'Your audio and video calls will appear here';

  @override
  String get noMissedCalls => 'No missed calls';

  @override
  String get noIncomingCalls => 'No incoming calls';

  @override
  String get noOutgoingCalls => 'No outgoing calls';

  @override
  String get busyCall => 'Busy';

  @override
  String today(String time) {
    return 'Today';
  }

  @override
  String yesterday(String time) {
    return 'Yesterday';
  }

  @override
  String get missedCall => 'Missed call';

  @override
  String get declinedCall => 'Declined call';

  @override
  String get incomingCall => 'Incoming call';

  @override
  String get outgoingCall => 'Outgoing call';

  @override
  String get audioCall => 'Audio call';

  @override
  String get callConfirmMessage => 'Would you like to call';

  @override
  String get openLink => 'Open link';

  @override
  String get openLinkConfirmMessage => 'Do you want to open this link?';

  @override
  String get videoCall => 'Video call';

  @override
  String get callEnded => 'Call ended';

  @override
  String callDuration(String duration) {
    return 'Duration: $duration';
  }

  @override
  String get noAnswer => 'No answer';

  @override
  String get callAgain => 'Call again';

  @override
  String get callInProgress => 'Call in progress';

  @override
  String get returnToCall => 'Return';

  @override
  String get callInfo => 'Call info';

  @override
  String get callType => 'Type';

  @override
  String get voiceCall => 'Voice call';

  @override
  String get callDirection => 'Direction';

  @override
  String get callStatus => 'Status';

  @override
  String get callBack => 'Call back';

  @override
  String get deleteCall => 'Delete call';

  @override
  String get deleteCallConfirmation =>
      'Are you sure you want to delete this call from your history?';

  @override
  String get callDeleted => 'Call deleted';

  @override
  String get paymentAccounts => 'Payment Methods';

  @override
  String get paymentAccountsDesc => 'Manage accounts to receive money';

  @override
  String get addPaymentAccount => 'Add an account';

  @override
  String get paymentAccountType => 'Account type';

  @override
  String get paymentAccountLabel => 'Account label';

  @override
  String get paymentAccountLabelRequired => 'Label is required';

  @override
  String get stripeConnect => 'Stripe Connect';

  @override
  String get stripeConnectDesc =>
      'Connect your Stripe account to receive international payments directly to your bank account.';

  @override
  String get stripeConnectSetup => 'Set up Stripe Connect';

  @override
  String get mobileMoney => 'Mobile Money';

  @override
  String get bankAccount => 'Bank Account';

  @override
  String get mobileProvider => 'Provider';

  @override
  String get mobileNumber => 'Phone number';

  @override
  String get mobileNumberRequired => 'Phone number is required';

  @override
  String get mobileNumberInvalid => 'Invalid number (min. 8 digits)';

  @override
  String get bankName => 'Bank name';

  @override
  String get bankNameRequired => 'Bank name is required';

  @override
  String get accountHolder => 'Account holder';

  @override
  String get accountHolderRequired => 'Account holder is required';

  @override
  String get ibanLabel => 'IBAN';

  @override
  String get ibanRequired => 'IBAN is required';

  @override
  String get bicLabel => 'BIC / SWIFT';

  @override
  String get optional => 'optional';

  @override
  String get defaultAccount => 'Default account';

  @override
  String get setAsDefault => 'Set as default';

  @override
  String get setAsDefaultDesc =>
      'Use this account as your primary payment method';

  @override
  String get deletePaymentAccount => 'Delete account';

  @override
  String get confirmDeletePaymentAccount =>
      'Are you sure you want to delete this payment account?';

  @override
  String get accountAdded => 'Account added successfully';

  @override
  String get paymentAccountDeleted => 'Account deleted';

  @override
  String get setAsDefaultSuccess => 'Account set as default';

  @override
  String get noPaymentAccounts => 'No payment methods configured';

  @override
  String get paymentAccountRequired =>
      'Add a payment method to receive your earnings';

  @override
  String get saveAccount => 'Save account';

  @override
  String get saving => 'Saving...';

  @override
  String get confirmPayment => 'Confirm payment';

  @override
  String get paymentSummary => 'Summary';

  @override
  String get grossAmount => 'Gross amount';

  @override
  String get commission => 'Commission';

  @override
  String get netAmount => 'Net amount';

  @override
  String get destinationAccount => 'Destination account';

  @override
  String get confirmAndPay => 'Confirm and pay';

  @override
  String get confirmPaymentBiometrics => 'Confirm to validate the payment';

  @override
  String get enterPin => 'Enter your PIN code';

  @override
  String get useBiometrics => 'Use biometrics';

  @override
  String get enableBiometricsDesc =>
      'Use your fingerprint or Face ID to confirm payments faster.';

  @override
  String get notNow => 'Not now';

  @override
  String get enable => 'Enable';

  @override
  String get setupPin => 'Set up your PIN';

  @override
  String get setupPinDesc =>
      'This 4-digit code protects your financial transactions.';

  @override
  String get confirmPin => 'Confirm PIN';

  @override
  String get confirmPinDesc => 'Enter your PIN again to confirm.';

  @override
  String get pinMismatch => 'PINs don\'t match';

  @override
  String get incorrectPin => 'Incorrect PIN';

  @override
  String get tooManyAttempts => 'Too many attempts. Please try again later.';

  @override
  String get attemptsRemaining => 'attempts remaining';

  @override
  String get paymentHistory => 'Payment History';

  @override
  String get paymentHistoryDesc => 'View all your transactions';

  @override
  String get allTransactions => 'All';

  @override
  String get tickets => 'Tickets';

  @override
  String get tips => 'Tips';

  @override
  String get sales => 'Sales';

  @override
  String get payouts => 'Payouts';

  @override
  String get statusPending => 'Pending';

  @override
  String get statusProcessing => 'Processing';

  @override
  String get statusCompleted => 'Completed';

  @override
  String get statusFailed => 'Failed';

  @override
  String get statusCancelled => 'Cancelled';

  @override
  String get statusRefunded => 'Refunded';

  @override
  String get transactionDetail => 'Transaction Detail';

  @override
  String get reportIssue => 'Report an issue';

  @override
  String get noTransactions => 'No transactions';

  @override
  String get counterparty => 'Counterparty';

  @override
  String get dateLabel => 'Date';

  @override
  String get completedOn => 'Completed on';

  @override
  String get referenceLabel => 'Reference';

  @override
  String get copied => 'Copied!';

  @override
  String get descriptionLabel => 'Description';

  @override
  String get paymentTypeTicket => 'Ticket';

  @override
  String get paymentTypeTip => 'Tip';

  @override
  String get paymentTypeSale => 'Sale';

  @override
  String get paymentTypePayout => 'Payout';

  @override
  String get paymentTypeTransfer => 'Transfer';

  @override
  String reportTransactionSubject(String id, String type) {
    return 'Issue with transaction #$id - $type';
  }

  @override
  String get reportTransactionIntro =>
      'Hello,\n\nI am reporting an issue with the following transaction:\n';

  @override
  String get describeYourProblem => 'Describe your problem:\n';

  @override
  String get supportTickets => 'Support Tickets';

  @override
  String get newSupportTicket => 'New ticket';

  @override
  String get supportTicketCreated => 'Ticket created successfully';

  @override
  String get supportTicketUpdated => 'Ticket updated';

  @override
  String get supportReply => 'Support reply';

  @override
  String get ticketOpen => 'Open';

  @override
  String get ticketInProgress => 'In Progress';

  @override
  String get ticketResolved => 'Resolved';

  @override
  String get ticketClosed => 'Closed';

  @override
  String get yourMessage => 'Your message...';

  @override
  String get sendReply => 'Send';

  @override
  String get supportTeam => 'Support Team';

  @override
  String get noSupportTickets => 'No support tickets';

  @override
  String get noSupportTicketsDesc => 'Your support requests will appear here';

  @override
  String get ticketSubject => 'Subject';

  @override
  String get ticketDescription => 'Problem description';

  @override
  String get ticketDescriptionRequired => 'Please describe the problem';

  @override
  String get ticketCategory => 'Category';

  @override
  String get ticketCategoryTransaction => 'Transaction';

  @override
  String get ticketCategoryAccount => 'Account';

  @override
  String get ticketCategoryTechnical => 'Technical';

  @override
  String get ticketCategoryOther => 'Other';

  @override
  String get supportNotificationTitle => 'Support reply';

  @override
  String supportNotificationBody(String subject) {
    return 'Your ticket \"$subject\" has received a reply';
  }

  @override
  String get forward => 'Forward';

  @override
  String get forwarded => 'Forwarded';

  @override
  String get forwardTo => 'Forward to...';

  @override
  String get messageForwarded => 'Message forwarded';

  @override
  String messagesForwarded(int count) {
    return '$count messages forwarded';
  }

  @override
  String deleteSelectedMessages(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 's',
      one: '',
    );
    return 'Delete $count message$_temp0?';
  }

  @override
  String get messagesDeletedForYou => 'Messages will be deleted for you only.';

  @override
  String messagesDeletedSuccess(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 's',
      one: '',
    );
    return '$count message$_temp0 deleted';
  }

  @override
  String get searchConversation => 'Search a conversation...';

  @override
  String get noConversationFound => 'No conversation found';

  @override
  String get messageCopied => 'Message copied';

  @override
  String get reply => 'Reply';

  @override
  String get react => 'React';

  @override
  String get copy => 'Copy';

  @override
  String get report => 'Report';

  @override
  String get transferSendMoney => 'Send money';

  @override
  String get transferReset => 'Reset';

  @override
  String get transferContinue => 'Continue';

  @override
  String get transferBack => 'Back';

  @override
  String get transferRecipient => 'Recipient';

  @override
  String get transferPaymentMethod => 'Payment method';

  @override
  String get transferAmount => 'Amount';

  @override
  String get transferConfirmation => 'Confirmation';

  @override
  String get transferConfirmButton => 'Confirm';

  @override
  String get transferAddRecipient => 'Add a recipient';

  @override
  String get transferSelectExistingRecipient =>
      'Or select an existing recipient';

  @override
  String get transferNoRecipients => 'No registered recipients';

  @override
  String get transferFavorites => 'Favorites';

  @override
  String get transferRecentlyUsed => 'Recently used';

  @override
  String get transferOtherRecipients => 'Other recipients';

  @override
  String get transferSelectPaymentMethod => 'Select a payment method';

  @override
  String get transferDebitAccountInfo => 'Debit account information';

  @override
  String get transferCountryCode => 'Country code';

  @override
  String get transferMynitaNumber => 'Mynita number *';

  @override
  String get transferWaveNumber => 'Wave number *';

  @override
  String get transferPhoneHint => 'XX XX XX XX';

  @override
  String get transferPhoneRequired => 'Phone number is required';

  @override
  String get transferPhoneInvalid => 'Invalid number';

  @override
  String get transferBankName => 'Bank name *';

  @override
  String get transferBankNameRequired => 'Bank name is required';

  @override
  String get transferAccountNumberIban => 'Account number / IBAN *';

  @override
  String get transferAccountNumberIbanHint => 'XXXX XXXX XXXX XXXX';

  @override
  String get transferAccountNumberRequired => 'Account number is required';

  @override
  String get transferCurrency => 'Currency';

  @override
  String get transferAmountToSend => 'Amount to send';

  @override
  String transferMinimumAmount(String currency) {
    return 'Minimum 5 $currency';
  }

  @override
  String get transferEnterAmount => 'Enter an amount';

  @override
  String get transferInvalidAmount => 'Invalid amount';

  @override
  String get transferMessageOptional => 'Message (optional)';

  @override
  String get transferMessageHint => 'Ex: For groceries';

  @override
  String get transferSummary => 'Summary';

  @override
  String get transferAmountSent => 'Amount:';

  @override
  String transferFees(String percent) {
    return 'Fees:';
  }

  @override
  String get transferTotalDebited => 'Total debited';

  @override
  String transferExchangeRate(String from, String rate) {
    return 'Exchange rate';
  }

  @override
  String get transferRecipientWillReceive => 'The recipient will receive';

  @override
  String get transferAmountToReceive => 'Amount to receive';

  @override
  String transferTotalDebitedAmount(String amount, String currency) {
    return 'Total debited: $amount $currency';
  }

  @override
  String transferPayVia(String method) {
    return 'Pay via $method';
  }

  @override
  String get transferTermsAndConditions =>
      'By confirming, you accept the transfer terms and conditions. Funds will be available within 24 hours.';

  @override
  String get transferSelectRecipientError => 'Select a recipient';

  @override
  String get transferSelectPaymentMethodError => 'Select a payment method';

  @override
  String get transferFeeCalculationError => 'Error calculating fees';

  @override
  String get transferConfirmTitle => 'Confirm transfer';

  @override
  String get transferAboutToSend => 'You are about to send:';

  @override
  String get transferAmountLabel => 'Amount to send';

  @override
  String get transferFeesLabel => 'Fees';

  @override
  String get transferTotalLabel => 'Total:';

  @override
  String transferFromLabel(String method, String account) {
    return 'From: $method ($account)';
  }

  @override
  String transferToLabel(String name) {
    return 'To: $name';
  }

  @override
  String get transferIrreversibleWarning =>
      'This action is irreversible. Do you want to continue?';

  @override
  String get transferInitiatedSuccess => 'Transfer initiated successfully';

  @override
  String get transferSecureTitle => 'Secure transfer';

  @override
  String get transferSecureMessage =>
      'Money transfers require the app to be installed from Google Play Store to ensure the security of your transactions.';

  @override
  String get transferUserNotConnected => 'User not connected';

  @override
  String transferError(String error) {
    return 'Error: $error';
  }

  @override
  String get recipientEditTitle => 'Edit recipient';

  @override
  String get recipientNewTitle => 'New recipient';

  @override
  String get recipientPersonalInfo => 'Personal information';

  @override
  String get recipientFullName => 'Full name *';

  @override
  String get recipientFullNameHint => 'Ex: Amadou Boubacar';

  @override
  String get recipientNameRequired => 'Name is required';

  @override
  String get recipientNameTooShort => 'Name must be at least 3 characters';

  @override
  String get recipientPhoneNumber => 'Phone number *';

  @override
  String get recipientEmailOptional => 'Email (optional)';

  @override
  String get recipientEmailHint => 'example@email.com';

  @override
  String get recipientEmailInvalid => 'Invalid email';

  @override
  String get recipientReceptionMode => 'Reception mode';

  @override
  String get recipientPaymentDetails => 'Payment details';

  @override
  String recipientMobilePaymentInfo(String service) {
    return 'The transfer will be made via $service to the recipient\'s phone number.';
  }

  @override
  String get recipientCashPickupInfo =>
      'The recipient can withdraw the money at a NITA service point with a valid ID.';

  @override
  String get recipientSelectBank => 'Select a bank';

  @override
  String get recipientAccountNumber => 'Account number *';

  @override
  String get recipientAccountNumberHint => 'XXXX XXXX XXXX XXXX';

  @override
  String get recipientAccountNumberRequired => 'Account number is required';

  @override
  String get recipientAccountNumberInvalid => 'Invalid account number';

  @override
  String get recipientLocation => 'Location';

  @override
  String get recipientCountry => 'Country';

  @override
  String get recipientCity => 'City';

  @override
  String get recipientAddressOptional => 'Address (optional)';

  @override
  String get recipientAddressHint => 'Neighborhood, street...';

  @override
  String get recipientAddToFavorites => 'Add to favorites';

  @override
  String get recipientFavoritesQuickAccess =>
      'Quick access for future transfers';

  @override
  String get recipientSaveChanges => 'Save changes';

  @override
  String get recipientAddButton => 'Add recipient';

  @override
  String get recipientModifiedSuccess => 'Recipient modified successfully';

  @override
  String get recipientAddedSuccess => 'Recipient added successfully';

  @override
  String get recipientDeleteTitle => 'Delete recipient?';

  @override
  String recipientDeleteConfirm(String name) {
    return 'Do you really want to remove $name from your recipients?';
  }

  @override
  String get recipientDeleted => 'Recipient deleted';

  @override
  String get recipientTypeMynita => 'Mynita';

  @override
  String get recipientTypeWave => 'Wave';

  @override
  String get recipientTypeBankAccount => 'Bank account';

  @override
  String get recipientTypeCashPickup => 'Cash pickup';

  @override
  String get recipientTypeMynitaDesc => 'Transfer via Mynita';

  @override
  String get recipientTypeWaveDesc => 'Transfer via Wave';

  @override
  String get recipientTypeBankAccountDesc => 'Direct bank transfer';

  @override
  String get recipientTypeCashPickupDesc => 'Pickup at a service point';

  @override
  String get senderPaymentMynita => 'Mynita';

  @override
  String get senderPaymentWave => 'Wave';

  @override
  String get senderPaymentBankAccount => 'Bank account';

  @override
  String get senderPaymentMynitaDesc => 'Pay via Mynita';

  @override
  String get senderPaymentWaveDesc => 'Pay via Wave';

  @override
  String get senderPaymentBankAccountDesc => 'Pay by bank transfer';

  @override
  String get starMessage => 'Add to favorites';

  @override
  String get unstarMessage => 'Remove from favorites';

  @override
  String get starredMessages => 'Starred messages';

  @override
  String get noStarredMessages => 'No starred messages';

  @override
  String get searchMessages => 'Search in conversation...';

  @override
  String get noSearchResults => 'No results';

  @override
  String get selectAll => 'Select all';

  @override
  String get deselectAll => 'Deselect all';

  @override
  String get callHold => 'Hold';

  @override
  String get callResume => 'Resume';

  @override
  String get callOnHold => 'On hold';

  @override
  String get callReconnecting => 'Reconnecting...';

  @override
  String get callError => 'Call error';

  @override
  String get callQualityGood => 'Good quality';

  @override
  String get callQualityFair => 'Fair quality';

  @override
  String get callQualityPoor => 'Poor quality';

  @override
  String get groupCallTitle => 'Group Call';

  @override
  String get groupCallCreate => 'Start group call';

  @override
  String get groupCallJoin => 'Join';

  @override
  String get groupCallLeave => 'Leave call';

  @override
  String get groupCallEnd => 'End call';

  @override
  String get groupCallInvite => 'Invite participants';

  @override
  String groupCallParticipants(int count) {
    return '$count participants';
  }

  @override
  String get groupCallWaiting => 'Waiting for participants...';

  @override
  String get groupCallConnecting => 'Connecting to call...';

  @override
  String get groupCallConnected => 'Connected';

  @override
  String get groupCallDisconnected => 'Disconnected';

  @override
  String get groupCallReconnecting => 'Reconnecting...';

  @override
  String get groupCallMeshMode => 'Direct connection';

  @override
  String get groupCallSfuMode => 'Server-assisted';

  @override
  String get groupCallE2eeEnabled => 'End-to-end encrypted';

  @override
  String get groupCallE2eeDisabled => 'Not encrypted';

  @override
  String get groupCallE2eeVerify => 'Verify encryption';

  @override
  String groupCallE2eeVerificationCode(String code) {
    return 'Verification code: $code';
  }

  @override
  String get groupCallE2eeVerifyHint =>
      'Compare this code with other participants to verify encryption';

  @override
  String get groupCallVideoQuality => 'Video quality';

  @override
  String get groupCallVideoQualityLow => 'Low (180p)';

  @override
  String get groupCallVideoQualityMedium => 'Medium (360p)';

  @override
  String get groupCallVideoQualityHigh => 'High (720p)';

  @override
  String get groupCallVideoQualityAuto => 'Auto';

  @override
  String get groupCallScreenShare => 'Share screen';

  @override
  String get groupCallStopScreenShare => 'Stop sharing';

  @override
  String get groupCallRaiseHand => 'Raise hand';

  @override
  String get groupCallLowerHand => 'Lower hand';

  @override
  String groupCallHandRaised(String name) {
    return '$name raised hand';
  }

  @override
  String get groupCallMuted => 'Muted';

  @override
  String get groupCallUnmuted => 'Unmuted';

  @override
  String get groupCallCameraOff => 'Camera off';

  @override
  String get groupCallCameraOn => 'Camera on';

  @override
  String get groupCallSpeaking => 'Speaking';

  @override
  String get groupCallNetworkPoor => 'Poor connection';

  @override
  String get groupCallNetworkGood => 'Good connection';

  @override
  String groupCallParticipantJoined(String name) {
    return '$name joined';
  }

  @override
  String groupCallParticipantLeft(String name) {
    return '$name left';
  }

  @override
  String get groupCallSelectParticipants => 'Select participants';

  @override
  String get groupCallMinParticipants => 'Select at least one participant';

  @override
  String groupCallMaxParticipants(int max) {
    return 'Maximum $max participants';
  }

  @override
  String get groupCallStartVideo => 'Start video call';

  @override
  String get groupCallStartAudio => 'Start audio call';

  @override
  String get groupCallSimulcast => 'Adaptive quality enabled';

  @override
  String get groupCallSwitchingToSfu =>
      'Switching to server mode for better quality...';

  @override
  String get comingSoon => 'COMING SOON';

  @override
  String get goBack => 'Go back';

  @override
  String get comingSoonCallsTitle => 'Audio & Video Calls';

  @override
  String get comingSoonCallsDescription =>
      'Make high-quality audio and video calls with your friends and family. This feature is under development and will be available very soon.';

  @override
  String get comingSoonAudioRoomsTitle => 'Audio Rooms';

  @override
  String get comingSoonAudioRoomsDescription =>
      'Join live audio discussions with the community. Participate in debates, Q&A sessions and more. This feature is coming soon.';

  @override
  String get comingSoonInDevelopment => 'Under development';

  @override
  String get comingSoonPodcastsTitle => 'Podcasts';

  @override
  String get comingSoonPodcastsDescription =>
      'Listen to and create podcasts about the Nigerien diaspora. Share your stories, interviews, and discussions. This feature is coming soon.';

  @override
  String get temporarilyClosed => 'Temporarily closed';

  @override
  String get services => 'Services';

  @override
  String get viewFullDetails => 'View full details';

  @override
  String get showBusinessesOnMap => 'Show businesses on map';

  @override
  String get hideBusinessesOnMap => 'Hide businesses on map';

  @override
  String get locationRequiredToSeeMembers =>
      'Location required to view members';

  @override
  String get activate => 'Enable';

  @override
  String get reminderTitle => 'Reminders';

  @override
  String get reminderInfoText =>
      'You will receive a push notification before the event starts based on configured reminders.';

  @override
  String get reminderOneHour => '1 hour before';

  @override
  String get reminderTwentyFourHours => '24 hours before';

  @override
  String get reminderOneWeek => '1 week before';

  @override
  String get reminderSet => 'Reminder set';

  @override
  String get reminderCancelled => 'Reminder removed';

  @override
  String get reminderPast => 'Past';

  @override
  String get audioRoomReminderTitle => 'Audio room starting soon';

  @override
  String get podcastNewEpisodeTitle => 'New episode';

  @override
  String get transferReminderTitle => 'Upcoming transfer';

  @override
  String get serviceMoneyTransfer => 'money transfers';

  @override
  String get serviceMarketplace => 'marketplace';

  @override
  String get serviceBusinessDirectory => 'business directory';

  @override
  String get serviceEmbassies => 'embassies';

  @override
  String quickAccessToService(String service) {
    return 'Quick access to service: $service.';
  }

  @override
  String quickAccessToServices(String services, String lastService) {
    return 'Quick access to services: $services and $lastService.';
  }

  @override
  String get searchableMembers => 'members';

  @override
  String get searchableGroups => 'groups';

  @override
  String get searchableEvents => 'events';

  @override
  String findEasily(String item) {
    return 'Find $item easily.';
  }

  @override
  String findMultipleEasily(String items, String lastItem) {
    return 'Find $items and $lastItem easily.';
  }

  @override
  String discoverCommunityStats(String stats) {
    return 'Discover the community: $stats count. Tap to explore.';
  }

  @override
  String get searchProduct => 'Search for a product...';

  @override
  String get searchEmbassy => 'Search by name, country or city...';

  @override
  String get searchEmployee => 'Search by name, title, role...';

  @override
  String get searchRecipient => 'Search for a recipient...';

  @override
  String get searchFriend => 'Search for a friend...';

  @override
  String get searchByRecipient => 'Search by recipient...';

  @override
  String get searchBusiness => 'Search for a business...';

  @override
  String get download => 'Download';

  @override
  String get share => 'Share';

  @override
  String get galleryPermissionDenied => 'Permission denied to access gallery';

  @override
  String get imageSavedToGallery => 'Image saved to gallery';

  @override
  String get errorDownloading => 'Error downloading';

  @override
  String get errorSharing => 'Error sharing';

  @override
  String get imageNotAvailable => 'Image not available';

  @override
  String imageCounter(int current, int total) {
    return '$current of $total';
  }

  @override
  String todayAt(String time) {
    return 'Today at $time';
  }

  @override
  String yesterdayAt(String time) {
    return 'Yesterday at $time';
  }

  @override
  String get deletePhoto => 'Delete photo';

  @override
  String get confirmDeletePhoto => 'Do you really want to delete the photo?';

  @override
  String get confirmDeleteGroup =>
      'Do you really want to delete this group? This action is irreversible.';

  @override
  String get deleteGroup => 'Delete group';

  @override
  String get groupDeleted => 'Group deleted';

  @override
  String get deletionError => 'Error during deletion';

  @override
  String get editGroup => 'Edit group';

  @override
  String get promoteAdmin => 'Promote to Admin';

  @override
  String get demoteAdmin => 'Remove Admin';

  @override
  String get joinRequests => 'Join requests';

  @override
  String get requestApproved => 'Request approved';

  @override
  String get requestRejected => 'Request rejected';

  @override
  String get accessDenied => 'Access Denied';

  @override
  String errorWithDetails(String error) {
    return 'Error: $error';
  }

  @override
  String get deleteConversationWarning =>
      'Warning: The other person can still send you messages. The conversation will reappear if you receive a new message.';

  @override
  String get deleteAndBlock => 'Delete and block';

  @override
  String get messageWillBeDeleted => 'Message will be deleted';

  @override
  String get undo => 'Undo';

  @override
  String confirmDeleteMultipleMessages(int count) {
    return 'Delete $count messages?';
  }

  @override
  String get deleteMessages => 'Delete messages';

  @override
  String get hostCountry => 'Host country (optional)';

  @override
  String get creatorMustTransferOwnership =>
      'The creator must transfer ownership before leaving';

  @override
  String get transfers => 'Transfers';

  @override
  String get reset => 'Reset';

  @override
  String get back => 'Back';

  @override
  String get skip => 'Skip';

  @override
  String get coachMarkProfile => 'Your profile';

  @override
  String get coachMarkProfileDesc =>
      'Tap here to access your profile and complete it with your information.';

  @override
  String get coachMarkNotifications => 'Notifications';

  @override
  String get coachMarkNotificationsDesc =>
      'Stay informed of new messages and community activities.';

  @override
  String get coachMarkNearbyMembers => 'Nearby members';

  @override
  String get coachMarkNearbyMembersDesc =>
      'Discover Nigeriens in your area. Swipe to see more profiles.';

  @override
  String get coachMarkUpcomingEvents => 'Upcoming events';

  @override
  String get coachMarkUpcomingEventsDesc =>
      'Participate in diaspora meetings and activities. Tap to see details.';

  @override
  String get locationRequiredForNearby =>
      'To see nearby members, you must enable your location. It\'s give and take!';

  @override
  String get enableLocation => 'ENABLE';

  @override
  String get serviceTransfer => 'Transfer';

  @override
  String get serviceDirectory => 'Directory';

  @override
  String get serviceAudioRooms => 'Audio Rooms';

  @override
  String get servicePodcasts => 'Podcasts';

  @override
  String get allServices => 'All services';

  @override
  String get friend => 'Friend';

  @override
  String get embassies => 'Embassies';

  @override
  String get mapLegendSemantics =>
      'Legend: Green for friends, Orange for members, Blue for embassies';

  @override
  String get saveAsPodcast => 'Save as Podcast';

  @override
  String get publishRecording => 'Publish this recording';

  @override
  String get closeRoom => 'Close room';

  @override
  String get closeRoomConfirm => 'Are you sure you want to close this room?';

  @override
  String get moderationMode => 'Moderation Mode (invisible)';

  @override
  String get userNotConnected => 'User not connected';

  @override
  String get paidRoomsNotAllowed => 'Paid rooms are not allowed';

  @override
  String get paidRoomsDisabled => 'Paid rooms are disabled';

  @override
  String get cardSecurityInfo =>
      'Your card data is secured by Stripe. We never store your full card number.';

  @override
  String get cardTransferInfo =>
      'The transfer will be made directly to the card via Visa Direct or Mastercard Send.';

  @override
  String get registeredCard => 'Registered card';

  @override
  String get changeCard => 'Change';

  @override
  String get cardInfoRequired => 'Please enter complete card information';

  @override
  String cardVerificationError(String error) {
    return 'Error verifying card: $error';
  }

  @override
  String get closeRoomWarning =>
      'This action will close the room for all participants.';

  @override
  String get closeReasonHint => 'Reason for closing...';

  @override
  String get defaultCloseReason => 'Community rules violation';

  @override
  String get collectionsNotAllowed => 'Collections are not allowed';

  @override
  String get heritageContentNotAllowed => 'Heritage content is not allowed';

  @override
  String minTicketPrice(int price) {
    return 'Minimum ticket price is $price XOF';
  }

  @override
  String maxTicketPrice(int price) {
    return 'Maximum ticket price is $price XOF';
  }

  @override
  String get defaultUserName => 'User';

  @override
  String errorCreating(String error) {
    return 'Error creating: $error';
  }

  @override
  String get roomNotFound => 'Room not found';

  @override
  String get blockedFromRoom => 'You are blocked from this room';

  @override
  String get roomFull => 'Room is full';

  @override
  String errorConnecting(String error) {
    return 'Connection error: $error';
  }

  @override
  String get unauthorizedAccess => 'Unauthorized access';

  @override
  String tomorrowAt(String time) {
    return 'Tomorrow at $time';
  }

  @override
  String forBeneficiary(String beneficiary) {
    return 'For: $beneficiary';
  }

  @override
  String goalAmount(String amount) {
    return 'Goal: $amount';
  }

  @override
  String get contribute => 'Contribute';

  @override
  String get suggestedAmount => 'Suggested amount';

  @override
  String get orEnterAmount => 'Or enter an amount';

  @override
  String get amountInXof => 'Amount in XOF';

  @override
  String get messageOptional => 'Message (optional)';

  @override
  String get confirmContribution => 'Confirm contribution';

  @override
  String get collectionLabel => 'Collection';

  @override
  String get emergencyLabel => 'Emergency';

  @override
  String get projectLabel => 'Project';

  @override
  String get duesLabel => 'Dues';

  @override
  String get moderatorRole => 'Moderator';

  @override
  String get warnHost => 'Warn the host';

  @override
  String get warningSentToHost => 'Warning sent to the host';

  @override
  String get muteMicrophone => 'Mute microphone';

  @override
  String userMuted(String userName) {
    return '$userName has been muted';
  }

  @override
  String get kickFromRoom => 'Kick from room';

  @override
  String userKicked(String userName) {
    return '$userName has been kicked';
  }

  @override
  String get blockFromRoom => 'Block from this room';

  @override
  String userBlockedFromRoom(String userName) {
    return '$userName has been blocked';
  }

  @override
  String get videoEnabled => 'Video enabled';

  @override
  String get videoEnabledDesc => 'Allow speakers to share their video';

  @override
  String get remove => 'Remove';

  @override
  String errorLabel(String error) {
    return 'Error: $error';
  }

  @override
  String get noEventFound => 'No event found';

  @override
  String get noGroupFound => 'No group found';

  @override
  String get noEmbassyFound => 'No embassy found';

  @override
  String get warningMessageHint => 'Warning message...';

  @override
  String get searchEventHint => 'Search an event...';

  @override
  String get searchGroupHint => 'Search a group...';

  @override
  String get searchEmbassyHint => 'Search an embassy...';

  @override
  String get pleaseAddCoverImage => 'Please add a cover image';

  @override
  String get podcastCreatedSuccess => 'Podcast created successfully!';

  @override
  String get createPodcast => 'Create a podcast';

  @override
  String get languageFrench => 'French';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageHausa => 'Hausa';

  @override
  String get languageZarma => 'Zarma/Djerma';

  @override
  String get frequencyNotDefined => 'Not defined';

  @override
  String get frequencyDaily => 'Daily';

  @override
  String get frequencyWeekly => 'Weekly';

  @override
  String get frequencyBiweekly => 'Biweekly';

  @override
  String get frequencyMonthly => 'Monthly';

  @override
  String get explicitContent => 'Explicit content';

  @override
  String get explicitContentDesc => 'This podcast contains adult content';

  @override
  String get createThePodcast => 'Create the podcast';

  @override
  String get episodeNotFound => 'Episode not found';

  @override
  String get downloadInProgress => 'Download in progress...';

  @override
  String get sleepTimerDisabled => 'Disabled';

  @override
  String get sleepTimer15min => '15 minutes';

  @override
  String get sleepTimer30min => '30 minutes';

  @override
  String get sleepTimer45min => '45 minutes';

  @override
  String get sleepTimer1hour => '1 hour';

  @override
  String get sleepTimerEndOfEpisode => 'End of episode';

  @override
  String get sleepTimerEndActivated =>
      'Sleep timer until end of episode activated';

  @override
  String get sleepTimerFinished => 'Sleep timer finished';

  @override
  String sleepTimerMinutes(int minutes) {
    return 'Timer: $minutes minutes';
  }

  @override
  String get myPodcasts => 'My Podcasts';

  @override
  String get newPodcast => 'New podcast';

  @override
  String get createMyFirstPodcast => 'Create my first podcast';

  @override
  String viewAllEpisodes(int count) {
    return 'View all $count episodes';
  }

  @override
  String get newEpisode => 'New episode';

  @override
  String get noPodcastsYet => 'You don\'t have any podcasts yet';

  @override
  String get noPodcastsDescription =>
      'Create your first podcast and share your voice with the diaspora community!';

  @override
  String get noEpisodesPublished => 'No episodes published';

  @override
  String episodeListenInfo(String duration, int count) {
    return '$duration • $count listens';
  }

  @override
  String get viewPodcast => 'View podcast';

  @override
  String get statistics => 'Statistics';

  @override
  String get pausePodcast => 'Pause';

  @override
  String get publishPodcast => 'Publish';

  @override
  String get podcastPaused => 'Podcast paused';

  @override
  String get podcastPublished => 'Podcast published';

  @override
  String get deletePodcastTitle => 'Delete podcast?';

  @override
  String deletePodcastWarning(String title) {
    return 'Are you sure you want to delete \"$title\" and all its episodes? This action is irreversible.';
  }

  @override
  String get podcastDeleted => 'Podcast deleted';

  @override
  String get episodeDownloaded => 'Episode downloaded';

  @override
  String get deleteDownload => 'Delete download';

  @override
  String get downloadDeleted => 'Download deleted';

  @override
  String get selectPodcastOrCreate => 'Select a podcast or create a new one';

  @override
  String get recordingSoonAvailable => 'Room recording will be available soon';

  @override
  String get audioFileNotFound => 'Audio file not found';

  @override
  String get episodePublishedSuccess => 'Episode published successfully!';

  @override
  String get publicationError => 'Error during publication';

  @override
  String get publish => 'Publish';

  @override
  String get createAPodcast => 'Create a podcast';

  @override
  String get podcasts => 'Podcasts';

  @override
  String get noPodcastAvailable => 'No podcast available';

  @override
  String get noRecentEpisode => 'No recent episode';

  @override
  String get endOfEpisode => 'End of episode';

  @override
  String get addChapter => 'Add a chapter';

  @override
  String get add => 'Add';

  @override
  String get pleaseSelectAudioFile => 'Please select an audio file';

  @override
  String get premiumEpisode => 'Premium episode';

  @override
  String get subscribersOnly => 'Reserved for paying subscribers';

  @override
  String get podcastNotFound => 'Podcast not found';

  @override
  String get trending => 'Trending';

  @override
  String get newEpisodes => 'New episodes';

  @override
  String get resumeListening => 'Resume';

  @override
  String get categories => 'Categories';

  @override
  String get subscriptions => 'Subscriptions';

  @override
  String get noResultsFound => 'No results found';

  @override
  String get noSubscription => 'No subscriptions';

  @override
  String get subscribeToFindHere => 'Subscribe to podcasts to find them here';

  @override
  String get chapterTitle => 'Chapter title';

  @override
  String get marketplace => 'Marketplace';

  @override
  String get sell => 'Sell';

  @override
  String get allCountries => 'All countries';

  @override
  String get myProducts => 'My products';

  @override
  String get listForSale => 'List for sale';

  @override
  String get addAtLeastOneImage => 'Add at least one image';

  @override
  String get priceTTC => 'Price incl. taxes';

  @override
  String get subtotal => 'Subtotal';

  @override
  String taxRate(String rate) {
    return 'Tax ($rate%)';
  }

  @override
  String get myOrders => 'My orders';

  @override
  String get discoverProducts => 'Discover products';

  @override
  String get paymentSuccess => 'Payment successful!';

  @override
  String get orderUpdateError => 'Error updating order';

  @override
  String paymentError(String error) {
    return 'Payment error: $error';
  }

  @override
  String get deliveryConfirmed => 'Delivery confirmed';

  @override
  String get orderMarkedAsShipped => 'Order marked as shipped';

  @override
  String get trackingNumber => 'Tracking number';

  @override
  String get cart => 'Cart';

  @override
  String cartWithCount(int count) {
    return 'Cart ($count)';
  }

  @override
  String get emptyCart => 'Empty';

  @override
  String get total => 'Total';

  @override
  String get ordersCreatedSuccess => 'Order(s) created successfully!';

  @override
  String get loadingText => 'Loading...';

  @override
  String get deleteProduct => 'Delete product';

  @override
  String get addedToCart => 'Added to cart';

  @override
  String get addToCart => 'Add to cart';

  @override
  String get conversationCreationError => 'Error creating conversation';

  @override
  String get noProductsYet => 'You don\'t have any products yet';

  @override
  String get emptyCartMessage => 'Your cart is empty';

  @override
  String get businessDirectory => 'Business Directory';

  @override
  String get boostYourBusiness => 'Boost your business';

  @override
  String get boostActivatedSuccess => 'Boost activated successfully!';

  @override
  String get boostPurchaseError => 'Error purchasing boost';

  @override
  String get newBusiness => 'New business';

  @override
  String get photos => 'Photos';

  @override
  String get contact => 'Contact';

  @override
  String get servicesOffered => 'Services offered';

  @override
  String get createTheBusiness => 'Create the business';

  @override
  String get businessCreatedSuccess => 'Business created successfully!';

  @override
  String get creationError => 'Error during creation';

  @override
  String get boost => 'Boost';

  @override
  String get writeReview => 'Write a review';

  @override
  String get writeFirstReview => 'Write the first review';

  @override
  String viewAllReviews(int count) {
    return 'View all $count reviews';
  }

  @override
  String get mustBeLoggedInToReview =>
      'You must be logged in to leave a review';

  @override
  String get pleaseGiveRating => 'Please give a rating';

  @override
  String get pleaseWriteReview => 'Please write a review';

  @override
  String get submissionError => 'Error during submission';

  @override
  String get deleteReview => 'Delete review';

  @override
  String get deleteReviewConfirm =>
      'Do you really want to delete this review? This action is irreversible.';

  @override
  String get reviewDeleted => 'Review deleted';

  @override
  String get reportReview => 'Report this review';

  @override
  String get pleaseIndicateReason => 'Please indicate a reason';

  @override
  String get useMyLocation => 'Use my location';

  @override
  String get enterCity => 'Enter city';

  @override
  String get apply => 'Apply';

  @override
  String get newPost => 'New post';

  @override
  String get type => 'Type:';

  @override
  String get duration => 'Duration:';

  @override
  String get embassiesAndConsulates => 'Embassies & Consulates';

  @override
  String get contactEmbassy => 'Contact embassy';

  @override
  String get messageSentSuccess => 'Message sent successfully!';

  @override
  String get newRequest => 'New request';

  @override
  String get requestSubmittedSuccess => 'Request submitted successfully!';

  @override
  String get callAction => 'Call';

  @override
  String get groupModified => 'Group modified successfully';

  @override
  String get modificationError => 'Error during modification';

  @override
  String get nameRequired => 'Name is required';

  @override
  String get nameMinLength => 'Name must be at least 3 characters';

  @override
  String get privateGroup => 'Private group';

  @override
  String get groupCreated => 'Group created successfully';

  @override
  String get groupCreationError => 'Error creating group';

  @override
  String get promotionError => 'Error during promotion';

  @override
  String get demotionError => 'Error during demotion';

  @override
  String get requestSent => 'Request sent successfully';

  @override
  String get groupCountryHint =>
      'The country where the group community is located';

  @override
  String get memberRemoved => 'Member removed successfully';

  @override
  String get memberRemovalError => 'Error removing member';

  @override
  String get filterGroups => 'Groups';

  @override
  String get muted => 'Muted';

  @override
  String get pin => 'Pin';

  @override
  String get unpin => 'Unpin';

  @override
  String get pinLimitReached => 'You cannot pin more than 5 conversations';

  @override
  String get conversationPinned => 'Conversation pinned';

  @override
  String get editMessage => 'Edit message';

  @override
  String get edited => 'edited';

  @override
  String get editTimeExpired => 'Edit time has expired (25 min)';

  @override
  String get messageEdited => 'Message edited';

  @override
  String get conversationUnpinned => 'Conversation unpinned';

  @override
  String get disappearingMessages => 'Disappearing messages';

  @override
  String get disappearingMessagesDescription =>
      'New messages will disappear after the selected time';

  @override
  String get off => 'Off';

  @override
  String get hours24 => '24 hours';

  @override
  String get days7 => '7 days';

  @override
  String get days30 => '30 days';

  @override
  String expiresIn(Object time) {
    return 'Expires in $time';
  }

  @override
  String disappearingMessagesEnabled(Object duration) {
    return 'Disappearing messages enabled ($duration)';
  }

  @override
  String get disappearingMessagesDisabled => 'Disappearing messages disabled';

  @override
  String get muteNotifications => 'Mute notifications';

  @override
  String get muteNotificationsDescription =>
      'You will not receive notifications for this conversation during the selected time';

  @override
  String get muteFor1Hour => '1 hour';

  @override
  String get muteFor8Hours => '8 hours';

  @override
  String get muteFor24Hours => '24 hours';

  @override
  String get muteFor1Week => '1 week';

  @override
  String get muteForever => 'Always';

  @override
  String get conversationMuted => 'Conversation muted';

  @override
  String mutedUntil(Object time) {
    return 'Muted until $time';
  }

  @override
  String get emptyStateNoDataTitle => 'No data';

  @override
  String get emptyStateNoDataMessage =>
      'There\'s nothing to display at the moment.';

  @override
  String get emptyStateNoResultsTitle => 'No results';

  @override
  String get emptyStateNoResultsMessage => 'No results match your search.';

  @override
  String get emptyStateNoResultsAction => 'Clear search';

  @override
  String get emptyStateNoMessagesTitle => 'No messages';

  @override
  String get emptyStateNoMessagesMessage =>
      'You don\'t have any conversations yet. Start chatting with the community!';

  @override
  String get emptyStateNoMessagesAction => 'New conversation';

  @override
  String get emptyStateNoNotificationsTitle => 'No notifications';

  @override
  String get emptyStateNoNotificationsMessage =>
      'You\'re all caught up! No new notifications.';

  @override
  String get emptyStateNoEventsTitle => 'No events';

  @override
  String get emptyStateNoEventsMessage =>
      'There are no upcoming events at the moment.';

  @override
  String get emptyStateNoEventsAction => 'Create an event';

  @override
  String get emptyStateNoGroupsTitle => 'No groups';

  @override
  String get emptyStateNoGroupsMessage =>
      'You\'re not a member of any group. Join or create one!';

  @override
  String get emptyStateNoGroupsAction => 'Explore groups';

  @override
  String get emptyStateNoFriendsTitle => 'No friends yet';

  @override
  String get emptyStateNoFriendsMessage =>
      'Connect with other community members.';

  @override
  String get emptyStateNoFriendsAction => 'Find friends';

  @override
  String get emptyStateNoProductsTitle => 'No products';

  @override
  String get emptyStateNoProductsMessage => 'The marketplace is empty for now.';

  @override
  String get emptyStateNoProductsAction => 'Publish a product';

  @override
  String get emptyStateNoOrdersTitle => 'No orders';

  @override
  String get emptyStateNoOrdersMessage => 'You haven\'t placed any orders yet.';

  @override
  String get emptyStateNoOrdersAction => 'View marketplace';

  @override
  String get emptyStateNoTransactionsTitle => 'No transactions';

  @override
  String get emptyStateNoTransactionsMessage =>
      'You haven\'t made any transfers yet.';

  @override
  String get emptyStateNoTransactionsAction => 'Send money';

  @override
  String get emptyStateOfflineTitle => 'Offline mode';

  @override
  String get emptyStateOfflineMessage =>
      'You\'re currently offline. Some features may be limited.';

  @override
  String get emptyStateOfflineAction => 'Retry';

  @override
  String get emptyStateErrorTitle => 'An error occurred';

  @override
  String get emptyStateErrorMessage => 'Unable to load data. Please try again.';

  @override
  String get emptyStateErrorAction => 'Retry';

  @override
  String get emptyStateMaintenanceTitle => 'Maintenance in progress';

  @override
  String get emptyStateMaintenanceMessage =>
      'The app is under maintenance. Please check back later.';

  @override
  String get transferSelectRecipientFirst => 'Please select a recipient';

  @override
  String get transferSelectPaymentMethodFirst =>
      'Please select a payment method';

  @override
  String get transferInitiated => 'Transfer initiated successfully';

  @override
  String get transferFailed => 'Transfer failed';

  @override
  String get businessCreationError => 'Error during creation';

  @override
  String get reviewPleaseRate => 'Please give a rating';

  @override
  String get reviewPleaseWrite => 'Please write a review';

  @override
  String get reviewSubmitted => 'Review submitted successfully';

  @override
  String get reviewSubmissionError => 'Error during submission';

  @override
  String get mustBeLoggedIn => 'You must be logged in';

  @override
  String get groupRequestSent => 'Request sent successfully';

  @override
  String get groupRequestApproved => 'Request approved';

  @override
  String get groupRequestDeclined => 'Request declined';

  @override
  String get messageSent => 'Message sent';

  @override
  String get cannotGetLocation => 'Unable to get location';

  @override
  String get reminderScheduled => 'Reminder scheduled';

  @override
  String get reminderRemoved => 'Reminder removed';

  @override
  String get reminderPassed => 'Passed';

  @override
  String get selectAudioFile => 'Please select an audio file';

  @override
  String get episodePublished => 'Episode published successfully';

  @override
  String get downloadRemoved => 'Download removed';

  @override
  String get transactionStatusPending => 'Pending';

  @override
  String get transactionStatusDebiting => 'Debiting';

  @override
  String get transactionStatusProcessing => 'Processing';

  @override
  String get transactionStatusSending => 'Sending';

  @override
  String get transactionStatusCompleted => 'Completed';

  @override
  String get transactionStatusFailed => 'Failed';

  @override
  String get transactionStatusRefunding => 'Refunding';

  @override
  String get transactionStatusRefunded => 'Refunded';

  @override
  String get transactionStatusCancelled => 'Cancelled';

  @override
  String get businessCategoryRestaurant => 'Restaurant';

  @override
  String get businessCategoryGrocery => 'Grocery';

  @override
  String get businessCategoryBeauty => 'Beauty';

  @override
  String get businessCategoryFashion => 'Fashion';

  @override
  String get businessCategoryServices => 'Services';

  @override
  String get businessCategoryHealth => 'Health';

  @override
  String get businessCategoryEducation => 'Education';

  @override
  String get businessCategoryTechnology => 'Technology';

  @override
  String get businessCategoryTravel => 'Travel';

  @override
  String get businessCategoryOther => 'Other';

  @override
  String get callAudio => 'Audio call';

  @override
  String get callVideo => 'Video call';

  @override
  String get callRinging => 'Ringing';

  @override
  String get callOngoing => 'Ongoing';

  @override
  String get callMissed => 'Missed';

  @override
  String get callDeclined => 'Declined';

  @override
  String get callFailed => 'Failed';

  @override
  String errorWithMessage(String message) {
    return 'Error: $message';
  }

  @override
  String get consentWelcome => 'Welcome!';

  @override
  String get consentAcceptConditions =>
      'Before continuing, please accept our conditions.';

  @override
  String get consentTermsAccept =>
      'I accept the terms and conditions of the Diaspo Niger application.';

  @override
  String get consentPrivacyAccept =>
      'I accept the privacy policy and the processing of my personal data.';

  @override
  String get consentCodeOfConductAccept =>
      'I commit to respecting the code of conduct and community rules.';

  @override
  String get consentDataProtection =>
      'Your data is protected and will never be shared without your consent.';

  @override
  String get readDetails => 'Read details →';

  @override
  String get forgotPasswordTitle => 'Forgot password?';

  @override
  String get forgotPasswordDescription =>
      'Enter your email address to receive a reset link.';

  @override
  String get sendLink => 'Send link';

  @override
  String get backToLogin => 'Back to login';

  @override
  String get emailSentTitle => 'Email sent!';

  @override
  String resetLinkSentTo(String email) {
    return 'We sent a reset link to $email';
  }

  @override
  String get checkSpamFolder =>
      'Also check your spam folder if you can\'t find the email.';

  @override
  String get resendLink => 'Resend link';

  @override
  String get enableNotifications => 'Enable notifications';

  @override
  String get notificationsMasterOnDesc =>
      'You receive the app\'s notifications';

  @override
  String get notificationsMasterOffDesc => 'All notifications are turned off';

  @override
  String get notificationPromptMessage =>
      'Receive alerts when you have new messages, incoming calls or important activities.\n\nYou can change this setting at any time.';

  @override
  String get later => 'Later';

  @override
  String get notificationsDisabledMessage =>
      'Notifications are disabled. You will not receive alerts for new messages and calls.\n\nTo enable them, go to the application settings.';

  @override
  String get openSettings => 'Open settings';

  @override
  String get permissionBlocked => 'Permission blocked';

  @override
  String get typeYourReply => 'Type your reply...';

  @override
  String get openPlayStore => 'Open Play Store';

  @override
  String get understood => 'Understood';

  @override
  String get connectedElsewhere => 'Connected elsewhere';

  @override
  String get connectedElsewhereMessage =>
      'Your account has been connected on another device. You have been logged out from this device for security.';

  @override
  String get ok => 'OK';

  @override
  String get taxAutomatic => 'Automatic';

  @override
  String get taxExempt => 'Tax exempt';

  @override
  String get taxStandard => 'Standard VAT (19%)';

  @override
  String get taxReduced => 'Reduced VAT (10%)';

  @override
  String get taxCustom => 'Custom';

  @override
  String get views => 'views';

  @override
  String get reviews => 'Reviews';

  @override
  String get contactAction => 'Contact';

  @override
  String get addAction => 'Add';

  @override
  String get viewAll => 'View all';

  @override
  String get modify => 'Modify';

  @override
  String get retryAction => 'Retry';

  @override
  String get tooltipFavorites => 'Favorites';

  @override
  String get tooltipForward => 'Forward';

  @override
  String get tooltipDelete => 'Delete';

  @override
  String get tooltipVoiceCall => 'Voice call';

  @override
  String get tooltipVideoCall => 'Video call';

  @override
  String get addCaption => 'Add a caption...';

  @override
  String get photosLabel => 'Photos';

  @override
  String get videosLabel => 'Videos';

  @override
  String get audioLabel => 'Audio';

  @override
  String get documentsLabel => 'Documents';

  @override
  String get photoLabel => 'Photo';

  @override
  String get videoLabel => 'Video';

  @override
  String get positionLabel => 'Position';

  @override
  String get microphonePermissionRequired => 'Microphone permission required';

  @override
  String get cannotDeleteAfter1Hour => 'Cannot delete message after 1 hour';

  @override
  String get sendAction => 'Send';

  @override
  String get forwardError => 'Error forwarding message';

  @override
  String get cannotStartCall => 'Cannot start the call';

  @override
  String get remindMeLater => 'Remind me later';

  @override
  String get in1Hour => 'In 1 hour';

  @override
  String get tomorrowMorning => 'Tomorrow morning (9am)';

  @override
  String get flipCamera => 'Flip';

  @override
  String get permissionRequired => 'Permission required';

  @override
  String get adminOverview => 'Overview';

  @override
  String get adminUsers => 'Users';

  @override
  String get adminBusinesses => 'Businesses';

  @override
  String get adminContent => 'Content';

  @override
  String get adminReports => 'Reports';

  @override
  String get adminSupport => 'Support';

  @override
  String get adminLiveRooms => 'Live Rooms';

  @override
  String get adminMarketplace => 'Marketplace';

  @override
  String get adminTransfers => 'Transfers';

  @override
  String get adminEmbassies => 'Embassies';

  @override
  String get adminAnalytics => 'Analytics';

  @override
  String get adminNotifications => 'Notifications';

  @override
  String get adminConfiguration => 'Configuration';

  @override
  String get adminFeatures => 'Features';

  @override
  String get adminAudit => 'Audit';

  @override
  String get adminRoles => 'Admin Roles';

  @override
  String get adminRefresh => 'Refresh';

  @override
  String get adminLogout => 'Logout';

  @override
  String get adminCreateEmbassy => 'Create an embassy';

  @override
  String get adminModerate => 'Moderate';

  @override
  String get adminModerationMode => 'Moderation Mode';

  @override
  String get adminGhostModeDescription =>
      'You will join this room in invisible mode (ghost mode). Participants will not be able to see you.\n\nYou will be able to:\n• Listen to conversations\n• Watch videos (if enabled)\n• Warn the host\n• Close the room if necessary';

  @override
  String get adminJoin => 'Join';

  @override
  String get adminViewReports => 'View Reports';

  @override
  String get adminManageUsers => 'Manage Users';

  @override
  String get adminSendNotification => 'Send Notification';

  @override
  String get adminViewAnalytics => 'View Analytics';

  @override
  String get adminFeatureFlags => 'Feature Flags';

  @override
  String get adminAuditHistory => 'Audit History';

  @override
  String get adminNewAdmin => 'New Admin';

  @override
  String adminChangeRole(String role) {
    return 'Change role';
  }

  @override
  String get adminRevokeAccess => 'Revoke admin access';

  @override
  String get adminAccessDenied =>
      'Access denied. Administrator account required.';

  @override
  String get adminBack => 'Back';

  @override
  String adminAllTab(int count) {
    return 'All ($count)';
  }

  @override
  String adminPendingTab(int count) {
    return 'Pending ($count)';
  }

  @override
  String adminBoostedTab(int count) {
    return 'Boosted ($count)';
  }

  @override
  String get adminVerify => 'Verify';

  @override
  String get adminRemoveVerification => 'Remove verification';

  @override
  String get adminBoost30Days => 'Boost (30 days)';

  @override
  String get adminRemoveBoost => 'Remove boost';

  @override
  String get adminConfirmDeletion => 'Confirm deletion';

  @override
  String get adminGroupPrivate => 'Group made private';

  @override
  String get adminGroupPublic => 'Group made public';

  @override
  String get makePublic => 'Make public';

  @override
  String get makePrivate => 'Make private';

  @override
  String get adminEmailLabel => 'Email';

  @override
  String get adminEmailHint => 'user@example.com';

  @override
  String get adminEmbassyCreated => 'Embassy created successfully!';

  @override
  String get adminConnectionError => 'Error connecting to room';

  @override
  String get adminSearchPlaceholder => 'Search by name, reason, ID...';

  @override
  String get adminAllActions => 'All actions';

  @override
  String get adminActionUsers => 'Users';

  @override
  String get adminActionBusinesses => 'Businesses';

  @override
  String get adminActionContent => 'Content';

  @override
  String get adminActionReports => 'Reports';

  @override
  String get adminActionTransactions => 'Transactions';

  @override
  String get adminActionSettings => 'Settings';

  @override
  String get adminFeatureFlagsUpdated => 'Feature flags updated';

  @override
  String get adminMaintenanceHint => 'Ex: Application under maintenance...';

  @override
  String get adminSignInWithGoogle => 'Sign in with Google';

  @override
  String get adminEmailField => 'Email';

  @override
  String get adminPasswordField => 'Password';

  @override
  String get adminLogin => 'Login';

  @override
  String adminProductsTab(int count) {
    return 'Products ($count)';
  }

  @override
  String adminOrdersTab(int count) {
    return 'Orders ($count)';
  }

  @override
  String adminDisputesTab(int count) {
    return 'Disputes ($count)';
  }

  @override
  String get adminBuyer => 'Buyer';

  @override
  String get adminSeller => 'Seller';

  @override
  String get adminRefund => 'Refund';

  @override
  String adminGroupsTab(int count) {
    return 'Groups ($count)';
  }

  @override
  String get adminSendTab => 'Send';

  @override
  String get adminHistoryTab => 'History';

  @override
  String get adminTitleLabel => 'Title';

  @override
  String get adminMessageLabel => 'Message';

  @override
  String get adminClearAction => 'Clear';

  @override
  String get adminConfirmSend => 'Confirm send';

  @override
  String get adminSendingNotificationTo =>
      'You are about to send a notification to:';

  @override
  String adminMessagePreview(String message) {
    return 'Message: $message';
  }

  @override
  String get adminSearchReportsPlaceholder => 'Search by name, reason, ID...';

  @override
  String adminViewTarget(String type) {
    return 'View $type';
  }

  @override
  String get adminReject => 'Reject';

  @override
  String get adminProcess => 'Process';

  @override
  String get adminDeleteContent => 'Delete content';

  @override
  String get adminClearFilters => 'Clear filters';

  @override
  String get adminRejectReasonHint =>
      'Ex: Report unfounded, content compliant...';

  @override
  String get adminProcessNoteHint => 'Ex: Warning sent, content modified...';

  @override
  String adminChangeToRole(String role) {
    return 'Change to $role';
  }

  @override
  String get adminFeesTab => 'Fees';

  @override
  String get adminBoostsTab => 'Boosts';

  @override
  String get adminTaxesTab => 'Taxes';

  @override
  String get adminMediaTab => 'Media';

  @override
  String get adminSystemTab => 'System';

  @override
  String get adminAudioTab => 'Audio';

  @override
  String get adminFeesUpdated => 'Fees updated';

  @override
  String get adminFeePercentage => 'Fee percentage';

  @override
  String get adminMinFee => 'Minimum fee (XOF)';

  @override
  String get adminMaxFee => 'Maximum fee (XOF)';

  @override
  String get adminPlatformCommission => 'Platform commission';

  @override
  String get adminMinCommission => 'Min commission (XOF)';

  @override
  String get adminMaxCommission => 'Max commission (XOF)';

  @override
  String get adminBoostPricesUpdated => 'Boost prices updated';

  @override
  String get adminVatRatesUpdated => 'VAT rates updated';

  @override
  String get adminMediaLimitsUpdated => 'Media limits updated';

  @override
  String get adminMaxDimension => 'Max dimension (px)';

  @override
  String get adminCompressionQuality => 'Compression quality (%)';

  @override
  String get adminMaxImagesUpload => 'Max images/upload';

  @override
  String get adminMaxImageSize => 'Max image size (MB)';

  @override
  String get adminMaxVideoSize => 'Max video size (MB)';

  @override
  String get adminMaxMessageChars => 'Max message characters';

  @override
  String get adminUrlsUpdated => 'URLs updated';

  @override
  String get adminIntervalsUpdated => 'Intervals updated';

  @override
  String get adminShareBaseUrl => 'Share base URL';

  @override
  String get adminSupportEmail => 'Support email';

  @override
  String get adminPrivacyEmail => 'Privacy email (GDPR)';

  @override
  String get adminBugReportEmail => 'Bug report email';

  @override
  String get adminFeedbackEmail => 'Feedback email';

  @override
  String get adminModerationEmail => 'Moderation email';

  @override
  String get adminLocationUpdateInterval => 'Location update (min)';

  @override
  String get adminOnlineHeartbeat => 'Online status heartbeat (min)';

  @override
  String get adminCacheDuration => 'Cache duration (min)';

  @override
  String get adminAudioSettingsUpdated => 'Audio settings updated';

  @override
  String get adminTicketPrices => 'Ticket prices (XOF)';

  @override
  String get adminTipAmounts => 'Tip amounts (XOF)';

  @override
  String get adminPriceHint => 'Ex: 1, 2, 5, 10, 20';

  @override
  String get adminComplete => 'Complete';

  @override
  String get adminSearchUserPlaceholder => 'Search for a user...';

  @override
  String get adminLoadingText => 'Loading...';

  @override
  String get adminNoUserFound => 'No user found';

  @override
  String adminUserActivity(String name) {
    return 'Activity of $name';
  }

  @override
  String get adminNoActivity => 'No activity recorded';

  @override
  String get adminConfirmLogout => 'Confirm logout';

  @override
  String get adminDisconnect => 'Disconnect';

  @override
  String get adminReactivate => 'Reactivate';

  @override
  String get adminApprove => 'Approve';

  @override
  String get adminSuspend => 'Suspend';

  @override
  String adminEmbassyApproved(String name) {
    return 'Embassy $name approved';
  }

  @override
  String adminEmbassyRejected(String name) {
    return 'Embassy $name rejected';
  }

  @override
  String adminEmbassySuspended(String name) {
    return 'Embassy $name suspended';
  }

  @override
  String adminEmbassyReactivated(String name) {
    return 'Embassy $name reactivated';
  }

  @override
  String get adminRejectRequest => 'Reject request';

  @override
  String get adminRejectReason => 'Reason for rejection';

  @override
  String adminExportInProgress(String type) {
    return 'Export of $type in progress...';
  }

  @override
  String get audioRoomWarnHost => 'Warn the host';

  @override
  String audioRoomTicketHelper(String min, String max, String currency) {
    return 'Min: $min $currency - Max: $max $currency';
  }

  @override
  String audioRoomGoalHelper(String min, String max) {
    return 'Min: $min XOF - Max: $max XOF';
  }

  @override
  String get heritageStories => 'Stories';

  @override
  String get heritageProverbs => 'Proverbs';

  @override
  String get heritageHistory => 'History';

  @override
  String get heritageCeremonies => 'Ceremonies';

  @override
  String get heritageLanguage => 'Language';

  @override
  String get heritageCraft => 'Craft';

  @override
  String get heritageRecipes => 'Recipes';

  @override
  String get heritageMedicine => 'Medicine';

  @override
  String get boostType => 'Type:';

  @override
  String get boostDuration => 'Duration:';

  @override
  String get boostTotal => 'Total:';

  @override
  String get businessViews => 'Views';

  @override
  String get businessReviews => 'Reviews';

  @override
  String get businessContact => 'Contact';

  @override
  String get businessAdd => 'Add';

  @override
  String get businessNewPost => 'New post';

  @override
  String get businessPostType => 'Type';

  @override
  String get businessPostTitle => 'Title';

  @override
  String get businessPostTitleHint => 'Ex: New collection available';

  @override
  String get businessPostContent => 'Content';

  @override
  String get businessPostContentHint => 'Describe your news...';

  @override
  String get businessDeletePost => 'Delete';

  @override
  String businessSeeAllReviews(int count) {
    return 'View $count other reviews';
  }

  @override
  String get reviewMustBeLoggedIn => 'You must be logged in to leave a review';

  @override
  String get reviewDeleteTitle => 'Delete review';

  @override
  String get reviewDeleteConfirm =>
      'Do you really want to delete this review? This action is irreversible.';

  @override
  String get reviewReportTitle => 'Report this review';

  @override
  String get reviewReportReason => 'Report reason';

  @override
  String get reviewReportHint => 'Why are you reporting this review?';

  @override
  String get reviewReportNoReason => 'Please indicate a reason';

  @override
  String get reviewModify => 'Edit';

  @override
  String get reviewReport => 'Report';

  @override
  String get reviewSubmitError => 'Error submitting';

  @override
  String get reviewTitleOptional => 'Title (optional)';

  @override
  String get reviewTitleHint => 'Ex: Excellent service';

  @override
  String get reviewYourReview => 'Your review';

  @override
  String get reviewShareExperience => 'Share your experience...';

  @override
  String get businessSearchCountry => 'Search for a country';

  @override
  String get businessCityHint => 'Ex: Paris, Niamey, New York...';

  @override
  String get businessNewTitle => 'New business';

  @override
  String get businessPhotosSection => 'Photos';

  @override
  String get businessCategorySection => 'Category';

  @override
  String get businessNameLabel => 'Business name *';

  @override
  String get businessDescriptionLabel => 'Description *';

  @override
  String get businessContactSection => 'Contact';

  @override
  String get businessPhoneLabel => 'Phone';

  @override
  String get businessEmailLabel => 'Email';

  @override
  String get businessWebsiteLabel => 'Website';

  @override
  String get businessLocationSection => 'Location';

  @override
  String get businessSearchCountryHint => 'Type the country name';

  @override
  String get businessCountryLabel => 'Country';

  @override
  String get businessCityLabel => 'City';

  @override
  String get businessAddressLabel => 'Address';

  @override
  String get businessServicesSection => 'Services offered';

  @override
  String get businessAddServiceHint => 'Add a service';

  @override
  String get businessCreateButton => 'Create business';

  @override
  String get callPermissionTitle => 'Permission required';

  @override
  String get callClose => 'Close';

  @override
  String get embassyRequestSubmitted => 'Request submitted successfully!';

  @override
  String get embassyNewRequest => 'New request';

  @override
  String embassyReopenDate(String date) {
    return 'Expected reopening: $date';
  }

  @override
  String get embassyContact => 'Contact';

  @override
  String get embassyRequest => 'Request';

  @override
  String get embassyStaff => 'Staff';

  @override
  String get embassyCall => 'Call';

  @override
  String get embassyEmail => 'Email';

  @override
  String get embassyWebsite => 'Website';

  @override
  String get embassyDirections => 'Go there';

  @override
  String get embassyMessageSent => 'Message sent successfully!';

  @override
  String get embassyContactTitle => 'Contact the embassy';

  @override
  String get embassySubjectHint => 'Ex: Passport information request';

  @override
  String get embassyMessageHint => 'Describe your request in detail...';

  @override
  String get embassyDepartment => 'Department';

  @override
  String get embassyCallAction => 'Call';

  @override
  String get embassyRoute => 'Route';

  @override
  String get embassyDetails => 'Details';

  @override
  String eventImageSelectionError(String error) {
    return 'Error selecting images: $error';
  }

  @override
  String get eventSelectImages => 'Select images';

  @override
  String get eventPosterLimit => 'Limit of 5 posters reached';

  @override
  String get eventShareRecap => 'Share recap';

  @override
  String get eventPhotoLimit => 'Limit of 10 photos reached';

  @override
  String get eventAddPhotoMin => 'Please add at least one photo';

  @override
  String get eventSelectPhotos => 'Select photos';

  @override
  String eventAddPhotos(int count) {
    return 'Add photos ($count/10)';
  }

  @override
  String get friendSendMessage => 'Send message';

  @override
  String get friendRemoveTitle => 'Remove friend';

  @override
  String get friendRemoveAction => 'Remove';

  @override
  String get friendRequestDeclined => 'Request declined';

  @override
  String get friendDecline => 'Decline';

  @override
  String get friendRequestAccepted => 'Request accepted';

  @override
  String get friendAccept => 'Accept';

  @override
  String get friendRequestCancelled => 'Request cancelled';

  @override
  String get friendCancelRequest => 'Cancel request';

  @override
  String get groupCreateTitle => 'Create group';

  @override
  String get groupEditTitle => 'Edit group';

  @override
  String get groupPromoteAdmin => 'Promote to Admin';

  @override
  String get groupDemoteAdmin => 'Remove Admin';

  @override
  String get groupConfirmAction => 'Confirm';

  @override
  String get groupMembershipRequests => 'Membership requests';

  @override
  String get groupRejectTooltip => 'Reject';

  @override
  String get groupApproveTooltip => 'Approve';

  @override
  String get groupFilterAll => 'All';

  @override
  String get groupFilterAllFeminine => 'All';

  @override
  String get shareWhatsApp => 'WhatsApp';

  @override
  String get shareFacebook => 'Facebook';

  @override
  String get shareX => 'X';

  @override
  String get shareMore => 'More';

  @override
  String get homeMessages => 'Messages';

  @override
  String get homeGroups => 'Groups';

  @override
  String get homeMarketplace => 'Marketplace';

  @override
  String get homeTransfers => 'Transfers';

  @override
  String get homeDirectory => 'Directory';

  @override
  String get mapEnable => 'ENABLE';

  @override
  String get mapTestTitle => 'Simple Map Test';

  @override
  String get marketplaceAddImageMin => 'Add at least one image';

  @override
  String get marketplaceCustomTaxRate => 'Custom rate (%)';

  @override
  String get marketplaceCustomTaxHint => 'Ex: 15';

  @override
  String get marketplacePriceTTC => 'Price including tax';

  @override
  String get marketplaceSubtotal => 'Subtotal';

  @override
  String marketplaceTaxRate(String rate) {
    return 'Tax ($rate%)';
  }

  @override
  String get marketplaceTitleLabel => 'Title';

  @override
  String get marketplaceTitleHint => 'Ex: iPhone 13 Pro Max';

  @override
  String get marketplaceDescriptionLabel => 'Description';

  @override
  String get marketplaceDescriptionHint => 'Describe your product...';

  @override
  String get marketplacePriceLabel => 'Price';

  @override
  String get marketplaceQuantityLabel => 'Quantity';

  @override
  String get marketplaceCurrencyLabel => 'Currency';

  @override
  String get marketplaceCategoryLabel => 'Category';

  @override
  String get marketplaceConditionLabel => 'Condition';

  @override
  String get marketplaceCountryLabel => 'Country';

  @override
  String get marketplaceCityLabel => 'City/Address (optional)';

  @override
  String get marketplaceCityHint => 'Ex: Niamey';

  @override
  String get marketplaceAllCategory => 'All';

  @override
  String get marketplaceMyOrders => 'My orders';

  @override
  String get marketplaceDiscoverProducts => 'Discover products';

  @override
  String get marketplacePaymentSuccess => 'Payment successful!';

  @override
  String get marketplaceOrderUpdateError => 'Error updating order';

  @override
  String marketplacePaymentError(String error) {
    return 'Payment error: $error';
  }

  @override
  String get marketplaceDeliveryConfirmed => 'Delivery confirmed';

  @override
  String get marketplaceMarkedAsShipped => 'Order marked as shipped';

  @override
  String get marketplaceTrackingNumber => 'Tracking number';

  @override
  String get marketplaceTrackingHint => 'Enter tracking number (optional)';

  @override
  String get marketplaceLoadingLabel => 'Loading...';

  @override
  String get marketplaceViewsLabel => 'views';

  @override
  String get marketplacePublishedLabel => 'published';

  @override
  String get marketplaceAddedToCart => 'Added to cart';

  @override
  String get marketplaceViewCart => 'View';

  @override
  String get marketplaceAddToCart => 'Add to cart';

  @override
  String get marketplaceDeleteProduct => 'Delete product';

  @override
  String get marketplaceConversationError => 'Error creating conversation';

  @override
  String get messageVideoPlayError => 'Video playback error';

  @override
  String get messageVideoSaved => 'Video saved to gallery';

  @override
  String get messageVideoSaveError => 'Error saving video';

  @override
  String get messageInfo => 'Info';

  @override
  String messageBackgroundError(String error) {
    return 'Error selecting image: $error';
  }

  @override
  String messageBackgroundApplyError(String error) {
    return 'Error applying: $error';
  }

  @override
  String messagePhotosCount(int count) {
    return 'Photos ($count)';
  }

  @override
  String messageFilesCount(int count) {
    return 'Files ($count)';
  }

  @override
  String get messageLocationSearchHint => 'Search for a place...';

  @override
  String get messageLocationError => 'Unable to get location';

  @override
  String get messageSendThisPosition => 'Send this location';

  @override
  String get fileLabel => 'File';

  @override
  String get messageTypeAudio => '🎵 Audio';

  @override
  String get messageTypeVoiceNote => 'Voice note';

  @override
  String get shareError => 'Unable to share this content';

  @override
  String get shareDownloadingMedia => 'Preparing media...';

  @override
  String get messageInfoTitle => 'Message info';

  @override
  String messageSentAt(String time) {
    return 'Sent · $time';
  }

  @override
  String tabReadBy(int n) {
    return 'Read · $n';
  }

  @override
  String tabDeliveredTo(int n) {
    return 'Received · $n';
  }

  @override
  String tabReactions(int n) {
    return 'Reactions · $n';
  }

  @override
  String get allReactions => 'All';

  @override
  String get noReactionsYet => 'No reactions yet';

  @override
  String get notReadYet => 'No one has read this message yet';

  @override
  String get notDeliveredYet => 'Not delivered yet';

  @override
  String get documentPDF => 'PDF';

  @override
  String get documentDOC => 'DOC';

  @override
  String get documentXLS => 'XLS';

  @override
  String get documentPPT => 'PPT';

  @override
  String get documentZIP => 'ZIP';

  @override
  String get documentTXT => 'TXT';

  @override
  String get documentCSV => 'CSV';

  @override
  String get documentJSON => 'JSON';

  @override
  String get notificationIn1Hour => 'In 1 hour';

  @override
  String get notificationTomorrowMorning => 'Tomorrow morning (9am)';

  @override
  String get notificationReminderScheduled => 'Reminder scheduled';

  @override
  String get paymentBankHint => 'Ex: BCEAO, Ecobank...';

  @override
  String get paymentIbanHint => 'NEXX XXXX XXXX XXXX';

  @override
  String get podcastTitleLabel => 'Podcast title *';

  @override
  String get podcastDescriptionLabel => 'Description';

  @override
  String get podcastCategoryLabel => 'Category *';

  @override
  String get podcastLanguageLabel => 'Language *';

  @override
  String get podcastFrequencyLabel => 'Publishing frequency';

  @override
  String get podcastTagsLabel => 'Tags';

  @override
  String get podcastTagsHint => 'Add a tag';

  @override
  String get podcastLike => 'Like';

  @override
  String get podcastSleepTimerDisabled => 'Disabled';

  @override
  String get podcastEpisodeEnd => 'End of episode';

  @override
  String get podcastSleepTimerEnabled => 'Stop at end of episode enabled';

  @override
  String get podcastSleepTimerEnded => 'Sleep timer ended';

  @override
  String podcastTimerMinutes(int minutes) {
    return 'Timer: $minutes minutes';
  }

  @override
  String get podcastAddChapter => 'Add chapter';

  @override
  String get podcastChapterTitle => 'Chapter title';

  @override
  String get podcastMinutes => 'Minutes';

  @override
  String get podcastSeconds => 'Seconds';

  @override
  String get podcastSelectAudioFile => 'Please select an audio file';

  @override
  String get podcastNewEpisode => 'New episode';

  @override
  String get podcastEpisodeTitle => 'Episode title *';

  @override
  String get podcastEpisodeNotes => 'Description / Notes';

  @override
  String get podcastPremiumOnly => 'For paying subscribers only';

  @override
  String get podcastDownloaded => 'Downloaded';

  @override
  String get podcastDownload => 'Download';

  @override
  String get podcastDeleteDownload => 'Delete download';

  @override
  String get podcastDownloadRemoved => 'Download removed';

  @override
  String get podcastSelectOrCreate => 'Select a podcast or create a new one';

  @override
  String get podcastRecordingComingSoon =>
      'Room recording will be available soon';

  @override
  String get podcastAudioNotFound => 'Audio file not found';

  @override
  String get podcastPublishError => 'Error publishing';

  @override
  String get podcastEpisodeTitleHint => 'Episode title';

  @override
  String get podcastEpisodeDescriptionHint => 'Episode description (optional)';

  @override
  String get podcastPublish => 'Publish';

  @override
  String get podcastCreateNew => 'Create a podcast';

  @override
  String get profileSpecifyProfession => 'Specify your profession';

  @override
  String get profileSpecifyCountry => 'Or enter your country';

  @override
  String get profileRegion => 'Region';

  @override
  String get profileOriginCity => 'City of origin';

  @override
  String get profileSpecifyOriginCity => 'Specify your city of origin';

  @override
  String get profilePhoneVerified => 'Number verified successfully!';

  @override
  String profileCodeSent(String phone) {
    return 'Code sent to $phone';
  }

  @override
  String get profileConfigTitle => 'Profile configuration';

  @override
  String get profilePrevious => 'Previous';

  @override
  String get profileFullNameLabel => 'Full name';

  @override
  String get profileFullNameHint => 'Ex: John Doe';

  @override
  String get profileProfessionLabel => 'Profession';

  @override
  String get profileProfessionHint => 'Select your profession';

  @override
  String get profileCurrentCityLabel => 'Current city';

  @override
  String get profileCurrentCityHint => 'Ex: Paris, Niamey, New York...';

  @override
  String get profileOriginCityHint => 'Your city...';

  @override
  String get profileShareLocation => 'Share my location';

  @override
  String get profileEnableNotifications => 'Enable notifications';

  @override
  String get profileReceiveAllNotifications => 'Receive all notifications';

  @override
  String get profileNewEventsInCity => 'New events in your city';

  @override
  String get profileMessagesNotifications => 'Messages';

  @override
  String get profileNewMessagesNotifications =>
      'New messages and conversations';

  @override
  String get profileCurrentCountryLabel => 'Current country';

  @override
  String get profileSelectCountry => 'Select your country';

  @override
  String get profileOriginRegionLabel => 'Region of origin';

  @override
  String get profileSelectRegion => 'Select your region';

  @override
  String get profileOriginCityLabel => 'City of origin';

  @override
  String get profileSelectCity => 'Select your city';

  @override
  String get profileLocationDenied => 'Location permission denied';

  @override
  String get profileCannotChatDeleted => 'Cannot chat with a deleted user';

  @override
  String get profileCannotCall => 'Cannot call this user';

  @override
  String get profileBlockUser => 'Block user';

  @override
  String get profileTravelMode => 'Travel Mode';

  @override
  String get profileAudioCall => 'Audio';

  @override
  String get profileVideoCall => 'Video';

  @override
  String get profileRequestCancelled => 'Friend request cancelled';

  @override
  String get profileRequestNotExist => 'This request no longer exists.';

  @override
  String get profileCancelRequestAction => 'Cancel request';

  @override
  String get profileRequestDeclined => 'Friend request declined';

  @override
  String get profileDeclineAction => 'Decline';

  @override
  String get profileRequestAccepted => 'Friend request accepted';

  @override
  String get profileAcceptAction => 'Accept';

  @override
  String get profileQRScanned => 'QR code scanned successfully';

  @override
  String get reportMyReports => 'My reports';

  @override
  String get reportDescribeIssue => 'Describe the issue...';

  @override
  String get reportSendReport => 'Send report';

  @override
  String get settingsRenameDevice => 'Rename device';

  @override
  String get settingsDeviceName => 'Device name';

  @override
  String get settingsRenameAction => 'Rename';

  @override
  String get settingsRevokeDevice => 'Revoke device?';

  @override
  String get settingsRevokeAction => 'Revoke';

  @override
  String get settingsConnectedDevices => 'Connected devices';

  @override
  String get settingsDeleteBackup => 'Delete backup?';

  @override
  String get settingsKeyBackup => 'Key backup';

  @override
  String get settingsPassphraseLabel => 'Passphrase';

  @override
  String get settingsRestoreKeys => 'Restore keys';

  @override
  String get settingsGeneratePassphrase => 'Generate secure passphrase';

  @override
  String get settingsPassphraseHint => 'Minimum 8 characters';

  @override
  String get settingsConfirmPassphrase => 'Confirm passphrase';

  @override
  String get settingsCreateBackup => 'Create backup';

  @override
  String get settingsTermsOfService => 'Terms of Service';

  @override
  String get settingsBugDescriptionLabel => 'Bug description';

  @override
  String get settingsBugDescriptionHint =>
      'Describe the issue you encountered...';

  @override
  String get settingsCurrencySearchHint => 'Search for a currency...';

  @override
  String get transferFullNameLabel => 'Full name *';

  @override
  String get transferFullNameHint => 'Ex: Amadou Boubacar';

  @override
  String get transferPhoneLabel => 'Phone number *';

  @override
  String get transferEmailOptional => 'Email (optional)';

  @override
  String get transferEmailHint => 'example@email.com';

  @override
  String get transferCardNameLabel => 'Name on card *';

  @override
  String get transferCardNameHint => 'JOHN DOE';

  @override
  String get transferChangeCard => 'Change';

  @override
  String get transferCardInfoLabel => 'Card information *';

  @override
  String get transferCountryLabel => 'Country';

  @override
  String get transferCityLabel => 'City';

  @override
  String get transferAddressOptional => 'Address (optional)';

  @override
  String get transferAddressHint => 'Neighborhood, street...';

  @override
  String get transferAddToFavorites => 'Add to favorites';

  @override
  String get transferFavoritesSubtitle => 'Quick access for future transfers';

  @override
  String get transferEnterCardInfo => 'Please enter complete card information';

  @override
  String get transferDeleteRecipient => 'Delete recipient?';

  @override
  String get transferRecipientDeleted => 'Recipient deleted';

  @override
  String get transferNewRecipient => 'New';

  @override
  String get transferAddManually => 'Add manually';

  @override
  String get transferChooseRecipient => 'Choose a recipient';

  @override
  String get transferAddRecipientTooltip => 'Add a recipient';

  @override
  String get transferEditRecipient => 'Edit';

  @override
  String transferDeleteConfirm(String name) {
    return 'Delete $name?';
  }

  @override
  String get transferAccountNumber => 'Account number / IBAN *';

  @override
  String get transferAccountHint => 'XXXX XXXX XXXX XXXX';

  @override
  String get transferCurrencyLabel => 'Currency';

  @override
  String get transferMessageTitle => 'Message';

  @override
  String get transferSelectRecipient => 'Select a recipient';

  @override
  String get transferTotal => 'Total:';

  @override
  String transferDebitInProgress(String provider) {
    return '$provider debit in progress...';
  }

  @override
  String get transferDetails => 'Transfer details';

  @override
  String get transferAmountSentLabel => 'Amount sent';

  @override
  String get transferCopied => 'Copied to clipboard';

  @override
  String get transferRetry => 'Retry transfer';

  @override
  String get transferContactSupport => 'Contact support';

  @override
  String get transferHistory => 'Transfer history';

  @override
  String get transferSendAction => 'Send';

  @override
  String get transferActiveFilters => 'Active filters: ';

  @override
  String get transferClearAll => 'Clear all';

  @override
  String get transferSendMoney2 => 'Send money';

  @override
  String get transferChoosePeriod => 'Choose a period';

  @override
  String get transferApplyFilters => 'Apply filters';

  @override
  String get transferTitle => 'Transfers';

  @override
  String get transferRecipientsTooltip => 'Recipients';

  @override
  String get transferHistoryTooltip => 'History';

  @override
  String get transferSendMoneyDescription =>
      'Transfer money to Niger in a few clicks';

  @override
  String get transferRecentTransactions => 'Recent transactions';

  @override
  String get transferNoTransactions => 'No transactions';

  @override
  String get transferTransactionsWillAppear =>
      'Your transfers will appear here';

  @override
  String get transferSend => 'Send';

  @override
  String get personalInfo => 'Personal information';

  @override
  String get recipientTypeTitle => 'Receiving method';

  @override
  String get paymentDetailsTitle => 'Payment details';

  @override
  String get locationTitle => 'Location';

  @override
  String mobileTransferInfo(String service) {
    return 'The transfer will be made via $service to the recipient\'s phone number.';
  }

  @override
  String get cashPickupInfo =>
      'The recipient can withdraw the money at a NITA service point with an ID.';

  @override
  String get addRecipientButton => 'Add recipient';

  @override
  String get recipientModified => 'Recipient modified successfully';

  @override
  String get recipientAdded => 'Recipient added successfully';

  @override
  String get supportEmailTitle => 'Email';

  @override
  String get supportLiveChat => 'Live chat';

  @override
  String get supportAvailable247 => 'Available 24/7';

  @override
  String get supportChatUnavailable => 'Chat unavailable at the moment';

  @override
  String get supportPhone => 'Phone';

  @override
  String get imagePickerCamera => 'Camera';

  @override
  String get imagePickerGallery => 'Gallery';

  @override
  String get notificationEnableDescription =>
      'Receive alerts when you have new messages, incoming calls or important activities.\n\nYou can change this setting at any time.';

  @override
  String get notificationDisabledDescription =>
      'Notifications are disabled. You won\'t receive alerts for new messages and calls.\n\nTo enable them, go to the app settings.';

  @override
  String get notificationBlockedDescription =>
      'You have blocked notifications for this app.\n\nTo receive notifications for new messages and calls, you need to enable them manually in system settings.';

  @override
  String get installFromPlayStore =>
      'To access this feature, please install the app from Google Play Store.';

  @override
  String get accessRestricted => 'Access restricted';

  @override
  String securityCheckFailed(String error) {
    return 'Unable to verify security: $error';
  }

  @override
  String get deviceBasicSecurityFailed =>
      'This device does not meet basic security requirements.';

  @override
  String get deviceSecurityFailed =>
      'This device does not meet security requirements.';

  @override
  String get playStoreRequired =>
      'This feature requires installation from Google Play Store.';

  @override
  String get highSecurityFailed =>
      'This device does not meet high security requirements.';

  @override
  String get signedInElsewhere => 'Signed in elsewhere';

  @override
  String get signedInElsewhereDescription =>
      'Your account was signed in on another device. You have been signed out of this device for security.';

  @override
  String get cameraPermissionRestricted =>
      'Camera access is restricted on this device.';

  @override
  String get cameraPermissionRequired =>
      'Camera access is required to take photos.';

  @override
  String get photoLibraryPermissionDenied =>
      'Photo library access was denied. Please enable it in app settings.';

  @override
  String get photoLibraryPermissionRestricted =>
      'Photo library access is restricted on this device.';

  @override
  String get photoLibraryPermissionRequired =>
      'Photo library access is required to select images.';

  @override
  String get selectAnElement => 'Select an element';

  @override
  String get cameraPermissionRequiredTitle => 'Camera permission required';

  @override
  String get specifyYourProfession => 'Specify your profession';

  @override
  String get orEnterYourCountry => 'Or enter your country';

  @override
  String get profileConfiguration => 'Profile configuration';

  @override
  String get locationPermissionDeniedForever =>
      'Location permission permanently denied';

  @override
  String get travelModeEnabled => 'Travel Mode enabled (Background location)';

  @override
  String get travelModeDisabled => 'Travel Mode disabled';

  @override
  String get cannotChatWithDeletedUser => 'Cannot chat with a deleted user';

  @override
  String get qrCodeScannedSuccess => 'QR code scanned successfully';

  @override
  String get whatsApp => 'WhatsApp';

  @override
  String get facebook => 'Facebook';

  @override
  String get sendAMessage => 'Send a message';

  @override
  String get removeFromFriends => 'Remove from friends';

  @override
  String get requestDeclinedMessage => 'Request declined';

  @override
  String get decline => 'Decline';

  @override
  String get requestSentSuccess => 'Request sent successfully';

  @override
  String get removeAdmin => 'Remove Admin';

  @override
  String get membershipRequests => 'Membership requests';

  @override
  String errorPrefix(String error) {
    return 'Error: $error';
  }

  @override
  String get favorites => 'Favorites';

  @override
  String photosCount(int count) {
    return 'Photos ($count)';
  }

  @override
  String filesCount(int count) {
    return 'Files ($count)';
  }

  @override
  String get videoPlaybackError => 'Video playback error';

  @override
  String get videoSavedToGallery => 'Video saved to gallery';

  @override
  String get info => 'Info';

  @override
  String imageSelectionError(String error) {
    return 'Error selecting image: $error';
  }

  @override
  String get cannotDeleteMessageAfter1h => 'Cannot delete message after 1 hour';

  @override
  String get pdf => 'PDF';

  @override
  String get doc => 'DOC';

  @override
  String get joinCall => 'Join';

  @override
  String get groupCall => 'Group call';

  @override
  String get cannotGetPosition => 'Cannot get position';

  @override
  String get searchPlace => 'Search a place...';

  @override
  String get modifyGroup => 'Edit group';

  @override
  String get themeMode => 'Mode';

  @override
  String get themeAppearance => 'Appearance';

  @override
  String get themeGreenDefault => 'Green (Default)';

  @override
  String get themeOrangeClassic => 'Orange (Classic)';

  @override
  String get scanProfile => 'Scan a profile';

  @override
  String get placeQrCodeInFrame => 'Place the QR code in the frame to scan';

  @override
  String get flashActive => 'Flash active';

  @override
  String get flash => 'Flash';

  @override
  String cameraErrorCode(String errorCode) {
    return 'Camera error: $errorCode';
  }

  @override
  String get invalidQrCode => 'Invalid QR code';

  @override
  String get linkExpiredOrNotFound => 'Link expired or not found';

  @override
  String get connectionError => 'Connection error';

  @override
  String get invalidQrCodeFormat => 'Invalid or unrecognized QR code format';

  @override
  String get shareMyProfileTitle => 'Share my profile';

  @override
  String get generatingLink => 'Generating link...';

  @override
  String get unableToGenerateShareLink => 'Unable to generate share link';

  @override
  String get oops => 'Oops!';

  @override
  String get errorOccurred => 'An error occurred';

  @override
  String get scanToFindMe => 'Scan to find me';

  @override
  String get scanQrCode => 'Scan a QR code';

  @override
  String discoverMyProfile(String url) {
    return 'Discover my profile on Diaspo Niger: $url';
  }

  @override
  String get myProfileOnDiaspoNiger => 'My Diaspo Niger profile';

  @override
  String atTime(String time) {
    return 'at $time';
  }

  @override
  String get saveVideoError => 'Error saving video';

  @override
  String get fileNotAvailable => 'File not available';

  @override
  String get fileCouldNotLoad => 'The file could not be loaded';

  @override
  String get host => 'Host';

  @override
  String get live => 'Live';

  @override
  String get waiting => 'Waiting';

  @override
  String get endToEndEncrypted => 'End-to-End Encrypted';

  @override
  String get noPhotos => 'No photos';

  @override
  String get noFiles => 'No files';

  @override
  String get loadingVideo => 'Loading video...';

  @override
  String get playbackError => 'Playback error';

  @override
  String get deleteMessage => 'Delete message';

  @override
  String get selectAction => 'Select';

  @override
  String sendToConversations(int count) {
    return 'Send to $count conversation(s)';
  }

  @override
  String get cannotResendMessage =>
      'Cannot resend this type of message. Please resend manually.';

  @override
  String get searchError => 'Search error';

  @override
  String applyError(String error) {
    return 'Error applying: $error';
  }

  @override
  String get deleteForMeSubtitle =>
      'The message will be deleted only from your view';

  @override
  String get deleteForEveryoneSubtitle =>
      'The message will be deleted for all participants';

  @override
  String get audioNotAvailable => 'Audio not available';

  @override
  String get invalidAudioUrl => 'Invalid audio URL';

  @override
  String get audioPlaybackError => 'Playback error';

  @override
  String get audioNotFound => 'Audio not found';

  @override
  String get insufficientPermissionMessage =>
      'You do not have permission to access this page.';

  @override
  String get shareALocation => 'Share a location';

  @override
  String get searchLocation => 'Search a location...';

  @override
  String get selectedPosition => 'Selected position';

  @override
  String get gettingLocation => 'Getting location...';

  @override
  String get myCurrentLocation => 'My current location';

  @override
  String get orSelectOnMap => 'or select on map';

  @override
  String get loadingMap => 'Loading map...';

  @override
  String get sendThisLocation => 'Send this location';

  @override
  String get thisGroupWasDeleted => 'This group was deleted';

  @override
  String get thisUserWasDeleted => 'This user was deleted';

  @override
  String get youBlockedThisUser => 'You have blocked this user';

  @override
  String get messageResendFailed => 'Message resend failed';

  @override
  String get unableToStartCall => 'Unable to start call';

  @override
  String get encrypted => 'Encrypted';

  @override
  String get typeYourMessageBelow => 'Type your message below';

  @override
  String get sendFirstMessageGroup =>
      'Be the first to send a message in this group!';

  @override
  String get accept => 'Accept';

  @override
  String confirmRemoveFriend(String name) {
    return 'Do you really want to remove $name from your friends?';
  }

  @override
  String get groupCreatedSuccess => 'Group created successfully';

  @override
  String get groupUpdatedSuccess => 'Group updated successfully';

  @override
  String get groupUpdateError => 'Error updating group';

  @override
  String get addPhoto => 'Add photo';

  @override
  String get groupNamePlaceholder => 'E.g.: Niger Entrepreneurs';

  @override
  String get describeYourGroup => 'Describe your group...';

  @override
  String get descriptionMinLength =>
      'The description must contain at least 10 characters';

  @override
  String get selectCountry => 'Select a country';

  @override
  String get hostCountryHelp =>
      'The country where the group community is located';

  @override
  String get selectRegion => 'Select a region';

  @override
  String get originRegionHelp => 'To group members by region of origin';

  @override
  String get detailedLocation => 'Detailed location (optional)';

  @override
  String get tagsHint => 'Separate tags with commas';

  @override
  String get membersNeedApproval => 'Members need approval';

  @override
  String get createTheGroup => 'Create the group';

  @override
  String get sendFileTitle => 'Send a file';

  @override
  String get cameraSection => 'Camera';

  @override
  String get locationSection => 'Location';

  @override
  String get originAtNiger => 'Origin in Niger';

  @override
  String get next => 'Next';

  @override
  String get finish => 'Finish';

  @override
  String get connectionErrorRetry => 'Connection error. Please try again.';

  @override
  String errorGeneric(String error) {
    return 'Error: $error';
  }

  @override
  String blockUserConfirmMessage(String name) {
    return 'Do you really want to block $name? You will no longer receive messages from them.';
  }

  @override
  String get blockingError => 'Error while blocking';

  @override
  String get infoLabel => 'Info';

  @override
  String get viewCart => 'View';

  @override
  String get selectImages => 'Select images';

  @override
  String get selectPhotos => 'Select photos';

  @override
  String addPhotosCount(int count) {
    return 'Add photos ($count/10)';
  }

  @override
  String photosLimitReached(int count) {
    return 'Limit of $count photos reached';
  }

  @override
  String selectionError(String error) {
    return 'Error during selection: $error';
  }

  @override
  String get addAtLeastOnePhoto => 'Please add at least one photo';

  @override
  String get shareRecap => 'Share recap';

  @override
  String get okButton => 'OK';

  @override
  String get profilePhotoTitle => 'Profile photo';

  @override
  String get profilePhotoOptional => 'Optional';

  @override
  String get yourLocation => 'Your location';

  @override
  String get locationConnectHelp =>
      'This helps us connect you with members near you.';

  @override
  String get interestsTitle => 'Your interests';

  @override
  String get interestsHelp =>
      'Select your areas of interest to personalize your experience.';

  @override
  String get themeAppTitle => 'App theme';

  @override
  String get themeCustomizeHelp =>
      'Customize the app appearance according to your preferences.';

  @override
  String get displayMode => 'Display mode';

  @override
  String get lightMode => 'Light';

  @override
  String get lightModeSubtitle => 'Light theme';

  @override
  String get darkMode => 'Dark';

  @override
  String get darkModeSubtitle => 'Dark theme';

  @override
  String get autoMode => 'Automatic';

  @override
  String get autoModeSubtitle => 'Follows system settings';

  @override
  String get themeColorTitle => 'Theme color';

  @override
  String get greenColor => 'Green';

  @override
  String get orangeColor => 'Orange';

  @override
  String get takePhotoTitle => 'Take a photo';

  @override
  String get takePhotoSubtitle => 'Use the camera';

  @override
  String get galleryTitle => 'Choose from gallery';

  @override
  String get gallerySubtitle => 'Select an existing image';

  @override
  String get deletePhotoTitle => 'Delete photo';

  @override
  String get deletePhotoSubtitle => 'Use default initials';

  @override
  String get adminHistoryAudit => 'Audit History';

  @override
  String get adminGoBack => 'Go back';

  @override
  String get adminAll => 'All';

  @override
  String get adminPending => 'Pending';

  @override
  String get adminBoosted => 'Boosted';

  @override
  String get adminConfirmDelete => 'Confirm deletion';

  @override
  String get adminRevoke => 'Revoke';

  @override
  String get adminTaxFees => 'Fees';

  @override
  String get adminTaxBoosts => 'Boosts';

  @override
  String get adminTaxes => 'Taxes';

  @override
  String get adminMedias => 'Media';

  @override
  String get adminSystem => 'System';

  @override
  String get adminAudio => 'Audio';

  @override
  String get adminFeeMinimum => 'Minimum fee (XOF)';

  @override
  String get adminFeeMaximum => 'Maximum fee (XOF)';

  @override
  String get adminCommissionMin => 'Commission min (XOF)';

  @override
  String get adminCommissionMax => 'Commission max (XOF)';

  @override
  String get adminVatRateUpdated => 'VAT rate updated';

  @override
  String get adminBaseShareUrl => 'Base share URL';

  @override
  String get adminAudioUpdated => 'Audio settings updated';

  @override
  String get adminClear => 'Clear';

  @override
  String get adminAboutToSend => 'You are about to send a notification to:';

  @override
  String get adminLoginWithGoogle => 'Sign in with Google';

  @override
  String get adminPasswordLabel => 'Password';

  @override
  String get adminLoginButton => 'Login';

  @override
  String adminProductsCount(int count) {
    return 'Products ($count)';
  }

  @override
  String adminOrdersCount(int count) {
    return 'Orders ($count)';
  }

  @override
  String adminDisputesCount(int count) {
    return 'Disputes ($count)';
  }

  @override
  String get adminDelete => 'Delete';

  @override
  String adminGroupsCount(int count) {
    return 'Groups ($count)';
  }

  @override
  String get adminSearchUser => 'Search for a user...';

  @override
  String get adminLoading => 'Loading...';

  @override
  String get adminNoUsersFound => 'No users found';

  @override
  String adminActivityOf(String name) {
    return 'Activity of $name';
  }

  @override
  String get adminSearchReports => 'Search by name, reason, ID...';

  @override
  String adminViewType(String type) {
    return 'View the $type';
  }

  @override
  String get adminRejectionHint =>
      'Ex: Report unfounded, content compliant with rules...';

  @override
  String get adminResolutionHint => 'Ex: Warning sent, content modified...';

  @override
  String get adminDeleteContentTitle => 'Delete content';

  @override
  String get adminCreateEmbassyTitle => 'Create an embassy';

  @override
  String get adminWarnHost => 'Warn host';

  @override
  String adminGoalHint(String min, String max) {
    return 'Min: $min XOF - Max: $max XOF';
  }

  @override
  String get interestCulture => 'Culture';

  @override
  String get interestSport => 'Sport';

  @override
  String get interestBusiness => 'Business';

  @override
  String get interestEducation => 'Education';

  @override
  String get interestTechnology => 'Technology';

  @override
  String get interestArts => 'Arts';

  @override
  String get interestHealth => 'Health';

  @override
  String get interestPolitics => 'Politics';

  @override
  String get noBusinessFound => 'No business found';

  @override
  String get beFirstToAddBusiness => 'Be the first to add your business!';

  @override
  String get filterByLocation => 'Filter by location';

  @override
  String get searchCountryLabel => 'Search for a country';

  @override
  String get countryPlaceholder => 'Country';

  @override
  String get cityPlaceholder => 'City';

  @override
  String get cityHintExample => 'Ex: Paris, Niamey, New York...';

  @override
  String get verifiedBadge => 'Verified';

  @override
  String get premiumBadge => 'Premium';

  @override
  String reviewsCountLabel(String rating, int count) {
    return '$rating ($count reviews)';
  }

  @override
  String get contactSectionTitle => 'Contact';

  @override
  String get servicesSectionTitle => 'Services';

  @override
  String get viewsStatLabel => 'Views';

  @override
  String get reviewsStatLabel => 'Reviews';

  @override
  String get openingHoursTitle => 'Opening hours';

  @override
  String get dayMondayLabel => 'Monday';

  @override
  String get dayTuesdayLabel => 'Tuesday';

  @override
  String get dayWednesdayLabel => 'Wednesday';

  @override
  String get dayThursdayLabel => 'Thursday';

  @override
  String get dayFridayLabel => 'Friday';

  @override
  String get daySaturdayLabel => 'Saturday';

  @override
  String get daySundayLabel => 'Sunday';

  @override
  String get closedStatus => 'Closed';

  @override
  String get currentOffersTitle => 'Current offers';

  @override
  String get noCurrentOffersMessage => 'No current offers';

  @override
  String validUntilLabel(String date) {
    return 'Valid until $date';
  }

  @override
  String get newsSectionTitle => 'News';

  @override
  String get addActionButton => 'Add';

  @override
  String get noNewsMessage => 'No news';

  @override
  String get newPostDialogTitle => 'New post';

  @override
  String get typeFieldLabel => 'Type';

  @override
  String get titleFieldPost => 'Title';

  @override
  String get titleHintPost => 'Ex: New collection available';

  @override
  String get contentFieldPost => 'Content';

  @override
  String get contentHintDescribe => 'Describe your news...';

  @override
  String get publishAction => 'Publish';

  @override
  String get deleteDialogTitle => 'Delete';

  @override
  String get confirmDeletePostMessage =>
      'Do you really want to delete this post?';

  @override
  String get customerReviewsTitle => 'Customer reviews';

  @override
  String get viewAllAction => 'View all';

  @override
  String get noReviewsYetMessage => 'No reviews yet';

  @override
  String get writeFirstReviewAction => 'Write the first review';

  @override
  String get writeReviewAction => 'Write a review';

  @override
  String seeOtherReviewsLabel(int count) {
    return 'See $count other reviews';
  }

  @override
  String get loginRequiredForReview =>
      'You must be logged in to leave a review';

  @override
  String get editAction => 'Edit';

  @override
  String get boostAction => 'Boost';

  @override
  String get alreadyLeftReviewMessage => 'You have already left a review';

  @override
  String get reviewDeletedMessage => 'Review deleted';

  @override
  String get reportReviewTitle => 'Report this review';

  @override
  String get reportReasonField => 'Reason for report';

  @override
  String get reportReasonHintText => 'Why are you reporting this review?';

  @override
  String get reviewReportedMessage => 'Review reported';

  @override
  String get reportErrorOccurred => 'Error while reporting';

  @override
  String get deleteReviewDialogTitle => 'Delete review';

  @override
  String get confirmDeleteReviewMessage =>
      'Do you really want to delete this review? This action is irreversible.';

  @override
  String get reviewsScreenLabel => 'Reviews';

  @override
  String get beFirstToShareExperience =>
      'Be the first to share your experience!';

  @override
  String get loadingErrorMessage => 'Loading error';

  @override
  String get retryButtonLabel => 'Retry';

  @override
  String nReviewsLabel(int count) {
    return '$count reviews';
  }

  @override
  String get allCountriesOption => 'All countries';

  @override
  String get chooseCountryDialogTitle => 'Choose a country';

  @override
  String get noProductAvailableMessage => 'No product available';

  @override
  String get beFirstToSellMessage => 'Be the first to sell!';

  @override
  String noSearchResultsForQuery(String query) {
    return 'No results for \"$query\"';
  }

  @override
  String get myOrdersScreenTitle => 'My orders';

  @override
  String get myPurchasesTabLabel => 'My purchases';

  @override
  String get mySalesTabLabel => 'My sales';

  @override
  String get noOrdersYetMessage => 'You haven\'t placed any orders yet';

  @override
  String get noOrdersReceivedMessage => 'You haven\'t received any orders yet';

  @override
  String sellerWithNameLabel(String name) {
    return 'Seller: $name';
  }

  @override
  String buyerWithNameLabel(String name) {
    return 'Buyer: $name';
  }

  @override
  String articlesCountLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 's',
      one: '',
    );
    return '$count item$_temp0';
  }

  @override
  String quantityShortLabel(int qty) {
    return 'Qty: $qty';
  }

  @override
  String payAmountLabel(String amount) {
    return 'Pay $amount';
  }

  @override
  String get confirmReceiptAction => 'Confirm receipt';

  @override
  String get markAsShippedAction => 'Mark as shipped';

  @override
  String get trackingNumberDialogTitle => 'Tracking number';

  @override
  String get trackingNumberHintOptional => 'Enter tracking number (optional)';

  @override
  String get confirmAction => 'Confirm';

  @override
  String get paymentSuccessfulMessage => 'Payment successful!';

  @override
  String get orderUpdateErrorOccurred => 'Error updating order';

  @override
  String paymentErrorWithDetails(String error) {
    return 'Payment error: $error';
  }

  @override
  String get deliveryConfirmedSuccess => 'Delivery confirmed';

  @override
  String availableQuantityInfo(int qty) {
    return '$qty available';
  }

  @override
  String get descriptionSectionTitle => 'Description';

  @override
  String get sellerSectionTitle => 'Seller';

  @override
  String get loadingLabel => 'Loading...';

  @override
  String get viewProfileAction => 'View profile';

  @override
  String get contactSellerAction => 'Contact seller';

  @override
  String get connectingLabel => 'Connecting...';

  @override
  String get conversationCreationErrorMessage => 'Error creating conversation';

  @override
  String get interestedInProductText =>
      'Hello, I am interested in this product:';

  @override
  String get addToCartAction => 'Add to cart';

  @override
  String get addedToCartSuccess => 'Added to cart';

  @override
  String get viewAction => 'View';

  @override
  String get deleteProductDialogTitle => 'Delete product';

  @override
  String get confirmDeleteProductMessage =>
      'Are you sure you want to delete this product?';

  @override
  String get sellProductScreenTitle => 'Sell a product';

  @override
  String get editProductScreenTitle => 'Edit product';

  @override
  String get addImageAction => 'Add';

  @override
  String get photosSectionTitle => 'Photos';

  @override
  String get titleFieldProduct => 'Title';

  @override
  String get titleHintProduct => 'Ex: iPhone 13 Pro Max';

  @override
  String get titleRequiredError => 'Please enter a title';

  @override
  String get descriptionFieldProduct => 'Description';

  @override
  String get descriptionHintProduct => 'Describe your product...';

  @override
  String get priceFieldProduct => 'Price';

  @override
  String get priceRequiredError => 'Please enter a price';

  @override
  String get priceInvalidError => 'Invalid price';

  @override
  String get quantityFieldProduct => 'Quantity';

  @override
  String get quantityRequiredError => 'Required';

  @override
  String get quantityInvalidError => 'Invalid';

  @override
  String get currencyFieldProduct => 'Currency';

  @override
  String get categoryFieldProduct => 'Category';

  @override
  String get conditionFieldProduct => 'Condition';

  @override
  String get countryFieldProduct => 'Country';

  @override
  String get countryRequiredError => 'Please select a country';

  @override
  String get cityAddressOptionalField => 'City/Address (optional)';

  @override
  String get cityAddressHintProduct => 'Ex: Niamey';

  @override
  String get taxSettingsSectionTitle => 'Tax settings';

  @override
  String get taxExemptCategoryMessage =>
      'This category is tax-exempt by default';

  @override
  String defaultTaxForCategoryInfo(String rate) {
    return 'Default tax for this category: $rate%';
  }

  @override
  String get customRateField => 'Custom rate (%)';

  @override
  String get customRateHintExample => 'Ex: 15';

  @override
  String get priceTtcToggle => 'Price includes tax';

  @override
  String get priceTtcEnabledInfo => 'The displayed price already includes tax';

  @override
  String get priceTtcDisabledInfo => 'Tax will be added to the displayed price';

  @override
  String get previewSectionTitle => 'Preview';

  @override
  String get subtotalLine => 'Subtotal';

  @override
  String taxRateLine(String rate) {
    return 'Tax ($rate%)';
  }

  @override
  String get totalLine => 'Total';

  @override
  String get publishProductAction => 'Publish';

  @override
  String get saveProductAction => 'Save';

  @override
  String get addImageRequiredError => 'Please add at least one image';

  @override
  String get userNotConnectedMessage => 'User not connected';

  @override
  String get productModifiedMessage => 'Product modified';

  @override
  String get productPublishedMessage => 'Product published';

  @override
  String get orderAction => 'Order';

  @override
  String get convertedNote => '(converted)';

  @override
  String get securePurchaseDialogTitle => 'Secure purchase';

  @override
  String get purchaseSecurityNote =>
      'Purchases on the marketplace require the app to be installed from Google Play Store.';

  @override
  String get publishedDateLabel => 'published';

  @override
  String get unknownUserLabel => 'Unknown';

  @override
  String get allCategoryFilter => 'All';

  @override
  String get replyAction => 'Reply';

  @override
  String get readAction => 'Read';

  @override
  String get taxAutomaticDesc => 'Tax calculated based on product category';

  @override
  String get taxExemptDesc => 'No tax on this product';

  @override
  String get taxStandardDesc => 'Standard VAT rate';

  @override
  String get taxReducedDesc => 'Reduced rate for essential products';

  @override
  String get taxCustomDesc => 'Define a custom rate';

  @override
  String get adminSearchByAdminOrAction => 'Search by admin or action...';

  @override
  String get adminTransactions => 'Transactions';

  @override
  String adminAllCount(int count) {
    return 'All ($count)';
  }

  @override
  String adminPendingCount(int count) {
    return '$count pending';
  }

  @override
  String adminBoostedCount(int count) {
    return 'Boosted ($count)';
  }

  @override
  String adminGroupType(String type) {
    return 'Group • $type';
  }

  @override
  String get adminEmailAddress => 'Email address';

  @override
  String get adminRoomConnectionError => 'Error connecting to room';

  @override
  String get adminSend => 'Send';

  @override
  String get adminHistory => 'History';

  @override
  String get adminTitle => 'Title';

  @override
  String get adminMessage => 'Message';

  @override
  String get adminRejectHint =>
      'Ex: Unfounded report, content complies with rules...';

  @override
  String get adminProcessHint => 'Ex: Warning sent, content modified...';

  @override
  String get adminChangeRoleTitle => 'Change role';

  @override
  String get adminRevokeAction => 'Revoke';

  @override
  String get adminFees => 'Fees';

  @override
  String get adminBoosts => 'Boosts';

  @override
  String get adminMedia => 'Media';

  @override
  String get adminMaxImagesPerUpload => 'Max images/upload';

  @override
  String get adminMaxCharsPerMessage => 'Max chars per message';

  @override
  String get adminCustomAmountsHint => 'Ex: 1, 2, 5, 10, 20';

  @override
  String get adminNoActivityRecorded => 'No activity recorded';

  @override
  String audioRoomCollectionHelper(int min, int max) {
    return 'Min: $min XOF - Max: $max XOF';
  }

  @override
  String get audioRoomStoriesLabel => 'Stories';

  @override
  String get audioRoomProverbsLabel => 'Proverbs';

  @override
  String get audioRoomHistoryLabel => 'History';

  @override
  String get audioRoomCeremoniesLabel => 'Ceremonies';

  @override
  String get audioRoomLanguageLabelNav => 'Language';

  @override
  String get audioRoomCraftLabel => 'Craft';

  @override
  String get audioRoomRecipesLabel => 'Recipes';

  @override
  String get audioRoomMedicineLabel => 'Medicine';

  @override
  String get businessBoostActivated => 'Boost activated successfully!';

  @override
  String get businessBoostError => 'Error purchasing boost';

  @override
  String get businessBoostTitle => 'Boost your business';

  @override
  String get businessTypeLabel => 'Type:';

  @override
  String get businessDurationLabel => 'Duration:';

  @override
  String get businessTotalLabel => 'Total:';

  @override
  String get businessPhotosLabel => 'Photos';

  @override
  String get businessCategoryLabel => 'Category';

  @override
  String get businessNameRequired => 'Business name *';

  @override
  String get businessDescriptionRequired => 'Description *';

  @override
  String get businessContactLabel => 'Contact';

  @override
  String get businessLocationLabel => 'Location';

  @override
  String get businessCountryHint => 'Type country name';

  @override
  String get businessServicesOffered => 'Services offered';

  @override
  String get businessAddService => 'Add a service';

  @override
  String get businessCreateAction => 'Create the business';

  @override
  String get businessEditReview => 'Edit';

  @override
  String get businessReportReview => 'Report';

  @override
  String get businessGiveRating => 'Please give a rating';

  @override
  String get businessWriteReview => 'Please write a review';

  @override
  String get businessSubmissionError => 'Error during submission';

  @override
  String get businessTitleOptional => 'Title (optional)';

  @override
  String get businessTitleHint => 'Ex: Excellent service';

  @override
  String get businessYourReview => 'Your review';

  @override
  String get businessShareExperience => 'Share your experience...';

  @override
  String get businessAddReview => 'Add';

  @override
  String get callPermissionRequired => 'Permission required';

  @override
  String get callSettings => 'Settings';

  @override
  String get callEnd => 'End';

  @override
  String eventImageSelectionErrorMsg(String error) {
    return 'Error selecting images: $error';
  }

  @override
  String get eventPosterLimitReached => 'Limit of 5 posters reached';

  @override
  String eventSelectionError(String error) {
    return 'Selection error: $error';
  }

  @override
  String get eventPhotoLimitReached => 'Limit of 10 photos reached';

  @override
  String get eventAddAtLeastOnePhoto => 'Please add at least one photo';

  @override
  String get eventRecapShareTooltip => 'Share recap';

  @override
  String eventPhotosAddCount(int count) {
    return 'Add photos ($count/10)';
  }

  @override
  String get groupRequestSentSuccess => 'Request sent successfully';

  @override
  String get groupPromoteAdminTitle => 'Promote to Admin';

  @override
  String get groupDemoteAdminTitle => 'Remove Admin';

  @override
  String get groupConfirmTitle => 'Confirm';

  @override
  String get groupMembershipRequestsTitle => 'Membership requests';

  @override
  String get groupApprovedRequest => 'Request approved';

  @override
  String get groupDeclinedRequest => 'Request declined';

  @override
  String get groupRejectAction => 'Reject';

  @override
  String get groupApproveAction => 'Approve';

  @override
  String get groupAllFilter => 'All';

  @override
  String mediaGalleryPhotos(int count) {
    return 'Photos ($count)';
  }

  @override
  String mediaGalleryFiles(int count) {
    return 'Files ($count)';
  }

  @override
  String get mediaCaptionHint => 'Add a caption...';

  @override
  String messageConversationError(String error) {
    return 'Error: $error';
  }

  @override
  String get messageInfoLabel => 'Info';

  @override
  String get notificationRemindLater => 'Remind me later';

  @override
  String get notificationIn1HourOption => 'In 1 hour';

  @override
  String get notificationScheduled => 'Reminder scheduled';

  @override
  String get notificationTomorrowOption => 'Tomorrow morning (9am)';

  @override
  String get podcastDisabledOption => 'Disabled';

  @override
  String get podcastEndOfEpisodeOption => 'End of episode';

  @override
  String get podcastSleepEndActivated => 'Stop at end of episode enabled';

  @override
  String get podcastSleepEnded => 'Sleep timer ended';

  @override
  String podcastTimerSet(int minutes) {
    return 'Timer: $minutes minutes';
  }

  @override
  String get podcastNotFoundError => 'Podcast not found';

  @override
  String get podcastAddEpisode => 'Add';

  @override
  String podcastErrorPrefix(String error) {
    return 'Error: $error';
  }

  @override
  String get podcastAddChapterTitle => 'Add a chapter';

  @override
  String get podcastChapterTitleLabel => 'Chapter title';

  @override
  String get podcastMinutesLabel => 'Minutes';

  @override
  String get podcastSecondsLabel => 'Seconds';

  @override
  String get podcastSelectAudio => 'Please select an audio file';

  @override
  String podcastEpisodeError(String error) {
    return 'Error: $error';
  }

  @override
  String get podcastEpisodeTitleRequired => 'Episode title *';

  @override
  String get podcastDescriptionNotes => 'Description / Notes';

  @override
  String get podcastSubscribersOnlyLabel => 'Reserved for paying subscribers';

  @override
  String get podcastDownloadedTooltip => 'Downloaded';

  @override
  String get podcastDownloadTooltip => 'Download';

  @override
  String get podcastDeleteDownloadTitle => 'Delete download';

  @override
  String get podcastDownloadDeleted => 'Download deleted';

  @override
  String get podcastSelectOrCreateNew => 'Select a podcast or create a new one';

  @override
  String get podcastRecordingSoon => 'Room recording will be available soon';

  @override
  String get podcastAudioMissing => 'Audio file not found';

  @override
  String get podcastPublishingError => 'Error during publication';

  @override
  String get podcastEpisodeTitleInput => 'Episode title';

  @override
  String get podcastEpisodeDescInput => 'Episode description (optional)';

  @override
  String get podcastPublishAction => 'Publish';

  @override
  String get podcastCreateAction => 'Create a podcast';

  @override
  String profileCodeSentTo(String phone) {
    return 'Code sent to $phone';
  }

  @override
  String get profileTravelModeTitle => 'Travel Mode';

  @override
  String get reportMyReportsTitle => 'My reports';

  @override
  String get reportDescribeProblem => 'Describe the problem...';

  @override
  String get reportSendAction => 'Send report';

  @override
  String get settingsRenameDeviceTitle => 'Rename device';

  @override
  String get settingsDeviceNameLabel => 'Device name';

  @override
  String get settingsRename => 'Rename';

  @override
  String get settingsRevokeDeviceTitle => 'Revoke device?';

  @override
  String get settingsRevokeConfirm => 'Revoke';

  @override
  String get settingsConnectedDevicesTitle => 'Connected devices';

  @override
  String get settingsDeleteBackupTitle => 'Delete backup?';

  @override
  String get settingsKeyBackupTitle => 'Key backup';

  @override
  String get settingsPassphrase => 'Passphrase';

  @override
  String get settingsRestoreKeysAction => 'Restore keys';

  @override
  String get settingsGenerateSecurePassphrase => 'Generate secure passphrase';

  @override
  String get settingsPassphraseMinChars => 'Minimum 8 characters';

  @override
  String get settingsConfirmPassphraseLabel => 'Confirm passphrase';

  @override
  String get settingsCreateBackupAction => 'Create backup';

  @override
  String get settingsTermsTitle => 'Terms of Service';

  @override
  String get settingsBugDescLabel => 'Bug description';

  @override
  String get settingsBugDescHint => 'Describe the issue you encountered...';

  @override
  String get settingsCurrencySearch => 'Search for a currency...';

  @override
  String get settingsOk => 'OK';

  @override
  String get transferAddRecipientTitle => 'Add a recipient';

  @override
  String transferErrorPrefix(String error) {
    return 'Error: $error';
  }

  @override
  String get transferNewAction => 'New';

  @override
  String get transferAddManuallyAction => 'Add manually';

  @override
  String get transferChooseRecipientTitle => 'Choose a recipient';

  @override
  String get transferAddRecipientHint => 'Add a recipient';

  @override
  String get transferSendMoneyAction => 'Send money';

  @override
  String get transferEditAction => 'Edit';

  @override
  String get transferDeleteTitle => 'Delete?';

  @override
  String transferDeleteMsg(String name) {
    return 'Delete $name?';
  }

  @override
  String get transferDetailsTitle => 'Transfer details';

  @override
  String get transferAmountSentLine => 'Amount sent';

  @override
  String get transferFeesLine => 'Fees';

  @override
  String get transferExchangeRateLine => 'Exchange rate';

  @override
  String get transferCopiedToClipboard => 'Copied to clipboard';

  @override
  String get transferRetryAction => 'Retry transfer';

  @override
  String get transferContactSupportAction => 'Contact support';

  @override
  String get transferStatusPending => 'Pending';

  @override
  String get transferStatusDebiting => 'Debiting';

  @override
  String get transferStatusProcessing => 'Processing';

  @override
  String get transferStatusSending => 'Sending';

  @override
  String get transferStatusCompleted => 'Completed';

  @override
  String get transferStatusFailed => 'Failed';

  @override
  String get transferStatusRefunding => 'Refunding';

  @override
  String get transferStatusRefunded => 'Refunded';

  @override
  String get transferStatusCancelled => 'Cancelled';

  @override
  String get transferStatusPendingDesc =>
      'Your transfer is awaiting processing.';

  @override
  String get transferStatusDebitingDesc =>
      'The debit is in progress on your account.';

  @override
  String get transferStatusProcessingDesc =>
      'Your transfer is being processed.';

  @override
  String get transferStatusSendingDesc =>
      'The money is being sent to the recipient.';

  @override
  String get transferStatusCompletedDesc =>
      'Your transfer was completed successfully!';

  @override
  String get transferStatusFailedDesc =>
      'The transfer failed. Please try again.';

  @override
  String get transferStatusRefundingDesc => 'The refund is being processed.';

  @override
  String get transferStatusRefundedDesc =>
      'The amount has been refunded to your account.';

  @override
  String get transferStatusCancelledDesc => 'This transfer has been cancelled.';

  @override
  String get transferEmailOption => 'Email';

  @override
  String get transferLiveChat => 'Live chat';

  @override
  String get transferAvailable247 => 'Available 24/7';

  @override
  String get transferChatUnavailable => 'Chat unavailable at the moment';

  @override
  String get transferPhoneOption => 'Phone';

  @override
  String get transferHistoryTitle => 'Transfer history';

  @override
  String get transferSendActionLabel => 'Send';

  @override
  String get transferActiveFiltersLabel => 'Active filters: ';

  @override
  String get transferClearAllAction => 'Clear all';

  @override
  String get transferChoosePeriodAction => 'Choose a period';

  @override
  String get transferApplyFiltersAction => 'Apply filters';

  @override
  String get widgetRetryAction => 'Retry';

  @override
  String get widgetCameraOption => 'Camera';

  @override
  String get widgetGalleryOption => 'Gallery';

  @override
  String get adminDashboardTitle => 'Dashboard';

  @override
  String get adminDashboardWelcome =>
      'Welcome to DiaspoNiger administration panel';

  @override
  String get adminGeneralStats => 'General Statistics';

  @override
  String get adminActiveSessions => 'Active Sessions';

  @override
  String get adminCommerceMarketplace => 'Commerce & Marketplace';

  @override
  String get adminProducts => 'Products';

  @override
  String get adminQuickActions => 'Quick Actions';

  @override
  String get adminNoLiveRooms => 'No live rooms';

  @override
  String get adminNoLiveRoomsDesc =>
      'There are currently no active audio rooms.';

  @override
  String get adminLiveAudioRooms => 'Live Audio Rooms';

  @override
  String get adminLiveAudioRoomsDesc => 'Monitor and moderate live audio rooms';

  @override
  String get adminEmbassyManagement => 'Embassy Management';

  @override
  String get adminEmbassyManagementDesc => 'Create and manage embassy accounts';

  @override
  String get adminLoadingData => 'Loading data...';

  @override
  String get adminErrorOccurred => 'An error occurred';

  @override
  String get adminActive => 'active';

  @override
  String get adminPaid => 'Paid';

  @override
  String get adminVideo => 'Video';

  @override
  String get adminHost => 'Host';

  @override
  String get adminModerationDialogContent =>
      'You will join this room in invisible mode (ghost mode). Participants will not be able to see you.\n\nYou will be able to:\n- Listen to conversations\n- Watch videos (if enabled)\n- Warn the host\n- Close the room if necessary';

  @override
  String get eventPostersOptional => 'Event posters (optional)';

  @override
  String get eventPostersLabel => 'Event posters';

  @override
  String get eventPostersUpTo5 => 'Add up to 5 posters for your event';

  @override
  String eventManagePosters(int count) {
    return 'Manage posters ($count/5)';
  }

  @override
  String get eventCurrentPosters => 'Current posters';

  @override
  String get eventNewPosters => 'New posters';

  @override
  String get eventAddImages => 'Add images';

  @override
  String eventAddPosterCount(int count) {
    return 'Add ($count/5)';
  }

  @override
  String get eventRecapTitle => 'Recap';

  @override
  String get eventCreateRecap => 'Create a recap';

  @override
  String get eventEditRecap => 'Edit recap';

  @override
  String get eventRecapInfo =>
      'Share the best moments of your event with photos and a description.';

  @override
  String get eventRecapPhotosLabel => 'Recap photos';

  @override
  String eventRecapUpTo10Photos(int count) {
    return 'Add up to 10 photos ($count/10)';
  }

  @override
  String get eventExistingPhotos => 'Existing photos';

  @override
  String get eventNewPhotos => 'New photos';

  @override
  String get eventRecapDescriptionHint => 'Tell us how the event went...';

  @override
  String get eventRecapDescriptionRequired => 'Please add a description';

  @override
  String get eventRecapDescriptionTooShort =>
      'Description must be at least 20 characters';

  @override
  String get eventRecapUpdateButton => 'Update';

  @override
  String get eventRecapCreateButton => 'Create recap';

  @override
  String get eventRecapUpdatedSuccess => 'Recap updated successfully';

  @override
  String get eventRecapCreatedSuccess => 'Recap created successfully';

  @override
  String eventRecapError(String error) {
    return 'Error: $error';
  }

  @override
  String get noConnection => 'No connection';

  @override
  String get weakConnection => 'Weak connection';

  @override
  String get unstableConnection => 'Unstable connection';

  @override
  String get goodConnection => 'Good connection';

  @override
  String get noInternetConnection => 'No internet connection';

  @override
  String get poorConnectionLimitedFunctions =>
      'Weak connection - some features may be limited';

  @override
  String get chooseAnImage => 'Choose an image';

  @override
  String get chooseImages => 'Choose images';

  @override
  String get permissionDeniedGeneric => 'Permission denied';

  @override
  String maximumImages(int count) {
    return 'Maximum $count images';
  }

  @override
  String get callPermissionMicrophone => 'microphone';

  @override
  String get callPermissionCamera => 'camera';

  @override
  String callPermissionDenied(String permissions) {
    return '$permissions access is required to make calls. Please allow it in settings.';
  }

  @override
  String get callEndConfirmMessage => 'Do you really want to end this call?';

  @override
  String get callEndButton => 'End';

  @override
  String get callDeclinedStatus => 'Call declined';

  @override
  String get callNoAnswer => 'No answer';

  @override
  String get callEndedStatus => 'Call ended';

  @override
  String get callCameraInitializing => 'Initializing camera...';

  @override
  String get callCameraDisabled => 'Camera disabled';

  @override
  String get callReconnectingStatus => 'Reconnecting...';

  @override
  String get callPleaseWait => 'Please wait';

  @override
  String get callReenableButton => 'Re-enable';

  @override
  String get callConnectionQuality => 'Connection quality';

  @override
  String get callLatency => 'Latency';

  @override
  String get callPacketLoss => 'Packet loss';

  @override
  String get callJitter => 'Jitter';

  @override
  String get callBandwidth => 'Bandwidth';

  @override
  String get callAudioCodec => 'Audio codec';

  @override
  String get callVideoCodec => 'Video codec';

  @override
  String get callVideoLabel => 'Video';

  @override
  String get callCloseButton => 'Close';

  @override
  String get callPermissionAnd => 'and';

  @override
  String get businessBoostVisibilityTitle => 'Increase your visibility';

  @override
  String get businessBoostVisibilityDesc =>
      'Appear first in search results and attract more customers.';

  @override
  String get businessBoostTypeLabel => 'Boost type';

  @override
  String get businessBoostRecommended => 'Recommended';

  @override
  String get marketplaceTaxSettings => 'Tax settings';

  @override
  String get marketplacePreview => 'Preview';

  @override
  String get marketplaceChooseCountry => 'Choose a country';

  @override
  String get marketplacePhotos => 'Photos';

  @override
  String get marketplaceAddPhoto => 'Add';

  @override
  String get marketplaceTitleRequired => 'Enter a title';

  @override
  String get marketplaceDescriptionRequired => 'Enter a description';

  @override
  String get marketplaceSelectCountry => 'Select a country';

  @override
  String get marketplaceTaxIncluded =>
      'The displayed price already includes tax';

  @override
  String get marketplaceTaxAdded => 'Tax will be added to the displayed price';

  @override
  String marketplaceErrorWithMessage(String error) {
    return 'Error: $error';
  }

  @override
  String marketplaceNoResultFor(String query) {
    return 'No results for \"$query\"';
  }

  @override
  String get marketplaceNoProductAvailable => 'No product available';

  @override
  String get marketplaceBeFirstToSell => 'Be the first to sell!';

  @override
  String get marketplaceTodayLabel => 'Today';

  @override
  String get marketplaceYesterdayLabel => 'Yesterday';

  @override
  String marketplaceDaysAgoLabel(int days) {
    return '$days days ago';
  }

  @override
  String marketplaceWeeksAgoLabel(int weeks) {
    return '$weeks week(s) ago';
  }

  @override
  String marketplaceMonthsAgoLabel(int months) {
    return '$months month(s) ago';
  }

  @override
  String get marketplaceUserNotConnected => 'User not connected';

  @override
  String get marketplaceAllCountries => 'All countries';

  @override
  String get mapSimpleTestTitle => 'Simple Map Test';

  @override
  String get businessBoostStartingFrom => 'Starting from';

  @override
  String get businessBoostDurationLabel => 'Duration';

  @override
  String get businessBoostSavings25 => '~25% saved';

  @override
  String get businessBoostSavings42 => '~42% saved';

  @override
  String get businessBoostBuyFor => 'Buy for';

  @override
  String get businessBoostNote =>
      'Note: The boost will be active immediately after payment.';

  @override
  String get businessNameRequiredError => 'Name is required';

  @override
  String get businessDescriptionRequiredError => 'Description is required';

  @override
  String get businessSelectCountry => 'Select a country';

  @override
  String get businessSearchCountryPlaceholder => 'Search for a country';

  @override
  String get businessTypeCountryName => 'Type the country name';

  @override
  String get reviewHelpful => 'Helpful';

  @override
  String reviewHelpfulCount(int count) {
    return 'Helpful ($count)';
  }

  @override
  String get reviewPleaseWriteReview => 'Please write a review';

  @override
  String get reviewModifiedSuccess => 'Review modified successfully';

  @override
  String get reviewPublishedSuccess => 'Review published successfully';

  @override
  String get reviewWriteTitle => 'Write a review';

  @override
  String get reviewModifyTitle => 'Modify your review';

  @override
  String get reviewYourRating => 'Your rating';

  @override
  String get reviewPublish => 'Publish';

  @override
  String reviewPhotosCount(int current, int max) {
    return 'Photos ($current/$max)';
  }

  @override
  String get activateCamera => 'Activate';

  @override
  String get deactivateCamera => 'Deactivate';

  @override
  String get minAmountIs => 'The minimum amount is';

  @override
  String get maxAmountIs => 'The maximum amount is';

  @override
  String get heritageLanguageType => 'Language';

  @override
  String get groupNameExample => 'E.g.: Niger Entrepreneurs';

  @override
  String get groupNameIsRequired => 'The name is required';

  @override
  String get groupNameMinLength =>
      'The name must contain at least 3 characters';

  @override
  String get descriptionIsRequired => 'The description is required';

  @override
  String get hostCountryHint =>
      'The country where the group community is located';

  @override
  String get none => 'None';

  @override
  String get regionOriginHint => 'To group members by region of origin';

  @override
  String get detailedLocationExample => 'E.g.: Paris 18th, Île-de-France';

  @override
  String get tagsExample => 'E.g.: business, networking, tech';

  @override
  String get tagsSeparatedByCommas => 'Separate tags with commas';

  @override
  String get privateGroupLabel => 'Private group';

  @override
  String get membersMustBeApproved => 'Members must be approved';

  @override
  String get modifyTheGroup => 'Edit the group';

  @override
  String get noPendingRequests => 'No pending requests';

  @override
  String get membershipRequestsTitle => 'Membership requests';

  @override
  String get requestApprovedSuccess => 'Request approved';

  @override
  String get requestRejectedSuccess => 'Request rejected';

  @override
  String get rejectAction => 'Reject';

  @override
  String get approveAction => 'Approve';

  @override
  String get promoteToAdmin => 'Promote to Admin';

  @override
  String get removeFromGroup => 'Remove from group';

  @override
  String get confirmRemoveMember =>
      'Do you really want to remove this member from the group?';

  @override
  String get memberPromotedAdmin => 'Member promoted to admin';

  @override
  String get promoteError => 'Error during promotion';

  @override
  String get memberDemotedAdmin => 'Admin demoted';

  @override
  String get demoteError => 'Error during demotion';

  @override
  String get memberRemovedFromGroup => 'Member removed from the group';

  @override
  String get removalError => 'Error during removal';

  @override
  String get confirmTitle => 'Confirm';

  @override
  String viewAllMembers(int count) {
    return 'View all $count members';
  }

  @override
  String get allFeminine => 'All';

  @override
  String get originRegionLabel => 'Region of origin';

  @override
  String get toutes => 'All';

  @override
  String get groupCreationSuccess => 'Group created successfully';

  @override
  String get requester => 'Requester';

  @override
  String get podcastsAddCover => 'Add a cover';

  @override
  String get podcastsCategoryRequired => 'Category *';

  @override
  String get podcastsLanguageRequired => 'Language *';

  @override
  String get podcastsPublicationFrequency => 'Publication frequency';

  @override
  String get podcastsAddTag => 'Add a tag';

  @override
  String get podcastsNewEpisodeTitle => 'New episode';

  @override
  String get podcastsAddChapterDialog => 'Add a chapter';

  @override
  String get podcastsChapterTitleLabel => 'Chapter title';

  @override
  String get podcastsMinutes => 'Minutes';

  @override
  String get podcastsSeconds => 'Seconds';

  @override
  String get podcastsAdd => 'Add';

  @override
  String get podcastsSelectAudioFile => 'Please select an audio file';

  @override
  String get podcastsEpisodePublished => 'Episode published successfully!';

  @override
  String get podcastsAudioFileTitle => 'Select an audio file';

  @override
  String get podcastsFileSelected => 'File selected';

  @override
  String get podcastsNoChaptersAdded => 'No chapters added';

  @override
  String podcastsErrorNotFound(String error) {
    return 'Error: $error';
  }

  @override
  String get podcastsNotFound => 'Podcast not found';

  @override
  String get podcastsEpisodeNotFound => 'Episode not found';

  @override
  String podcastsBy(String name) {
    return 'By $name';
  }

  @override
  String get podcastsAbout => 'About';

  @override
  String get podcastsNoEpisodes => 'No episodes available';

  @override
  String get podcastsDescriptionNotes => 'Description / Notes';

  @override
  String get podcastsLikeAction => 'Like';

  @override
  String get podcastsDownloadInProgress => 'Download in progress';

  @override
  String get podcastsSleepTimerTitle => 'Sleep timer';

  @override
  String get podcastsSleepTimerDisabled => 'Disabled';

  @override
  String get podcastsSleepTimer15 => '15 minutes';

  @override
  String get podcastsSleepTimer30 => '30 minutes';

  @override
  String get podcastsSleepTimer45 => '45 minutes';

  @override
  String get podcastsSleepTimer60 => '1 hour';

  @override
  String get podcastsSleepTimerEnd => 'End of episode';

  @override
  String get podcastsSleepTimerActivated => 'Stop at end of episode activated';

  @override
  String get podcastsSleepTimerFinished => 'Sleep timer finished';

  @override
  String podcastsSleepTimerSet(int minutes) {
    return 'Timer: $minutes minutes';
  }

  @override
  String podcastsEpisodeNumber(int number) {
    return 'Episode $number';
  }

  @override
  String get podcastsLiveLabel => 'Live';

  @override
  String get podcastsDownloaded => 'Downloaded';

  @override
  String get podcastsAvailableOffline => 'Available offline';

  @override
  String get podcastsDeleteDownload => 'Delete download';

  @override
  String get podcastsDownloadDeleted => 'Download deleted';

  @override
  String get podcastsSaveAsPodcast => 'Save as Podcast';

  @override
  String get podcastsSaveAsPodcastDesc =>
      'Publish this room recording as a podcast episode';

  @override
  String get podcastsSelectPodcast => 'Select a podcast';

  @override
  String get podcastsSelectOrCreate => 'Select a podcast or create a new one';

  @override
  String get podcastsRecordingSoon => 'Room recording will be available soon';

  @override
  String get podcastsAudioFileNotFound => 'Audio file not found';

  @override
  String get podcastsEpisodeTitleInput => 'Episode title';

  @override
  String get podcastsEpisodeDescriptionInput =>
      'Episode description (optional)';

  @override
  String get podcastsSourceRoom => 'Source room';

  @override
  String get podcastsPublish => 'Publish';

  @override
  String get podcastsNoPodcastsYet => 'You don\'t have any podcasts yet';

  @override
  String get podcastsCreateFirstPodcast =>
      'Create your first podcast to add episodes';

  @override
  String get podcastsCreateNewPodcast => 'Create a new podcast';

  @override
  String get podcastsStartSeries => 'Start your podcast series';

  @override
  String get notificationReplySent => 'Message sent';

  @override
  String get notificationReplyConfirmation => 'Your reply has been sent';

  @override
  String get notificationPendingMessage => 'Pending message';

  @override
  String get notificationPendingReply =>
      'Your reply will be sent as soon as possible';

  @override
  String get notificationIncomingVideoCall => 'Incoming video call...';

  @override
  String get notificationIncomingAudioCall => 'Incoming audio call...';

  @override
  String get notificationAnswerAction => 'Answer';

  @override
  String get notificationDeclineAction => 'Decline';

  @override
  String get notificationReplyAction => 'Reply';

  @override
  String get notificationMarkReadAction => 'Mark as read';

  @override
  String get notificationSendButton => 'Send';

  @override
  String get notificationTypePlaceholder => 'Type your reply...';

  @override
  String get notificationCallsChannel => 'Calls';

  @override
  String get notificationCallsDescription => 'Notifications for incoming calls';

  @override
  String get notificationUnknownCaller => 'Unknown';

  @override
  String get taxExemptBySeller => 'Exempt by seller';

  @override
  String get sharedMedia => 'Shared media';

  @override
  String get thisWeek => 'This week';

  @override
  String get lastWeek => 'Last week';

  @override
  String get thisMonth => 'This month';

  @override
  String get sharedPhotosWillAppear => 'Shared photos will appear here';

  @override
  String get sharedFilesWillAppear => 'Shared files will appear here';

  @override
  String get otherMembers => 'Other members';

  @override
  String get imagePreview => 'Image preview';

  @override
  String get videoPreview => 'Video preview';

  @override
  String get documentPreview => 'Document preview';

  @override
  String get conversationBackground => 'Conversation background';

  @override
  String get defaultBackground => 'Default background';

  @override
  String get colors => 'Colors';

  @override
  String get defaultTheme => 'Default theme';

  @override
  String get imageSelected => 'Image selected';

  @override
  String get chooseImage => 'Choose an image';

  @override
  String errorImageSelection(String error) {
    return 'Error selecting image: $error';
  }

  @override
  String errorApplication(String error) {
    return 'Error applying: $error';
  }

  @override
  String get receivedMessage => 'Received message';

  @override
  String get sentMessage => 'Sent message';

  @override
  String get messageDeleted => 'Message deleted';

  @override
  String get photo => 'Photo';

  @override
  String get video => 'Video';

  @override
  String get audio => 'Audio';

  @override
  String get document => 'Document';

  @override
  String get systemMessage => 'System message';

  @override
  String get call => 'Call';

  @override
  String get pending => 'Pending';

  @override
  String get sharedLocation => 'Shared location';

  @override
  String get embassyTemporarilyClosed => 'Temporarily closed';

  @override
  String get embassyOfficialVerified => 'Official Verified Account';

  @override
  String get embassyComingSoon => 'Coming Soon';

  @override
  String get embassyConsularServices => 'Consular Services';

  @override
  String get embassyOpeningHours => 'Opening Hours';

  @override
  String get embassyJurisdiction => 'Jurisdiction';

  @override
  String get embassyJurisdictionDescription =>
      'This embassy serves nationals in:';

  @override
  String get embassyNoActivities => 'No activities scheduled at the moment.';

  @override
  String get embassyNoNews => 'No news available.';

  @override
  String get embassyInfoTab => 'Info';

  @override
  String get embassyActivitiesTab => 'Activities';

  @override
  String get embassyNewsTab => 'News';

  @override
  String get embassyFormPrefilledNotice =>
      'Form pre-filled from your profile. Please verify and complete the information.';

  @override
  String get embassyRequestType => 'Request type *';

  @override
  String get embassyPersonalInfo => 'Personal information';

  @override
  String get embassyFullName => 'Full name *';

  @override
  String get embassyDateOfBirth => 'Date of birth *';

  @override
  String get embassyDateFormat => 'DD/MM/YYYY';

  @override
  String get embassyPlaceOfBirth => 'Place of birth';

  @override
  String get embassyNationality => 'Nationality';

  @override
  String get embassyNigerien => 'Nigerien';

  @override
  String get embassyCurrentAddress => 'Current address *';

  @override
  String get embassyContactSection => 'Contact';

  @override
  String get embassyPhone => 'Phone *';

  @override
  String get embassyEmailField => 'Email';

  @override
  String get embassyPassportInfo => 'Passport information';

  @override
  String get embassyPassportNumber => 'Passport number';

  @override
  String get embassyPassportExpiry => 'Expiration date';

  @override
  String get embassyNotesSection => 'Remarks / Additional information';

  @override
  String get embassyNotesPlaceholder =>
      'Add additional details if necessary...';

  @override
  String embassyCharacterCount(int count) {
    return '$count characters';
  }

  @override
  String get embassyWarningMessage =>
      'You may need to visit the embassy with original documents. Keep your tracking number.';

  @override
  String get embassySending => 'Sending...';

  @override
  String get embassySubmitRequest => 'Submit request';

  @override
  String get embassyFieldRequired => 'Required field';

  @override
  String get embassyFieldRequiredShort => 'Required';

  @override
  String get embassyUserNotConnected => 'User not logged in';

  @override
  String embassyErrorPrefix(String error) {
    return 'Error: $error';
  }

  @override
  String get embassyPassportRenewal => 'Passport renewal';

  @override
  String get embassyPassportNewRequest => 'New passport application';

  @override
  String get embassyVisaApplication => 'Visa application';

  @override
  String get embassyBirthCertificate => 'Birth certificate';

  @override
  String get embassyMarriageCertificate => 'Marriage certificate';

  @override
  String get embassyDeathCertificate => 'Death certificate';

  @override
  String get embassyConsularId => 'Consular card';

  @override
  String get embassyLegalDocument => 'Legal document';

  @override
  String get embassyLaissezPasser => 'Laissez-passer';

  @override
  String get embassyPowerOfAttorney => 'Power of attorney';

  @override
  String get embassyInscription => 'Consular registration';

  @override
  String get embassyOtherRequest => 'Other request';

  @override
  String get embassyPassportRenewalDesc =>
      'Renewal of an existing passport nearing expiration.';

  @override
  String get embassyPassportNewRequestDesc =>
      'First passport application or replacement of a lost/stolen passport.';

  @override
  String get embassyVisaApplicationDesc =>
      'Visa application for foreign nationals.';

  @override
  String get embassyBirthCertificateDesc =>
      'Copy or extract of birth certificate.';

  @override
  String get embassyMarriageCertificateDesc =>
      'Copy or extract of marriage certificate.';

  @override
  String get embassyDeathCertificateDesc =>
      'Copy or extract of death certificate.';

  @override
  String get embassyConsularIdDesc =>
      'Consular registration card for Nigerien nationals.';

  @override
  String get embassyLegalDocumentDesc =>
      'Legalization or certification of official documents.';

  @override
  String get embassyLaissezPasserDesc =>
      'Temporary travel document in case of passport loss.';

  @override
  String get embassyPowerOfAttorneyDesc =>
      'Power of attorney for legal representation.';

  @override
  String get embassyInscriptionDesc =>
      'Registration in the register of Nigeriens abroad.';

  @override
  String get embassyOtherRequestDesc => 'Other type of administrative request.';

  @override
  String get embassyMessageType => 'Message type';

  @override
  String get embassySubject => 'Subject *';

  @override
  String get embassyMessage => 'Message *';

  @override
  String get embassyMessageNote =>
      'Your message will be forwarded to the embassy. You will receive a notification when they respond.';

  @override
  String get embassySendMessage => 'Send message';

  @override
  String get embassySubjectRequired => 'Subject is required';

  @override
  String get embassySubjectMinLength =>
      'Subject must contain at least 5 characters';

  @override
  String get embassyMessageRequired => 'Message is required';

  @override
  String get embassyMessageMinLength =>
      'Message must contain at least 20 characters';

  @override
  String embassyMessageCharacterCount(int count) {
    return '$count/1000 characters';
  }

  @override
  String get embassyMessageGeneral => 'General question';

  @override
  String get embassyMessageRequest => 'Service request';

  @override
  String get embassyMessageComplaint => 'Complaint';

  @override
  String get embassyMessageInquiry => 'Information';

  @override
  String get embassyMessageFollowUp => 'File follow-up';

  @override
  String get embassySearchTitle => 'Search employee';

  @override
  String embassyStaffTitle(String name) {
    return 'Staff - $name';
  }

  @override
  String get embassyAllDepartments => 'All departments';

  @override
  String get embassyDepartmentDirection => 'Direction';

  @override
  String get embassyDepartmentConsular => 'Consular services';

  @override
  String get embassyDepartmentVisa => 'Visa section';

  @override
  String get embassyDepartmentCivilStatus => 'Civil status';

  @override
  String get embassyDepartmentSocial => 'Social affairs';

  @override
  String get embassyDepartmentChancellery => 'Chancellery';

  @override
  String get embassyDepartmentCommunication => 'Communication';

  @override
  String get embassyDepartmentAdministration => 'Administration';

  @override
  String get embassyLoadingError => 'Loading error';

  @override
  String get embassyRetry => 'Retry';

  @override
  String get embassyNoEmployeeFound => 'No employee found';

  @override
  String get embassyModifySearch => 'Try modifying your search criteria';

  @override
  String get adminAnalyticsAndReports => 'Analytics & Reports';

  @override
  String get adminAnalyticsSubtitle => 'Application statistics and metrics';

  @override
  String get adminLoadingError => 'Loading error';

  @override
  String get adminUserGrowth => 'User Growth';

  @override
  String get adminToday => 'Today';

  @override
  String get adminThisWeek => 'This week';

  @override
  String get adminThisMonth => 'This month';

  @override
  String get adminMonthlyEvolution => 'Monthly Evolution (last 6 months)';

  @override
  String get adminNoDataAvailable => 'No data available';

  @override
  String get adminEventsByCategory => 'Events by Category';

  @override
  String get adminBusinessesByCategory => 'Businesses by Category';

  @override
  String get adminNoData => 'No data';

  @override
  String get adminDataExport => 'Data Export';

  @override
  String get adminExportUsers => 'Export Users';

  @override
  String get adminExportEvents => 'Export Events';

  @override
  String get adminExportBusinesses => 'Export Businesses';

  @override
  String get adminExportTransactions => 'Export Transactions';

  @override
  String get adminPanelTitle => 'Admin Panel';

  @override
  String get adminDiaspoNigerMonitoring => 'DiaspoNiger Monitoring';

  @override
  String get adminOrText => 'OR';

  @override
  String get adminGoogleError => 'Google login error';

  @override
  String get adminAccessDeniedMessage =>
      'Access denied. Administrator account required.';

  @override
  String get adminContentModeration => 'Content Moderation';

  @override
  String get adminContentSubtitle => 'Manage community events and groups';

  @override
  String adminEventsTabCount(int count) {
    return 'Events ($count)';
  }

  @override
  String adminGroupsTabCount(int count) {
    return 'Groups ($count)';
  }

  @override
  String get adminLoadingContent => 'Loading content...';

  @override
  String get adminOrganizerLabel => 'Organizer';

  @override
  String get adminMembersCount => 'members';

  @override
  String get adminCategoryLabel => 'Category';

  @override
  String get adminCancelAction => 'Cancel';

  @override
  String get adminDeleteAction => 'Delete';

  @override
  String get adminConfirmAction => 'Confirm';

  @override
  String get adminCancelEventTitle => 'Cancel event';

  @override
  String get adminCancelEventMsg =>
      'Are you sure you want to cancel this event?';

  @override
  String get adminDeleteEventTitle => 'Delete event';

  @override
  String get adminDeleteEventMsg =>
      'Are you sure you want to delete this event? This action is irreversible.';

  @override
  String get adminMakePublicAction => 'Make public';

  @override
  String get adminMakePrivateAction => 'Make private';

  @override
  String get adminEventCancelled => 'Event cancelled';

  @override
  String get adminEventDeleted => 'Event deleted';

  @override
  String get adminGroupMadePublic => 'Group made public';

  @override
  String get adminGroupMadePrivate => 'Group made private';

  @override
  String get adminGroupDeleted => 'Group deleted';

  @override
  String get adminNoEventsFound => 'No events found';

  @override
  String get adminNoGroupsFound => 'No groups found';

  @override
  String get adminErrorNotConnected => 'Admin not connected';

  @override
  String get adminReportsManagement => 'Reports Management';

  @override
  String get adminReportsSubtitle => 'Handle inappropriate content reports';

  @override
  String get adminPendingLabel => 'Pending';

  @override
  String get adminResolvedLabel => 'Resolved';

  @override
  String get adminDismissedLabel => 'Dismissed';

  @override
  String get adminTotalLabel => 'Total';

  @override
  String adminProcessedTabCount(int count) {
    return 'Processed ($count)';
  }

  @override
  String get adminTypeFilterLabel => 'Type:';

  @override
  String get adminAllTypesOption => 'All';

  @override
  String get adminReportedOnLabel => 'Reported on:';

  @override
  String get adminTargetNameLabel => 'Name';

  @override
  String get adminCapturedContentLabel => 'Captured content (preserved)';

  @override
  String get adminHostLabel => 'Host';

  @override
  String get adminDescriptionLabel => 'Description';

  @override
  String get adminAdminNoteLabel => 'Admin note';

  @override
  String get adminReportDismissed => 'Report dismissed';

  @override
  String get adminReportProcessed => 'Report processed';

  @override
  String get adminReportProcessedNotified => 'Report processed (user notified)';

  @override
  String get adminContentDeleted => 'Content deleted';

  @override
  String get adminContentDeletedNotified => 'Content deleted (user notified)';

  @override
  String get adminDismissReportTitle => 'Dismiss report';

  @override
  String get adminDismissReportPrompt => 'Reason for dismissal:';

  @override
  String get adminProcessReportTitle => 'Process report';

  @override
  String get adminProcessReportPrompt => 'Resolution note:';

  @override
  String get adminDeleteContentMsg =>
      'Are you sure you want to delete this content?';

  @override
  String adminDeleteIrreversibleMsg(String type) {
    return 'This action is irreversible and will permanently delete the $type.';
  }

  @override
  String get adminNoResultsSearch => 'No results for this search';

  @override
  String get adminNoReportsAvailable => 'No reports';

  @override
  String get adminTargetIdLabel => 'Target ID';

  @override
  String get adminReportedByLabel => 'Reported by';

  @override
  String get adminReportedUserLabel => 'Reported user';

  @override
  String get adminLoadingReports => 'Loading reports...';

  @override
  String get adminRejectAction => 'Reject';

  @override
  String get adminProcessAction => 'Process';

  @override
  String get adminDeleteContentAction => 'Delete content';

  @override
  String get adminClearFiltersAction => 'Clear filters';

  @override
  String get adminViewTheLabel => 'View the';

  @override
  String get adminGeneralStatsTitle => 'General Statistics';

  @override
  String get adminActiveSessionsLabel => 'Active Sessions';

  @override
  String get adminEventsLabel => 'Events';

  @override
  String get adminGroupsLabel => 'Groups';

  @override
  String get adminCommerceTitle => 'Commerce & Marketplace';

  @override
  String get adminBusinessesLabel => 'Businesses';

  @override
  String get adminProductsLabel => 'Products';

  @override
  String get adminTransactionsLabel => 'Transactions';

  @override
  String get adminReportsLabel => 'Reports';

  @override
  String get adminQuickActionsTitle => 'Quick Actions';

  @override
  String get adminActiveStatus => 'active';

  @override
  String get adminManageEmbassiesTitle => 'Manage Embassies';

  @override
  String get adminManageEmbassiesDesc => 'Create and manage embassy accounts';

  @override
  String get adminLiveAudioRoomsTitle => 'Live Audio Rooms';

  @override
  String get adminNoLiveRoomsTitle => 'No live rooms';

  @override
  String get adminNoLiveRoomsMsg => 'There are currently no live audio rooms.';

  @override
  String get adminLiveLabel => 'LIVE';

  @override
  String get adminPaidTag => 'Paid';

  @override
  String get adminVideoTag => 'Video';

  @override
  String get adminModeratorModeTitle => 'Moderation Mode';

  @override
  String get adminModeratorModeMsg =>
      'You will join this room in invisible mode (ghost mode). Participants will not be able to see you.\n\nYou will be able to:\n• Listen to conversations\n• Watch videos (if enabled)\n• Warn the host\n• Close the room if necessary';

  @override
  String get adminJoinAction => 'Join';

  @override
  String get adminTransferFeesTitle => 'Transfer Fees';

  @override
  String get adminTransferFeesDesc => 'Configure fees on money transfers';

  @override
  String get adminMarketplaceFeesTitle => 'Marketplace Fees';

  @override
  String get adminMarketplaceFeesDesc => 'Commission on product sales';

  @override
  String get adminSaveChanges => 'Save changes';

  @override
  String get adminFieldRequired => 'Required';

  @override
  String get adminValueBetweenError => 'Value between 0 and 100';

  @override
  String get adminInvalidNumberError => 'Invalid number';

  @override
  String get adminBasePricesTitle => 'Base prices (7 days)';

  @override
  String get adminStandardTier => 'Standard';

  @override
  String get adminStandardTierDesc => 'Enhanced visibility';

  @override
  String get adminFeaturedTier => 'Featured';

  @override
  String get adminFeaturedTierDesc => 'Badge + better position';

  @override
  String get adminPremiumTier => 'Premium';

  @override
  String get adminPremiumTierDesc => 'Top position + dedicated section';

  @override
  String get adminDurationMultipliersTitle => 'Duration multipliers';

  @override
  String get adminDays7Label => '7 days';

  @override
  String get adminDays30Label => '30 days';

  @override
  String get adminDays90Label => '90 days';

  @override
  String get adminPricePreviewTitle => 'Price preview (Standard)';

  @override
  String get adminPercentageHint => 'Ex: 2.5 for 2.5%';

  @override
  String get adminFeesUpdatedSuccess => 'Fees updated';

  @override
  String get adminBoostPricesUpdatedSuccess => 'Boost prices updated';

  @override
  String get adminConfigurationAppTitle => 'App Configuration';

  @override
  String get podcastsSubscribersLabel => 'subscribers';

  @override
  String get podcastsEpisodesLabel => 'episodes';

  @override
  String get podcastsPlaysLabel => 'plays';

  @override
  String get securityDeleteBackupTitle => 'Delete backup?';

  @override
  String get securityDeleteBackupContent =>
      'This action is irreversible. If you lose your keys and no longer have a backup, you will not be able to read your old messages.';

  @override
  String get securityBackupDeleted => 'Backup deleted';

  @override
  String get securityBackupTitle => 'Key backup';

  @override
  String get e2eeBackupNudgeMessage =>
      'Back up your encryption keys so you don\'t lose access to your messages if you switch devices.';

  @override
  String get e2eeBackupNudgeAction => 'Back up';

  @override
  String get e2eeRestoreNudgeMessage =>
      'Restore your encryption keys to read your encrypted messages on this device.';

  @override
  String get e2eeRestoreNudgeAction => 'Restore';

  @override
  String get securityRestoreKeys => 'Restore keys';

  @override
  String get securityGeneratePassphrase => 'Generate secure passphrase';

  @override
  String get securityCreateBackup => 'Create backup';

  @override
  String get securityPassphrase => 'Passphrase';

  @override
  String get securityPassphraseMin => 'Minimum 8 characters';

  @override
  String get securityConfirmPassphrase => 'Confirm passphrase';

  @override
  String securityDeletionError(String error) {
    return 'Error during deletion: $error';
  }

  @override
  String get bugReportDescription => 'Bug description';

  @override
  String get bugReportDescriptionHint => 'Describe the problem encountered...';

  @override
  String get bugReportDescriptionRequired => 'Please describe the bug';

  @override
  String get bugReportStepsOptional => 'Steps to reproduce (optional)';

  @override
  String get bugReportStepsHint => '1. Open the app\n2. ...';

  @override
  String get bugReportEmailOpened => 'Email app opened';

  @override
  String get bugReportEmailFailed => 'Unable to open email app';

  @override
  String get reminder => 'Reminder';

  @override
  String get confirmSend => 'Confirm sending';

  @override
  String get titleLabel => 'Title';

  @override
  String get adminGlobalNotifications => 'Global Notifications';

  @override
  String get adminGlobalNotificationsDesc => 'Send notifications to all users';

  @override
  String get adminNewNotification => 'New Notification';

  @override
  String get adminNotifTitleHint => 'Ex: Important update';

  @override
  String get adminNotifMessageHint => 'Notification content...';

  @override
  String get adminRecipients => 'Recipients';

  @override
  String get adminAllUsers => 'All users';

  @override
  String get adminAdministrators => 'Administrators';

  @override
  String get adminVerifiedProfiles => 'Verified profiles';

  @override
  String get adminBusinessOwners => 'Business owners';

  @override
  String get adminSending => 'Sending...';

  @override
  String get adminNoTitle => 'No title';

  @override
  String get adminStatusSent => 'Sent';

  @override
  String get adminStatusPending => 'Pending';

  @override
  String get adminStatusFailed => 'Failed';

  @override
  String get adminTargetAll => 'All';

  @override
  String get adminTargetAdmins => 'Admins';

  @override
  String get adminTargetVerified => 'Verified';

  @override
  String get adminTargetBusinesses => 'Businesses';

  @override
  String get adminNoNotificationsSent => 'No notifications sent';

  @override
  String get adminFillTitleAndMessage => 'Please fill in the title and message';

  @override
  String get adminNotConnected => 'Error: Admin not connected';

  @override
  String get typeLabel => 'Type:';

  @override
  String get contentDeleted => 'Content deleted';

  @override
  String get contentDeletedUserNotified => 'Content deleted (user notified)';

  @override
  String get adminRejectionReason => 'Rejection reason';

  @override
  String get adminMaintenanceMessageHint =>
      'Ex: Application under maintenance...';

  @override
  String get adminReportRejected => 'Report rejected';

  @override
  String get adminReportProcessedUserNotified =>
      'Report processed (user notified)';

  @override
  String get adminReportsManagementDesc =>
      'Handle inappropriate content reports';

  @override
  String get adminRejectReport => 'Reject report';

  @override
  String get adminRejectionReasonLabel => 'Rejection reason:';

  @override
  String get adminProcessReport => 'Process report';

  @override
  String get adminResolutionNoteLabel => 'Resolution note:';

  @override
  String get adminMinimumFee => 'Minimum fee (XOF)';

  @override
  String get adminMaximumFee => 'Maximum fee (XOF)';

  @override
  String get adminBoostRatesUpdated => 'Boost rates updated';

  @override
  String get adminLocationUpdateMin => 'Location update (min)';

  @override
  String get adminOnlineHeartbeatMin => 'Online status heartbeat (min)';

  @override
  String get adminCacheDurationMin => 'Cache duration (min)';

  @override
  String get adminExampleValues => 'Ex: 1, 2, 5, 10, 20';

  @override
  String get adminSearchUserHint => 'Search for a user...';

  @override
  String adminUserActivityTitle(String name) {
    return 'Activity of $name';
  }

  @override
  String adminChangeTo(String role) {
    return 'Change to $role';
  }

  @override
  String get revoke => 'Revoke';

  @override
  String get refresh => 'Refresh';

  @override
  String get adminRoleManagementTitle => 'Admin Role Management';

  @override
  String get adminRoleManagementSubtitle =>
      'Assign and manage administrator roles';

  @override
  String get adminNoAdminsConfigured => 'No administrators configured';

  @override
  String get noName => 'No name';

  @override
  String lastLoginAt(String lastLogin) {
    return 'Last login: $lastLogin';
  }

  @override
  String adminChangeRoleConfirm(String name, String oldRole, String newRole) {
    return 'Do you want to change $name\'s role from $oldRole to $newRole?';
  }

  @override
  String adminRevokeAccessConfirm(String name) {
    return 'Do you really want to revoke $name\'s admin access? This person will no longer be able to access the admin panel.';
  }

  @override
  String groupsCount(int count) {
    return 'Groups ($count)';
  }

  @override
  String get groupLabel => 'Group';

  @override
  String get refund => 'Refund';

  @override
  String get adminFeesPercentageLabel => 'Fees percentage';

  @override
  String get adminMinFeesLabel => 'Minimum fees (XOF)';

  @override
  String get adminMaxFeesLabel => 'Maximum fees (XOF)';

  @override
  String get adminPlatformCommissionLabel => 'Platform commission';

  @override
  String get adminMinCommissionLabel => 'Min commission (XOF)';

  @override
  String get adminMaxCommissionLabel => 'Max commission (XOF)';

  @override
  String get adminMaxDimensionLabel => 'Max dimension (px)';

  @override
  String adminUserActivityTitleParam(String name) {
    return 'Activity of $name';
  }

  @override
  String get myReports => 'My reports';

  @override
  String get myReportsSubtitle => 'View your reports history';

  @override
  String get calls => 'Calls';

  @override
  String get noiseSuppression => 'Noise suppression';

  @override
  String get noiseSuppressionSubtitle =>
      'Reduces background noise during calls';

  @override
  String get soundAndVibration => 'Sound and Vibration';

  @override
  String get sound => 'Sound';

  @override
  String get vibration => 'Vibration';

  @override
  String get chooseCurrency => 'Choose currency';

  @override
  String get pricesDisplayedIn => 'Prices will be displayed in this currency';

  @override
  String get noCurrencyFound => 'No currency found';

  @override
  String get chatBackground => 'Chat background';

  @override
  String get customColor => 'Custom color';

  @override
  String get customImage => 'Custom image';

  @override
  String get greenDefault => 'Green (Default)';

  @override
  String get orangeClassic => 'Orange (Classic)';

  @override
  String get chooseColor => 'Choose color';

  @override
  String get mainCurrencies => 'Main currencies';

  @override
  String get africa => 'Africa';

  @override
  String get asia => 'Asia';

  @override
  String get europe => 'Europe';

  @override
  String get americas => 'Americas';

  @override
  String get oceaniaMiddleEast => 'Oceania & Middle East';

  @override
  String get describeTheProblem => 'Describe the problem...';

  @override
  String get sendReport => 'Send report';

  @override
  String get deviceNameLabel => 'Device name';

  @override
  String get renameDeviceTitle => 'Rename device';

  @override
  String get searchCurrency => 'Search for a currency...';

  @override
  String get restoreKeys => 'Restore keys';

  @override
  String get tags => 'Tags';

  @override
  String get requestToJoin => 'Request to join';

  @override
  String get podcastsCancel => 'Cancel';

  @override
  String get addFriendsAsRecipients => 'Add your friends as recipients';

  @override
  String get noFriendMatchesSearch => 'No friend matches your search';

  @override
  String get addManually => 'Add manually';

  @override
  String get chooseRecipient => 'Choose a recipient';

  @override
  String get cardLabel => 'Card';

  @override
  String get cashLabel => 'Cash';

  @override
  String get noRecipientFound => 'No recipient found';

  @override
  String get noRecipientRegistered => 'No recipient registered';

  @override
  String get tryModifyingFilters => 'Try modifying filters';

  @override
  String get addFirstRecipient => 'Add your first recipient';

  @override
  String confirmDeleteRecipient(String name) {
    return 'Are you sure you want to delete $name?';
  }

  @override
  String recipientDeletedSuccess(String name) {
    return '$name has been deleted';
  }

  @override
  String get removeFromFavorites => 'Remove from favorites';

  @override
  String get confirmDeleteTitle => 'Confirm deletion';

  @override
  String get amountSent => 'Amount sent';

  @override
  String get fees => 'Fees';

  @override
  String get totalDebited => 'Total debited';

  @override
  String get exchangeRate => 'Exchange rate';

  @override
  String get amountReceived => 'Amount received';

  @override
  String get recipient => 'Recipient';

  @override
  String get unknown => 'Unknown';

  @override
  String get information => 'Information';

  @override
  String get reference => 'Reference';

  @override
  String get paymentMode => 'Payment mode';

  @override
  String get stripeId => 'Stripe ID';

  @override
  String get mynitaRef => 'Mynita Ref';

  @override
  String get date => 'Date';

  @override
  String get notAvailable => 'N/A';

  @override
  String get completionDate => 'Completion date';

  @override
  String get failureReason => 'Failure reason';

  @override
  String get copiedToClipboard => 'Copied to clipboard';

  @override
  String get notes => 'Notes';

  @override
  String get activeFilters => 'Active filters';

  @override
  String get clearAll => 'Clear all';

  @override
  String get unknownDate => 'Unknown date';

  @override
  String reviewedOn(String date) {
    return 'Reviewed on $date';
  }

  @override
  String get unknownRecipient => 'Unknown recipient';

  @override
  String get noTransferFound => 'No transfer found';

  @override
  String get noTransferCompleted => 'No transfer completed yet';

  @override
  String get sendMoneyToLovedOnes => 'Send money to your loved ones';

  @override
  String get filterTransfers => 'Filter transfers';

  @override
  String get status => 'Status';

  @override
  String get period => 'Period';

  @override
  String get allPeriods => 'All';

  @override
  String get last7Days => 'Last 7 days';

  @override
  String get last30Days => 'Last 30 days';

  @override
  String get last3Months => 'Last 3 months';

  @override
  String get choosePeriod => 'Choose period';

  @override
  String get applyFilters => 'Apply filters';

  @override
  String get statusDebiting => 'Debiting';

  @override
  String get statusSending => 'Sending';

  @override
  String get statusRefunding => 'Refunding';

  @override
  String get noDeviceRegistered => 'No device registered';

  @override
  String get devicesE2eeWillAppear =>
      'Devices using end-to-end encryption will appear here.';

  @override
  String get rename => 'Rename';

  @override
  String get revokeDeviceQuestion => 'Revoke device?';

  @override
  String revokeDeviceConfirmMessage(String deviceName) {
    return 'Do you really want to revoke access for \"$deviceName\"?';
  }

  @override
  String get deviceRenameSuccess => 'Device renamed';

  @override
  String get deviceRenameError => 'Error renaming device';

  @override
  String get restoreOnThisDevice => 'Restore on this device';

  @override
  String get enterPassphraseToRestore =>
      'Enter your passphrase to restore your keys:';

  @override
  String get createABackup => 'Create a backup';

  @override
  String get createBackupButton => 'Create a backup';

  @override
  String get confirmPassphraseLabel => 'Confirm passphrase';

  @override
  String get passphraseCopied => 'Passphrase copied';

  @override
  String get xTwitter => 'X';

  @override
  String get more => 'More';

  @override
  String get travelMode => 'Travel Mode';

  @override
  String codeSentTo(String phoneNumber) {
    return 'Code sent to $phoneNumber';
  }

  @override
  String get addParticipant => 'Add participant';

  @override
  String get addToCall => 'Add to call';

  @override
  String get convertingToGroupCall => 'Converting to group call...';

  @override
  String get selectParticipantToAdd => 'Select a participant';

  @override
  String get noEligibleParticipants => 'No participants available';

  @override
  String get noEligibleParticipantsHint =>
      'Add friends or start a conversation to be able to add them to a call';

  @override
  String get recentConversations => 'Recent conversations';

  @override
  String get callConvertedToGroup => 'Converted to group call';

  @override
  String participantBusy(String name) {
    return '$name is on a call';
  }

  @override
  String get conversionFailed => 'Failed to add participant';

  @override
  String get slideToCancel => 'Cancel';

  @override
  String get releaseToCancel => 'Cancel';

  @override
  String get recordingLocked => 'Recording locked';

  @override
  String get releaseToLock => 'Release to lock';

  @override
  String get slideUpToLock => 'Slide up';

  @override
  String timeRemaining(String time) {
    return 'Time remaining: $time';
  }

  @override
  String get lock => 'Lock';

  @override
  String get localEvents => 'Local events';

  @override
  String get localEventsSubtitle =>
      'Receive notifications for new events in my city';

  @override
  String get systemMessages => 'System messages';

  @override
  String get systemMessagesSubtitle =>
      'Receive notifications for system events (e.g., new member)';

  @override
  String get confidentiality => 'Privacy';

  @override
  String get messagePreview => 'Message preview';

  @override
  String get messagePreviewSubtitle => 'Show message content in notifications';

  @override
  String get onlineStatus => 'Online';

  @override
  String seenAgo(String ago) {
    return 'Seen $ago';
  }

  @override
  String get offline => 'Offline';

  @override
  String discoverProfile(String link) {
    return 'Discover my profile on Diaspo Niger: $link';
  }

  @override
  String profileOf(String name) {
    return 'Profile of $name';
  }

  @override
  String get unableToGenerateLink => 'Unable to generate share link';

  @override
  String get profileSendFriendRequest => 'Send friend request';

  @override
  String get profileFriendRequestSent => 'Friend request sent';

  @override
  String get profileFriendRequestFailed => 'Failed to send request';

  @override
  String get profileNewMember => 'New member';

  @override
  String get profileNoBio => 'No bio';

  @override
  String get profileNoSkillsAdded => 'No skills added';

  @override
  String get profileNoInterestsAdded => 'No interests added';

  @override
  String get profileShowOnlineStatus => 'Show my online status';

  @override
  String get profileReport => 'Report';

  @override
  String get profileSettings => 'Settings';

  @override
  String get profileSendingRequest => 'Sending...';

  @override
  String get profileTravelModeSubtitle =>
      'Allow location even when the app is closed (updates every 5 min)';

  @override
  String get profileShowOnlineStatusSubtitle =>
      'Allows you to see and be seen online. If disabled, you won\'t see others\' status.';

  @override
  String get whoSeesYou => 'Who sees you';

  @override
  String get dataSaverMode => 'Data saver mode';

  @override
  String get dataSaverModeSubtitle =>
      'Media not downloaded automatically in chats';

  @override
  String get displayCurrency => 'Currency';

  @override
  String get displayCurrencySubtitle =>
      'Prices will be displayed in this currency';

  @override
  String profileUpdateError(String error) {
    return 'Error updating: $error';
  }

  @override
  String get profileLoadingText => 'Loading...';

  @override
  String get profileLoadError => 'Loading error';

  @override
  String conversationYouPrefix(String message) {
    return 'You: $message';
  }

  @override
  String get emojis => 'Emojis';

  @override
  String get gifs => 'GIFs';

  @override
  String get searchGifs => 'Search GIFs';

  @override
  String get gifNoResults => 'No results.';

  @override
  String get gifLoadError => 'Could not load GIFs.';

  @override
  String get gifProviderNotConfigured => 'GIFs are not configured yet.';

  @override
  String get gifDataSaverNote => 'Downloaded once, sent without using data';

  @override
  String get stickerRecentlyUsed => 'Recently used';

  @override
  String get stickerDataSaverNote =>
      'Stickers are downloaded once, then sent without using data.';

  @override
  String get searchStickers => 'Search stickers';

  @override
  String get searchResults => 'Results';

  @override
  String get showKeyboard => 'Show keyboard';

  @override
  String get stickers => 'Stickers';

  @override
  String get stickerPacks => 'Sticker packs';

  @override
  String get recentStickers => 'Recent';

  @override
  String get favoriteStickers => 'Favorites';

  @override
  String get addStickerPack => 'Add sticker pack';

  @override
  String get removeStickerPack => 'Remove pack';

  @override
  String get stickerPackAdded => 'Sticker pack added';

  @override
  String get stickerPackRemoved => 'Sticker pack removed';

  @override
  String get noStickersYet => 'No stickers yet';

  @override
  String get browseStickers => 'Browse sticker packs';

  @override
  String get stickerLabel => 'Sticker';

  @override
  String get myStickerPacks => 'My sticker packs';

  @override
  String get createStickerPack => 'Create sticker pack';

  @override
  String get stickerPackName => 'Pack name';

  @override
  String get stickerPackDescription => 'Description (optional)';

  @override
  String get stickerPackThumbnail => 'Thumbnail';

  @override
  String get addStickers => 'Add stickers';

  @override
  String get stickerPackCreated => 'Sticker pack created';

  @override
  String get stickerPackPending => 'Pending moderation';

  @override
  String get stickerPackApproved => 'Approved';

  @override
  String get stickerPackRejected => 'Rejected';

  @override
  String get deleteStickerPack => 'Delete pack';

  @override
  String get confirmDeleteStickerPack =>
      'Are you sure you want to delete this sticker pack?';

  @override
  String get noStickerPacks => 'No sticker packs';

  @override
  String get officialPacks => 'Official packs';

  @override
  String get communityPacks => 'Community packs';

  @override
  String get serviceFeed => 'Social Feed';

  @override
  String get feedTitle => 'Social Feed';

  @override
  String get storyTakePhoto => 'Take a photo';

  @override
  String get storyChooseFromGallery => 'Choose from gallery';

  @override
  String storiesTodayCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count stories today',
      one: '1 story today',
      zero: 'No story today',
    );
    return '$_temp0';
  }

  @override
  String get storiesShow => 'Show';

  @override
  String get storyChooseVideo => 'Choose a video';

  @override
  String get storyVideoMaxDuration => '30 seconds maximum';

  @override
  String storyViewersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count views',
      one: '1 view',
      zero: 'No views',
    );
    return '$_temp0';
  }

  @override
  String get storyNoViewersYet => 'No one has seen this story yet';

  @override
  String get feedEmpty => 'No posts yet.\nBe the first to share something!';

  @override
  String feedNewPostsPill(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count new posts',
      one: '1 new post',
      zero: 'No new post',
    );
    return '$_temp0';
  }

  @override
  String get createPost => 'Create a post';

  @override
  String get postPlaceholder => 'What\'s on your mind?';

  @override
  String get publishPost => 'Publish';

  @override
  String get likePost => 'Like';

  @override
  String get commentPost => 'Comment';

  @override
  String get sharePost => 'Share';

  @override
  String get deletePost => 'Delete post';

  @override
  String get confirmDeletePost => 'Are you sure you want to delete this post?';

  @override
  String get followUser => 'Follow';

  @override
  String get unfollowUser => 'Unfollow';

  @override
  String get followTitle => 'Followers & following';

  @override
  String get followersTitle => 'Followers';

  @override
  String get followingTitle => 'Following';

  @override
  String get noFollowersYet => 'No followers yet.';

  @override
  String get noFollowingYet => 'Not following anyone yet.';

  @override
  String get myFollowsTitle => 'Followers & following';

  @override
  String get myFollowsSubtitle => 'See who follows you and who you follow';

  @override
  String get errorLoadingData => 'Failed to load. Please try again.';

  @override
  String get commentPlaceholder => 'Add a comment…';

  @override
  String get addComment => 'Post';

  @override
  String get postDeleted => 'Post deleted';

  @override
  String get postShared => 'Post shared';

  @override
  String get noComments => 'No comments yet';

  @override
  String get postNotFoundTitle => 'Post not found';

  @override
  String get postNotFoundMessage =>
      'It may have been deleted by its author, or the link is incorrect.';

  @override
  String get postLoadFailedTitle => 'Can\'t show this post';

  @override
  String get postLoadFailedMessage => 'Check your connection, then try again.';

  @override
  String get backToFeed => 'Back to feed';

  @override
  String get deleteComment => 'Delete comment';

  @override
  String get confirmDeleteComment =>
      'Are you sure you want to delete this comment?';

  @override
  String get commentDeleted => 'Comment deleted';

  @override
  String get editPost => 'Edit post';

  @override
  String get editPostTitle => 'Edit post';

  @override
  String get likeComment => 'Like';

  @override
  String replyingTo(String name) {
    return 'Replying to $name';
  }

  @override
  String viewReplies(int count) {
    return 'View $count replies';
  }

  @override
  String get hideReplies => 'Hide replies';

  @override
  String get loadingMore => 'Loading…';

  @override
  String get feedError => 'Unable to load the feed';

  @override
  String get postError => 'Unable to load the post';

  @override
  String get addMedia => 'Add media';

  @override
  String get addVideo => 'Add a video';

  @override
  String get publishing => 'Publishing…';

  @override
  String get publishSuccess => 'Post created successfully';

  @override
  String get publishError => 'Error while publishing';

  @override
  String followers(int count) {
    return '$count followers';
  }

  @override
  String following(int count) {
    return '$count following';
  }

  @override
  String postLikes(int count) {
    return '$count like(s)';
  }

  @override
  String postComments(int count) {
    return '$count comment(s)';
  }

  @override
  String get mentionSuggestionHint => 'Mention a member';

  @override
  String get mentionNotificationTitle => 'You were mentioned';

  @override
  String mentionNotificationBody(String senderName, String groupName) {
    return '$senderName mentioned you in $groupName';
  }

  @override
  String mentionedBy(String name) {
    return 'Mentioned by $name';
  }

  @override
  String get loadingEllipsis => 'Loading...';

  @override
  String get rejected => 'Rejected';

  @override
  String get suspended => 'Suspended';

  @override
  String get reactivate => 'Reactivate';

  @override
  String get reject => 'Reject';

  @override
  String get approve => 'Approve';

  @override
  String get suspend => 'Suspend';

  @override
  String get rejectionReason => 'Reason for rejection';

  @override
  String get complete => 'Complete';

  @override
  String get buyer => 'Buyer';

  @override
  String get seller => 'Seller';

  @override
  String get deleteContent => 'Delete content';

  @override
  String get process => 'Process';

  @override
  String get clearFilters => 'Clear filters';

  @override
  String get newAdmin => 'New Admin';

  @override
  String get changeRole => 'Change role';

  @override
  String get revokeAccess => 'Revoke access';

  @override
  String exportInProgress(String type) {
    return 'Export of $type in progress...';
  }

  @override
  String get embassyCreated => 'Embassy created successfully!';

  @override
  String get createEmbassy => 'Create an embassy';

  @override
  String get joinAction => 'Join';

  @override
  String get viewReports => 'View Reports';

  @override
  String get manageUsers => 'Manage Users';

  @override
  String get sendNotification => 'Send Notification';

  @override
  String get viewAnalytics => 'View Analytics';

  @override
  String get configuration => 'Configuration';

  @override
  String get featureFlags => 'Feature Flags';

  @override
  String get auditHistory => 'Audit History';

  @override
  String get emailAction => 'Email';

  @override
  String get website => 'Website';

  @override
  String get getDirections => 'Get directions';

  @override
  String get department => 'Department';

  @override
  String get messageTitle => 'Title';

  @override
  String get messageBody => 'Message';

  @override
  String get confirmSending => 'Confirm sending';

  @override
  String get aboutToSend => 'You are about to send a notification to:';

  @override
  String messageLabel(String message) {
    return 'Message: $message';
  }

  @override
  String get searchBy => 'Search by name, reason, ID...';

  @override
  String viewTheItem(String item) {
    return 'View the $item';
  }

  @override
  String changeToRole(String role) {
    return 'Change to $role';
  }

  @override
  String get revokeAdminAccess => 'Revoke admin access';

  @override
  String get revokeAction => 'Revoke';

  @override
  String get feesUpdated => 'Fees updated';

  @override
  String get feePercentage => 'Fee percentage';

  @override
  String get minimumFee => 'Minimum fee (XOF)';

  @override
  String get maximumFee => 'Maximum fee (XOF)';

  @override
  String get platformCommission => 'Platform commission';

  @override
  String get minimumCommission => 'Minimum commission (XOF)';

  @override
  String get maximumCommission => 'Maximum commission (XOF)';

  @override
  String get boostRatesUpdated => 'Boost rates updated';

  @override
  String get vatRateUpdated => 'VAT rate updated';

  @override
  String get mediaLimitsUpdated => 'Media limits updated';

  @override
  String get maxDimension => 'Max dimension (px)';

  @override
  String get compressionQuality => 'Compression quality (%)';

  @override
  String get maxImagesPerUpload => 'Max images/upload';

  @override
  String get maxImageSize => 'Max image size (MB)';

  @override
  String get maxVideoSize => 'Max video size (MB)';

  @override
  String get maxCharsPerMessage => 'Max characters per message';

  @override
  String get urlsUpdated => 'URLs updated';

  @override
  String get intervalsUpdated => 'Intervals updated';

  @override
  String get baseShareUrl => 'Base URL for sharing';

  @override
  String get privacyEmail => 'Privacy email (GDPR)';

  @override
  String get bugReportEmail => 'Bug report email';

  @override
  String get feedbackEmail => 'Feedback email';

  @override
  String get moderationEmail => 'Moderation email';

  @override
  String get locationUpdateInterval => 'Location update (min)';

  @override
  String get onlineStatusHeartbeat => 'Online status heartbeat (min)';

  @override
  String get cacheDuration => 'Cache duration (min)';

  @override
  String get audioSettingsUpdated => 'Audio settings updated';

  @override
  String get exampleValues => 'Ex: 1, 2, 5, 10, 20';

  @override
  String get searchUser => 'Search for a user...';

  @override
  String get noUserFound => 'No user found';

  @override
  String get noActivityRecorded => 'No activity recorded';

  @override
  String activityOf(String name) {
    return 'Activity of $name';
  }

  @override
  String get confirmLogoutTitle => 'Confirm logout';

  @override
  String get disconnect => 'Disconnect';

  @override
  String get publicGroup => 'Public';

  @override
  String embassyApproved(String name) {
    return 'Embassy $name approved';
  }

  @override
  String embassyRejected(String name) {
    return 'Embassy $name rejected';
  }

  @override
  String embassySuspended(String name) {
    return 'Embassy $name suspended';
  }

  @override
  String embassyReactivated(String name) {
    return 'Embassy $name reactivated';
  }

  @override
  String get rejectRequest => 'Reject the request';

  @override
  String get featureFlagsUpdated => 'Feature flags updated';

  @override
  String get maintenanceMessage => 'Ex: Application under maintenance...';

  @override
  String get signInWithGoogle => 'Sign in with Google';

  @override
  String get loginButton => 'Login';

  @override
  String products(int count) {
    return 'Products ($count)';
  }

  @override
  String orders(int count) {
    return 'Orders ($count)';
  }

  @override
  String disputes(int count) {
    return 'Disputes ($count)';
  }

  @override
  String get sendButton => 'Send';

  @override
  String get emailAddress => 'Email address';

  @override
  String get emailPlaceholder => 'user@example.com';

  @override
  String get passwordLabel => 'Password';

  @override
  String get businessCreated => 'Business created successfully!';

  @override
  String get businessName => 'Business name *';

  @override
  String get telephone => 'Telephone';

  @override
  String get address => 'Address';

  @override
  String get offeredServices => 'Offered services';

  @override
  String get addService => 'Add a service';

  @override
  String get createBusiness => 'Create business';

  @override
  String get typeColon => 'Type:';

  @override
  String get durationColon => 'Duration:';

  @override
  String get totalColon => 'Total:';

  @override
  String get modifyReview => 'Modify';

  @override
  String get pleaseRate => 'Please rate';

  @override
  String get titleOptional => 'Title (optional)';

  @override
  String get titleExample => 'Ex: Excellent service';

  @override
  String get yourReview => 'Your review';

  @override
  String get shareExperience => 'Share your experience...';

  @override
  String get addButton => 'Add';

  @override
  String get imageLimitReached => 'Limit of 5 posters reached';

  @override
  String get photoLimitReached => 'Limit of 10 photos reached';

  @override
  String addPhotos(int current, int max) {
    return 'Add photos ($current/$max)';
  }

  @override
  String get requestSubmitted => 'Request submitted successfully!';

  @override
  String get exampleRequest => 'Ex: Inquiry about passport';

  @override
  String get describeRequest => 'Describe your request in detail...';

  @override
  String get searchCountry => 'Search for a country';

  @override
  String get typeCountryName => 'Type the country name';

  @override
  String get itinerary => 'Itinerary';

  @override
  String get promoteAdminTitle => 'Promote Admin';

  @override
  String get removeAdminTitle => 'Remove Admin';

  @override
  String get requestRefused => 'Request refused';

  @override
  String get refuse => 'Refuse';

  @override
  String get allLabel => 'All';

  @override
  String get allCategories => 'All';

  @override
  String get messagesLabel => 'Messages';

  @override
  String get groupsLabel => 'Groups';

  @override
  String get directory => 'Directory';

  @override
  String get activateButton => 'ACTIVATE';

  @override
  String get simpleMapTest => 'Simple Map Test';

  @override
  String get addImage => 'Add at least one image';

  @override
  String get customRate => 'Custom rate (%)';

  @override
  String get rateExample => 'Ex: 15';

  @override
  String tax(String rate) {
    return 'Tax ($rate%)';
  }

  @override
  String get titlePlaceholder => 'Ex: iPhone 13 Pro Max';

  @override
  String get descriptionPlaceholder => 'Describe your product...';

  @override
  String get quantity => 'Quantity';

  @override
  String get categoryLabel => 'Category';

  @override
  String get condition => 'Condition';

  @override
  String get cityAddress => 'City/Address (optional)';

  @override
  String get cityExample => 'Ex: Niamey';

  @override
  String get everything => 'Everything';

  @override
  String get published => 'published';

  @override
  String get pdfLabel => 'PDF';

  @override
  String get docLabel => 'DOC';

  @override
  String get xlsLabel => 'XLS';

  @override
  String get pptLabel => 'PPT';

  @override
  String get zipLabel => 'ZIP';

  @override
  String get txtLabel => 'TXT';

  @override
  String get csvLabel => 'CSV';

  @override
  String get jsonLabel => 'JSON';

  @override
  String get joinLabel => 'Join';

  @override
  String get remindLater => 'Remind me later';

  @override
  String get audioRoomsReminderSet => 'Reminder set — we\'ll notify you';

  @override
  String get audioRoomsStartingSoon => 'The room is starting';

  @override
  String get inOneHour => 'In 1 hour';

  @override
  String get exampleBank => 'Ex: BCEAO, Ecobank...';

  @override
  String get ibanExample => 'NEXX XXXX XXXX XXXX';

  @override
  String get categoryRequired => 'Category *';

  @override
  String get languageRequired => 'Language *';

  @override
  String get publicationFrequency => 'Publication frequency';

  @override
  String get addTag => 'Add a tag';

  @override
  String get likes => 'Likes';

  @override
  String get sleepTimerEnded => 'Sleep timer ended';

  @override
  String timerMinutes(int minutes) {
    return 'Timer: $minutes minutes';
  }

  @override
  String get episodeTitle => 'Episode title *';

  @override
  String get episodeDescription => 'Description / Notes';

  @override
  String get reservedForSubscribers => 'Reserved for paying subscribers';

  @override
  String get downloaded => 'Downloaded';

  @override
  String get selectPodcast => 'Select a podcast or create a new one';

  @override
  String get recordingAvailableSoon => 'The recording will be available soon';

  @override
  String get episodeTitlePlaceholder => 'Episode title';

  @override
  String get episodeDescriptionPlaceholder => 'Episode description (optional)';

  @override
  String codeSent(String phone) {
    return 'Code sent to $phone';
  }

  @override
  String get describeIssue => 'Describe the issue...';

  @override
  String get connectedDevicesTitle => 'Connected devices';

  @override
  String get backupKeys => 'Key backup';

  @override
  String get deleteBackupQuestion => 'Delete backup?';

  @override
  String get generateSecurePassphrase => 'Generate a secure passphrase';

  @override
  String get minimumChars => 'Minimum 8 characters';

  @override
  String get termsOfUse => 'Terms of use';

  @override
  String get bugDescriptionLabel => 'Bug description';

  @override
  String get bugDescriptionPlaceholder => 'Describe the issue encountered...';

  @override
  String get addRecipient => 'Add a recipient';

  @override
  String get newRecipient => 'New';

  @override
  String get deleteRecipientQuestion => 'Delete recipient?';

  @override
  String deleteRecipientConfirm(String name) {
    return 'Do you want to delete $name?';
  }

  @override
  String get deleteQuestion => 'Delete?';

  @override
  String get sendMoney => 'Send money';

  @override
  String deleteConfirm(String name) {
    return 'Delete $name?';
  }

  @override
  String get retryTransfer => 'Retry the transfer';

  @override
  String get contactSupport => 'Contact support';

  @override
  String get debitInProgress => 'Debit in progress';

  @override
  String get inProgress => 'In progress';

  @override
  String get sendingInProgress => 'Sending in progress';

  @override
  String get completed => 'Completed';

  @override
  String get failed => 'Failed';

  @override
  String get refundInProgress => 'Refund in progress';

  @override
  String get refunded => 'Refunded';

  @override
  String get cancelled => 'Cancelled';

  @override
  String get liveChat => 'Live chat';

  @override
  String get liveChatAvailable => 'Available 24/7';

  @override
  String get chatNotAvailable => 'Chat not available at the moment';

  @override
  String get sendMoneyButton => 'Send money';

  @override
  String applicationError(String error) {
    return 'Error during application: $error';
  }

  @override
  String helperText(String min, String max) {
    return 'Min: $min XOF - Max: $max XOF';
  }

  @override
  String get tales => 'Tales';

  @override
  String get proverbs => 'Proverbs';

  @override
  String get ceremonies => 'Ceremonies';

  @override
  String get craft => 'Craft';

  @override
  String get recipes => 'Recipes';

  @override
  String get medicine => 'Medicine';

  @override
  String get automatic => 'Automatic';

  @override
  String get exempt => 'Exempt';

  @override
  String get standardVAT => 'Standard VAT (19%)';

  @override
  String get reducedVAT => 'Reduced VAT (10%)';

  @override
  String get custom => 'Custom';

  @override
  String get typeYourResponse => 'Type your response...';

  @override
  String get forYouTab => 'For you';

  @override
  String get followingTab => 'Following';

  @override
  String get recentTab => 'Recent';

  @override
  String audioRoomsAvailableCount(int count) {
    return '$count rooms available';
  }

  @override
  String audioRoomsLiveTabLabel(int count) {
    return 'Live ($count)';
  }

  @override
  String audioRoomsScheduledTabLabel(int count) {
    return 'Scheduled ($count)';
  }

  @override
  String get audioRoomsNoLiveRooms => 'No live rooms';

  @override
  String get audioRoomsNoLiveSubtitle => 'Be the first to start';

  @override
  String get audioRoomsNoScheduledRooms => 'No scheduled rooms';

  @override
  String get audioRoomsNoScheduledSubtitle => 'Plan a session';

  @override
  String audioRoomsLiveListeners(int count) {
    return 'LIVE · $count listeners';
  }

  @override
  String audioRoomsRegisteredCount(int count) {
    return '$count registered';
  }

  @override
  String get audioRoomsScheduleButton => 'Schedule';

  @override
  String get audioRoomConnecting => 'Connecting...';

  @override
  String get audioRoomDefaultTitle => 'Audio room';

  @override
  String audioRoomParticipantsOnStage(int count, int max) {
    return 'On stage · $count/$max';
  }

  @override
  String audioRoomListenersCount(int count) {
    return 'Listeners · $count';
  }

  @override
  String audioRoomHandsRaisedSection(int count) {
    return 'Hands raised · $count';
  }

  @override
  String get audioRoomEndConfirmTitle => 'End the room?';

  @override
  String get audioRoomEndConfirmMessage =>
      'All participants will be disconnected.';

  @override
  String get audioRoomGhostMode => 'Ghost mode · invisible admin';

  @override
  String get audioRoomSuperAdmin => 'SuperAdmin';

  @override
  String get audioRoomModerators => 'Moderators';

  @override
  String get audioRoomMuteLabel => 'Muted';

  @override
  String get audioRoomActiveLabel => 'Active';

  @override
  String get audioRoomStatsLabel => 'Stats';

  @override
  String get audioRoomCameraLabel => 'Camera';

  @override
  String get audioRoomHandLabel => 'Hand';

  @override
  String get audioRoomGoDownLabel => 'Go down';

  @override
  String get audioRoomTipLabel => 'Tip';

  @override
  String get audioRoomShareLabel => 'Share';

  @override
  String get audioRoomLeaveLabel => 'Leave';

  @override
  String get audioRoomEndLabel => 'End';

  @override
  String get audioRoomInviteLabel => 'Invite';

  @override
  String get audioRoomCoHostLabel => 'Co-host';

  @override
  String get audioRoomMuteAction => 'Mute';

  @override
  String get audioRoomKickLabel => 'Kick';

  @override
  String get audioRoomBlockLabel => 'Block';

  @override
  String get audioRoomWarnLabel => 'Warn';

  @override
  String get cannotLaunchPhoneDialer => 'Cannot launch phone dialer';

  @override
  String get cannotLaunchEmailClient => 'Cannot launch email client';

  @override
  String get cannotOpenWebsite => 'Cannot open website';

  @override
  String get cannotOpenMaps => 'Cannot open maps';

  @override
  String get liveMicLabel => 'Mic';

  @override
  String get liveMicMuted => 'Mic off';

  @override
  String get liveCameraLabel => 'Camera';

  @override
  String get liveCameraOff => 'Camera off';

  @override
  String get liveEndLabel => 'End';

  @override
  String get liveStartBroadcast => 'Start live';

  @override
  String get liveConnecting => 'Connecting...';

  @override
  String get searchForGroupLabel => 'Search a group';

  @override
  String get searchForDiscussionLabel => 'Search a discussion';

  @override
  String get searchForFriendLabel => 'Search a friend';

  @override
  String get searchForMemberLabel => 'Search a member';

  @override
  String get searchLabel => 'Search';

  @override
  String get searchDiscussionHint => 'Search a discussion...';

  @override
  String get searchFriendHint => 'Search a friend...';

  @override
  String get searchMembersOrGroupsHint => 'Search members or groups...';

  @override
  String get searchMembersOrGroupsPrompt => 'Search members or groups';

  @override
  String get membersSection => 'Members';

  @override
  String get groupsSection => 'Groups';

  @override
  String get conversationsSection => 'Conversations';

  @override
  String get memberDefault => 'Member';

  @override
  String get friendLabel => 'Friend';

  @override
  String get conversationDefault => 'Conversation';

  @override
  String get adminConfirmDisconnect => 'Confirm disconnection';

  @override
  String adminDisconnectDevicesConfirm(String userName) {
    return 'Do you really want to disconnect $userName from all their devices?';
  }

  @override
  String get adminNotConnectedError => 'Error: Admin not connected';

  @override
  String get adminUsersTitle => 'User Management';

  @override
  String get adminUsersDesc => 'Manage user accounts and sessions';

  @override
  String get neverConnected => 'Never';

  @override
  String get noEmail => 'No email';

  @override
  String get adminRoleLabel => 'Admin';

  @override
  String get bannedLabel => 'Banned';

  @override
  String get userDefault => 'User';

  @override
  String get adminForceDisconnect => 'Force disconnect';

  @override
  String get loadingUsers => 'Loading users...';

  @override
  String get noUsersFound => 'No users found';

  @override
  String get adminTaxRatesTitle => 'VAT rates by category';

  @override
  String get adminTaxRatesDesc =>
      'Define the rates applicable to each category';

  @override
  String get adminImagesTitle => 'Images';

  @override
  String get adminImagesDesc => 'Image upload configuration';

  @override
  String get adminImagesDimensionHint => 'Max width and height';

  @override
  String get adminVideosTitle => 'Videos';

  @override
  String get adminVideosDesc => 'Limits for videos';

  @override
  String get adminMessagesTitle => 'Messages';

  @override
  String get adminMessagesDesc => 'Message configuration';

  @override
  String adminMaxValueConstraint(int max) {
    return 'Max: $max';
  }

  @override
  String get adminUrlsAndContactTitle => 'URLs & Contact';

  @override
  String get adminUrlsAndContactDesc => 'Links and emails configuration';

  @override
  String get adminIntervalsTitle => 'System intervals';

  @override
  String get adminIntervalsDesc => 'Update frequencies';

  @override
  String get audioRoomForceCloseTitle => 'Force close?';

  @override
  String get audioRoomForceButton => 'Force';

  @override
  String get scheduleRoomTitle => 'Schedule';

  @override
  String get scheduleRoomMultiTimezone => 'multi-timezone';

  @override
  String get scheduleNewRoomLabel => 'New room';

  @override
  String get errorLoadingStickers => 'Error loading stickers';

  @override
  String get noRecentStickers => 'No recent stickers';

  @override
  String get errorLoadingRecentStickers => 'Error loading recent stickers';

  @override
  String get noFavoriteStickers => 'No favorite stickers';

  @override
  String get addToFavoritesHint => 'Long press to add favorites';

  @override
  String get errorLoadingFavorites => 'Error loading favorites';

  @override
  String get noStickersInPack => 'No stickers in this pack';

  @override
  String get addToFavorites => 'Add to favorites';

  @override
  String get audioRoomForceCloseLabel => 'Force close';

  @override
  String get audioRoomForceCloseDesc =>
      'The room will be immediately closed and the action will be audited.';

  @override
  String get audioRoomForceCloseAuditNote => 'Irreversible action · audit log';

  @override
  String get ghostListeners => 'visible listeners';

  @override
  String get ghostSpeakers => 'visible speakers';

  @override
  String get ghostReports => 'Reports';

  @override
  String get ghostDuration => 'Duration';

  @override
  String get creatorEarningsTitle => 'My Earnings';

  @override
  String get withdrawalRequestTitle => 'Withdrawal request';

  @override
  String get withdrawalAmountLabel => 'Amount to withdraw';

  @override
  String get tipEarningsLabel => 'Tips';

  @override
  String get ticketEarningsLabel => 'Room tickets';

  @override
  String get subscriptionEarningsLabel => 'Subscriptions';

  @override
  String get replayEarningsLabel => 'Replays';

  @override
  String get totalLabel => 'Total';

  @override
  String get stripeDashboardButton => 'Stripe dashboard';

  @override
  String get audioRoomVideoEnabled => 'Video enabled';

  @override
  String get audioRoomTicketPriceField => 'Ticket price (€)';

  @override
  String get audioRoomEnableFundraising => 'Enable fundraising';

  @override
  String get audioRoomFundraisingGoal => 'Goal (€)';

  @override
  String get audioRoomBeneficiary => 'Beneficiary';

  @override
  String get audioRoomLinkedTo => 'Linked to';

  @override
  String get audioRoomEmbassyLink => 'Embassy';

  @override
  String get selectVideoFirst => 'Please select a video';

  @override
  String get subscribeButton => 'Subscribe';

  @override
  String get previewTooltip => 'Preview';

  @override
  String get subscriptionActivated => 'Subscription activated!';

  @override
  String get liveBadge => 'LIVE';

  @override
  String get chaptersPill => 'Chapters';

  @override
  String get replayBadge => 'REPLAY';

  @override
  String get sleepTimer => 'Sleep timer';

  @override
  String get sleepTimerOff => 'Off';

  @override
  String get saveAsPodcastTitle => 'Save as podcast';

  @override
  String get saveAsPodcastSubtitle => 'post-production';

  @override
  String get postPublicationTips => 'Post-publication tips';

  @override
  String get keepPrivate => 'Keep private';

  @override
  String get paidRoomBadge => 'PAID ROOM';

  @override
  String get verifiedHostBadge => 'verified host';

  @override
  String get hostShareLabel => 'Paid to host';

  @override
  String get paymentMethodLabel => 'PAYMENT METHOD';

  @override
  String get optionalMessageHint => 'Message (optional)…';

  @override
  String get creditCardMethod => 'Credit card (Stripe)';

  @override
  String get creditCardBrands => 'Visa, Mastercard, Apple Pay, Google Pay';

  @override
  String get mobileMoneyMethod => 'Mobile Money';

  @override
  String get mobileMoneyBrands => 'Mynita, Wave (coming soon)';

  @override
  String get ceremonyRoomLabel => 'Ceremony · Extended family broadcast';

  @override
  String get moderatorInitialLabel => 'M';

  @override
  String get timezonesLabel => 'TIMEZONES';

  @override
  String get niamieyTimezoneLabel => 'GMT+1 · Niamey';

  @override
  String get kenteMotifAuto => 'Kente pattern auto-generated';

  @override
  String get autoLabel => 'AUTO';

  @override
  String get laterButton => 'Later';

  @override
  String get bankNameHint => 'Ex: BCEAO, Ecobank...';

  @override
  String get ibanHint => 'NEXX XXXX XXXX XXXX';

  @override
  String get adTransferTitle => 'Send money to Niger';

  @override
  String get adTransferSubtitle =>
      'Fast and secure transfers to your loved ones';

  @override
  String get adTransferCta => 'Send now';

  @override
  String get adGroupTitle => 'Join a diaspora group';

  @override
  String get adGroupSubtitle => 'Connect with Nigeriens near you';

  @override
  String get adGroupCta => 'Discover groups';

  @override
  String get adMarketplaceTitle => 'Diaspo Niger Marketplace';

  @override
  String get adMarketplaceSubtitle => 'Buy and sell within the community';

  @override
  String get adMarketplaceCta => 'Explore the market';

  @override
  String get adAudioRoomsTitle => 'Live audio rooms';

  @override
  String get adAudioRoomsSubtitle => 'Join real-time discussions';

  @override
  String get adAudioRoomsCta => 'View rooms';

  @override
  String get notifGroupOrders => 'Orders';

  @override
  String get notifGroupProximity => 'Proximity alerts';

  @override
  String get notifGroupCalls => 'Calls';

  @override
  String get notifGroupAudioRooms => 'Audio rooms';

  @override
  String get notifGroupPodcasts => 'Podcasts';

  @override
  String get notifGroupTransfers => 'Transfers';

  @override
  String get notifGroupAll => 'Notifications';

  @override
  String notifNewMessagesCount(int count) {
    return '$count new messages';
  }

  @override
  String notifMessagesFrom(int count, int conversations) {
    return '$count messages from $conversations conversations';
  }

  @override
  String notifFriendRequestsCount(int count) {
    return '$count friend requests';
  }

  @override
  String get notifNow => 'now';

  @override
  String get imageSaved => 'Image saved';

  @override
  String get saveFailed => 'Save failed';

  @override
  String get videoSaved => 'Video saved';

  @override
  String embassiesFoundCount(int count) {
    return '$count embassy(ies) found';
  }

  @override
  String get embassiesHelperText =>
      'Available embassies and consulates will appear here.';

  @override
  String get startNowLabel => 'Start now';

  @override
  String recipientReceives(String name) {
    return '$name receives';
  }

  @override
  String get sendTipYouSend => 'You send';

  @override
  String get sendTipShownInRoomNote =>
      'Your tip appears in the room with your name.';

  @override
  String get ticketPaymentMethodCard => 'Bank card';

  @override
  String get ticketPinRequired => 'PIN code required to confirm';

  @override
  String get ticketReplayAccessNote =>
      'The ticket gives access to the room and its replay.';

  @override
  String ticketBuyAndJoin(String amount) {
    return 'Pay $amount and join';
  }

  @override
  String get configCompleteLabel => 'complete configuration';

  @override
  String get familyEventLabel => 'Family event';

  @override
  String get eventLabel => 'Event';

  @override
  String get sessionRecorded => 'Recorded session';

  @override
  String get incompleteStripeConfig =>
      'Incomplete configuration. Complete your Stripe profile.';

  @override
  String get userNotLoggedIn => 'User not logged in';

  @override
  String get adminBanUserTitle => 'Ban user';

  @override
  String get adminBanReasonLabel => 'Reason for ban:';

  @override
  String get adminUserBanned => 'User banned';

  @override
  String get adminUnbanUserTitle => 'Unban user';

  @override
  String get adminUnbanConfirm => 'Are you sure you want to unban this user?';

  @override
  String get adminUserUnbanned => 'User unbanned';

  @override
  String get adminPromoteToAdminTitle => 'Promote to admin';

  @override
  String get adminPromoteConfirm =>
      'Are you sure you want to promote this user to administrator?';

  @override
  String get adminUserPromoted => 'User promoted to admin';

  @override
  String get adminRevokeAdminTitle => 'Remove admin rights';

  @override
  String get adminRevokeAdminConfirm =>
      'Are you sure you want to remove administrator rights?';

  @override
  String get adminAdminRightsRevoked => 'Admin rights removed';

  @override
  String get adminCertifyUserTitle => 'Certify user';

  @override
  String adminCertifyConfirm(String name) {
    return 'Grant certification to $name?';
  }

  @override
  String get adminUserCertified => 'User certified';

  @override
  String get adminRevokeCertTitle => 'Revoke certification';

  @override
  String adminRevokeCertConfirm(String name) {
    return 'Remove certification from $name?';
  }

  @override
  String get adminCertRevoked => 'Certification revoked';

  @override
  String get adminForceDisconnectConfirm =>
      'This will disconnect the user from all their devices.';

  @override
  String get adminUserDisconnected => 'User disconnected';

  @override
  String adminDisconnectedSuccess(String name) {
    return '$name has been disconnected.';
  }

  @override
  String get adminBusinessVerified => 'Business verified';

  @override
  String get adminVerificationRemoved => 'Verification removed';

  @override
  String get adminBusinessBoosted => 'Business boosted for 30 days';

  @override
  String get adminBoostRemoved => 'Boost removed';

  @override
  String get adminDeleteBusinessTitle => 'Delete business';

  @override
  String get adminDeleteBusinessConfirm =>
      'Are you sure you want to delete this business? This action is irreversible.';

  @override
  String get adminBusinessDeleted => 'Business deleted';

  @override
  String get adminProductActivated => 'Product activated';

  @override
  String get adminProductDeactivated => 'Product deactivated';

  @override
  String get adminDeleteProductTitle => 'Delete product';

  @override
  String get adminDeleteProductConfirm =>
      'Are you sure you want to delete this product?';

  @override
  String get adminProductDeleted => 'Product deleted';

  @override
  String get adminResolveDisputeTitle => 'Resolve dispute';

  @override
  String get adminDisputeResolved => 'Dispute resolved';

  @override
  String get adminCancelEventConfirm =>
      'Are you sure you want to cancel this event?';

  @override
  String get adminDeleteEventConfirm =>
      'Are you sure you want to delete this event? This action is irreversible.';

  @override
  String get adminDeleteGroupTitle => 'Delete group';

  @override
  String get adminDeleteGroupConfirm =>
      'Are you sure you want to delete this group? This action is irreversible.';

  @override
  String get adminTransactionFailReasonLabel => 'Failure reason:';

  @override
  String get adminTransactionFailed => 'Transaction marked as failed';

  @override
  String get adminMarkCompleteTitle => 'Mark as completed';

  @override
  String get adminMarkCompleteConfirm =>
      'Are you sure you want to mark this transaction as completed?';

  @override
  String get adminTransactionCompleted => 'Transaction completed';

  @override
  String get adminRefundReasonLabel => 'Refund reason:';

  @override
  String get adminTransactionRefunded => 'Transaction refunded';

  @override
  String get adminUnknownAdmin => 'Unknown admin';

  @override
  String get adminUnknownDate => 'Unknown date';

  @override
  String adminEventByOrganizer(String id) {
    return 'Event by $id';
  }

  @override
  String adminEventsTab(int count) {
    return 'Events ($count)';
  }

  @override
  String get adminAvailable => 'Available';

  @override
  String get adminUnavailable => 'Unavailable';

  @override
  String get adminNoOrders => 'No orders found';

  @override
  String get adminNoDisputes => 'No ongoing disputes';

  @override
  String adminDisputeId(String id) {
    return 'Dispute #$id';
  }

  @override
  String adminDisputeReasonLabel(String reason) {
    return 'Reason: $reason';
  }

  @override
  String get adminReasonUnspecified => 'Unspecified';

  @override
  String get adminAmountHeader => 'Amount';

  @override
  String get adminAmountXofHeader => 'Amount in XOF';

  @override
  String get adminFailReasonHeader => 'Failure reason';

  @override
  String get adminTipAmountXof => 'Tip amounts (XOF)';

  @override
  String get adminRoomLimitsTitle => 'Room limits';

  @override
  String get adminRoomLimitsSubtitle => 'Maximum capacity and duration';

  @override
  String get adminMaxDurationLabel => 'Max duration (minutes)';

  @override
  String get adminPredefinedTipsTitle => 'Predefined tip amounts';

  @override
  String get adminPredefinedTipsSubtitle =>
      'Separated by comma (in units, not cents)';

  @override
  String get wifiAndMobileData => 'WiFi and mobile data';

  @override
  String get wifiOnly => 'WiFi only';

  @override
  String get autoDownloads => 'Automatic downloads';

  @override
  String get passphraseMinLength =>
      'Passphrase must contain at least 8 characters';

  @override
  String get backupCreatedSuccess => 'Backup created successfully';

  @override
  String backupCreateError(String error) {
    return 'Error creating backup: $error';
  }

  @override
  String get keysRestoredSuccess => 'Keys restored successfully';

  @override
  String backupCreatedOn(String date) {
    return 'Created on: $date';
  }

  @override
  String get passphraseRequiredNote =>
      'Without it, your keys cannot be restored.';

  @override
  String minTipAmountError(int amount, String currency) {
    return 'Minimum amount: $amount $currency';
  }

  @override
  String maxTipAmountError(int amount, String currency) {
    return 'Maximum amount: $amount $currency';
  }

  @override
  String get ghostSuperAdminBadge => 'GHOST · SuperAdmin';

  @override
  String get ghostInvisibleNotice =>
      'You are invisible: neither the host nor the participants can see you. Every action you take is logged.';

  @override
  String get ghostActionsTitle => 'GHOST ACTIONS';

  @override
  String get ghostMuteSilent => 'Silent mute';

  @override
  String get ghostExclude => 'Exclude';

  @override
  String get ghostBlockGlobal => 'Block globally';

  @override
  String get ghostPickParticipantTitle => 'Pick a participant';

  @override
  String get ghostNoParticipants => 'No participant to moderate';

  @override
  String ghostActionMuted(String name) {
    return '$name is now muted';
  }

  @override
  String ghostActionKicked(String name) {
    return '$name was removed from the room';
  }

  @override
  String ghostActionBlocked(String name) {
    return '$name was blocked';
  }

  @override
  String get audioRoomCapacityNote => '10 speakers · 1,000 listeners';

  @override
  String get audioRoomAdminLockNote =>
      '🔒 Features subject to administrator rules.';

  @override
  String get payoutHistoryTitle => 'Payout history';

  @override
  String get noWithdrawalsYet => 'No withdrawals made yet';

  @override
  String get availableBalance => 'Available balance';

  @override
  String get processingEllipsis => 'Processing…';

  @override
  String get withdrawEarnings => 'Withdraw earnings';

  @override
  String get stripeConnectRequired =>
      'Set up Stripe Connect to enable withdrawals.';

  @override
  String get earningsBreakdown => 'Earnings breakdown';

  @override
  String get stripeConnectAccount => 'Stripe Connect account';

  @override
  String get stripeAccountActive =>
      'Your account is active. Withdrawals are available.';

  @override
  String get createStripePrompt =>
      'Create a Stripe Connect account to receive your payments.';

  @override
  String get continueSetupButton => 'Continue setup';

  @override
  String get createStripeButton => 'Create Stripe account';

  @override
  String get podcastCoverLabel => 'Cover';

  @override
  String get podcastVisibilityLabel => 'Visibility';

  @override
  String get podcastFollowersVisibility => 'Followers';

  @override
  String get podcastPrivateVisibility => 'Private';

  @override
  String get podcastVideoEpisodeLabel => 'Video episode';

  @override
  String get podcastVideoProcessing => 'Video processing…';

  @override
  String get podcastEpisodeTitleLabel => 'Episode title';

  @override
  String get podcastAiChaptersLabel => 'AI-detected chapters';

  @override
  String get scheduleRoomCaveat =>
      'Displayed to each member in their local timezone during the reminder.';

  @override
  String get filesLabel => 'Files';

  @override
  String get embassyFormIntro =>
      'Fill in this form to create a new embassy. The request will be verified before publication.';

  @override
  String get embassyBasicInfoSection => 'Basic information';

  @override
  String get embassySelectType => 'Select establishment type';

  @override
  String get embassyTypeEmbassy => 'Embassy';

  @override
  String get embassyTypeConsulate => 'Consulate';

  @override
  String get embassyTypeMission => 'Diplomatic mission';

  @override
  String get embassyTypeDelegation => 'Delegation';

  @override
  String get embassyNameField => 'Name *';

  @override
  String get embassyCountryField => 'Host country *';

  @override
  String get embassyCityField => 'City *';

  @override
  String get embassyAddressField => 'Full address *';

  @override
  String get embassyNameRequired => 'Name is required';

  @override
  String get embassyCountryRequired => 'Country is required';

  @override
  String get embassyCityRequired => 'City is required';

  @override
  String get embassyAddressRequired => 'Address is required';

  @override
  String get embassyLocationSection => 'GPS location (optional)';

  @override
  String get embassyServicesSection => 'Services offered';

  @override
  String get embassyJurisdictionSection => 'Countries under jurisdiction';

  @override
  String get embassyJurisdictionDesc =>
      'Indicate the countries whose nationals can contact this embassy.';

  @override
  String get embassyAddCountry => 'Add a country';

  @override
  String get embassyHoursSection => 'Opening hours';

  @override
  String get embassyHoursHint => 'Ex: 09:00 - 17:00 or Closed';

  @override
  String get embassyCreateButton => 'Create embassy';

  @override
  String get emailInvalidError => 'Invalid email';

  @override
  String get adminDemoted => 'Demoted';

  @override
  String get adminPrivacyChanged => 'Privacy changed';

  @override
  String get adminReportResolved => 'Report resolved';

  @override
  String get adminAvailabilityChanged => 'Availability changed';

  @override
  String get adminConfigUpdated => 'Configuration updated';

  @override
  String get adminFeatureChanged => 'Feature changed';

  @override
  String get adminNotificationSent => 'Notification sent';

  @override
  String get adminForceLogoutAction => 'Forced logout';

  @override
  String get adminAuditEmptyState => 'Administrator actions will appear here';

  @override
  String get adminDetailsLabel => 'Details:';

  @override
  String get adminTransferMonitoringTitle => 'Transfer Monitoring';

  @override
  String get adminTransferMonitoringSubtitle =>
      'Real-time transaction and volume tracking';

  @override
  String get adminTransferVolume => 'Transfer Volume';

  @override
  String get adminByCurrency => 'Details by Currency';

  @override
  String get adminTotalVolumeUSD => 'Total Volume (USD)';

  @override
  String get adminFeesCollectedUSD => 'Fees Collected (USD)';

  @override
  String adminFailedTab(int count) {
    return 'Failed ($count)';
  }

  @override
  String adminCompletedTab(int count) {
    return 'Completed ($count)';
  }

  @override
  String adminProcessedTab(int count) {
    return 'Processed ($count)';
  }

  @override
  String adminAdminsTab(int count) {
    return 'Admins ($count)';
  }

  @override
  String adminBannedTab(int count) {
    return 'Banned ($count)';
  }

  @override
  String adminActiveTab(int count) {
    return 'Active ($count)';
  }

  @override
  String adminSuspendedTab(int count) {
    return 'Suspended ($count)';
  }

  @override
  String get adminMarkFailedAction => 'Fail';

  @override
  String get adminMarkAsFailedTitle => 'Mark as failed';

  @override
  String get adminTransactionDebiting => 'Debiting';

  @override
  String get adminTransactionInProgress => 'In progress';

  @override
  String get adminTransactionSending => 'Sending';

  @override
  String get adminTransactionCompletedLabel => 'Completed';

  @override
  String get adminTransactionRefunding => 'Refunding';

  @override
  String get adminActiveLabel => 'Active';

  @override
  String get adminSuspendedLabel => 'Suspended';

  @override
  String get adminSuspendedStatus => 'Suspended';

  @override
  String get adminVerifiedStatus => 'Verified';

  @override
  String get adminNoEmbassyPending => 'No embassy pending verification';

  @override
  String get adminNoEmbassyActive => 'No active embassy';

  @override
  String get adminNoEmbassySuspended => 'No suspended embassy';

  @override
  String get adminNoEmbassy => 'No embassy';

  @override
  String get adminLoadingEmbassies => 'Loading embassies...';

  @override
  String get adminLoadError => 'Loading error';

  @override
  String get adminUsersManagementTitle => 'User Management';

  @override
  String get adminUsersManagementSubtitle =>
      'Manage accounts, permissions and bans';

  @override
  String get adminNoName => 'No name';

  @override
  String get adminNoEmail => 'No email';

  @override
  String adminLastLogin(String date) {
    return 'Last login: $date';
  }

  @override
  String adminBanReason(String reason) {
    return 'Reason: $reason';
  }

  @override
  String get adminCertifiedBadge => 'CERTIFIED';

  @override
  String get adminAdminBadge => 'ADMIN';

  @override
  String get adminBannedBadge => 'BANNED';

  @override
  String get adminFeaturesToggleSubtitle => 'Enable/disable options';

  @override
  String get adminActiveRoomsFeature => 'Active audio rooms';

  @override
  String get adminPaidRoomsFeature => 'Paid rooms';

  @override
  String get adminTipsFeature => 'Tips';

  @override
  String get adminPaidReplaysFeature => 'Paid replays';

  @override
  String get adminCreatorSubscriptionsFeature => 'Creator subscriptions';

  @override
  String get adminRecordingFeature => 'Recording';

  @override
  String get adminCommissionsTitle => 'Commissions';

  @override
  String get adminCommissionsSubtitle => 'Percentage taken by the platform';

  @override
  String get adminTicketsLabel => 'Tickets';

  @override
  String get adminTipsLabel => 'Tips';

  @override
  String get adminReplaysLabel => 'Replays';

  @override
  String get adminSubscriptionsLabel => 'Subscriptions';

  @override
  String get adminPriceLimitsTitle => 'Price limits';

  @override
  String get adminPriceLimitsSubtitle => 'Min/Max for transactions';

  @override
  String get adminMinLabel => 'Min';

  @override
  String get adminMaxLabel => 'Max';

  @override
  String get adminMaxSpeakersLabel => 'Max speakers';

  @override
  String get adminMaxListenersLabel => 'Max listeners';

  @override
  String get stickerLoadError => 'Error loading stickers';

  @override
  String get stickerNoRecent => 'No recent stickers';

  @override
  String get stickerRecentLoadError => 'Error loading recent stickers';

  @override
  String get stickerNoFavorites => 'No favorite stickers';

  @override
  String get stickerAddFavoritesHint =>
      'Long press a sticker to add to favorites';

  @override
  String get stickerFavoritesLoadError => 'Error loading favorites';

  @override
  String get stickerPackEmpty => 'No stickers in this pack';

  @override
  String priceConvertedFrom(String currency) {
    return 'Converted from $currency';
  }

  @override
  String get onboardingWelcomeTitle => 'Welcome to\nDiaspo Niger';

  @override
  String get onboardingWelcomeDesc =>
      'Connect with the Nigerien diaspora around the world. Find your compatriots and share together.';

  @override
  String get onboardingDiscoverTitle => 'Discover members';

  @override
  String get onboardingDiscoverDesc =>
      'Find Nigeriens near you with our interactive map. See who lives in your region.';

  @override
  String get onboardingGroupsTitle => 'Join groups';

  @override
  String get onboardingGroupsDesc =>
      'Join thematic communities: professionals, students, entrepreneurs... Exchange and support each other.';

  @override
  String get onboardingEventsTitle => 'Participate in events';

  @override
  String get onboardingEventsDesc =>
      'Organize or join meetings, conferences and cultural activities of the diaspora.';

  @override
  String get onboardingConnectedTitle => 'Stay connected';

  @override
  String get onboardingConnectedDesc =>
      'Chat privately with community members. Build lasting connections with the diaspora.';

  @override
  String get adminAudioLiveSection => 'Live Audio Rooms';

  @override
  String get adminAudioLiveSectionDesc =>
      'Monitor and moderate live audio rooms';

  @override
  String get adminMustBeConnected => 'You must be connected to save';

  @override
  String get adminMaintenanceMode => 'Maintenance Mode';

  @override
  String get adminMaintenanceActive => 'Application under maintenance';

  @override
  String get adminMaintenanceInactive => 'Application active';

  @override
  String get adminMaintenanceWarning =>
      'The application will be inaccessible to all non-admin users!';

  @override
  String get adminFeaturesSubtitle => 'Enable or disable modules';

  @override
  String get featureMoneyTransfer => 'Money transfer';

  @override
  String get featureMoneyTransferDesc => 'Send money to Niger';

  @override
  String get featureMarketplaceDesc => 'Buy and sell products';

  @override
  String get featureBusinessDirectory => 'Business directory';

  @override
  String get featureBusinessDirectoryDesc => 'Directory of Nigerien businesses';

  @override
  String get featureEventsDesc => 'Create and participate in events';

  @override
  String get featureGroupsDesc => 'Create and manage groups';

  @override
  String get featureEmbassiesDesc => 'Consular services and embassies';

  @override
  String get featureAudioRoomsDesc => 'Live voice rooms and replays';

  @override
  String get featurePodcasts => 'Podcasts';

  @override
  String get featurePodcastsDesc => 'Listen and create podcasts';

  @override
  String get settingsImagesLabel => 'Images';

  @override
  String get manualDownload => 'Manual (ask)';

  @override
  String get reportMessageTitle => 'Report message';

  @override
  String get reportMessageSubtitle => 'Report this message to administrators';

  @override
  String get reportMotifLabel => 'Reason for report:';

  @override
  String get violenceThreats => 'Violence or threats';

  @override
  String get disable => 'Disable';

  @override
  String get noProductFound => 'No product found';

  @override
  String get comingSoonShort => 'Coming soon';

  @override
  String get loadingReports => 'Loading reports...';

  @override
  String get noReports => 'No reports';

  @override
  String get noSearchResultsForFilter => 'No results for this search';

  @override
  String get notVerifiedLabel => 'Not verified';

  @override
  String get deleteContentConfirmTitle =>
      'Are you sure you want to delete this content?';

  @override
  String deleteContentIrreversibleDesc(String type) {
    return 'This action is irreversible and will permanently delete the $type.';
  }

  @override
  String get reportTypeConversation => 'Conversation';

  @override
  String get reportTypeEvent => 'Event';

  @override
  String get reportTypeGroup => 'Group';

  @override
  String get reportTypeBusiness => 'Business';

  @override
  String get reportTypeProduct => 'Product';

  @override
  String get categoryFood => 'Food';

  @override
  String get categoryCrafts => 'Crafts';

  @override
  String get categoryElectronics => 'Electronics';

  @override
  String get categoryClothing => 'Clothing';

  @override
  String get categoryRealEstate => 'Real estate';

  @override
  String get categoryOther => 'Other (standard)';

  @override
  String get callDeleteError => 'Error during deletion';

  @override
  String typingOneName(String name) {
    return '$name is typing...';
  }

  @override
  String typingTwoNames(String name1, String name2) {
    return '$name1 and $name2 are typing...';
  }

  @override
  String typingManyNames(String name, int count) {
    return '$name and $count others are typing...';
  }

  @override
  String get typingSomeone => 'Someone is typing...';

  @override
  String typingManyPeople(int count) {
    return '$count people are typing...';
  }

  @override
  String get messageTypePhoto => '📷 Photo';

  @override
  String get messageTypeVideo => '🎥 Video';

  @override
  String get messageTypeFile => '📄 Document';

  @override
  String get messageTypeCall => '📞 Call';

  @override
  String get messageTypeLocation => '📍 Location';

  @override
  String get messageTypeSticker => '🎭 Sticker';

  @override
  String reportContentTitle(String target) {
    return 'Report $target';
  }

  @override
  String get reportTargetUser => 'this user';

  @override
  String get reportTargetMessage => 'this message';

  @override
  String get reportTargetConversation => 'this conversation';

  @override
  String get reportTargetGroup => 'this group';

  @override
  String get reportTargetEvent => 'this event';

  @override
  String get reportTargetBusiness => 'this business';

  @override
  String get reportTargetProduct => 'this product';

  @override
  String get reportSentThanks => 'Report sent. Thank you for your help.';

  @override
  String get reportSendFailed => 'Error sending report';

  @override
  String get reportAlreadyReportedInfo =>
      'You have already reported this content. Our team is reviewing your report.';

  @override
  String get reportWhyQuestion => 'Why are you reporting this content?';

  @override
  String get reportExtraDetails => 'Additional details (optional)';

  @override
  String get reportedContentLabel => 'Reported content';

  @override
  String get reportInfoText =>
      'Reports are reviewed by our moderation team. Repeated false reports may result in sanctions.';

  @override
  String get reportReasonSpam => 'Spam';

  @override
  String get reportReasonHarassment => 'Harassment';

  @override
  String get reportReasonInappropriate => 'Inappropriate content';

  @override
  String get reportReasonViolence => 'Violence';

  @override
  String get reportReasonHateSpeech => 'Hate speech';

  @override
  String get reportReasonScam => 'Scam';

  @override
  String get reportReasonImpersonation => 'Identity theft';

  @override
  String get reportReasonOther => 'Other';

  @override
  String get maintenanceInProgress => 'Maintenance in progress';

  @override
  String get maintenanceDefaultMessage =>
      'The application is temporarily unavailable for maintenance. Please try again later.';

  @override
  String get maintenanceImprovingExperience =>
      'We are working to improve your experience.';

  @override
  String get phoneVerifTitle => 'Phone number verification';

  @override
  String phoneVerifEnterCodeHint(String phone) {
    return 'Enter the code sent to\n$phone';
  }

  @override
  String phoneVerifSendCodeHint(String phone) {
    return 'We will send a verification code to\n$phone';
  }

  @override
  String get sendCode => 'Send code';

  @override
  String get verify => 'Verify';

  @override
  String get resendCode => 'Resend code';

  @override
  String resendCodeIn(int seconds) {
    return 'Resend in ${seconds}s';
  }

  @override
  String get phoneVerifSendError => 'Error sending code';

  @override
  String get phoneVerifEnterComplete => 'Please enter the complete code';

  @override
  String get phoneVerifResendRequired =>
      'Verification error. Please resend the code.';

  @override
  String get phoneVerifUserNotLoggedIn => 'Error: user not logged in';

  @override
  String get phoneVerifInvalidCode => 'Invalid code';

  @override
  String get phoneVerifError => 'Verification error';

  @override
  String get phoneVerifInvalidNumber => 'Invalid phone number';

  @override
  String get phoneVerifTooManyAttempts => 'Too many attempts. Try again later';

  @override
  String get phoneVerifQuotaExceeded => 'Quota exceeded. Try again later';

  @override
  String get phoneVerifNetworkError => 'Network error. Check your connection';

  @override
  String get searchUsers => 'Search users';

  @override
  String get inviteMember => 'Invite a member';

  @override
  String get inviteSent => 'Invitation sent!';

  @override
  String get inviteAlreadySent => 'Already invited';

  @override
  String get inviteError => 'Invitation error';

  @override
  String get receivedGroupInvitations => 'Group invitations';

  @override
  String invitedByName(String name) {
    return 'Invited by $name';
  }

  @override
  String get noInvitationsReceived => 'No pending invitations';

  @override
  String get myQrCode => 'My QR Code';

  @override
  String get scanMode => 'Scan';

  @override
  String get shareMyQr => 'Share my QR';

  @override
  String get myPostsTitle => 'My posts';

  @override
  String get myPostsEmpty => 'You haven\'t published anything yet';

  @override
  String get savedPostsTitle => 'Saved posts';

  @override
  String get savedPostsEmpty => 'You haven\'t saved any posts yet';

  @override
  String savedPostsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count saved',
      one: '1 saved',
      zero: 'none saved',
    );
    return '$_temp0';
  }

  @override
  String get savedPostsCountLabel => 'saved';

  @override
  String get exploreFeed => 'Explore the feed';

  @override
  String get videos => 'Videos';

  @override
  String get texts => 'Text';

  @override
  String get myPostsEmptyTitle => 'Your first post\nawaits';

  @override
  String get myPostsEmptyBody =>
      'Share news, a photo, or a question with the diaspora.';

  @override
  String get savedPostsEmptyTitle => 'Nothing saved\nyet';

  @override
  String get savedPostsEmptyBody =>
      'Tap the bookmark on any post to keep it here.';

  @override
  String get savedPostsNote => 'Your saved items are visible only to you.';

  @override
  String get repostsTitle => 'My reposts';

  @override
  String get repostsError => 'Couldn\'t load your reposts.';

  @override
  String get repostsEmptyTitle => 'No reposts yet';

  @override
  String get repostsEmptyBody =>
      'Repost something to share it with your followers.';

  @override
  String get followersEmptyTitle => 'No followers\nyet';

  @override
  String get followersEmptyBody =>
      'Post and engage to get noticed by the diaspora.';

  @override
  String get followingEmptyTitle => 'You\'re not\nfollowing anyone';

  @override
  String get followingEmptyBody =>
      'Follow members to see their posts in your feed.';

  @override
  String get searchPeopleHint => 'Search people';

  @override
  String get suggestionsTitle => 'Suggestions';

  @override
  String get older => 'Older';

  @override
  String get trendingHashtags => 'Trending hashtags';

  @override
  String get noPostsForFilter => 'No loaded posts match this filter.';

  @override
  String get todayTitle => 'Today';

  @override
  String get messagesUnreadTitle => 'Unread messages';

  @override
  String get mentions => 'Mentions';

  @override
  String get groupActive => 'Active';

  @override
  String get groupCalm => 'Quiet';

  @override
  String get settingsPrivacySecurity => 'Privacy & security';

  @override
  String get settingsAppearanceLanguage => 'Appearance & language';

  @override
  String get settingsHelpAbout => 'Help & about';

  @override
  String get locationReciprocity =>
      'It\'s mutual: share your approximate location to see members near you.';

  @override
  String get locationGuarantee1 =>
      'Approximate position, never your exact address';

  @override
  String get locationGuarantee2 => 'Can be turned off anytime';

  @override
  String get locationGuarantee3 => 'Hidden from accounts you block';

  @override
  String get exploreOtherwise => 'Explore another way';

  @override
  String get embassyOpen => 'Open';

  @override
  String get reopenExpected => 'Reopening expected';

  @override
  String get posts => 'posts';

  @override
  String get postSingle => 'post';

  @override
  String get shareToConversation => 'Send to...';

  @override
  String get sharedFromAnotherApp => 'Shared from another app';

  @override
  String get sharedContentSent => 'Shared content sent successfully';

  @override
  String get someSharedContentNotSent => 'Some items could not be shared';

  @override
  String sharedFileCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 's',
      one: '',
    );
    return '+$count file$_temp0';
  }

  @override
  String get sharedTextCount => '1 text';

  @override
  String get exportConversation => 'Export conversation';

  @override
  String get exportFormatTxt => 'Text (.txt)';

  @override
  String get exportFormatJson => 'JSON (.json)';

  @override
  String get exportFormatHtml => 'HTML (.html)';

  @override
  String get noMessagesToExport => 'No messages to export';

  @override
  String get exportError => 'Export error';

  @override
  String get onbCitiesEyebrow => 'Niamey · Paris · Montreal · Abidjan';

  @override
  String get onbWelcomeTitle => 'Welcome to\nDiaspo Niger';

  @override
  String get onbWelcomeBody =>
      'The Nigerien community, wherever it is: find your people, help each other out, stay close to home even from far away.';

  @override
  String get onbWelcomeIllustration => 'illustration — the diaspora';

  @override
  String get onbMembersTitle => 'Discover\nthe members';

  @override
  String get onbMembersBody =>
      'See who lives near you: occupation, home town, languages spoken — everything you need to find the right person at the right time.';

  @override
  String get onbMembersIllustration => 'illustration — member map';

  @override
  String get onbMembersBullet1 =>
      'Approximate location, never the exact address';

  @override
  String get onbMembersBullet2 => 'You see those who share, and they see you';

  @override
  String get onbGroupsTitle => 'Join\ngroups';

  @override
  String get onbGroupsBody =>
      'Neighbourhood support, associations, student cohorts: find your own near you or back home.';

  @override
  String get onbGroupsIllustration => 'illustration — joining a group';

  @override
  String get onbGroupsBullet1 => 'Public or private groups, your call';

  @override
  String get onbGroupsBullet2 => 'End-to-end encrypted conversations';

  @override
  String get onbEventsTitle => 'Take part in\nevents';

  @override
  String get onbEventsBody =>
      'Celebrations, admin help desks, sports meet-ups: sign up in one tap and add the date to your calendar.';

  @override
  String get onbEventsIllustration => 'illustration — Republic Day';

  @override
  String get onbEventsBullet1 => 'In person or online';

  @override
  String get onbEventsBullet2 => 'A reminder before the day';

  @override
  String get onbConnectedTitle => 'Stay\nconnected';

  @override
  String get onbConnectedBody =>
      'Two permissions and you are ready. You can change them at any time in Settings.';

  @override
  String get onbConnectedIllustration => 'illustration — staying connected';

  @override
  String get onbNotificationsSubtitle =>
      'Messages, invitations, event reminders';

  @override
  String get onbLocationSubtitle => 'Reciprocal: you see those who share';

  @override
  String get onbLaterWithoutPermissions => 'Later, without permissions';

  @override
  String get setupIdentityTitle => 'Let us get acquainted';

  @override
  String get setupIdentityBody =>
      'Your name and occupation help members know who you are — and reach out at the right moment.';

  @override
  String get setupFullNameHint => 'Moussa Adamou';

  @override
  String get setupProfessionHint => 'Choose from the list';

  @override
  String get setupProfessionHelper =>
      'Chosen from the list: Entrepreneur, Engineer, Doctor, Student…';

  @override
  String get setupAddPhoto => 'Add a photo';

  @override
  String get setupPhotoHint => 'Optional · your initials otherwise';

  @override
  String get setupYourPhoto => 'Your photo';

  @override
  String get setupLocationBody =>
      'This is what puts you on the member map and surfaces the groups and events in your city.';

  @override
  String get setupCityHint => 'Paris, Niamey, New York…';

  @override
  String get setupOriginCityHint => 'Specify your home town';

  @override
  String get setupShareLocationSubtitle =>
      'Reciprocal: you see nearby members, they see you';

  @override
  String get setupLocationPrivacyNote =>
      'Approximate location only · changeable in Settings';

  @override
  String get setupInterestsBody =>
      'They personalise your feed and group suggestions. Pick at least two.';

  @override
  String get setupNoneSelected => 'None selected';

  @override
  String setupSelectedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count selected',
      one: '1 selected',
      zero: 'None selected',
    );
    return '$_temp0';
  }

  @override
  String get setupWhatYouGet => 'What you will receive';

  @override
  String get setupThemeBody =>
      'Dark mode saves battery on OLED screens. Changeable at any time in Settings.';

  @override
  String get setupAccentColor => 'Accent colour';

  @override
  String get setupAllSet => 'All set';

  @override
  String setupAllSetNamed(String name) {
    return 'All set, $name';
  }

  @override
  String setupCompletionSummary(int percent) {
    return 'Profile $percent% complete: you are visible on the member map and in search.';
  }

  @override
  String setupCompletionSummaryCity(int percent, String city) {
    return 'Profile $percent% complete: you are visible on the member map for $city and in search.';
  }

  @override
  String get setupHandleInvalid => 'Choose an available username';

  @override
  String get setupErrorConnection =>
      'Connection error. Check your internet connection.';

  @override
  String get setupErrorNotSignedIn => 'Not signed in. Please sign in again.';

  @override
  String get setupErrorProfileMissing =>
      'Profile not found. Please restart the app.';

  @override
  String setupErrorGeneric(String details) {
    return 'Error: $details';
  }

  @override
  String get handleLabel => 'Username';

  @override
  String get handleExample => 'moussa';

  @override
  String get handleHint => 'Used to find and mention you · optional';

  @override
  String get handleAvailableHint => 'Available · used to find and mention you';

  @override
  String get handleTaken => 'This username is already taken';

  @override
  String get handleFormat => '3 to 20 characters: letters, digits, _';

  @override
  String messagesActiveGroups(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count active groups',
      one: '1 active group',
      zero: 'No active group',
    );
    return '$_temp0';
  }

  @override
  String groupsJoinedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count joined',
      one: '1 joined',
      zero: '0 joined',
    );
    return '$_temp0';
  }

  @override
  String groupsPendingInvites(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count invitations',
      one: '1 invitation',
      zero: 'No invitation',
    );
    return '$_temp0';
  }

  @override
  String notificationsUnreadCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count unread',
      one: '1 unread',
      zero: 'No unread',
    );
    return '$_temp0';
  }

  @override
  String get homeServiceFeed => 'The feed';

  @override
  String homeNobodyWithin(int km) {
    return 'Nobody within $km km';
  }

  @override
  String get homeLocationActiveNote =>
      'Your location is on: you will show up as soon as a member shares theirs.';

  @override
  String get homeWidenRadius => 'Widen to 200 km';

  @override
  String get homeInviteRelative => 'Invite someone close';

  @override
  String get homeNotOnMapTitle => 'You do not appear on the map';

  @override
  String get homeNotOnMapBody =>
      'Sharing is reciprocal: without your location, you cannot see others either.';

  @override
  String get homeEnableLocation => 'Turn on my location';

  @override
  String get homeOfflineTitle => 'You are offline';

  @override
  String get homeOfflineBody =>
      'Showing cached content. It will refresh automatically when the network is back.';

  @override
  String get homeCompleteProfile => 'Complete your profile';

  @override
  String homeGroupsToDiscover(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count groups to discover',
      one: '1 group to discover',
    );
    return '$_temp0';
  }

  @override
  String get homeFindYourCommunity => 'Find your community';

  @override
  String get homeGettingStarted => 'GETTING STARTED';

  @override
  String get homeFindRelatives => 'Find your people';

  @override
  String get homeFindRelativesSub => 'By QR code, without swapping numbers';

  @override
  String get homeJoinGroup => 'Join a group';

  @override
  String get homeEnableMemberMap => 'Turn on the member map';

  @override
  String get homeEnableMemberMapSub => 'Reciprocal · can be turned off';

  @override
  String homeFirstMeetupCity(String city) {
    return 'A tea, a match, a hand with paperwork: be the first to bring the $city community together.';
  }

  @override
  String get homeFirstMeetup =>
      'A tea, a match, a hand with paperwork: be the first to bring the community together.';

  @override
  String get homeStartFirstMeetup => 'Start the first meet-up';

  @override
  String get homeEventChipPaperwork => 'Paperwork';

  @override
  String homeNoEventInCity(String city) {
    return 'No event in $city';
  }

  @override
  String get homeNoInPersonEvent => 'No in-person event';

  @override
  String get homeOnlineWorkshopNote =>
      'An online workshop is available from home.';

  @override
  String get homeNothingPlanned => 'Nothing planned right now';

  @override
  String homeLastEventGathered(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'The last one gathered $count people.',
      one: 'The last one gathered 1 person.',
    );
    return '$_temp0';
  }

  @override
  String get homeReviveCommunity =>
      'Get the community going again with a new event.';

  @override
  String get homeNotifyNext => 'Notify me of the next one';

  @override
  String get homeAddCity => 'Add my city';

  @override
  String get homeAddCountry => 'Add my country';

  @override
  String get homeAddProfession => 'Add my occupation';

  @override
  String get homeFieldProfession => 'occupation';

  @override
  String get homeCompleteBio => 'Complete my bio';

  @override
  String get homeShareInvite =>
      'Join me on Diaspo Niger, the Nigerien community around the world.';

  @override
  String get groupsSuggestedForYou => 'Suggested for you';

  @override
  String get groupsActionUnavailable =>
      'Action unavailable right now, please try again.';

  @override
  String get groupsDetailsUnavailable => 'Details unavailable.';

  @override
  String groupSeeAllMembers(int count) {
    return 'See all $count members';
  }

  @override
  String get groupRoleModerator => 'Mod';

  @override
  String get messagesMyNotes => 'My notes';

  @override
  String get messagesMyNotesSubtitle => 'Notes, drafts and polls';

  @override
  String get callStatusMissed => 'missed';

  @override
  String get callStatusDeclined => 'declined';

  @override
  String get callKindVideo => 'video';

  @override
  String notificationsGroupedMessages(int count, int conversations) {
    return '$count messages from $conversations conversations';
  }

  @override
  String get profileCompletionPhotoBenefit =>
      'You will be recognised more easily';

  @override
  String get profileCompletionCityBenefit =>
      'You will show up for nearby members';

  @override
  String get profileFieldOccupation => 'Occupation';

  @override
  String get profileCompletionJobBenefit => 'Useful for introductions';

  @override
  String get profileCompletionBioBenefit =>
      'Introduce yourself to the community';

  @override
  String get profileCompleteYours => 'Complete your profile';

  @override
  String profileCompletionPercent(int percent) {
    return 'Your profile is $percent% complete';
  }

  @override
  String get profileCompletionPitch =>
      'A complete profile makes you visible in search and on the members map.';

  @override
  String get profileCompletionAdd => 'Add';

  @override
  String get profileToComplete => 'Profile to complete';

  @override
  String get profileCompleteMine => 'Complete my profile';

  @override
  String profileBlockConfirm(String name) {
    return 'Are you sure you want to block $name? You will no longer receive messages from them.';
  }

  @override
  String profileCommonGroups(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count groups in common',
      one: '1 group in common',
    );
    return '$_temp0';
  }

  @override
  String profileAcceptError(String details) {
    return 'Could not accept: $details';
  }

  @override
  String get profileRequestGoneDetail =>
      'This request no longer exists. It may already have been accepted or cancelled.';

  @override
  String get searchRecent => 'Recent searches';

  @override
  String get searchAnything => 'Search...';

  @override
  String get homeServiceTransfers => 'money transfers';

  @override
  String get homeServiceShop => 'shop';

  @override
  String get homeServiceEmbassies => 'embassies';

  @override
  String homeA11yServices(String list) {
    return 'Quick access to services: $list.';
  }

  @override
  String get homeSearchableMembers => 'members';

  @override
  String get homeSearchableGroups => 'groups';

  @override
  String get homeSearchableEvents => 'events';

  @override
  String homeA11ySearch(String list) {
    return 'Find $list easily.';
  }

  @override
  String homeA11yStats(String list) {
    return 'Discover the community: number of $list. Tap to explore.';
  }

  @override
  String get listSeparatorAnd => ' and ';

  @override
  String profileCompletionMessage(int count, String fields, String place) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$fields make you visible to the community$place.',
      one: '$fields makes you visible to the community$place.',
    );
    return '$_temp0';
  }

  @override
  String profileCompletionField(String field) {
    return 'your $field';
  }

  @override
  String profileCompletionPlace(String city) {
    return ' in $city';
  }

  @override
  String get homeFieldPhoto => 'photo';

  @override
  String get homeFieldCity => 'city';

  @override
  String get homeFieldCountry => 'country';

  @override
  String get homeFieldBio => 'bio';

  @override
  String get recordingGestureHints => 'Slide ‹ to cancel · ↑ to lock';

  @override
  String get releaseToCancelNow => 'Release to cancel';

  @override
  String get recordingWillBeDeleted => 'The recording will be deleted';

  @override
  String get recordingLockedBadge => 'Locked';

  @override
  String get recordingHandsFree => 'Hands free — you can let go of the screen';

  @override
  String get pollLabel => 'Poll';

  @override
  String get mediaBlurredPreview => 'blurred preview';

  @override
  String mediaBlurredPreviewSize(String size) {
    return 'blurred preview · $size';
  }

  @override
  String get moreActions => 'More actions';

  @override
  String get ghostMuteSilentNote =>
      '\"Silent mute\" does not notify the person: their mic simply stops being broadcast, with no error message.';

  @override
  String get podcastsEpisodeSavedDraft => 'Episode saved as a draft';

  @override
  String get profileStatPosts => 'Posts';

  @override
  String get filterUnreadFeminine => 'Unread';

  @override
  String get whoCanSeeMyNumber => 'Who can see my number?';

  @override
  String get changePhotoAction => 'Change photo';

  @override
  String get mapSortNearest => 'Nearest';

  @override
  String get mapSortByName => 'By name';

  @override
  String plusMoreCount(int count) {
    return '+$count';
  }

  @override
  String plusMoreLanguages(int count) {
    return '+$count languages';
  }

  @override
  String get phoneVerifiedBySms => 'Verified by SMS';

  @override
  String get phoneVisibilityQuestion => 'Who can see my number?';

  @override
  String get originSummaryPlaceholder => 'region and city';

  @override
  String get adminFailedPlural => 'Failed';

  @override
  String get eventOnSite => 'In person';

  @override
  String get feedNewRepost => 'New repost';

  @override
  String get feedPlaceLabel => 'Place';

  @override
  String get feedFollowedHashtags => 'Followed hashtags';

  @override
  String get feedRepostsTitle => 'Reposts';

  @override
  String get feedRepostAction => 'Repost';

  @override
  String get groupMediaAndFiles => 'Media and files';

  @override
  String get groupsByCountry => 'Groups by country';

  @override
  String get groupsLoadFailed => 'Unable to load groups';

  @override
  String get messageUnpinFailed => 'Unable to unpin this message';

  @override
  String get openSettingsAction => 'Open settings';

  @override
  String get newGroupTitle => 'New group';

  @override
  String get messageExpired => 'Expired';

  @override
  String get messageLocalCopy => 'Local';

  @override
  String get notifTimezoneHint =>
      'Useful with the Niamey–Paris time difference';

  @override
  String get pollMultipleChoice => 'Multiple choice';

  @override
  String get pollVoteAction => 'Vote';

  @override
  String get pollViewResults => 'View results';

  @override
  String get profileYourCurrentCity => 'Your current city';

  @override
  String get profileYourProfession => 'Your profession';

  @override
  String get transferMobileOperatorRequired => 'Mobile operator *';

  @override
  String get messageEcoBadge => 'ECO';
}
