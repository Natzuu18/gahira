import 'package:dartz/dartz.dart';
import 'package:file_picker/file_picker.dart';
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

  Future<Either<Failure, void>> submitOperatorMaintenanceRequest({
    required String? machineId,
    required String? drumId,
    required String maintenanceType,
    required String reason,
    required String operatorId,
    required PlatformFile photo,
  }) async {
    try {
      final bytes = photo.bytes;
      if (bytes == null || bytes.isEmpty) {
        return const Left(ServerFailure('The selected photo could not be read.'));
      }

      final now = DateTime.now();
      final extension = photo.name.contains('.')
          ? photo.name.split('.').last.toLowerCase()
          : 'jpg';
      final path =
          'maintenance/maintenance_${now.millisecondsSinceEpoch}.$extension';
      final storage = _client.storage.from('serviceRequests');
      await storage.uploadBinary(
        path,
        bytes,
        fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
      );
      final photoUrl = storage.getPublicUrl(path);
      final endTime = now.add(const Duration(hours: 1));

      await _client.from('maintenance_schedule').insert({
        'machine_id': machineId,
        'drum_id': drumId,
        'maintenance_type': maintenanceType,
        'maintenance_date': _dateString(now),
        'start_time': _timeString(now),
        'end_time': _timeString(endTime),
        'description': reason.trim(),
        'remarks': 'Evidence photo: $photoUrl',
        'status': 'scheduled',
        'performed_by': operatorId,
      });
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure('Could not submit maintenance request: $e'));
    }
  }

  String _dateString(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  String _timeString(DateTime date) =>
      '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}:00';

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
