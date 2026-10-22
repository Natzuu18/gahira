import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/navigation/app_scaffold_messenger.dart';

class PushNotificationService {
  PushNotificationService._();

  static final PushNotificationService instance = PushNotificationService._();

  String? _registeredToken;
  String? _registeredUserId;
  bool _initialized = false;

  Future<void> initializeForCurrentUser() async {
    final isMobile =
        defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
    if (_initialized || kIsWeb || !isMobile || Firebase.apps.isEmpty) return;
    _initialized = true;

    try {
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        _initialized = false;
        return;
      }

      if (defaultTargetPlatform == TargetPlatform.iOS) {
        var apnsToken = await messaging.getAPNSToken();
        for (var attempt = 0; apnsToken == null && attempt < 5; attempt++) {
          await Future<void>.delayed(const Duration(seconds: 1));
          apnsToken = await messaging.getAPNSToken();
        }
        if (apnsToken == null) {
          throw StateError('The APNs token is not available yet.');
        }
      }

      await messaging.setForegroundNotificationPresentationOptions(
        alert: false,
        badge: false,
        sound: false,
      );
      final userId = Supabase.instance.client.auth.currentUser?.id;
      messaging.onRegistered.listen((newToken) {
        final currentUserId = Supabase.instance.client.auth.currentUser?.id;
        if (currentUserId != null) {
          unawaited(_saveToken(newToken, currentUserId));
        }
      });
      messaging.onUnregistered.listen((_) {
        unawaited(_removeRegisteredToken());
      });
      FirebaseMessaging.onMessage.listen(_showForegroundMessage);
      Supabase.instance.client.auth.onAuthStateChange.listen((state) {
        if (state.event == AuthChangeEvent.signedOut) {
          unawaited(_removeRegisteredToken());
        } else if (state.event == AuthChangeEvent.signedIn) {
          final currentUserId = state.session?.user.id;
          final currentToken = _registeredToken;
          if (currentUserId != null && currentToken != null) {
            unawaited(_saveToken(currentToken, currentUserId));
          }
        }
      });
      await messaging.register();
      final currentToken = _registeredToken;
      if (currentToken != null && userId != null) {
        await _saveToken(currentToken, userId);
      }
    } catch (error, stackTrace) {
      _initialized = false;
      debugPrint('Could not initialize push notifications: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> _saveToken(String token, String userId) async {
    try {
      await Supabase.instance.client.from('push_device_tokens').upsert({
        'user_id': userId,
        'fid': token,
        'platform': defaultTargetPlatform == TargetPlatform.iOS
            ? 'ios'
            : 'android',
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'fid');
      _registeredToken = token;
      _registeredUserId = userId;
    } catch (error) {
      debugPrint('Could not register the push token: $error');
    }
  }

  Future<void> _removeRegisteredToken() async {
    final token = _registeredToken;
    final userId = _registeredUserId;
    if (token == null || userId == null) return;
    try {
      await Supabase.instance.client
          .from('push_device_tokens')
          .delete()
          .eq('fid', token)
          .eq('user_id', userId);
    } catch (error) {
      debugPrint('Could not remove the push token on sign out: $error');
    } finally {
      _registeredToken = null;
      _registeredUserId = null;
    }
  }

  Future<void> unregisterBeforeSignOut() => _removeRegisteredToken();

  void _showForegroundMessage(RemoteMessage message) {
    final title = message.notification?.title ?? 'Service progress update';
    final body = message.notification?.body;
    if (body == null || body.isEmpty) return;
    appScaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(content: Text('$title: $body')),
    );
  }
}
