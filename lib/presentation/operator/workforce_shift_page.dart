import 'package:flutter/material.dart';

import '../shared_widgets/appColor.dart';
import '../shared_widgets/themeToggleButton.dart';
import 'operator_drawer.dart';

class WorkforceShiftPage extends StatefulWidget {
  const WorkforceShiftPage({super.key});

  @override
  State<WorkforceShiftPage> createState() => _WorkforceShiftPageState();
}

class _WorkforceShiftPageState extends State<WorkforceShiftPage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // Mock data
  final List<Map<String, dynamic>> _operators = [
    {
      'id': 'OP-001',
      'name': 'John Doe',
      'role': 'Senior Operator',
      'status': 'On Duty',
      'assignedEquipment': 'Mill #01',
      'shift': 'Afternoon',
      'availability': 'Available',
    },
    {
      'id': 'OP-002',
      'name': 'Jane Smith',
      'role': 'Operator',
      'status': 'On Duty',
      'assignedEquipment': 'Mill #02',
      'shift': 'Afternoon',
      'availability': 'Available',
    },
    {
      'id': 'OP-003',
      'name': 'Mike Johnson',
      'role': 'Operator',
      'status': 'Off Duty',
      'assignedEquipment': 'None',
      'shift': 'Morning',
      'availability': 'Available',
    },
    {
      'id': 'OP-004',
      'name': 'Sarah Williams',
      'role': 'Junior Operator',
      'status': 'On Leave',
      'assignedEquipment': 'None',
      'shift': 'N/A',
      'availability': 'Unavailable',
    },
  ];

  final List<Map<String, dynamic>> _shifts = [
    {
      'id': 'SHIFT-001',
      'name': 'Morning Shift',
      'time': '06:00 AM - 02:00 PM',
      'date': '2024-01-17',
      'assignedCount': 2,
      'requiredCount': 3,
      'status': 'Active',
    },
    {
      'id': 'SHIFT-002',
      'name': 'Afternoon Shift',
      'time': '02:00 PM - 10:00 PM',
      'date': '2024-01-17',
      'assignedCount': 2,
      'requiredCount': 3,
      'status': 'Upcoming',
    },
    {
      'id': 'SHIFT-003',
      'name': 'Night Shift',
      'time': '10:00 PM - 06:00 AM',
      'date': '2024-01-17',
      'assignedCount': 1,
      'requiredCount': 3,
      'status': 'Scheduled',
    },
  ];

  final List<Map<String, dynamic>> _assignmentHistory = [
    {
      'id': 'ASGN-001',
      'operatorName': 'John Doe',
      'equipment': 'Mill #01',
      'shift': 'Morning',
      'date': '2024-01-16',
      'duration': '8 hours',
    },
    {
      'id': 'ASGN-002',
      'operatorName': 'Jane Smith',
      'equipment': 'Mill #02',
      'shift': 'Morning',
      'date': '2024-01-16',
      'duration': '8 hours',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
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
            'WORKFORCE & SHIFTS',
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
              onPressed: _showAddOperatorDialog,
              tooltip: 'Add Operator',
            ),
            const ThemeToggleButton(),
            IconButton(
              icon: const Icon(Icons.menu_rounded, color: kGold),
              tooltip: 'Menu',
              onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
            ),
          ],
          bottom: TabBar(
            labelColor: kGold,
            unselectedLabelColor: context.mutedTextColor,
            indicatorColor: kGold,
            tabs: const [
              Tab(text: 'Operators'),
              Tab(text: 'Shifts'),
              Tab(text: 'History'),
            ],
          ),
        ),
        endDrawer: const OperatorDrawer(
          currentMenu: OperatorMenu.workforce,
          operatorName: 'Operator',
        ),
        body: TabBarView(
          children: [
            _buildOperatorsTab(),
            _buildShiftsTab(),
            _buildHistoryTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildOperatorsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 1.6,
            children: [
              _buildSummaryCard('Total Operators', '4', Icons.people_outline_rounded, kGold),
              _buildSummaryCard('On Duty', '2', Icons.work_rounded, Colors.green),
              _buildSummaryCard('Available', '3', Icons.check_circle_outline_rounded, Colors.blue),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Operators',
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
          ..._operators.map((op) => _buildOperatorCard(op)),
        ],
      ),
    );
  }

  Widget _buildShiftsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 1.6,
            children: [
              _buildSummaryCard('Today\'s Shifts', '3', Icons.calendar_today_rounded, kGold),
              _buildSummaryCard('Active', '1', Icons.play_circle_outline_rounded, Colors.green),
              _buildSummaryCard('Upcoming', '2', Icons.schedule_rounded, Colors.orange),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Shift Schedule',
                style: TextStyle(
                  color: context.textColor,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              ElevatedButton.icon(
                onPressed: _showScheduleShiftDialog,
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('Schedule Shift'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kGold,
                  foregroundColor: kBlack,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ..._shifts.map((shift) => _buildShiftCard(shift)),
        ],
      ),
    );
  }

  Widget _buildHistoryTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Assignment History',
            style: TextStyle(
              color: context.textColor,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          ..._assignmentHistory.map((history) => _buildAssignmentHistoryCard(history)),
        ],
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

  Widget _buildOperatorCard(Map<String, dynamic> op) {
    final status = op['status'];
    final statusColor = status == 'On Duty'
        ? Colors.green
        : (status == 'Off Duty' ? Colors.orange : Colors.red);
    
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
                  color: statusColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.person_rounded, color: statusColor, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      op['name'],
                      style: TextStyle(
                        color: context.textColor,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      op['role'],
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
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: statusColor.withOpacity(0.3)),
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
          const SizedBox(height: 16),
          Row(
            children: [
              _buildInfoChip('ID', op['id']),
              const SizedBox(width: 8),
              _buildInfoChip('Shift', op['shift']),
              const SizedBox(width: 8),
              _buildAvailabilityChip(op['availability']),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildAssignmentInfo('Assigned Equipment', op['assignedEquipment']),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _assignOperator(op),
                  icon: const Icon(Icons.assignment_rounded, size: 16),
                  label: const Text('Assign'),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: kGold.withOpacity(0.3)),
                    foregroundColor: context.textColor,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _viewOperatorDetails(op),
                  icon: const Icon(Icons.visibility_outlined, size: 16),
                  label: const Text('Details'),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: kGold.withOpacity(0.3)),
                    foregroundColor: context.textColor,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildShiftCard(Map<String, dynamic> shift) {
    final status = shift['status'];
    final statusColor = status == 'Active'
        ? Colors.green
        : (status == 'Upcoming' ? Colors.orange : Colors.blue);
    
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
                  color: statusColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.schedule_rounded, color: statusColor, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      shift['name'],
                      style: TextStyle(
                        color: context.textColor,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      shift['time'],
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
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: statusColor.withOpacity(0.3)),
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
          const SizedBox(height: 16),
          Row(
            children: [
              _buildInfoChip('ID', shift['id']),
              const SizedBox(width: 8),
              _buildInfoChip('Date', shift['date']),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildAssignmentInfo('Assigned', '${shift['assignedCount']}/${shift['requiredCount']}'),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: LinearProgressIndicator(
                  value: shift['assignedCount'] / shift['requiredCount'],
                  backgroundColor: kGold.withOpacity(0.1),
                  color: kGold,
                  minHeight: 6,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _assignToShift(shift),
                  icon: const Icon(Icons.person_add_rounded, size: 16),
                  label: const Text('Assign Operator'),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: kGold.withOpacity(0.3)),
                    foregroundColor: context.textColor,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _viewShiftDetails(shift),
                  icon: const Icon(Icons.visibility_outlined, size: 16),
                  label: const Text('Details'),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: kGold.withOpacity(0.3)),
                    foregroundColor: context.textColor,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAssignmentHistoryCard(Map<String, dynamic> history) {
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
                  color: kGold.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.history_rounded, color: kGold, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      history['operatorName'],
                      style: TextStyle(
                        color: context.textColor,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      history['shift'],
                      style: TextStyle(
                        color: context.mutedTextColor,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildInfoChip('Equipment', history['equipment']),
              const SizedBox(width: 8),
              _buildInfoChip('Date', history['date']),
              const SizedBox(width: 8),
              _buildInfoChip('Duration', history['duration']),
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

  Widget _buildAvailabilityChip(String availability) {
    final color = availability == 'Available' ? Colors.green : Colors.red;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            availability == 'Available' ? Icons.check_circle_rounded : Icons.cancel_rounded,
            color: color,
            size: 12,
          ),
          const SizedBox(width: 4),
          Text(
            availability,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAssignmentInfo(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: context.mutedTextColor,
            fontSize: 11,
          ),
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

  void _showAddOperatorDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.surfaceColor,
        title: Text(
          'Add New Operator',
          style: TextStyle(color: context.textColor),
        ),
        content: const Text('Operator registration form - UI only (no backend)'),
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
                  content: Text('Operator added (mock)'),
                  backgroundColor: kGold,
                ),
              );
            },
            child: const Text('Add', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showScheduleShiftDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.surfaceColor,
        title: Text(
          'Schedule Shift',
          style: TextStyle(color: context.textColor),
        ),
        content: const Text('Shift scheduling form - UI only (no backend)'),
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
                  content: Text('Shift scheduled (mock)'),
                  backgroundColor: kGold,
                ),
              );
            },
            child: const Text('Schedule', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _assignOperator(Map<String, dynamic> op) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.surfaceColor,
        title: Text(
          'Assign ${op['name']}',
          style: TextStyle(color: context.textColor),
        ),
        content: const Text('Operator assignment form - UI only (no backend)'),
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
                  content: Text('Operator assigned (mock)'),
                  backgroundColor: kGold,
                ),
              );
            },
            child: const Text('Assign', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _viewOperatorDetails(Map<String, dynamic> op) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.surfaceColor,
        title: Text(
          'Operator Details: ${op['id']}',
          style: TextStyle(color: context.textColor),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('Name', op['name']),
              _buildDetailRow('Role', op['role']),
              _buildDetailRow('Status', op['status']),
              _buildDetailRow('Shift', op['shift']),
              _buildDetailRow('Assigned Equipment', op['assignedEquipment']),
              _buildDetailRow('Availability', op['availability']),
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

  void _assignToShift(Map<String, dynamic> shift) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Assigning operator to ${shift['name']} (mock)'),
        backgroundColor: kGold,
      ),
    );
  }

  void _viewShiftDetails(Map<String, dynamic> shift) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.surfaceColor,
        title: Text(
          'Shift Details: ${shift['id']}',
          style: TextStyle(color: context.textColor),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('Name', shift['name']),
              _buildDetailRow('Time', shift['time']),
              _buildDetailRow('Date', shift['date']),
              _buildDetailRow('Status', shift['status']),
              _buildDetailRow('Assigned', '${shift['assignedCount']}/${shift['requiredCount']}'),
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
            width: 120,
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
}
