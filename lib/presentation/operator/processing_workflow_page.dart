import 'package:flutter/material.dart';
import '../../application/services/service_request_service.dart';
import '../../domain/entities/service_request_entity.dart';
import '../../infrastructure/repositories/supabase_service_request_repository.dart';
import '../shared_widgets/appColor.dart';
import '../shared_widgets/themeToggleButton.dart';
import '../shared_widgets/audit_trail_viewer.dart';
import 'operator_drawer.dart';

class ProcessingWorkflowPage extends StatefulWidget {
  const ProcessingWorkflowPage({super.key});

  @override
  State<ProcessingWorkflowPage> createState() => _ProcessingWorkflowPageState();
}

class _ProcessingWorkflowPageState extends State<ProcessingWorkflowPage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final SupabaseServiceRequestRepository _repository = SupabaseServiceRequestRepository();
  late final ServiceRequestService _service;

  List<ServiceRequestEntity> _requests = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _service = ServiceRequestService(_repository);
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    setState(() => _isLoading = true);
    final result = await _repository.getServiceRequests();
    setState(() {
      _requests = result.getOrElse(() => []);
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final assignedTasks = _requests.where((r) => r.status == ServiceRequestStatus.scheduled || r.status == ServiceRequestStatus.assigned).toList();
    final activeProcessing = _requests.where((r) => r.status == ServiceRequestStatus.processing).toList();

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: context.bgColor,
      appBar: AppBar(
        backgroundColor: context.surfaceColor,
        elevation: 0,
        title: const Text('PROCESSING', style: TextStyle(color: kGold, fontWeight: FontWeight.bold, letterSpacing: 2)),
        actions: [
          const ThemeToggleButton(),
          IconButton(icon: const Icon(Icons.menu_rounded, color: kGold), onPressed: () => _scaffoldKey.currentState?.openEndDrawer()),
        ],
      ),
      endDrawer: const OperatorDrawer(currentMenu: OperatorMenu.processing, operatorName: 'Operator'),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: kGold))
          : RefreshIndicator(
              onRefresh: _loadTasks,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  _buildSectionHeader('Active Processing'),
                  ...activeProcessing.map((r) => _buildJobCard(r, true)),
                  const SizedBox(height: 24),
                  _buildSectionHeader('Assigned Tasks'),
                  ...assignedTasks.map((r) => _buildJobCard(r, false)),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(title, style: TextStyle(color: context.textColor, fontSize: 18, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildJobCard(ServiceRequestEntity request, bool isActive) {
    return Card(
      color: context.surfaceColor,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: kGold.withOpacity(0.1))),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(request.materialDetails.type, style: TextStyle(color: context.textColor, fontWeight: FontWeight.bold)),
                Text(request.id.substring(0, 8), style: TextStyle(color: kGold, fontSize: 12)),
              ],
            ),
            const Divider(),
            _buildInfoRow('Weight', '${request.materialDetails.actualWeight ?? request.materialDetails.weight} kg'),
            _buildInfoRow('Est. Time', request.processingDetails.estimatedTime ?? 'N/A'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _updateStatus(request, isActive ? ServiceRequestStatus.processingCompleted : ServiceRequestStatus.processing),
              style: ElevatedButton.styleFrom(backgroundColor: isActive ? Colors.green : kGold, minimumSize: const Size(double.infinity, 45)),
              child: Text(isActive ? 'Mark as Completed' : 'Start Processing', style: const TextStyle(color: kBlack)),
            ),
          ],
        ),
      ),
    );
  }

  void _updateStatus(ServiceRequestEntity request, ServiceRequestStatus newStatus) async {
    final result = await _service.updateProcessingStatus(
      requestId: request.id,
      operatorId: 'CURRENT_OPERATOR_ID', // TODO
      newStatus: newStatus,
      currentStatus: request.status.name,
    );
    result.fold(
      (l) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.message))),
      (_) => _loadTasks(),
    );
  }

  Widget _buildInfoRow(String label, String value) {
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
}
