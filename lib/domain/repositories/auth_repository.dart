import 'package:dartz/dartz.dart';
import '../../domain/entities/user_entity.dart';
import '../../core/error/failures.dart';
abstract class AuthRepository {
  /// Logs a user in with email + password.
  /// Returns the authenticated [UserEntity] on success.
  Future<Either<Failure, UserEntity>> login({
    required String email,
    required String password,
  });

  /// Registers a new user with a default/initial password.
  /// Returns the newly created [UserEntity] on success.
  Future<Either<Failure, UserEntity>> signUp({
    required String fname,
    String? mname,
    required String lname,
    required String address,
    required String email,
    required String password, // default password, hashed downstream
    required String contactNum,
    required String roleId,
  });

  /// Optional but commonly paired with login/signup — logs the current user out.
  Future<Either<Failure, void>> logout();

  /// Optional — checks if a user session already exists (auto-login on app start).
  Future<Either<Failure, UserEntity?>> getCurrentUser();
}