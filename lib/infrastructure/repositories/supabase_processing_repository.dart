import 'package:dartz/dartz.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/error/failures.dart';
import '../supabase/supabase_config.dart';

class SupabaseProcessingRepository {
  final SupabaseClient _client = SupabaseConfig.client;

  Future<Either<Failure, List<Map<String, dynamic>>>> getProcessingTasks({String? status}) async {
    try {
      var query = _client.from('processing_tasks').select('''
        *,
        service_requests:service_request_id (
          service_request_id,
          purpose,
          quantity,
          user:user_id (fname, lname)
        ),
        machines:machine_id (machine_name),
        drums:drum_id (drum_name),
        operator:operator_id (fname, lname)
      ''');

      if (status != null) {
        query = query.eq('status', status);
      }

      final response = await query.order('scheduled_date', ascending: true);
      return Right(List<Map<String, dynamic>>.from(response));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  Future<Either<Failure, void>> createProcessingTask(Map<String, dynamic> task) async {
    try {
      await _client.from('processing_tasks').insert(task);
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  Future<Either<Failure, void>> updateTaskStatus(String processingId, String status, {String? remarks}) async {
    try {
      final updates = <String, dynamic>{};
      updates['status'] = status;
      updates['updated_at'] = DateTime.now().toIso8601String();

      if (remarks != null) updates['remarks'] = remarks;

      await _client.from('processing_tasks').update(updates).eq('processing_id', processingId);
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}
