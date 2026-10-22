import 'package:flutter/material.dart';
import 'package:dartz/dartz.dart' hide State;
import 'package:intl/intl.dart';
import '../../core/error/failures.dart';
import '../../application/services/service_request_service.dart';
import '../../domain/entities/service_request_entity.dart';
import '../../domain/entities/user_entity.dart';
import '../../infrastructure/repositories/supabase_service_request_repository.dart';
import '../../infrastructure/repositories/supabase_user_repository.dart';
import '../../infrastructure/models/user_model.dart';
import '../../infrastructure/supabase/supabase_config.dart';
import '../shared_widgets/appColor.dart';
import '../shared_widgets/adminDrawer.dart';
import '../shared_widgets/themeToggleButton.dart';
import '../shared_widgets/audit_trail_viewer.dart';
import '../admin/billing_page.dart';
import '../shared_widgets/monitoring_page.dart';

class ServiceRequestPage extends StatefulWidget {
  const ServiceRequestPage({super.key});

  @override
  State<ServiceRequestPage> createState() => _ServiceRequestPageState();
}

class _ServiceRequestPageState extends State<ServiceRequestPage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final SupabaseServiceRequestRepository _repository =
      SupabaseServiceRequestRepository();
  late final ServiceRequestService _service;
  final SupabaseUserRepository _userRepository = SupabaseUserRepository();

  List<ServiceRequestEntity> _requests = [];
  Set<String> _emergencyStoppedRequestIds = {};
  List<UserEntity> _allUsers = [];
  List<Map<String, dynamic>> _verificationAppeals = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _filterStatus = 'All';
  String _scheduleTimelineFilter =
      'All'; // New options: 'All', 'Today', 'Upcoming'
  final Set<String> _showOriginalDataIds = {};

  @override
  void initState() {
    super.initState();
    _service = ServiceRequestService(_repository);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final requestsResult = await _repository.getServiceRequests();
    final activeBatchesResult = await _repository.getActiveMillingBatches();
    final usersResult = await _userRepository.getAllUsers();
    final appealsResult = await _repository.getOperatorVerificationAppeals();

    final stoppedRequestIds = <String>{};
    activeBatchesResult.fold((_) {}, (batches) {
      for (final batch in batches) {
        final drumStopped =
            batch['drums']?['status']?.toString().toLowerCase() ==
            'emergency_stop';
        final machineStopped =
            batch['machines']?['status']?.toString().toLowerCase() ==
            'emergency_stop';
        final requestId = batch['service_request_id']?.toString();
        if ((drumStopped || machineStopped) && requestId != null) {
          stoppedRequestIds.add(requestId);
        }
      }
    });

    setState(() {
      _requests = requestsResult.getOrElse(() => []);
      _emergencyStoppedRequestIds = stoppedRequestIds;
      _allUsers = usersResult.getOrElse(() => []);
      _verificationAppeals = appealsResult.getOrElse(() => []);
      _isLoading = false;
    });
  }

  String _getCreatorName(ServiceRequestEntity request) {
    if (request.creatorName != null && request.creatorName!.isNotEmpty) {
      return request.creatorName!;
    }
    return _getUserName(request.creatorId);
  }

  String _getUserName(String id) {
    UserEntity? user;
    for (final u in _allUsers) {
      if (u.userId == id) {
        user = u;
        break;
      }
    }
    return user != null ? '${user.fname} ${user.lname}' : 'Unknown';
  }

  String _serviceReference(String id) =>
      'SR: ${id.substring(0, id.length < 8 ? id.length : 8).toUpperCase()}';

  Widget _buildLogoMark() {    return Image.asset(
      'assets/img/EGReS.png',
      width: 34,
      height: 34,
      fit: BoxFit.contain,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: context.bgColor,
      appBar: AppBar(
        backgroundColor: context.surfaceColor,
        elevation: 0,
        leadingWidth: 64,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16),
          child: _buildLogoMark(),
        ),
        title: const Text(
          'SERVICES',
          style: TextStyle(
            color: kGold,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
          ),
        ),
        actions: const [ThemeToggleButton(), SizedBox(width: 8)],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: kGold))
          : Column(
              children: [
                _buildFilterBar(),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _loadData,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _filteredRequests.length,
                      itemBuilder: (context, index) {
                        final req = _filteredRequests[index];
                        return _buildRequestCard(
                          req,
                          index: _filterStatus == 'Queued' ? index + 1 : null,
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  List<ServiceRequestEntity> get _filteredRequests {
    List<ServiceRequestEntity> list = List.from(_requests);
    final query = _searchQuery.trim().toLowerCase();
    if (query.isNotEmpty) {
      list = list.where((request) {
        final requester = _getCreatorName(request).toLowerCase();
        final requestId = request.id.toLowerCase();
        final participants = request.participatingMinerIds
            .join(' ')
            .toLowerCase();
        return requester.contains(query) ||
            requestId.contains(query) ||
            participants.contains(query);
      }).toList();
    }
    if (_filterStatus != 'All') {
      list = list
          .where(
            (r) =>
                r.status.toString().split('.').last.toLowerCase() ==
                    _filterStatus.toLowerCase() ||
                (_filterStatus == 'Processing' &&
                    r.status == ServiceRequestStatus.emergencyStop &&
                    r.emergencyResolvedAt == null),
          )
          .toList();
    }

    // Sort logic for Queue: Sort items in the queue by their creation time so their UI index acts as dynamic position counter
    // Only display items that haven't moved to 'processing' or 'completed' stages yet
    if (_filterStatus == 'Verified' || _filterStatus == 'Queued') {
      list = list
          .where(
            (r) =>
                r.status != ServiceRequestStatus.processing &&
                r.status != ServiceRequestStatus.processingCompleted &&
                r.status != ServiceRequestStatus.completed,
          )
          .toList();
      list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    }
    // Timeline filter logic for Scheduled services
    if (_filterStatus == 'Scheduled') {
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final todayEnd = todayStart.add(const Duration(days: 1));

      if (_scheduleTimelineFilter == 'Today') {
        list = list
            .where(
              (r) =>
                  r.approvedAt != null &&
                  r.approvedAt!.isAfter(todayStart) &&
                  r.approvedAt!.isBefore(todayEnd),
            )
            .toList();
      } else if (_scheduleTimelineFilter == 'Upcoming') {
        list = list
            .where(
              (r) => r.approvedAt != null && r.approvedAt!.isAfter(todayEnd),
            )
            .toList();
      }

      // Sort scheduled by date
      list.sort(
        (a, b) => a.approvedAt?.compareTo(b.approvedAt ?? DateTime.now()) ?? 0,
      );
    }
    return list;
  }

  Widget _buildFilterBar() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          color: context.surfaceColor,
          child: Column(
            children: [
              TextField(
                style: TextStyle(color: context.textColor),
                cursorColor: kGold,
                decoration: InputDecoration(
                  hintText:
                      'Search by requester, service ID, or participant...',
                  hintStyle: TextStyle(
                    color: context.mutedTextColor,
                    fontSize: 13,
                  ),
                  prefixIcon: const Icon(Icons.search, color: kGold),
                  suffixIcon: _searchQuery.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Clear search',
                          icon: const Icon(Icons.clear, color: kGold),
                          onPressed: () => setState(() => _searchQuery = ''),
                        ),
                  filled: true,
                  fillColor: context.bgColor,
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 16,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: kGold.withValues(alpha: 0.2)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: kGold.withValues(alpha: 0.2)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: kGold, width: 1.5),
                  ),
                ),
                onChanged: (value) => setState(() => _searchQuery = value),
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    'Verified',
                    'Queued',
                    'Scheduled',
                    'Processing',
                    'ProcessingCompleted',
                  ].map((status) => Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: _buildStatusFilterChip(status),
                  )).toList(),
                ),
              ),
            ],
          ),
        ),
        if (_filterStatus == 'Scheduled')
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            decoration: BoxDecoration(
              color: context.surfaceColor,
              border: Border(top: BorderSide(color: kGold.withOpacity(0.1))),
            ),
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 4,
              runSpacing: 4,
              children: ['All', 'Today', 'Upcoming'].map((timeline) {
                final isSelected = _scheduleTimelineFilter == timeline;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ActionChip(
                    label: Text(
                      timeline,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isSelected
                            ? kBlack
                            : context.textColor.withOpacity(0.7),
                      ),
                    ),
                    onPressed: () =>
                        setState(() => _scheduleTimelineFilter = timeline),
                    backgroundColor: isSelected ? kGold : context.bgColor,
                    padding: EdgeInsets.zero,
                    side: BorderSide(
                      color: isSelected ? kGold : kGold.withOpacity(0.1),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }

  Widget _buildStatusFilterChip(String status) {
    final isSelected = _filterStatus == status;
    final count = _requests
        .where((request) => request.status.name.toLowerCase() == status.toLowerCase())
        .length;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        ChoiceChip(
          label: Text(
            status,
            style: TextStyle(
              fontSize: 12,
              color: isSelected ? kBlack : context.textColor,
            ),
          ),
          selected: isSelected,
          onSelected: (_) => setState(() {
            _filterStatus = isSelected ? 'All' : status;
            if (_filterStatus != 'Scheduled') _scheduleTimelineFilter = 'All';
          }),
          selectedColor: kGold,
          backgroundColor: context.bgColor,
          showCheckmark: false,
        ),
        if (count > 0)
          Positioned(
            top: -6,
            right: -6,
            child: Container(
              constraints: const BoxConstraints(minWidth: 25, minHeight: 25),
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF28B8D4), Color(0xFF28B88A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(13),
                border: Border.all(color: context.surfaceColor, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF28B8A5).withValues(alpha: 0.32),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Text(
                '$count',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildVerificationAppealCard(
    Map<String, dynamic> appeal,
    OperatorVerification? verification,
  ) {
    final minerValue = appeal['users'];
    final miner = minerValue is Map ? minerValue : const <String, dynamic>{};
    final minerName =
        '${miner['fname'] ?? ''} ${miner['lname'] ?? ''}'.trim();
    final appealDate = appeal['appeal_date']?.toString() ?? 'Unknown date';
    final status = appeal['status']?.toString() ?? 'pending';

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.deepOrange.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.deepOrange.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${appeal['category'] ?? 'Appeal'} • $appealDate',
            style: const TextStyle(
              color: Colors.deepOrange,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
          if (minerName.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Submitted by $minerName',
              style: TextStyle(color: context.mutedTextColor, fontSize: 11),
            ),
          ],
          const SizedBox(height: 6),
          Text(
            appeal['reason']?.toString() ?? '',
            style: TextStyle(color: context.textColor, fontSize: 13),
          ),
          if ((appeal['evidence_url']?.toString() ?? '').isNotEmpty) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                appeal['evidence_url'].toString(),
                height: 180,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  height: 72,
                  alignment: Alignment.center,
                  color: context.surfaceColor,
                  child: const Text('Appeal image could not be loaded.'),
                ),
              ),
            ),
          ],
          if ((appeal['admin_response']?.toString() ?? '').isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Admin response: ${appeal['admin_response']}',
              style: TextStyle(color: context.mutedTextColor, fontSize: 12),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              Chip(
                label: Text(status.toUpperCase()),
                visualDensity: VisualDensity.compact,
                backgroundColor: switch (status) {
                  'pending' => Colors.orange.withValues(alpha: 0.15),
                  'rejected' => Colors.red.withValues(alpha: 0.12),
                  _ => Colors.teal.withValues(alpha: 0.15),
                },
                labelStyle: TextStyle(
                  color: switch (status) {
                    'pending' => Colors.deepOrange,
                    'rejected' => Colors.redAccent,
                    _ => Colors.teal,
                  },
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              if (status == 'pending')
                TextButton.icon(
                  onPressed: () => _reviewVerificationAppeal(
                    appeal,
                    verification,
                  ),
                  icon: const Icon(Icons.rate_review_outlined, size: 17),
                  label: const Text('Review appeal'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _reviewVerificationAppeal(
    Map<String, dynamic> appeal,
    OperatorVerification? verification,
  ) async {
    if (verification == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Verified data could not be loaded.')),
      );
      return;
    }

    final adminId = SupabaseConfig.client.auth.currentUser?.id;
    if (adminId == null) return;

    final sacksController = TextEditingController(
      text: verification.actualSacks.toString(),
    );
    final conditionController = TextEditingController(text: verification.condition);
    final stateController = TextEditingController(text: verification.state);
    final sourceController = TextEditingController(text: verification.source);
    final estimateController = TextEditingController(
      text: verification.processingEstimate ?? '',
    );
    final responseController = TextEditingController();
    var isSaving = false;
    String? validationMessage;

    final decision = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          backgroundColor: dialogContext.surfaceColor,
          title: const Text('Review Miner Appeal'),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${appeal['category']}: ${appeal['reason']}'),
                  const SizedBox(height: 12),
                  if ((appeal['evidence_url']?.toString() ?? '').isNotEmpty)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        appeal['evidence_url'].toString(),
                        height: 190,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => const SizedBox(
                          height: 72,
                          child: Center(
                            child: Text('Appeal image could not be loaded.'),
                          ),
                        ),
                      ),
                    )
                  else
                    const Text(
                      'No image evidence was attached to this appeal.',
                      style: TextStyle(color: Colors.redAccent),
                    ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: sacksController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Correct actual sack count',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: conditionController,
                    decoration: const InputDecoration(
                      labelText: 'Correct material condition',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: stateController,
                    decoration: const InputDecoration(
                      labelText: 'Correct material state',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: sourceController,
                    decoration: const InputDecoration(
                      labelText: 'Correct source details',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: estimateController,
                    decoration: const InputDecoration(
                      labelText: 'Processing estimate',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: responseController,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Response to miner (optional)',
                      border: OutlineInputBorder(),
                      alignLabelWithHint: true,
                    ),
                  ),
                  if (validationMessage != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      validationMessage!,
                      style: const TextStyle(color: Colors.redAccent),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSaving ? null : () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            TextButton.icon(
              onPressed: isSaving
                  ? null
                  : () => _saveAppealDecision(
                      dialogContext,
                      setDialogState,
                      appeal: appeal,
                      verification: verification,
                      adminId: adminId,
                      resolve: false,
                      sacksController: sacksController,
                      conditionController: conditionController,
                      stateController: stateController,
                      sourceController: sourceController,
                      estimateController: estimateController,
                      responseController: responseController,
                      setSaving: (value) => isSaving = value,
                      setValidationMessage: (value) => validationMessage = value,
                    ),
              icon: const Icon(Icons.close_rounded, color: Colors.redAccent),
              label: const Text('Reject Appeal'),
            ),
            FilledButton.icon(
              onPressed: isSaving
                  ? null
                  : () => _saveAppealDecision(
                      dialogContext,
                      setDialogState,
                      appeal: appeal,
                      verification: verification,
                      adminId: adminId,
                      resolve: true,
                      sacksController: sacksController,
                      conditionController: conditionController,
                      stateController: stateController,
                      sourceController: sourceController,
                      estimateController: estimateController,
                      responseController: responseController,
                      setSaving: (value) => isSaving = value,
                      setValidationMessage: (value) => validationMessage = value,
                    ),
              icon: const Icon(Icons.check_circle_outline_rounded),
              label: const Text('Save & Resolve'),
            ),
          ],
        ),
      ),
    );

    sacksController.dispose();
    conditionController.dispose();
    stateController.dispose();
    sourceController.dispose();
    estimateController.dispose();
    responseController.dispose();
    if (decision != null && mounted) {
      await _loadData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            decision
                ? 'Appeal resolved and verified data updated.'
                : 'Appeal rejected.',
          ),
        ),
      );
    }
  }

  Future<void> _saveAppealDecision(
    BuildContext dialogContext,
    StateSetter setDialogState, {
    required Map<String, dynamic> appeal,
    required OperatorVerification verification,
    required String adminId,
    required bool resolve,
    required TextEditingController sacksController,
    required TextEditingController conditionController,
    required TextEditingController stateController,
    required TextEditingController sourceController,
    required TextEditingController estimateController,
    required TextEditingController responseController,
    required ValueChanged<bool> setSaving,
    required ValueChanged<String?> setValidationMessage,
  }) async {
    final sacks = int.tryParse(sacksController.text.trim());
    if (resolve &&
        (sacks == null ||
            sacks < 0 ||
            conditionController.text.trim().isEmpty ||
            stateController.text.trim().isEmpty ||
            sourceController.text.trim().isEmpty ||
            estimateController.text.trim().isEmpty)) {
      setDialogState(
        () => setValidationMessage(
          'Enter a valid sack count and complete all corrected verification fields.',
        ),
      );
      return;
    }

    setDialogState(() {
      setSaving(true);
      setValidationMessage(null);
    });
    final result = await _repository.reviewOperatorVerificationAppeal(
      appealId: appeal['appeal_id'].toString(),
      requestId: appeal['service_request_id'].toString(),
      adminId: adminId,
      verificationId: verification.id,
      resolve: resolve,
      actualSacks: sacks,
      condition: conditionController.text.trim(),
      state: stateController.text.trim(),
      source: sourceController.text.trim(),
      processingEstimate: estimateController.text.trim(),
      adminResponse: responseController.text.trim(),
    );

    result.fold(
      (failure) => setDialogState(() {
        setSaving(false);
        setValidationMessage(failure.message);
      }),
      (_) => Navigator.pop(dialogContext, resolve),
    );
  }

  Widget _buildRequestCard(ServiceRequestEntity request, {int? index}) {
    final hasActiveEmergency =
        (request.status == ServiceRequestStatus.emergencyStop &&
            request.emergencyResolvedAt == null) ||
        _emergencyStoppedRequestIds.contains(request.id);
    final requestAppeals = _verificationAppeals
        .where((appeal) => appeal['service_request_id']?.toString() == request.id)
        .toList();
    final bool isKorpo = request.participatingMinerIds.length > 1;
    final String typeLabel = isKorpo
        ? 'KORPO (${request.participatingMinerIds.length})'
        : 'INDIVIDUAL';
    final String requesterName = _getCreatorName(request);
    final String dateStr = DateFormat(
      'MMM dd, yyyy • hh:mm a',
    ).format(request.createdAt);

    final latestVerification = request.materialDetails.verifications.isNotEmpty
        ? request.materialDetails.verifications.last
        : null;

    final bool showOriginal =
        _showOriginalDataIds.contains(request.id) || latestVerification == null;
    final displaySacks = showOriginal
        ? (request.materialDetails.numberOfSacks ?? 0)
        : latestVerification.actualSacks;
    final displayCondition = showOriginal
        ? (request.materialDetails.condition ?? 'N/A')
        : latestVerification.condition;
    final displayState = showOriginal
        ? (request.materialDetails.state ?? 'N/A')
        : latestVerification.state;

    return Card(
      color: context.surfaceColor,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: hasActiveEmergency ? Colors.red : kGold.withOpacity(0.1),
          width: hasActiveEmergency ? 2 : 1,
        ),
      ),
      child: ExpansionTile(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _serviceReference(request.id),
                  style: const TextStyle(
                    color: kGold,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  requesterName,
                  style: TextStyle(
                    color: context.mutedTextColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.4,
                  ),
                ),
                if (latestVerification != null && !showOriginal)
                  Text(
                    'Verified by ${latestVerification.operatorName ?? 'Operator'}',
                    style: TextStyle(
                      color: Colors.teal,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              ],
            ),
            if (hasActiveEmergency)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.red.withOpacity(0.55)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Colors.red, size: 15),
                    SizedBox(width: 4),
                    Text(
                      'EMERGENCY STOP',
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                        fontSize: 9,
                      ),
                    ),
                  ],
                ),
              ),
            if (index != null)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.orange.withOpacity(0.3)),
                ),
                child: Text(
                  'QUEUE POSITION: #$index',
                  style: const TextStyle(
                    color: Colors.orange,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: isKorpo
                        ? Colors.blue.withOpacity(0.1)
                        : kGold.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    typeLabel,
                    style: TextStyle(
                      color: isKorpo ? Colors.blue : kGold,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  dateStr,
                  style: TextStyle(color: context.mutedTextColor, fontSize: 11),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Status: ${request.status.toString().split('.').last}',
              style: TextStyle(
                color: _getStatusColor(request.status),
                fontSize: 12,
              ),
            ),
          ],
        ),
        childrenPadding: const EdgeInsets.all(16),
        children: [
          if (requestAppeals.isNotEmpty) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'MINER APPEALS',
                style: TextStyle(
                  color: Colors.deepOrange,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                  letterSpacing: 1,
                ),
              ),
            ),
            const SizedBox(height: 8),
            ...requestAppeals.map(
              (appeal) => _buildVerificationAppealCard(
                appeal,
                latestVerification,
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (latestVerification != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                children: [
                  Expanded(
                    child: ActionChip(
                      label: Text(
                        showOriginal
                            ? 'Switch to Verified Data'
                            : 'Show Original Miner Data',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      onPressed: () => setState(() {
                        if (showOriginal) {
                          _showOriginalDataIds.remove(request.id);
                        } else {
                          _showOriginalDataIds.add(request.id);
                        }
                      }),
                      backgroundColor: showOriginal
                          ? Colors.teal.withOpacity(0.1)
                          : kGold.withOpacity(0.1),
                      side: BorderSide(
                        color: showOriginal ? Colors.teal : kGold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (isKorpo) ...[
            const Text(
              'GROUP PARTICIPANTS',
              style: TextStyle(
                color: kGold,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: request.participatingMinerIds
                  .map(
                    (id) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: kGold.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: kGold.withOpacity(0.2)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.person_outline_rounded,
                            size: 14,
                            color: kGold,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _getUserName(id),
                            style: TextStyle(
                              color: context.textColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),
          ],
          _buildDetailRow(
            showOriginal ? 'Miner Sacks' : 'Actual Sacks (Verified)',
            '$displaySacks Sacks',
          ),
          _buildDetailRow('Condition', displayCondition),
          _buildDetailRow('State', displayState),
          _buildDetailRow(
            'Est. Time',
            request.processingDetails.estimatedTime ?? 'N/A',
          ),
          if (latestVerification != null)
            _buildDetailRow(
              'Verified By',
              latestVerification.operatorName ??
                  _getUserName(latestVerification.operatorId),
            ),
          if (showOriginal && request.materialDetails.photoUrls.isNotEmpty) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Miner Submitted Photos',
                style: TextStyle(
                  color: context.mutedTextColor,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 96,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: request.materialDetails.photoUrls.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final url = request.materialDetails.photoUrls[index];
                  return InkWell(
                    onTap: () => showDialog<void>(
                      context: context,
                      builder: (context) => Dialog(
                        child: InteractiveViewer(child: Image.network(url)),
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        url,
                        width: 116,
                        height: 96,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const SizedBox(
                          width: 116,
                          child: Center(child: Icon(Icons.broken_image_outlined)),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
          if (latestVerification?.notes != null && !showOriginal)
            _buildDetailRow('Operator Notes', latestVerification!.notes!),
          if (latestVerification != null &&
              latestVerification.photoUrls.isNotEmpty &&
              !showOriginal) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Operator Verification Photos',
                style: TextStyle(
                  color: context.mutedTextColor,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 96,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: latestVerification.photoUrls.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final url = latestVerification.photoUrls[index];
                  return InkWell(
                    onTap: () => showDialog<void>(
                      context: context,
                      builder: (context) => Dialog(
                        child: InteractiveViewer(child: Image.network(url)),
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        url,
                        width: 116,
                        height: 96,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const SizedBox(
                          width: 116,
                          child: Center(child: Icon(Icons.broken_image_outlined)),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],

          if (request.status == ServiceRequestStatus.verified ||
              request.status == ServiceRequestStatus.accepted) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _handleAddToQueue(request),
                    icon: const Icon(Icons.queue_rounded, size: 18),
                    label: const Text('Add to Queue'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.orange,
                      side: const BorderSide(color: Colors.orange),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _showScheduleDialog(request),
                    icon: const Icon(Icons.calendar_today_rounded, size: 18),
                    label: const Text('Set Schedule'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kGold,
                      foregroundColor: kBlack,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (request.status == ServiceRequestStatus.processing ||
              request.status == ServiceRequestStatus.processingCompleted)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => MonitoringPage(
                            request: request,
                            title: 'ADMIN MONITORING',
                            isAdmin: true,
                          ),
                        ),
                      ),
                      icon: const Icon(Icons.monitor_heart_outlined, size: 18),
                      label: const Text(
                        'MONITOR LIVE PROCESS',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.withOpacity(0.1),
                        foregroundColor: Colors.blue,
                        side: BorderSide(color: Colors.blue.withOpacity(0.3)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  if (request.status ==
                      ServiceRequestStatus.processingCompleted) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const BillingPage(),
                          ),
                        ),
                        icon: const Icon(Icons.receipt_long_outlined, size: 18),
                        label: const Text(
                          'PROCEED TO FINANCIAL HANDLING',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kGold,
                          foregroundColor: kBlack,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          const Divider(),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            childrenPadding: const EdgeInsets.only(bottom: 8),
            leading: const Icon(Icons.history_rounded, color: kGold),
            title: const Text(
              'Audit Trail',
              style: TextStyle(color: kGold, fontWeight: FontWeight.bold),
            ),
            children: [
              FutureBuilder<Either<Failure, List<Map<String, dynamic>>>>(
                future: _repository.getAuditTrails(request.id),
                builder: (context, snapshot) {
                  if (snapshot.hasData) {
                    return snapshot.data!.fold(
                      (failure) => Text(
                        'Error loading history: ${failure.message}',
                        style: const TextStyle(color: Colors.redAccent),
                      ),
                      (trails) => AuditTrailViewer(auditTrails: trails),
                    );
                  }
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(
                      child: CircularProgressIndicator(color: kGold),
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showScheduleDialog(ServiceRequestEntity request) {
    DateTime selectedDate = DateTime.now().add(const Duration(days: 1));
    final latestVerification = request.materialDetails.verifications.isNotEmpty
        ? request.materialDetails.verifications.last
        : null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.bgColor,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              left: 20,
              right: 20,
              top: 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Schedule Processing',
                    style: TextStyle(
                      color: kGold,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Summary of what is being scheduled
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: context.surfaceColor,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: kGold.withOpacity(0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'VERIFICATION SUMMARY',
                          style: TextStyle(
                            color: kGold.withOpacity(0.7),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildDetailRow(
                          'Actual Sacks',
                          '${latestVerification?.actualSacks ?? request.materialDetails.numberOfSacks ?? 0}',
                        ),
                        _buildDetailRow(
                          'Condition',
                          latestVerification?.condition ??
                              request.materialDetails.condition ??
                              'N/A',
                        ),
                        _buildDetailRow(
                          'Est. Time',
                          request.processingDetails.estimatedTime ?? 'N/A',
                        ),
                        if (latestVerification != null)
                          _buildDetailRow(
                            'Assigned Operator',
                            _getUserName(latestVerification.operatorId),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  ListTile(
                    title: Text(
                      'Date: ${DateFormat('yyyy-MM-dd').format(selectedDate)}',
                      style: TextStyle(color: context.textColor),
                    ),
                    trailing: const Icon(Icons.calendar_today, color: kGold),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 90)),
                      );
                      if (picked != null)
                        setModalState(() => selectedDate = picked);
                    },
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () async {
                      final currentUserId =
                          SupabaseConfig.client.auth.currentUser?.id;
                      if (currentUserId == null) return;

                      final result = await _service.ownerScheduleService(
                        requestId: request.id,
                        ownerId: currentUserId,
                        scheduledDate: selectedDate,
                        verifyingOperatorId: latestVerification?.operatorId,
                        verifyingOperatorName: latestVerification == null
                            ? null
                            : _getUserName(latestVerification.operatorId),
                        currentStatus: request.status
                            .toString()
                            .split('.')
                            .last,
                      );
                      Navigator.pop(context);
                      result.fold(
                        (l) => ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(SnackBar(content: Text(l.message))),
                        (_) => _loadData(),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kGold,
                      minimumSize: const Size(double.infinity, 50),
                    ),
                    child: const Text(
                      'Confirm Schedule',
                      style: TextStyle(color: kBlack),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _handleAddToQueue(ServiceRequestEntity request) async {
    final latestVerification = request.materialDetails.verifications.isNotEmpty
        ? request.materialDetails.verifications.last
        : null;

    final bool confirm =
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: context.surfaceColor,
            title: const Text('Add to Queue', style: TextStyle(color: kGold)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Are you sure you want to add this request to the general queue based on the verified data?',
                  style: TextStyle(color: context.textColor, fontSize: 14),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: context.bgColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      _buildDetailRow(
                        'Actual Sacks',
                        '${latestVerification?.actualSacks ?? request.materialDetails.numberOfSacks ?? 0}',
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(
                  'Cancel',
                  style: TextStyle(color: context.mutedTextColor),
                ),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(backgroundColor: kGold),
                child: const Text('Confirm', style: TextStyle(color: kBlack)),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirm) return;

    final currentUserId = SupabaseConfig.client.auth.currentUser?.id;
    if (currentUserId == null) return;

    final result = await _service.addToGeneralQueue(
      requestId: request.id,
      userId: currentUserId,
      currentStatus: request.status.toString().split('.').last,
    );

    result.fold(
      (l) => ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l.message))),
      (_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Added to general mill queue table successfully'),
            backgroundColor: Colors.green,
          ),
        );
        _loadData();
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    final normalizedLabel = label.toLowerCase();
    final icon = normalizedLabel.contains('sack')
        ? Icons.inventory_2_outlined
        : normalizedLabel.contains('condition')
        ? Icons.health_and_safety_outlined
        : normalizedLabel.contains('state')
        ? Icons.category_outlined
        : normalizedLabel.contains('time')
        ? Icons.schedule_outlined
        : normalizedLabel.contains('operator') ||
              normalizedLabel.contains('verified by')
        ? Icons.verified_user_outlined
        : normalizedLabel.contains('weight')
        ? Icons.straighten_rounded
        : normalizedLabel.contains('source')
        ? Icons.location_on_outlined
        : normalizedLabel.contains('note')
        ? Icons.notes_outlined
        : Icons.info_outline_rounded;
    final iconColor = normalizedLabel.contains('operator') ||
            normalizedLabel.contains('verified by')
        ? Colors.teal
        : kGold;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, color: iconColor, size: 17),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: context.mutedTextColor, fontSize: 13),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: context.textColor,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(ServiceRequestStatus status) {
    switch (status) {
      case ServiceRequestStatus.completed:
        return Colors.green;
      case ServiceRequestStatus.processing:
        return Colors.blue;
      case ServiceRequestStatus.returnedToMiner:
        return Colors.red;
      case ServiceRequestStatus.scheduled:
        return kGold;
      case ServiceRequestStatus.verified:
        return Colors.teal;
      case ServiceRequestStatus.accepted:
        return Colors.green;
      default:
        return kGold;
    }
  }
}
