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

class ServiceRequestPage extends StatefulWidget {
  const ServiceRequestPage({super.key});

  @override
  State<ServiceRequestPage> createState() => _ServiceRequestPageState();
}

class _ServiceRequestPageState extends State<ServiceRequestPage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final SupabaseServiceRequestRepository _repository = SupabaseServiceRequestRepository();
  late final ServiceRequestService _service;
  final SupabaseUserRepository _userRepository = SupabaseUserRepository();

  List<ServiceRequestEntity> _requests = [];
  List<UserEntity> _allUsers = [];
  bool _isLoading = true;
  String _filterStatus = 'All';
  String _scheduleTimelineFilter = 'All'; // New options: 'All', 'Today', 'Upcoming'

  @override
  void initState() {
    super.initState();
    _service = ServiceRequestService(_repository);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final requestsResult = await _repository.getServiceRequests();
    final usersResult = await _userRepository.getAllUsers();
    
    setState(() {
      _requests = requestsResult.getOrElse(() => []);
      _allUsers = usersResult.getOrElse(() => []);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: context.bgColor,
      appBar: AppBar(
        backgroundColor: context.surfaceColor,
        elevation: 0,
        title: const Text('SERVICES', style: TextStyle(color: kGold, fontWeight: FontWeight.bold, letterSpacing: 2)),
        actions: [
          const ThemeToggleButton(),
          IconButton(icon: const Icon(Icons.menu_rounded, color: kGold), onPressed: () => _scaffoldKey.currentState?.openEndDrawer()),
        ],
      ),
      endDrawer: const AdminDrawer(currentMenu: AdminMenu.serviceRequest),
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
                        return _buildRequestCard(req, index: (_filterStatus == 'Verified' || _filterStatus == 'Queued') ? index + 1 : null);
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
    if (_filterStatus != 'All') {
      list = list.where((r) => r.status.name.toLowerCase() == _filterStatus.toLowerCase()).toList();
    }
    
    // Sort logic for Queue: Sort items in the queue by their creation time so their UI index acts as dynamic position counter
    // Only display items that haven't moved to 'processing' or 'completed' stages yet
    if (_filterStatus == 'Verified' || _filterStatus == 'Queued') {
      list = list.where((r) => r.status != ServiceRequestStatus.processing && r.status != ServiceRequestStatus.processingCompleted && r.status != ServiceRequestStatus.completed).toList();
      list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    }
    // Timeline filter logic for Scheduled services
    if (_filterStatus == 'Scheduled') {
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final todayEnd = todayStart.add(const Duration(days: 1));

      if (_scheduleTimelineFilter == 'Today') {
        list = list.where((r) => r.approvedAt != null && r.approvedAt!.isAfter(todayStart) && r.approvedAt!.isBefore(todayEnd)).toList();
      } else if (_scheduleTimelineFilter == 'Upcoming') {
        list = list.where((r) => r.approvedAt != null && r.approvedAt!.isAfter(todayEnd)).toList();
      }
      
      // Sort scheduled by date
      list.sort((a, b) => a.approvedAt?.compareTo(b.approvedAt ?? DateTime.now()) ?? 0);
    }
    return list;
  }

  Widget _buildFilterBar() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          color: context.surfaceColor,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: ['All', 'Verified', 'Queued', 'Scheduled', 'Processing', 'ProcessingCompleted'].map((status) {
                final isSelected = _filterStatus == status;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(status, style: TextStyle(fontSize: 12, color: isSelected ? kBlack : context.textColor)),
                    selected: isSelected,
                    onSelected: (val) => setState(() {
                      _filterStatus = status;
                      if (_filterStatus != 'Scheduled') _scheduleTimelineFilter = 'All';
                    }),
                    selectedColor: kGold,
                    backgroundColor: context.bgColor,
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        if (_filterStatus == 'Scheduled')
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            decoration: BoxDecoration(
              color: context.surfaceColor,
              border: Border(top: BorderSide(color: kGold.withOpacity(0.1))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: ['All', 'Today', 'Upcoming'].map((timeline) {
                final isSelected = _scheduleTimelineFilter == timeline;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ActionChip(
                    label: Text(timeline, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isSelected ? kBlack : context.textColor.withOpacity(0.7))),
                    onPressed: () => setState(() => _scheduleTimelineFilter = timeline),
                    backgroundColor: isSelected ? kGold : context.bgColor,
                    padding: EdgeInsets.zero,
                    side: BorderSide(color: isSelected ? kGold : kGold.withOpacity(0.1)),
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }

  Widget _buildRequestCard(ServiceRequestEntity request, {int? index}) {
    final bool isKorpo = request.participatingMinerIds.length > 1;
    final String typeLabel = isKorpo ? 'KORPO (${request.participatingMinerIds.length})' : 'INDIVIDUAL';
    final String requesterName = _getCreatorName(request);
    final String dateStr = DateFormat('MMM dd, yyyy • hh:mm a').format(request.createdAt);

    return Card(
      color: context.surfaceColor,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: kGold.withOpacity(0.1))),
      child: ExpansionTile(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(requesterName, style: const TextStyle(color: kGold, fontWeight: FontWeight.bold)),
            if (index != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.orange.withOpacity(0.3)),
                ),
                child: Text(
                  'QUEUE POSITION: #$index',
                  style: const TextStyle(color: Colors.orange, fontSize: 11, fontWeight: FontWeight.bold),
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
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isKorpo ? Colors.blue.withOpacity(0.1) : kGold.withOpacity(0.1),
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
                Text(dateStr, style: TextStyle(color: context.mutedTextColor, fontSize: 11)),
              ],
            ),
            const SizedBox(height: 4),
            Text('Status: ${request.status.name}', style: TextStyle(color: _getStatusColor(request.status), fontSize: 12)),
          ],
        ),
        childrenPadding: const EdgeInsets.all(16),
        children: [
          if (isKorpo) ...[
            const Text('GROUP PARTICIPANTS', style: TextStyle(color: kGold, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: request.participatingMinerIds.map((id) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: kGold.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: kGold.withOpacity(0.2)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.person_outline_rounded, size: 14, color: kGold),
                    const SizedBox(width: 6),
                    Text(
                      _getUserName(id),
                      style: TextStyle(color: context.textColor, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              )).toList(),
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),
          ],
          _buildDetailRow('Number of Sacks', '${request.materialDetails.numberOfSacks ?? 0} Sacks'),
          _buildDetailRow('Condition', request.materialDetails.condition ?? 'N/A'),
          _buildDetailRow('State', request.materialDetails.state ?? 'N/A'),
          _buildDetailRow('Est. Time', request.processingDetails.estimatedTime ?? 'N/A'),
          if (request.status == ServiceRequestStatus.verified || request.status == ServiceRequestStatus.accepted) ...[
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
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              ],
            ),
          ],
          const Divider(),
          const SizedBox(height: 16),
          const Text('Audit Trail', style: TextStyle(color: kGold, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          FutureBuilder<Either<Failure, List<Map<String, dynamic>>>>(
            future: _repository.getAuditTrails(request.id),
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                return snapshot.data!.fold((l) => const Text('Error loading history'), (trails) => AuditTrailViewer(auditTrails: trails));
              }
              return const CircularProgressIndicator();
            },
          ),
        ],
      ),
    );
  }

  void _showScheduleDialog(ServiceRequestEntity request) {
    DateTime selectedDate = DateTime.now().add(const Duration(days: 1));

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
                  Text('Schedule Processing', style: TextStyle(color: kGold, fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  ListTile(
                    title: Text('Date: ${DateFormat('yyyy-MM-dd').format(selectedDate)}', style: TextStyle(color: context.textColor)),
                    trailing: const Icon(Icons.calendar_today, color: kGold),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 90)),
                      );
                      if (picked != null) setModalState(() => selectedDate = picked);
                    },
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () async {
                      final currentUserId = SupabaseConfig.client.auth.currentUser?.id;
                      if (currentUserId == null) return;

                      final result = await _service.ownerScheduleAndAssign(
                        requestId: request.id,
                        ownerId: currentUserId,
                        scheduledDate: selectedDate,
                        assignedOperatorIds: const [], // Empty list as operator assignment isn't required here
                        currentStatus: request.status.name,
                      );
                      Navigator.pop(context);
                      result.fold(
                        (l) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.message))),
                        (_) => _loadData(),
                      );
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: kGold, minimumSize: const Size(double.infinity, 50)),
                    child: const Text('Confirm Schedule', style: TextStyle(color: kBlack)),
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
    final currentUserId = SupabaseConfig.client.auth.currentUser?.id;
    if (currentUserId == null) return;

    final result = await _service.addToGeneralQueue(
      requestId: request.id,
      userId: currentUserId,
      currentStatus: request.status.name,
    );

    result.fold(
      (l) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.message))),
      (_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Added to general mill queue table successfully'), backgroundColor: Colors.green),
        );
        _loadData();
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: context.mutedTextColor, fontSize: 13)),
          Text(value, style: TextStyle(color: context.textColor, fontSize: 13, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Color _getStatusColor(ServiceRequestStatus status) {
    switch (status) {
      case ServiceRequestStatus.completed: return Colors.green;
      case ServiceRequestStatus.processing: return Colors.blue;
      case ServiceRequestStatus.returnedToMiner: return Colors.red;
      case ServiceRequestStatus.scheduled: return kGold;
      case ServiceRequestStatus.verified: return Colors.teal;
      case ServiceRequestStatus.accepted: return Colors.green;
      default: return kGold;
    }
  }
}
