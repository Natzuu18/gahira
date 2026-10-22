import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Firebase configuration for the Android app registered in project egres-43a8a.
/// iOS is intentionally not configured yet.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return android;
    }

    throw UnsupportedError(
      'Firebase is currently configured for Android only.',
    );
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAc3Qoy0ZqhplOsfWyEdWrkv2X4ETLkb0s',
    appId: '1:63488850418:android:9647c6a2a10d9c49e0936b',
    messagingSenderId: '63488850418',
    projectId: 'egres-43a8a',
    storageBucket: 'egres-43a8a.firebasestorage.app',
  );
}
