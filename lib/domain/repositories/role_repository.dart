import 'package:dartz/dartz.dart';
import '../entities/role_entity.dart';
import '../../core/error/failures.dart';

abstract class RoleRepository {
  Future<Either<Failure, List<RoleEntity>>> getRoles();
  Future<Either<Failure, RoleEntity>> getRoleById(String roleId);
}
