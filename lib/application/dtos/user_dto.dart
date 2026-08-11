import '../../domain/entities/user_entity.dart';

class UserDto {
  final String userId;
  final String fname;
  final String? mname;
  final String lname;
  final String address;
  final String email;
  final String password;
  final String contactNum;
  final String roleId;
  final String status;

  const UserDto({
    required this.userId,
    required this.fname,
    this.mname,
    required this.lname,
    required this.address,
    required this.email,
    required this.password,
    required this.contactNum,
    required this.roleId,
    required this.status,
  });

  factory UserDto.fromJson(Map<String, dynamic> json) {
    return UserDto(
      userId: json['userId'] as String,
      fname: json['fname'] as String,
      mname: json['mname'] as String?,
      lname: json['lname'] as String,
      address: json['address'] as String,
      email: json['email'] as String,
      password: json['password'] as String,
      contactNum: json['contact_Num'] as String,
      roleId: json['role'] as String,
      status: json['status'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'fname': fname,
      'mname': mname,
      'lname': lname,
      'address': address,
      'email': email,
      'password': password,
      'contact_Num': contactNum,
      'role': roleId,
      'status': status,
    };
  }

  factory UserDto.fromEntity(UserEntity entity) {
    return UserDto(
      userId: entity.userId,
      fname: entity.fname,
      mname: entity.mname,
      lname: entity.lname,
      address: entity.address,
      email: entity.email,
      password: entity.password ?? 'gahira123!',
      contactNum: entity.contactNum,
      roleId: entity.roleId,
      status: entity.status,
    );
  }

  UserEntity toEntity() {
    return UserEntity(
      userId: userId,
      fname: fname,
      mname: mname,
      lname: lname,
      address: address,
      email: email,
      password: password,
      contactNum: contactNum,
      roleId: roleId,
      status: status,
    );
  }
}
