import 'dart:math';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';
import 'package:http/http.dart' as http;
import 'package:dartz/dartz.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/error/failures.dart';
import '../../domain/entities/registration_data.dart';
import '../../domain/entities/registration_enums.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/registration_repository.dart';
import '../../core/config/env_config.dart';
import '../models/user_model.dart';
import '../supabase/supabase_config.dart';

class SupabaseRegistrationRepository implements RegistrationRepository {
  final SupabaseClient _client = SupabaseConfig.client;

  @override
  Future<Either<Failure, UserEntity>> register(RegistrationData data) async {
    try {
      // 0. Confirm phone verification actually happened for this exact phone
      // and token, server-side.
      final verification = await _client
          .from('phone_otp_verifications')
          .select()
          .eq('phone', _normalizePhone(data.phone))
          .eq('verification_token', data.phoneVerificationToken ?? '')
          .eq('verified', true)
          .eq('consumed', false)
          .maybeSingle();

      if (verification == null) {
        return const Left(AuthFailure('Phone number is not verified'));
      }
      if (DateTime.parse(verification['token_expires_at']).isBefore(DateTime.now())) {
        return const Left(AuthFailure('Phone verification expired, please verify again'));
      }

      // 1. Get the correct role_id from the role table
      // NOTE: table is "role" (singular) per schema, not "roles"
      final roleResult = await _client
          .from('role')
          .select('role_id')
          .eq('role', data.role.name)
          .single();

      final roleId = roleResult['role_id'];

      // 2. Generate a temporary password (since Supabase Auth requires one)
      final tempPassword = _generateRandomPassword();

      // 3. Sign up in Supabase Auth
      // Email is the auth identifier here. Phone is NOT passed to signUp() —
      // it's stored separately as a plain column in public.users below
      // (via newUser.toJson() -> contactNum), since GoTrue's signUp() rejects
      // requests that include both email and phone.
      final authResponse = await _client.auth.signUp(
        email: data.email,
        password: tempPassword,
      );

      final authUser = authResponse.user;
      if (authUser == null) {
        return const Left(AuthFailure('Auth registration failed'));
      }

      // 4. Create User Profile in 'users' table
      // NOTE: confirm UserModel.toJson() emits the PK key exactly as "userId"
      // (schema shows camelCase here, unlike every other table which is snake_case)
      final newUser = UserModel(
        userId: authUser.id,
        fname: data.firstName,
        mname: data.middleName,
        lname: data.lastName,
        address: data.address,
        email: data.email,
        contactNum: data.phone,
        roleId: roleId.toString(),
        status: 'pending',
      );

      await _client.from('users').insert(newUser.toJson());

      // 5. Handle File Uploads & Personal Details
      String? documentPath;
      if (data.role == UserRole.client && data.clientDocument != null) {
        final extension = data.clientDocumentName?.split('.').last ?? 'bin';
        documentPath = 'doc_${authUser.id}_${DateTime.now().millisecondsSinceEpoch}.$extension';
        
        await _client.storage.from('userFiles').uploadBinary(
          documentPath,
          data.clientDocument!,
          fileOptions: const FileOptions(contentType: 'application/octet-stream'),
        );

        await _client.from('personal_details').insert({
          'user_id': authUser.id,
          'document': _bytesToBytea(data.clientDocument!),
          'uploaded_at': DateTime.now().toIso8601String(),
        });
      } else if (data.role == UserRole.operator && data.resume != null) {
        final extension = data.resumeName?.split('.').last ?? 'bin';
        documentPath = 'resume_${authUser.id}_${DateTime.now().millisecondsSinceEpoch}.$extension';

        await _client.storage.from('userFiles').uploadBinary(
          documentPath,
          data.resume!,
          fileOptions: const FileOptions(contentType: 'application/octet-stream'),
        );

        await _client.from('personal_details').insert({
          'user_id': authUser.id,
          'document': _bytesToBytea(data.resume!),
          'uploaded_at': DateTime.now().toIso8601String(),
        });
      }

      // 6. Create initial application entry
      try {
        await _client.from('applications').insert({
          'user_id': authUser.id,
          'status': 'pending',
          'temp_pass': tempPassword,
          'document_id': documentPath, // Path to file in userFiles bucket
          'created_at': DateTime.now().toIso8601String(),
        });
      } catch (e) {
        // Rollback: delete the user if the application record fails
        await _client.from('users').delete().eq('userId', authUser.id);
        // Note: we can't easily delete from Supabase Auth without service role
        rethrow;
      }

      // Mark the verification token consumed so it can't be replayed.
      await _client
          .from('phone_otp_verifications')
          .update({'consumed': true})
          .eq('id', verification['id']);

      return Right(newUser);
    } on AuthException catch (e) {
      String message = e.message;
      if (message.toLowerCase().contains('account created')) {
        message = 'Registered successfully. Wait for the admin response';
      }
      return Left(AuthFailure(message));
    } on PostgrestException catch (e) {
      return Left(ServerFailure('Database error: ${e.message}'));
    } catch (e) {
      if (e.toString().contains('SocketException')) {
        return const Left(NetworkFailure('Network unreachable'));
      }
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> sendPhoneOtp(String phoneNumber) async {
    String? insertedId;
    try {
      final phone = _normalizePhone(phoneNumber);

      // 1. Generate a random 6-digit PIN
      final pin = (100000 + Random().nextInt(900000)).toString();

      // 2. Hash the PIN using SHA-256 for secure storage
      final pinHash = sha256.convert(utf8.encode(pin)).toString();

      // 3. Store the hashed PIN in the 'phone_otp_verifications' table
      // We select the ID so we can rollback (delete) if the SMS fails.
      final insertResponse = await _client.from('phone_otp_verifications').insert({
        'phone': phone,
        'otp_hash': pinHash,
        'otp_expires_at':
            DateTime.now().add(const Duration(minutes: 5)).toIso8601String(),
        'attempts': 0,
        'verified': false,
        'consumed': false,
      }).select('id').single();
      
      insertedId = insertResponse['id'].toString();

      // 4. Send the raw PIN to the user via PhilSMS
      final response = await http.post(
        Uri.parse(EnvConfig.philsmsEndpoint),
        headers: {
          'Authorization': 'Bearer ${EnvConfig.philsmsApiKey.trim()}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'recipient': phone,
          'sender_id': EnvConfig.philsmsSenderId,
          'message': 'Gahira: $pin is your confirmation code. Valid for 5 mins.',
        }),
      );

      if (response.statusCode >= 300) {
        // ROLLBACK: Delete the verification record since SMS failed
        if (insertedId != null) {
          await _client.from('phone_otp_verifications').delete().eq('id', insertedId);
        }

        String errMsg = 'Failed to send SMS via PhilSMS.';
        try {
          final body = jsonDecode(response.body);
          if (body['message'] != null) {
            errMsg = 'PhilSMS Error: ${body['message']}';
          }
        } catch (_) {}
        return Left(ServerFailure(errMsg));
      }

      return const Right(null);
    } catch (e) {
      // ROLLBACK on unexpected error
      if (insertedId != null) {
        await _client.from('phone_otp_verifications').delete().eq('id', insertedId);
      }
      return Left(ServerFailure('OTP process failed: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, String>> verifyPhoneOtp({
    required String phoneNumber,
    required String code,
  }) async {
    try {
      final phone = _normalizePhone(phoneNumber);

      // 1. Look up the most recent unverified row for this phone
      final List<dynamic> rows = await _client
          .from('phone_otp_verifications')
          .select()
          .eq('phone', phone)
          .eq('verified', false)
          .order('created_at', ascending: false)
          .limit(1);

      if (rows.isEmpty) {
        return const Left(
            AuthFailure('No pending verification for this number'));
      }
      final row = rows.first as Map<String, dynamic>;

      // 2. Check if code has expired (5 min TTL)
      final expiresAt = DateTime.parse(row['otp_expires_at'] as String);
      if (expiresAt.isBefore(DateTime.now())) {
        return const Left(AuthFailure('Code expired, request a new one'));
      }

      // 3. Check attempt count (max 5)
      final attempts = row['attempts'] as int;
      if (attempts >= 5) {
        return const Left(
            AuthFailure('Too many attempts, request a new code'));
      }

      // 4. Compare hashed input with stored hash
      final inputHash = sha256.convert(utf8.encode(code)).toString();
      if (inputHash != row['otp_hash']) {
        await _client
            .from('phone_otp_verifications')
            .update({'attempts': attempts + 1}).eq('id', row['id']);
        return const Left(AuthFailure('Incorrect code'));
      }

      // 5. On success: Mark verified, generate token, set token expiry
      final token = const Uuid().v4().replaceAll('-', '');
      await _client.from('phone_otp_verifications').update({
        'verified': true,
        'verification_token': token,
        'token_expires_at':
            DateTime.now().add(const Duration(minutes: 15)).toIso8601String(),
      }).eq('id', row['id']);

      return Right(token);
    } catch (e) {
      return Left(AuthFailure('Verification failed: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, List<Map<String, dynamic>>>> getAvailableSlots() async {
    try {
      final response = await _client
          .from('appointment_availability')
          .select()
          .eq('status', 'open')
          .order('date', ascending: true);

      return Right(List<Map<String, dynamic>>.from(response));
    } catch (e) {
      return Left(ServerFailure('Failed to fetch availability: ${e.toString()}'));
    }
  }

  String _generateRandomPassword() {
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#\$';
    return List.generate(12, (index) => chars[Random().nextInt(chars.length)]).join();
  }

  // Postgres bytea over PostgREST expects hex format: "\x" followed by the
  // hex-encoded bytes (e.g. "\xdeadbeef"). Plain base64 or raw byte lists
  // will be rejected/mis-stored, so encode explicitly here.
  String _bytesToBytea(List<int> bytes) {
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '\\x$hex';
  }

  String _normalizePhone(String raw) {
    final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.startsWith('63')) return digits;
    if (digits.startsWith('0')) return '63${digits.substring(1)}';
    if (digits.startsWith('9')) return '63$digits';
    return digits;
  }
}
