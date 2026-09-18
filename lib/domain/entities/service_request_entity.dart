import 'package:equatable/equatable.dart';

enum ServiceRequestStatus {
  draft,
  pendingOperatorVerification,
  returnedToMiner,
  accepted,
  verified,
  scheduled,
  assigned,
  processing,
  processingCompleted,
  goldHandoff,
  completed,
  cancelled
}

enum ProcessingStage {
  none,
  rebagging,
  loading,
  millingCrushing,
  unloading,
  washingSeparation,
  refining,
  completed
}

class ServiceRequestEntity extends Equatable {
  final String id;
  final String creatorId; // Logged-in Miner
  final List<String> participatingMinerIds;
  final MaterialDetails materialDetails;
  final ProcessingDetails processingDetails;
  final VerificationDetails? verificationDetails;
  final ServiceRequestStatus status;
  final bool isOperatorAssisted;
  final String? assistedByOperatorId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? billingId;

  const ServiceRequestEntity({
    required this.id,
    required this.creatorId,
    required this.participatingMinerIds,
    required this.materialDetails,
    required this.processingDetails,
    this.verificationDetails,
    required this.status,
    this.isOperatorAssisted = false,
    this.assistedByOperatorId,
    required this.createdAt,
    required this.updatedAt,
    this.billingId,
  });

  ServiceRequestEntity copyWith({
    String? id,
    String? creatorId,
    List<String>? participatingMinerIds,
    MaterialDetails? materialDetails,
    ProcessingDetails? processingDetails,
    VerificationDetails? verificationDetails,
    ServiceRequestStatus? status,
    bool? isOperatorAssisted,
    String? assistedByOperatorId,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? billingId,
  }) {
    return ServiceRequestEntity(
      id: id ?? this.id,
      creatorId: creatorId ?? this.creatorId,
      participatingMinerIds:
          participatingMinerIds ?? this.participatingMinerIds,
      materialDetails: materialDetails ?? this.materialDetails,
      processingDetails: processingDetails ?? this.processingDetails,
      verificationDetails: verificationDetails ?? this.verificationDetails,
      status: status ?? this.status,
      isOperatorAssisted: isOperatorAssisted ?? this.isOperatorAssisted,
      assistedByOperatorId: assistedByOperatorId ?? this.assistedByOperatorId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      billingId: billingId ?? this.billingId,
    );
  }

  @override
  List<Object?> get props => [
        id,
        creatorId,
        participatingMinerIds,
        materialDetails,
        processingDetails,
        verificationDetails,
        status,
        isOperatorAssisted,
        assistedByOperatorId,
        createdAt,
        updatedAt,
        billingId,
      ];
}

class MaterialDetails extends Equatable {
  final String type;
  final String? condition; // Rocky, Muddy, etc.
  final String? state; // Dry, Wet, Others
  final String? sourceType; // Associated Tunnel, Ball Mill, etc.
  final String? source; // Details of the source
  final int? numberOfSacks;
  final double weight; // Estimated weight
  final double? actualWeight; // Set by Operator
  final String? notes;
  final String? documentUrl;
  final List<String> photoUrls;
  final List<OperatorVerification> verifications; // List of verifications from Operators

  const MaterialDetails({
    required this.type,
    this.condition,
    this.state,
    this.sourceType,
    this.source,
    this.numberOfSacks,
    required this.weight,
    this.actualWeight,
    this.notes,
    this.documentUrl,
    this.photoUrls = const [],
    this.verifications = const [],
  });

  MaterialDetails copyWith({
    String? type,
    String? condition,
    String? state,
    String? sourceType,
    String? source,
    int? numberOfSacks,
    double? weight,
    double? actualWeight,
    String? notes,
    String? documentUrl,
    List<String>? photoUrls,
    List<OperatorVerification>? verifications,
  }) {
    return MaterialDetails(
      type: type ?? this.type,
      condition: condition ?? this.condition,
      state: state ?? this.state,
      sourceType: sourceType ?? this.sourceType,
      source: source ?? this.source,
      numberOfSacks: numberOfSacks ?? this.numberOfSacks,
      weight: weight ?? this.weight,
      actualWeight: actualWeight ?? this.actualWeight,
      notes: notes ?? this.notes,
      documentUrl: documentUrl ?? this.documentUrl,
      photoUrls: photoUrls ?? this.photoUrls,
      verifications: verifications ?? this.verifications,
    );
  }

  @override
  List<Object?> get props => [
        type,
        condition,
        state,
        sourceType,
        source,
        numberOfSacks,
        weight,
        actualWeight,
        notes,
        documentUrl,
        photoUrls,
        verifications
      ];
}

class OperatorVerification extends Equatable {
  final String id;
  final String operatorId;
  final DateTime verifiedAt;
  
  // Verified/Corrected Material Details
  final double actualWeight;
  final int actualSacks;
  final String condition;
  final String state;
  final String source;
  
  // Verification Outcome
  final bool isAccurate;
  final String? notes; // correction_notes
  final String? processingEstimate;

  const OperatorVerification({
    required this.id,
    required this.operatorId,
    required this.verifiedAt,
    required this.actualWeight,
    required this.actualSacks,
    required this.condition,
    required this.state,
    required this.source,
    required this.isAccurate,
    this.notes,
    this.processingEstimate,
  });

  @override
  List<Object?> get props => [
    id, 
    operatorId, 
    verifiedAt, 
    actualWeight, 
    actualSacks, 
    condition, 
    state, 
    source, 
    isAccurate, 
    notes, 
    processingEstimate
  ];
}

class ProcessingDetails extends Equatable {
  final String requirements;
  final String? estimatedTime; // Set by Operator
  final DateTime? scheduledDate; // Set by Owner
  final List<String> assignedOperatorIds;
  final ProcessingStage currentStage;

  const ProcessingDetails({
    required this.requirements,
    this.estimatedTime,
    this.scheduledDate,
    required this.assignedOperatorIds,
    this.currentStage = ProcessingStage.none,
  });

  ProcessingDetails copyWith({
    String? requirements,
    String? estimatedTime,
    DateTime? scheduledDate,
    List<String>? assignedOperatorIds,
    ProcessingStage? currentStage,
  }) {
    return ProcessingDetails(
      requirements: requirements ?? this.requirements,
      estimatedTime: estimatedTime ?? this.estimatedTime,
      scheduledDate: scheduledDate ?? this.scheduledDate,
      assignedOperatorIds: assignedOperatorIds ?? this.assignedOperatorIds,
      currentStage: currentStage ?? this.currentStage,
    );
  }

  @override
  List<Object?> get props =>
      [requirements, estimatedTime, scheduledDate, assignedOperatorIds, currentStage];
}

class VerificationDetails extends Equatable {
  final String operatorId;
  final DateTime verifiedAt;
  final String? remarks;
  final bool isAccurate;

  const VerificationDetails({
    required this.operatorId,
    required this.verifiedAt,
    this.remarks,
    required this.isAccurate,
  });

  @override
  List<Object?> get props => [operatorId, verifiedAt, remarks, isAccurate];
}
