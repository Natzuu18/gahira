import 'dart:math';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:dartz/dartz.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/error/failures.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/entities/registration_enums.dart';
import '../../domain/repositories/user_repository.dart';
import '../models/user_model.dart';
import '../supabase/supabase_config.dart';

class SupabaseUserRepository implements UserRepository {
  final SupabaseClient _client = SupabaseConfig.client;

  @override
  Future<Either<Failure, List<UserEntity>>> getAllUsers() async {
    try {
      final response = await _client
          .from('users')
          .select('*, role:role_id(role), mining_units:mining_unit_id(name, type), pin_hash')
          .order('fname', ascending: true);

      final List<UserEntity> users = (response as List)
          .map((json) {
            final data = Map<String, dynamic>.from(json);
            final roleName = data['role'] != null ? data['role']['role'] : '';
            data['role_id'] = roleName; // Map role name to role_id for entity
            return UserModel.fromJson(data);
          })
          .toList();

      return Right(users);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  Future<Either<Failure, List<UserEntity>>> getMinersAndClients() async {
    try {
      // Role IDs from screenshot: 
      // Miner: 5ef69f93-cb07-4052-989e-9e6ca48c4360
      // Operator: 91fb0b2f-f627-4234-ae38-2a305a799ff4
      
      final response = await _client
          .from('users')
          .select('*, role:role_id(role), mining_units:mining_unit_id(name, type), pin_hash')
          .or('status.eq.approved,status.eq.active,status.eq.inactive')
          .inFilter('role_id', [
            '5ef69f93-cb07-4052-989e-9e6ca48c4360', // miner
            '91fb0b2f-f627-4234-ae38-2a305a799ff4'  // operator
          ])
          .order('fname', ascending: true);

      final List<UserEntity> users = (response as List)
          .map((json) {
            final data = Map<String, dynamic>.from(json);
            final roleName = data['role'] != null ? data['role']['role'] : '';
            data['role_id'] = roleName;
            return UserModel.fromJson(data);
          })
          .toList();

      return Right(users);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  Future<Either<Failure, List<UserEntity>>> getInactiveUsers() async {
    try {
      final response = await _client
          .from('users')
          .select('*, role:role_id(role), mining_units:mining_unit_id(name, type), pin_hash')
          .eq('status', 'inactive')
          .order('fname', ascending: true);

      final List<UserEntity> users = (response as List)
          .map((json) {
            final data = Map<String, dynamic>.from(json);
            final roleName = data['role'] != null ? data['role']['role'] : '';
            data['role_id'] = roleName;
            return UserModel.fromJson(data);
          })
          .toList();

      return Right(users);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  Future<Either<Failure, List<UserEntity>>> getOperators() async {
    try {
      final response = await _client
          .from('users')
          .select('*, role:role_id(role), mining_units:mining_unit_id(name, type), pin_hash')
          .eq('role_id', '91fb0b2f-f627-4234-ae38-2a305a799ff4') // operator
          .order('fname', ascending: true);

      final List<UserEntity> users = (response as List)
          .map((json) {
            final data = Map<String, dynamic>.from(json);
            final roleName = data['role'] != null ? data['role']['role'] : '';
            data['role_id'] = roleName;
            return UserModel.fromJson(data);
          })
          .toList();

      return Right(users);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  Future<Either<Failure, void>> updateUserStatus(String userId, String status) async {
    try {
      await _client.from('users').update({'status': status}).eq('userId', userId);
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> addUserByAdmin({
    required String firstName,
    String? middleName,
    required String lastName,
    required String phone,
    required String email,
    required String address,
    required UserRole role,
    String? miningUnitId,
  }) async {
    try {
      final tempPassword = _generateRandomPassword();
      
      // Map enum to the corresponding Role ID from your database
      String roleId = '';
      switch (role) {
        case UserRole.operator:
          roleId = '91fb0b2f-f627-4234-ae38-2a305a799ff4';
          break;
        case UserRole.miner:
        case UserRole.client:
          roleId = '5ef69f93-cb07-4052-989e-9e6ca48c4360'; 
          break;
      }

      // Call the updated RPC to handle direct user creation and SMS sending
      await _client.rpc(
        'add_user_by_admin_rpc',
        params: {
          'u_email': email,
          'u_phone': phone,
          'u_fname': firstName,
          'u_mname': middleName ?? '',
          'u_lname': lastName,
          'u_address': address,
          'u_pass': tempPassword,
          'u_role_id': roleId,
          'u_mining_unit_id': miningUnitId,
        },
      );

      return const Right(null);
    } on PostgrestException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  Future<Either<Failure, List<Map<String, dynamic>>>> getMiningUnits() async {
    try {
      final response = await _client
          .from('mining_units')
          .select()
          .order('name', ascending: true);
      return Right(List<Map<String, dynamic>>.from(response));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  String _generateRandomPassword() {
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    return List.generate(8, (index) => chars[Random().nextInt(chars.length)]).join();
  }

  @override
  Future<Either<Failure, UserEntity>> getUserById(String userId) async {
    try {
      final response = await _client
          .from('users')
          .select('*, role:role_id(role), mining_units:mining_unit_id(name, type), pin_hash')
          .eq('userId', userId)
          .single();

      final data = Map<String, dynamic>.from(response);
      final roleName = data['role'] != null ? data['role']['role'] : '';
      data['role_id'] = roleName;
      
      return Right(UserModel.fromJson(data));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, UserEntity>> updateUser(UserEntity user) async {
    try {
      final model = UserModel.fromEntity(user);
      final data = model.toJson();
      
      // Map role name back to UUID if necessary before sending to DB
      if (data['role_id'] == 'miner') {
        data['role_id'] = '5ef69f93-cb07-4052-989e-9e6ca48c4360';
      } else if (data['role_id'] == 'operator') {
        data['role_id'] = '91fb0b2f-f627-4234-ae38-2a305a799ff4';
      } else if (data['role_id'] == 'admin') {
        data['role_id'] = 'ff1e5b6e-b1ac-4a37-bb2c-36e890de6804';
      }

      final response = await _client
          .from('users')
          .update(data)
          .eq('userId', user.userId)
          .select('*, role:role_id(role), mining_units:mining_unit_id(name, type), pin_hash')
          .single();

      final updatedData = Map<String, dynamic>.from(response);
      final roleName = updatedData['role'] != null ? updatedData['role']['role'] : '';
      updatedData['role_id'] = roleName;

      return Right(UserModel.fromJson(updatedData));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> deleteUser(String userId) async {
    try {
      await _client.from('users').delete().eq('userId', userId);
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> updateUserPin(String userId, String pin) async {
    try {
      final pinHash = sha256.convert(utf8.encode(pin)).toString();
      await _client
          .from('users')
          .update({'pin_hash': pinHash})
          .eq('userId', userId);
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}
