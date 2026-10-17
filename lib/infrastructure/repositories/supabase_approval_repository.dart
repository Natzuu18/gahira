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
      if (e.message.contains('SMS Delivery Failed')) {
        return ServerFailure('SMS Delivery Failed: The request was rolled back. Please check the recipient\'s number or try again later.');
      }
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

  /// Consolidates approval logic via backend and sends approval SMS via PhilSMS directly
  Future<Either<Failure, void>> approveApplication({
    required String applicationId,
    required String userId,
  }) async {
    try {
      // 1. Fetch user details and application temp password
      final userResponse = await _client
          .from('users')
          .select('contact_num, email, fname, role:role_id(role)')
          .eq('userId', userId)
          .single();

      final appResponse = await _client
          .from('applications')
          .select('temp_pass')
          .eq('application_id', applicationId)
          .maybeSingle();
      
      String phone = userResponse['contact_num'] ?? '';
      String normalizedPhone = _normalizePhone(phone);
      
      // PhilSMS requires a valid 12-digit number starting with 639
      if (normalizedPhone.length < 12) {
        return Left(ServerFailure('Invalid phone number: "$phone". SMS cannot be sent. Please update the user\'s contact info to a valid format (e.g., 09123456789) first.'));
      }

      // 2. Update the phone number in the DB to the normalized version to ensure PhilSMS success
      if (normalizedPhone != phone) {
        await _client
            .from('users')
            .update({'contact_num': normalizedPhone})
            .eq('userId', userId);
      }

      // 3. Get or generate the temporary password
      String? existingPass = appResponse?['temp_pass']?.toString();
      final tempPassword = (existingPass != null && existingPass.trim().isNotEmpty)
          ? existingPass.trim()
          : _generateRandomPassword();

      // 4. Update Auth and DB status
      try {
        await _client.rpc(
          'approve_application_with_pass',
          params: {
            'app_id': applicationId,
            'u_id': userId,
            'new_pass': tempPassword,
          },
        );
      } catch (_) {
        // Fallback to direct table updates if RPC function is missing or fails
        await _client
            .from('applications')
            .update({
              'status': 'approved',
              'temp_pass': tempPassword,
              'response_at': DateTime.now().toIso8601String(),
            })
            .eq('application_id', applicationId);

        await _client
            .from('users')
            .update({'status': 'approved'})
            .eq('userId', userId);
      }

      // 5. Send SMS notification to the user via PhilSMS
      final fname = userResponse['fname'] ?? 'User';
      final email = userResponse['email'] ?? '';
      final roleMap = userResponse['role'] as Map<String, dynamic>?;
      final roleName = roleMap?['role']?.toString().toUpperCase() ?? 'ACCOUNT';

      final smsMessage = 'Gahira System: Hello $fname! Your $roleName application has been APPROVED. You can now log in using Email: $email | Password: $tempPassword. Thank you!';

      final smsResponse = await http.post(
        Uri.parse(EnvConfig.philsmsEndpoint),
        headers: {
          'Authorization': 'Bearer ${EnvConfig.philsmsApiKey.trim()}',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'recipient': normalizedPhone,
          'sender_id': EnvConfig.philsmsSenderId,
          'message': smsMessage,
        }),
      );

      if (smsResponse.statusCode >= 300) {
        String errMsg = 'Failed to send SMS via PhilSMS.';
        try {
          final body = jsonDecode(smsResponse.body);
          if (body['message'] != null) {
            errMsg = 'PhilSMS Error: ${body['message']}';
          }
        } catch (_) {}
        return Left(ServerFailure('Application approved in system, but SMS failed: $errMsg'));
      }

      try {
        final body = jsonDecode(smsResponse.body);
        if (body['status'] == 'error' || body['status'] == 'failed') {
          final msg = body['message'] ?? 'PhilSMS delivery error';
          return Left(ServerFailure('Application approved in system, but PhilSMS returned: $msg'));
        }
      } catch (_) {}

      return const Right(null);
    } catch (e) {
      return Left(_mapError(e));
    }
  }

  /// Updates application status and optionally user status
  Future<Either<Failure, void>> updateApplicationStatus({
    required String applicationId,  
    required String userId,
    required String status,
    String? reason,
  }) async {
    try {
      // If approving, we route through the backend to handle SMS and Auth update securely
      if (status == 'approved') {
        return approveApplication(applicationId: applicationId, userId: userId);
      }

      if (status == 'rejected') {
        return rejectApplication(
          applicationId: applicationId,
          userId: userId,
          reason: reason ?? 'Application requirements not met',
        );
      }

      // For other statuses, update DB directly
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

  /// Declines / rejects an application, updates database status, and sends SMS with reason
  Future<Either<Failure, void>> rejectApplication({
    required String applicationId,
    required String userId,
    required String reason,
  }) async {
    try {
      // 1. Fetch user details
      final userResponse = await _client
          .from('users')
          .select('contact_num, fname, role:role_id(role)')
          .eq('userId', userId)
          .single();

      String phone = userResponse['contact_num'] ?? '';
      String normalizedPhone = _normalizePhone(phone);

      // 2. Update DB status to 'rejected'
      await _client
          .from('applications')
          .update({
            'status': 'rejected',
            'appointment_remarks': 'Declined reason: $reason',
            'response_at': DateTime.now().toIso8601String(),
          })
          .eq('application_id', applicationId);

      await _client
          .from('users')
          .update({'status': 'rejected'})
          .eq('userId', userId);

      // 3. Send SMS if valid phone number is available
      if (normalizedPhone.length >= 12) {
        final fname = userResponse['fname'] ?? 'User';
        final roleMap = userResponse['role'] as Map<String, dynamic>?;
        final roleName = roleMap?['role']?.toString().toUpperCase() ?? 'ACCOUNT';

        final smsMessage = 'Gahira System: Hello $fname! Your $roleName application was DECLINED. Reason: $reason. For inquiries, please contact support.';

        final smsResponse = await http.post(
          Uri.parse(EnvConfig.philsmsEndpoint),
          headers: {
            'Authorization': 'Bearer ${EnvConfig.philsmsApiKey.trim()}',
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: jsonEncode({
            'recipient': normalizedPhone,
            'sender_id': EnvConfig.philsmsSenderId,
            'message': smsMessage,
          }),
        );

        if (smsResponse.statusCode >= 300) {
          String errMsg = 'Failed to send SMS via PhilSMS.';
          try {
            final body = jsonDecode(smsResponse.body);
            if (body['message'] != null) {
              errMsg = 'PhilSMS Error: ${body['message']}';
            }
          } catch (_) {}
          return Left(ServerFailure('Application declined in DB, but SMS failed: $errMsg'));
        }
      }

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
            userId,
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
            userId,
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
          .eq('userId', userId);

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
          .eq('userId', userId);

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

  String _generateRandomPassword() {
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    return List.generate(10, (index) => chars[Random().nextInt(chars.length)]).join();
  }
}
