import 'dart:io';
import 'dart:math';
import 'package:dartz/dartz.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/error/failures.dart';
import '../../domain/entities/registration_data.dart';
import '../../domain/entities/registration_enums.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/registration_repository.dart';
import '../models/user_model.dart';
import '../supabase/supabase_config.dart';

class SupabaseRegistrationRepository implements RegistrationRepository {
  final SupabaseClient _client = SupabaseConfig.client;

  @override
  Future<Either<Failure, UserEntity>> register(RegistrationData data) async {
    try {
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
      // Schema: personal_details(document_id uuid PK, user_id uuid, document bytea, uploaded_at timestamptz)
      // The table has NO "document_path" column — files are kept in Storage for
      // retrieval, but the actual bytes must still be written into the
      // "document" bytea column to satisfy the schema. document_id is left
      // out so the DB can generate it (uuid PK).
      if (data.role == UserRole.client && data.clientDocument != null) {
        final fileName = 'doc_${authUser.id}_${DateTime.now().millisecondsSinceEpoch}';
        await _client.storage.from('userFiles').uploadBinary(
          fileName,
          data.clientDocument!,
          fileOptions: const FileOptions(contentType: 'application/octet-stream'),
        );

        await _client.from('personal_details').insert({
          'user_id': authUser.id,
          'document': _bytesToBytea(data.clientDocument!),
          'uploaded_at': DateTime.now().toIso8601String(),
        });
      } else if (data.role == UserRole.operator && data.resume != null) {
        final fileName = 'resume_${authUser.id}_${DateTime.now().millisecondsSinceEpoch}';
        await _client.storage.from('userFiles').uploadBinary(
          fileName,
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
      // Schema: applications(application_id, user_id, created_at, response_at, status)
      // There is no appointment_date column — if you need to persist that,
      // add the column to the table first.
      await _client.from('applications').insert({
        'user_id': authUser.id,
        'status': 'pending',
        'created_at': DateTime.now().toIso8601String(),
      });

      return Right(newUser);
    } on AuthException catch (e) {
      return Left(AuthFailure(e.message));
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
    try {
      await _client.auth.signInWithOtp(
        phone: phoneNumber,
        shouldCreateUser: false, // Only verifying number for now
      );
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure('Failed to send OTP: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, bool>> verifyPhoneOtp({
    required String phoneNumber,
    required String code,
  }) async {
    try {
      final response = await _client.auth.verifyOTP(
        phone: phoneNumber,
        token: code,
        type: OtpType.sms,
      );
      return Right(response.user != null || response.session != null);
    } catch (e) {
      return const Left(AuthFailure('Invalid or expired OTP code'));
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
}