import 'dart:convert';
import 'package:dart_frog/dart_frog.dart';
import 'package:http/http.dart' as http;
import 'package:otp_server/otp_helpers.dart';

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.post) {
    return Response.json(statusCode: 405, body: {'status': 'error', 'message': 'Method not allowed'});
  }

  final payload = jsonDecode(await context.request.body()) as Map<String, dynamic>;
  final phoneRaw = payload['phone'] as String?;
  final code = payload['code'] as String?;
  if (phoneRaw == null || code == null) {
    return Response.json(statusCode: 400, body: {'status': 'error', 'message': 'phone and code are required'});
  }
  final phone = normalizePhone(phoneRaw);

  final queryUri = Uri.parse(
    '$supabaseUrl/rest/v1/phone_otp_verifications'
    '?phone=eq.$phone&verified=eq.false&order=created_at.desc&limit=1',
  );
  final queryRes = await http.get(queryUri, headers: supabaseHeaders);
  final rows = jsonDecode(queryRes.body) as List;
  if (rows.isEmpty) {
    return Response.json(
      statusCode: 404,
      body: {'status': 'error', 'message': 'No pending verification for this number'},
    );
  }
  final row = rows.first as Map<String, dynamic>;

  final expiresAt = DateTime.parse(row['otp_expires_at'] as String);
  if (expiresAt.isBefore(DateTime.now().toUtc())) {
    return Response.json(statusCode: 400, body: {'status': 'error', 'message': 'Code expired, request a new one'});
  }
  final attempts = row['attempts'] as int;
  if (attempts >= maxAttempts) {
    return Response.json(
      statusCode: 429,
      body: {'status': 'error', 'message': 'Too many attempts, request a new code'},
    );
  }

  if (hashString(code) != row['otp_hash']) {
    await http.patch(
      Uri.parse('$supabaseUrl/rest/v1/phone_otp_verifications?id=eq.${row['id']}'),
      headers: supabaseHeaders,
      body: jsonEncode({'attempts': attempts + 1}),
    );
    return Response.json(statusCode: 400, body: {'status': 'error', 'message': 'Incorrect code'});
  }

  final token = generateToken();
  await http.patch(
    Uri.parse('$supabaseUrl/rest/v1/phone_otp_verifications?id=eq.${row['id']}'),
    headers: supabaseHeaders,
    body: jsonEncode({
      'verified': true,
      'verification_token': token,
      'token_expires_at': DateTime.now().toUtc().add(tokenTtl).toIso8601String(),
    }),
  );

  return Response.json(body: {
    'status': 'success',
    'data': {'verification_token': token},
  });
}
