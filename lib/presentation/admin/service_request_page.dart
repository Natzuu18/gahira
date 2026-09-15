import 'package:flutter/material.dart';
import 'package:dartz/dartz.dart' hide State;
import '../../core/error/failures.dart';
import '../../application/services/service_request_service.dart';
import '../../domain/entities/service_request_entity.dart';
import '../../domain/entities/user_entity.dart';
import '../../infrastructure/repositories/supabase_service_request_repository.dart';
import '../../infrastructure/repositories/supabase_user_repository.dart';
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
  List<UserEntity> _operators = [];
  bool _isLoading = true;
  String _filterStatus = 'All';

  @override
  void initState() {
    super.initState();
    _service = ServiceRequestService(_repository);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final requestsResult = await _repository.getServiceRequests();
    final usersResult = await _userRepository.getMinersAndClients();
    
    setState(() {
      _requests = requestsResult.getOrElse(() => []);
      _operators = usersResult.getOrElse(() => []).where((u) => u.roleId == 'operator').toList();
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: context.bgColor,
      appBar: AppBar(
        backgroundColor: context.surfaceColor,
        elevation: 0,
        title: const Text('MANAGE REQUESTS', style: TextStyle(color: kGold, fontWeight: FontWeight.bold, letterSpacing: 2)),
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
                      itemBuilder: (context, index) => _buildRequestCard(_filteredRequests[index]),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  List<ServiceRequestEntity> get _filteredRequests {
    if (_filterStatus == 'All') return _requests;
    return _requests.where((r) => r.status.name.toLowerCase() == _filterStatus.toLowerCase()).toList();
  }

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      color: context.surfaceColor,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: ['All', 'Verified', 'Scheduled', 'Processing', 'ProcessingCompleted'].map((status) {
            final isSelected = _filterStatus == status;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(status, style: TextStyle(fontSize: 12, color: isSelected ? kBlack : context.textColor)),
                selected: isSelected,
                onSelected: (val) => setState(() => _filterStatus = status),
                selectedColor: kGold,
                backgroundColor: context.bgColor,
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildRequestCard(ServiceRequestEntity request) {
    return Card(
      color: context.surfaceColor,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: kGold.withOpacity(0.1))),
      child: ExpansionTile(
        title: Text('Request ID: ${request.id.substring(0, 8)}', style: const TextStyle(color: kGold, fontWeight: FontWeight.bold)),
        subtitle: Text('Status: ${request.status.name}', style: TextStyle(color: _getStatusColor(request.status))),
        childrenPadding: const EdgeInsets.all(16),
        children: [
          _buildDetailRow('Material', '${request.materialDetails.type} (${request.materialDetails.weight} kg)'),
          if (request.materialDetails.actualWeight != null)
            _buildDetailRow('Verified Weight', '${request.materialDetails.actualWeight} kg'),
          _buildDetailRow('Est. Time', request.processingDetails.estimatedTime ?? 'N/A'),
          const Divider(),
          if (request.status == ServiceRequestStatus.verified || request.status == ServiceRequestStatus.accepted)
            ElevatedButton(
              onPressed: () => _showScheduleDialog(request),
              style: ElevatedButton.styleFrom(backgroundColor: kGold, minimumSize: const Size(double.infinity, 45)),
              child: const Text('Schedule & Assign Operators', style: TextStyle(color: kBlack)),
            ),
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
    List<String> assignedOperators = [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.bgColor,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Schedule Processing', style: TextStyle(color: kGold, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                ListTile(
                  title: Text('Date: ${selectedDate.toLocal().toString().split(' ')[0]}', style: TextStyle(color: context.textColor)),
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
                const SizedBox(height: 16),
                const Text('Assign Operators', style: TextStyle(color: kGold, fontWeight: FontWeight.w500)),
                ..._operators.map((op) => CheckboxListTile(
                  title: Text('${op.fname} ${op.lname}', style: TextStyle(color: context.textColor)),
                  value: assignedOperators.contains(op.userId),
                  onChanged: (v) => setModalState(() => v! ? assignedOperators.add(op.userId) : assignedOperators.remove(op.userId)),
                  activeColor: kGold,
                )),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: assignedOperators.isEmpty ? null : () async {
                    final result = await _service.ownerScheduleAndAssign(
                      requestId: request.id,
                      ownerId: 'CURRENT_OWNER_ID', // TODO
                      scheduledDate: selectedDate,
                      assignedOperatorIds: assignedOperators,
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
          );
        },
      ),
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
      default: return kGold;
    }
  }
}
