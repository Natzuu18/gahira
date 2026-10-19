import '../../domain/entities/user_entity.dart';

class UserModel extends UserEntity {
  const UserModel({
    required super.userId,
    required super.fname,
    super.mname,
    required super.lname,
    required super.address,
    required super.email,
    super.password,
    required super.contactNum,
    required super.roleId,
    required super.status,
    super.miningUnitId,
    super.miningUnitName,
    super.miningUnitType,
    super.pinHash,
    super.createdAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    DateTime? parsedCreatedAt;
    if (json['created_at'] != null) {
      parsedCreatedAt = DateTime.tryParse(json['created_at'].toString());
    } else if (json['applications'] != null) {
      final apps = json['applications'];
      if (apps is List && apps.isNotEmpty) {
        final respAt = apps[0]['response_at'] ?? apps[0]['created_at'];
        if (respAt != null) parsedCreatedAt = DateTime.tryParse(respAt.toString());
      } else if (apps is Map && (apps['response_at'] != null || apps['created_at'] != null)) {
        final respAt = apps['response_at'] ?? apps['created_at'];
        if (respAt != null) parsedCreatedAt = DateTime.tryParse(respAt.toString());
      }
    }

    return UserModel(
      userId: (json['userId'] ?? json['userid'] ?? json['user_id'] ?? '').toString(),
      fname: json['fname'] ?? '',
      mname: json['mname'],
      lname: json['lname'] ?? '',
      address: json['address'] ?? '',
      email: json['email'] ?? '',
      // password intentionally not read back — it's never stored in this table
      contactNum: json['contact_num'] ?? '',
      roleId: (json['role_id'] ?? json['role'] ?? '').toString(),
      status: json['status'] ?? '',
      miningUnitId: json['mining_unit_id'],
      miningUnitName: json['mining_unit_name'] ?? (json['mining_units'] != null ? json['mining_units']['name'] : null),
      miningUnitType: json['mining_unit_type'] ?? (json['mining_units'] != null ? json['mining_units']['type'] : null),
      pinHash: json['pin_hash'],
      createdAt: parsedCreatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'userId': userId,
      'fname': fname,
      'mname': mname,
      'lname': lname,
      'address': address,
      'email': email,
      // 'password' deliberately omitted
      'contact_num': contactNum,
      'role_id': roleId,
      'status': status,
      'mining_unit_id': miningUnitId,
      'pin_hash': pinHash,
    };
    if (createdAt != null) {
      map['created_at'] = createdAt!.toIso8601String();
    }
    return map;
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
      miningUnitId: entity.miningUnitId,
      miningUnitName: entity.miningUnitName,
      miningUnitType: entity.miningUnitType,
      pinHash: entity.pinHash,
      createdAt: entity.createdAt,
    );
  }
}
