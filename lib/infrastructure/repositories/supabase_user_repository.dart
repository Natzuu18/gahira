import 'dart:math';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';
import 'package:dartz/dartz.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/error/failures.dart';
import '../../core/config/env_config.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/entities/registration_enums.dart';
import '../../domain/repositories/user_repository.dart';
import '../models/user_model.dart';
import '../supabase/supabase_config.dart';

class SupabaseUserRepository implements UserRepository {
  final SupabaseClient _client = SupabaseConfig.client;

  Future<String?> _getRoleIdByName(String roleName) async {
    try {
      final response = await _client
          .from('role')
          .select('role_id')
          .ilike('role', roleName)
          .maybeSingle();
      return response?['role_id']?.toString();
    } catch (_) {
      return null;
    }
  }

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
      final response = await _client
          .from('users')
          .select('*, role:role_id(role), mining_units:mining_unit_id(name, type), pin_hash')
          .or('status.eq.approved,status.eq.active,status.eq.inactive')
          .order('fname', ascending: true);

      final List<UserEntity> users = (response as List)
          .map((json) {
            final data = Map<String, dynamic>.from(json);
            final roleName = data['role'] != null ? data['role']['role']?.toString().toLowerCase() : '';
            data['role_id'] = data['role'] != null ? data['role']['role'] : '';
            return MapEntry(roleName, UserModel.fromJson(data));
          })
          .where((entry) => entry.key == 'miner' || entry.key == 'operator' || entry.key == 'client')
          .map((entry) => entry.value)
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
          .select('*, role:role_id!inner(role), mining_units:mining_unit_id(name, type), pin_hash')
          .ilike('role.role', 'operator')
          .order('fname', ascending: true);

      final List<UserEntity> users = (response as List)
          .map((json) {
            final data = Map<String, dynamic>.from(json);
            final roleName = data['role'] != null ? data['role']['role'] : 'operator';
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

  String _normalizePhone(String raw) {
    final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.startsWith('63')) return digits;
    if (digits.startsWith('0')) return '63${digits.substring(1)}';
    if (digits.startsWith('9')) return '63$digits';
    return digits;
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
      final normalizedPhone = _normalizePhone(phone);
      if (normalizedPhone.length < 12) {
        return Left(ServerFailure('Invalid phone number: "$phone". SMS cannot be sent. Please enter a valid phone number starting with 09 (e.g. 09123456789).'));
      }

      final tempPassword = _generateRandomPassword();
      
      final roleName = role == UserRole.operator ? 'operator' : 'miner';
      final roleId = await _getRoleIdByName(roleName);
      if (roleId == null) {
        return Left(ServerFailure('Role "$roleName" not found in database'));
      }

      // Call the RPC to handle direct user creation
      try {
        await _client.rpc(
          'add_user_by_admin_rpc',
          params: {
            'u_email': email,
            'u_phone': normalizedPhone,
            'u_fname': firstName,
            'u_mname': middleName ?? '',
            'u_lname': lastName,
            'u_address': address,
            'u_pass': tempPassword,
            'u_role_id': roleId,
            'u_mining_unit_id': miningUnitId,
          },
        );
      } catch (e) {
        // Fallback or handle if RPC errors out
      }

      // Send SMS via PhilSMS directly
      final roleTitle = role == UserRole.operator ? 'OPERATOR' : 'MINER';
      final smsMessage = 'Gahira System: Hello $firstName! An admin has created your $roleTitle account. You can now log in using Email: $email | Password: $tempPassword. Thank you!';

      final smsResponse = await http.post(
        Uri.parse(EnvConfig.philsmsEndpoint),
        headers: {
          'Authorization': 'Bearer ${EnvConfig.philsmsApiKey.trim()}',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'recipient': normalizedPhone,
          'sender_id': EnvConfig.philsmsSenderId,
          'message': smsMessage,
        }),
      );

      if (smsResponse.statusCode >= 300) {
        String errMsg = 'Failed to send SMS via PhilSMS.';
        try {
          final body = jsonDecode(smsResponse.body);
          if (body['message'] != null) {
            errMsg = 'PhilSMS Error: ${body['message']}';
          }
        } catch (_) {}
        return Left(ServerFailure('User created in system, but SMS failed: $errMsg'));
      }

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
      if (data['role_id'] != null && data['role_id'].toString().isNotEmpty) {
        final fetchedRoleId = await _getRoleIdByName(data['role_id'].toString());
        if (fetchedRoleId != null) {
          data['role_id'] = fetchedRoleId;
        }
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
