import 'package:dartz/dartz.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/error/failures.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../models/user_model.dart';
import '../supabase/supabase_config.dart';

class SupabaseAuthRepository implements AuthRepository {
  final SupabaseClient _client = SupabaseConfig.client;

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

      if (response.user == null) {
        return const Left(AuthFailure('Login failed: User not found'));
      }

      // Fetch additional user info from our 'users' table
      final userData = await _client
          .from('users')
          .select()
          .eq('userId', response.user!.id)
          .single();

      return Right(UserModel.fromJson(userData));
    } on AuthException catch (e) {
      return Left(AuthFailure(e.message));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
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

      if (response.user == null) {
        return const Left(AuthFailure('Sign up failed'));
      }

      final newUser = UserModel(
        userId: response.user!.id,
        fname: fname,
        mname: mname,
        lname: lname,
        address: address,
        email: email,
        password: password, // Note: In a real app, you might not store the raw password in the DB
        contactNum: contactNum,
        roleId: roleId,
        status: 'pending',
      );

      await _client.from('users').insert(newUser.toJson());

      return Right(newUser);
    } on AuthException catch (e) {
      return Left(AuthFailure(e.message));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> logout() async {
    try {
      await _client.auth.signOut();
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
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
      return Left(ServerFailure(e.toString()));
    }
  }
}
