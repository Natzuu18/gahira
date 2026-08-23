import 'dart:convert';
import 'package:dart_frog/dart_frog.dart';
import 'package:http/http.dart' as http;
import 'package:otp_server/otp_helpers.dart';

Future<Response> onRequest(RequestContext context) async {
  // Method Check
  if (context.request.method != HttpMethod.get) {
    return Response.json(
      statusCode: 405, 
      body: {'status': 'error', 'message': 'Method not allowed'}
    );
  }

  try {
    // 1. Fetch 'open' slots from Supabase via REST API
    // We order by date to ensure the calendar is easy to build on frontend.
    final url = Uri.parse(
      '$supabaseUrl/rest/v1/appointment_availability'
      '?status=eq.open'
      '&order=date.asc'
    );

    final response = await http.get(
      url,
      headers: supabaseHeaders,
    );

    if (response.statusCode >= 300) {
      return Response.json(
        statusCode: response.statusCode,
        body: {
          'status': 'error', 
          'message': 'Failed to fetch availability',
          'details': response.body
        },
      );
    }

    // 2. Return the data as JSON
    final data = jsonDecode(response.body);
    return Response.json(body: {
      'status': 'success',
      'data': data,
    });
  } catch (e) {
    return Response.json(
      statusCode: 500,
      body: {'status': 'error', 'message': e.toString()},
    );
  }
}
