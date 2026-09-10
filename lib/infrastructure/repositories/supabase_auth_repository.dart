import 'dart:io';
import 'package:dartz/dartz.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/error/failures.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../models/user_model.dart';
import '../supabase/supabase_config.dart';

class SupabaseAuthRepository implements AuthRepository {
  final SupabaseClient _client = SupabaseConfig.client;

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

  /// Normalizes email input so signup/login always compare the same string
  /// (avoids "invalid credentials" caused purely by case/whitespace drift).
  String _normalizeEmail(String email) => email.trim().toLowerCase();

  Failure _mapError(Object e) {
    if (e is SocketException) {
      return NetworkFailure('No internet connection: ${e.message}');
    }
    if (e is AuthException) {
      // Supabase returns this specific message when the account exists
      // but the email hasn't been confirmed yet. Surface it distinctly
      // instead of letting it fall through as a generic AuthFailure.
      final lower = e.message.toLowerCase();
      if (lower.contains('email not confirmed') ||
          lower.contains('confirm your email')) {
        return AuthFailure(
          'Please confirm your email before logging in. Check your inbox for the confirmation link.',
        );
      }
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

  @override
  Future<Either<Failure, UserEntity>> login({
    required String email,
    required String password,
  }) async {
    try {
      final normalizedEmail = _normalizeEmail(email);

      final response = await _client.auth.signInWithPassword(
        email: normalizedEmail,
        password: password,
      );

      final authUser = response.user;
      if (authUser == null) {
        return const Left(AuthFailure('Login failed: User not found'));
      }

      final userData = await _client
          .from('users')
          .select('*, role:role_id(role)')
          .eq('userId', authUser.id)
          .maybeSingle();

      if (userData == null) {
        return const Left(
          ServerFailure('Account found but profile data is missing. Please contact support.'),
        );
      }

      // Check if account is still pending approval
      if (userData['status'] == 'pending') {
        await _client.auth.signOut();
        return const Left(
          AuthFailure('Your application is still pending. Please wait for admin to response.'),
        );
      }

      if (userData['status'] == 'rejected') {
        await _client.auth.signOut();
        return const Left(
          AuthFailure('Your application was rejected. Please contact support for more information.'),
        );
      }

      final updatedUserData = Map<String, dynamic>.from(userData);
      
      // Check if password change is required (first login after approval)
      if (userData['status'] == 'approved') {
        updatedUserData['role_id'] = 'change_password_required';
      } else {
        // Extract the role name from the joined 'role' table for normal users
        final roleData = userData['role'] as Map<String, dynamic>?;
        final roleName = roleData != null ? roleData['role'] as String? : null;
        if (roleName != null) {
          updatedUserData['role_id'] = roleName;
        }
      }

      print('Fetched User: ${authUser.email}, Status: ${userData['status']}, Role Assigned: ${updatedUserData['role_id']}');

      return Right(UserModel.fromJson(updatedUserData));
    } catch (e) {
      return Left(_mapError(e));
    }
  }

  @override
  Future<Either<Failure, UserEntity>> signUp({
    required String fname,
    String? mname,
    required String lname,
    required String address,
    required String email,
    required String password,
    required String contactNum,
    required String roleId,
  }) async {
    try {
      final normalizedEmail = _normalizeEmail(email);

      final response = await _client.auth.signUp(
        email: normalizedEmail,
        password: password,
      );

      final authUser = response.user;
      if (authUser == null) {
        return const Left(AuthFailure('Sign up failed'));
      }

      final newUser = UserModel(
        userId: authUser.id,
        fname: fname,
        mname: mname,
        lname: lname,
        address: address,
        email: normalizedEmail,
        contactNum: contactNum,
        roleId: roleId,
        status: 'pending',
      );

      try {
        await _client.from('users').insert(newUser.toJson());
      } catch (insertError) {
        return Left(
          ServerFailure(
            'Application submitted but profile setup failed: ${insertError.toString()}. '
                'Please contact support.',
          ),
        );
      }

      // response.session is null when the Supabase project requires email
      // confirmation. The auth user + profile row both got created, but the
      // account can't log in yet, so tell the caller explicitly instead of
      // reporting a plain success that leads to a confusing "invalid
      // credentials" on the very next login attempt.
      if (response.session == null) {
        return const Left(
          AuthFailure(
            'Application submitted. Please check your email to confirm your address, then wait for admin response.',
          ),
        );
      }

      return Right(newUser);
    } catch (e) {
      return Left(_mapError(e));
    }
  }

  @override
  Future<Either<Failure, void>> updatePassword(String newPassword) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return const Left(AuthFailure('No user logged in.'));

      // 1. Update the password in Supabase Auth
      await _client.auth.updateUser(UserAttributes(password: newPassword));

      // 2. Update status to 'active' in public.users table
      // This marks the "1st login/change password" as completed.
      await _client
          .from('users')
          .update({'status': 'active'})
          .eq('userId', user.id);

      return const Right(null);
    } catch (e) {
      return Left(_mapError(e));
    }
  }

  @override
  Future<Either<Failure, void>> logout() async {
    try {
      await _client.auth.signOut();
      return const Right(null);
    } catch (e) {
      return Left(_mapError(e));
    }
  }

  @override
  Future<Either<Failure, UserEntity?>> getCurrentUser() async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return const Right(null);

      final userData = await _client
          .from('users')
          .select('*, role:role_id(role)')
          .eq('userId', user.id)
          .maybeSingle();

      if (userData == null) return const Right(null);

      // Extract the role name from the joined 'role' table
      final roleData = userData['role'] as Map<String, dynamic>?;
      final roleName = roleData != null ? roleData['role'] as String? : null;

      final updatedUserData = Map<String, dynamic>.from(userData);
      if (roleName != null) {
        updatedUserData['role_id'] = roleName;
      }

      print('Current User: ${user.email}, Role ID: ${userData['role_id']}, Role Name: $roleName');

      return Right(UserModel.fromJson(updatedUserData));
    } catch (e) {
      return Left(_mapError(e));
    }
  }
}