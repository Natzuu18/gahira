import 'package:flutter/material.dart';
import 'package:dartz/dartz.dart' hide State;

import '../../core/error/failures.dart';
import '../../domain/entities/service_request_entity.dart';
import '../shared_widgets/appColor.dart';
import '../shared_widgets/themeToggleButton.dart';
import '../shared_widgets/notification_bell_button.dart';
import 'operator_menu.dart';
import 'workforce_shift_page.dart';
import '../../infrastructure/repositories/supabase_service_request_repository.dart';
import '../../infrastructure/models/service_request_model.dart';

import 'service_verification_page.dart';

class OperatorDashboardPage extends StatefulWidget {
  const OperatorDashboardPage({
    super.key,
    this.operatorName = 'Operator',
    this.onNavigate,
  });

  final String operatorName;
  final ValueChanged<OperatorMenu>? onNavigate;

  @override
  State<OperatorDashboardPage> createState() => _OperatorDashboardPageState();
}

class _OperatorDashboardPageState extends State<OperatorDashboardPage> {
  final SupabaseServiceRequestRepository _requestRepository =
      SupabaseServiceRequestRepository();
  late Future<Either<Failure, List<ServiceRequestModel>>> _requestsFuture;

  @override
  void initState() {
    super.initState();
    _requestsFuture = _requestRepository.getServiceRequests();
  }

  void _refreshRequests() {
    setState(() {
      _requestsFuture = _requestRepository.getServiceRequests();
    });
  }

  void _openPage(Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  void _openMenu(OperatorMenu menu, Widget fallbackPage) {
    final onNavigate = widget.onNavigate;
    if (onNavigate != null) {
      onNavigate(menu);
    } else {
      _openPage(fallbackPage);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bgColor,
      appBar: AppBar(
        backgroundColor: context.surfaceColor,
        elevation: 0,
        leadingWidth: 64,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16),
          child: _buildLogoMark(context),
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
          const NotificationBellButton(),
          const ThemeToggleButton(),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: kGold),
            tooltip: 'Refresh dashboard',
            onPressed: _refreshRequests,
          ),
        ],
      ),
      body: FutureBuilder<Either<Failure, List<ServiceRequestModel>>>(
        future: _requestsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: kGold));
          }
          if (snapshot.hasError) {
            return _buildErrorState(snapshot.error.toString());
          }
          final result = snapshot.data;
          if (result == null) {
            return _buildErrorState('The dashboard could not load requests.');
          }
          return result.fold(
            (failure) => _buildErrorState(failure.message),
            _buildDashboardContent,
          );
        },
      ),
    );
  }

  Widget _buildDashboardContent(List<ServiceRequestModel> requests) {
    final pendingCount = requests
        .where(
          (request) =>
              request.status ==
              ServiceRequestStatus.pendingOperatorVerification,
        )
        .length;
    final queueCount = requests
        .where(
          (request) =>
              request.status == ServiceRequestStatus.queued ||
              request.status == ServiceRequestStatus.scheduled,
        )
        .length;
    final processingCount = requests
        .where((request) => request.status == ServiceRequestStatus.processing)
        .length;
    final emergencyCount = requests
        .where(
          (request) => request.status == ServiceRequestStatus.emergencyStop,
        )
        .length;
    final recentRequests = [...requests]
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    return RefreshIndicator(
      color: kGold,
      onRefresh: () async {
        final future = _requestRepository.getServiceRequests();
        setState(() => _requestsFuture = future);
        await future;
      },
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1120),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
            children: [
              _buildWelcomeCard(),
              const SizedBox(height: 20),
              _buildSectionHeading(
                'Today at a glance',
                'Live request overview',
              ),
              const SizedBox(height: 10),
              LayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.maxWidth >= 760 ? 4 : 2;
                  return GridView.count(
                    crossAxisCount: columns,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: columns == 4 ? 1.65 : 1.7,
                    children: [
                      _buildMetricCard(
                        'Needs verification',
                        pendingCount,
                        Icons.fact_check_outlined,
                        kGold,
                      ),
                      _buildMetricCard(
                        'In queue',
                        queueCount,
                        Icons.pending_actions_rounded,
                        Colors.blue,
                      ),
                      _buildMetricCard(
                        'Processing',
                        processingCount,
                        Icons.settings_input_component_rounded,
                        Colors.green,
                      ),
                      _buildMetricCard(
                        'Needs attention',
                        emergencyCount,
                        Icons.warning_amber_rounded,
                        Colors.red,
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 22),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: _buildSectionHeading(
                      'Recent service requests',
                      'Sorted by most recently updated',
                    ),
                  ),
                  TextButton(
                    onPressed: () => _openMenu(
                      OperatorMenu.serviceVerification,
                      const ServiceVerificationPage(),
                    ),
                    child: const Text('View all'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (recentRequests.isEmpty)
                _buildEmptyState('No service requests have been submitted yet.')
              else
                ...recentRequests.take(5).map(_buildRecentRequestCard),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [kGold.withValues(alpha: 0.2), context.surfaceColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kGold.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'OPERATOR WORKSPACE',
                  style: TextStyle(
                    color: kGold.withValues(alpha: 0.9),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.4,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Welcome back, ${widget.operatorName}',
                  style: TextStyle(
                    color: context.textColor,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: kGold.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.engineering_rounded,
              color: kGold,
              size: 30,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeading(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: context.textColor,
            fontSize: 17,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: TextStyle(color: context.mutedTextColor, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildMetricCard(String label, int value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 19),
              const Spacer(),
              Text(
                value.toString(),
                style: TextStyle(
                  color: context.textColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 24,
                ),
              ),
            ],
          ),
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: context.mutedTextColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentRequestCard(ServiceRequestModel request) {
    final status = _statusLabel(request.status);
    final isPending =
        request.status == ServiceRequestStatus.pendingOperatorVerification;
    final isEmergency = request.status == ServiceRequestStatus.emergencyStop;
    final statusColor = isEmergency
        ? Colors.red
        : isPending
        ? kGold
        : request.status == ServiceRequestStatus.processing
        ? Colors.green
        : Colors.blue;
    final sacks = request.materialDetails.numberOfSacks ?? 0;
    final reference = request.serviceReference;

    return Card(
      color: context.surfaceColor,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: context.textColor.withValues(alpha: 0.05)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: CircleAvatar(
          backgroundColor: statusColor.withValues(alpha: 0.12),
          child: Icon(
            isEmergency
                ? Icons.warning_amber_rounded
                : isPending
                ? Icons.fact_check_outlined
                : Icons.inventory_2_outlined,
            color: statusColor,
            size: 20,
          ),
        ),
        title: Text(
          request.creatorName?.isNotEmpty == true
              ? request.creatorName!
              : 'Miner request',
          style: TextStyle(
            color: context.textColor,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 3),
          child: Text(
            '$reference  •  $sacks ${sacks == 1 ? 'sack' : 'sacks'}  •  ${request.materialDetails.sourceType ?? 'Material service'}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: context.mutedTextColor, fontSize: 11),
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                status,
                style: TextStyle(
                  color: statusColor,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, color: context.mutedTextColor, size: 20),
          ],
        ),
        onTap: () => _openMenu(
          OperatorMenu.serviceVerification,
          const ServiceVerificationPage(),
        ),
      ),
    );
  }

  String _statusLabel(ServiceRequestStatus status) {
    final words = status.name.replaceAllMapped(
      RegExp(r'([a-z])([A-Z])'),
      (match) => '${match[1]} ${match[2]}',
    );
    return words[0].toUpperCase() + words.substring(1);
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, color: Colors.orange, size: 40),
            const SizedBox(height: 10),
            Text(
              'Dashboard data is unavailable',
              style: TextStyle(
                color: context.textColor,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: context.mutedTextColor, fontSize: 12),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _refreshRequests,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kGold.withValues(alpha: 0.12)),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: TextStyle(color: context.mutedTextColor, fontSize: 13),
      ),
    );
  }

  Widget _buildLogoMark(BuildContext context) {    return Image.asset(
      'assets/img/EGReS.png',
      width: 34,
      height: 34,
      fit: BoxFit.contain,
    );
  }
}
