import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dartz/dartz.dart' hide State;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/error/failures.dart';
import '../../application/services/service_request_service.dart';
import '../../domain/entities/service_request_entity.dart';
import '../../infrastructure/repositories/supabase_service_request_repository.dart';
import '../../infrastructure/repositories/supabase_user_repository.dart';
import '../../infrastructure/models/user_model.dart';
import '../../domain/entities/user_entity.dart';
import '../shared_widgets/appColor.dart';
import '../shared_widgets/themeToggleButton.dart';
import '../shared_widgets/pin_dialog.dart';
import '../shared_widgets/audit_trail_viewer.dart';
import '../miner/miner_drawer.dart';

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
  UserEntity? _currentUser;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _service = ServiceRequestService(_repository);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;

    final requestsResult = await _repository.getServiceRequests();
    final minersResult = await _userRepository.getMinersAndClients();
    
    if (currentUserId != null) {
      final userResult = await _userRepository.getUserById(currentUserId);
      userResult.fold((l) => null, (user) => _currentUser = user);
    }

    setState(() {
      _requests = requestsResult.getOrElse(() => []);
      
      // Add example data if list is empty (UI Only focus)
      if (_requests.isEmpty) {
        _requests = [
          ServiceRequestEntity(
            id: 'REQ-DEMO-001',
            creatorId: currentUserId ?? '',
            participatingMinerIds: [],
            materialDetails: MaterialDetails(
              type: 'Gold Ore',
              condition: 'Rocky',
              state: 'Dry',
              sourceType: 'Associated Tunnel',
              source: _currentUser?.miningUnitName ?? 'Associated Tunnel #1',
              weight: 250.0,
              numberOfSacks: 5,
              photoUrls: ['dummy_url_1', 'dummy_url_2'],
            ),
            processingDetails: ProcessingDetails(
              requirements: 'Standard processing',
              assignedOperatorIds: [],
            ),
            status: ServiceRequestStatus.pendingOperatorVerification,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
          ServiceRequestEntity(
            id: 'REQ-DEMO-002',
            creatorId: currentUserId ?? '',
            participatingMinerIds: [],
            materialDetails: MaterialDetails(
              type: 'Silver Ore',
              condition: 'Mixed',
              state: 'Wet',
              sourceType: 'Other',
              source: 'External Quarry B',
              weight: 120.5,
              numberOfSacks: 3,
              photoUrls: [],
            ),
            processingDetails: ProcessingDetails(
              requirements: 'Careful refining',
              assignedOperatorIds: [],
            ),
            status: ServiceRequestStatus.verified,
            createdAt: DateTime.now().subtract(const Duration(days: 1)),
            updatedAt: DateTime.now().subtract(const Duration(days: 1)),
          ),
          ServiceRequestEntity(
            id: 'REQ-DEMO-003',
            creatorId: currentUserId ?? '',
            participatingMinerIds: [],
            materialDetails: MaterialDetails(
              type: 'Mixed Ore',
              condition: 'Clay',
              state: 'Others',
              sourceType: 'Partner Source',
              source: 'Consolidated Mines Group',
              weight: 500.0,
              numberOfSacks: 12,
              photoUrls: [],
            ),
            processingDetails: ProcessingDetails(
              requirements: 'High pressure washing needed',
              assignedOperatorIds: [],
            ),
            status: ServiceRequestStatus.processing,
            createdAt: DateTime.now().subtract(const Duration(days: 3)),
            updatedAt: DateTime.now().subtract(const Duration(days: 1)),
          ),
        ];
      }

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
      endDrawer: MinerDrawer(
          currentMenu: MinerMenu.serviceRequests, minerName: 'Miner'),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showRequestWorkflow(),
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

  Widget _buildStepLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 8),
      child: Text(text, style: TextStyle(color: context.mutedTextColor, fontSize: 12, fontWeight: FontWeight.bold)),
    );
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
                  if (request.status == ServiceRequestStatus.pendingOperatorVerification || 
                      request.status == ServiceRequestStatus.returnedToMiner)
                    IconButton(
                      icon: const Icon(Icons.edit_note_rounded, color: kGold, size: 24),
                      onPressed: () => _showRequestWorkflow(existingRequest: request),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  const SizedBox(height: 4),
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
            if (request.materialDetails.state != null &&
                request.materialDetails.state!.isNotEmpty)
              _buildDetailRow(
                  Icons.water_drop_outlined, 'State', request.materialDetails.state!),
            if (request.materialDetails.sourceType != null &&
                request.materialDetails.sourceType!.isNotEmpty)
              _buildDetailRow(
                  Icons.source_outlined, 'Source Type', request.materialDetails.sourceType!),
            if (request.materialDetails.source != null &&
                request.materialDetails.source!.isNotEmpty)
              _buildDetailRow(
                  Icons.location_on_outlined, 'Source Details', request.materialDetails.source!),
            if (request.materialDetails.photoUrls.isNotEmpty)
              _buildDetailRow(Icons.photo_library_outlined, 'Photos', '${request.materialDetails.photoUrls.length} Attached'),
            if (request.participatingMinerIds.length > 1)
              _buildParticipantsDropdown(request.participatingMinerIds),
            if (request.materialDetails.numberOfSacks != null)
              _buildDetailRow(Icons.shopping_bag_outlined, 'Quantity',
                  '${request.materialDetails.numberOfSacks} Sacks'),
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

  void _showRequestWorkflow({ServiceRequestEntity? existingRequest}) {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    if (currentUserId == null) return;

    int currentStep = 1;
    final formKey = GlobalKey<FormState>();

    // Step 1: Miner Selection
    bool forMyselfOnly = existingRequest == null || existingRequest.participatingMinerIds.length <= 1;
    bool isPickerOpen = false; 
    List<String> participating = existingRequest != null 
      ? existingRequest.participatingMinerIds.where((id) => id != currentUserId).toList() 
      : [];
    String minerSearchQuery = '';

    // Step 2: Material Information
    String condition = existingRequest?.materialDetails.condition ?? 'Rocky';
    String state = existingRequest?.materialDetails.state ?? 'Dry';
    String sourceType = existingRequest?.materialDetails.sourceType ?? 'Associated Ball Mill';
    String sourceDetails = existingRequest?.materialDetails.source ?? '';

    if (existingRequest == null) {
      if (_currentUser?.miningUnitType == 'Ball Mill' || _currentUser?.miningUnitType == 'Processing Plant') {
        sourceType = 'Associated Ball Mill';
        sourceDetails = _currentUser?.miningUnitName ?? '';
      } else {
        sourceType = 'Ball Mill / Processing Plant';
      }
    }

    int? sacks = existingRequest?.materialDetails.numberOfSacks;
    double weight = existingRequest?.materialDetails.weight ?? 0;
    String notes = existingRequest?.materialDetails.notes ?? '';
    List<PlatformFile> selectedPhotos = []; // Note: New photos only for simplicity or handle existing
    List<String> existingPhotoUrls = existingRequest?.materialDetails.photoUrls ?? [];

    final List<String> conditionOptions = ['Rocky', 'Muddy', 'Sandy', 'Mixed', 'Clay'];
    final List<String> stateOptions = ['Dry', 'Wet', 'Others'];
    final List<String> sourceOptions = [
      'Associated Ball Mill',
      'Ball Mill / Processing Plant',
      'Partner Source',
      'Other'
    ];

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
                        _buildStepLabel('Selected Participants'),
                        
                        // "Dropdown" Header
                        InkWell(
                          onTap: () => setModalState(() => isPickerOpen = !isPickerOpen),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: context.surfaceColor,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: kGold.withOpacity(0.3)),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: Row(
                                      children: participating.isEmpty 
                                        ? [Text('Tap to select miners...', style: TextStyle(color: context.mutedTextColor, fontSize: 13))]
                                        : participating.map((id) {
                                            UserEntity? miner;
                                            for (var m in _availableMiners) {
                                              if (m.userId == id) {
                                                miner = m;
                                                break;
                                              }
                                            }
                                            final name = miner != null ? '${miner.fname} ${miner.lname}' : 'Unknown';
                                            return Padding(
                                              padding: const EdgeInsets.only(right: 8.0),
                                              child: Chip(
                                                label: Text(name, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                                                backgroundColor: kGold.withOpacity(0.1),
                                                padding: EdgeInsets.zero,
                                                visualDensity: VisualDensity.compact,
                                                side: BorderSide(color: kGold.withOpacity(0.3)),
                                                onDeleted: () => setModalState(() => participating.remove(id)),
                                              ),
                                            );
                                          }).toList(),
                                    ),
                                  ),
                                ),
                                Icon(isPickerOpen ? Icons.arrow_drop_up_rounded : Icons.arrow_drop_down_rounded, color: kGold),
                              ],
                            ),
                          ),
                        ),

                        if (isPickerOpen) ...[
                          const SizedBox(height: 8),
                          // "Dropdown" Menu content
                          Container(
                            decoration: BoxDecoration(
                              color: context.surfaceColor.withOpacity(0.8),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: kGold.withOpacity(0.1)),
                              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2))],
                            ),
                            child: Column(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: TextField(
                                    decoration: InputDecoration(
                                      hintText: 'Search miners...',
                                      prefixIcon: const Icon(Icons.search, color: kGold, size: 18),
                                      isDense: true,
                                      contentPadding: EdgeInsets.zero,
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                    style: TextStyle(color: context.textColor, fontSize: 12),
                                    onChanged: (v) => setModalState(() => minerSearchQuery = v),
                                  ),
                                ),
                                Container(
                                  constraints: const BoxConstraints(maxHeight: 200),
                                  child: ListView(
                                    shrinkWrap: true,
                                    children: _availableMiners
                                        .where((m) =>
                                            m.userId != currentUserId &&
                                            (m.fname.toLowerCase().contains(minerSearchQuery.toLowerCase()) ||
                                                m.lname.toLowerCase().contains(minerSearchQuery.toLowerCase())))
                                        .map((m) => CheckboxListTile(
                                              title: Text('${m.fname} ${m.lname}', style: TextStyle(color: context.textColor, fontSize: 13)),
                                              value: participating.contains(m.userId),
                                              dense: true,
                                              visualDensity: VisualDensity.compact,
                                              onChanged: (v) => setModalState(() => v! ? participating.add(m.userId) : participating.remove(m.userId)),
                                              activeColor: kGold,
                                              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                                              controlAffinity: ListTileControlAffinity.leading,
                                            ))
                                        .toList(),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ] else ...[
                      // Material Condition (Bullets)
                      _buildStepLabel('Material Condition'),
                      ...conditionOptions.map((c) => RadioListTile<String>(
                        title: Text(c, style: TextStyle(color: context.textColor, fontSize: 13)),
                        value: c,
                        groupValue: condition,
                        activeColor: kGold,
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        onChanged: (v) => setModalState(() => condition = v!),
                      )).toList(),
                      const SizedBox(height: 16),

                      // Material State (Bullets)
                      _buildStepLabel('Material State'),
                      ...stateOptions.map((s) => RadioListTile<String>(
                        title: Text(s, style: TextStyle(color: context.textColor, fontSize: 13)),
                        value: s,
                        groupValue: state,
                        activeColor: kGold,
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        onChanged: (v) => setModalState(() => state = v!),
                      )).toList(),
                      const SizedBox(height: 16),

                      // Material Source (Bullets)
                      _buildStepLabel('Material Source'),
                      ...sourceOptions.map((so) => RadioListTile<String>(
                        title: Text(so, style: TextStyle(color: context.textColor, fontSize: 13)),
                        value: so,
                        groupValue: sourceType,
                        activeColor: kGold,
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        onChanged: (v) => setModalState(() {
                          sourceType = v!;
                          
                          // Auto-fill logic
                          bool canAutoFill = false;
                          if (sourceType == 'Associated Ball Mill' && 
                                    (_currentUser?.miningUnitType == 'Ball Mill' || _currentUser?.miningUnitType == 'Processing Plant')) {
                            canAutoFill = true;
                          }

                          if (canAutoFill && _currentUser?.miningUnitName != null) {
                            sourceDetails = _currentUser!.miningUnitName!;
                          } else {
                            sourceDetails = '';
                          }
                        }),
                      )).toList(),
                      const SizedBox(height: 16),

                      // Source Details
                      _buildStepLabel('Source Details'),
                      // Display read-only if it matches user's associated unit
                      if (sourceType == 'Associated Ball Mill' &&
                          sourceDetails.isNotEmpty &&
                          _currentUser?.miningUnitName == sourceDetails)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: context.surfaceColor,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: kGold.withOpacity(0.1)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Unit Type: ${_currentUser?.miningUnitType}', 
                                style: TextStyle(color: kGold, fontSize: 11, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              Text(sourceDetails, style: TextStyle(color: context.textColor, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        )
                      else
                        _buildValidatedInput(
                          label: '',
                          hint: 'Enter source details manually',
                          initialValue: sourceDetails,
                          onChanged: (v) => sourceDetails = v,
                          validator: (v) => (v == null || v.isEmpty) ? 'Source details required' : null,
                        ),
                      const SizedBox(height: 16),

                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _buildValidatedInput(
                              label: 'Number of Sacks',
                              hint: 'Optional',
                              initialValue: sacks?.toString(),
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
                              initialValue: weight > 0 ? weight.toString() : null,
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
                        label: 'Additional Notes',
                        hint: 'Any other processing requirements...',
                        initialValue: notes,
                        maxLines: 2,
                        onChanged: (v) => notes = v,
                      ),
                      const SizedBox(height: 8),
                      Text('Sack Photos (Up to 5)',
                          style: TextStyle(
                              color: context.mutedTextColor,
                              fontSize: 12,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            // Existing Photos
                            ...existingPhotoUrls.map((url) => Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: Stack(
                                children: [
                                  Container(
                                    width: 80,
                                    height: 80,
                                    decoration: BoxDecoration(
                                      color: context.surfaceColor,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: kGold.withOpacity(0.2)),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: Image.network(url, fit: BoxFit.cover, 
                                        errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, color: Colors.red)),
                                    ),
                                  ),
                                  Positioned(
                                    right: -2,
                                    top: -2,
                                    child: GestureDetector(
                                      onTap: () => setModalState(() => existingPhotoUrls.remove(url)),
                                      child: const CircleAvatar(
                                        radius: 10,
                                        backgroundColor: Colors.red,
                                        child: Icon(Icons.close, size: 12, color: Colors.white),
                                      ),
                                    ),
                                  )
                                ],
                              ),
                            )),
                            // New selected photos
                            ...selectedPhotos.map((p) => Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: Stack(
                                children: [
                                  Container(
                                    width: 80,
                                    height: 80,
                                    decoration: BoxDecoration(
                                      color: context.surfaceColor,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: kGold.withOpacity(0.2)),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: p.bytes != null 
                                        ? Image.memory(p.bytes!, fit: BoxFit.cover)
                                        : const Icon(Icons.image, color: kGold),
                                    ),
                                  ),
                                  Positioned(
                                    right: -2,
                                    top: -2,
                                    child: GestureDetector(
                                      onTap: () => setModalState(() => selectedPhotos.remove(p)),
                                      child: const CircleAvatar(
                                        radius: 10,
                                        backgroundColor: Colors.red,
                                        child: Icon(Icons.close, size: 12, color: Colors.white),
                                      ),
                                    ),
                                  )
                                ],
                              ),
                            )),
                            if ((selectedPhotos.length + existingPhotoUrls.length) < 5)
                              InkWell(
                                onTap: () async {
                                  final result = await FilePicker.platform.pickFiles(
                                    type: FileType.image,
                                    allowMultiple: true,
                                    withData: true,
                                  );
                                  if (result != null) {
                                    setModalState(() {
                                      final remaining = 5 - (selectedPhotos.length + existingPhotoUrls.length);
                                      selectedPhotos.addAll(result.files.take(remaining));
                                    });
                                  }
                                },
                                child: Container(
                                  width: 80,
                                  height: 80,
                                  decoration: BoxDecoration(
                                    color: context.surfaceColor,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: kGold.withOpacity(0.3), style: BorderStyle.solid),
                                  ),
                                  child: const Center(child: Icon(Icons.add_a_photo_outlined, color: kGold)),
                                ),
                              ),
                          ],
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
                                    existingRequestId: existingRequest?.id,
                                    condition: condition,
                                    state: state,
                                    sourceType: sourceType,
                                    weight: weight,
                                    sacks: sacks,
                                    source: sourceDetails,
                                    notes: notes,
                                    miners: [currentUserId, ...participating],
                                    newPhotos: selectedPhotos,
                                    existingPhotoUrls: existingPhotoUrls,
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
    String? existingRequestId,
    required String condition,
    required String state,
    required String sourceType,
    required double weight,
    int? sacks,
    required String source,
    required String notes,
    required List<String> miners,
    required List<PlatformFile> newPhotos,
    required List<String> existingPhotoUrls,
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
            title: Text(existingRequestId == null ? 'Review Request Details' : 'Review Updates',
                style: const TextStyle(color: kGold, fontWeight: FontWeight.bold)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Please check the entered information for accuracy.',
                      style: TextStyle(
                          color: context.mutedTextColor, fontSize: 13)),
                  const SizedBox(height: 20),
                  _buildDetailRow(Icons.info_outline, 'Condition', condition),
                  _buildDetailRow(Icons.water_drop_outlined, 'State', state),
                  _buildDetailRow(Icons.source_outlined, 'Source Type', sourceType),
                  _buildDetailRow(Icons.location_on_outlined, 'Source Details', source),
                  if (sacks != null)
                    _buildDetailRow(
                        Icons.shopping_bag_outlined, 'Sacks', sacks.toString()),
                  _buildDetailRow(Icons.scale_rounded, 'Est. Weight', '$weight kg'),
                  _buildDetailRow(Icons.people_rounded, 'Participants',
                      '${miners.length} Miner(s)'),
                  _buildDetailRow(Icons.photo_library_outlined, 'Photos', '${newPhotos.length + existingPhotoUrls.length} Total'),
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
                          existingRequestId: existingRequestId,
                          condition: condition,
                          state: state,
                          sourceType: sourceType,
                          weight: weight,
                          sacks: sacks,
                          source: source,
                          notes: notes,
                          miners: miners,
                          newPhotos: newPhotos,
                          existingPhotoUrls: existingPhotoUrls,
                        );
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: kGold,
                  foregroundColor: kBlack,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child: Text(existingRequestId == null ? 'Authorize & Submit' : 'Authorize & Update',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showPinConfirmation({
    String? existingRequestId,
    required String condition,
    required String state,
    required String sourceType,
    required double weight,
    int? sacks,
    required String source,
    required String notes,
    required List<String> miners,
    required List<PlatformFile> newPhotos,
    required List<String> existingPhotoUrls,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => PinDialog(
        title: 'Miner PIN Confirmation',
        onConfirm: (pin) async {
          final currentUserId = Supabase.instance.client.auth.currentUser?.id;
          if (currentUserId == null) return 'Session expired. Please re-login.';

          // 1. Upload new photos if any
          List<String> photoUrls = List.from(existingPhotoUrls);
          if (newPhotos.isNotEmpty) {
             final uploadResult = await _repository.uploadRequestPhotos(newPhotos);
             bool uploadFailed = false;
             uploadResult.fold(
               (l) => uploadFailed = true,
               (urls) => photoUrls.addAll(urls),
             );
             if (uploadFailed) return 'Failed to upload photos. Check connection.';
          }

          if (existingRequestId != null) {
            // UPDATE WORKFLOW
            final result = await _service.updateRequest(
              requestId: existingRequestId,
              creatorId: currentUserId,
              participatingMinerIds: miners,
              materialType: 'Ore',
              materialCondition: condition,
              materialState: state,
              materialSourceType: sourceType,
              numberOfSacks: sacks,
              materialWeight: weight,
              source: source,
              notes: notes,
              pin: pin,
              photoUrls: photoUrls,
            );
            return result.fold((l) => l.message, (_) {
               _loadData();
               return null;
            });
          } else {
            // CREATE WORKFLOW
            final result = await _service.createRequest(
              creatorId: currentUserId,
              participatingMinerIds: miners,
              materialType: 'Ore', 
              materialCondition: condition,
              materialState: state,
              materialSourceType: sourceType,
              numberOfSacks: sacks,
              materialWeight: weight,
              source: source,
              notes: notes,
              processingRequirements: notes, 
              pin: pin,
              photoUrls: photoUrls,
            );

            return result.fold(
              (l) => l.message, 
              (_) {
                _loadData();
                return null; 
              },
            );
          }
        },
      ),
    ).then((success) {
      if (success == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(existingRequestId == null ? 'Request submitted successfully!' : 'Request updated successfully!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });
  }

  Widget _buildParticipantsDropdown(List<String> ids) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        leading: Icon(Icons.group_outlined, size: 18, color: kGold.withOpacity(0.6)),
        title: Text('Participants (${ids.length})', style: TextStyle(color: context.mutedTextColor, fontSize: 14)),
        trailing: const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: kGold),
        childrenPadding: const EdgeInsets.only(left: 32, bottom: 12),
        expandedAlignment: Alignment.centerLeft,
        children: [
          Container(
            constraints: const BoxConstraints(maxHeight: 120),
            child: SingleChildScrollView(
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: ids.map((id) {
                   UserEntity? miner;
                    for (var m in _availableMiners) {
                      if (m.userId == id) {
                        miner = m;
                        break;
                      }
                    }
                    final name = miner != null ? '${miner.fname} ${miner.lname}' : 'Miner';
                    return Chip(
                      label: Text(name, style: const TextStyle(fontSize: 10)),
                      backgroundColor: kGold.withOpacity(0.05),
                      side: BorderSide(color: kGold.withOpacity(0.2)),
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                    );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildValidatedInput({
    required String label,
    required String hint,
    String? initialValue,
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
            initialValue: initialValue,
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

  String _getMinerNames(List<String> ids) {
    if (ids.isEmpty) return 'None';
    return ids.map((id) {
      // Manual loop to avoid runtime type issues with firstWhere and inheritance
      UserEntity? miner;
      for (final m in _availableMiners) {
        if (m.userId == id) {
          miner = m;
          break;
        }
      }

      miner ??= UserModel(
        userId: id,
        fname: 'Miner',
        lname: '',
        email: '',
        address: '',
        contactNum: '',
        roleId: '',
        status: '',
      );

      return '${miner!.fname} ${miner.lname}'.trim();
    }).join(', ');
  }
}
