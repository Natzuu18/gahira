import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../shared_widgets/appColor.dart';
import '../shared_widgets/themeToggleButton.dart';
import '../client/service_requests_page.dart';
import '../shared_widgets/emergency_alert_banner.dart';
import 'miner_drawer.dart';
import '../../infrastructure/repositories/supabase_service_request_repository.dart';
import '../../domain/entities/service_request_entity.dart';

class MinerDashboardPage extends StatefulWidget {
  const MinerDashboardPage({super.key, this.minerName = 'Miner'});

  final String minerName;

  @override
  State<MinerDashboardPage> createState() => _MinerDashboardPageState();
}

class _MinerDashboardPageState extends State<MinerDashboardPage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final SupabaseServiceRequestRepository _requestRepository =
      SupabaseServiceRequestRepository();

  List<ServiceRequestEntity> _allRequests = [];
  bool _isLoadingMiners = false;
  bool _hasActionRequired = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoadingMiners = true);
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    if (currentUserId == null) {
      if (mounted) setState(() => _isLoadingMiners = false);
      return;
    }

    final requestsResult = await _requestRepository.getServiceRequests();

    if (mounted) {
      setState(() {
        _allRequests = requestsResult.fold(
          (_) => [],
          (list) => list.where((r) => r.creatorId == currentUserId).toList(),
        );
        _hasActionRequired = _allRequests.any(
          (r) => r.status == ServiceRequestStatus.returnedToMiner,
        );
        _isLoadingMiners = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeCount = _allRequests
        .where(
          (r) =>
              r.status == ServiceRequestStatus.processing ||
              r.status == ServiceRequestStatus.assigned ||
              r.status == ServiceRequestStatus.scheduled ||
              r.status == ServiceRequestStatus.verified,
        )
        .length;
    final recentRequests = List<ServiceRequestEntity>.from(_allRequests)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final completedRequests = recentRequests
        .where((request) => request.status == ServiceRequestStatus.completed)
        .toList();

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
          style: TextStyle(
            color: kGold,
            fontWeight: FontWeight.bold,
            letterSpacing: 3,
            fontSize: 16,
          ),
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
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const ServiceRequestsPage(),
            ),
          );
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
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1120),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 24,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Welcome back,',
                                  style: TextStyle(
                                    color: context.mutedTextColor,
                                    fontSize: 14,
                                  ),
                                ),
                                Text(
                                  widget.minerName,
                                  style: TextStyle(
                                    color: context.textColor,
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            _buildAccountStatusBadge(),
                          ],
                        ),
                        const SizedBox(height: 32),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final columns = constraints.maxWidth >= 900
                                ? 4
                                : constraints.maxWidth >= 600
                                ? 3
                                : 2;
                            return GridView.count(
                              crossAxisCount: columns,
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              mainAxisSpacing: 12,
                              crossAxisSpacing: 12,
                              childAspectRatio: constraints.maxWidth < 360
                                  ? 1.25
                                  : 1.5,
                              children: [
                                _buildSummaryMetric(
                                  'My Total Requests',
                                  _allRequests.length.toString(),
                                  Icons.description_outlined,
                                  kGold,
                                ),
                                _buildSummaryMetric(
                                  'Active Jobs',
                                  activeCount.toString(),
                                  Icons.settings_input_component_rounded,
                                  Colors.green,
                                ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 32),
                        if (_hasActionRequired) ...[
                          _buildActionRequiredCard(),
                          const SizedBox(height: 32),
                        ],
                        Text(
                          'Quick Actions',
                          style: TextStyle(
                            color: context.textColor,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final actions = [
                              _buildQuickActionButton(
                                'New Request',
                                Icons.add_circle_outline,
                                () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const ServiceRequestsPage(),
                                    ),
                                  );
                                },
                              ),
                              _buildQuickActionButton(
                                'History',
                                Icons.history_rounded,
                                () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const ServiceRequestsPage(),
                                    ),
                                  );
                                },
                              ),
                            ];
                            if (constraints.maxWidth >= 600) {
                              return Row(
                                children: [
                                  Expanded(child: actions[0]),
                                  const SizedBox(width: 12),
                                  Expanded(child: actions[1]),
                                ],
                              );
                            }
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                actions[0],
                                const SizedBox(height: 12),
                                actions[1],
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 32),
                        _buildSectionHeader('Recent Requests', () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ServiceRequestsPage(),
                            ),
                          );
                        }),
                        const SizedBox(height: 12),
                        if (_isLoadingMiners)
                          const Center(
                            child: CircularProgressIndicator(color: kGold),
                          )
                        else if (recentRequests.isEmpty)
                          _buildEmptyState(
                            'No service requests yet. Create one to get started.',
                          )
                        else
                          ...recentRequests.take(3).map(_buildRequestListItem),
                        const SizedBox(height: 32),
                        Text(
                          'Active Operations',
                          style: TextStyle(
                            color: context.textColor,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildEmptyState(
                          activeCount == 0
                              ? 'No active processing at the moment.'
                              : '$activeCount ${activeCount == 1 ? 'request is' : 'requests are'} in progress. Open Service Requests to see the latest status.',
                        ),
                        const SizedBox(height: 32),
                        _buildSectionHeader('Completion History', () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ServiceRequestsPage(),
                            ),
                          );
                        }),
                        const SizedBox(height: 12),
                        if (completedRequests.isEmpty)
                          _buildEmptyState(
                            'Completed requests will appear here.',
                          )
                        else
                          ...completedRequests
                              .take(3)
                              .map(_buildHistoryListItem),
                        const SizedBox(height: 80),
                      ],
                    ),
                  ),
                ),
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
      decoration: BoxDecoration(
        color: kGold.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kGold.withOpacity(0.3)),
      ),
      child: const Row(
        children: [
          Icon(Icons.circle, color: Colors.green, size: 8),
          SizedBox(width: 8),
          Text(
            'Account Active',
            style: TextStyle(
              color: kGold,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryMetric(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kGold.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: color, size: 24),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  color: context.textColor,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                title,
                style: TextStyle(color: context.mutedTextColor, fontSize: 12),
              ),
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
        Text(
          title,
          style: TextStyle(
            color: context.textColor,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        TextButton(
          onPressed: onTap,
          child: const Text('View All', style: TextStyle(color: kGold)),
        ),
      ],
    );
  }

  Widget _buildRequestListItem(ServiceRequestEntity request) {
    final String reference = request.id.length > 8
        ? request.id.substring(0, 8).toUpperCase()
        : request.id.toUpperCase();
    final String material =
        request.materialDetails.sourceType ?? 'Service request';
    final String date = MaterialLocalizations.of(
      context,
    ).formatShortDate(request.createdAt);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kGold.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: kGold.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.description_outlined,
              color: kGold,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  material,
                  style: TextStyle(
                    color: context.textColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'Ref: $reference • $date',
                  style: TextStyle(color: context.mutedTextColor, fontSize: 11),
                ),
              ],
            ),
          ),
          _buildStatusBadge(_statusLabel(request.status)),
        ],
      ),
    );
  }

  Widget _buildHistoryListItem(ServiceRequestEntity request) {
    final String material =
        request.materialDetails.sourceType ?? 'Service request';
    final String date = MaterialLocalizations.of(
      context,
    ).formatShortDate(request.updatedAt);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.textColor.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.check_circle_outline_rounded,
            color: Colors.green,
            size: 20,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  material,
                  style: TextStyle(
                    color: context.textColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'Completed $date',
                  style: TextStyle(color: context.mutedTextColor, fontSize: 11),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.check_circle_outline_rounded,
            color: kGold,
            size: 20,
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    final color = status == 'Approved' ? Colors.green : Colors.orange;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  String _statusLabel(ServiceRequestStatus status) {
    switch (status) {
      case ServiceRequestStatus.pendingOperatorVerification:
        return 'Awaiting verification';
      case ServiceRequestStatus.returnedToMiner:
        return 'Needs attention';
      case ServiceRequestStatus.processingCompleted:
        return 'Processing complete';
      case ServiceRequestStatus.emergencyStop:
        return 'Paused';
      default:
        return status.name
            .replaceAllMapped(
              RegExp(r'([A-Z])'),
              (match) => ' ${match.group(0)!.toLowerCase()}',
            )
            .trim();
    }
  }

  Widget _buildEmptyState(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Text(
          message,
          style: TextStyle(color: context.mutedTextColor, fontSize: 13),
        ),
      ),
    );
  }

  Widget _buildActionRequiredCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.red),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Action Required',
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'One or more requests were returned for corrections.',
                  style: TextStyle(color: context.textColor, fontSize: 12),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ServiceRequestsPage(),
                ),
              );
            },
            child: const Text(
              'View',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionButton(
    String label,
    IconData icon,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: context.surfaceColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kGold.withOpacity(0.1)),
        ),
        child: Column(
          children: [
            Icon(icon, color: kGold, size: 28),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: context.textColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogoMark() {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: kGold, width: 1.6),
        color: context.bgColor,
      ),
      child: const Icon(
        Icons.settings_input_component_rounded,
        color: kGold,
        size: 16,
      ),
    );
  }
}
