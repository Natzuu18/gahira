import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../infrastructure/notifications/user_notification_repository.dart';
import 'appColor.dart';

class NotificationInboxPage extends StatefulWidget {
  const NotificationInboxPage({super.key});

  @override
  State<NotificationInboxPage> createState() => _NotificationInboxPageState();
}

class _NotificationInboxPageState extends State<NotificationInboxPage> {
  final _repository = UserNotificationRepository();
  late Future<List<Map<String, dynamic>>> _notificationsFuture;
  bool _isMarkingAllRead = false;

  @override
  void initState() {
    super.initState();
    _notificationsFuture = _repository.getNotifications();
  }

  Future<void> _refresh() async {
    final future = _repository.getNotifications();
    setState(() {
      _notificationsFuture = future;
    });
    await future;
  }

  Future<void> _markRead(Map<String, dynamic> notification) async {
    if (notification['read_at'] != null) return;
    try {
      await _repository.markRead(notification['id'].toString());
      if (mounted) await _refresh();
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _markAllRead() async {
    setState(() => _isMarkingAllRead = true);
    try {
      await _repository.markAllRead();
      if (mounted) await _refresh();
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) setState(() => _isMarkingAllRead = false);
    }
  }

  void _showError(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Could not update notifications: $error')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bgColor,
      appBar: AppBar(
        backgroundColor: context.surfaceColor,
        title: const Text(
          'NOTIFICATIONS',
          style: TextStyle(
            color: kGold,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
        iconTheme: const IconThemeData(color: kGold),
        actions: [
          TextButton(
            onPressed: _isMarkingAllRead ? null : _markAllRead,
            child: Text(
              _isMarkingAllRead ? 'Saving...' : 'Mark all read',
              style: const TextStyle(color: kGold),
            ),
          ),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _notificationsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator(color: kGold));
          }
          if (snapshot.hasError) {
            return _messageState(
              icon: Icons.cloud_off_outlined,
              title: 'Could not load notifications',
              detail: snapshot.error.toString(),
              action: TextButton.icon(
                onPressed: _refresh,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try again'),
              ),
            );
          }
          final notifications = snapshot.data ?? const [];
          if (notifications.isEmpty) {
            return _messageState(
              icon: Icons.notifications_none_rounded,
              title: 'You are all caught up',
              detail:
                  'Service progress, payment, and application updates will appear here.',
            );
          }
          return RefreshIndicator(
            onRefresh: _refresh,
            color: kGold,
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: notifications.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final notification = notifications[index];
                final isUnread = notification['read_at'] == null;
                final createdAt = DateTime.tryParse(
                  notification['created_at']?.toString() ?? '',
                );
                final serviceRequestId = notification['service_request_id']
                    ?.toString();
                final srReference = _serviceReference(serviceRequestId);
                return Card(
                  color: context.surfaceColor,
                  margin: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(
                      color: isUnread
                          ? kGold.withValues(alpha: 0.48)
                          : kGold.withValues(alpha: 0.12),
                    ),
                  ),
                  child: ListTile(
                    onTap: isUnread ? () => _markRead(notification) : null,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    leading: Icon(
                      isUnread
                          ? Icons.notifications_active_outlined
                          : Icons.notifications_none_rounded,
                      color: isUnread ? kGold : context.mutedTextColor,
                    ),
                    title: Text(
                      notification['title']?.toString() ?? 'Update',
                      style: TextStyle(
                        color: context.textColor,
                        fontWeight: isUnread
                            ? FontWeight.bold
                            : FontWeight.w600,
                      ),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 5),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            notification['body']?.toString() ?? '',
                            style: TextStyle(color: context.mutedTextColor),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 10,
                            children: [
                              if (srReference != null)
                                Text(
                                  srReference,
                                  style: const TextStyle(
                                    color: kGold,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              if (createdAt != null)
                                Text(
                                  DateFormat(
                                    'MMM d, yyyy · h:mm a',
                                  ).format(createdAt.toLocal()),
                                  style: TextStyle(
                                    color: context.mutedTextColor,
                                    fontSize: 11,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    trailing: isUnread
                        ? const Icon(Icons.circle, color: kGold, size: 9)
                        : null,
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  String? _serviceReference(String? id) {
    if (id == null || id.isEmpty) return null;
    return 'SR: ${id.substring(0, id.length < 8 ? id.length : 8).toUpperCase()}';
  }

  Widget _messageState({
    required IconData icon,
    required String title,
    required String detail,
    Widget? action,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: kGold, size: 42),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                color: context.textColor,
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              detail,
              style: TextStyle(color: context.mutedTextColor, fontSize: 12),
              textAlign: TextAlign.center,
            ),
            if (action != null) ...[const SizedBox(height: 12), action],
          ],
        ),
      ),
    );
  }
}
