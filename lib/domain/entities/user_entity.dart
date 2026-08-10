import 'package:equatable/equatable.dart';

class UserEntity extends Equatable {
  final String userId;
  final String fname;
  final String? mname;
  final String lname;
  final String address;
  final String email;
  final String? password; // nullable — not persisted; Supabase Auth owns credential storage
  final String contactNum;
  final String roleId; // FK -> RoleEntity
  final String status; // e.g. active / inactive / pending

  const UserEntity({
    required this.userId,
    required this.fname,
    this.mname,
    required this.lname,
    required this.address,
    required this.email,
    this.password, // no longer required
    required this.contactNum,
    required this.roleId,
    required this.status,
  });

  @override
  List<Object?> get props => [
    userId,
    fname,
    mname,
    lname,
    address,
    email,
    password,
    contactNum,
    roleId,
    status,
  ];
}