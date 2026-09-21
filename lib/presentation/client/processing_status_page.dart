import 'package:flutter/material.dart';

import 'package:supabase_flutter/supabase_flutter.dart';
import '../../infrastructure/repositories/supabase_service_request_repository.dart';
import '../../domain/entities/service_request_entity.dart';
import '../shared_widgets/appColor.dart';
import '../shared_widgets/themeToggleButton.dart';
import '../shared_widgets/monitoring_page.dart';
import '../miner/miner_drawer.dart';

class ProcessingStatusPage extends StatefulWidget {
  const ProcessingStatusPage({super.key});

  @override
  State<ProcessingStatusPage> createState() => _ProcessingStatusPageState();
}

class _ProcessingStatusPageState extends State<ProcessingStatusPage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final _repository = SupabaseServiceRequestRepository();
  List<ServiceRequestEntity> _requests = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final result = await _repository.getServiceRequests();
    if (mounted) {
      setState(() {
        _requests = result.getOrElse(() => [])
            .where((r) => 
                r.status == ServiceRequestStatus.processing || 
                r.status == ServiceRequestStatus.processingCompleted ||
                r.status == ServiceRequestStatus.goldHandoff ||
                r.status == ServiceRequestStatus.completed)
            .toList();
        _isLoading = false;
      });
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
        title: const Text('PROCESSING TRACKER', style: TextStyle(color: kGold, fontWeight: FontWeight.bold, letterSpacing: 2, fontSize: 16)),
        iconTheme: const IconThemeData(color: kGold),
        actions: [
          const ThemeToggleButton(),
          IconButton(icon: const Icon(Icons.menu_rounded, color: kGold), onPressed: () => _scaffoldKey.currentState?.openEndDrawer()),
        ],
      ),
      endDrawer: MinerDrawer(currentMenu: MinerMenu.processingStatus, minerName: 'Miner'),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: kGold))
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  _buildSectionTitle('ACTIVE PROCESSING'),
                  if (_requests.where((r) => r.status != ServiceRequestStatus.completed).isEmpty)
                    _buildEmptyState('No active processing jobs.')
                  else
                    ..._requests.where((r) => r.status != ServiceRequestStatus.completed).map((r) => _buildMonitorCard(r)),
                  
                  const SizedBox(height: 32),
                  _buildSectionTitle('COMPLETED HISTORY'),
                  ..._requests.where((r) => r.status == ServiceRequestStatus.completed).map((r) => _buildMonitorCard(r)),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16, left: 4),
      child: Text(title, style: TextStyle(color: context.mutedTextColor, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
    );
  }

  Widget _buildEmptyState(String msg) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(color: context.surfaceColor, borderRadius: BorderRadius.circular(16)),
      child: Center(child: Text(msg, style: TextStyle(color: context.mutedTextColor, fontSize: 13))),
    );
  }

  Widget _buildMonitorCard(ServiceRequestEntity request) {
    final bool isDone = request.status == ServiceRequestStatus.completed;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kGold.withOpacity(0.1)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: (isDone ? Colors.green : kGold).withOpacity(0.1), shape: BoxShape.circle),
          child: Icon(isDone ? Icons.check_circle : Icons.sync, color: isDone ? Colors.green : kGold),
        ),
        title: Text(request.materialDetails.sourceType ?? 'Service Request', style: TextStyle(color: context.textColor, fontWeight: FontWeight.bold)),
        subtitle: Text('ID: ${request.id.substring(0, 8).toUpperCase()} • ${request.status.name}', style: const TextStyle(fontSize: 12)),
        trailing: const Icon(Icons.chevron_right, color: kGold),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => MonitoringPage(request: request))),
      ),
    );
  }
}
}
