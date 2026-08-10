import 'package:dartz/dartz.dart';
import '../entities/user_entity.dart';
import '../../core/error/failures.dart';

abstract class UserRepository {
  Future<Either<Failure, UserEntity>> getUserById(String userId);
  Future<Either<Failure, List<UserEntity>>> getAllUsers();
  Future<Either<Failure, UserEntity>> updateUser(UserEntity user);
  Future<Either<Failure, void>> deleteUser(String userId);
}
