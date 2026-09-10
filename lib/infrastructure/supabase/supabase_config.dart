import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/config/env_config.dart';

class SupabaseConfig {
  static String get url => EnvConfig.supabaseUrl;
  static String get anonKey => EnvConfig.supabaseAnonKey;

  static Future<void> init() async {
    await Supabase.initialize(
      url: url,
      anonKey: anonKey,
    );
  }

  static SupabaseClient get client => Supabase.instance.client;
}
