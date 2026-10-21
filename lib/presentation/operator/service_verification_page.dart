import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../../core/navigation/app_scaffold_messenger.dart';
import '../shared_widgets/appColor.dart';
import '../shared_widgets/themeToggleButton.dart';
import '../shared_widgets/pin_dialog.dart';
import 'emergency_stop_dialog.dart';
import '../../infrastructure/repositories/supabase_service_request_repository.dart';
import '../../infrastructure/repositories/supabase_user_repository.dart';
import '../../application/services/service_request_service.dart';
import '../../domain/entities/service_request_entity.dart';
import '../../domain/entities/user_entity.dart';
import '../../infrastructure/supabase/supabase_config.dart';
import '../../infrastructure/models/user_model.dart';
import 'sacking_page.dart';

enum _ServiceRequestFilter { all, toVerify, queued, scheduledToday }

class ServiceVerificationPage extends StatefulWidget {
  const ServiceVerificationPage({super.key, this.onPendingCountChanged});

  final ValueChanged<int>? onPendingCountChanged;

  @override
  State<ServiceVerificationPage> createState() =>
      _ServiceVerificationPageState();
}

class _ServiceVerificationPageState extends State<ServiceVerificationPage> {
  final SupabaseServiceRequestRepository _repository =
      SupabaseServiceRequestRepository();
  late final ServiceRequestService _service;
  final SupabaseUserRepository _userRepository = SupabaseUserRepository();

  List<ServiceRequestEntity> _requests = [];
  List<UserEntity> _allUsers = [];
  final ValueNotifier<int> _requestsRevision = ValueNotifier<int>(0);
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _service = ServiceRequestService(_repository);
    _loadRequests();
  }

  @override
  void dispose() {
    _requestsRevision.dispose();
    super.dispose();
  }

  Future<void> _loadRequests({bool showLoading = true}) async {
    if (!mounted) return;
    if (showLoading) setState(() => _isLoading = true);

    try {
      final operatorId = Supabase.instance.client.auth.currentUser?.id;
      if (operatorId == null) {
        throw StateError('Session expired. Please re-login.');
      }

      final pendingResult = await _repository
          .getPendingOperatorVerificationRequests();
      final verifiedResult = await _repository
          .getServiceRequestsVerifiedByOperator(operatorId);
      final ongoingResult = await _repository
          .getOngoingServiceRequestsForOperator(operatorId);
      final assignedResult = await _repository
          .getAssignedServiceRequestsForOperator(operatorId);
      final allRequestsResult = await _repository.getServiceRequests();
      final usersResult = await _userRepository.getAllUsers();

      if (!mounted) return;

      String? errorMessage;
      List<ServiceRequestEntity> pendingRequests = [];
      List<ServiceRequestEntity> verifiedRequests = [];
      List<ServiceRequestEntity> ongoingRequests = [];
      List<ServiceRequestEntity> assignedRequests = [];
      List<ServiceRequestEntity> allRequests = [];
      pendingResult.fold(
        (l) => errorMessage = 'Pending requests: ${l.message}',
        (list) {
          pendingRequests = list;
          widget.onPendingCountChanged?.call(list.length);
        },
      );
      verifiedResult.fold(
        (l) => errorMessage =
            '${errorMessage == null ? '' : '$errorMessage. '}Verification history: ${l.message}',
        (list) => verifiedRequests = list,
      );
      ongoingResult.fold(
        (l) => errorMessage =
            '${errorMessage == null ? '' : '$errorMessage. '}Ongoing services: ${l.message}',
        (list) => ongoingRequests = list,
      );
      assignedResult.fold(
        (l) => errorMessage =
            '${errorMessage == null ? '' : '$errorMessage. '}Assigned services: ${l.message}',
        (list) => assignedRequests = list,
      );
      allRequestsResult.fold(
        (l) => errorMessage =
            '${errorMessage == null ? '' : '$errorMessage. '}Queued services: ${l.message}',
        (list) => allRequests = list,
      );
      _requests = {
        for (final request in [
          ...pendingRequests,
          ...verifiedRequests,
          ...ongoingRequests,
          ...assignedRequests,
          ...allRequests.where(
            (request) => request.status == ServiceRequestStatus.queued,
          ),
        ])
          request.id: request,
      }.values.toList();
      _requestsRevision.value++;

      usersResult.fold(
        (l) => errorMessage = (errorMessage ?? '') + ' Users: ${l.message}',
        (list) => _allUsers = list,
      );

      if (errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading data: $errorMessage'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 10),
            action: SnackBarAction(
              label: 'RETRY',
              textColor: Colors.white,
              onPressed: _loadRequests,
            ),
          ),
        );
      }

      setState(() => _isLoading = false);
    } catch (e) {
      print('Critical Error in _loadRequests: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Critical Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _openEmergencyStopDialog() async {
    final stopped = await showDialog<bool>(
      context: context,
      builder: (_) => const EmergencyStopDialog(),
    );
    if (stopped == true && mounted) {
      await _loadRequests(showLoading: false);
    }
  }

  String _getMinerName(String id) {
    UserEntity? user;
    for (final u in _allUsers) {
      if (u.userId == id) {
        user = u;
        break;
      }
    }
    return user != null ? '${user.fname} ${user.lname}' : 'Unknown Miner';
  }

  @override
  Widget build(BuildContext context) {
    final operatorId = Supabase.instance.client.auth.currentUser?.id;
    final assignedRequests = _requests
        .where(
          (request) =>
              operatorId != null &&
              request.processingDetails.assignedOperatorIds.contains(
                operatorId,
              ) &&
              {
                ServiceRequestStatus.verified,
                ServiceRequestStatus.accepted,
                ServiceRequestStatus.queued,
                ServiceRequestStatus.scheduled,
              }.contains(request.status),
        )
        .toList();
    final pendingRequests = _requests
        .where(
          (r) => r.status == ServiceRequestStatus.pendingOperatorVerification,
        )
        .toList();
    final serviceRequestItems = _getServiceRequestItems();
    final ongoingRequests = _requests
        .where(
          (r) =>
              ((r.status == ServiceRequestStatus.queued &&
                    operatorId != null &&
                    r.processingDetails.assignedOperatorIds.contains(
                      operatorId,
                    )) ||
                  r.status == ServiceRequestStatus.processing ||
                  r.status == ServiceRequestStatus.emergencyStop) &&
              operatorId != null &&
              r.processingDetails.assignedOperatorIds.contains(operatorId),
        )
        .toList();
    final verifiedRequests = _requests
        .where(
          (r) =>
              r.status != ServiceRequestStatus.pendingOperatorVerification &&
              r.status != ServiceRequestStatus.processing &&
              r.status != ServiceRequestStatus.emergencyStop &&
              r.materialDetails.verifications.any(
                (verification) =>
                    verification.operatorId ==
                    Supabase.instance.client.auth.currentUser?.id,
              ),
        )
        .toList();

    return Scaffold(
      backgroundColor: context.bgColor,
      appBar: AppBar(
        backgroundColor: context.surfaceColor,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildLogoMark(),
            const SizedBox(width: 10),
            const Text(
              'SERVICES',
              style: TextStyle(
                color: kGold,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
                fontSize: 16,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Emergency stop: choose a drum or entire machine',
            onPressed: _openEmergencyStopDialog,
            icon: const Icon(Icons.warning_amber_rounded),
            color: Colors.redAccent,
          ),
          const ThemeToggleButton(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showMinerDirectory,
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'CREATE REQUEST',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: kGold))
          : RefreshIndicator(
              onRefresh: _loadRequests,
              color: kGold,
              child: Center(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 100),
                  children: [
                    if (assignedRequests.isNotEmpty) ...[
                      _buildAssignedServicesNotice(assignedRequests),
                      const SizedBox(height: 16),
                    ],
                    _buildSectionTitle('SERVICE DESK'),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _buildServiceShortcutCard(
                            title: 'Service Requests',
                            subtitle: 'Pending and scheduled work',
                            count: serviceRequestItems.length,
                            icon: Icons.assignment_outlined,
                            color: kGold,
                            onTap: () => _showServiceListSheet(
                              title: 'Service Requests',
                              subtitle: 'Pending verification tasks',
                              icon: Icons.assignment_outlined,
                              color: kGold,
                              requests: serviceRequestItems,
                              isPending: true,
                              emptyMessage: 'No pending verification tasks.',
                              showRequestFilters: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildServiceShortcutCard(
                            title: 'Verification History',
                            subtitle: 'Verified by you',
                            count: verifiedRequests.length,
                            icon: Icons.fact_check_rounded,
                            color: Colors.teal,
                            onTap: () => _showServiceListSheet(
                              title: 'Verification History',
                              subtitle: 'Your completed verification checks',
                              icon: Icons.fact_check_rounded,
                              color: Colors.teal,
                              requests: verifiedRequests,
                              isPending: false,
                              emptyMessage: 'No services verified by you yet.',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(child: _buildSectionTitle('ONGOING SERVICES')),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.lightBlue.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${ongoingRequests.length} active',
                            style: const TextStyle(
                              color: Colors.lightBlue,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (ongoingRequests.isEmpty)
                      _buildEmptyState('You have no ongoing services.')
                    else
                      ...ongoingRequests.map(
                        (r) => _buildRequestCard(r, isPending: false),
                      ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildServiceShortcutCard({
    required String title,
    required String subtitle,
    required int count,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(top: 4),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: color.withValues(alpha: 0.24)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.13),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Text(
                    '$count',
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: context.textColor,
                fontSize: 14,
                height: 1.15,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: context.mutedTextColor, fontSize: 10.5),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: onTap,
                style: OutlinedButton.styleFrom(
                  foregroundColor: color,
                  side: BorderSide(color: color.withValues(alpha: 0.45)),
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  visualDensity: VisualDensity.compact,
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Open'),
                    SizedBox(width: 5),
                    Icon(Icons.arrow_forward_rounded, size: 15),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogoMark() {    return Image.asset(
      'assets/img/EGReS.png',
      width: 34,
      height: 34,
      fit: BoxFit.contain,
    );
  }

  Future<void> _showServiceListSheet({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required List<ServiceRequestEntity> requests,
    required bool isPending,
    required String emptyMessage,
    bool showRequestFilters = false,
  }) {
    var selectedFilter = _ServiceRequestFilter.all;
    var isRefreshingRequests = false;
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.78,
        minChildSize: 0.48,
        maxChildSize: 0.94,
        builder: (context, scrollController) => StatefulBuilder(
          builder: (context, setSheetState) {
            Future<void> selectFilterAndRefresh(
              _ServiceRequestFilter filter,
            ) async {
              if (isRefreshingRequests) return;
              setSheetState(() {
                selectedFilter = filter;
                isRefreshingRequests = true;
              });
              await _loadRequests(showLoading: false);
              if (!context.mounted) return;
              setSheetState(() => isRefreshingRequests = false);
            }
            return Container(
          decoration: BoxDecoration(
            color: context.surfaceColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
            border: Border.all(color: color.withValues(alpha: 0.22)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: context.mutedTextColor.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 12, 12),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.13),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(icon, color: color),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              color: context.textColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 17,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '$subtitle | ${requests.length} total',
                            style: TextStyle(
                              color: context.mutedTextColor,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(sheetContext),
                      icon: Icon(Icons.close_rounded, color: context.mutedTextColor),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: color.withValues(alpha: 0.15)),
              if (showRequestFilters)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _serviceRequestFilterChip(
                          label: 'All',
                          filter: _ServiceRequestFilter.all,
                          selectedFilter: selectedFilter,
                          onSelected: selectFilterAndRefresh,
                        ),
                        const SizedBox(width: 8),
                        _serviceRequestFilterChip(
                          label: 'To Verify',
                          filter: _ServiceRequestFilter.toVerify,
                          selectedFilter: selectedFilter,
                          onSelected: selectFilterAndRefresh,
                        ),
                        const SizedBox(width: 8),
                        _serviceRequestFilterChip(
                          label: 'Queued',
                          filter: _ServiceRequestFilter.queued,
                          selectedFilter: selectedFilter,
                          onSelected: selectFilterAndRefresh,
                        ),
                        const SizedBox(width: 8),
                        _serviceRequestFilterChip(
                          label: 'Scheduled Today',
                          filter: _ServiceRequestFilter.scheduledToday,
                          selectedFilter: selectedFilter,
                          onSelected: selectFilterAndRefresh,
                        ),
                      ],
                    ),
                  ),
                ),
              if (showRequestFilters && isRefreshingRequests)
                const LinearProgressIndicator(minHeight: 2, color: kGold),
              Expanded(
                child: ValueListenableBuilder<int>(
                  valueListenable: _requestsRevision,
                  builder: (context, _, _) {
                    final currentRequests = showRequestFilters
                        ? _getServiceRequestItems()
                        : requests;
                    final filteredRequests = _filterServiceRequests(
                      currentRequests,
                      selectedFilter,
                    );
                    return filteredRequests.isEmpty
                    ? ListView(
                        controller: scrollController,
                        padding: const EdgeInsets.all(18),
                        children: [
                          _buildEmptyState(
                                filteredRequests.isEmpty && currentRequests.isNotEmpty
                                ? _serviceRequestFilterEmptyMessage(
                                    selectedFilter,
                                  )
                                : emptyMessage,
                          ),
                        ],
                      )
                    : ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                        itemCount: filteredRequests.length,
                        itemBuilder: (context, index) => _buildRequestCard(
                          filteredRequests[index],
                          isPending: isPending &&
                              filteredRequests[index].status ==
                                  ServiceRequestStatus
                                      .pendingOperatorVerification,
                          queueNumber:
                              selectedFilter == _ServiceRequestFilter.queued
                              ? index + 1
                              : null,
                        ),
                      );
                  },
                ),
              ),
            ],
          ),
            );
          },
        ),
      ),
    );
  }

  List<ServiceRequestEntity> _filterServiceRequests(
    List<ServiceRequestEntity> requests,
    _ServiceRequestFilter filter,
  ) {
    switch (filter) {
      case _ServiceRequestFilter.toVerify:
        return requests
            .where((request) =>
                request.status ==
                ServiceRequestStatus.pendingOperatorVerification)
            .toList();
      case _ServiceRequestFilter.queued:
        final queued = requests
            .where((request) =>
                request.status == ServiceRequestStatus.queued &&
                request.processingDetails.assignedOperatorIds.isEmpty)
            .toList();
        queued.sort(
          (a, b) => (a.queueAddedAt ?? a.createdAt).compareTo(
            b.queueAddedAt ?? b.createdAt,
          ),
        );
        return queued;
      case _ServiceRequestFilter.scheduledToday:
        final now = DateTime.now();
        return requests.where((request) {
          final scheduledDate = request.processingDetails.scheduledDate;
          return request.status == ServiceRequestStatus.scheduled &&
              scheduledDate != null &&
              scheduledDate.year == now.year &&
              scheduledDate.month == now.month &&
              scheduledDate.day == now.day;
        }).toList();
      case _ServiceRequestFilter.all:
        return requests;
    }
  }

  List<ServiceRequestEntity> _getServiceRequestItems() {
    final operatorId = Supabase.instance.client.auth.currentUser?.id;
    final items = _requests
        .where(
          (request) =>
              request.status ==
                  ServiceRequestStatus.pendingOperatorVerification ||
              request.status == ServiceRequestStatus.queued ||
              request.status == ServiceRequestStatus.scheduled,
        )
        .toList();
    if (operatorId == null) return items;

    for (final request in _requests) {
      final isAssignedToOperator = request.processingDetails.assignedOperatorIds
          .contains(operatorId);
      final isAssignableStatus = {
        ServiceRequestStatus.verified,
        ServiceRequestStatus.accepted,
        ServiceRequestStatus.queued,
        ServiceRequestStatus.scheduled,
      }.contains(request.status);
      if (isAssignedToOperator &&
          isAssignableStatus &&
          !items.any((item) => item.id == request.id)) {
        items.add(request);
      }
    }
    return items;
  }

  String _serviceRequestFilterEmptyMessage(_ServiceRequestFilter filter) {
    switch (filter) {
      case _ServiceRequestFilter.toVerify:
        return 'No service requests to verify.';
      case _ServiceRequestFilter.queued:
        return 'No queued service requests.';
      case _ServiceRequestFilter.scheduledToday:
        return 'No services scheduled for today.';
      case _ServiceRequestFilter.all:
        return 'No service requests.';
    }
  }

  Widget _serviceRequestFilterChip({
    required String label,
    required _ServiceRequestFilter filter,
    required _ServiceRequestFilter selectedFilter,
    required ValueChanged<_ServiceRequestFilter> onSelected,
  }) {
    final isSelected = selectedFilter == filter;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onSelected(filter),
      selectedColor: kGold,
      backgroundColor: context.bgColor,
      labelStyle: TextStyle(
        color: isSelected ? kBlack : context.textColor,
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      side: BorderSide(
        color: isSelected ? kGold : context.mutedTextColor.withValues(alpha: 0.25),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      showCheckmark: false,
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Text(
        title,
        style: TextStyle(
          color: context.mutedTextColor,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildEmptyState(String msg) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: Text(
          msg,
          style: TextStyle(color: context.mutedTextColor, fontSize: 13),
        ),
      ),
    );
  }

  Widget _buildAssignedServicesNotice(
    List<ServiceRequestEntity> assignedRequests,
  ) {
    return Material(
      color: Colors.teal.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showServiceListSheet(
          title: 'Assigned to you',
          subtitle: 'Services assigned by admin',
          icon: Icons.assignment_ind_outlined,
          color: Colors.teal,
          requests: assignedRequests,
          isPending: false,
          emptyMessage: 'No services have been assigned to you.',
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.assignment_ind_outlined, color: Colors.teal),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'ASSIGNED TO YOU',
                      style: TextStyle(
                        color: Colors.teal,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Admin assigned ${assignedRequests.length} service${assignedRequests.length == 1 ? '' : 's'} to you. Tap to review.',
                      style: TextStyle(
                        color: context.textColor,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Colors.teal),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRequestCard(
    ServiceRequestEntity request, {
    required bool isPending,
    int? queueNumber,
  }) {
    final bool isGroup = request.participatingMinerIds.length > 1;
    final String timeStr = DateFormat('hh:mm a').format(request.createdAt);
    final operatorId = Supabase.instance.client.auth.currentUser?.id;
    final isAssignedToCurrentOperator = operatorId != null &&
        request.processingDetails.assignedOperatorIds.contains(operatorId);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isPending
              ? kGold.withOpacity(0.2)
              : context.textColor.withOpacity(0.05),
        ),
      ),
      child: InkWell(
        onTap: () => _showRequestDetails(request),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isGroup
                          ? Colors.blue.withOpacity(0.1)
                          : kGold.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      isGroup ? 'GROUP' : 'INDIVIDUAL',
                      style: TextStyle(
                        color: isGroup ? Colors.blue : kGold,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  Text(
                    timeStr,
                    style: TextStyle(
                      color: context.mutedTextColor,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
              if (queueNumber != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.orange.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    'QUEUE #$queueNumber',
                    style: const TextStyle(
                      color: Colors.orange,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Text(
                request.creatorName ?? 'Unknown Miner',
                style: TextStyle(
                  color: context.textColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    Icons.inventory_2_outlined,
                    size: 14,
                    color: kGold.withOpacity(0.7),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${request.materialDetails.numberOfSacks ?? 0} Sacks • ${request.materialDetails.weight != null ? '${request.materialDetails.weight} kg • ' : ''}${request.materialDetails.condition} • ${request.materialDetails.state}',
                    style: TextStyle(
                      color: context.mutedTextColor,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              if (isAssignedToCurrentOperator) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.teal.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.teal.withValues(alpha: 0.3)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.assignment_ind_outlined,
                          color: Colors.teal, size: 14),
                      SizedBox(width: 6),
                      Text(
                        'ASSIGNED TO YOU',
                        style: TextStyle(
                          color: Colors.teal,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (!isPending) ...[
                const SizedBox(height: 12),
                _buildStatusBadge(request.status),
              ],
              if (queueNumber != null) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _claimQueuedService(request),
                    icon: const Icon(Icons.front_hand_rounded, size: 18),
                    label: const Text('CLAIM SERVICE'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kGold,
                      foregroundColor: kBlack,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(ServiceRequestStatus status) {
    Color color = kGold;
    String label = status.toString().split('.').last.toUpperCase();

    if (status == ServiceRequestStatus.verified ||
        status == ServiceRequestStatus.accepted) {
      color = Colors.green;
      label = 'IN QUEUE';
    }
    if (status == ServiceRequestStatus.returnedToMiner) {
      color = Colors.redAccent;
      label = 'INACCURATE';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  void _showRequestDetails(ServiceRequestEntity request) {
    final operatorId = Supabase.instance.client.auth.currentUser?.id;
    final isAssignedToMe = operatorId != null &&
        request.processingDetails.assignedOperatorIds.contains(operatorId);
    var canScrollFurther = true;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.bgColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          return DraggableScrollableSheet(
            initialChildSize: 0.8,
            maxChildSize: 0.95,
            expand: false,
            builder: (context, scrollController) => Stack(
              children: [
                NotificationListener<ScrollNotification>(
                  onNotification: (notification) {
                    final canScroll = notification.metrics.extentAfter > 8;
                    if (canScrollFurther != canScroll) {
                      setSheetState(() => canScrollFurther = canScroll);
                    }
                    return false;
                  },
                  child: SingleChildScrollView(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
                    child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(
                    color: context.mutedTextColor.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Full Information',
                    style: TextStyle(
                      color: kGold,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _buildDetailSection('MINER DETAILS', [
                _buildDetailRow(
                  'Primary Miner',
                  request.creatorName ?? 'Unknown Miner',
                ),
                if (request.participatingMinerIds.length > 1)
                  _buildGroupMembersList(
                    request.participatingMinerIds
                        .where((id) => id != request.creatorId)
                        .toList(),
                  ),
              ]),
              const SizedBox(height: 24),
              _buildDetailSection('MATERIAL SUMMARY', [
                _buildDetailRow(
                  'Condition',
                  request.materialDetails.condition ?? 'N/A',
                ),
                _buildDetailRow(
                  'State',
                  request.materialDetails.state ?? 'N/A',
                ),
                _buildDetailRow(
                  'Sacks',
                  '${request.materialDetails.numberOfSacks ?? 0}',
                ),
                if (request.materialDetails.weight != null)
                  _buildDetailRow(
                    'Est. Weight',
                    '${request.materialDetails.weight} kg',
                  ),
                if (request.materialDetails.actualWeight != null)
                  _buildDetailRow(
                    'Actual Weight',
                    '${request.materialDetails.actualWeight} kg',
                  ),
                _buildDetailRow(
                  'Source Type',
                  request.materialDetails.sourceType ?? 'N/A',
                ),
                _buildDetailRow(
                  'Source Name',
                  request.materialDetails.source ?? 'N/A',
                ),
              ]),
              if (request.materialDetails.photoUrls.isNotEmpty) ...[
                const SizedBox(height: 24),
                const Text(
                  'MATERIAL PHOTOS',
                  style: TextStyle(
                    color: kGold,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 100,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: request.materialDetails.photoUrls.length,
                    itemBuilder: (context, index) {
                      final photoUrl = request.materialDetails.photoUrls[index];
                      return GestureDetector(
                        onTap: () => _showFullScreenPhoto(photoUrl),
                        child: Container(
                          width: 100,
                          margin: const EdgeInsets.only(right: 12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: kGold.withOpacity(0.2)),
                            image: DecorationImage(
                              image: NetworkImage(photoUrl),
                              fit: BoxFit.cover,
                            ),
                          ),
                          child: const Align(
                            alignment: Alignment.bottomRight,
                            child: Padding(
                              padding: EdgeInsets.all(5),
                              child: Icon(
                                Icons.open_in_full_rounded,
                                color: Colors.white,
                                size: 15,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
              if (request.materialDetails.notes != null &&
                  request.materialDetails.notes!.isNotEmpty) ...[
                const SizedBox(height: 24),
                _buildDetailSection('MINER NOTES', [
                  Text(
                    request.materialDetails.notes!,
                    style: TextStyle(
                      color: context.textColor,
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                ]),
              ],
              if (request.status == ServiceRequestStatus.queued ||
                  request.status == ServiceRequestStatus.verified ||
                  request.status == ServiceRequestStatus.accepted ||
                  request.status == ServiceRequestStatus.scheduled ||
                  request.status == ServiceRequestStatus.assigned ||
                  request.status == ServiceRequestStatus.processing ||
                  request.status == ServiceRequestStatus.emergencyStop) ...[
                const SizedBox(height: 40),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.withOpacity(0.3)),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.check_circle_rounded,
                        color: Colors.green,
                        size: 24,
                      ),
                      SizedBox(width: 12),
                      Text(
                        'VERIFIED',
                        style: TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: context.surfaceColor,
                      foregroundColor: kGold,
                      side: const BorderSide(color: kGold),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: isAssignedToMe
                        ? () async {
                            Navigator.pop(context);
                            await _openAssignedService(request);
                          }
                        : null,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          request.status == ServiceRequestStatus.processing ||
                                  request.status ==
                                      ServiceRequestStatus.emergencyStop
                              ? 'CONTINUE SERVICE'
                              : 'START SERVICE',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.play_arrow_rounded, size: 20),
                      ],
                    ),
                  ),
                ),
              ],
              if (request.status ==
                  ServiceRequestStatus.pendingOperatorVerification) ...[
                const SizedBox(height: 40),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kGold,
                      foregroundColor: kBlack,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      _showVerificationForm(request);
                    },
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'NEXT: VERIFY MATERIAL',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        SizedBox(width: 8),
                        Icon(Icons.arrow_forward_rounded, size: 20),
                      ],
                    ),
                  ),
                ),
              ],
            ],
                    ),
                  ),
                ),
                if (canScrollFurther)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: IgnorePointer(
                      child: Container(
                        height: 42,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              context.bgColor.withOpacity(0),
                              context.bgColor.withOpacity(0.98),
                            ],
                          ),
                        ),
                        child: Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 28,
                          color: kGold.withOpacity(0.95),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _openAssignedService(ServiceRequestEntity request) async {
    final operatorId = Supabase.instance.client.auth.currentUser?.id;
    if (operatorId == null) return;

    if (request.status != ServiceRequestStatus.processing &&
        request.status != ServiceRequestStatus.emergencyStop) {
      final result = await _service.claimAndStartService(
        requestId: request.id,
        operatorId: operatorId,
        currentStatus: request.status.toString().split('.').last,
      );
      final failure = result.fold<String?>((error) => error.message, (_) => null);
      if (failure != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not start service: $failure')),
          );
        }
        return;
      }
    }

    if (!mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => SackingPage(request: request)),
    );
    if (mounted) await _loadRequests();
  }

  Future<void> _claimQueuedService(ServiceRequestEntity request) async {
    final operatorId = Supabase.instance.client.auth.currentUser?.id;
    if (operatorId == null) return;

    final result = await _service.claimQueuedService(
      requestId: request.id,
      operatorId: operatorId,
    );
    if (!mounted) return;

    result.fold(
      (failure) {
        final messenger =
            appScaffoldMessengerKey.currentState ??
            ScaffoldMessenger.of(context);
        if (failure.message.toLowerCase().contains(
          'already assigned to another active service',
        )) {
          messenger.hideCurrentMaterialBanner();
          messenger.showMaterialBanner(
            MaterialBanner(
              leading: const Icon(Icons.info_outline, color: Colors.redAccent),
              content: const Text(
                'You have an ongoing services! Please complete it first. Thank You!',
              ),
              backgroundColor: context.surfaceColor,
              actions: [
                TextButton(
                  onPressed: messenger.hideCurrentMaterialBanner,
                  child: const Text('DISMISS'),
                ),
              ],
            ),
          );
        } else {
          messenger.showSnackBar(
            SnackBar(content: Text('Could not claim service: ${failure.message}')),
          );
        }
      },
      (_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Service claimed. Open Assigned to You to start it.'),
          ),
        );
        _loadRequests(showLoading: false);
      },
    );
  }

  void _showFullScreenPhoto(String photoUrl) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog.fullscreen(
        child: Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            title: const Text('Material Photo'),
            actions: [
              IconButton(
                tooltip: 'Close photo',
                onPressed: () => Navigator.pop(dialogContext),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          body: Center(
            child: InteractiveViewer(
              minScale: 0.8,
              maxScale: 5,
              child: Image.network(
                photoUrl,
                fit: BoxFit.contain,
                loadingBuilder: (context, child, progress) =>
                    progress == null
                    ? child
                    : const CircularProgressIndicator(color: kGold),
                errorBuilder: (context, error, stackTrace) => const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Unable to load this photo.',
                    style: TextStyle(color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showVerificationForm(ServiceRequestEntity request) {
    final originalSacks = request.materialDetails.numberOfSacks ?? 0;
    final originalCondition =
        (request.materialDetails.condition ?? 'Rocky').trim().toLowerCase();
    final originalState =
        (request.materialDetails.state ?? 'Dry').trim().toLowerCase();
    final sackController = TextEditingController(
      text: originalSacks.toString(),
    );
    final originalWeight = request.materialDetails.weight ?? request.materialDetails.actualWeight;
    final weightController = TextEditingController(
      text: originalWeight != null ? originalWeight.toString() : '',
    );
    final estNumController = TextEditingController(text: '3');
    final remarksController = TextEditingController();

    // Pre-fill editable fields
    String currentCondition = request.materialDetails.condition ?? 'Rocky';
    String currentState = request.materialDetails.state ?? 'Dry';
    String otherState = ''; // For "Others" option

    if (currentState != 'Dry' && currentState != 'Wet') {
      otherState = currentState;
      currentState = 'Others';
    }

    String currentSource = request.materialDetails.source ?? '';

    bool isAccurate() {
      final actualSacks = int.tryParse(sackController.text.trim());
      final actualState = currentState == 'Others'
          ? otherState.trim()
          : currentState.trim();
      return actualSacks == originalSacks &&
          currentCondition.trim().toLowerCase() == originalCondition &&
          actualState.toLowerCase() == originalState;
    }
    String timeUnit = 'Hours';

    final List<String> conditionOptions = [
      'Rocky',
      'Muddy',
      'Sandy',
      'Mixed',
      'Clay',
    ];
    final List<String> stateOptions = ['Dry', 'Wet', 'Others'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.bgColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            left: 24,
            right: 24,
            top: 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Material Verification',
                  style: TextStyle(
                    color: kGold,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: kGold.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: kGold.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline_rounded, color: kGold, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Miner Declared Material',
                              style: TextStyle(
                                color: kGold,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Declared: ${request.materialDetails.numberOfSacks ?? 0} Sacks'
                              '${request.materialDetails.weight != null ? ' • ${request.materialDetails.weight} kg (Est.)' : ''}'
                              ' • ${request.materialDetails.condition ?? "Rocky"} • ${request.materialDetails.state ?? "Dry"}',
                              style: TextStyle(
                                color: context.textColor,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: sackController,
                        keyboardType: TextInputType.number,
                        onChanged: (_) => setModalState(() {}),
                        style: TextStyle(color: context.textColor),
                        decoration: InputDecoration(
                          labelText: 'Actual Sacks',
                          filled: true,
                          fillColor: context.surfaceColor,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: weightController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        onChanged: (_) => setModalState(() {}),
                        style: TextStyle(color: context.textColor),
                        decoration: InputDecoration(
                          labelText: 'Actual Weight (kg)',
                          hintText: request.materialDetails.weight != null
                              ? 'Est: ${request.materialDetails.weight} kg'
                              : 'Optional',
                          filled: true,
                          fillColor: context.surfaceColor,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                const Text(
                  'Correct Material Condition',
                  style: TextStyle(
                    color: kGold,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: conditionOptions
                        .map(
                          (c) => Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Radio<String>(
                                value: c,
                                groupValue: currentCondition,
                                activeColor: kGold,
                                onChanged: (v) =>
                                    setModalState(() => currentCondition = v!),
                              ),
                              Text(
                                c,
                                style: TextStyle(
                                  color: context.textColor,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        )
                        .toList(),
                  ),
                ),

                const SizedBox(height: 12),
                const Text(
                  'Correct Material State',
                  style: TextStyle(
                    color: kGold,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Row(
                  children: stateOptions
                      .map(
                        (s) => Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Radio<String>(
                              value: s,
                              groupValue: currentState,
                              activeColor: kGold,
                              onChanged: (v) =>
                                  setModalState(() => currentState = v!),
                            ),
                            Text(
                              s,
                              style: TextStyle(
                                color: context.textColor,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      )
                      .toList(),
                ),
                if (currentState == 'Others')
                  Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 16),
                    child: TextFormField(
                      initialValue: otherState,
                      onChanged: (v) {
                        otherState = v;
                        setModalState(() {});
                      },
                      style: TextStyle(color: context.textColor, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Specify material state',
                        filled: true,
                        fillColor: context.surfaceColor,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),

                const SizedBox(height: 20),
                TextFormField(
                  initialValue: currentSource,
                  readOnly: true, // Not changeable
                  enabled: false,
                  style: TextStyle(color: context.textColor.withOpacity(0.6)),
                  decoration: InputDecoration(
                    labelText: 'Source Name (Verified)',
                    filled: true,
                    fillColor: context.surfaceColor.withOpacity(0.5),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),

                const SizedBox(height: 24),
                const Text(
                  'Processing Estimate',
                  style: TextStyle(
                    color: kGold,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    SizedBox(
                      width: 80,
                      child: TextFormField(
                        controller: estNumController,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: context.textColor,
                          fontWeight: FontWeight.bold,
                        ),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: context.surfaceColor,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: context.surfaceColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: context.mutedTextColor.withOpacity(0.3),
                          ),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: timeUnit,
                            dropdownColor: context.surfaceColor,
                            isExpanded: true,
                            style: TextStyle(
                              color: context.textColor,
                              fontWeight: FontWeight.bold,
                            ),
                            items: ['Minutes', 'Hours', 'Days']
                                .map(
                                  (t) => DropdownMenuItem(
                                    value: t,
                                    child: Text(t),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) =>
                                setModalState(() => timeUnit = v!),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: (isAccurate() ? Colors.green : Colors.redAccent)
                        .withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: (isAccurate() ? Colors.green : Colors.redAccent)
                          .withValues(alpha: 0.35),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isAccurate()
                            ? Icons.check_circle_rounded
                            : Icons.error_rounded,
                        color: isAccurate() ? Colors.green : Colors.redAccent,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        isAccurate() ? 'Accurate' : 'Inaccurate',
                        style: TextStyle(
                          color: isAccurate() ? Colors.green : Colors.redAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const Spacer(),
                      Icon(
                        Icons.lock_outline_rounded,
                        size: 16,
                        color: context.mutedTextColor,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'Automatic',
                        style: TextStyle(
                          color: context.mutedTextColor,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),

                TextFormField(
                  controller: remarksController,
                  style: TextStyle(color: context.textColor),
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: isAccurate()
                        ? 'General Remarks'
                        : 'Notes for Miner',
                    hintText: isAccurate()
                        ? 'Optional'
                        : 'Explain discrepancies',
                    filled: true,
                    fillColor: context.surfaceColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),

                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kGold,
                      foregroundColor: kBlack,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () => _confirmWithPin(request, {
                      'sacks': int.tryParse(sackController.text) ?? 0,
                      'actualWeight': double.tryParse(weightController.text),
                      'condition': currentCondition,
                      'state': currentState == 'Others'
                          ? otherState
                          : currentState,
                      'source': currentSource,
                      'isAccurate': isAccurate(),
                      'time': '${estNumController.text} $timeUnit',
                      'remarks': remarksController.text,
                    }),
                    child: const Text(
                      'SUBMIT VERIFICATION',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _confirmWithPin(
    ServiceRequestEntity request,
    Map<String, dynamic> data,
  ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => PinDialog(
        title: 'Operator Security PIN',
        onConfirm: (pin) async {
          final operatorId = Supabase.instance.client.auth.currentUser?.id;
          if (operatorId == null) return 'Session expired. Please re-login.';

          final result = await _service.verifyMaterial(
            requestId: request.id,
            operatorId: operatorId,
            actualSacks: data['sacks'],
            actualWeight: data['actualWeight'],
            condition: data['condition'],
            state: data['state'],
            source: data['source'],
            estimatedTime: data['time'],
            isAccurate: data['isAccurate'],
            pin: pin,
            remarks: data['remarks'],
            currentStatus: request.status.name,
          );

          return result.fold(
            (l) => l.message,
            (_) => null, // Success: return null to let PinDialog pop itself
          );
        },
      ),
    ).then((success) {
      if (success == true) {
        // If the PIN dialog finished successfully, close the Verification form sheet
        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        }

        _loadRequests(showLoading: false);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Verification submitted!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });
  }

  void _showMinerDirectory() {
    String searchQuery = '';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.bgColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: const EdgeInsets.all(24),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.8,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Miner Directory',
                style: TextStyle(
                  color: kGold,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                decoration: InputDecoration(
                  hintText: 'Search miners...',
                  prefixIcon: const Icon(Icons.search, color: kGold),
                  filled: true,
                  fillColor: context.surfaceColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onChanged: (v) => setModalState(() => searchQuery = v),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView(
                  children: _allUsers
                      .where(
                        (u) =>
                            u.roleId.toLowerCase().contains('miner') &&
                            ('${u.fname} ${u.lname}'.toLowerCase().contains(
                              searchQuery.toLowerCase(),
                            )),
                      )
                      .map(
                        (miner) => Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: context.surfaceColor,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: kGold.withOpacity(0.1)),
                          ),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: kGold.withOpacity(0.1),
                              child: Text(
                                miner.fname[0].toUpperCase(),
                                style: const TextStyle(
                                  color: kGold,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            title: Text(
                              '${miner.fname} ${miner.lname}',
                              style: TextStyle(
                                color: context.textColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            subtitle: Text(
                              miner.miningUnitName ?? 'Independent Miner',
                              style: const TextStyle(fontSize: 11),
                            ),
                            trailing: ElevatedButton(
                              onPressed: () {
                                Navigator.pop(context);
                                _showCreateAssistedRequest(
                                  initialMinerId: miner.userId,
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: kGold.withOpacity(0.1),
                                foregroundColor: kGold,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  side: const BorderSide(color: kGold),
                                ),
                              ),
                              child: const Text(
                                'CREATE',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCreateAssistedRequest({String? initialMinerId}) {
    int currentStep = 1;
    final formKey = GlobalKey<FormState>();

    List<String> selectedMinerIds = initialMinerId != null
        ? [initialMinerId]
        : [];
    String minerSearchQuery = '';

    String condition = 'Rocky';
    String state = 'Dry';
    String otherState = '';
    int? sacks;
    double weight = 0;
    String source = '';
    String estProcessingTime = '';
    String notes = '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.bgColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            left: 20,
            right: 20,
            top: 12,
          ),
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: kGold.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        currentStep == 1
                            ? 'Step 1: Miner Selection'
                            : 'Step 2: Material Info',
                        style: const TextStyle(
                          color: kGold,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '$currentStep / 2',
                        style: TextStyle(
                          color: context.mutedTextColor,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  if (currentStep == 1) ...[
                    const Text(
                      'Select additional miners for group requests.',
                      style: TextStyle(fontSize: 13),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      decoration: InputDecoration(
                        hintText: 'Search miners...',
                        prefixIcon: const Icon(Icons.search, color: kGold),
                        filled: true,
                        fillColor: context.surfaceColor,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: kGold.withOpacity(0.2)),
                        ),
                      ),
                      style: TextStyle(color: context.textColor),
                      onChanged: (v) =>
                          setModalState(() => minerSearchQuery = v),
                    ),
                    const SizedBox(height: 12),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 250),
                      child: ListView(
                        shrinkWrap: true,
                        children: _allUsers
                            .where(
                              (m) =>
                                  m.roleId.toLowerCase().contains('miner') &&
                                  ('${m.fname} ${m.lname}'
                                      .toLowerCase()
                                      .contains(
                                        minerSearchQuery.toLowerCase(),
                                      )),
                            )
                            .map(
                              (m) => CheckboxListTile(
                                title: Text(
                                  '${m.fname} ${m.lname}',
                                  style: TextStyle(
                                    color: context.textColor,
                                    fontSize: 14,
                                  ),
                                ),
                                subtitle: Text(
                                  m.email,
                                  style: TextStyle(
                                    color: context.mutedTextColor,
                                    fontSize: 11,
                                  ),
                                ),
                                value: selectedMinerIds.contains(m.userId),
                                onChanged: (v) => setModalState(
                                  () => v!
                                      ? selectedMinerIds.add(m.userId)
                                      : selectedMinerIds.remove(m.userId),
                                ),
                                activeColor: kGold,
                                contentPadding: EdgeInsets.zero,
                                controlAffinity:
                                    ListTileControlAffinity.leading,
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  ] else ...[
                    _buildFormLabel('Material Condition'),
                    Wrap(
                      spacing: 8,
                      children: ['Rocky', 'Muddy', 'Sandy', 'Mixed', 'Clay']
                          .map(
                            (c) => Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Radio<String>(
                                  value: c,
                                  groupValue: condition,
                                  activeColor: kGold,
                                  onChanged: (v) =>
                                      setModalState(() => condition = v!),
                                ),
                                Text(
                                  c,
                                  style: TextStyle(
                                    color: context.textColor,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          )
                          .toList(),
                    ),

                    _buildFormLabel('Material State'),
                    Wrap(
                      spacing: 8,
                      children: ['Dry', 'Wet', 'Others']
                          .map(
                            (s) => Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Radio<String>(
                                  value: s,
                                  groupValue: state,
                                  activeColor: kGold,
                                  onChanged: (v) =>
                                      setModalState(() => state = v!),
                                ),
                                Text(
                                  s,
                                  style: TextStyle(
                                    color: context.textColor,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          )
                          .toList(),
                    ),
                    if (state == 'Others')
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: TextFormField(
                          onChanged: (v) => otherState = v,
                          style: TextStyle(
                            color: context.textColor,
                            fontSize: 13,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Specify state',
                            filled: true,
                            fillColor: context.surfaceColor,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          child: _buildAssistedInput(
                            'Actual Sacks',
                            '0',
                            (v) => sacks = int.tryParse(v),
                            isNumber: true,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildAssistedInput(
                            'Actual Weight (kg)',
                            '0.0',
                            (v) => weight = double.tryParse(v) ?? 0,
                            isNumber: true,
                            isDecimal: true,
                          ),
                        ),
                      ],
                    ),

                    _buildAssistedInput(
                      'Est. Total Processing Time',
                      'e.g. 3 hours',
                      (v) => estProcessingTime = v,
                    ),
                    _buildAssistedInput(
                      'Source / Tunnel Name',
                      'Enter origin',
                      (v) => source = v,
                    ),
                    _buildAssistedInput(
                      'Additional Notes',
                      'Optional requirements',
                      (v) => notes = v,
                      maxLines: 2,
                    ),
                  ],

                  const SizedBox(height: 32),
                  Row(
                    children: [
                      if (currentStep == 2) ...[
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () =>
                                setModalState(() => currentStep = 1),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: kGold),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              minimumSize: const Size(0, 54),
                            ),
                            child: const Text(
                              'Back',
                              style: TextStyle(color: kGold),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            if (currentStep == 1) {
                              if (selectedMinerIds.isEmpty) return;
                              setModalState(() => currentStep = 2);
                            } else {
                              if (formKey.currentState!.validate()) {
                                Navigator.pop(context);
                                _confirmAssistedRequestSubmission(
                                  selectedMiners: _allUsers
                                      .where(
                                        (u) =>
                                            selectedMinerIds.contains(u.userId),
                                      )
                                      .toList(),
                                  condition: condition,
                                  state: state == 'Others' ? otherState : state,
                                  sacks: sacks ?? 0,
                                  weight: weight,
                                  source: source,
                                  estTime: estProcessingTime,
                                  notes: notes,
                                );
                              }
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kGold,
                            foregroundColor: kBlack,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            minimumSize: const Size(0, 54),
                          ),
                          child: Text(
                            currentStep == 1
                                ? 'Next Step'
                                : 'Review & Authorize',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _confirmAssistedRequestSubmission({
    required List<UserEntity> selectedMiners,
    required String condition,
    required String state,
    required int sacks,
    double? weight,
    required String source,
    required String estTime,
    required String notes,
  }) {
    String authorizerId = selectedMiners.first.userId;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: context.surfaceColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Confirm Assisted Submission',
            style: TextStyle(color: kGold, fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'One miner must authorize this record with their PIN.',
                  style: TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 16),
                _buildReviewRow('Source', source),
                _buildReviewRow('Sacks', sacks.toString()),
                if (weight != null && weight > 0)
                  _buildReviewRow('Weight', '$weight kg'),
                _buildReviewRow('Condition', condition),
                const SizedBox(height: 16),
                const Text(
                  'Who is authorizing?',
                  style: TextStyle(
                    color: kGold,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                ...selectedMiners
                    .map(
                      (m) => RadioListTile<String>(
                        title: Text(
                          '${m.fname} ${m.lname}',
                          style: TextStyle(
                            color: context.textColor,
                            fontSize: 13,
                          ),
                        ),
                        value: m.userId,
                        groupValue: authorizerId,
                        activeColor: kGold,
                        contentPadding: EdgeInsets.zero,
                        onChanged: (v) =>
                            setDialogState(() => authorizerId = v!),
                      ),
                    )
                    .toList(),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _authorizeAssistedPIN(
                  minerId: authorizerId,
                  allMinerIds: selectedMiners.map((m) => m.userId).toList(),
                  condition: condition,
                  state: state,
                  sacks: sacks,
                  weight: weight,
                  source: source,
                  estTime: estTime,
                  notes: notes,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: kGold,
                foregroundColor: kBlack,
              ),
              child: const Text('Verify PIN'),
            ),
          ],
        ),
      ),
    );
  }

  void _authorizeAssistedPIN({
    required String minerId,
    required List<String> allMinerIds,
    required String condition,
    required String state,
    required int sacks,
    double? weight,
    required String source,
    required String estTime,
    required String notes,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => PinDialog(
        title: 'Miner PIN Verification',
        onConfirm: (pin) async {
          final operatorId = Supabase.instance.client.auth.currentUser?.id;
          if (operatorId == null) return 'Session expired.';

          final operatorName = _getMinerName(operatorId);

          final result = await _service.createRequest(
            creatorId: minerId,
            participatingMinerIds: allMinerIds,
            materialCondition: condition,
            materialState: state,
            numberOfSacks: sacks,
            materialWeight: weight != null && weight > 0 ? weight : null,
            source: source,
            notes: notes,
            processingRequirements: notes,
            estimatedTime: estTime,
            pin: pin,
            isOperatorAssisted: true,
            assistedByOperatorId: operatorId,
            assistedByOperatorName: operatorName,
          );

          return result.fold(
            (l) => l.message,
            (_) => null, // Return null so PinDialog pops itself
          );
        },
      ),
    ).then((success) {
      if (success == true) {
        // Close the Assisted Request Form Sheet
        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        }

        _loadRequests();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Assisted request submitted successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    });
  }

  Widget _buildFormLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 4),
      child: Text(
        text,
        style: const TextStyle(
          color: kGold,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 1,
        ),
      ),
    );
  }

  Widget _buildAssistedInput(
    String label,
    String hint,
    Function(String) onChanged, {
    bool isNumber = false,
    bool isDecimal = false,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        onChanged: onChanged,
        maxLines: maxLines,
        keyboardType: isNumber
            ? (isDecimal
                  ? const TextInputType.numberWithOptions(decimal: true)
                  : TextInputType.number)
            : TextInputType.text,
        style: TextStyle(color: context.textColor, fontSize: 14),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          filled: true,
          fillColor: context.surfaceColor,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildReviewRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(color: context.mutedTextColor, fontSize: 12),
          ),
          Text(
            value,
            style: TextStyle(
              color: context.textColor,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupMembersList(List<String> memberIds) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Group Members (${memberIds.length})',
            style: TextStyle(color: context.mutedTextColor, fontSize: 13),
          ),
          const SizedBox(height: 6),
          Container(
            constraints: const BoxConstraints(maxHeight: 176),
            decoration: BoxDecoration(
              color: context.bgColor.withOpacity(0.45),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: kGold.withOpacity(0.15)),
            ),
            child: Stack(
              children: [
                ListView.separated(
                  shrinkWrap: true,
                  padding: EdgeInsets.only(bottom: memberIds.length > 3 ? 24 : 0),
                  itemCount: memberIds.length,
                  separatorBuilder: (_, _) => Divider(
                    height: 1,
                    color: kGold.withOpacity(0.1),
                  ),
                  itemBuilder: (context, index) => ListTile(
                    dense: true,
                    visualDensity: VisualDensity.compact,
                    leading: Icon(
                      Icons.person_outline_rounded,
                      size: 18,
                      color: kGold.withOpacity(0.8),
                    ),
                    title: Text(
                      _getMinerName(memberIds[index]),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: context.textColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                if (memberIds.length > 3)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: IgnorePointer(
                      child: Container(
                        height: 28,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              context.bgColor.withOpacity(0),
                              context.bgColor.withOpacity(0.95),
                            ],
                          ),
                        ),
                        child: Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 20,
                          color: kGold.withOpacity(0.9),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: kGold.withOpacity(0.7),
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        ...children,
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(color: context.mutedTextColor, fontSize: 13),
          ),
          Text(
            value,
            style: TextStyle(
              color: context.textColor,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
