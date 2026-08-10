import 'package:dartz/dartz.dart';
import '../../core/error/failures.dart';
import '../../domain/repositories/user_repository.dart';
import '../dtos/user_dto.dart';

class UserService {
  final UserRepository repository;
  UserService(this.repository);

  Future<Either<Failure, UserDto>> getUserById(String userId) async {
    final result = await repository.getUserById(userId);
    return result.map((entity) => UserDto.fromEntity(entity));
  }

  Future<Either<Failure, List<UserDto>>> getAllUsers() async {
    final result = await repository.getAllUsers();
    return result.map((entities) => entities.map((e) => UserDto.fromEntity(e)).toList());
  }

  Future<Either<Failure, UserDto>> updateUser(UserDto user) async {
    final result = await repository.updateUser(user.toEntity());
    return result.map((entity) => UserDto.fromEntity(entity));
  }

  Future<Either<Failure, void>> deleteUser(String userId) {
    return repository.deleteUser(userId);
  }
}
