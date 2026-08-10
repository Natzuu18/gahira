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

  @override
  Future<Either<Failure, UserEntity>> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      final authUser = response.user;
      if (authUser == null) {
        return const Left(AuthFailure('Login failed: User not found'));
      }

      final userData = await _client
          .from('users')
          .select()
          .eq('userId', authUser.id)
          .maybeSingle();

      if (userData == null) {
        return const Left(
          ServerFailure('Account found but profile data is missing. Please contact support.'),
        );
      }

      return Right(UserModel.fromJson(userData));
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
      final response = await _client.auth.signUp(
        email: email,
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
        email: email,
        contactNum: contactNum,
        roleId: roleId,
        status: 'pending',
      );

      try {
        await _client.from('users').insert(newUser.toJson());
      } catch (insertError) {
        return Left(
          ServerFailure(
            'Account created but profile setup failed: ${insertError.toString()}. '
                'Please try logging in or contact support.',
          ),
        );
      }

      return Right(newUser);
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
          .select()
          .eq('userId', user.id)
          .maybeSingle();

      if (userData == null) return const Right(null);

      return Right(UserModel.fromJson(userData));
    } catch (e) {
      return Left(_mapError(e));
    }
  }
}