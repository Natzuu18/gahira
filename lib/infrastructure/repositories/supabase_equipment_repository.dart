import 'package:dartz/dartz.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/error/failures.dart';
import '../supabase/supabase_config.dart';

class SupabaseEquipmentRepository {
  final SupabaseClient _client = SupabaseConfig.client;

  // --- MACHINES ---
  Future<Either<Failure, List<Map<String, dynamic>>>> getMachines() async {
    try {
      final response = await _client.from('machines').select('*, drums(*)').order('machine_name');
      return Right(List<Map<String, dynamic>>.from(response));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  Future<Either<Failure, void>> addMachine(Map<String, dynamic> machine) async {
    try {
      await _client.from('machines').insert(machine);
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  Future<Either<Failure, void>> updateMachine(String id, Map<String, dynamic> updates) async {
    try {
      await _client.from('machines').update(updates).eq('machine_id', id);
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  // --- DRUMS ---
  Future<Either<Failure, List<Map<String, dynamic>>>> getDrums() async {
    try {
      final response = await _client.from('drums').select('*, machines:machine_id(machine_name)').order('drum_name');
      return Right(List<Map<String, dynamic>>.from(response));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  Future<Either<Failure, void>> addDrum(Map<String, dynamic> drum) async {
    try {
      await _client.from('drums').insert(drum);
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  Future<Either<Failure, void>> updateDrum(String id, Map<String, dynamic> updates) async {
    try {
      await _client.from('drums').update(updates).eq('drum_id', id);
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  // --- MAINTENANCE ---
  Future<Either<Failure, List<Map<String, dynamic>>>> getMaintenanceSchedules() async {
    try {
      final response = await _client.from('maintenance_schedule').select('''
        *,
        machines:machine_id(machine_name),
        drums:drum_id(drum_name)
      ''').order('maintenance_date', ascending: false);
      return Right(List<Map<String, dynamic>>.from(response));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  Future<Either<Failure, void>> addMaintenance(Map<String, dynamic> log) async {
    try {
      await _client.from('maintenance_schedule').insert(log);
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  Future<Either<Failure, void>> updateMaintenance(String id, Map<String, dynamic> updates) async {
    try {
      await _client.from('maintenance_schedule').update(updates).eq('maintenance_id', id);
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  Future<Either<Failure, void>> updateMaintenanceStatus(String id, String status) async {
    try {
      await _client.from('maintenance_schedule').update({'status': status}).eq('maintenance_id', id);
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}
