import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/services/supabase_auth_bridge.dart';
import '../models/notification_model.dart';
import 'notification_remote_datasource.dart';

class NotificationSupabaseDataSource implements NotificationRemoteDataSource {
  SupabaseClient get _supabase => Supabase.instance.client;

  NotificationModel _fromRow(Map<String, dynamic> row) {
    final data = Map<String, dynamic>.from(
      (row['data'] as Map<String, dynamic>?) ?? {},
    );
    return NotificationModel.fromJson({
      ...data,
      'id': row['id'].toString(),
      'userId': row['user_id'],
      'type': row['type'],
      'title': row['title'],
      'body': row['body'],
      'isRead': row['is_read'],
      'createdAt': row['created_at'],
    });
  }

  @override
  Stream<List<NotificationModel>> getNotifications(
    String userId, {
    int limit = 20,
  }) {
    return _supabase
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(limit)
        .map((rows) => rows.map(_fromRow).toList());
  }

  @override
  Future<List<NotificationModel>> fetchNotifications({
    required String userId,
    int limit = 20,
    DateTime? startAfter,
  }) async {
    try {
      var query = _supabase
          .from('notifications')
          .select()
          .eq('user_id', userId);

      if (startAfter != null) {
        query = query.lt('created_at', startAfter.toUtc().toIso8601String());
      }

      final rows = await query
          .order('created_at', ascending: false)
          .limit(limit);
      return rows.map(_fromRow).toList();
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<int> getUnreadCount(String userId) async {
    try {
      final response = await _supabase
          .from('notifications')
          .select()
          .eq('user_id', userId)
          .eq('is_read', false)
          .count(CountOption.exact);
      return response.count;
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<void> markAsRead(String notificationId) async {
    try {
      await SupabaseAuthBridge.instance.ensureAuthenticated();
      await _supabase
          .from('notifications')
          .update({'is_read': true})
          .eq('id', notificationId);
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<void> markAllAsRead(String userId) async {
    try {
      await SupabaseAuthBridge.instance.ensureAuthenticated();
      await _supabase
          .from('notifications')
          .update({'is_read': true})
          .eq('user_id', userId)
          .eq('is_read', false);
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<void> deleteNotification(String notificationId) async {
    try {
      await SupabaseAuthBridge.instance.ensureAuthenticated();
      await _supabase
          .from('notifications')
          .delete()
          .eq('id', notificationId);
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<void> deleteAllNotifications(String userId) async {
    try {
      await SupabaseAuthBridge.instance.ensureAuthenticated();
      await _supabase
          .from('notifications')
          .delete()
          .eq('user_id', userId);
    } catch (e) {
      throw ServerException(e.toString());
    }
  }
}
