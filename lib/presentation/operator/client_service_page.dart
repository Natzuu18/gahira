import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dartz/dartz.dart' hide State;
import '../../infrastructure/supabase/supabase_config.dart';
import '../../application/services/service_request_service.dart';
import '../../domain/entities/service_request_entity.dart';
import '../../infrastructure/repositories/supabase_service_request_repository.dart';
import '../shared_widgets/appColor.dart';
import '../shared_widgets/themeToggleButton.dart';
import '../shared_widgets/pin_dialog.dart';
import '../shared_widgets/audit_trail_viewer.dart';
import 'operator_drawer.dart';

class ClientServicePage extends StatefulWidget {
  const ClientServicePage({super.key});

  @override
  State<ClientServicePage> createState() => _ClientServicePageState();
}

class _ClientServicePageState extends State<ClientServicePage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final SupabaseServiceRequestRepository _repository = SupabaseServiceRequestRepository();
  late final ServiceRequestService _service;

  List<ServiceRequestEntity> _requests = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _service = ServiceRequestService(_repository);
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    setState(() => _isLoading = true);
    final result = await _repository.getServiceRequests();
    setState(() {
      _requests = result.getOrElse(() => []);
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final pendingVerification = _requests.where((r) => r.status == ServiceRequestStatus.pendingOperatorVerification).toList();

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: context.bgColor,
      appBar: AppBar(
        backgroundColor: context.surfaceColor,
        elevation: 0,
        title: const Text('MINER SERVICES', style: TextStyle(color: kGold, fontWeight: FontWeight.bold, letterSpacing: 2)),
        iconTheme: const IconThemeData(color: kGold),
        actions: [
          const ThemeToggleButton(),
          IconButton(
            icon: const Icon(Icons.menu_rounded, color: kGold),
            onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
          ),
        ],
      ),
      endDrawer: const OperatorDrawer(currentMenu: OperatorMenu.clientService, operatorName: 'Operator'),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: kGold))
          : RefreshIndicator(
              onRefresh: _loadRequests,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Text('Pending Verification', style: TextStyle(color: context.textColor, fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  if (pendingVerification.isEmpty)
                    Center(child: Text('No pending verifications', style: TextStyle(color: context.mutedTextColor)))
                  else
                    ...pendingVerification.map((r) => _buildVerificationCard(r)),
                ],
              ),
            ),
    );
  }

  Widget _buildVerificationCard(ServiceRequestEntity request) {
    return Card(
      color: context.surfaceColor,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: kGold.withOpacity(0.2))),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(request.creatorName ?? 'Unknown Miner', style: const TextStyle(color: kGold, fontWeight: FontWeight.bold, fontSize: 16)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: kGold.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                  child: Text('ID: ${request.id.substring(0, 8)}', style: const TextStyle(color: kGold, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(request.materialDetails.sourceType ?? 'N/A', style: TextStyle(color: context.textColor, fontWeight: FontWeight.w500, fontSize: 13)),
            const Divider(),
            _buildInfoRow('Miner Reqs', request.processingDetails.requirements),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _showVerificationDialog(request),
              style: ElevatedButton.styleFrom(backgroundColor: kGold, foregroundColor: kBlack, minimumSize: const Size(double.infinity, 45)),
              child: const Text('Verify Physical Material'),
            ),
          ],
        ),
      ),
    );
  }

  void _showVerificationDialog(ServiceRequestEntity request) {
    String estTime = '';
    String notes = '';
    String corrections = '';
    bool isAccurate = true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.bgColor,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 20, right: 20, top: 20),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Verify Material', style: TextStyle(color: kGold, fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: Text('Information is Accurate?', style: TextStyle(color: context.textColor)),
                    value: isAccurate,
                    onChanged: (v) => setModalState(() => isAccurate = v),
                    activeColor: kGold,
                  ),
                  TextField(
                    decoration: InputDecoration(labelText: 'Est. Processing Time', labelStyle: TextStyle(color: context.mutedTextColor)),
                    style: TextStyle(color: context.textColor),
                    onChanged: (v) => estTime = v,
                  ),
                  if (!isAccurate)
                    TextField(
                      decoration: InputDecoration(labelText: 'Corrections/Discrepancy', labelStyle: TextStyle(color: Colors.redAccent)),
                      style: TextStyle(color: context.textColor),
                      onChanged: (v) => corrections = v,
                    ),
                  TextField(
                    decoration: InputDecoration(labelText: 'Verification Notes', labelStyle: TextStyle(color: context.mutedTextColor)),
                    style: TextStyle(color: context.textColor),
                    onChanged: (v) => notes = v,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _confirmWithPin(request, estTime, isAccurate, notes, corrections);
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: kGold, minimumSize: const Size(double.infinity, 50)),
                    child: Text(isAccurate ? 'Confirm Verification' : 'Return to Miner', style: const TextStyle(color: kBlack)),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _confirmWithPin(ServiceRequestEntity request, String time, bool accurate, String notes, String corrections) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => PinDialog(
        onConfirm: (pin) async {
          final result = await _service.verifyMaterial(
            requestId: request.id,
            operatorId: SupabaseConfig.client.auth.currentUser?.id ?? '',
            actualSacks: request.materialDetails.numberOfSacks ?? 0,
            condition: request.materialDetails.condition ?? 'Rocky',
            state: request.materialDetails.state ?? 'Dry',
            source: request.materialDetails.source ?? '',
            estimatedTime: time,
            isAccurate: accurate,
            pin: pin,
            remarks: corrections.isNotEmpty ? corrections : notes,
            currentStatus: request.status.name,
          );
          return result.fold(
            (l) => l.message,
            (_) {
              _loadRequests();
              return null;
            },
          );
        },
      ),
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
