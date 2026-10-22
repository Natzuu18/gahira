import 'package:supabase_flutter/supabase_flutter.dart';

class UserNotificationRepository {
  static const _pageSize = 500;
  final SupabaseClient _client = Supabase.instance.client;

  String get _userId {
    final id = _client.auth.currentUser?.id;
    if (id == null) throw StateError('Sign in to view notifications.');
    return id;
  }

  Future<List<Map<String, dynamic>>> getNotifications() async {
    final notifications = <Map<String, dynamic>>[];
    var offset = 0;
    while (true) {
      final rows = await _client
          .from('service_progress_notifications')
          .select(
            'id, title, body, service_request_id, data, created_at, read_at',
          )
          .eq('user_id', _userId)
          .order('created_at', ascending: false)
          .order('id', ascending: false)
          .range(offset, offset + _pageSize - 1);
      final page = (rows as List)
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList();
      notifications.addAll(page);
      if (page.length < _pageSize) return notifications;
      offset += page.length;
    }
  }

  Future<int> getUnreadCount() async {
    var unreadCount = 0;
    var offset = 0;
    while (true) {
      final rows = await _client
          .from('service_progress_notifications')
          .select('id')
          .eq('user_id', _userId)
          .isFilter('read_at', null)
          .range(offset, offset + _pageSize - 1);
      final pageSize = (rows as List).length;
      unreadCount += pageSize;
      if (pageSize < _pageSize) return unreadCount;
      offset += pageSize;
    }
  }

  Future<void> markRead(String notificationId) async {
    await _client
        .from('service_progress_notifications')
        .update({'read_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', notificationId)
        .eq('user_id', _userId)
        .isFilter('read_at', null);
  }

  Future<void> markAllRead() async {
    await _client
        .from('service_progress_notifications')
        .update({'read_at': DateTime.now().toUtc().toIso8601String()})
        .eq('user_id', _userId)
        .isFilter('read_at', null);
  }
}
