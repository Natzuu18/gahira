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
    // Parse verifications if they exist (from join on operator_verified_services)
    final List<OperatorVerification> verificationList = [];
    if (json['operator_verified_services'] != null) {
      final List<dynamic> verificationsRaw = json['operator_verified_services'] as List;
      for (var v in verificationsRaw) {
        verificationList.add(OperatorVerification(
          id: v['verification_id']?.toString() ?? '',
          operatorId: v['operator_id']?.toString() ?? '',
          verifiedAt: v['verified_at'] != null ? DateTime.parse(v['verified_at']) : DateTime.now(),
          actualWeight: (v['actual_weight'] ?? 0.0).toDouble(),
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
        type: json['purpose']?.toString() ?? 'Ore',
        condition: json['material_condition']?.toString(),
        state: json['material_state']?.toString(),
        sourceType: json['material_source_type']?.toString(),
        source: json['material_source']?.toString(),
        numberOfSacks: json['quantity'] as int?,
        weight: (json['material_weight'] ?? 0.0).toDouble(),
        notes: json['material_notes']?.toString(),
        documentUrl: null,
        photoUrls: (json['photo_urls'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [],
        verifications: verificationList,
      ),
      processingDetails: const ProcessingDetails(
        requirements: '',
        assignedOperatorIds: [],
      ),
      status: ServiceRequestStatus.values.firstWhere(
        (e) => e.name == (json['status']?.toString()),
        orElse: () => ServiceRequestStatus.pendingOperatorVerification,
      ),
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : DateTime.now(),
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': creatorId,
      'service_type': 'Milling',
      'request_date': createdAt.toIso8601String().split('T')[0],
      'quantity': materialDetails.numberOfSacks ?? 0,
      'purpose': materialDetails.type,
      'status': status.name,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'material_condition': materialDetails.condition,
      'material_state': materialDetails.state,
      'material_source_type': materialDetails.sourceType,
      'material_source': materialDetails.source,
      'material_notes': materialDetails.notes,
      'photo_urls': materialDetails.photoUrls,
      'material_weight': materialDetails.weight,
      'participating_miners': participatingMinerIds,
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
