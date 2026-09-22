import 'package:dartz/dartz.dart';
import '../../core/error/failures.dart';
import '../../domain/entities/service_request_entity.dart';
import '../../infrastructure/models/service_request_model.dart';
import '../../infrastructure/repositories/supabase_service_request_repository.dart';

class ServiceRequestService {
  final SupabaseServiceRequestRepository _repository;

  ServiceRequestService(this._repository);

  // Helper to get enum name safely
  String _enumName(dynamic e) => e.toString().split('.').last;

  Future<Either<Failure, ServiceRequestEntity>> createRequest({
    required String creatorId,
    required List<String> participatingMinerIds,
    String? materialCondition,
    String? materialState,
    String? materialSourceType,
    int? numberOfSacks,
    String? source,
    String? notes,
    String? documentUrl,
    List<String> photoUrls = const [],
    required String processingRequirements,
    required String pin,
    bool isOperatorAssisted = false,
    String? assistedByOperatorId,
    String? assistedByOperatorName,
    String? estimatedTime, // Only for assisted
  }) async {
    // 1. Verify PIN
    final pinValid = await _repository.verifyUserPin(creatorId, pin);
    if (pinValid.isLeft()) return Left((pinValid as Left<Failure, bool>).value);
    if (!(pinValid as Right<Failure, bool>).value) return const Left(ValidationFailure('Incorrect PIN'));

    // 2. Create Request model
    final model = ServiceRequestModel(
      id: '', 
      creatorId: creatorId,
      participatingMinerIds: participatingMinerIds,
      materialDetails: MaterialDetails(
        condition: materialCondition,
        state: materialState,
        sourceType: materialSourceType,
        numberOfSacks: numberOfSacks,
        source: source,
        notes: notes,
        documentUrl: documentUrl,
        photoUrls: photoUrls,
      ),
      processingDetails: ProcessingDetails(
        requirements: processingRequirements,
        assignedOperatorIds: [],
        estimatedTime: estimatedTime,
      ),
      status: isOperatorAssisted
          ? ServiceRequestStatus.verified
          : ServiceRequestStatus.pendingOperatorVerification,
      isOperatorAssisted: isOperatorAssisted,
      assistedByOperatorId: assistedByOperatorId,
      approvedBy: isOperatorAssisted ? assistedByOperatorId : null,
      approvedAt: isOperatorAssisted ? DateTime.now() : null,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    // 3. Save to Repository
    final result = await _repository.createServiceRequest(model);
    if (result.isLeft()) return result;
    
    final created = (result as Right<Failure, ServiceRequestEntity>).value;

    // 4. Direct Verification if assisted
    if (isOperatorAssisted && assistedByOperatorId != null) {
      await _repository.submitOperatorVerification(
        requestId: created.id,
        operatorId: assistedByOperatorId,
        actualSacks: numberOfSacks ?? 0,
        condition: materialCondition ?? 'Rocky',
        state: materialState ?? 'Dry',
        source: source ?? 'N/A',
        isAccurate: true,
        processingEstimate: estimatedTime ?? '3 Hours',
        notes: '${assistedByOperatorName ?? "Operator"} operator assisted request',
      );
    }

    // 5. Log Audit Trail
    await _repository.logAuditTrail(
      requestId: created.id,
      userId: assistedByOperatorId ?? creatorId,
      action: isOperatorAssisted ? 'OPERATOR_ASSISTED_CREATE' : 'CREATE_REQUEST',
      previousStatus: 'None',
      newStatus: _enumName(model.status),
      remarks: isOperatorAssisted
          ? 'Created by Operator $assistedByOperatorId on behalf of Miner $creatorId'
          : null,
    );

    return Right(created);
  }

  Future<Either<Failure, ServiceRequestEntity>> updateRequest({
    required String requestId,
    required String creatorId,
    required List<String> participatingMinerIds,
    String? materialCondition,
    String? materialState,
    String? materialSourceType,
    int? numberOfSacks,
    String? source,
    String? notes,
    List<String> photoUrls = const [],
    required String pin,
  }) async {
    // 1. Verify PIN
    final pinValid = await _repository.verifyUserPin(creatorId, pin);
    if (pinValid.isLeft()) return Left((pinValid as Left<Failure, bool>).value);
    if (!(pinValid as Right<Failure, bool>).value) return const Left(ValidationFailure('Incorrect PIN'));

    final model = ServiceRequestModel(
      id: requestId,
      creatorId: creatorId,
      participatingMinerIds: participatingMinerIds,
      materialDetails: MaterialDetails(
        condition: materialCondition,
        state: materialState,
        sourceType: materialSourceType,
        numberOfSacks: numberOfSacks,
        source: source,
        notes: notes,
        photoUrls: photoUrls,
      ),
      processingDetails: const ProcessingDetails(
        requirements: '',
        assignedOperatorIds: [],
      ),
      status: ServiceRequestStatus.pendingOperatorVerification,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final result = await _repository.updateServiceRequest(model);
    if (result.isLeft()) return result;

    final updated = (result as Right<Failure, ServiceRequestEntity>).value;

    await _repository.logAuditTrail(
      requestId: updated.id,
      userId: creatorId,
      action: 'UPDATE_REQUEST',
      previousStatus: 'Unknown',
      newStatus: _enumName(updated.status),
      remarks: 'Request details updated by miner',
    );

    return Right(updated);
  }

  Future<Either<Failure, void>> verifyMaterial({
    required String requestId,
    required String operatorId,
    required int actualSacks,
    required String condition,
    required String state,
    required String source,
    required String estimatedTime,
    required bool isAccurate,
    required String pin,
    String? remarks,
    required String currentStatus,
  }) async {
    // 1. Verify PIN
    final pinValid = await _repository.verifyUserPin(operatorId, pin);
    if (pinValid.isLeft()) return Left((pinValid as Left<Failure, bool>).value);
    if (!(pinValid as Right<Failure, bool>).value) return const Left(ValidationFailure('Incorrect PIN'));

    const newStatus = ServiceRequestStatus.verified;

    // 2. Update status in main table
    final result = await _repository.updateRequestStatus(
      requestId: requestId,
      status: _enumName(newStatus),
      userId: operatorId,
      additionalData: {
        'updated_at': DateTime.now().toIso8601String(),
        'approved_by': operatorId,
        'approved_at': DateTime.now().toIso8601String(),
      },
    );

    if (result.isLeft()) return result;

    // 3. Submit verification record
    await _repository.submitOperatorVerification(
      requestId: requestId,
      operatorId: operatorId,
      actualSacks: actualSacks,
      condition: condition,
      state: state,
      source: source,
      isAccurate: isAccurate,
      processingEstimate: estimatedTime,
      notes: remarks,
    );

    // 4. Log Audit Trail
    await _repository.logAuditTrail(
      requestId: requestId,
      userId: operatorId,
      action: isAccurate ? 'VERIFY_ACCURATE' : 'VERIFY_INACCURATE',
      previousStatus: currentStatus,
      newStatus: _enumName(newStatus),
      remarks: remarks,
    );

    return const Right(null);
  }

  Future<Either<Failure, void>> minerRespondToReturn({
    required String requestId,
    required String minerId,
    required bool accept,
    required String currentStatus,
  }) async {
    final newStatus = accept ? ServiceRequestStatus.accepted : ServiceRequestStatus.cancelled;
    final result = await _repository.updateRequestStatus(
      requestId: requestId,
      status: _enumName(newStatus),
      userId: minerId,
    );

    if (result.isLeft()) return result;

    await _repository.logAuditTrail(
      requestId: requestId,
      userId: minerId,
      action: accept ? 'ACCEPT_CORRECTIONS' : 'CANCEL_REQUEST',
      previousStatus: currentStatus,
      newStatus: _enumName(newStatus),
    );
    return const Right(null);
  }

  Future<Either<Failure, void>> addToGeneralQueue({
    required String requestId,
    required String userId,
    required String currentStatus,
  }) async {
    final statusResult = await _repository.updateRequestStatus(
      requestId: requestId,
      status: _enumName(ServiceRequestStatus.queued),
      userId: userId,
    );

    if (statusResult.isLeft()) return statusResult;

    final queueResult = await _repository.addToMillQueue(
      requestId: requestId,
      userId: userId,
      queueType: 'general',
    );

    if (queueResult.isLeft()) return queueResult;

    await _repository.logAuditTrail(
      requestId: requestId,
      userId: userId,
      action: 'ADD_TO_QUEUE',
      previousStatus: currentStatus,
      newStatus: _enumName(ServiceRequestStatus.queued),
      remarks: 'Moved to general mill queue by admin',
    );
    return const Right(null);
  }

  Future<Either<Failure, void>> ownerScheduleAndAssign({
    required String requestId,
    required String ownerId,
    required DateTime scheduledDate,
    required List<String> assignedOperatorIds,
    required String currentStatus,
  }) async {
    final result = await _repository.updateRequestStatus(
      requestId: requestId,
      status: _enumName(ServiceRequestStatus.scheduled),
      userId: ownerId,
      additionalData: {
        'approved_by': ownerId,
        'approved_at': scheduledDate.toIso8601String(),
      },
    );

    if (result.isLeft()) return result;

    final queueResult = await _repository.addToMillQueue(
      requestId: requestId,
      userId: ownerId,
      queueType: 'scheduled',
      scheduledAt: scheduledDate,
    );

    if (queueResult.isLeft()) return queueResult;

    await _repository.logAuditTrail(
      requestId: requestId,
      userId: ownerId,
      action: 'SCHEDULE_AND_ASSIGN',
      previousStatus: currentStatus,
      newStatus: _enumName(ServiceRequestStatus.scheduled),
      remarks: 'Assigned to ${assignedOperatorIds.length} operators and added to mill queue',
    );
    return const Right(null);
  }

  Future<Either<Failure, void>> updateProcessingStatus({
    required String requestId,
    required String operatorId,
    required ServiceRequestStatus newStatus,
    required String currentStatus,
    ProcessingStage? newStage,
    int? sackedQuantity,
    int? minerSacksProcessed,
    String? remarks,
  }) async {
    final result = await _repository.updateRequestStatus(
      requestId: requestId,
      status: _enumName(newStatus),
      userId: operatorId,
      additionalData: {
        if (remarks != null) 'processing_notes': remarks,
        if (newStage != null) 'current_processing_stage': _enumName(newStage),
        if (sackedQuantity != null) 'sacked_quantity': sackedQuantity,
        if (minerSacksProcessed != null) 'miner_sacks_processed': minerSacksProcessed,
      },
    );

    if (result.isLeft()) return result;

    if (newStatus == ServiceRequestStatus.processing) {
      try {
        await _repository.updateMillQueueStatus(requestId: requestId, status: 'in_progress');
      } catch (_) {}
    } else if (newStatus == ServiceRequestStatus.processingCompleted) {
      try {
        await _repository.updateMillQueueStatus(requestId: requestId, status: 'completed');
      } catch (_) {}
    }

    await _repository.logAuditTrail(
      requestId: requestId,
      userId: operatorId,
      action: 'UPDATE_PROCESSING',
      previousStatus: currentStatus,
      newStatus: _enumName(newStatus),
      remarks: newStage != null ? 'Moved to stage: ${_enumName(newStage)}' : remarks,
    );
    return const Right(null);
  }

  Future<Either<Failure, void>> claimAndStartService({
    required String requestId,
    required String operatorId,
    required String currentStatus,
  }) async {
    final statusResult = await _repository.updateRequestStatus(
      requestId: requestId,
      status: _enumName(ServiceRequestStatus.processing),
      userId: operatorId,
      additionalData: {'current_processing_stage': _enumName(ProcessingStage.rebagging)},
    );

    if (statusResult.isLeft()) return statusResult;

    final ongoingResult = await _repository.claimServiceRequest(
      requestId: requestId,
      operatorId: operatorId,
    );

    if (ongoingResult.isLeft()) return ongoingResult;

    await _repository.updateMillQueueStatus(requestId: requestId, status: 'in_progress');

    await _repository.logAuditTrail(
      requestId: requestId,
      userId: operatorId,
      action: 'CLAIM_SERVICE',
      previousStatus: currentStatus,
      newStatus: _enumName(ServiceRequestStatus.processing),
      remarks: 'Service claimed and started by operator',
    );
    return const Right(null);
  }

  Future<Either<Failure, void>> completeBilling({
    required String requestId,
    required String ownerId,
    required String billingId,
    required String currentStatus,
  }) async {
    final result = await _repository.updateRequestStatus(
      requestId: requestId,
      status: _enumName(ServiceRequestStatus.completed),
      userId: ownerId,
      additionalData: {'billing_id': billingId},
    );

    if (result.isLeft()) return result;

    await _repository.logAuditTrail(
      requestId: requestId,
      userId: ownerId,
      action: 'COMPLETE_BILLING',
      previousStatus: currentStatus,
      newStatus: _enumName(ServiceRequestStatus.completed),
    );
    return const Right(null);
  }

  Future<Either<Failure, void>> startBatchMilling({
    required String requestId,
    required String operatorId,
    required String machineId,
    required String drumId,
    required int inputSacks,
    required int outputSacks,
    required int estimatedDurationMinutes,
  }) async {
    // 1. Create the batch record
    final batchResult = await _repository.createMillingBatch(
      requestId: requestId,
      operatorId: operatorId,
      machineId: machineId,
      drumId: drumId,
      inputSacks: inputSacks,
      outputSacks: outputSacks,
      estimatedDurationMinutes: estimatedDurationMinutes,
    );

    return batchResult.fold(
      (l) => Left(l),
      (_) async {
        // 2. Update the main request with current total sacked quantity
        // First get all batches for this request
        final batchesRes = await _repository.getMillingBatches(requestId);
        int totalOutputSacks = 0;
        batchesRes.fold((_) => null, (list) {
          for (var b in list) {
            totalOutputSacks += (b['output_sacks'] as int? ?? 0);
          }
        });

        await _repository.updateRequestStatus(
          requestId: requestId,
          status: ServiceRequestStatus.processing.name,
          userId: operatorId,
          additionalData: {
            'sacked_quantity': totalOutputSacks,
            'current_processing_stage': ProcessingStage.millingCrushing.name,
          },
        );

        // 3. Log Audit
        await _repository.logAuditTrail(
          requestId: requestId,
          userId: operatorId,
          action: 'START_BATCH',
          previousStatus: ServiceRequestStatus.processing.name,
          newStatus: ServiceRequestStatus.processing.name,
          remarks: 'Started batch milling with $inputSacks sacks (Resacked to $outputSacks)',
        );
        
        return const Right(null);
      },
    );
  }

  Future<Either<Failure, void>> extendBatchMilling({
    required String batchId,
    required int additionalMinutes,
    required String requestId,
    required String operatorId,
  }) async {
    // 1. Get current duration
    final batchesRes = await _repository.getMillingBatches(requestId);
    int currentDuration = 30;
    batchesRes.fold((_) => null, (list) {
      final b = list.firstWhere((element) => element['batch_id'] == batchId);
      currentDuration = b['estimated_duration_minutes'] as int? ?? 30;
    });

    // 2. Update
    final result = await _repository.updateMillingBatchDuration(batchId, currentDuration + additionalMinutes);
    
    return result.fold(
      (l) => Left(l),
      (_) async {
        await _repository.logAuditTrail(
          requestId: requestId,
          userId: operatorId,
          action: 'EXTEND_BATCH',
          previousStatus: _enumName(ServiceRequestStatus.processing),
          newStatus: _enumName(ServiceRequestStatus.processing),
          remarks: 'Extended batch milling by $additionalMinutes minutes',
        );
        return const Right(null);
      },
    );
  }

  Future<Either<Failure, void>> completeBatchMilling({
    required String batchId,
    required String machineId,
    required String drumId,
    required String requestId,
    required String operatorId,
  }) async {
    final result = await _repository.completeMillingBatch(
      batchId: batchId,
      machineId: machineId,
      drumId: drumId,
    );

    return result.fold(
      (l) => Left(l),
      (_) async {
        await _repository.logAuditTrail(
          requestId: requestId,
          userId: operatorId,
          action: 'COMPLETE_BATCH',
          previousStatus: ServiceRequestStatus.processing.name,
          newStatus: ServiceRequestStatus.processing.name,
          remarks: 'Completed batch milling',
        );
        return const Right(null);
      },
    );
  }

  Future<Either<Failure, void>> triggerEmergencyStop({
    String? requestId,
    required String operatorId,
    required String reason,
    String? machineId,
    String? drumId,
    bool stopEntireMachine = false,
  }) async {
    return _repository.triggerEmergencyStop(
      requestId: requestId,
      operatorId: operatorId,
      reason: reason,
      machineId: machineId,
      drumId: drumId,
      stopEntireMachine: stopEntireMachine,
    );
  }

  Future<Either<Failure, void>> resolveEmergencyStop({
    required String requestId,
    required String adminId,
  }) async {
    return _repository.resolveEmergencyStop(requestId: requestId, adminId: adminId);
  }

  Future<Either<Failure, void>> resumeProcessing({
    required String requestId,
    required String operatorId,
  }) async {
    return _repository.resumeProcessing(requestId: requestId, operatorId: operatorId);
  }
}
