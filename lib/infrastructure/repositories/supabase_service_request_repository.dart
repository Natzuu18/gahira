import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:dartz/dartz.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/error/failures.dart';
import '../../domain/entities/service_request_entity.dart';
import '../models/service_request_model.dart';
import '../supabase/supabase_config.dart';

class SupabaseServiceRequestRepository {
  final SupabaseClient _client = SupabaseConfig.client;

  Future<Either<Failure, List<ServiceRequestModel>>> getServiceRequests() async {
    try {
      final response = await _client
          .from('service_requests')
          .select('*, users:user_id(*), operator_verified_services(*), mill_queue(*), ongoing_services(*), service_participant_financials(*, users:user_id(*))');
      
      print('--- FETCHING SERVICE REQUESTS ---');
      // Removed big RAW DATA print to prevent hangs

      final list = (response as List).map((json) {
        try {
          return ServiceRequestModel.fromJson(json);
        } catch (e) {
          print('PARSING ERROR FOR ROW: $json');
          print('ERROR DETAILS: $e');
          rethrow;
        }
      }).toList();

      return Right(list);
    } catch (e) {
      print('REPOSITORY FETCH ERROR: $e');
      return Left(ServerFailure(e.toString()));
    }
  }

  Future<Either<Failure, ServiceRequestModel>> createServiceRequest(ServiceRequestModel model) async {
    try {
      final data = model.toJson();
      
      // Insert the main request
      final response = await _client
          .from('service_requests')
          .insert(data)
          .select()
          .single();
      
      final created = ServiceRequestModel.fromJson(response);

      // Create Audit Trail entry for creation
      await logAuditTrail(
        requestId: created.id,
        userId: created.creatorId,
        action: 'CREATE_REQUEST',
        previousStatus: 'None',
        newStatus: created.status.name,
        remarks: 'Material submission started',
      );

      return Right(created);
    } on PostgrestException catch (e) {
      return Left(ServerFailure('Database error: ${e.message}'));
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
      print('Status Update Error: $e');
      return Left(ServerFailure(e.toString()));
    }
  }

  Future<Either<Failure, void>> addToMillQueue({
    required String requestId,
    required String userId,
    required String queueType,
    DateTime? scheduledAt,
  }) async {
    try {
      await _client.from('mill_queue').insert({
        'service_request_id': requestId,
        'queue_type': queueType,
        'scheduled_at': scheduledAt?.toIso8601String(),
        'added_by': userId,
        'status': 'waiting',
      });
      return const Right(null);
    } catch (e) {
      print('Add to mill queue error: $e');
      return Left(ServerFailure(e.toString()));
    }
  }

  Future<Either<Failure, void>> claimServiceRequest({
    required String requestId,
    required String operatorId,
  }) async {
    try {
      await _client.from('ongoing_services').insert({
        'service_request_id': requestId,
        'operator_id': operatorId,
        'current_stage': 'rebagging',
      });
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  // --- BATCH SACK PROCESSING ---
  Future<Either<Failure, List<Map<String, dynamic>>>> getMillingBatches(String requestId) async {
    try {
      final response = await _client
          .from('milling_batches')
          .select('*, machines(*), drums(*)')
          .eq('service_request_id', requestId)
          .order('created_at', ascending: true);
      return Right(List<Map<String, dynamic>>.from(response));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  Future<Either<Failure, void>> createMillingBatch({
    required String requestId,
    required String operatorId,
    required String machineId,
    required String drumId,
    required int inputSacks,
    required int outputSacks,
    required int estimatedDurationMinutes,
  }) async {
    try {
      // 1. Insert milling batch
      await _client.from('milling_batches').insert({
        'service_request_id': requestId,
        'operator_id': operatorId,
        'machine_id': machineId,
        'drum_id': drumId,
        'input_sacks': inputSacks,
        'output_sacks': outputSacks,
        'estimated_duration_minutes': estimatedDurationMinutes,
        'status': 'milling',
      });

      // 2. Mark the specific drum as 'in_use'
      await _client.from('drums').update({'status': 'in_use'}).eq('drum_id', drumId);

      // 3. Check if all drums in this machine are now in use
      final freeDrums = await _client
          .from('drums')
          .select('drum_id')
          .eq('machine_id', machineId)
          .eq('status', 'available');
      
      if ((freeDrums as List).isEmpty) {
        // Machine is fully occupied
        await _client.from('machines').update({'status': 'in_use'}).eq('machine_id', machineId);
      }

      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  Future<Either<Failure, void>> completeMillingBatch({
    required String batchId,
    required String machineId,
    required String drumId,
  }) async {
    try {
      // 1. Complete batch status
      await _client.from('milling_batches').update({'status': 'completed', 'completed_at': DateTime.now().toIso8601String()}).eq('batch_id', batchId);

      // 2. Revert the specific drum back to 'available'
      await _client.from('drums').update({'status': 'available'}).eq('drum_id', drumId);

      // 3. Since at least this drum is now available, the machine is available for use
      await _client.from('machines').update({'status': 'available'}).eq('machine_id', machineId);

      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  Future<Either<Failure, void>> updateMillingBatchDuration(String batchId, int newDuration) async {
    try {
      await _client.from('milling_batches').update({'estimated_duration_minutes': newDuration}).eq('batch_id', batchId);
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  Future<Either<Failure, void>> triggerEmergencyStop({
    String? requestId,
    required String operatorId,
    required String reason,
    String? machineId,
    String? drumId,
    bool stopEntireMachine = false,
  }) async {
    try {
      final now = DateTime.now().toIso8601String();

      if (stopEntireMachine && machineId != null) {
        // --- MACHINE-WIDE STOP ---
        
        // 1. Mark Machine as emergency stop
        await _client.from('machines').update({'status': 'emergency_stop'}).eq('machine_id', machineId);

        // 2. Mark ALL Drums of this machine as emergency stop
        await _client.from('drums').update({'status': 'emergency_stop'}).eq('machine_id', machineId);

        // 3. Find all active service requests currently using ANY drum on this machine
        final drumsResponse = await _client.from('drums').select('drum_id').eq('machine_id', machineId);
        final drumIds = (drumsResponse as List).map((d) => d['drum_id'].toString()).toList();

        if (drumIds.isNotEmpty) {
          final activeBatches = await _client
              .from('milling_batches')
              .select('service_request_id')
              .filter('drum_id', 'in', drumIds)
              .eq('status', 'milling');
          
          final requestIds = (activeBatches as List).map((b) => b['service_request_id'].toString()).toSet().toList();

          // 4. Update all these service requests to emergencyStop
          if (requestIds.isNotEmpty) {
            await _client.from('service_requests').update({
              'status': 'emergencyStop',
              'emergency_reason': 'MACHINE FAILURE: $reason',
              'emergency_stopped_at': now,
              'updated_at': now,
            }).filter('service_request_id', 'in', requestIds);

            for (final rid in requestIds) {
              await logAuditTrail(
                requestId: rid,
                userId: operatorId,
                action: 'EMERGENCY_STOP_MACHINE',
                previousStatus: 'processing',
                newStatus: 'emergencyStop',
                remarks: reason,
              );
            }
          }
        }
      } else if (drumId != null) {
        // --- SPECIFIC DRUM STOP ---
        
        // 1. Mark the specific drum
        await _client.from('drums').update({'status': 'emergency_stop'}).eq('drum_id', drumId);

        // 2. Find the active service request using this drum
        final activeBatchResponse = await _client
            .from('milling_batches')
            .select('service_request_id')
            .eq('drum_id', drumId)
            .eq('status', 'milling');
        
        final List batches = activeBatchResponse as List;
        
        if (batches.isNotEmpty) {
          final rid = batches.first['service_request_id'].toString();
          
          // 3. Update the specific service request
          await _client.from('service_requests').update({
            'status': 'emergencyStop',
            'emergency_reason': 'DRUM FAILURE: $reason',
            'emergency_stopped_at': now,
            'updated_at': now,
          }).eq('service_request_id', rid);

          // 4. Log Audit
          await logAuditTrail(
            requestId: rid,
            userId: operatorId,
            action: 'EMERGENCY_STOP_DRUM',
            previousStatus: 'processing',
            newStatus: 'emergencyStop',
            remarks: reason,
          );
        }
      }

      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }


  Future<Either<Failure, void>> updateMillQueueStatus({
    required String requestId,
    required String status,
  }) async {
    try {
      await _client.from('mill_queue').update({'status': status}).eq('service_request_id', requestId);
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  Future<Either<Failure, void>> upsertParticipantFinancials(List<Map<String, dynamic>> records) async {
    try {
      await _client.from('service_participant_financials').upsert(records);
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  Future<Either<Failure, void>> saveBillingItems(List<Map<String, dynamic>> items) async {
    try {
      await _client.from('service_billing_items').insert(items);
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  Future<Either<Failure, List<Map<String, dynamic>>>> getAllBillingExpenses() async {
    try {
      final response = await _client
          .from('service_billing_items')
          .select('*, service_requests(service_request_id, user_id, users(fname, lname))')
          .order('created_at', ascending: false);
      return Right(List<Map<String, dynamic>>.from(response));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  Future<Either<Failure, void>> recordParticipantPayment(Map<String, dynamic> payment) async {
    try {
      await _client.from('participant_payments').insert(payment);
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  Future<Either<Failure, void>> updateParticipantFinancial({
    required String requestId,
    required String userId,
    required double amountPaid,
    required String status,
  }) async {
    try {
      await _client
          .from('service_participant_financials')
          .update({
            'amount_paid': amountPaid,
            'status': status,
            'last_payment_at': DateTime.now().toIso8601String(),
          })
          .eq('service_request_id', requestId)
          .eq('user_id', userId);
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  Future<Either<Failure, void>> submitOperatorVerification({
    required String requestId,
    required String operatorId,
    required int actualSacks,
    required String condition,
    required String state,
    required String source,
    required bool isAccurate,
    required String processingEstimate,
    String? notes,
  }) async {
    try {
      await _client.from('operator_verified_services').insert({
        'service_request_id': requestId,
        'operator_id': operatorId,
        'actual_sacks': actualSacks,
        'condition': condition,
        'state': state,
        'source': source,
        'is_accurate': isAccurate,
        'processing_estimate': processingEstimate,
        'correction_notes': notes,
        'verified_at': DateTime.now().toIso8601String(),
      });
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  Future<Either<Failure, ServiceRequestModel>> updateServiceRequest(ServiceRequestModel model) async {
    try {
      final data = model.toJson();
      // Remove fields that shouldn't be updated or cause issues
      data.remove('user_id'); 
      data.remove('created_at');
      
      final response = await _client
          .from('service_requests')
          .update(data)
          .eq('service_request_id', model.id)
          .select()
          .single();
          
      return Right(ServiceRequestModel.fromJson(response));
    } on PostgrestException catch (e) {
      return Left(ServerFailure('Update failed: ${e.message}'));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  Future<Either<Failure, bool>> verifyUserPin(String userId, String pin) async {
    try {
      final response = await _client
          .from('users')
          .select('pin_hash')
          .eq('userId', userId)
          .single();
      
      final storedHash = response['pin_hash'] as String?;
      if (storedHash == null) return const Right(false);

      final inputHash = sha256.convert(utf8.encode(pin)).toString();
      return Right(storedHash == inputHash);
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

  Future<Either<Failure, List<String>>> uploadRequestPhotos(List<PlatformFile> photos) async {
    try {
      final List<String> urls = [];
      for (final file in photos) {
        if (file.bytes == null) continue;
        final extension = file.name.split('.').last;
        final path = 'request_${DateTime.now().millisecondsSinceEpoch}_${urls.length}.$extension';
        
        await _client.storage.from('serviceRequests').uploadBinary(
          path,
          file.bytes!,
          fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
        );
        
        urls.add(_client.storage.from('serviceRequests').getPublicUrl(path));
      }
      return Right(urls);
    } catch (e) {
      return Left(ServerFailure('Photo upload failed: ${e.toString()}'));
    }
  }

  Future<Either<Failure, void>> resolveEmergencyStop({
    required String requestId,
    required String adminId,
  }) async {
    try {
      final now = DateTime.now().toIso8601String();

      // 1. Get the current request to check reason and find equipment
      final srRes = await _client.from('service_requests').select('*').eq('service_request_id', requestId).single();
      final reason = srRes['emergency_reason']?.toString() ?? '';
      final isMachineFailure = reason.contains('MACHINE FAILURE:');

      // 2. Resolve the SR
      await _client.from('service_requests').update({
        'emergency_resolved_at': now,
        'updated_at': now,
      }).eq('service_request_id', requestId);

      // 3. Reset Equipment
      final batchesRes = await getMillingBatches(requestId);
      await batchesRes.fold((_) async {}, (batches) async {
        final active = batches.where((b) => b['status'] == 'milling').toList();
        if (active.isNotEmpty) {
          final drumId = active.first['drum_id'];
          final machineId = active.first['machine_id'];

          if (isMachineFailure && machineId != null) {
            // Reset entire machine and all its drums
            await _client.from('machines').update({'status': 'in_use'}).eq('machine_id', machineId);
            await _client.from('drums').update({'status': 'in_use'}).eq('machine_id', machineId);
            
            // Also mark other SRs on this machine as resolved
            final drumsOfMachine = await _client.from('drums').select('drum_id').eq('machine_id', machineId);
            final dIds = (drumsOfMachine as List).map((d) => d['drum_id'].toString()).toList();
            
            final otherBatches = await _client.from('milling_batches').select('service_request_id').filter('drum_id', 'in', dIds).eq('status', 'milling');
            final otherSrs = (otherBatches as List).map((b) => b['service_request_id'].toString()).toSet().toList();
            
            if (otherSrs.isNotEmpty) {
              await _client.from('service_requests').update({'emergency_resolved_at': now}).filter('service_request_id', 'in', otherSrs);
            }
          } else {
            // Reset only this specific drum
            await _client.from('drums').update({'status': 'in_use'}).eq('drum_id', drumId);
            if (machineId != null) {
              await _client.from('machines').update({'status': 'in_use'}).eq('machine_id', machineId);
            }
          }
        }
      });

      await logAuditTrail(
        requestId: requestId,
        userId: adminId,
        action: 'EMERGENCY_RESOLVED',
        previousStatus: 'emergencyStop',
        newStatus: 'emergencyStop',
        remarks: 'Admin resolved issue. Systems restored.',
      );

      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  Future<Either<Failure, void>> resumeProcessing({
    required String requestId,
    required String operatorId,
  }) async {
    try {
      final now = DateTime.now().toIso8601String();

      await _client.from('service_requests').update({
        'status': 'processing',
        'emergency_reason': null,
        'emergency_stopped_at': null,
        'emergency_resolved_at': null,
        'updated_at': now,
      }).eq('service_request_id', requestId);

      await logAuditTrail(
        requestId: requestId,
        userId: operatorId,
        action: 'RESUME_PROCESSING',
        previousStatus: 'emergencyStop',
        newStatus: 'processing',
        remarks: 'Operator resumed processing.',
      );

      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}
