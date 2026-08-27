import 'package:flutter/material.dart';

import '../shared_widgets/appColor.dart';
import '../shared_widgets/themeToggleButton.dart';
import 'client_drawer.dart';

// Gahira Ball Mill Management System - Processing Status Page
// Clients can track the progress of their processing jobs through workflow stages

class ProcessingStatusPage extends StatefulWidget {
  const ProcessingStatusPage({super.key});

  @override
  State<ProcessingStatusPage> createState() => _ProcessingStatusPageState();
}

class _ProcessingStatusPageState extends State<ProcessingStatusPage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  final List<Map<String, dynamic>> _mockJobs = [
    {
      'id': 'JOB-2024-008',
      'requestId': 'REQ-2024-015',
      'title': 'Gold Ore Processing',
      'currentStage': 3, // 0-5: Submitted, Verified, Scheduled, Processing, Quality Check, Completed
      'drum': 'Drum #03',
      'batch': 'BATCH-2024-015',
      'startDate': '2024-01-15',
      'estimatedCompletion': '2024-01-17',
    },
    {
      'id': 'JOB-2024-007',
      'requestId': 'REQ-2024-014',
      'title': 'Silver Refining',
      'currentStage': 2,
      'drum': 'Drum #01',
      'batch': 'BATCH-2024-014',
      'startDate': '2024-01-16',
      'estimatedCompletion': '2024-01-19',
    },
    {
      'id': 'JOB-2024-006',
      'requestId': 'REQ-2024-012',
      'title': 'Gold Ore Processing',
      'currentStage': 5,
      'drum': 'Drum #02',
      'batch': 'BATCH-2024-012',
      'startDate': '2024-01-10',
      'estimatedCompletion': '2024-01-12',
      'actualCompletion': '2024-01-12',
    },
  ];

  final List<String> _workflowStages = [
    'Submitted',
    'Verified',
    'Scheduled',
    'Processing',
    'Quality Check',
    'Completed',
  ];

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
            tooltip: 'Menu',
            onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
          ),
        ],
      ),
      endDrawer: const ClientDrawer(
        currentMenu: ClientMenu.processingStatus,
        clientName: 'Client',
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Text(
              'Processing Status',
              style: TextStyle(
                color: context.textColor,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Track the progress of your processing jobs',
              style: TextStyle(
                color: context.mutedTextColor,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),

            // Active Jobs Section
            Text(
              'Active Jobs',
              style: TextStyle(
                color: context.textColor,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ..._mockJobs.where((j) => j['currentStage'] < 5).map((job) => _buildJobCard(job)),
            
            const SizedBox(height: 32),

            // Completed Jobs Section
            Text(
              'Completed Jobs',
              style: TextStyle(
                color: context.textColor,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ..._mockJobs.where((j) => j['currentStage'] == 5).map((job) => _buildJobCard(job)),
          ],
        ),
      ),
    );
  }

  Widget _buildJobCard(Map<String, dynamic> job) {
    final int currentStage = job['currentStage'];
    final bool isCompleted = currentStage == 5;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kGold.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isCompleted 
                      ? Colors.green.withOpacity(0.1)
                      : kGold.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.settings_input_component_rounded,
                  color: isCompleted ? Colors.green : kGold,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      job['title'],
                      style: TextStyle(
                        color: context.textColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      '${job['id']} • ${job['requestId']}',
                      style: TextStyle(
                        color: context.mutedTextColor,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (isCompleted)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle, color: Colors.green, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        'Completed',
                        style: TextStyle(
                          color: Colors.green,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(height: 1),
          const SizedBox(height: 20),
          
          // Job Details
          Row(
            children: [
              _buildDetailItem('Drum', job['drum']),
              const SizedBox(width: 24),
              _buildDetailItem('Batch', job['batch']),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.calendar_today_outlined,
                  color: context.mutedTextColor, size: 14),
              const SizedBox(width: 4),
              Text(
                'Started: ${job['startDate']}',
                style: TextStyle(
                  color: context.mutedTextColor,
                  fontSize: 12,
                ),
              ),
              const SizedBox(width: 24),
              Icon(Icons.access_time_outlined,
                  color: context.mutedTextColor, size: 14),
              const SizedBox(width: 4),
              Text(
                isCompleted 
                    ? 'Completed: ${job['actualCompletion']}'
                    : 'Est. Completion: ${job['estimatedCompletion']}',
                style: TextStyle(
                  color: context.mutedTextColor,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Workflow Progress
          Text(
            'Workflow Progress',
            style: TextStyle(
              color: context.textColor,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          _buildWorkflowProgress(currentStage),
        ],
      ),
    );
  }

  Widget _buildDetailItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(color: context.mutedTextColor, fontSize: 10),
        ),
        Text(
          value,
          style: TextStyle(
            color: context.textColor,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildWorkflowProgress(int currentStage) {
    return Column(
      children: List.generate(_workflowStages.length, (index) {
        final bool isCompleted = index < currentStage;
        final bool isCurrent = index == currentStage;
        final bool isPending = index > currentStage;

        return Column(
          children: [
            Row(
              children: [
                _buildStageIndicator(isCompleted, isCurrent, isPending),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    _workflowStages[index],
                    style: TextStyle(
                      color: isCompleted 
                          ? Colors.green
                          : (isCurrent ? kGold : context.mutedTextColor),
                      fontSize: 13,
                      fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ),
              ],
            ),
            if (index < _workflowStages.length - 1)
              Padding(
                padding: const EdgeInsets.only(left: 11),
                child: Container(
                  height: 24,
                  width: 2,
                  color: isCompleted 
                      ? Colors.green.withOpacity(0.5)
                      : kGold.withOpacity(0.2),
                ),
              ),
          ],
        );
      }),
    );
  }

  Widget _buildStageIndicator(bool isCompleted, bool isCurrent, bool isPending) {
    Color color;
    if (isCompleted) {
      color = Colors.green;
    } else if (isCurrent) {
      color = kGold;
    } else {
      color = kGold.withOpacity(0.3);
    }

    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        border: Border.all(color: color, width: 2),
      ),
      child: isCompleted
          ? const Icon(Icons.check, color: Colors.white, size: 14)
          : isCurrent
              ? Container(
                  margin: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: context.surfaceColor,
                  ),
                )
              : null,
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
