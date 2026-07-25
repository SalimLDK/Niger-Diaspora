import '../../features/profile/domain/entities/profile_entity.dart';

extension ProfileEntityCompat on ProfileEntity {
  /// Peut recevoir un appel / notification push (en ligne ou notifications actives).
  bool get canReceiveNotifications => isOnline || notificationsEnabled;
}
