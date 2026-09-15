import 'package:dartz/dartz.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/error/failures.dart';
import '../../domain/entities/service_request_entity.dart';
import '../models/service_request_model.dart';
import '../supabase/supabase_config.dart';

class SupabaseServiceRequestRepository {
  final SupabaseClient _client = SupabaseConfig.client;

  Future<Either<Failure, List<ServiceRequestModel>>> getServiceRequests() async {
    try {
      final response = await _client.from('service_requests').select().order('created_at', ascending: false);
      return Right((response as List).map((e) => ServiceRequestModel.fromJson(e)).toList());
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  Future<Either<Failure, ServiceRequestModel>> createServiceRequest(ServiceRequestModel model) async {
    try {
      final response = await _client.from('service_requests').insert(model.toJson()).select().single();
      return Right(ServiceRequestModel.fromJson(response));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  Future<Either<Failure, void>> updateRequestStatus({
    required String requestId,
    required String status,
    required String userId,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      final updates = {
        'status': status,
        'updated_at': DateTime.now().toIso8601String(),
        ...?additionalData,
      };

      await _client.from('service_requests').update(updates).eq('service_request_id', requestId);
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  Future<Either<Failure, bool>> verifyUserPin(String userId, String pin) async {
    try {
      // Assuming 'pin' column in 'users' table. 
      // In a real app, this should be a secure RPC call that hashes the input.
      final response = await _client
          .from('users')
          .select('pin')
          .eq('userId', userId)
          .single();
      
      final storedPin = response['pin'] as String?;
      return Right(storedPin == pin);
    } catch (e) {
      return Left(ServerFailure('PIN verification failed: ${e.toString()}'));
    }
  }

  Future<Either<Failure, void>> logAuditTrail({
    required String requestId,
    required String userId,
    required String action,
    required String previousStatus,
    required String newStatus,
    String? remarks,
  }) async {
    try {
      await _client.from('audit_trails').insert({
        'service_request_id': requestId,
        'user_id': userId,
        'action': action,
        'previous_status': previousStatus,
        'new_status': newStatus,
        'remarks': remarks,
        'created_at': DateTime.now().toIso8601String(),
      });
      return const Right(null);
    } catch (e) {
      // Audit trail failure shouldn't necessarily break the flow, but we log it
      print('Audit trail error: $e');
      return const Right(null);
    }
  }

  Future<Either<Failure, List<Map<String, dynamic>>>> getAuditTrails(String requestId) async {
    try {
      final response = await _client
          .from('audit_trails')
          .select('*, user:user_id(fname, lname, role_id)')
          .eq('service_request_id', requestId)
          .order('created_at', ascending: true);
      return Right(List<Map<String, dynamic>>.from(response));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}
