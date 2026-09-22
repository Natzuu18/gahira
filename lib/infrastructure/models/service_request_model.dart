import '../../domain/entities/service_request_entity.dart';

class ServiceRequestModel extends ServiceRequestEntity {
  const ServiceRequestModel({
    required super.id,
    required super.creatorId,
    required super.participatingMinerIds,
    required super.materialDetails,
    required super.processingDetails,
    super.verificationDetails,
    super.financialDetails,
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
    // 1. Defensively parse user/miner info
    String? creatorName;
    if (json['users'] != null) {
      final u = json['users'];
      if (u is Map) {
        creatorName = '${u['fname'] ?? ''} ${u['lname'] ?? ''}'.trim();
      } else if (u is List && u.isNotEmpty) {
        final first = u[0];
        creatorName = '${first['fname'] ?? ''} ${first['lname'] ?? ''}'.trim();
      }
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

    // Parse mill_queue for scheduling info
    DateTime? scheduledDate;
    if (json['mill_queue'] != null) {
      final mq = json['mill_queue'];
      if (mq is List && mq.isNotEmpty) {
        final first = mq[0];
        if (first['scheduled_at'] != null) {
          scheduledDate = DateTime.parse(first['scheduled_at']);
        }
      } else if (mq is Map && mq['scheduled_at'] != null) {
        scheduledDate = DateTime.parse(mq['scheduled_at']);
      }
    }

    // Parse processing estimate from the latest verification
    String? estimatedTime;
    String? finalCondition = json['material_condition']?.toString();
    String? finalState = json['material_state']?.toString();
    String? finalSource = json['material_source']?.toString();
    int? finalSacks = json['quantity'] as int?;

    if (verificationList.isNotEmpty) {
      final latest = verificationList.last;
      estimatedTime = latest.processingEstimate;
      finalCondition = latest.condition;
      finalState = latest.state;
      finalSource = latest.source;
      finalSacks = latest.actualSacks;
    }

    return ServiceRequestModel(
      id: json['service_request_id']?.toString() ?? '',
      creatorId: json['user_id']?.toString() ?? '',
      participatingMinerIds: (json['participating_miners'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      materialDetails: MaterialDetails(
        condition: finalCondition,
        state: finalState,
        sourceType: json['material_source_type']?.toString(),
        source: finalSource,
        numberOfSacks: finalSacks,
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
        minerSacksProcessed: json['miner_sacks_processed'] as int? ?? 0,
        unloadingStartedAt: json['unloading_started_at'] != null ? DateTime.parse(json['unloading_started_at']) : null,
        unloadingCompletedAt: json['unloading_completed_at'] != null ? DateTime.parse(json['unloading_completed_at']) : null,
        estimatedTime: estimatedTime,
        scheduledDate: scheduledDate,
        assignedOperatorIds: [],
        currentStage: ProcessingStage.values.firstWhere(
          (e) => e.name == (json['current_processing_stage']?.toString()),
          orElse: () => ProcessingStage.none,
        ),
      ),
      financialDetails: FinancialDetails(
        goldWeightGrams: (json['gold_weight_grams'] as num?)?.toDouble(),
        goldBuyingPrice: (json['gold_buying_price'] as num?)?.toDouble(),
        goldPurchaseValue: (json['gold_purchase_value'] as num?)?.toDouble(),
        deductBillFromGold: json['deduct_bill_from_gold'] as bool? ?? false,
        processingFee: (json['processing_fee'] as num? ?? 0).toDouble(),
        otherExpenses: (json['other_expenses'] as num? ?? 0).toDouble(),
        totalBill: (json['total_bill'] as num? ?? 0).toDouble(),
        amountToMiner: (json['amount_to_miner'] as num? ?? 0).toDouble(),
        paymentAmount: (json['payment_amount'] as num? ?? 0).toDouble(),
        paymentReceiptUrl: json['payment_receipt_url']?.toString(),
        paymentDate: json['payment_date'] != null ? DateTime.parse(json['payment_date']) : null,
        participantBreakdown: (json['service_participant_financials'] as List<dynamic>?)
            ?.map((e) => ParticipantFinancial(
                  userId: e['user_id']?.toString() ?? '',
                  userName: e['users'] != null ? '${e['users']['fname']} ${e['users']['lname']}' : null,
                  shareAmount: (e['share_amount'] as num? ?? 0).toDouble(),
                  individualExpenses: (e['individual_expenses'] as num? ?? 0).toDouble(),
                  individualExpenseReason: e['individual_expense_reason']?.toString(),
                  totalDue: (e['total_due'] as num? ?? 0).toDouble(),
                  amountPaid: (e['amount_paid'] as num? ?? 0).toDouble(),
                  status: e['status']?.toString() ?? 'unpaid',
                ))
            .toList(),
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
      'miner_sacks_processed': processingDetails.minerSacksProcessed,
      'unloading_started_at': processingDetails.unloadingStartedAt?.toIso8601String(),
      'unloading_completed_at': processingDetails.unloadingCompletedAt?.toIso8601String(),
      'billing_id': billingId,
      'gold_weight_grams': financialDetails?.goldWeightGrams,
      'gold_buying_price': financialDetails?.goldBuyingPrice,
      'gold_purchase_value': financialDetails?.goldPurchaseValue,
      'deduct_bill_from_gold': financialDetails?.deductBillFromGold,
      'processing_fee': financialDetails?.processingFee,
      'other_expenses': financialDetails?.otherExpenses,
      'total_bill': financialDetails?.totalBill,
      'amount_to_miner': financialDetails?.amountToMiner,
      'payment_amount': financialDetails?.paymentAmount,
      'payment_receipt_url': financialDetails?.paymentReceiptUrl,
      'payment_date': financialDetails?.paymentDate?.toIso8601String(),
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
      financialDetails: entity.financialDetails,
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
