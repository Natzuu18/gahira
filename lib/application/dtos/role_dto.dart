import '../../domain/entities/role_entity.dart';

class RoleDto {
  final String roleId;
  final String role;
  final String status;

  const RoleDto({
    required this.roleId,
    required this.role,
    required this.status,
  });

  factory RoleDto.fromJson(Map<String, dynamic> json) {
    return RoleDto(
      roleId: json['role_id'] as String,
      role: json['role'] as String,
      status: json['status'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'role_id': roleId,
      'role': role,
      'status': status,
    };
  }

  factory RoleDto.fromEntity(RoleEntity entity) {
    return RoleDto(roleId: entity.roleId, role: entity.role, status: entity.status);
  }

  RoleEntity toEntity() {
    return RoleEntity(roleId: roleId, role: role, status: status);
  }
}