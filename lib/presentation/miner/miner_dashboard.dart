import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../shared_widgets/appColor.dart';
import '../shared_widgets/themeToggleButton.dart';
import '../shared_widgets/pin_dialog.dart';
import '../client/service_requests_page.dart';
import '../shared_widgets/emergency_alert_banner.dart';
import 'miner_drawer.dart';
import '../../infrastructure/repositories/supabase_user_repository.dart';
import '../../infrastructure/repositories/supabase_service_request_repository.dart';
import '../../application/services/service_request_service.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/entities/service_request_entity.dart';

class MinerDashboardPage extends StatefulWidget {
  const MinerDashboardPage({super.key, this.minerName = 'Miner'});

  final String minerName;

  @override
  State<MinerDashboardPage> createState() => _MinerDashboardPageState();
}

class _MinerDashboardPageState extends State<MinerDashboardPage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final SupabaseUserRepository _userRepository = SupabaseUserRepository();
  final SupabaseServiceRequestRepository _requestRepository =
      SupabaseServiceRequestRepository();
  late final ServiceRequestService _service;

  List<UserEntity> _otherMiners = [];
  List<ServiceRequestEntity> _allRequests = [];
  UserEntity? _currentUser;
  bool _isLoadingMiners = false;
  bool _hasActionRequired = false;

  final List<Map<String, dynamic>> _mockRequests = [
    {'ref': 'REQ-8A2F', 'material': 'Gold Ore', 'status': 'Pending', 'date': '2024-09-15', 'condition': 'Rocky', 'state': 'Dry', 'source': 'Associated Tunnel'},
  ];

  final List<Map<String, dynamic>> _mockActiveOps = [
    {'machine': 'Ball Mill A', 'drum': 'Drum #02', 'operator': 'Mike', 'status': 'Processing', 'progress': 0.65},
  ];

  final List<Map<String, dynamic>> _mockHistory = [
    {'material': 'Gold Ore', 'yield': '12.4g', 'date': '2024-09-10', 'status': 'Completed'},
  ];

  @override
  void initState() {
    super.initState();
    _service = ServiceRequestService(_requestRepository);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoadingMiners = true);
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    if (currentUserId == null) return;

    final userResult = await _userRepository.getUserById(currentUserId);
    userResult.fold((l) => null, (user) => _currentUser = user);

    final minersResult = await _userRepository.getMinersAndClients();
    final requestsResult = await _requestRepository.getServiceRequests();

    if (mounted) {
      setState(() {
        _otherMiners = minersResult.fold(
          (l) => [],
          (users) => users.where((u) => u.userId != currentUserId && u.roleId == 'miner').toList(),
        );
        
        _allRequests = requestsResult.fold((_) => [], (list) => list.where((r) => r.creatorId == currentUserId).toList());
        _hasActionRequired = _allRequests.any((r) => r.status == ServiceRequestStatus.returnedToMiner);
        _isLoadingMiners = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeCount = _allRequests.where((r) => 
      r.status == ServiceRequestStatus.processing || 
      r.status == ServiceRequestStatus.assigned ||
      r.status == ServiceRequestStatus.scheduled ||
      r.status == ServiceRequestStatus.verified
    ).length;

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
          'GAHIRA',
          style: TextStyle(color: kGold, fontWeight: FontWeight.bold, letterSpacing: 3, fontSize: 16),
        ),
        iconTheme: const IconThemeData(color: kGold),
        actions: [
          const ThemeToggleButton(),
          IconButton(
            icon: const Icon(Icons.menu_rounded, color: kGold),
            onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
          ),
        ],
      ),
      endDrawer: MinerDrawer(
        currentMenu: MinerMenu.dashboard,
        minerName: widget.minerName,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(context, MaterialPageRoute(builder: (context) => const ServiceRequestsPage()));
        },
        backgroundColor: kGold,
        foregroundColor: kBlack,
        child: const Icon(Icons.add_rounded),
      ),
      body: Column(
        children: [
          const EmergencyAlertBanner(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Welcome back,', style: TextStyle(color: context.mutedTextColor, fontSize: 14)),
                          Text(widget.minerName, style: TextStyle(color: context.textColor, fontSize: 24, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const Spacer(),
                      _buildAccountStatusBadge(),
                    ],
                  ),
                  const SizedBox(height: 32),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    childAspectRatio: 1.5,
                    children: [
                      _buildSummaryMetric('My Total Requests', _allRequests.length.toString(), Icons.description_outlined, kGold),
                      _buildSummaryMetric('Active Jobs', activeCount.toString(), Icons.settings_input_component_rounded, Colors.green),
                    ],
                  ),
                  const SizedBox(height: 32),
                  if (_hasActionRequired) ...[
                    _buildActionRequiredCard(),
                    const SizedBox(height: 32),
                  ],
                  Text('Quick Actions', style: TextStyle(color: context.textColor, fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(child: _buildQuickActionButton('New Request', Icons.add_circle_outline, () {
                        Navigator.push(context, MaterialPageRoute(builder: (context) => const ServiceRequestsPage()));
                      })),
                      const SizedBox(width: 12),
                      Expanded(child: _buildQuickActionButton('History', Icons.history_rounded, () {
                        Navigator.push(context, MaterialPageRoute(builder: (context) => const ServiceRequestsPage()));
                      })),
                    ],
                  ),
                  const SizedBox(height: 32),
                  _buildSectionHeader('Recent Requests', () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const ServiceRequestsPage()));
                  }),
                  const SizedBox(height: 12),
                  ..._mockRequests.map((r) => _buildRequestListItem(r)),
                  const SizedBox(height: 32),
                  Text('Active Operations', style: TextStyle(color: context.textColor, fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  if (_mockActiveOps.isEmpty)
                    _buildEmptyState('No active processing at the moment.')
                  else
                    ..._mockActiveOps.map((op) => _buildActiveOpCard(op)),
                  const SizedBox(height: 32),
                  _buildSectionHeader('Completion History', () {}),
                  const SizedBox(height: 12),
                  ..._mockHistory.map((h) => _buildHistoryListItem(h)),
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountStatusBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: kGold.withOpacity(0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: kGold.withOpacity(0.3))),
      child: const Row(
        children: [
          Icon(Icons.circle, color: Colors.green, size: 8),
          SizedBox(width: 8),
          Text('Account Active', style: TextStyle(color: kGold, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildSummaryMetric(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: context.surfaceColor, borderRadius: BorderRadius.circular(16), border: Border.all(color: kGold.withOpacity(0.1))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: color, size: 24),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: TextStyle(color: context.textColor, fontSize: 20, fontWeight: FontWeight.bold)),
              Text(title, style: TextStyle(color: context.mutedTextColor, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, VoidCallback onTap) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: TextStyle(color: context.textColor, fontSize: 18, fontWeight: FontWeight.bold)),
        TextButton(onPressed: onTap, child: const Text('View All', style: TextStyle(color: kGold))),
      ],
    );
  }

  Widget _buildRequestListItem(Map<String, dynamic> req) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: context.surfaceColor, borderRadius: BorderRadius.circular(12), border: Border.all(color: kGold.withOpacity(0.05))),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: kGold.withOpacity(0.1), shape: BoxShape.circle),
            child: const Icon(Icons.description_outlined, color: kGold, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(req['material'], style: TextStyle(color: context.textColor, fontWeight: FontWeight.w600)),
                Text('Ref: ${req['ref']} • ${req['date']}', style: TextStyle(color: context.mutedTextColor, fontSize: 11)),
              ],
            ),
          ),
          _buildStatusBadge(req['status']),
        ],
      ),
    );
  }

  Widget _buildActiveOpCard(Map<String, dynamic> op) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: context.surfaceColor, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.green.withOpacity(0.2))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.settings_input_component_rounded, color: Colors.green, size: 20),
              const SizedBox(width: 12),
              Text(op['machine'], style: TextStyle(color: context.textColor, fontWeight: FontWeight.bold)),
              const Spacer(),
              Text('${(op['progress'] * 100).toInt()}%', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 16),
          LinearProgressIndicator(value: op['progress'], backgroundColor: Colors.green.withOpacity(0.1), color: Colors.green, borderRadius: BorderRadius.circular(4)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Drum: ${op['drum']}', style: TextStyle(color: context.mutedTextColor, fontSize: 12)),
              Text('Op: ${op['operator']}', style: TextStyle(color: context.mutedTextColor, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryListItem(Map<String, dynamic> item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: context.surfaceColor, borderRadius: BorderRadius.circular(12), border: Border.all(color: context.textColor.withOpacity(0.05))),
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline_rounded, color: Colors.green, size: 20),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item['material'], style: TextStyle(color: context.textColor, fontWeight: FontWeight.w600)),
                Text('Date: ${item['date']}', style: TextStyle(color: context.mutedTextColor, fontSize: 11)),
              ],
            ),
          ),
          Text(item['yield'], style: const TextStyle(color: kGold, fontWeight: FontWeight.bold, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    final color = status == 'Approved' ? Colors.green : Colors.orange;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
      child: Text(status, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildEmptyState(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: context.surfaceColor, borderRadius: BorderRadius.circular(12)),
      child: Center(child: Text(message, style: TextStyle(color: context.mutedTextColor, fontSize: 13))),
    );
  }

  Widget _buildActionRequiredCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.red.withOpacity(0.3))),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.red),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Action Required', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                Text('One or more requests were returned for corrections.', style: TextStyle(color: context.textColor, fontSize: 12)),
              ],
            ),
          ),
          TextButton(onPressed: () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => const ServiceRequestsPage()));
          }, child: const Text('View', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }

  Widget _buildQuickActionButton(String label, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(color: context.surfaceColor, borderRadius: BorderRadius.circular(12), border: Border.all(color: kGold.withOpacity(0.1))),
        child: Column(
          children: [
            Icon(icon, color: kGold, size: 28),
            const SizedBox(height: 8),
            Text(label, style: TextStyle(color: context.textColor, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  Widget _buildLogoMark() {
    return Container(
      width: 34, height: 34,
      decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: kGold, width: 1.6), color: context.bgColor),
      child: const Icon(Icons.settings_input_component_rounded, color: kGold, size: 16),
    );
  }
}
