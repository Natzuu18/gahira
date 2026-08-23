import 'package:flutter/material.dart';

import '../shared_widgets/appColor.dart';
import '../shared_widgets/themeToggleButton.dart';
import 'operator_drawer.dart';

class ProcessingWorkflowPage extends StatefulWidget {
  const ProcessingWorkflowPage({super.key});

  @override
  State<ProcessingWorkflowPage> createState() => _ProcessingWorkflowPageState();
}

class _ProcessingWorkflowPageState extends State<ProcessingWorkflowPage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // Mock data
  final List<Map<String, dynamic>> _jobs = [
    {
      'id': 'JOB-001',
      'client': 'ABC Mining Corp',
      'batchId': 'BATCH-2024-001',
      'drum': 'Drum #01',
      'stage': 'Grinding',
      'progress': 0.65,
      'status': 'In Progress',
      'startDate': '2024-01-15',
    },
    {
      'id': 'JOB-002',
      'client': 'Gold Corp Ltd',
      'batchId': 'BATCH-2024-002',
      'drum': 'Drum #02',
      'stage': 'Crushing',
      'progress': 0.30,
      'status': 'In Progress',
      'startDate': '2024-01-16',
    },
    {
      'id': 'JOB-003',
      'client': 'Silver Mining Co',
      'batchId': 'BATCH-2024-003',
      'drum': 'Drum #03',
      'stage': 'Processing',
      'progress': 0.85,
      'status': 'In Progress',
      'startDate': '2024-01-14',
    },
    {
      'id': 'JOB-004',
      'client': 'Precious Metals Inc',
      'batchId': 'BATCH-2024-004',
      'drum': 'Drum #04',
      'stage': 'Completed',
      'progress': 1.0,
      'status': 'Completed',
      'startDate': '2024-01-10',
    },
  ];

  final List<String> _workflowStages = [
    'Receiving',
    'Crushing',
    'Grinding',
    'Processing',
    'Quality Check',
    'Packaging',
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
          'PROCESSING WORKFLOW',
          style: TextStyle(
            color: kGold,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
            fontSize: 16,
          ),
        ),
        iconTheme: const IconThemeData(color: kGold),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded, color: kGold),
            onPressed: _showAddJobDialog,
            tooltip: 'Add New Job',
          ),
          const ThemeToggleButton(),
          IconButton(
            icon: const Icon(Icons.menu_rounded, color: kGold),
            tooltip: 'Menu',
            onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
          ),
        ],
      ),
      endDrawer: const OperatorDrawer(
        currentMenu: OperatorMenu.processing,
        operatorName: 'Operator',
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Summary Cards
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 1.6,
              children: [
                _buildSummaryCard('Active Jobs', '3', Icons.work_outline_rounded, Colors.green),
                _buildSummaryCard('Completed Today', '1', Icons.check_circle_outline_rounded, kGold),
                _buildSummaryCard('Pending', '2', Icons.pending_outlined, Colors.orange),
              ],
            ),
            const SizedBox(height: 24),

            // Jobs List
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Processing Jobs',
                  style: TextStyle(
                    color: context.textColor,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: kGold.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: kGold.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.filter_list_rounded, color: kGold, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        'Filter',
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
            const SizedBox(height: 16),
            ..._jobs.map((job) => _buildJobCard(job)),
            const SizedBox(height: 24),

            // Workflow Stages Reference
            Text(
              'Workflow Stages',
              style: TextStyle(
                color: context.textColor,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildWorkflowStagesReference(),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color) {
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
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                title,
                style: TextStyle(
                  color: context.mutedTextColor,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildJobCard(Map<String, dynamic> job) {
    final isCompleted = job['status'] == 'Completed';
    final stageIndex = _workflowStages.indexOf(job['stage']);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
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
                  isCompleted ? Icons.check_circle_rounded : Icons.work_rounded,
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
                      job['id'],
                      style: TextStyle(
                        color: context.textColor,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      job['client'],
                      style: TextStyle(
                        color: context.mutedTextColor,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isCompleted
                      ? Colors.green.withOpacity(0.1)
                      : kGold.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isCompleted ? Colors.green.withOpacity(0.3) : kGold.withOpacity(0.3),
                  ),
                ),
                child: Text(
                  job['status'],
                  style: TextStyle(
                    color: isCompleted ? Colors.green : kGold,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildInfoChip('Batch', job['batchId']),
              const SizedBox(width: 8),
              _buildInfoChip('Drum', job['drum']),
              const SizedBox(width: 8),
              _buildInfoChip('Started', job['startDate']),
            ],
          ),
          const SizedBox(height: 16),
          // Workflow Progress Timeline
          _buildWorkflowTimeline(stageIndex, isCompleted),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: job['progress'],
            backgroundColor: kGold.withOpacity(0.1),
            color: isCompleted ? Colors.green : kGold,
            minHeight: 6,
            borderRadius: BorderRadius.circular(3),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Current Stage: ${job['stage']}',
                style: TextStyle(
                  color: context.textColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '${(job['progress'] * 100).toInt()}% Complete',
                style: TextStyle(
                  color: context.mutedTextColor,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showJobDetails(job),
                  icon: const Icon(Icons.visibility_outlined, size: 16),
                  label: const Text('View Details'),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: kGold.withOpacity(0.3)),
                    foregroundColor: context.textColor,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (!isCompleted)
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _updateJobStage(job),
                    icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                    label: const Text('Next Stage'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kGold,
                      foregroundColor: kBlack,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: kGold.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: kGold.withOpacity(0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              color: context.mutedTextColor,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: context.textColor,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkflowTimeline(int currentStageIndex, bool isCompleted) {
    return SizedBox(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _workflowStages.length,
        itemBuilder: (context, index) {
          final isCurrentStage = index == currentStageIndex;
          final isPastStage = index < currentStageIndex || isCompleted;
          
          return Row(
            children: [
              Column(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: isPastStage || isCurrentStage
                          ? (isCompleted ? Colors.green : kGold)
                          : kGold.withOpacity(0.2),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isPastStage || isCurrentStage
                            ? (isCompleted ? Colors.green : kGold)
                            : kGold.withOpacity(0.3),
                        width: 2,
                      ),
                    ),
                    child: isPastStage || isCurrentStage
                        ? Icon(
                            isPastStage ? Icons.check : Icons.circle,
                            color: Colors.white,
                            size: 12,
                          )
                        : null,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _workflowStages[index].substring(0, 3),
                    style: TextStyle(
                      color: isPastStage || isCurrentStage
                          ? (isCompleted ? Colors.green : kGold)
                          : context.mutedTextColor,
                      fontSize: 9,
                      fontWeight: isCurrentStage ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ],
              ),
              if (index < _workflowStages.length - 1)
                Container(
                  width: 20,
                  height: 2,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  color: isPastStage
                      ? (isCompleted ? Colors.green : kGold)
                      : kGold.withOpacity(0.2),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildWorkflowStagesReference() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kGold.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Standard Processing Workflow',
            style: TextStyle(
              color: context.textColor,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          ..._workflowStages.asMap().entries.map((entry) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: kGold.withOpacity(0.1),
                      shape: BoxShape.circle,
                      border: Border.all(color: kGold.withOpacity(0.3)),
                    ),
                    child: Center(
                      child: Text(
                        '${entry.key + 1}',
                        style: TextStyle(
                          color: kGold,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    entry.value,
                    style: TextStyle(
                      color: context.textColor,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
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

  void _showAddJobDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.surfaceColor,
        title: Text(
          'Add New Processing Job',
          style: TextStyle(color: context.textColor),
        ),
        content: const Text('Job creation form - UI only (no backend)'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: kGold),
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Job added (mock)'),
                  backgroundColor: kGold,
                ),
              );
            },
            child: const Text('Add Job', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showJobDetails(Map<String, dynamic> job) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.surfaceColor,
        title: Text(
          'Job Details: ${job['id']}',
          style: TextStyle(color: context.textColor),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('Client', job['client']),
              _buildDetailRow('Batch ID', job['batchId']),
              _buildDetailRow('Drum', job['drum']),
              _buildDetailRow('Current Stage', job['stage']),
              _buildDetailRow('Status', job['status']),
              _buildDetailRow('Start Date', job['startDate']),
              _buildDetailRow('Progress', '${(job['progress'] * 100).toInt()}%'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: Colors.grey)),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: TextStyle(
                color: context.mutedTextColor,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: context.textColor,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _updateJobStage(Map<String, dynamic> job) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Moving ${job['id']} to next stage (mock)'),
        backgroundColor: kGold,
      ),
    );
  }
}
