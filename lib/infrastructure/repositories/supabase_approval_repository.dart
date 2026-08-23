import 'dart:io';
import 'package:dartz/dartz.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../../core/error/failures.dart';
import '../supabase/supabase_config.dart';

class SupabaseApprovalRepository {
  final SupabaseClient _client = SupabaseConfig.client;

  // PhilSMS credentials for sending approval SMS
  static const _philsmsToken = '3681|YUG5fYRSWoqGyZb8PWoRoYmmllw7HWvbwkItyOB94c6f0330';
  static const _philsmsSenderId = 'PhilSMS';
  static const _philsmsEndpoint = 'https://dashboard.philsms.com/api/v3/sms/send';

  static const _networkHints = [
    'network',
    'connection',
    'failed to host lookup',
    'socketexception',
    'clientexception',
  ];

  bool _looksLikeNetworkError(String message) {
    final lower = message.toLowerCase();
    return _networkHints.any(lower.contains);
  }

  Failure _mapError(Object e) {
    if (e is SocketException) {
      return NetworkFailure('No internet connection: ${e.message}');
    }
    if (e is AuthException) {
      return _looksLikeNetworkError(e.message)
          ? NetworkFailure(e.message)
          : AuthFailure(e.message);
    }
    if (e is PostgrestException) {
      return _looksLikeNetworkError(e.message)
          ? NetworkFailure(e.message)
          : ServerFailure('Database error: ${e.message}');
    }
    final str = e.toString();
    return _looksLikeNetworkError(str)
        ? NetworkFailure('Network error occurred')
        : ServerFailure(str);
  }

  String _normalizePhone(String raw) {
    final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.startsWith('63')) return digits;
    if (digits.startsWith('0')) return '63${digits.substring(1)}';
    if (digits.startsWith('9')) return '63$digits';
    return digits;
  }

  /// Fetches all pending accounts (users with status 'pending')
  Future<Either<Failure, List<Map<String, dynamic>>>> fetchPendingAccounts() async {
    try {
      final response = await _client
          .from('users')
          .select('''
            user_id,
            fname,
            mname,
            lname,
            email,
            contact_num,
            role_id,
            status,
            created_at,
            role:role_id(role),
            applications!inner(
              application_id,
              created_at,
              response_at,
              status
            ),
            personal_details(
              document_id,
              uploaded_at
            )
          ''')
          .eq('status', 'pending')
          .order('created_at', ascending: false);

      return Right(List<Map<String, dynamic>>.from(response));
    } catch (e) {
      return Left(_mapError(e));
    }
  }

  /// Fetches all registered accounts (for debugging/verification)
  Future<Either<Failure, List<Map<String, dynamic>>>> fetchAllAccounts() async {
    try {
      final response = await _client
          .from('users')
          .select('''
            user_id,
            fname,
            mname,
            lname,
            email,
            contact_num,
            role_id,
            status,
            created_at,
            role:role_id(role),
            applications(
              application_id,
              created_at,
              response_at,
              status
            ),
            personal_details(
              document_id,
              uploaded_at
            )
          ''')
          .order('created_at', ascending: false);

      return Right(List<Map<String, dynamic>>.from(response));
    } catch (e) {
      return Left(_mapError(e));
    }
  }

  /// Approves an account by updating user status and application status
  Future<Either<Failure, void>> approveAccount({
    required String userId,
    required String temporaryPassword,
  }) async {
    try {
      // Update user status to 'approved'
      await _client
          .from('users')
          .update({'status': 'approved'})
          .eq('user_id', userId);

      // Update application status to 'approved'
      await _client
          .from('applications')
          .update({
            'status': 'approved',
            'response_at': DateTime.now().toIso8601String(),
          })
          .eq('user_id', userId);

      // Note: The temporary password is already set during registration
      // We don't need to update it here since it's already stored in Supabase Auth
      // The user will use the temp password sent during registration to log in

      return const Right(null);
    } catch (e) {
      return Left(_mapError(e));
    }
  }

  /// Rejects an account by updating user status and application status
  Future<Either<Failure, void>> rejectAccount({
    required String userId,
  }) async {
    try {
      // Update user status to 'rejected'
      await _client
          .from('users')
          .update({'status': 'rejected'})
          .eq('user_id', userId);

      // Update application status to 'rejected'
      await _client
          .from('applications')
          .update({
            'status': 'rejected',
            'response_at': DateTime.now().toIso8601String(),
          })
          .eq('user_id', userId);

      return const Right(null);
    } catch (e) {
      return Left(_mapError(e));
    }
  }

  /// Sends approval SMS with username and temporary password
  Future<Either<Failure, void>> sendApprovalSms({
    required String phoneNumber,
    required String username,
    required String temporaryPassword,
  }) async {
    try {
      final normalizedPhone = _normalizePhone(phoneNumber);
      final message = 'Your GAHIRA account has been approved.\n'
          'Username: $username\n'
          'Temporary Password: $temporaryPassword\n'
          'Please log in and change your password immediately.';

      final smsRes = await http.post(
        Uri.parse(_philsmsEndpoint),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $_philsmsToken',
        },
        body: jsonEncode({
          'recipient': normalizedPhone,
          'sender_id': _philsmsSenderId,
          'type': 'plain',
          'message': message,
        }),
      );

      final smsBody = jsonDecode(smsRes.body) as Map<String, dynamic>;
      if (smsRes.statusCode >= 300 || smsBody['status'] != 'success') {
        return Left(ServerFailure(smsBody['message'] ?? 'Failed to send SMS'));
      }

      return const Right(null);
    } catch (e) {
      return Left(ServerFailure('Failed to send SMS: ${e.toString()}'));
    }
  }

  /// Fetches document URL from Supabase Storage
  Future<Either<Failure, String>> getDocumentUrl({
    required String userId,
    required String documentId,
  }) async {
    try {
      // Get the personal_details record to find the uploaded file
      final personalDetails = await _client
          .from('personal_details')
          .select()
          .eq('user_id', userId)
          .eq('document_id', documentId)
          .maybeSingle();

      if (personalDetails == null) {
        return const Left(ServerFailure('Document not found'));
      }

      // Construct the file name based on the pattern used in registration
      // Pattern: 'doc_${userId}_${timestamp}' or 'resume_${userId}_${timestamp}'
      final uploadedAt = DateTime.parse(personalDetails['uploaded_at']);
      final timestamp = uploadedAt.millisecondsSinceEpoch;
      
      // Try both patterns
      final possibleNames = [
        'doc_${userId}_$timestamp',
        'resume_${userId}_$timestamp',
      ];

      String? publicUrl;
      for (final fileName in possibleNames) {
        try {
          final url = _client.storage.from('userFiles').getPublicUrl(fileName);
          publicUrl = url;
          break;
        } catch (e) {
          continue;
        }
      }

      if (publicUrl == null) {
        return const Left(ServerFailure('Document file not found in storage'));
      }

      return Right(publicUrl);
    } catch (e) {
      return Left(_mapError(e));
    }
  }
}
