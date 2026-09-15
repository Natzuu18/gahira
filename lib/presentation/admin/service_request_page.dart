import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../shared_widgets/appColor.dart';
import '../shared_widgets/adminDrawer.dart';
import '../shared_widgets/themeToggleButton.dart';

import '../../../infrastructure/repositories/supabase_service_request_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ServiceRequestPage extends StatefulWidget {
  const ServiceRequestPage({super.key});

  @override
  State<ServiceRequestPage> createState() => _ServiceRequestPageState();
}

class _ServiceRequestPageState extends State<ServiceRequestPage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final _repository = SupabaseServiceRequestRepository();
  String _filterStatus = 'All';
  List<Map<String, dynamic>> _requests = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchRequests();
  }

  Future<void> _fetchRequests() async {
    setState(() => _isLoading = true);
    final result = await _repository.getServiceRequests();
    
    if (!mounted) return;

    result.fold(
      (failure) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(failure.message)));
        setState(() => _isLoading = false);
      },
      (list) {
        // Map backend data to UI expected format
        final mapped = list.map((r) {
          final user = r['user'] as Map<String, dynamic>?;
          return {
            'id': r['service_request_id'],
            'raw_id': r['service_request_id'],
            'minerName': user != null ? '${user['fname']} ${user['lname']}' : 'Unknown Miner',
            'type': r['service_type'] ?? 'Standard',
            'material': r['purpose'] ?? 'Unspecified Material',
            'weight': '${r['quantity'] ?? 0} kg',
            'estimatedTime': 'TBD', // This can be calculated later
            'status': r['status'] ?? 'Pending',
            'operatorVerified': r['approved_at'] != null,
            'operatorName': 'System', // Placeholder
            'createdAt': DateFormat('yyyy-MM-dd hh:mm a').format(DateTime.parse(r['created_at'])),
            'participatingMiners': [user != null ? '${user['fname']} ${user['lname']}' : 'Miner'],
            'remarks': r['remarks'] ?? '',
          };
        }).toList();

        setState(() {
          _requests = mapped;
          _isLoading = false;
        });
      },
    );
  }

  List<Map<String, dynamic>> get _filteredRequests {
    if (_filterStatus == 'All') return _requests;
    return _requests.where((r) => r['status'] == _filterStatus).toList();
  }

  Future<void> _updateStatus(String requestId, String newStatus) async {
    final adminId = Supabase.instance.client.auth.currentUser?.id;
    if (adminId == null) return;

    final result = await _repository.updateRequestStatus(
      requestId: requestId,
      status: newStatus,
      adminId: adminId,
    );

    result.fold(
      (failure) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(failure.message))),
      (_) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Request $newStatus')));
        _fetchRequests();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: context.bgColor,
      appBar: AppBar(
        backgroundColor: context.surfaceColor,
        elevation: 0,
        leadingWidth: 64,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16),
          child: _buildLogoMark(),
        ),
        title: const Text(
          'SERVICE REQUESTS',
          style: TextStyle(color: kGold, fontWeight: FontWeight.bold, letterSpacing: 2, fontSize: 16),
        ),
        actions: [
          const ThemeToggleButton(),
          IconButton(
            icon: const Icon(Icons.menu_rounded, color: kGold),
            onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
          ),
        ],
      ),
      endDrawer: const AdminDrawer(currentMenu: AdminMenu.serviceRequest),
      body: Column(
        children: [
          _buildFilterBar(),
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator(color: kGold))
              : RefreshIndicator(
                  onRefresh: _fetchRequests,
                  color: kGold,
                  child: _filteredRequests.isEmpty 
                    ? const Center(child: Text('No service requests found'))
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _filteredRequests.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 16),
                        itemBuilder: (context, index) => _buildRequestCard(_filteredRequests[index]),
                      ),
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      color: context.surfaceColor,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: ['All', 'Awaiting Review', 'Pending Verification', 'Approved', 'Rejected'].map((status) {
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

  Widget _buildRequestCard(Map<String, dynamic> request) {
    return Container(
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.textColor.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(request['id'], style: const TextStyle(color: kGold, fontWeight: FontWeight.bold, fontSize: 13)),
                    Text(request['createdAt'], style: TextStyle(color: context.mutedTextColor, fontSize: 11)),
                  ],
                ),
                _buildStatusBadge(request['status']),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildInfoRow(Icons.person_outline, 'Primary Miner', request['minerName']),
                _buildInfoRow(Icons.category_outlined, 'Request Type', request['type']),
                _buildInfoRow(Icons.layers_outlined, 'Material', '${request['material']} (${request['weight']})'),
                _buildInfoRow(Icons.timer_outlined, 'Est. Processing', request['estimatedTime']),
                _buildInfoRow(
                  Icons.verified_user_outlined, 
                  'Verification', 
                  request['operatorVerified'] ? 'Verified by ${request['operatorName']}' : 'Awaiting Operator',
                  valueColor: request['operatorVerified'] ? Colors.green : Colors.orange
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _showRequestDetails(request),
                    style: OutlinedButton.styleFrom(side: BorderSide(color: kGold.withOpacity(0.5))),
                    child: const Text('VIEW DETAILS', style: TextStyle(color: kGold, fontSize: 12)),
                  ),
                ),
                const SizedBox(width: 12),
                if (request['status'] == 'Pending' || request['status'] == 'Awaiting Review')
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _showProceedDialog(request),
                      style: ElevatedButton.styleFrom(backgroundColor: kGold),
                      child: const Text('PROCEED TO SCHEDULE', style: TextStyle(color: kBlack, fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: kGold.withOpacity(0.7)),
          const SizedBox(width: 12),
          Text('$label:', style: TextStyle(color: context.mutedTextColor, fontSize: 12)),
          const SizedBox(width: 8),
          Expanded(child: Text(value, style: TextStyle(color: valueColor ?? context.textColor, fontSize: 12, fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color = Colors.blue;
    if (status == 'Awaiting Review' || status == 'Pending') color = kGold;
    if (status == 'Approved') color = Colors.green;
    if (status == 'Rejected') color = Colors.red;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: color.withOpacity(0.5))),
      child: Text(status.toUpperCase(), style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  void _showRequestDetails(Map<String, dynamic> request) {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.surfaceColor,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        expand: false,
        builder: (_, controller) => SingleChildScrollView(
          controller: controller,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Full Request Details', style: TextStyle(color: kGold, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              _buildDetailSection('PARTICIPATING MINERS', (request['participatingMiners'] as List).join(', ')),
              _buildDetailSection('MATERIAL ANALYSIS', 'Visual inspection passed. Purpose: ${request['material']}'),
              _buildDetailSection('OPERATOR REMARKS', request['remarks'] ?? 'No remarks provided.'),
              _buildDetailSection('HISTORY', 'Created: ${request['createdAt']}'),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('CLOSE', style: TextStyle(color: Colors.grey)),
                    ),
                  ),
                  if (request['status'] == 'Pending' || request['status'] == 'Awaiting Review')
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _updateStatus(request['raw_id'], 'Rejected');
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                        child: const Text('REJECT REQUEST', style: TextStyle(color: Colors.white)),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(color: kGold.withOpacity(0.7), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
          const SizedBox(height: 8),
          Text(content, style: TextStyle(color: context.textColor, fontSize: 14, height: 1.5)),
        ],
      ),
    );
  }

  void _showProceedDialog(Map<String, dynamic> request) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Approve for Scheduling'),
        content: Text('Confirming ${request['id']} will move it to the Processing Schedule. Proceed?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () {
              Navigator.pop(context);
              _updateStatus(request['raw_id'], 'Approved');
            },
            child: const Text('Approve'),
          ),
        ],
      ),
    );
  }

  Widget _buildLogoMark() {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: kGold, width: 1.6), color: context.bgColor),
      child: const Icon(Icons.settings_input_component_rounded, color: kGold, size: 16),
    );
  }
}
