import 'package:dartz/dartz.dart';
import '../../core/error/failures.dart';
import '../../domain/repositories/auth_repository.dart';
import '../dtos/login_request_dto.dart';
import '../dtos/signup_request_dto.dart';
import '../dtos/user_dto.dart';

class AuthService {
  final AuthRepository repository;
  AuthService(this.repository);

  Future<Either<Failure, UserDto>> login(LoginRequestDto request) async {
    final result = await repository.login(email: request.email, password: request.password);
    return result.map((entity) => UserDto.fromEntity(entity));
  }

  Future<Either<Failure, UserDto>> signUp(SignUpRequestDto request) async {
    final result = await repository.signUp(
      fname: request.fname,
      mname: request.mname,
      lname: request.lname,
      address: request.address,
      email: request.email,
      password: request.password,
      contactNum: request.contactNum,
      roleId: request.roleId,
    );
    return result.map((entity) => UserDto.fromEntity(entity));
  }

  Future<Either<Failure, void>> logout() => repository.logout();

  Future<Either<Failure, UserDto?>> getCurrentUser() async {
    final result = await repository.getCurrentUser();
    return result.fold(
      (failure) => Left(failure),
      (entity) => Right(entity != null ? UserDto.fromEntity(entity) : null),
    );
  }
}
