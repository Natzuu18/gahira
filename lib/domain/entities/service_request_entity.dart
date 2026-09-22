import 'package:equatable/equatable.dart';

enum ServiceRequestStatus {
  draft,
  pendingOperatorVerification,
  returnedToMiner,
  accepted,
  verified,
  queued,
  scheduled,
  assigned,
  processing,
  processingCompleted,
  goldHandoff,
  completed,
  cancelled,
  emergencyStop
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
  final String? approvedBy;
  final DateTime? approvedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? billingId;
  final String? emergencyReason;
  final DateTime? emergencyStoppedAt;
  final DateTime? emergencyResolvedAt;
  final String? creatorName; // Optional display name

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
    this.approvedBy,
    this.approvedAt,
    required this.createdAt,
    required this.updatedAt,
    this.billingId,
    this.emergencyReason,
    this.emergencyStoppedAt,
    this.emergencyResolvedAt,
    this.creatorName,
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
    String? approvedBy,
    DateTime? approvedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? billingId,
    String? emergencyReason,
    DateTime? emergencyStoppedAt,
    DateTime? emergencyResolvedAt,
    String? creatorName,
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
      approvedBy: approvedBy ?? this.approvedBy,
      approvedAt: approvedAt ?? this.approvedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      billingId: billingId ?? this.billingId,
      emergencyReason: emergencyReason ?? this.emergencyReason,
      emergencyStoppedAt: emergencyStoppedAt ?? this.emergencyStoppedAt,
      emergencyResolvedAt: emergencyResolvedAt ?? this.emergencyResolvedAt,
      creatorName: creatorName ?? this.creatorName,
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
        approvedBy,
        approvedAt,
        createdAt,
        updatedAt,
        billingId,
        emergencyReason,
        emergencyStoppedAt,
        emergencyResolvedAt,
        creatorName,
      ];
}

class MaterialDetails extends Equatable {
  final String? condition; // Rocky, Muddy, etc.
  final String? state; // Dry, Wet, Others
  final String? sourceType; // Associated Tunnel, Ball Mill, etc.
  final String? source; // Details of the source
  final int? numberOfSacks;
  final String? notes;
  final String? documentUrl;
  final List<String> photoUrls;
  final List<OperatorVerification> verifications; // List of verifications from Operators

  const MaterialDetails({
    this.condition,
    this.state,
    this.sourceType,
    this.source,
    this.numberOfSacks,
    this.notes,
    this.documentUrl,
    this.photoUrls = const [],
    this.verifications = const [],
  });

  MaterialDetails copyWith({
    String? condition,
    String? state,
    String? sourceType,
    String? source,
    int? numberOfSacks,
    String? notes,
    String? documentUrl,
    List<String>? photoUrls,
    List<OperatorVerification>? verifications,
  }) {
    return MaterialDetails(
      condition: condition ?? this.condition,
      state: state ?? this.state,
      sourceType: sourceType ?? this.sourceType,
      source: source ?? this.source,
      numberOfSacks: numberOfSacks ?? this.numberOfSacks,
      notes: notes ?? this.notes,
      documentUrl: documentUrl ?? this.documentUrl,
      photoUrls: photoUrls ?? this.photoUrls,
      verifications: verifications ?? this.verifications,
    );
  }

  @override
  List<Object?> get props => [
        condition,
        state,
        sourceType,
        source,
        numberOfSacks,
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
  final String? processingNotes;
  final int? sackedQuantity; 
  final int? minerSacksProcessed; // Tracks cumulative miner sacks processed in batches
  final DateTime? unloadingStartedAt;
  final DateTime? unloadingCompletedAt;
  final String? estimatedTime; // Set by Operator
  final DateTime? scheduledDate; // Set by Owner
  final List<String> assignedOperatorIds;
  final ProcessingStage currentStage;

  const ProcessingDetails({
    required this.requirements,
    this.processingNotes,
    this.sackedQuantity,
    this.minerSacksProcessed = 0,
    this.unloadingStartedAt,
    this.unloadingCompletedAt,
    this.estimatedTime,
    this.scheduledDate,
    required this.assignedOperatorIds,
    this.currentStage = ProcessingStage.none,
  });

  ProcessingDetails copyWith({
    String? requirements,
    String? processingNotes,
    int? sackedQuantity,
    int? minerSacksProcessed,
    DateTime? unloadingStartedAt,
    DateTime? unloadingCompletedAt,
    String? estimatedTime,
    DateTime? scheduledDate,
    List<String>? assignedOperatorIds,
    ProcessingStage? currentStage,
  }) {
    return ProcessingDetails(
      requirements: requirements ?? this.requirements,
      processingNotes: processingNotes ?? this.processingNotes,
      sackedQuantity: sackedQuantity ?? this.sackedQuantity,
      minerSacksProcessed: minerSacksProcessed ?? this.minerSacksProcessed,
      unloadingStartedAt: unloadingStartedAt ?? this.unloadingStartedAt,
      unloadingCompletedAt: unloadingCompletedAt ?? this.unloadingCompletedAt,
      estimatedTime: estimatedTime ?? this.estimatedTime,
      scheduledDate: scheduledDate ?? this.scheduledDate,
      assignedOperatorIds: assignedOperatorIds ?? this.assignedOperatorIds,
      currentStage: currentStage ?? this.currentStage,
    );
  }

  @override
  List<Object?> get props =>
      [requirements, processingNotes, sackedQuantity, minerSacksProcessed, unloadingStartedAt, unloadingCompletedAt, estimatedTime, scheduledDate, assignedOperatorIds, currentStage];
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
