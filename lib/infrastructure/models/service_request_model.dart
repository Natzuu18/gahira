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
    super.approvedBy,
    super.approvedAt,
    required super.createdAt,
    required super.updatedAt,
    super.billingId,
    super.creatorName,
  });

  factory ServiceRequestModel.fromJson(Map<String, dynamic> json) {
    // Parse user/miner info if it exists
    String? creatorName;
    if (json['users'] != null) {
      final u = json['users'];
      creatorName = '${u['fname'] ?? ''} ${u['lname'] ?? ''}'.trim();
    }
    
    // Parse verifications if they exist (from join on operator_verified_services)
    final List<OperatorVerification> verificationList = [];
    if (json['operator_verified_services'] != null) {
      final List<dynamic> verificationsRaw = json['operator_verified_services'] as List;
      for (var v in verificationsRaw) {
        verificationList.add(OperatorVerification(
          id: v['verification_id']?.toString() ?? '',
          operatorId: v['operator_id']?.toString() ?? '',
          verifiedAt: v['verified_at'] != null ? DateTime.parse(v['verified_at']) : DateTime.now(),
          actualSacks: v['actual_sacks'] ?? 0,
          condition: v['condition'] ?? '',
          state: v['state'] ?? '',
          source: v['source'] ?? '',
          isAccurate: v['is_accurate'] ?? true,
          notes: v['correction_notes'],
          processingEstimate: v['processing_estimate'],
        ));
      }
    }

    return ServiceRequestModel(
      id: json['service_request_id']?.toString() ?? '',
      creatorId: json['user_id']?.toString() ?? '',
      participatingMinerIds: (json['participating_miners'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      materialDetails: MaterialDetails(
        condition: json['material_condition']?.toString(),
        state: json['material_state']?.toString(),
        sourceType: json['material_source_type']?.toString(),
        source: json['material_source']?.toString(),
        numberOfSacks: json['quantity'] as int?,
        notes: json['material_notes']?.toString(),
        documentUrl: null,
        photoUrls: (json['photo_urls'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [],
        verifications: verificationList,
      ),
      processingDetails: ProcessingDetails(
        requirements: json['material_notes']?.toString() ?? '',
        processingNotes: json['processing_notes']?.toString(),
        sackedQuantity: json['sacked_quantity'] as int?,
        assignedOperatorIds: [],
        currentStage: ProcessingStage.values.firstWhere(
          (e) => e.name == (json['current_processing_stage']?.toString()),
          orElse: () => ProcessingStage.none,
        ),
      ),
      status: ServiceRequestStatus.values.firstWhere(
        (e) => e.name == (json['status']?.toString()),
        orElse: () => ServiceRequestStatus.pendingOperatorVerification,
      ),
      isOperatorAssisted: json['is_operator_assisted'] as bool? ?? false,
      assistedByOperatorId: json['assisted_by_operator_id']?.toString(),
      approvedBy: json['approved_by']?.toString(),
      approvedAt: json['approved_at'] != null ? DateTime.parse(json['approved_at']) : null,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : DateTime.now(),
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : DateTime.now(),
      billingId: json['billing_id']?.toString(),
      creatorName: creatorName,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': creatorId,
      'service_type': 'Milling',
      'request_date': createdAt.toIso8601String().split('T')[0],
      'quantity': materialDetails.numberOfSacks ?? 0,
      'status': status.name,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'material_condition': materialDetails.condition,
      'material_state': materialDetails.state,
      'material_source_type': materialDetails.sourceType,
      'material_source': materialDetails.source,
      'material_notes': materialDetails.notes,
      'photo_urls': materialDetails.photoUrls,
      'participating_miners': participatingMinerIds,
      'is_operator_assisted': isOperatorAssisted,
      'assisted_by_operator_id': assistedByOperatorId,
      'approved_by': approvedBy,
      'approved_at': approvedAt?.toIso8601String(),
      'current_processing_stage': processingDetails.currentStage.name,
      'processing_notes': processingDetails.processingNotes,
      'sacked_quantity': processingDetails.sackedQuantity,
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
      isOperatorAssisted: entity.isOperatorAssisted,
      assistedByOperatorId: entity.assistedByOperatorId,
      approvedBy: entity.approvedBy,
      approvedAt: entity.approvedAt,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
      billingId: entity.billingId,
    );
  }
}
