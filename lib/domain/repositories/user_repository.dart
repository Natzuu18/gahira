import 'package:dartz/dartz.dart';
import '../entities/user_entity.dart';
import '../../core/error/failures.dart';

import '../../domain/entities/registration_enums.dart';

abstract class UserRepository {
  Future<Either<Failure, UserEntity>> getUserById(String userId);
  Future<Either<Failure, List<UserEntity>>> getAllUsers();
  Future<Either<Failure, UserEntity>> updateUser(UserEntity user);
  Future<Either<Failure, void>> deleteUser(String userId);
  Future<Either<Failure, void>> addUserByAdmin({
    required String firstName,
    String? middleName,
    required String lastName,
    required String phone,
    required String email,
    required String address,
    required UserRole role,
    String? miningUnitId,
  });
  Future<Either<Failure, void>> updateUserPin(String userId, String pin);
}
