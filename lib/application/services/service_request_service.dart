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
    final pinValid = await _repository.verifyUserPin(creatorId, pin);
    return pinValid.fold(
      (l) => Left(l),
      (isValid) async {
        if (!isValid) return const Left(ValidationFailure('Incorrect PIN'));

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

        final result = await _repository.createServiceRequest(model);
        return result.fold(
          (l) => Left(l),
          (created) async {
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

            await _repository.logAuditTrail(
              requestId: created.id,
              userId: assistedByOperatorId ?? creatorId,
              action: isOperatorAssisted
                  ? 'OPERATOR_ASSISTED_CREATE'
                  : 'CREATE_REQUEST',
              previousStatus: 'None',
              newStatus: _enumName(model.status),
              remarks: isOperatorAssisted
                  ? 'Created by Operator $assistedByOperatorId on behalf of Miner $creatorId'
                  : null,
            );
            return Right(created);
          },
        );
      },
    );
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
    final pinValid = await _repository.verifyUserPin(creatorId, pin);
    return pinValid.fold(
      (l) => Left(l),
      (isValid) async {
        if (!isValid) return const Left(ValidationFailure('Incorrect PIN'));

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
        return result.fold(
          (l) => Left(l),
          (updated) async {
            await _repository.logAuditTrail(
              requestId: updated.id,
              userId: creatorId,
              action: 'UPDATE_REQUEST',
              previousStatus: 'Unknown',
              newStatus: _enumName(updated.status),
              remarks: 'Request details updated by miner',
            );
            return Right(updated);
          },
        );
      },
    );
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
    final pinValid = await _repository.verifyUserPin(operatorId, pin);
    return pinValid.fold(
      (l) => Left(l),
      (isValid) async {
        if (!isValid) return const Left(ValidationFailure('Incorrect PIN'));

        const newStatus = ServiceRequestStatus.verified;

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

        return result.fold(
          (l) => Left(l),
          (_) async {
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

            await _repository.logAuditTrail(
              requestId: requestId,
              userId: operatorId,
              action: isAccurate ? 'VERIFY_ACCURATE' : 'VERIFY_INACCURATE',
              previousStatus: currentStatus,
              newStatus: _enumName(newStatus),
              remarks: remarks,
            );
            return const Right(null);
          },
        );
      },
    );
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

    return result.fold(
      (l) => Left(l),
      (_) async {
        await _repository.logAuditTrail(
          requestId: requestId,
          userId: minerId,
          action: accept ? 'ACCEPT_CORRECTIONS' : 'CANCEL_REQUEST',
          previousStatus: currentStatus,
          newStatus: _enumName(newStatus),
        );
        return const Right(null);
      },
    );
  }

  Future<Either<Failure, void>> addToGeneralQueue({
    required String requestId,
    required String userId,
    required String currentStatus,
  }) async {
    final statusResult = await _repository.updateRequestStatus(
      requestId: requestId,
      status: _enumName(ServiceRequestStatus.verified),
      userId: userId,
    );

    return statusResult.fold(
      (l) => Left(l),
      (_) async {
        final queueResult = await _repository.addToMillQueue(
          requestId: requestId,
          userId: userId,
          queueType: 'general',
        );

        return queueResult.fold(
          (l) => Left(l),
          (_) async {
            await _repository.logAuditTrail(
              requestId: requestId,
              userId: userId,
              action: 'ADD_TO_QUEUE',
              previousStatus: currentStatus,
              newStatus: _enumName(ServiceRequestStatus.verified),
              remarks: 'Moved to general mill queue by admin',
            );
            return const Right(null);
          },
        );
      },
    );
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

    return result.fold(
      (l) => Left(l),
      (_) async {
        final queueResult = await _repository.addToMillQueue(
          requestId: requestId,
          userId: ownerId,
          queueType: 'scheduled',
          scheduledAt: scheduledDate,
        );

        return queueResult.fold(
          (l) => Left(l),
          (_) async {
            await _repository.logAuditTrail(
              requestId: requestId,
              userId: ownerId,
              action: 'SCHEDULE_AND_ASSIGN',
              previousStatus: currentStatus,
              newStatus: _enumName(ServiceRequestStatus.scheduled),
              remarks: 'Assigned to ${assignedOperatorIds.length} operators and added to mill queue',
            );
            return const Right(null);
          },
        );
      },
    );
  }

  Future<Either<Failure, void>> updateProcessingStatus({
    required String requestId,
    required String operatorId,
    required ServiceRequestStatus newStatus,
    required String currentStatus,
    ProcessingStage? newStage,
    int? sackedQuantity,
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
      },
    );

    return result.fold(
      (l) => Left(l),
      (_) async {
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
      },
    );
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

    return statusResult.fold(
      (l) => Left(l),
      (_) async {
        final ongoingResult = await _repository.claimServiceRequest(
          requestId: requestId,
          operatorId: operatorId,
        );

        return ongoingResult.fold(
          (l) => Left(l),
          (_) async {
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
          },
        );
      },
    );
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

    return result.fold(
      (l) => Left(l),
      (_) async {
        await _repository.logAuditTrail(
          requestId: requestId,
          userId: ownerId,
          action: 'COMPLETE_BILLING',
          previousStatus: currentStatus,
          newStatus: _enumName(ServiceRequestStatus.completed),
        );
        return const Right(null);
      },
    );
  }
}
