import 'package:dartz/dartz.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/error/failures.dart';
import '../supabase/supabase_config.dart';

class SupabaseServiceRequestRepository {
  final SupabaseClient _client = SupabaseConfig.client;

  Future<Either<Failure, List<Map<String, dynamic>>>> getServiceRequests() async {
    try {
      // Fetching service requests with related user (miner) and participating miners
      // The schema shows service_requests linked to users (primary miner)
      // and potentially a junction table for participating miners.
      // For now, we fetch basic info and related primary user.
      final response = await _client.from('service_requests').select('''
        *,
        user:user_id (
          userId,
          fname,
          lname,
          email,
          contact_num
        )
      ''').order('created_at', ascending: false);

      return Right(List<Map<String, dynamic>>.from(response));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  Future<Either<Failure, void>> updateRequestStatus({
    required String requestId,
    required String status,
    required String adminId,
  }) async {
    try {
      final updates = {
        'status': status,
        'approved_by': adminId,
        'approved_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      await _client
          .from('service_requests')
          .update(updates)
          .eq('service_request_id', requestId);

      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  // If there's a participating miners table, we can fetch them separately or via join
  Future<Either<Failure, List<Map<String, dynamic>>>> getParticipatingMiners(String requestId) async {
    try {
      // Assuming a junction table exists based on the schema lines
      // Let's call it service_request_participants for now if it's there
      // Or if it's just a text field/json in service_requests.
      // Based on typical schema design:
      final response = await _client.from('service_request_participants').select('''
        user:user_id (
          fname,
          lname
        )
      ''').eq('service_request_id', requestId);
      
      return Right(List<Map<String, dynamic>>.from(response));
    } catch (e) {
      // If table doesn't exist, return empty list for now
      return const Right([]);
    }
  }
}
