import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';

final supabaseUrl = readEnv('SUPABASE_URL');
final supabaseServiceKey = readEnv('SUPABASE_SERVICE_ROLE_KEY');
final philsmsToken = readEnv('PHILSMS_API_TOKEN');
final philsmsSenderId = readEnv('PHILSMS_SENDER_ID', fallback: 'PhilSMS');
const philsmsEndpoint = 'https://app.philsms.com/api/v3/sms/send';

const otpTtl = Duration(minutes: 5);
const tokenTtl = Duration(minutes: 15);
const maxAttempts = 5;

final _uuid = Uuid();
final _random = Random.secure();

String readEnv(String key, {String? fallback}) {
  final value = Platform.environment[key] ?? fallback;
  if (value == null) {
    throw StateError('Missing required environment variable: $key');
  }
  return value;
}

String normalizePhone(String raw) {
  final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.startsWith('63')) return digits;
  if (digits.startsWith('0')) return '63${digits.substring(1)}';
  if (digits.startsWith('9')) return '63$digits';
  return digits;
}

String hashString(String input) => sha256.convert(utf8.encode(input)).toString();

String generateOtp() => (100000 + _random.nextInt(900000)).toString();

String generateToken() =>
    '${_uuid.v4().replaceAll('-', '')}${_uuid.v4().replaceAll('-', '')}';

Map<String, String> get supabaseHeaders => {
      'apikey': supabaseServiceKey,
      'Authorization': 'Bearer $supabaseServiceKey',
      'Content-Type': 'application/json',
      'Prefer': 'return=representation',
    };
