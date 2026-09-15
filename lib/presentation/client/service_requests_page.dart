import 'package:flutter/material.dart';
import 'package:dartz/dartz.dart' hide State;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: context.bgColor,
      appBar: AppBar(
        backgroundColor: context.surfaceColor,
        elevation: 0,
        title: const Text('SERVICE REQUESTS', style: TextStyle(color: kGold, fontWeight: FontWeight.bold, letterSpacing: 2)),
        iconTheme: const IconThemeData(color: kGold),
        actions: [
          const ThemeToggleButton(),
          IconButton(
            icon: const Icon(Icons.menu_rounded, color: kGold),
            onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
          ),
        ],
      ),
      endDrawer: const ClientDrawer(currentMenu: ClientMenu.serviceRequests, clientName: 'Miner'),
      floatingActionButton: FloatingActionButton(
        onPressed: _showNewRequestWorkflow,
        backgroundColor: kGold,
        child: const Icon(Icons.add_rounded, color: kBlack),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: kGold))
          : RefreshIndicator(
              onRefresh: _loadData,
              color: kGold,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('My Requests', style: TextStyle(color: context.textColor, fontSize: 24, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 24),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: ServiceRequestStatus.values.map((s) => _buildFilterChip(s.name)).toList()
                          ..insert(0, _buildFilterChip('All')),
                      ),
                    ),
                    const SizedBox(height: 24),
                    if (_filteredRequests.isEmpty)
                      Center(child: Text('No requests found', style: TextStyle(color: context.mutedTextColor)))
                    else
                      ..._filteredRequests.map((r) => _buildRequestCard(r)),
                  ],
                ),
              ),
            ),
    );
  }

  List<ServiceRequestEntity> get _filteredRequests {
    if (_selectedFilter == 'All') return _requests;
    return _requests.where((r) => r.status.name.toLowerCase() == _selectedFilter.toLowerCase()).toList();
  }

  Widget _buildFilterChip(String label) {
    final bool selected = _selectedFilter.toLowerCase() == label.toLowerCase();
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: (bool selected) => setState(() => _selectedFilter = selected ? label : 'All'),
        backgroundColor: context.surfaceColor,
        selectedColor: kGold.withOpacity(0.2),
        labelStyle: TextStyle(color: selected ? kGold : context.textColor, fontSize: 12),
        checkmarkColor: kGold,
      ),
    );
  }

  Widget _buildRequestCard(ServiceRequestEntity request) {
    return Card(
      color: context.surfaceColor,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: kGold.withOpacity(0.1))),
      child: ExpansionTile(
        title: Text(request.materialDetails.type, style: TextStyle(color: context.textColor, fontWeight: FontWeight.bold)),
        subtitle: Text('Status: ${request.status.name}', style: TextStyle(color: _getStatusColor(request.status))),
        childrenPadding: const EdgeInsets.all(16),
        children: [
          _buildDetailRow('Weight', '${request.materialDetails.weight} kg'),
          if (request.materialDetails.actualWeight != null)
            _buildDetailRow('Actual Weight', '${request.materialDetails.actualWeight} kg'),
          _buildDetailRow('Requirements', request.processingDetails.requirements),
          if (request.status == ServiceRequestStatus.returnedToMiner)
             _buildReturnActionSection(request),
          const Divider(),
          const Text('Audit Trail', style: TextStyle(color: kGold, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          FutureBuilder<Either<Failure, List<Map<String, dynamic>>>>(
            future: _repository.getAuditTrails(request.id),
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                return snapshot.data!.fold((l) => Text('Error loading history'), (trails) => AuditTrailViewer(auditTrails: trails));
              }
              return const CircularProgressIndicator();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildReturnActionSection(ServiceRequestEntity request) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Request Returned!', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          Text('Corrections: ${request.materialDetails.corrections ?? "None"}', style: TextStyle(color: context.textColor, fontSize: 12)),
          const SizedBox(height: 8),
          Row(
            children: [
              ElevatedButton(
                onPressed: () => _handleReturnResponse(request, true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                child: const Text('Accept Corrections'),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: () => _handleReturnResponse(request, false),
                style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red)),
                child: const Text('Cancel Request', style: TextStyle(color: Colors.red)),
              ),
            ],
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
      (_) => _loadData(),
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
      case ServiceRequestStatus.verified:
      case ServiceRequestStatus.processingCompleted:
      case ServiceRequestStatus.completed:
        return Colors.green;
      case ServiceRequestStatus.pendingOperatorVerification:
      case ServiceRequestStatus.scheduled:
      case ServiceRequestStatus.assigned:
      case ServiceRequestStatus.processing:
        return Colors.orange;
      case ServiceRequestStatus.returnedToMiner:
        return Colors.red;
      default:
        return kGold;
    }
  }

  void _showNewRequestWorkflow() {
    String type = '';
    double weight = 0;
    String reqs = '';
    List<String> participating = [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.bgColor,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 20, right: 20, top: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('New Service Request', style: TextStyle(color: kGold, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                TextField(
                  decoration: InputDecoration(labelText: 'Material Type', labelStyle: TextStyle(color: context.mutedTextColor)),
                  style: TextStyle(color: context.textColor),
                  onChanged: (v) => type = v,
                ),
                TextField(
                  decoration: InputDecoration(labelText: 'Estimated Weight (kg)', labelStyle: TextStyle(color: context.mutedTextColor)),
                  style: TextStyle(color: context.textColor),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => weight = double.tryParse(v) ?? 0,
                ),
                TextField(
                  decoration: InputDecoration(labelText: 'Processing Requirements', labelStyle: TextStyle(color: context.mutedTextColor)),
                  style: TextStyle(color: context.textColor),
                  maxLines: 2,
                  onChanged: (v) => reqs = v,
                ),
                const SizedBox(height: 16),
                const Text('Participating Miners', style: TextStyle(color: kGold, fontWeight: FontWeight.w500)),
                ..._availableMiners.map((m) => CheckboxListTile(
                  title: Text('${m.fname} ${m.lname}', style: TextStyle(color: context.textColor)),
                  value: participating.contains(m.userId),
                  onChanged: (v) => setModalState(() => v! ? participating.add(m.userId) : participating.remove(m.userId)),
                  activeColor: kGold,
                )),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _showReviewDialog(type, weight, reqs, participating);
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: kGold, minimumSize: const Size(double.infinity, 50)),
                  child: const Text('Review Request', style: TextStyle(color: kBlack)),
                ),
                const SizedBox(height: 20),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showReviewDialog(String type, double weight, String reqs, List<String> miners) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.surfaceColor,
        title: const Text('Review Summary', style: TextStyle(color: kGold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('Material', type),
            _buildDetailRow('Weight', '$weight kg'),
            _buildDetailRow('Miners', miners.length.toString()),
            const SizedBox(height: 8),
            Text('Requirements:', style: TextStyle(color: context.mutedTextColor, fontSize: 12)),
            Text(reqs, style: TextStyle(color: context.textColor)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Go Back')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _showPinConfirmation(type, weight, reqs, miners);
            },
            style: ElevatedButton.styleFrom(backgroundColor: kGold),
            child: const Text('Confirm & Submit'),
          ),
        ],
      ),
    );
  }

  void _showPinConfirmation(String type, double weight, String reqs, List<String> miners) {
    showDialog(
      context: context,
      builder: (context) => PinDialog(
        onConfirm: (pin) async {
          final result = await _service.createRequest(
            creatorId: 'CURRENT_USER_ID', // TODO: Get from Auth State
            participatingMinerIds: miners,
            materialType: type,
            materialWeight: weight,
            processingRequirements: reqs,
            pin: pin,
          );
          result.fold(
            (l) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.message))),
            (_) => _loadData(),
          );
        },
      ),
    );
  }
}
