class FirebaseCollections {
  static const String users = 'users';
  static const String profiles = 'profiles';
  static const String conversations = 'conversations';
  static const String messages = 'messages';
  static const String groups = 'groups';
  static const String events = 'events';
  static const String locations = 'user_locations';
  static const String notifications = 'notifications';
  static const String legalContent = 'legal_content';

  // Social features
  static const String friendRequests = 'friend_requests';
  static const String friends = 'friends'; // subcollection under users
  static const String groupRequests = 'group_requests';
  static const String groupInvites = 'group_invites';
  static const String profileShareLinks = 'profile_share_links';

  // Money Transfer
  static const String transactions = 'transactions';
  static const String recipients = 'recipients';

  // Marketplace
  static const String products = 'products';
  static const String orders = 'orders';
  static const String escrowTransactions = 'escrow_transactions';

  // Business Directory
  static const String businesses = 'businesses';
  static const String businessBoosts = 'business_boosts';
  static const String businessReviews = 'business_reviews';
  static const String businessPosts = 'business_posts';

  // Calls
  static const String calls = 'calls';

  // Admin Configuration
  static const String appConfig = 'app_config';
  static const String appSettings = 'settings'; // document under app_config
  static const String reports = 'reports';
  static const String embassies = 'embassies';
}
