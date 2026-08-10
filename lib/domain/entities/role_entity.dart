import 'package:equatable/equatable.dart';

class RoleEntity extends Equatable {
  final String roleId;
  final String role;   // e.g. Admin, Staff, Applicant
  final String status; // active / inactive

  const RoleEntity({
    required this.roleId,
    required this.role,
    required this.status,
  });

  @override
  List<Object?> get props => [roleId, role, status];
}