import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:dartz/dartz.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/config/env_config.dart';
import '../../core/error/failures.dart';
import '../../domain/entities/service_request_entity.dart';
import '../models/service_request_model.dart';
import '../supabase/supabase_config.dart';

class SupabaseServiceRequestRepository {
  final SupabaseClient _client;

  SupabaseServiceRequestRepository({SupabaseClient? client})
    : _client = client ?? SupabaseConfig.client;

  Future<Either<Failure, List<ServiceRequestModel>>>
  getServiceRequests() async {
    try {
      final response = await _client
          .from('service_requests')
          .select(
            '*, users:user_id(*), operator_verified_services(*), mill_queue(*), ongoing_services(*), service_participant_financials(*, users:user_id(*))',
          );

      print('--- FETCHING SERVICE REQUESTS ---');
      // Removed big RAW DATA print to prevent hangs

      return Right(_parseServiceRequestList(response));
    } catch (e) {
      print('REPOSITORY FETCH ERROR: $e');
      return Left(ServerFailure(e.toString()));
    }
  }

  Future<Either<Failure, List<ServiceRequestModel>>>
  getPendingOperatorVerificationRequests() async {
    try {
      final response = await _client
          .from('service_requests')
          .select(
            '*, users:user_id(*), operator_verified_services(*), mill_queue(*), ongoing_services(*), service_participant_financials(*, users:user_id(*))',
          )
          .eq('status', 'pendingOperatorVerification');
      return Right(_parseServiceRequestList(response));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  Future<Either<Failure, List<ServiceRequestModel>>>
  getServiceRequestsVerifiedByOperator(String operatorId) async {
    try {
      final response = await _client
          .from('service_requests')
          .select(
            '*, users:user_id(*), operator_verified_services!inner(*), mill_queue(*), ongoing_services(*), service_participant_financials(*, users:user_id(*))',
          )
          .eq('operator_verified_services.operator_id', operatorId);
      return Right(_parseServiceRequestList(response));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  Future<Either<Failure, List<ServiceRequestModel>>>
  getOngoingServiceRequestsForOperator(String operatorId) async {
    try {
      final response = await _client
          .from('service_requests')
          .select(
            '*, users:user_id(*), operator_verified_services(*), mill_queue(*), ongoing_services!inner(*), service_participant_financials(*, users:user_id(*))',
          )
          .eq('ongoing_services.operator_id', operatorId)
          .inFilter('status', ['processing', 'emergencyStop']);
      return Right(_parseServiceRequestList(response));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  Future<Either<Failure, List<ServiceRequestModel>>>
  getAssignedServiceRequestsForOperator(String operatorId) async {
    try {
      final response = await _client
          .from('service_requests')
          .select(
            '*, users:user_id(*), operator_verified_services(*), mill_queue(*), ongoing_services!inner(*), service_participant_financials(*, users:user_id(*))',
          )
          .eq('ongoing_services.operator_id', operatorId)
          .inFilter('status', ['verified', 'accepted', 'queued', 'scheduled']);
      return Right(_parseServiceRequestList(response));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  Future<Either<Failure, void>> assignAvailableOperatorToService({
    required String requestId,
    required String operatorId,
  }) async {
    try {
      final appealHold = await _getAppealOperationHold(requestId);
      if (appealHold != null) return Left(ServerFailure(appealHold));

      final operator = await _client
          .from('users')
          .select('status, role:role_id!inner(role)')
          .eq('userId', operatorId)
          .maybeSingle();
      final role = (operator?['role'] as Map?)?['role']
          ?.toString()
          .toLowerCase();
      final operatorStatus = operator?['status']?.toString().toLowerCase();
      if (operator == null ||
          role != 'operator' ||
          (operatorStatus != 'active' && operatorStatus != 'approved')) {
        return Left(
          ServerFailure('This operator is not active and available.'),
        );
      }

      final request = await _client
          .from('service_requests')
          .select('status, ongoing_services(operator_id)')
          .eq('service_request_id', requestId)
          .maybeSingle();
      final requestStatus = request?['status']?.toString();
      const assignableStatuses = {
        'verified',
        'accepted',
        'queued',
        'scheduled',
        'assigned',
      };
      if (request == null || !assignableStatuses.contains(requestStatus)) {
        return Left(
          ServerFailure('This service is no longer available for assignment.'),
        );
      }

      if (requestStatus == 'queued') {
        final now = DateTime.now();
        final todayStart = DateTime(now.year, now.month, now.day);
        final tomorrowStart = todayStart.add(const Duration(days: 1));
        final scheduledQueueRows = await _client
            .from('mill_queue')
            .select('service_request_id')
            .eq('queue_type', 'scheduled')
            .gte('scheduled_at', todayStart.toUtc().toIso8601String())
            .lt('scheduled_at', tomorrowStart.toUtc().toIso8601String());
        final scheduledRequestIds = (scheduledQueueRows as List)
            .map((row) => row['service_request_id'].toString())
            .toSet()
            .toList();

        if (scheduledRequestIds.isNotEmpty) {
          final scheduledRequest = await _client
              .from('service_requests')
              .select('service_request_id')
              .inFilter('service_request_id', scheduledRequestIds)
              .eq('status', 'scheduled')
              .limit(1)
              .maybeSingle();
          if (scheduledRequest != null) {
            return Left(
              ServerFailure(
                'Start today’s scheduled services before claiming queued services.',
              ),
            );
          }
        }
      }

      final rawAssignments = request['ongoing_services'];
      final currentAssignments = rawAssignments is List
          ? rawAssignments
          : rawAssignments is Map
          ? [rawAssignments]
          : const [];
      if (currentAssignments.isNotEmpty) {
        return Left(
          ServerFailure('This service already has an assigned operator.'),
        );
      }

      // A machine may be busy while one of its drums is still free. Claiming
      // another queued service is allowed whenever at least one drum is free;
      // equipment is selected when the operator starts processing it.
      final availableDrum = await _client
          .from('drums')
          .select('drum_id')
          .ilike('status', 'available')
          .limit(1)
          .maybeSingle();
      if (availableDrum == null) {
        return Left(
          ServerFailure(
            'No drums are currently available. Please try again when a drum is available.',
          ),
        );
      }

      await _client.from('ongoing_services').insert({
        'service_request_id': requestId,
        'operator_id': operatorId,
        'current_stage': 'rebagging',
      });
      return const Right(null);
    } catch (e) {
      return Left(_claimFailure(e));
    }
  }

  ServerFailure _claimFailure(Object error) {
    if (error is PostgrestException &&
        error.code == '23505' &&
        error.message.contains('ongoing_services_service_request_id_key')) {
      return ServerFailure('This service is claimed by another operator.');
    }
    return ServerFailure(error.toString());
  }

  Future<Either<Failure, void>> assignVerifyingOperatorToService({
    required String requestId,
    required String operatorId,
  }) async {
    try {
      await _client.from('ongoing_services').upsert({
        'service_request_id': requestId,
        'operator_id': operatorId,
        'current_stage': 'rebagging',
      }, onConflict: 'service_request_id');
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  List<ServiceRequestModel> _parseServiceRequestList(dynamic response) {
    return (response as List).map((json) {
      try {
        return ServiceRequestModel.fromJson(json);
      } catch (e) {
        print('PARSING ERROR FOR ROW: $json');
        print('ERROR DETAILS: $e');
        rethrow;
      }
    }).toList();
  }

  Future<Either<Failure, ServiceRequestModel>> createServiceRequest(
    ServiceRequestModel model,
  ) async {
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
      if ({
        'processing',
        'processingCompleted',
        'goldHandoff',
        'partiallyPaid',
        'completed',
      }.contains(status)) {
        final hold = await _getAppealOperationHold(requestId);
        if (hold != null) return Left(ServerFailure(hold));
      }

      final updates = {
        'status': status,
        'updated_at': DateTime.now().toIso8601String(),
        ...?additionalData,
      };

      await _client
          .from('service_requests')
          .update(updates)
          .eq('service_request_id', requestId);
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
      final hold = await _getAppealOperationHold(requestId);
      if (hold != null) return Left(ServerFailure(hold));

      final existing = await _client
          .from('ongoing_services')
          .select('operator_id')
          .eq('service_request_id', requestId)
          .maybeSingle();
      if (existing != null) {
        if (existing['operator_id']?.toString() != operatorId) {
          return Left(
            ServerFailure('This service is assigned to another operator.'),
          );
        }
        await _client
            .from('ongoing_services')
            .update({
              'current_stage': 'rebagging',
              'started_at': DateTime.now().toIso8601String(),
              'last_stage_updated_at': DateTime.now().toIso8601String(),
            })
            .eq('service_request_id', requestId);
      } else {
        await _client.from('ongoing_services').insert({
          'service_request_id': requestId,
          'operator_id': operatorId,
          'current_stage': 'rebagging',
        });
      }
      return const Right(null);
    } catch (e) {
      return Left(_claimFailure(e));
    }
  }

  Future<String?> _getAppealOperationHold(String requestId) async {
    final appeal = await _client
        .from('operator_verification_appeals')
        .select('status, miner_decision')
        .eq('service_request_id', requestId)
        .or('status.eq.pending,and(status.eq.rejected,miner_decision.is.null)')
        .limit(1)
        .maybeSingle();
    if (appeal == null) return null;
    if (appeal['status'] == 'pending') {
      return 'This service is on hold while the admin reviews the miner appeal.';
    }
    return 'The miner must choose to continue or cancel this service after the appeal was rejected.';
  }

  Future<Either<Failure, void>> decideRejectedVerificationAppeal({
    required String requestId,
    required String minerId,
    required bool continueService,
  }) async {
    try {
      final appeal = await _client
          .from('operator_verification_appeals')
          .select('appeal_id')
          .eq('service_request_id', requestId)
          .eq('miner_id', minerId)
          .eq('status', 'rejected')
          .isFilter('miner_decision', null)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();
      if (appeal == null) {
        return const Left(
          ServerFailure('There is no rejected appeal awaiting your decision.'),
        );
      }

      if (!continueService) {
        final cancelResult = await updateRequestStatus(
          requestId: requestId,
          status: 'cancelled',
          userId: minerId,
        );
        final failure = cancelResult.fold<Failure?>(
          (error) => error,
          (_) => null,
        );
        if (failure != null) return Left(failure);
      }

      await _client
          .from('operator_verification_appeals')
          .update({'miner_decision': continueService ? 'continue' : 'cancel'})
          .eq('appeal_id', appeal['appeal_id'].toString())
          .eq('status', 'rejected');
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure('Could not save your appeal decision: $e'));
    }
  }

  // --- BATCH SACK PROCESSING ---
  Future<Either<Failure, List<Map<String, dynamic>>>> getMillingBatches(
    String requestId,
  ) async {
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

  Future<Either<Failure, List<Map<String, dynamic>>>>
  getActiveMillingBatches() async {
    try {
      final response = await _client
          .from('milling_batches')
          .select('*, machines(*), drums(*)')
          .eq('status', 'milling');
      return Right(List<Map<String, dynamic>>.from(response));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  Future<Either<Failure, void>> releaseEquipmentForServiceRequest(
    String requestId,
  ) async {
    try {
      final batches = await _client
          .from('milling_batches')
          .select('machine_id, drum_id')
          .eq('service_request_id', requestId);

      final equipmentByDrum = <String, String>{};
      for (final batch in batches as List) {
        final drumId = batch['drum_id']?.toString();
        final machineId = batch['machine_id']?.toString();
        if (drumId != null && machineId != null) {
          equipmentByDrum[drumId] = machineId;
        }
      }

      final affectedMachines = <String>{};
      for (final entry in equipmentByDrum.entries) {
        final activeBatches = await _client
            .from('milling_batches')
            .select('batch_id')
            .eq('drum_id', entry.key)
            .eq('status', 'milling')
            .limit(1);
        if ((activeBatches as List).isNotEmpty) continue;

        final drum = await _client
            .from('drums')
            .select('status')
            .eq('drum_id', entry.key)
            .maybeSingle();
        if (drum?['status']?.toString() == 'in_use') {
          await _client
              .from('drums')
              .update({'status': 'available'})
              .eq('drum_id', entry.key);
          affectedMachines.add(entry.value);
        }
      }

      for (final machineId in affectedMachines) {
        final inUseDrums = await _client
            .from('drums')
            .select('drum_id')
            .eq('machine_id', machineId)
            .eq('status', 'in_use')
            .limit(1);
        if ((inUseDrums as List).isNotEmpty) continue;

        final machine = await _client
            .from('machines')
            .select('status')
            .eq('machine_id', machineId)
            .maybeSingle();
        if (machine?['status']?.toString() == 'in_use') {
          await _client
              .from('machines')
              .update({'status': 'available'})
              .eq('machine_id', machineId);
        }
      }

      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  Future<Either<Failure, void>> createSackingBatch({
    required String requestId,
    required String operatorId,
    required int inputSacks,
    required int outputSacks,
  }) async {
    try {
      await _client.from('milling_batches').insert({
        'service_request_id': requestId,
        'operator_id': operatorId,
        'input_sacks': inputSacks,
        'output_sacks': outputSacks,
        'status': 'ready_to_mill',
        'batch_kind': 'sacking',
      });

      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  Future<Either<Failure, void>> startMillingBatch({
    required String requestId,
    required String operatorId,
    required String machineId,
    required String drumId,
    required int inputSacks,
    required int estimatedDurationMinutes,
  }) async {
    try {
      final appealHold = await _getAppealOperationHold(requestId);
      if (appealHold != null) return Left(ServerFailure(appealHold));

      final requestBatches = await _client
          .from('milling_batches')
          .select('batch_kind, input_sacks, output_sacks')
          .eq('service_request_id', requestId);
      final batches = requestBatches as List;
      final preparedSacks = batches
          .where((batch) => batch['batch_kind'] == 'sacking')
          .fold<int>(
            0,
            (total, batch) =>
                total + ((batch['output_sacks'] as num?)?.toInt() ?? 0),
          );
      final alreadyAllocated = batches
          .where((batch) => batch['batch_kind'] == 'milling')
          .fold<int>(
            0,
            (total, batch) =>
                total + ((batch['input_sacks'] as num?)?.toInt() ?? 0),
          );
      final availableSacks = preparedSacks - alreadyAllocated;
      if (inputSacks <= 0 || inputSacks > availableSacks) {
        return Left(
          ServerFailure(
            'Only $availableSacks resacked sacks remain available to mill.',
          ),
        );
      }

      await _client.from('milling_batches').insert({
        'service_request_id': requestId,
        'operator_id': operatorId,
        'machine_id': machineId,
        'drum_id': drumId,
        'input_sacks': inputSacks,
        'output_sacks': inputSacks,
        'batch_kind': 'milling',
        'estimated_duration_minutes': estimatedDurationMinutes,
        'milling_started_at': DateTime.now().toUtc().toIso8601String(),
        'status': 'milling',
      });

      // Mark the selected drum and its machine as in use.
      await _client
          .from('drums')
          .update({'status': 'in_use'})
          .eq('drum_id', drumId);

      // 3. Check if all drums in this machine are now in use
      final freeDrums = await _client
          .from('drums')
          .select('drum_id')
          .eq('machine_id', machineId)
          .eq('status', 'available');

      if ((freeDrums as List).isEmpty) {
        // Machine is fully occupied
        await _client
            .from('machines')
            .update({'status': 'in_use'})
            .eq('machine_id', machineId);
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
      await _client
          .from('milling_batches')
          .update({
            'status': 'completed',
            'completed_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('batch_id', batchId);

      // 2. Revert the specific drum back to 'available'
      await _client
          .from('drums')
          .update({'status': 'available'})
          .eq('drum_id', drumId);

      // 3. Since at least this drum is now available, the machine is available for use
      await _client
          .from('machines')
          .update({'status': 'available'})
          .eq('machine_id', machineId);

      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  Future<Either<Failure, void>> startMillingBatchUnloading(
    String batchId,
  ) async {
    try {
      final batch = await _client
          .from('milling_batches')
          .select('status, unloading_started_at, unloading_completed_at')
          .eq('batch_id', batchId)
          .maybeSingle();
      if (batch == null || batch['status'] != 'completed') {
        return const Left(
          ServerFailure('Only a completed milling batch can be unloaded.'),
        );
      }
      if (batch['unloading_completed_at'] != null) {
        return const Left(
          ServerFailure('This batch has already been unloaded.'),
        );
      }
      if (batch['unloading_started_at'] != null) return const Right(null);

      await _client
          .from('milling_batches')
          .update({
            'unloading_started_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('batch_id', batchId);
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure('Could not start batch unloading: $e'));
    }
  }

  Future<Either<Failure, void>> completeMillingBatchUnloading(
    String batchId,
  ) async {
    try {
      final batch = await _client
          .from('milling_batches')
          .select('status, unloading_started_at, unloading_completed_at')
          .eq('batch_id', batchId)
          .maybeSingle();
      if (batch == null || batch['status'] != 'completed') {
        return const Left(
          ServerFailure('Only a completed milling batch can be unloaded.'),
        );
      }
      if (batch['unloading_started_at'] == null) {
        return const Left(
          ServerFailure('Start unloading before completing it.'),
        );
      }
      if (batch['unloading_completed_at'] != null) return const Right(null);

      await _client
          .from('milling_batches')
          .update({
            'unloading_completed_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('batch_id', batchId);
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure('Could not complete batch unloading: $e'));
    }
  }

  Future<Either<Failure, void>> startMillingBatchWashing(String batchId) async {
    try {
      final batch = await _client
          .from('milling_batches')
          .select(
            'status, unloading_completed_at, washing_started_at, washing_completed_at',
          )
          .eq('batch_id', batchId)
          .maybeSingle();
      if (batch == null || batch['status'] != 'completed') {
        return const Left(
          ServerFailure('Only a completed milling batch can be washed.'),
        );
      }
      if (batch['unloading_completed_at'] == null) {
        return const Left(
          ServerFailure('Finish unloading this batch before washing.'),
        );
      }
      if (batch['washing_completed_at'] != null ||
          batch['washing_started_at'] != null) {
        return const Right(null);
      }

      await _client
          .from('milling_batches')
          .update({
            'washing_started_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('batch_id', batchId);
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure('Could not start batch washing: $e'));
    }
  }

  Future<Either<Failure, void>> completeMillingBatchWashing(
    String batchId,
  ) async {
    try {
      final batch = await _client
          .from('milling_batches')
          .select(
            'status, unloading_completed_at, washing_started_at, washing_completed_at',
          )
          .eq('batch_id', batchId)
          .maybeSingle();
      if (batch == null || batch['status'] != 'completed') {
        return const Left(
          ServerFailure('Only a completed milling batch can be washed.'),
        );
      }
      if (batch['unloading_completed_at'] == null) {
        return const Left(
          ServerFailure('Finish unloading this batch before washing.'),
        );
      }
      if (batch['washing_started_at'] == null) {
        return const Left(ServerFailure('Start washing before completing it.'));
      }
      if (batch['washing_completed_at'] != null) return const Right(null);

      await _client
          .from('milling_batches')
          .update({
            'washing_completed_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('batch_id', batchId);
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure('Could not complete batch washing: $e'));
    }
  }

  Future<Either<Failure, void>> sendSeparationStartSms(String requestId) async {
    try {
      final request = await _client
          .from('service_requests')
          .select('users:user_id(fname, contact_num)')
          .eq('service_request_id', requestId)
          .maybeSingle();
      final miner = request?['users'] as Map<String, dynamic>?;
      final phoneNumber = miner?['contact_num']?.toString().trim() ?? '';
      if (phoneNumber.isEmpty) {
        return const Left(
          ServerFailure('The miner has no phone number on file.'),
        );
      }

      final digits = phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');
      final recipient = digits.startsWith('63')
          ? digits
          : digits.startsWith('0')
          ? '63${digits.substring(1)}'
          : digits.startsWith('9')
          ? '63$digits'
          : digits;
      final firstName = miner?['fname']?.toString().trim();
      final greeting = firstName == null || firstName.isEmpty
          ? 'Customer'
          : firstName;
      final response = await http.post(
        Uri.parse(EnvConfig.philsmsEndpoint),
        headers: {
          'Authorization': 'Bearer ${EnvConfig.philsmsApiKey.trim()}',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'recipient': recipient,
          'sender_id': EnvConfig.philsmsSenderId,
          'type': 'plain',
          'message':
              'Dear $greeting,\nPlease proceed to the facility to begin separation (puga) for your service request.\nEmilio Gold Refinery Service Management Center (EGReS)',
        }),
      );
      Map<String, dynamic>? responseBody;
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) responseBody = decoded;
      } catch (_) {}
      if (response.statusCode >= 300) {
        final providerMessage = responseBody?['message']?.toString();
        return Left(
          ServerFailure(
            providerMessage == null || providerMessage.isEmpty
                ? 'Could not send separation SMS (${response.statusCode}).'
                : 'PhilSMS: $providerMessage',
          ),
        );
      }
      final providerStatus = responseBody?['status']?.toString().toLowerCase();
      if (providerStatus == 'error' || providerStatus == 'failed') {
        final providerMessage = responseBody?['message']?.toString();
        return Left(
          ServerFailure(
            providerMessage == null || providerMessage.isEmpty
                ? 'PhilSMS rejected the separation SMS.'
                : 'PhilSMS: $providerMessage',
          ),
        );
      }
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure('Could not send separation SMS: $e'));
    }
  }

  Future<Either<Failure, void>> sendProcessingCompletionSms(
    String requestId,
  ) async {
    try {
      final request = await _client
          .from('service_requests')
          .select('users:user_id(fname, contact_num)')
          .eq('service_request_id', requestId)
          .maybeSingle();
      final miner = request?['users'] as Map<String, dynamic>?;
      if (miner == null) {
        return const Left(
          ServerFailure('Could not find the miner for this request.'),
        );
      }

      final admins = await _client
          .from('users')
          .select('contact_num, role:role_id!inner(role)')
          .ilike('role.role', 'admin');
      final minerName = miner['fname']?.toString().trim();
      final recipients = <({String phone, String audience})>[];
      final minerPhone = miner['contact_num']?.toString().trim() ?? '';
      if (minerPhone.isNotEmpty) {
        recipients.add((phone: minerPhone, audience: 'miner'));
      }
      final seenAdminPhones = <String>{};
      for (final admin in admins) {
        final phone = admin['contact_num']?.toString().trim() ?? '';
        final normalizedDigits = phone.replaceAll(RegExp(r'[^0-9]'), '');
        if (phone.isNotEmpty && seenAdminPhones.add(normalizedDigits)) {
          recipients.add((phone: phone, audience: 'administrator'));
        }
      }
      if (recipients.isEmpty) {
        return const Left(
          ServerFailure(
            'No miner or administrator phone numbers are available.',
          ),
        );
      }

      final minerGreeting = minerName == null || minerName.isEmpty
          ? 'Customer'
          : minerName;
      final failures = <String>[];
      if (minerPhone.isEmpty) failures.add('miner: no phone number on file');
      if (seenAdminPhones.isEmpty) {
        failures.add('administrator: no phone number is available');
      }
      for (final target in recipients) {
        final digits = target.phone.replaceAll(RegExp(r'[^0-9]'), '');
        final recipient = digits.startsWith('63')
            ? digits
            : digits.startsWith('0')
            ? '63${digits.substring(1)}'
            : digits.startsWith('9')
            ? '63$digits'
            : digits;
        final message = target.audience == 'miner'
            ? 'Dear $minerGreeting,\nProcessing for your service request is complete. Please contact the facility regarding billing and the next steps.\nEmilio Gold Refinery Service Management Center (EGReS)'
            : 'Dear Administrator,\nProcessing for SR: ${requestId.substring(0, requestId.length < 8 ? requestId.length : 8).toUpperCase()} is complete and ready for billing.\nEmilio Gold Refinery Service Management Center (EGReS)';
        final response = await http.post(
          Uri.parse(EnvConfig.philsmsEndpoint),
          headers: {
            'Authorization': 'Bearer ${EnvConfig.philsmsApiKey.trim()}',
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: jsonEncode({
            'recipient': recipient,
            'sender_id': EnvConfig.philsmsSenderId,
            'type': 'plain',
            'message': message,
          }),
        );
        Map<String, dynamic>? responseBody;
        try {
          final decoded = jsonDecode(response.body);
          if (decoded is Map<String, dynamic>) responseBody = decoded;
        } catch (_) {}
        final providerStatus = responseBody?['status']
            ?.toString()
            .toLowerCase();
        if (response.statusCode >= 300 ||
            providerStatus == 'error' ||
            providerStatus == 'failed') {
          final providerMessage = responseBody?['message']?.toString();
          failures.add(
            '${target.audience}: ${providerMessage?.isNotEmpty == true ? providerMessage : 'SMS request failed (${response.statusCode})'}',
          );
        }
      }

      if (failures.isNotEmpty) {
        return Left(
          ServerFailure('Processing completed, but ${failures.join('; ')}.'),
        );
      }
      return const Right(null);
    } catch (e) {
      return Left(
        ServerFailure('Could not send processing completion SMS: $e'),
      );
    }
  }

  Future<Either<Failure, void>> updateMillingBatchDuration(
    String batchId,
    int newDuration,
  ) async {
    try {
      await _client
          .from('milling_batches')
          .update({'estimated_duration_minutes': newDuration})
          .eq('batch_id', batchId);
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  Future<Either<Failure, void>> triggerEmergencyStop({
    String? requestId,
    required String operatorId,
    required String reason,
    String? evidenceUrl,
    String? machineId,
    String? drumId,
    bool stopEntireMachine = false,
  }) async {
    try {
      final now = DateTime.now().toUtc().toIso8601String();

      // Persist the request emergency details while keeping the service itself
      // processing. The selected drum or machine determines which batches pause.
      if (requestId != null) {
        final scope = stopEntireMachine ? 'MACHINE FAILURE' : 'DRUM FAILURE';
        await _client
            .from('service_requests')
            .update({
              'emergency_reason': '$scope: $reason',
              'emergency_evidence_url': evidenceUrl,
              'emergency_stopped_at': now,
              'emergency_resolved_at': null,
              'updated_at': now,
            })
            .eq('service_request_id', requestId);
      }

      if (stopEntireMachine && machineId != null) {
        // --- MACHINE-WIDE STOP ---

        // 1. Mark Machine as emergency stop
        await _client
            .from('machines')
            .update({'status': 'emergency_stop'})
            .eq('machine_id', machineId);

        // 2. Mark ALL Drums of this machine as emergency stop
        await _client
            .from('drums')
            .update({'status': 'emergency_stop'})
            .eq('machine_id', machineId);

        // 3. Find all active service requests currently using ANY drum on this machine
        final drumsResponse = await _client
            .from('drums')
            .select('drum_id')
            .eq('machine_id', machineId);
        final drumIds = (drumsResponse as List)
            .map((d) => d['drum_id'].toString())
            .toList();

        if (drumIds.isNotEmpty) {
          final activeBatches = await _client
              .from('milling_batches')
              .select('service_request_id')
              .filter('drum_id', 'in', drumIds)
              .eq('status', 'milling');

          final requestIds = (activeBatches as List)
              .map((b) => b['service_request_id'].toString())
              .toSet()
              .toList();

          // Keep affected services processing. Equipment status pauses only
          // batches running on this machine, leaving other machines running.
          if (requestIds.isNotEmpty) {
            await _client
                .from('service_requests')
                .update({
                  'emergency_reason': 'MACHINE FAILURE: $reason',
                  'emergency_evidence_url': evidenceUrl,
                  'emergency_stopped_at': now,
                  'emergency_resolved_at': null,
                  'updated_at': now,
                })
                .filter('service_request_id', 'in', requestIds);

            for (final rid in requestIds) {
              await logAuditTrail(
                requestId: rid,
                userId: operatorId,
                action: 'EMERGENCY_STOP_MACHINE',
                previousStatus: 'processing',
                newStatus: 'processing',
                remarks: reason,
              );
            }
          }
        }
      } else if (drumId != null) {
        // --- SPECIFIC DRUM STOP ---

        // 1. Mark the specific drum
        await _client
            .from('drums')
            .update({'status': 'emergency_stop'})
            .eq('drum_id', drumId);

        // 2. Find the active service request using this drum
        final activeBatchResponse = await _client
            .from('milling_batches')
            .select('service_request_id')
            .eq('drum_id', drumId)
            .eq('status', 'milling');

        final List batches = activeBatchResponse as List;

        if (batches.isNotEmpty) {
          final rid = batches.first['service_request_id'].toString();

          // Keep the service processing; the stopped drum pauses only its own
          // milling batch.
          await _client
              .from('service_requests')
              .update({
                'emergency_reason': 'DRUM FAILURE: $reason',
                'emergency_evidence_url': evidenceUrl,
                'emergency_stopped_at': now,
                'emergency_resolved_at': null,
                'updated_at': now,
              })
              .eq('service_request_id', rid);

          // 4. Log Audit
          await logAuditTrail(
            requestId: rid,
            userId: operatorId,
            action: 'EMERGENCY_STOP_DRUM',
            previousStatus: 'processing',
            newStatus: 'processing',
            remarks: reason,
          );
        }
      }

      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  Future<Either<Failure, String>> uploadEmergencyEvidence({
    required String requestId,
    required PlatformFile photo,
  }) async {
    try {
      final bytes = photo.bytes;
      if (bytes == null || bytes.isEmpty) {
        return Left(ServerFailure('Could not read the selected photo.'));
      }
      final extension = photo.extension?.toLowerCase() ?? 'jpg';
      final safeExtension = RegExp(r'^[a-z0-9]{1,8}$').hasMatch(extension)
          ? extension
          : 'jpg';
      final path =
          'emergency/$requestId/${DateTime.now().toUtc().microsecondsSinceEpoch}.$safeExtension';
      final contentType = safeExtension == 'jpg' || safeExtension == 'jpeg'
          ? 'image/jpeg'
          : 'image/$safeExtension';
      final storage = _client.storage.from('serviceRequests');
      await storage.uploadBinary(
        path,
        bytes,
        fileOptions: FileOptions(
          cacheControl: '3600',
          upsert: false,
          contentType: contentType,
        ),
      );
      return Right(storage.getPublicUrl(path));
    } catch (e) {
      return Left(ServerFailure('Emergency photo upload failed: $e'));
    }
  }

  Future<Either<Failure, void>> updateMillQueueStatus({
    required String requestId,
    required String status,
  }) async {
    try {
      await _client
          .from('mill_queue')
          .update({'status': status})
          .eq('service_request_id', requestId);
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  Future<Either<Failure, void>> upsertParticipantFinancials(
    List<Map<String, dynamic>> records,
  ) async {
    try {
      await _client.from('service_participant_financials').upsert(records);
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  Future<Either<Failure, void>> saveBillingItems(
    List<Map<String, dynamic>> items,
  ) async {
    try {
      await _client.from('service_billing_items').insert(items);
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  Future<Either<Failure, List<Map<String, dynamic>>>>
  getAllBillingExpenses() async {
    try {
      final response = await _client
          .from('service_billing_items')
          .select(
            '*, service_requests(service_request_id, user_id, users(fname, lname))',
          )
          .order('created_at', ascending: false);
      return Right(List<Map<String, dynamic>>.from(response));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  Future<Either<Failure, void>> recordParticipantPayment(
    Map<String, dynamic> payment,
  ) async {
    try {
      await _client.from('participant_payments').insert(payment);
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  Future<Either<Failure, void>> submitIndividualServicePayment(
    Map<String, dynamic> payment,
  ) async {
    try {
      await _client.rpc(
        'submit_individual_service_payment',
        params: {
          'target_service_request_id': payment['service_request_id'],
          'payment_amount': payment['amount'],
          'target_receipt_url': payment['receipt_url'],
        },
      );
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  Future<Either<Failure, List<Map<String, dynamic>>>>
  getPendingPaymentReceipts() async {
    try {
      final response = await _client
          .from('participant_payments')
          .select(
            'payment_id, service_request_id, user_id, amount, receipt_url, payment_date, verification_status, users:user_id(fname, lname)',
          )
          .eq('verification_status', 'pending')
          .order('payment_date');
      return Right(List<Map<String, dynamic>>.from(response));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  Future<Either<Failure, void>> reviewPaymentReceipt({
    required String paymentId,
    required bool approve,
    String? reviewNote,
  }) async {
    try {
      await _client.rpc(
        'review_service_payment_receipt',
        params: {
          'target_payment_id': paymentId,
          'approve_payment': approve,
          'target_review_note': reviewNote,
        },
      );
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  Future<Either<Failure, void>> submitGroupServicePayment({
    required String requestId,
    required double amount,
    required String receiptUrl,
  }) async {
    try {
      await _client.rpc(
        'submit_group_service_payment',
        params: {
          'target_service_request_id': requestId,
          'payment_amount': amount,
          'target_receipt_url': receiptUrl,
        },
      );
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  Future<Either<Failure, List<Map<String, dynamic>>>>
  getParticipantPaymentHistory(String userId) async {
    try {
      final response = await _client
          .from('participant_payments')
          .select(
            'payment_id, service_request_id, user_id, amount, receipt_url, payment_date, verification_status, review_note',
          )
          .eq('user_id', userId)
          .order('payment_date', ascending: false);
      return Right(List<Map<String, dynamic>>.from(response));
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

  /// Completes a group billing request once every participant's share is paid.
  /// Returns true when this call moved the request into Completed.
  Future<Either<Failure, bool>> completeGroupBillingIfSettled({
    required String requestId,
    required String userId,
  }) async {
    try {
      final request = await _client
          .from('service_requests')
          .select('status, billing_id, participating_miners')
          .eq('service_request_id', requestId)
          .maybeSingle();
      if (request == null || request['status'] == 'completed') {
        return const Right(false);
      }

      final rows = await _client
          .from('service_participant_financials')
          .select('total_due, amount_paid, status')
          .eq('service_request_id', requestId);
      final participants = List<Map<String, dynamic>>.from(rows);
      if (participants.isEmpty) return const Right(false);
      final expectedParticipants = request['participating_miners'];
      if (expectedParticipants is List &&
          participants.length < expectedParticipants.length) {
        return const Right(false);
      }

      var totalPaid = 0.0;
      for (final participant in participants) {
        final due = (participant['total_due'] as num? ?? 0).toDouble();
        final paid = (participant['amount_paid'] as num? ?? 0).toDouble();
        if (participant['status'] != 'paid' && paid + 0.005 < due) {
          return const Right(false);
        }
        totalPaid += paid.clamp(0, due).toDouble();
      }

      final now = DateTime.now().toUtc();
      await _client
          .from('service_requests')
          .update({
            'status': 'completed',
            'payment_amount': totalPaid,
            'remaining_balance': 0,
            'payment_date': now.toIso8601String(),
            'billing_id':
                request['billing_id'] ?? 'BILL-${now.millisecondsSinceEpoch}',
            'updated_at': now.toIso8601String(),
          })
          .eq('service_request_id', requestId);

      await logAuditTrail(
        requestId: requestId,
        userId: userId,
        action: 'GROUP_BILLING_COMPLETED',
        previousStatus: request['status']?.toString() ?? 'goldHandoff',
        newStatus: 'completed',
        remarks:
            'All participant balances have been paid. Total paid: $totalPaid',
      );
      return const Right(true);
    } catch (e) {
      return Left(ServerFailure('Could not complete group billing: $e'));
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
    List<String> verificationPhotoUrls = const [],
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
        'verification_photo_urls': verificationPhotoUrls,
        'verified_at': DateTime.now().toIso8601String(),
      });
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  Future<Either<Failure, void>> submitOperatorVerificationAppeal({
    required String requestId,
    required String minerId,
    required String category,
    required String reason,
    required DateTime appealDate,
  }) async {
    try {
      final pending = await _client
          .from('operator_verification_appeals')
          .select('appeal_id')
          .eq('service_request_id', requestId)
          .eq('miner_id', minerId)
          .eq('status', 'pending')
          .maybeSingle();
      if (pending != null) {
        return const Left(
          ServerFailure('You already have a pending appeal for this request.'),
        );
      }

      await _client.from('operator_verification_appeals').insert({
        'service_request_id': requestId,
        'miner_id': minerId,
        'category': category,
        'reason': reason,
        'appeal_date':
            '${appealDate.year.toString().padLeft(4, '0')}-'
            '${appealDate.month.toString().padLeft(2, '0')}-'
            '${appealDate.day.toString().padLeft(2, '0')}',
      });
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure('Could not submit appeal: $e'));
    }
  }

  Future<Either<Failure, List<Map<String, dynamic>>>>
  getOperatorVerificationAppeals() async {
    try {
      final response = await _client
          .from('operator_verification_appeals')
          .select(
            '*, users:miner_id(fname, lname), '
            'service_requests!inner(service_type)',
          )
          .order('created_at', ascending: false);
      return Right(List<Map<String, dynamic>>.from(response));
    } catch (e) {
      return Left(ServerFailure('Could not load verification appeals: $e'));
    }
  }

  Future<Either<Failure, Set<String>>> getPendingAppealRequestIds(
    String minerId,
  ) async {
    try {
      final response = await _client
          .from('operator_verification_appeals')
          .select('service_request_id')
          .eq('miner_id', minerId)
          .eq('status', 'pending');
      return Right(
        (response as List)
            .map((row) => row['service_request_id'].toString())
            .toSet(),
      );
    } catch (e) {
      return Left(ServerFailure('Could not load your pending appeals: $e'));
    }
  }

  Future<Either<Failure, List<Map<String, dynamic>>>>
  getVerificationAppealsForMiner(String minerId) async {
    try {
      final response = await _client
          .from('operator_verification_appeals')
          .select(
            'appeal_id, service_request_id, category, reason, appeal_date, '
            'status, admin_response, miner_decision, created_at',
          )
          .eq('miner_id', minerId)
          .order('created_at', ascending: false);
      return Right(List<Map<String, dynamic>>.from(response));
    } catch (e) {
      return Left(ServerFailure('Could not load your appeals: $e'));
    }
  }

  Future<Either<Failure, void>> reviewOperatorVerificationAppeal({
    required String appealId,
    required String requestId,
    required String adminId,
    required String verificationId,
    required bool resolve,
    int? actualSacks,
    String? condition,
    String? state,
    String? source,
    String? processingEstimate,
    String? adminResponse,
  }) async {
    try {
      if (resolve) {
        await _client
            .from('operator_verified_services')
            .update({
              'actual_sacks': actualSacks,
              'condition': condition,
              'state': state,
              'source': source,
              'processing_estimate': processingEstimate,
            })
            .eq('verification_id', verificationId)
            .eq('service_request_id', requestId);
      }

      await _client
          .from('operator_verification_appeals')
          .update({
            'status': resolve ? 'resolved' : 'rejected',
            'reviewed_by': adminId,
            'reviewed_at': DateTime.now().toUtc().toIso8601String(),
            'admin_response': adminResponse,
          })
          .eq('appeal_id', appealId)
          .eq('status', 'pending');
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure('Could not finish appeal review: $e'));
    }
  }

  Future<Either<Failure, ServiceRequestModel>> updateServiceRequest(
    ServiceRequestModel model,
  ) async {
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

      // PINs are entered through several UI flows. Normalize surrounding
      // whitespace the same way as when a PIN is saved before hashing it.
      final normalizedPin = pin.trim();
      final inputHash = sha256.convert(utf8.encode(normalizedPin)).toString();
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

  Future<Either<Failure, List<Map<String, dynamic>>>> getAuditTrails(
    String requestId,
  ) async {
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

  Future<Either<Failure, List<String>>> uploadRequestPhotos(
    List<PlatformFile> photos,
  ) async {
    try {
      final List<String> urls = [];
      for (final file in photos) {
        if (file.bytes == null) continue;
        final extension = file.name.split('.').last;
        final path =
            'request_${DateTime.now().millisecondsSinceEpoch}_${urls.length}.$extension';

        await _client.storage
            .from('serviceRequests')
            .uploadBinary(
              path,
              file.bytes!,
              fileOptions: const FileOptions(
                cacheControl: '3600',
                upsert: false,
              ),
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
      final now = DateTime.now().toUtc().toIso8601String();
      final srRes = await _client
          .from('service_requests')
          .select('emergency_reason, emergency_stopped_at')
          .eq('service_request_id', requestId)
          .single();
      final reason = srRes['emergency_reason']?.toString() ?? '';
      final batchesRes = await getMillingBatches(requestId);
      final batches = batchesRes.getOrElse(() => <Map<String, dynamic>>[]);
      final activeBatches = batches
          .where((batch) => batch['status'] == 'milling')
          .toList();
      final stoppedBatches = activeBatches.where((batch) {
        final drumStopped =
            batch['drums']?['status']?.toString().toLowerCase() ==
            'emergency_stop';
        final machineStopped =
            batch['machines']?['status']?.toString().toLowerCase() ==
            'emergency_stop';
        return drumStopped || machineStopped;
      }).toList();
      final machineFailure =
          reason.startsWith('MACHINE FAILURE:') ||
          stoppedBatches.any(
            (batch) =>
                batch['machines']?['status']?.toString().toLowerCase() ==
                'emergency_stop',
          );

      final affectedBatches = <Map<String, dynamic>>[];
      final affectedRequestIds = <String>{requestId};
      if (machineFailure && stoppedBatches.isNotEmpty) {
        final machineId = stoppedBatches
            .firstWhere(
              (batch) => batch['machine_id'] != null,
              orElse: () => stoppedBatches.first,
            )['machine_id']
            ?.toString();
        if (machineId != null) {
          final drumRows = await _client
              .from('drums')
              .select('drum_id')
              .eq('machine_id', machineId);
          final drumIds = (drumRows as List)
              .map((row) => row['drum_id'].toString())
              .toList();
          if (drumIds.isNotEmpty) {
            final batchRows = await _client
                .from('milling_batches')
                .select(
                  'batch_id, service_request_id, milling_started_at, created_at',
                )
                .filter('drum_id', 'in', drumIds)
                .eq('status', 'milling');
            affectedBatches.addAll(
              (batchRows as List).cast<Map<String, dynamic>>(),
            );
            affectedRequestIds.addAll(
              affectedBatches.map(
                (batch) => batch['service_request_id'].toString(),
              ),
            );
          }
          await _client
              .from('machines')
              .update({'status': 'in_use'})
              .eq('machine_id', machineId);
          await _client
              .from('drums')
              .update({'status': 'in_use'})
              .eq('machine_id', machineId);
        }
      } else if (stoppedBatches.isNotEmpty) {
        affectedBatches.addAll(stoppedBatches);
        final drumIds = stoppedBatches
            .map((batch) => batch['drum_id']?.toString())
            .whereType<String>()
            .toSet()
            .toList();
        final machineIds = stoppedBatches
            .map((batch) => batch['machine_id']?.toString())
            .whereType<String>()
            .toSet()
            .toList();
        if (drumIds.isNotEmpty) {
          await _client
              .from('drums')
              .update({'status': 'in_use'})
              .inFilter('drum_id', drumIds);
        }
        for (final machineId in machineIds) {
          await _client
              .from('machines')
              .update({'status': 'in_use'})
              .eq('machine_id', machineId);
        }
      }

      final requestRows = await _client
          .from('service_requests')
          .select('service_request_id, emergency_stopped_at')
          .inFilter('service_request_id', affectedRequestIds.toList());
      final stoppedAtByRequest = <String, DateTime>{};
      for (final row in requestRows as List) {
        final stoppedAt = row['emergency_stopped_at']?.toString();
        if (stoppedAt != null) {
          stoppedAtByRequest[row['service_request_id'].toString()] =
              DateTime.parse(stoppedAt).toUtc();
        }
      }

      for (final batch in affectedBatches) {
        final batchRequestId = batch['service_request_id'].toString();
        final stoppedAt = stoppedAtByRequest[batchRequestId];
        if (stoppedAt == null) continue;
        final pausedFor = DateTime.now().toUtc().difference(stoppedAt);
        if (pausedFor <= Duration.zero) continue;
        final startValue =
            batch['milling_started_at']?.toString() ??
            batch['created_at'].toString();
        final shiftedStart = DateTime.parse(
          startValue,
        ).toUtc().add(pausedFor).toIso8601String();
        await _client
            .from('milling_batches')
            .update({'milling_started_at': shiftedStart})
            .eq('batch_id', batch['batch_id']);
      }

      await _client
          .from('service_requests')
          .update({'emergency_resolved_at': now, 'updated_at': now})
          .inFilter('service_request_id', affectedRequestIds.toList());

      await logAuditTrail(
        requestId: requestId,
        userId: adminId,
        action: 'EMERGENCY_RESOLVED',
        previousStatus: 'processing',
        newStatus: 'processing',
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
      final now = DateTime.now().toUtc();
      final request = await _client
          .from('service_requests')
          .select('emergency_stopped_at, emergency_resolved_at')
          .eq('service_request_id', requestId)
          .maybeSingle();
      final stoppedAtValue = request?['emergency_stopped_at']?.toString();
      final alreadyResolved = request?['emergency_resolved_at'] != null;
      // The admin resolution already accounts for the paused time. Only apply
      // this fallback adjustment when resuming an older, unresolved stop.
      if (stoppedAtValue != null && !alreadyResolved) {
        final stoppedAt = DateTime.parse(stoppedAtValue).toUtc();
        final pausedFor = now.difference(stoppedAt);
        if (!pausedFor.isNegative && pausedFor > Duration.zero) {
          final activeBatches = await _client
              .from('milling_batches')
              .select('batch_id, milling_started_at, created_at')
              .eq('service_request_id', requestId)
              .eq('status', 'milling');
          for (final batch in activeBatches as List) {
            final startValue =
                batch['milling_started_at']?.toString() ??
                batch['created_at'].toString();
            final shiftedStart = DateTime.parse(
              startValue,
            ).toUtc().add(pausedFor).toIso8601String();
            await _client
                .from('milling_batches')
                .update({'milling_started_at': shiftedStart})
                .eq('batch_id', batch['batch_id']);
          }
        }
      }

      await _client
          .from('service_requests')
          .update({
            'status': 'processing',
            'emergency_reason': null,
            'emergency_stopped_at': null,
            'emergency_resolved_at': null,
            'updated_at': now.toIso8601String(),
          })
          .eq('service_request_id', requestId);

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
