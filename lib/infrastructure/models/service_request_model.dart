import '../../domain/entities/service_request_entity.dart';

class ServiceRequestModel extends ServiceRequestEntity {
  const ServiceRequestModel({
    required super.id,
    required super.creatorId,
    required super.participatingMinerIds,
    required super.materialDetails,
    required super.processingDetails,
    super.verificationDetails,
    required super.status,
    super.isOperatorAssisted,
    super.assistedByOperatorId,
    required super.createdAt,
    required super.updatedAt,
    super.billingId,
  });

  factory ServiceRequestModel.fromJson(Map<String, dynamic> json) {
    return ServiceRequestModel(
      id: json['service_request_id'] as String,
      creatorId: json['creator_id'] as String,
      participatingMinerIds: (json['participating_miners'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      materialDetails: MaterialDetails(
        type: json['material_type'] as String,
        condition: json['material_condition'] as String?,
        numberOfSacks: json['number_of_sacks'] as int?,
        weight: (json['material_weight'] as num).toDouble(),
        actualWeight: (json['actual_weight'] as num?)?.toDouble(),
        source: json['material_source'] as String?,
        notes: json['material_notes'] as String?,
        documentUrl: json['document_url'] as String?,
        corrections: json['material_corrections'] as String?,
      ),
      processingDetails: ProcessingDetails(
        requirements: json['processing_requirements'] as String,
        estimatedTime: json['estimated_time'] as String?,
        scheduledDate: json['scheduled_date'] != null
            ? DateTime.parse(json['scheduled_date'] as String)
            : null,
        assignedOperatorIds: (json['assigned_operators'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [],
        currentStage: ProcessingStage.values.firstWhere(
          (e) => e.name == (json['current_processing_stage'] as String?),
          orElse: () => ProcessingStage.none,
        ),
      ),
      verificationDetails: json['verified_by'] != null
          ? VerificationDetails(
              operatorId: json['verified_by'] as String,
              verifiedAt: DateTime.parse(json['verified_at'] as String),
              remarks: json['verification_remarks'] as String?,
              isAccurate: json['is_accurate'] as bool? ?? true,
            )
          : null,
      status: ServiceRequestStatus.values.firstWhere(
        (e) => e.name == (json['status'] as String),
        orElse: () => ServiceRequestStatus.draft,
      ),
      isOperatorAssisted: json['is_operator_assisted'] as bool? ?? false,
      assistedByOperatorId: json['assisted_by_operator_id'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      billingId: json['billing_id'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'service_request_id': id,
      'creator_id': creatorId,
      'participating_miners': participatingMinerIds,
      'material_type': materialDetails.type,
      'material_condition': materialDetails.condition,
      'number_of_sacks': materialDetails.numberOfSacks,
      'material_weight': materialDetails.weight,
      'actual_weight': materialDetails.actualWeight,
      'material_source': materialDetails.source,
      'material_notes': materialDetails.notes,
      'document_url': materialDetails.documentUrl,
      'material_corrections': materialDetails.corrections,
      'processing_requirements': processingDetails.requirements,
      'estimated_time': processingDetails.estimatedTime,
      'scheduled_date': processingDetails.scheduledDate?.toIso8601String(),
      'assigned_operators': processingDetails.assignedOperatorIds,
      'current_processing_stage': processingDetails.currentStage.name,
      'verified_by': verificationDetails?.operatorId,
      'verified_at': verificationDetails?.verifiedAt.toIso8601String(),
      'verification_remarks': verificationDetails?.remarks,
      'is_accurate': verificationDetails?.isAccurate,
      'status': status.name,
      'is_operator_assisted': isOperatorAssisted,
      'assisted_by_operator_id': assistedByOperatorId,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'billing_id': billingId,
    };
  }

  factory ServiceRequestModel.fromEntity(ServiceRequestEntity entity) {
    return ServiceRequestModel(
      id: entity.id,
      creatorId: entity.creatorId,
      participatingMinerIds: entity.participatingMinerIds,
      materialDetails: entity.materialDetails,
      processingDetails: entity.processingDetails,
      verificationDetails: entity.verificationDetails,
      status: entity.status,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
      billingId: entity.billingId,
    );
  }
}
