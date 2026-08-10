import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  static const String url = 'https://opsxwnjmcbvplrrtgqvj.supabase.co';
  static const String anonKey = 'sb_publishable_G-5YWyaY1cbW4EXZFCBGIQ_FnILc7ox';

  static Future<void> init() async {
    await Supabase.initialize(
      url: url,
      anonKey: anonKey,
    );
  }

  static SupabaseClient get client => Supabase.instance.client;
}
