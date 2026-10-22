import 'dart:async';

import 'package:flutter/material.dart';

import '../../infrastructure/notifications/user_notification_repository.dart';
import 'appColor.dart';
import 'notification_inbox_page.dart';

class NotificationBellButton extends StatefulWidget {
  const NotificationBellButton({super.key});

  @override
  State<NotificationBellButton> createState() => _NotificationBellButtonState();
}

class _NotificationBellButtonState extends State<NotificationBellButton> {
  final _repository = UserNotificationRepository();
  Timer? _refreshTimer;
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_refreshCount());
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => unawaited(_refreshCount()),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _refreshCount() async {
    try {
      final count = await _repository.getUnreadCount();
      if (mounted) setState(() => _unreadCount = count);
    } catch (_) {
      // Keep the bell available if the inbox migration has not been applied.
    }
  }

  Future<void> _openInbox() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const NotificationInboxPage()),
    );
    await _refreshCount();
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Notifications',
      onPressed: _openInbox,
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          const Icon(Icons.notifications_outlined, color: kGold),
          if (_unreadCount > 0)
            Positioned(
              right: -7,
              top: -6,
              child: Container(
                constraints: const BoxConstraints(minWidth: 17, minHeight: 17),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                decoration: const BoxDecoration(
                  color: Colors.redAccent,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  _unreadCount > 99 ? '99+' : '$_unreadCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
