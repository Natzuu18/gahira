import 'dart:io';
import 'package:dartz/dartz.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math';

import '../../core/error/failures.dart';
import '../supabase/supabase_config.dart';
import '../../core/config/env_config.dart';

class SupabaseApprovalRepository {
  final SupabaseClient _client = SupabaseConfig.client;

  SupabaseClient get client => _client;

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

  /// Fetches all pending applications joined with user and availability info
  Future<Either<Failure, List<Map<String, dynamic>>>> fetchPendingApplications() async {
    try {
      final response = await _client
          .from('applications')
          .select('''
            application_id,
            created_at,
            status,
            temp_pass,
            document_id,
            appointment_date,
            appointment_status,
            appointment_remarks,
            user:user_id (
              userId,
              fname,
              mname,
              lname,
              email,
              contact_num,
              role:role_id (role)
            ),
            availability:availability_id (
              date,
              start_time,
              end_time,
              address
            )
          ''')
          .eq('status', 'pending')
          .order('created_at', ascending: false);

      return Right(List<Map<String, dynamic>>.from(response));
    } catch (e) {
      return Left(_mapError(e));
    }
  }

  /// Consolidates approval logic via backend to ensure SMS and DB consistency
  Future<Either<Failure, void>> approveApplication({
    required String applicationId,
    required String userId,
  }) async {
    try {
      // 1. Fetch the temporary password generated during registration
      final appData = await _client
          .from('applications')
          .select('temp_pass, user:user_id(contact_num)')
          .eq('application_id', applicationId)
          .single();
      
      final tempPassword = appData['temp_pass'] as String?;
      if (tempPassword == null) {
        return const Left(ServerFailure('Temporary password not found for this application.'));
      }

      final user = appData['user'] as Map<String, dynamic>?;
      final phone = _normalizePhone(user?['contact_num'] ?? '');

      // 2. Update application and user status in Supabase to 'approved'
      await _client
          .from('applications')
          .update({
            'status': 'approved',
            'response_at': DateTime.now().toIso8601String(),
          })
          .eq('application_id', applicationId);

      await _client
          .from('users')
          .update({'status': 'approved'})
          .eq('userId', userId);

      // 4. Send the approval SMS via PhilSMS
      final response = await http.post(
        Uri.parse(EnvConfig.philsmsEndpoint),
        headers: {
          'Authorization': 'Bearer ${EnvConfig.philsmsApiKey.trim()}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'recipient': phone,
          'sender_id': EnvConfig.philsmsSenderId,
          'message': 'Gahira: Welcome! Access your profile with this temporary pass: $tempPassword',
        }),
      );

      if (response.statusCode >= 300) {
        // ROLLBACK: Revert status back to pending if SMS delivery fails
        await _client
            .from('applications')
            .update({
              'status': 'pending',
              'response_at': null,
            })
            .eq('application_id', applicationId);

        await _client
            .from('users')
            .update({'status': 'pending'})
            .eq('userId', userId);

        String errMsg = 'Failed to send SMS via PhilSMS.';
        try {
          final body = jsonDecode(response.body);
          if (body['message'] != null) {
            errMsg = 'PhilSMS Error: ${body['message']}';
          }
        } catch (_) {}
        return Left(ServerFailure('Rollback performed: $errMsg'));
      }

      return const Right(null);
    } catch (e) {
      // Rollback on unexpected exception
      try {
        await _client
            .from('applications')
            .update({
              'status': 'pending',
              'response_at': null,
            })
            .eq('application_id', applicationId);

        await _client
            .from('users')
            .update({'status': 'pending'})
            .eq('userId', userId);
      } catch (_) {}

      return Left(ServerFailure('Approval process failed: ${e.toString()}'));
    }
  }

  /// Updates application status and optionally user status
  Future<Either<Failure, void>> updateApplicationStatus({
    required String applicationId,
    required String userId,
    required String status,
  }) async {
    try {
      // If approving, we route through the backend to handle SMS and Auth update securely
      if (status == 'approved') {
        return approveApplication(applicationId: applicationId, userId: userId);
      }

      // For other statuses (like 'rejected'), we can still update DB directly or 
      // create a backend route if complex logic is needed.
      // Update application status
      await _client
          .from('applications')
          .update({
            'status': status,
            'response_at': DateTime.now().toIso8601String(),
          })
          .eq('application_id', applicationId);

      // Also update user status to match
      await _client
          .from('users')
          .update({'status': status})
          .eq('userId', userId);

      return const Right(null);
    } catch (e) {
      return Left(_mapError(e));
    }
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
