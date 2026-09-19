import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../application/services/service_request_service.dart';
import '../../domain/entities/service_request_entity.dart';
import '../../infrastructure/repositories/supabase_service_request_repository.dart';
import '../shared_widgets/appColor.dart';
import '../shared_widgets/themeToggleButton.dart';
import '../shared_widgets/adminDrawer.dart';

class BillingPage extends StatefulWidget {
  const BillingPage({super.key});

  @override
  State<BillingPage> createState() => _BillingPageState();
}

class _BillingPageState extends State<BillingPage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final SupabaseServiceRequestRepository _repository = SupabaseServiceRequestRepository();
  late final ServiceRequestService _service;
  
  List<ServiceRequestEntity> _completedRequests = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _service = ServiceRequestService(_repository);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final result = await _repository.getServiceRequests();
    setState(() {
      _completedRequests = result.getOrElse(() => [])
          .where((r) => r.status == ServiceRequestStatus.processingCompleted || r.status == ServiceRequestStatus.completed)
          .toList();
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
        title: const Text('GOLD HANDOFF & BILLING', style: TextStyle(color: kGold, fontWeight: FontWeight.bold, letterSpacing: 2)),
        actions: [
          const ThemeToggleButton(),
          IconButton(icon: const Icon(Icons.menu_rounded, color: kGold), onPressed: () => _scaffoldKey.currentState?.openEndDrawer()),
        ],
      ),
      endDrawer: const AdminDrawer(currentMenu: AdminMenu.bills),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: kGold))
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView.builder(
                padding: const EdgeInsets.all(20),
                itemCount: _completedRequests.length,
                itemBuilder: (context, index) => _buildBillingCard(_completedRequests[index]),
              ),
            ),
    );
  }

  Widget _buildBillingCard(ServiceRequestEntity request) {
    final isDone = request.status == ServiceRequestStatus.completed;
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
                Text('Request ID: ${request.id.substring(0, 8)}', style: const TextStyle(color: kGold, fontWeight: FontWeight.bold)),
                if (isDone) const Icon(Icons.check_circle, color: Colors.green, size: 20),
              ],
            ),
            const Divider(),
            _buildDetailRow('Reference', request.id.substring(0, 8).toUpperCase()),
            if (!isDone)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: ElevatedButton(
                  onPressed: () => _showBillingDialog(request),
                  style: ElevatedButton.styleFrom(backgroundColor: kGold, minimumSize: const Size(double.infinity, 45)),
                  child: const Text('Process Gold Handoff & Bill', style: TextStyle(color: kBlack)),
                ),
              )
            else
              _buildDetailRow('Billing ID', request.billingId ?? 'N/A'),
          ],
        ),
      ),
    );
  }

  void _showBillingDialog(ServiceRequestEntity request) {
    String billId = 'BILL-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
    double goldValue = 0;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.surfaceColor,
        title: const Text('Finalize Transaction', style: TextStyle(color: kGold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: InputDecoration(labelText: 'Gold Valuation (PHP)', labelStyle: TextStyle(color: context.mutedTextColor)),
              keyboardType: TextInputType.number,
              style: TextStyle(color: context.textColor),
              onChanged: (v) => goldValue = double.tryParse(v) ?? 0,
            ),
            const SizedBox(height: 16),
            Text('Billing ID: $billId', style: TextStyle(color: context.mutedTextColor, fontSize: 12)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: kGold),
            onPressed: () async {
              final result = await _service.completeBilling(
                requestId: request.id,
                ownerId: 'CURRENT_OWNER_ID', // TODO
                billingId: billId,
                currentStatus: request.status.name,
              );
              Navigator.pop(context);
              result.fold(
                (l) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.message))),
                (_) => _loadData(),
              );
            },
            child: const Text('Complete Handoff', style: TextStyle(color: kBlack)),
          ),
        ],
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
}
