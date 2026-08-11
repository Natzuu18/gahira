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
  if (phoneRaw == null || phoneRaw.isEmpty) {
    return Response.json(statusCode: 400, body: {'status': 'error', 'message': 'phone is required'});
  }
  final phone = normalizePhone(phoneRaw);

  final otp = generateOtp();
  final otpHash = hashString(otp);

  final insertRes = await http.post(
    Uri.parse('$supabaseUrl/rest/v1/phone_otp_verifications'),
    headers: supabaseHeaders,
    body: jsonEncode({
      'phone': phone,
      'otp_hash': otpHash,
      'otp_expires_at': DateTime.now().toUtc().add(otpTtl).toIso8601String(),
    }),
  );
  if (insertRes.statusCode >= 300) {
    return Response.json(
      statusCode: 500,
      body: {'status': 'error', 'message': 'Failed to record OTP: ${insertRes.body}'},
    );
  }

  final smsRes = await http.post(
    Uri.parse(philsmsEndpoint),
    headers: {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': 'Bearer $philsmsToken',
    },
    body: jsonEncode({
      'recipient': phone,
      'sender_id': philsmsSenderId,
      'type': 'plain',
      'message': 'Your verification code is $otp. It expires in 5 minutes.',
    }),
  );

  final smsBody = jsonDecode(smsRes.body) as Map<String, dynamic>;
  if (smsRes.statusCode >= 300 || smsBody['status'] != 'success') {
    return Response.json(
      statusCode: 502,
      body: {'status': 'error', 'message': smsBody['message'] ?? 'Failed to send SMS'},
    );
  }

  return Response.json(body: {'status': 'success'});
}
