import 'dart:io';
import 'package:flutter/foundation.dart';

/// Environment-aware configuration for Gahira Ball Mill Management System.
class EnvConfig {
  /// Supabase Configuration
  static const String supabaseUrl = 'https://opsxwnjmcbvplrrtgqvj.supabase.co';
  static const String supabaseAnonKey = 'sb_publishable_G-5YWyaY1cbW4EXZFCBGIQ_FnILc7ox';

  /// PhilSMS Configuration
  static const String philsmsEndpoint = 'https://dashboard.philsms.com/api/v3/sms/send';
  static const String philsmsApiKey = '4353|WiUWMX8UBolKHp5BrRsE14MvAT9H3bdE4UrY3g612eaaf318';
  static const String philsmsSenderId = 'PhilSMS';
}
