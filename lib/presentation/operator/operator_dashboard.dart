import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dartz/dartz.dart' hide State;

import '../../core/error/failures.dart';
import '../shared_widgets/appColor.dart';
import '../shared_widgets/themeToggleButton.dart';
import 'operator_drawer.dart';
import 'processing_workflow_page.dart';
import '../../infrastructure/repositories/supabase_user_repository.dart';
import '../../infrastructure/repositories/supabase_service_request_repository.dart';
import '../../domain/entities/service_request_entity.dart';
import '../../infrastructure/models/service_request_model.dart';
import '../../infrastructure/supabase/supabase_config.dart';

import 'service_verification_page.dart';

class OperatorDashboardPage extends StatefulWidget {
  const OperatorDashboardPage({super.key, this.operatorName = 'Operator'});

  final String operatorName;

  @override
  State<OperatorDashboardPage> createState() => _OperatorDashboardPageState();
}

class _OperatorDashboardPageState extends State<OperatorDashboardPage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final SupabaseUserRepository _userRepository = SupabaseUserRepository();
  final SupabaseServiceRequestRepository _requestRepository =
      SupabaseServiceRequestRepository();

  bool _isAvailable = true; // Simulating "Operator Becomes Available"

  // Mock data for dashboard visuals
  final List<Map<String, dynamic>> _millStatus = [
    {
      'name': 'Mill #01 - Primary',
      'status': 'Running',
      'rpm': 45.2,
      'load': 0.85
    },
    {
      'name': 'Mill #02 - Secondary',
      'status': 'Running',
      'rpm': 42.8,
      'load': 0.78
    },
    {'name': 'Mill #03 - Tertiary', 'status': 'Stopped', 'rpm': 0.0, 'load': 0.0},
    {
      'name': 'Mill #04 - Auxiliary',
      'status': 'Maintenance',
      'rpm': 12.5,
      'load': 0.30
    },
  ];

  final List<Map<String, dynamic>> _activeJobs = [
    {
      'id': 'JOB-001',
      'client': 'ABC Mining',
      'stage': 'Grinding',
      'progress': 0.65
    },
    {'id': 'JOB-002', 'client': 'Gold Corp', 'stage': 'Crushing', 'progress': 0.30},
    {
      'id': 'JOB-003',
      'client': 'Silver Ltd',
      'stage': 'Processing',
      'progress': 0.85
    },
  ];

  final List<Map<String, dynamic>> _activityLog = [
    {'message': 'Job JOB-001 moved to Grinding stage', 'time': '10 min ago'},
    {'message': 'Mill #02 maintenance completed', 'time': '1 hour ago'},
    {'message': 'Shift change: Morning to Afternoon', 'time': '2 hours ago'},
    {'message': 'New material delivery received', 'time': '3 hours ago'},
  ];

  @override
  void initState() {
    super.initState();
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
          child: _buildLogoMark(context),
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
      endDrawer: OperatorDrawer(
        currentMenu: OperatorMenu.dashboard,
        operatorName: widget.operatorName,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Availability Toggle & Welcome
            Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Welcome back,', style: TextStyle(color: context.mutedTextColor, fontSize: 14)),
                    Text(widget.operatorName, style: TextStyle(color: context.textColor, fontSize: 24, fontWeight: FontWeight.bold)),
                  ],
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => setState(() => _isAvailable = !_isAvailable),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _isAvailable ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _isAvailable ? Colors.green : Colors.red),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.circle, color: _isAvailable ? Colors.green : Colors.red, size: 8),
                        const SizedBox(width: 8),
                        Text(
                          _isAvailable ? 'AVAILABLE' : 'BUSY',
                          style: TextStyle(color: _isAvailable ? Colors.green : Colors.red, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // Quick Actions
            Text('Quick Actions', style: TextStyle(color: context.textColor, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildQuickActionButton(
                    context,
                    'Service Verification',
                    Icons.fact_check_outlined,
                    () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ServiceVerificationPage())),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildQuickActionButton(
                    context,
                    'Workflow',
                    Icons.settings_input_component_rounded,
                    () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ProcessingWorkflowPage())),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // Pending Verification Preview
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Recent Requests', style: TextStyle(color: context.textColor, fontSize: 18, fontWeight: FontWeight.bold)),
                TextButton(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ServiceVerificationPage())),
                  child: const Text('View All', style: TextStyle(color: kGold)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            FutureBuilder<Either<Failure, List<ServiceRequestModel>>>(
              future: _requestRepository.getServiceRequests(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: kGold));
                final list = snapshot.data?.fold((l) => [], (r) => r) ?? [];
                if (list.isEmpty) return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(color: context.surfaceColor, borderRadius: BorderRadius.circular(12)),
                  child: const Center(child: Text('No recent requests', style: TextStyle(color: Colors.grey))),
                );
                
                return Column(
                  children: list.take(3).map((r) => Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(color: context.surfaceColor, borderRadius: BorderRadius.circular(12)),
                    child: ListTile(
                      title: Text('Ref: ${r.id.substring(0,8).toUpperCase()}', style: TextStyle(color: context.textColor, fontWeight: FontWeight.bold, fontSize: 14)),
                      subtitle: Text('${r.materialDetails.numberOfSacks} Sacks • ${r.status.name}', style: const TextStyle(fontSize: 12)),
                      trailing: const Icon(Icons.chevron_right, color: kGold),
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ServiceVerificationPage())),
                    ),
                  )).toList(),
                );
              }
            ),
            const SizedBox(height: 32),

            // Active Metrics
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 1.5,
              children: [
                _buildMetricCard(context, 'Total Mills', '12', Icons.settings_input_component_rounded, kGold),
                _buildMetricCard(context, 'My Active Jobs', '02', Icons.play_circle_outline_rounded, Colors.green),
                _buildMetricCard(context, 'Maintenance', '01', Icons.build_circle_outlined, Colors.orange),
                _buildMetricCard(context, 'Avg Efficiency', '96%', Icons.bar_chart_rounded, Colors.blue),
              ],
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard(BuildContext context, String title, String value, IconData icon, Color color) {
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
              Text(value, style: TextStyle(color: context.textColor, fontSize: 20, fontWeight: FontWeight.bold)),
              Text(title, style: TextStyle(color: context.mutedTextColor, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionButton(BuildContext context, String label, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
        decoration: BoxDecoration(
          color: context.surfaceColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kGold.withOpacity(0.1)),
        ),
        child: Column(
          children: [
            Icon(icon, color: kGold, size: 28),
            const SizedBox(height: 8),
            Text(label, textAlign: TextAlign.center, style: TextStyle(color: context.textColor, fontWeight: FontWeight.w500, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Widget _buildLogoMark(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: kGold, width: 1.6),
        color: context.bgColor,
      ),
      child: const Icon(Icons.settings_input_component_rounded, color: kGold, size: 16),
    );
  }
}
