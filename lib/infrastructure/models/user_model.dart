import '../../domain/entities/user_entity.dart';

class UserModel extends UserEntity {
  const UserModel({
    required super.userId,
    required super.fname,
    super.mname,
    required super.lname,
    required super.address,
    required super.email,
    required super.password,
    required super.contactNum,
    required super.roleId,
    required super.status,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      userId: json['userId'] ?? '',
      fname: json['fname'] ?? '',
      mname: json['mname'],
      lname: json['lname'] ?? '',
      address: json['address'] ?? '',
      email: json['email'] ?? '',
      password: json['password'] ?? '',
      contactNum: json['contact_Num'] ?? '',
      roleId: json['role'] ?? '',
      status: json['status'] ?? '',
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

  factory UserModel.fromEntity(UserEntity entity) {
    return UserModel(
      userId: entity.userId,
      fname: entity.fname,
      mname: entity.mname,
      lname: entity.lname,
      address: entity.address,
      email: entity.email,
      password: entity.password,
      contactNum: entity.contactNum,
      roleId: entity.roleId,
      status: entity.status,
    );
  }
}
