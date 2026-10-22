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

  Future<void> initializeForMiner() async {
    final isMobile =
        defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
    if (_initialized || kIsWeb || !isMobile) return;
    if (Firebase.apps.isEmpty) {
      debugPrint('[Push] Firebase is not initialized; skipping device registration.');
      return;
    }
    _initialized = true;
    debugPrint('[Push] Starting registration on ${defaultTargetPlatform.name}.');

    try {
      final messaging = FirebaseMessaging.instance;
      var settings = await messaging.getNotificationSettings();
      debugPrint('[Push] Current permission status: ${settings.authorizationStatus.name}.');
      // Android 11 and earlier do not have the POST_NOTIFICATIONS runtime prompt.
      // On Android 13+, request only when the OS reports permission as undetermined.
      // A denied notification permission should not prevent device registration;
      // it only affects whether Android displays notifications.
      if (defaultTargetPlatform == TargetPlatform.iOS ||
          (defaultTargetPlatform == TargetPlatform.android &&
              settings.authorizationStatus == AuthorizationStatus.notDetermined)) {
        settings = await messaging.requestPermission(
          alert: true,
          badge: true,
          sound: true,
        );
        debugPrint('[Push] Permission request result: ${settings.authorizationStatus.name}.');
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

      if (defaultTargetPlatform == TargetPlatform.iOS) {
        await messaging.setForegroundNotificationPresentationOptions(
          alert: false,
          badge: false,
          sound: false,
        );
      }
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) {
        debugPrint('[Push] No Supabase user is signed in; cannot associate this device.');
      } else {
        debugPrint('[Push] Signed-in user ID: $userId.');
      }
      messaging.onRegistered.listen((newToken) {
        debugPrint('[Push] Firebase registered device ID received.');
        final currentUserId = Supabase.instance.client.auth.currentUser?.id;
        if (currentUserId != null) {
          unawaited(_saveToken(newToken, currentUserId));
        } else {
          debugPrint('[Push] Firebase returned a device ID, but no Supabase user is signed in.');
        }
      }, onError: (Object error) {
        debugPrint('[Push] Firebase registration stream error: $error');
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
      debugPrint('[Push] Calling Firebase register().');
      await messaging.register().timeout(const Duration(seconds: 20));
      debugPrint('[Push] Firebase register() completed; waiting for its device ID event.');
    } catch (error, stackTrace) {
      _initialized = false;
      debugPrint('Could not initialize miner push notifications: $error');
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
      debugPrint('[Push] Device ID saved to Supabase for user $userId.');
    } catch (error) {
      debugPrint('[Push] Could not save device ID to Supabase: $error');
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
