import 'package:dartz/dartz.dart';
import '../../core/error/failures.dart';
import '../../domain/repositories/role_repository.dart';
import '../dtos/role_dto.dart';

class RoleService {
  final RoleRepository repository;
  RoleService(this.repository);

  Future<Either<Failure, List<RoleDto>>> getRoles() async {
    final result = await repository.getRoles();
    return result.map((entities) => entities.map((e) => RoleDto.fromEntity(e)).toList());
  }

  Future<Either<Failure, RoleDto>> getRoleById(String roleId) async {
    final result = await repository.getRoleById(roleId);
    return result.map((entity) => RoleDto.fromEntity(entity));
  }
}
