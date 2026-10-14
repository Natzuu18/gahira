import 'package:dartz/dartz.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/error/failures.dart';
import '../supabase/supabase_config.dart';

class SupabaseProcessingRepository {
  final SupabaseClient _client = SupabaseConfig.client;

  Future<Either<Failure, List<Map<String, dynamic>>>> getProcessingTasks({String? status}) async {
    try {
      final response = await _client
          .from('service_requests')
          .select('''
            *,
            users:user_id(fname, lname),
            ongoing_services(
              id,
              current_stage,
              operator:operator_id(fname, lname),
              machines:machine_id(machine_name),
              drums:drum_id(drum_name)
            ),
            mill_queue(scheduled_at, queue_type)
          ''')
          .order('created_at', ascending: false);

      final List<Map<String, dynamic>> tasks = [];

      for (var row in (response as List)) {
        final srStatus = row['status']?.toString();
        
        // Map status for admin task view
        String taskStatus = 'Pending';
        if (srStatus == 'processing' || srStatus == 'assigned' || srStatus == 'queued' || srStatus == 'scheduled') {
          taskStatus = 'Active';
        } else if (srStatus == 'completed' || srStatus == 'processingCompleted' || srStatus == 'goldHandoff') {
          taskStatus = 'Completed';
        }

        if (status != null && taskStatus.toLowerCase() != status.toLowerCase()) {
          continue;
        }

        final userObj = row['users'] as Map<String, dynamic>?;
        final ongoingList = row['ongoing_services'] as List<dynamic>?;
        Map<String, dynamic>? ongoing;
        if (ongoingList != null && ongoingList.isNotEmpty) {
          ongoing = ongoingList.first as Map<String, dynamic>?;
        }

        final queueList = row['mill_queue'] as List<dynamic>?;
        String? scheduledDate = row['request_date']?.toString();
        if (queueList != null && queueList.isNotEmpty) {
          final q = queueList.first;
          if (q['scheduled_at'] != null) {
            scheduledDate = q['scheduled_at'].toString().split('T')[0];
          }
        }

        tasks.add({
          'processing_id': row['service_request_id'],
          'service_request_id': row['service_request_id'],
          'status': taskStatus,
          'scheduled_date': scheduledDate ?? DateTime.now().toIso8601String().split('T')[0],
          'service_requests': {
            'service_request_id': row['service_request_id'],
            'service_type': row['service_type'] ?? 'Milling',
            'quantity': row['quantity'] ?? 0,
            'user': userObj,
          },
          'machines': ongoing?['machines'] ?? {'machine_name': 'N/A'},
          'drums': ongoing?['drums'] ?? {'drum_name': 'N/A'},
          'operator': ongoing?['operator'] ?? {'fname': 'Operator', 'lname': ''},
          'remarks': row['processing_notes'] ?? '',
        });
      }

      return Right(tasks);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  Future<Either<Failure, void>> createProcessingTask(Map<String, dynamic> task) async {
    try {
      if (task['service_request_id'] != null) {
        await _client.from('service_requests').update({
          'status': 'processing',
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('service_request_id', task['service_request_id']);
      }
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  Future<Either<Failure, void>> updateTaskStatus(String processingId, String status, {String? remarks}) async {
    try {
      final updates = <String, dynamic>{
        'status': status.toLowerCase() == 'completed' ? 'processingCompleted' : status,
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (remarks != null) updates['processing_notes'] = remarks;

      await _client.from('service_requests').update(updates).eq('service_request_id', processingId);
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}
