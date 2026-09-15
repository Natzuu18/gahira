import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dartz/dartz.dart' hide State;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/error/failures.dart';
import '../../application/services/service_request_service.dart';
import '../../domain/entities/service_request_entity.dart';
import '../../infrastructure/repositories/supabase_service_request_repository.dart';
import '../../infrastructure/repositories/supabase_user_repository.dart';
import '../../domain/entities/user_entity.dart';
import '../shared_widgets/appColor.dart';
import '../shared_widgets/themeToggleButton.dart';
import '../shared_widgets/pin_dialog.dart';
import '../shared_widgets/audit_trail_viewer.dart';
import 'client_drawer.dart';

class ServiceRequestsPage extends StatefulWidget {
  const ServiceRequestsPage({super.key});

  @override
  State<ServiceRequestsPage> createState() => _ServiceRequestsPageState();
}

class _ServiceRequestsPageState extends State<ServiceRequestsPage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final SupabaseServiceRequestRepository _repository = SupabaseServiceRequestRepository();
  late final ServiceRequestService _service;
  final SupabaseUserRepository _userRepository = SupabaseUserRepository();

  String _selectedFilter = 'All';
  String _searchQuery = '';
  List<ServiceRequestEntity> _requests = [];
  List<UserEntity> _availableMiners = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _service = ServiceRequestService(_repository);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final requestsResult = await _repository.getServiceRequests();
    final minersResult = await _userRepository.getMinersAndClients();

    setState(() {
      _requests = requestsResult.getOrElse(() => []);
      _availableMiners = minersResult.getOrElse(() => []);
      _isLoading = false;
    });
  }

  String _getStatusLabel(ServiceRequestStatus status) {
    switch (status) {
      case ServiceRequestStatus.pendingOperatorVerification:
        return 'Pending Verification';
      case ServiceRequestStatus.returnedToMiner:
        return 'Needs Attention';
      case ServiceRequestStatus.accepted:
        return 'Accepted';
      case ServiceRequestStatus.verified:
        return 'Verified';
      case ServiceRequestStatus.scheduled:
        return 'Scheduled';
      case ServiceRequestStatus.assigned:
        return 'Assigned';
      case ServiceRequestStatus.processing:
        return 'In Processing';
      case ServiceRequestStatus.processingCompleted:
        return 'Processing Done';
      case ServiceRequestStatus.goldHandoff:
        return 'Gold Hand-off';
      case ServiceRequestStatus.completed:
        return 'Completed';
      case ServiceRequestStatus.cancelled:
        return 'Cancelled';
      default:
        return status.name;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: context.bgColor,
      appBar: AppBar(
        backgroundColor: context.surfaceColor,
        elevation: 0,
        centerTitle: false,
        title: const Text(
          'MY SERVICES',
          style: TextStyle(
              color: kGold,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
              fontSize: 18),
        ),
        iconTheme: const IconThemeData(color: kGold),
        actions: [
          const ThemeToggleButton(),
          IconButton(
            icon: const Icon(Icons.menu_rounded, color: kGold),
            onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      endDrawer: const ClientDrawer(
          currentMenu: ClientMenu.serviceRequests, clientName: 'Miner'),
      floatingActionButton: FloatingActionButton(
        onPressed: _showNewRequestWorkflow,
        backgroundColor: kGold,
        elevation: 4,
        child: const Icon(Icons.add_rounded, color: kBlack, size: 28),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: kGold))
          : RefreshIndicator(
              onRefresh: _loadData,
              color: kGold,
              backgroundColor: context.surfaceColor,
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                    alignment: Alignment.centerLeft,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Track your requests',
                          style: TextStyle(
                              color: context.textColor,
                              fontSize: 24,
                              fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          onChanged: (value) => setState(() => _searchQuery = value),
                          style: TextStyle(color: context.textColor, fontSize: 14),
                          decoration: InputDecoration(
                            hintText: 'Search by material or ID...',
                            hintStyle: TextStyle(color: context.mutedTextColor, fontSize: 14),
                            prefixIcon: const Icon(Icons.search_rounded, color: kGold, size: 20),
                            filled: true,
                            fillColor: context.surfaceColor,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(color: kGold.withOpacity(0.1)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(color: kGold, width: 1.5),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    height: 40,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      physics: const BouncingScrollPhysics(),
                      children: [
                        _buildFilterChip('All'),
                        _buildFilterChip('Needs Attention'),
                        _buildFilterChip('In Progress'),
                        _buildFilterChip('Completed'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: CustomScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      slivers: [
                        SliverPadding(
                          padding: const EdgeInsets.all(16),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                if (_filteredRequests.isEmpty) {
                                  return _buildEmptyState();
                                }
                                return _buildRequestCard(_filteredRequests[index]);
                              },
                              childCount: _filteredRequests.isEmpty ? 1 : _filteredRequests.length,
                            ),
                          ),
                        ),
                        const SliverToBoxAdapter(child: SizedBox(height: 80)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  List<ServiceRequestEntity> get _filteredRequests {
    List<ServiceRequestEntity> list = List.from(_requests);

    // Sort: Needs Attention first, then by date (latest first)
    list.sort((a, b) {
      if (a.status == ServiceRequestStatus.returnedToMiner &&
          b.status != ServiceRequestStatus.returnedToMiner) {
        return -1;
      }
      if (b.status == ServiceRequestStatus.returnedToMiner &&
          a.status != ServiceRequestStatus.returnedToMiner) {
        return 1;
      }
      return b.createdAt.compareTo(a.createdAt);
    });

    if (_searchQuery.isNotEmpty) {
      list = list.where((r) => 
        r.materialDetails.type.toLowerCase().contains(_searchQuery.toLowerCase()) ||
        r.id.toLowerCase().contains(_searchQuery.toLowerCase())
      ).toList();
    }

    if (_selectedFilter == 'All') return list;
    
    if (_selectedFilter == 'Needs Attention') {
      return list.where((r) => r.status == ServiceRequestStatus.returnedToMiner).toList();
    }
    
    if (_selectedFilter == 'In Progress') {
      return list.where((r) => 
        r.status != ServiceRequestStatus.completed && 
        r.status != ServiceRequestStatus.cancelled &&
        r.status != ServiceRequestStatus.returnedToMiner
      ).toList();
    }
    
    if (_selectedFilter == 'Completed') {
      return list.where((r) => r.status == ServiceRequestStatus.completed).toList();
    }

    return list.where((r) => _getStatusLabel(r.status) == _selectedFilter).toList();
  }

  Widget _buildFilterChip(String label) {
    final bool selected = _selectedFilter == label;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (bool isSelected) =>
            setState(() => _selectedFilter = isSelected ? label : 'All'),
        backgroundColor: context.surfaceColor,
        selectedColor: kGold,
        labelStyle: TextStyle(
          color: selected ? kBlack : context.textColor,
          fontSize: 13,
          fontWeight: selected ? FontWeight.bold : FontWeight.normal,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: selected ? kGold : kGold.withOpacity(0.1)),
        ),
        showCheckmark: false,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 80),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: kGold.withOpacity(0.05),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.auto_awesome_motion_rounded,
                  size: 64, color: kGold.withOpacity(0.3)),
            ),
            const SizedBox(height: 24),
            Text(
              'Nothing to show here',
              style: TextStyle(
                  color: context.textColor,
                  fontSize: 18,
                  fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            Text(
              _searchQuery.isNotEmpty
                  ? 'No results match your search "$_searchQuery"'
                  : 'Try changing your filter or create a new request.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: context.mutedTextColor, fontSize: 14, height: 1.5),
            ),
            if (_searchQuery.isNotEmpty || _selectedFilter != 'All')
              Padding(
                padding: const EdgeInsets.only(top: 24),
                child: TextButton(
                  onPressed: () => setState(() {
                    _searchQuery = '';
                    _selectedFilter = 'All';
                  }),
                  child: const Text('Clear all filters',
                      style: TextStyle(color: kGold, fontWeight: FontWeight.bold)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(ServiceRequestStatus status) {
    final color = _getStatusColor(status);
    final icon = _getStatusIcon(status);
    final label = _getStatusLabel(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: color.withOpacity(0.2), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 8),
          Text(
            label.toUpperCase(),
            style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.8),
          ),
        ],
      ),
    );
  }

  IconData _getStatusIcon(ServiceRequestStatus status) {
    switch (status) {
      case ServiceRequestStatus.accepted:
      case ServiceRequestStatus.verified:
        return Icons.check_circle_outline;
      case ServiceRequestStatus.processingCompleted:
      case ServiceRequestStatus.goldHandoff:
        return Icons.handyman_outlined;
      case ServiceRequestStatus.completed:
        return Icons.task_alt;
      case ServiceRequestStatus.pendingOperatorVerification:
        return Icons.hourglass_empty;
      case ServiceRequestStatus.scheduled:
      case ServiceRequestStatus.assigned:
        return Icons.calendar_month_outlined;
      case ServiceRequestStatus.processing:
        return Icons.sync;
      case ServiceRequestStatus.returnedToMiner:
        return Icons.assignment_return_outlined;
      case ServiceRequestStatus.cancelled:
        return Icons.cancel_outlined;
      default:
        return Icons.info_outline;
    }
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: const TextStyle(
                color: kGold,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5),
          ),
          const SizedBox(height: 6),
          Divider(color: kGold.withOpacity(0.15), thickness: 1),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: kGold.withOpacity(0.6)),
          const SizedBox(width: 14),
          Text(label,
              style: TextStyle(color: context.mutedTextColor, fontSize: 14)),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
                color: context.textColor,
                fontSize: 14,
                fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestCard(ServiceRequestEntity request) {
    final bool isActionRequired =
        request.status == ServiceRequestStatus.returnedToMiner;
    final bool isProcessingDone =
        request.status == ServiceRequestStatus.processingCompleted;
    
    // Formatting date: e.g. "Sept 15, 2026"
    final String dateStr = "${request.createdAt.day}/${request.createdAt.month}/${request.createdAt.year}";

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isActionRequired
              ? Colors.red.withOpacity(0.3)
              : kGold.withOpacity(0.1),
          width: isActionRequired ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          iconColor: kGold,
          collapsedIconColor: kGold.withOpacity(0.7),
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isActionRequired ? Colors.red.withOpacity(0.1) : kGold.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isActionRequired ? Icons.priority_high_rounded : Icons.inventory_2_rounded, 
                  color: isActionRequired ? Colors.red : kGold, 
                  size: 20
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      request.materialDetails.type,
                      style: TextStyle(
                          color: context.textColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 16),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          'Ref: ${request.id.substring(0, 8).toUpperCase()}',
                          style: TextStyle(
                              color: context.mutedTextColor,
                              fontSize: 11,
                              letterSpacing: 0.5),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          "• $dateStr",
                          style: TextStyle(
                              color: context.mutedTextColor,
                              fontSize: 11),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${request.materialDetails.weight} kg',
                    style: TextStyle(
                        color: kGold,
                        fontWeight: FontWeight.bold,
                        fontSize: 14),
                  ),
                  if (request.materialDetails.numberOfSacks != null)
                    Text(
                      '${request.materialDetails.numberOfSacks} sacks',
                      style: TextStyle(
                          color: context.mutedTextColor,
                          fontSize: 10),
                    ),
                ],
              ),
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 12.0),
            child: Row(
              children: [
                _buildStatusBadge(request.status),
              ],
            ),
          ),
          childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          children: [
            const Divider(height: 32),
            _buildSectionHeader('Material Summary'),
            _buildDetailRow(Icons.scale_outlined, 'Initial Weight',
                '${request.materialDetails.weight} kg'),
            if (request.materialDetails.actualWeight != null)
              _buildDetailRow(Icons.monitor_weight_rounded, 'Verified Weight',
                  '${request.materialDetails.actualWeight} kg'),
            if (request.materialDetails.condition != null &&
                request.materialDetails.condition!.isNotEmpty)
              _buildDetailRow(
                  Icons.info_outline, 'Condition', request.materialDetails.condition!),
            if (request.materialDetails.numberOfSacks != null)
              _buildDetailRow(Icons.shopping_bag_outlined, 'Quantity',
                  '${request.materialDetails.numberOfSacks} Sacks'),
            if (request.materialDetails.source != null &&
                request.materialDetails.source!.isNotEmpty)
              _buildDetailRow(
                  Icons.location_on_outlined, 'Source', request.materialDetails.source!),
            _buildSectionHeader('Processing & Timeline'),
            if (request.processingDetails.estimatedTime != null)
              _buildDetailRow(Icons.timer_outlined, 'Est. Duration',
                  request.processingDetails.estimatedTime!),
            if (request.processingDetails.scheduledDate != null)
              _buildDetailRow(
                  Icons.calendar_today_outlined,
                  'Scheduled Date',
                  request.processingDetails.scheduledDate!
                      .toString()
                      .split(' ')[0]),
            if (request.processingDetails.assignedOperatorIds.isNotEmpty)
              _buildDetailRow(
                  Icons.badge_outlined,
                  'Assigned Team',
                  '${request.processingDetails.assignedOperatorIds.length} Operator(s)'),
            _buildDetailRow(
                Icons.notes_rounded,
                'Instructions',
                request.processingDetails.requirements.isEmpty
                    ? 'None'
                    : request.processingDetails.requirements),
            if (request.billingId != null) ...[
              _buildSectionHeader('Billing Reference'),
              _buildDetailRow(Icons.receipt_long_outlined, 'Invoice ID',
                  request.billingId!.substring(0, 8).toUpperCase()),
            ],
            if (isActionRequired) _buildReturnActionSection(request),
            if (isProcessingDone) _buildGoldHandoffSection(request),
            _buildSectionHeader('History'),
            FutureBuilder<Either<Failure, List<Map<String, dynamic>>>>(
              future: _repository.getAuditTrails(request.id),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(
                        child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: kGold))),
                  );
                }
                if (snapshot.hasData) {
                  return snapshot.data!.fold(
                    (l) => Text('History unavailable',
                        style: TextStyle(
                            color: Colors.red.shade300, fontSize: 12)),
                    (trails) => Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: context.bgColor.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: AuditTrailViewer(auditTrails: trails),
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReturnActionSection(ServiceRequestEntity request) {
    return Container(
      margin: const EdgeInsets.only(top: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Action Required: Request Returned',
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Reason: ${request.materialDetails.corrections ?? "Incomplete information"}',
            style: TextStyle(color: context.textColor.withOpacity(0.9), fontSize: 13),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _handleReturnResponse(request, true),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.check_rounded, size: 18),
                  label: const Text('Accept & Resubmit', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _handleReturnResponse(request, false),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.red),
                    foregroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.close_rounded, size: 18),
                  label: const Text('Cancel Request', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGoldHandoffSection(ServiceRequestEntity request) {
    return Container(
      margin: const EdgeInsets.only(top: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kGold.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kGold.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.stars_rounded, color: kGold, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Gold Hand-off Required',
                style: TextStyle(color: kGold, fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Processing is complete. Please submit the recovered gold to the Owner to finalize buying and billing.',
            style: TextStyle(color: context.textColor.withOpacity(0.9), fontSize: 13, height: 1.4),
          ),
        ],
      ),
    );
  }

  void _handleReturnResponse(ServiceRequestEntity request, bool accept) async {
    final result = await _service.minerRespondToReturn(
      requestId: request.id,
      minerId: request.creatorId,
      accept: accept,
      currentStatus: request.status.name,
    );
    result.fold(
      (l) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.message))),
      (_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(accept ? 'Corrections accepted. Request sent for Owner review.' : 'Request cancelled.'),
            backgroundColor: accept ? Colors.green : Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
        _loadData();
      },
    );
  }

  Color _getStatusColor(ServiceRequestStatus status) {
    switch (status) {
      case ServiceRequestStatus.accepted:
      case ServiceRequestStatus.verified:
      case ServiceRequestStatus.processingCompleted:
      case ServiceRequestStatus.goldHandoff:
      case ServiceRequestStatus.completed:
        return Colors.green;
      case ServiceRequestStatus.pendingOperatorVerification:
      case ServiceRequestStatus.scheduled:
      case ServiceRequestStatus.assigned:
      case ServiceRequestStatus.processing:
        return Colors.orange;
      case ServiceRequestStatus.returnedToMiner:
        return Colors.red;
      case ServiceRequestStatus.cancelled:
        return Colors.grey;
      default:
        return kGold;
    }
  }

  void _showNewRequestWorkflow() {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    if (currentUserId == null) return;

    int currentStep = 1;
    final formKey = GlobalKey<FormState>();

    // Step 1: Miner Selection
    bool forMyselfOnly = true;
    List<String> participating = [];
    String minerSearchQuery = '';

    // Step 2: Material Information
    String type = '';
    String condition = '';
    int? sacks;
    double weight = 0;
    String source = '';
    String notes = '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.bgColor,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                left: 20,
                right: 20,
                top: 12),
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
                            borderRadius: BorderRadius.circular(2)),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          currentStep == 1
                              ? 'Step 1: Miner Selection'
                              : 'Step 2: Material Information',
                          style: const TextStyle(
                              color: kGold,
                              fontSize: 20,
                              fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '$currentStep / 2',
                          style: TextStyle(
                              color: context.mutedTextColor,
                              fontSize: 14,
                              fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    if (currentStep == 1) ...[
                      Text('Are you creating this request as a group?',
                          style: TextStyle(
                              color: context.textColor,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      RadioListTile<bool>(
                        title: Text('Create for myself only',
                            style: TextStyle(
                                color: context.textColor, fontSize: 14)),
                        value: true,
                        groupValue: forMyselfOnly,
                        activeColor: kGold,
                        contentPadding: EdgeInsets.zero,
                        onChanged: (v) => setModalState(() => forMyselfOnly = v!),
                      ),
                      RadioListTile<bool>(
                        title: Text('Add another Miner (Group)',
                            style: TextStyle(
                                color: context.textColor, fontSize: 14)),
                        value: false,
                        groupValue: forMyselfOnly,
                        activeColor: kGold,
                        contentPadding: EdgeInsets.zero,
                        onChanged: (v) => setModalState(() => forMyselfOnly = v!),
                      ),
                      if (!forMyselfOnly) ...[
                        const SizedBox(height: 16),
                        TextField(
                          decoration: InputDecoration(
                            hintText: 'Search miners by name...',
                            prefixIcon: const Icon(Icons.search, color: kGold),
                            filled: true,
                            fillColor: context.surfaceColor,
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide:
                                    BorderSide(color: kGold.withOpacity(0.2))),
                          ),
                          style: TextStyle(color: context.textColor),
                          onChanged: (v) =>
                              setModalState(() => minerSearchQuery = v),
                        ),
                        const SizedBox(height: 12),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 200),
                          child: ListView(
                            shrinkWrap: true,
                            children: _availableMiners
                                .where((m) =>
                                    m.userId != currentUserId &&
                                    (m.fname.toLowerCase().contains(
                                            minerSearchQuery.toLowerCase()) ||
                                        m.lname.toLowerCase().contains(
                                            minerSearchQuery.toLowerCase())))
                                .map((m) => CheckboxListTile(
                                      title: Text('${m.fname} ${m.lname}',
                                          style: TextStyle(
                                              color: context.textColor,
                                              fontSize: 14)),
                                      value: participating.contains(m.userId),
                                      onChanged: (v) => setModalState(() => v!
                                          ? participating.add(m.userId)
                                          : participating.remove(m.userId)),
                                      activeColor: kGold,
                                      contentPadding: EdgeInsets.zero,
                                      controlAffinity:
                                          ListTileControlAffinity.leading,
                                    ))
                                .toList(),
                          ),
                        ),
                      ],
                    ] else ...[
                      _buildValidatedInput(
                        label: 'Material Type',
                        hint: 'e.g. Gold Ore',
                        onChanged: (v) => type = v,
                        validator: (v) => (v == null || v.isEmpty) ? 'Material type is required' : null,
                      ),
                      _buildValidatedInput(
                        label: 'Material Condition',
                        hint: 'e.g. Wet, Dry, Muddy',
                        onChanged: (v) => condition = v,
                      ),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _buildValidatedInput(
                              label: 'Number of Sacks',
                              hint: 'Optional',
                              keyboardType: TextInputType.number,
                              onChanged: (v) => sacks = int.tryParse(v),
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildValidatedInput(
                              label: 'Estimated Weight (kg)',
                              hint: '0.0',
                              keyboardType: const TextInputType.numberWithOptions(
                                  decimal: true),
                              onChanged: (v) => weight = double.tryParse(v) ?? 0,
                              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                              validator: (v) {
                                if (v == null || v.isEmpty) return 'Weight is required';
                                final val = double.tryParse(v);
                                if (val == null || val <= 0) return 'Enter a valid weight';
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                      _buildValidatedInput(
                        label: 'Source (Tunnel)',
                        hint: 'Which tunnel did this come from?',
                        onChanged: (v) => source = v,
                      ),
                      _buildValidatedInput(
                        label: 'Additional Notes',
                        hint: 'Any other processing requirements...',
                        maxLines: 2,
                        onChanged: (v) => notes = v,
                      ),
                      const SizedBox(height: 8),
                      Text('Upload Photo/Document',
                          style: TextStyle(
                              color: context.mutedTextColor,
                              fontSize: 12,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                              content: Text('Photo upload coming soon!')));
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          decoration: BoxDecoration(
                            color: context.surfaceColor,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: kGold.withOpacity(0.3),
                                style: BorderStyle.solid),
                          ),
                          child: Center(
                            child: Column(
                              children: [
                                Icon(Icons.add_a_photo_outlined,
                                    color: kGold.withOpacity(0.7)),
                                const SizedBox(height: 4),
                                Text('Add Attachment (Optional)',
                                    style: TextStyle(
                                        color: kGold.withOpacity(0.7),
                                        fontSize: 12)),
                              ],
                            ),
                          ),
                        ),
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
                                minimumSize: const Size(double.infinity, 54),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                              child: const Text('Back',
                                  style: TextStyle(
                                      color: kGold, fontWeight: FontWeight.bold)),
                            ),
                          ),
                          const SizedBox(width: 12),
                        ],
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              if (currentStep == 1) {
                                if (!forMyselfOnly && participating.isEmpty) {
                                   ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content: Text('Please select at least one other miner for a group request.')));
                                   return;
                                }
                                setModalState(() => currentStep = 2);
                              } else {
                                if (formKey.currentState!.validate()) {
                                  Navigator.pop(context);
                                  _showReviewDialog(
                                    type: type,
                                    condition: condition,
                                    weight: weight,
                                    sacks: sacks,
                                    source: source,
                                    notes: notes,
                                    miners: [currentUserId, ...participating],
                                  );
                                }
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: kGold,
                              foregroundColor: kBlack,
                              minimumSize: const Size(double.infinity, 54),
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            child: Text(
                                currentStep == 1 ? 'Next Step' : 'Review Request',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 16)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showReviewDialog({
    required String type,
    required String condition,
    required double weight,
    int? sacks,
    required String source,
    required String notes,
    required List<String> miners,
  }) {
    bool isCertified = false;
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return AlertDialog(
            backgroundColor: context.surfaceColor,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text('Review Request Details',
                style: TextStyle(color: kGold, fontWeight: FontWeight.bold)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Please check the entered information for accuracy.',
                      style: TextStyle(
                          color: context.mutedTextColor, fontSize: 13)),
                  const SizedBox(height: 20),
                  _buildDetailRow(Icons.category_rounded, 'Material Type', type),
                  if (condition.isNotEmpty)
                    _buildDetailRow(
                        Icons.info_outline, 'Condition', condition),
                  if (sacks != null)
                    _buildDetailRow(
                        Icons.shopping_bag_outlined, 'Sacks', sacks.toString()),
                  _buildDetailRow(Icons.scale_rounded, 'Est. Weight', '$weight kg'),
                  if (source.isNotEmpty)
                    _buildDetailRow(Icons.location_on_outlined, 'Source', source),
                  _buildDetailRow(Icons.people_rounded, 'Participants',
                      '${miners.length} Miner(s)'),
                  const SizedBox(height: 16),
                  Text('Additional Notes:',
                      style: TextStyle(
                          color: context.mutedTextColor,
                          fontSize: 12,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: context.bgColor.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      notes.isEmpty ? 'None' : notes,
                      style: TextStyle(
                          color: context.textColor,
                          fontWeight: FontWeight.w500,
                          fontSize: 13),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Divider(),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                        'I certify that the information above is accurate and ready for verification.',
                        style: TextStyle(fontSize: 12)),
                    value: isCertified,
                    activeColor: kGold,
                    onChanged: (v) => setModalState(() => isCertified = v!),
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Go Back',
                    style: TextStyle(color: context.mutedTextColor)),
              ),
              ElevatedButton(
                onPressed: isCertified
                    ? () {
                        Navigator.pop(context);
                        _showPinConfirmation(
                          type: type,
                          condition: condition,
                          weight: weight,
                          sacks: sacks,
                          source: source,
                          notes: notes,
                          miners: miners,
                        );
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: kGold,
                  foregroundColor: kBlack,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Authorize & Submit',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showPinConfirmation({
    required String type,
    required String condition,
    required double weight,
    int? sacks,
    required String source,
    required String notes,
    required List<String> miners,
  }) {
    showDialog(
      context: context,
      builder: (context) => PinDialog(
        title: 'Authorize Submission',
        onConfirm: (pin) async {
          final currentUserId = Supabase.instance.client.auth.currentUser?.id;
          if (currentUserId == null) return;

          final result = await _service.createRequest(
            creatorId: currentUserId,
            participatingMinerIds: miners,
            materialType: type,
            materialCondition: condition,
            numberOfSacks: sacks,
            materialWeight: weight,
            source: source,
            notes: notes,
            processingRequirements: notes, // Mapping notes to requirements for now
            pin: pin,
          );
          result.fold(
            (l) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(l.message), backgroundColor: Colors.redAccent)),
            (_) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Request submitted for Operator verification!'),
                  backgroundColor: Colors.green,
                  behavior: SnackBarBehavior.floating,
                ),
              );
              _loadData();
            },
          );
        },
      ),
    );
  }

  Widget _buildValidatedInput({
    required String label,
    required String hint,
    TextInputType? keyboardType,
    int maxLines = 1,
    required Function(String) onChanged,
    String? Function(String?)? validator,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  color: context.mutedTextColor,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5)),
          const SizedBox(height: 8),
          TextFormField(
            decoration: InputDecoration(
              hintText: hint,
              hintStyle:
                  TextStyle(color: context.mutedTextColor.withOpacity(0.3)),
              filled: true,
              fillColor: context.surfaceColor,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: kGold.withOpacity(0.2))),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: kGold.withOpacity(0.2))),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: kGold, width: 1.5)),
              errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.redAccent, width: 1)),
              focusedErrorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.redAccent, width: 1.5)),
              errorStyle: const TextStyle(color: Colors.redAccent, fontSize: 11),
            ),
            style: TextStyle(color: context.textColor),
            keyboardType: keyboardType,
            maxLines: maxLines,
            onChanged: onChanged,
            validator: validator,
            inputFormatters: inputFormatters,
            autovalidateMode: AutovalidateMode.onUserInteraction,
          ),
        ],
      ),
    );
  }
}
