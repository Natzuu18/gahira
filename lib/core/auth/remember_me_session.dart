import 'package:shared_preferences/shared_preferences.dart';
import '../../infrastructure/supabase/supabase_config.dart';

class RememberMeSession {
  static const _expiresAtKey = 'remember_me_expires_at';
  static const duration = Duration(days: 7);

  static Future<DateTime?> get expiresAt async {
    final preferences = await SharedPreferences.getInstance();
    final timestamp = preferences.getInt(_expiresAtKey);
    return timestamp == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(timestamp);
  }

  static Future<DateTime> rememberForSevenDays() async {
    final expiresAt = DateTime.now().add(duration);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setInt(_expiresAtKey, expiresAt.millisecondsSinceEpoch);
    return expiresAt;
  }

  static Future<void> clear() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_expiresAtKey);
  }

  static Future<void> signOut() async {
    await SupabaseConfig.client.auth.signOut();
    await clear();
  }
}
