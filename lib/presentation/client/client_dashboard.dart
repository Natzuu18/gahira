import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../shared_widgets/appColor.dart';
import '../shared_widgets/themeToggleButton.dart';
import '../../domain/entities/service_request_entity.dart';
import '../../infrastructure/repositories/supabase_service_request_repository.dart';
import 'client_drawer.dart';
import 'service_requests_page.dart';

// Gahira Ball Mill Management System - Client Dashboard
// Main dashboard for clients to view their service requests, processing status, and billing

class ClientDashboardPage extends StatefulWidget {
  const ClientDashboardPage({super.key, this.clientName = 'Client'});

  final String clientName;

  @override
  State<ClientDashboardPage> createState() => _ClientDashboardPageState();
}

class _ClientDashboardPageState extends State<ClientDashboardPage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final SupabaseServiceRequestRepository _requestRepository =
      SupabaseServiceRequestRepository();
  List<ServiceRequestEntity> _requests = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    final result = await _requestRepository.getServiceRequests();
    if (!mounted) return;
    setState(() {
      _requests = result.fold(
        (_) => <ServiceRequestEntity>[],
        (requests) =>
            requests
                .where(
                  (request) =>
                      request.creatorId == userId ||
                      request.participatingMinerIds.contains(userId),
                )
                .toList()
              ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt)),
      );
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
        leadingWidth: 64,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16),
          child: _buildLogoMark(),
        ),
        title: const Text(
          'EGReS',
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
            tooltip: 'Menu',
            onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
          ),
        ],
      ),
      endDrawer: ClientDrawer(
        currentMenu: ClientMenu.dashboard,
        clientName: widget.clientName,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const ServiceRequestsPage(),
            ),
          ).then((_) {
            // Ideally refresh stats here
          });
        },
        backgroundColor: kGold,
        foregroundColor: kBlack,
        child: const Icon(Icons.add_rounded),
      ),
      body: SingleChildScrollView(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1120),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Welcome section
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
                            widget.clientName,
                            style: TextStyle(
                              color: context.textColor,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: kGold.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: kGold.withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.circle,
                              color: Colors.green,
                              size: 8,
                            ),
                            const SizedBox(width: 8),
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
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // Metrics Summary Cards
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
                          _buildMetricCard(
                            'My Requests',
                            _isLoading ? '...' : '${_requests.length}',
                            Icons.description_outlined,
                            kGold,
                          ),
                          _buildMetricCard(
                            'In Progress',
                            _isLoading
                                ? '...'
                                : '${_requests.where((request) => request.status == ServiceRequestStatus.processing || request.status == ServiceRequestStatus.assigned || request.status == ServiceRequestStatus.scheduled).length}',
                            Icons.settings_input_component_rounded,
                            Colors.blue,
                          ),
                          _buildMetricCard(
                            'Needs Attention',
                            _isLoading
                                ? '...'
                                : '${_requests.where((request) => request.status == ServiceRequestStatus.returnedToMiner).length}',
                            Icons.priority_high_rounded,
                            Colors.orange,
                          ),
                          _buildMetricCard(
                            'Completed',
                            _isLoading
                                ? '...'
                                : '${_requests.where((request) => request.status == ServiceRequestStatus.completed).length}',
                            Icons.task_alt_rounded,
                            Colors.green,
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 32),

                  // Quick Actions
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
                          'View Status',
                          Icons.visibility_outlined,
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

                  // Recent Service Requests
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        'Recent Service Requests',
                        style: TextStyle(
                          color: context.textColor,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextButton(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ServiceRequestsPage(),
                          ),
                        ),
                        child: const Text(
                          'View All',
                          style: TextStyle(color: kGold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_isLoading)
                    const Center(child: CircularProgressIndicator(color: kGold))
                  else if (_requests.isEmpty)
                    _buildEmptyState('Your service requests will appear here.')
                  else
                    ..._requests.take(3).map(_buildServiceRequestItem),

                  const SizedBox(height: 32),

                  // Recent Activity
                  Text(
                    'Recent Activity',
                    style: TextStyle(
                      color: context.textColor,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_requests.isEmpty && !_isLoading)
                    _buildEmptyState(
                      'Updates will appear here as your requests progress.',
                    )
                  else
                    ..._requests.take(3).map(_buildRequestActivity),
                  const SizedBox(height: 80), // Space for FAB
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMetricCard(
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

  Widget _buildQuickActionButton(
    String label,
    IconData icon,
    VoidCallback onPressed,
  ) {
    return Container(
      height: 80,
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kGold.withOpacity(0.1)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: kGold, size: 28),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  color: context.textColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildServiceRequestItem(ServiceRequestEntity request) {
    final String title =
        request.materialDetails.sourceType ?? 'Service request';
    final String status = _statusLabel(request.status);
    final String date = MaterialLocalizations.of(
      context,
    ).formatShortDate(request.createdAt);
    final Color statusColor = request.status == ServiceRequestStatus.completed
        ? Colors.green
        : (request.status == ServiceRequestStatus.processing
              ? Colors.blue
              : Colors.orange);

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
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.description_outlined,
              color: statusColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: context.textColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'Date: $date',
                  style: TextStyle(color: context.mutedTextColor, fontSize: 12),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              status,
              style: TextStyle(
                color: statusColor,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestActivity(ServiceRequestEntity request) {
    final reference = request.id.length > 8
        ? request.id.substring(0, 8).toUpperCase()
        : request.id.toUpperCase();
    return _buildActivityLog(
      'Request $reference: ${_statusLabel(request.status)}',
      MaterialLocalizations.of(context).formatShortDate(request.updatedAt),
    );
  }

  Widget _buildEmptyState(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Text(message, style: TextStyle(color: context.mutedTextColor)),
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
      default:
        return status.name
            .replaceAllMapped(
              RegExp(r'([A-Z])'),
              (match) => ' ${match.group(0)!.toLowerCase()}',
            )
            .trim();
    }
  }

  Widget _buildActivityLog(String message, String time) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 4),
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: kGold,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message,
                  style: TextStyle(color: context.textColor, fontSize: 14),
                ),
                Text(
                  time,
                  style: TextStyle(color: context.mutedTextColor, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogoMark() {    return Image.asset(
      'assets/img/EGReS.png',
      width: 34,
      height: 34,
      fit: BoxFit.contain,
    );
  }
}
