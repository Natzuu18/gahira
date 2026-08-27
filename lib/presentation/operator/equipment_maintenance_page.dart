import 'package:flutter/material.dart';

import '../shared_widgets/appColor.dart';
import '../shared_widgets/themeToggleButton.dart';
import 'operator_drawer.dart';

class EquipmentMaintenancePage extends StatefulWidget {
  const EquipmentMaintenancePage({super.key});

  @override
  State<EquipmentMaintenancePage> createState() => _EquipmentMaintenancePageState();
}

class _EquipmentMaintenancePageState extends State<EquipmentMaintenancePage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // Mock data
  final List<Map<String, dynamic>> _equipment = [
    {
      'id': 'EQ-001',
      'name': 'Ball Mill #01 - Primary',
      'type': 'Ball Mill',
      'status': 'Running',
      'drum': 'Drum #01',
      'capacity': '500 kg',
      'utilization': 0.85,
      'lastMaintenance': '2024-01-10',
      'nextMaintenance': '2024-02-10',
    },
    {
      'id': 'EQ-002',
      'name': 'Ball Mill #02 - Secondary',
      'type': 'Ball Mill',
      'status': 'Running',
      'drum': 'Drum #02',
      'capacity': '400 kg',
      'utilization': 0.78,
      'lastMaintenance': '2024-01-12',
      'nextMaintenance': '2024-02-12',
    },
    {
      'id': 'EQ-003',
      'name': 'Ball Mill #03 - Tertiary',
      'type': 'Ball Mill',
      'status': 'Stopped',
      'drum': 'Drum #03',
      'capacity': '350 kg',
      'utilization': 0.0,
      'lastMaintenance': '2024-01-05',
      'nextMaintenance': '2024-02-05',
    },
    {
      'id': 'EQ-004',
      'name': 'Ball Mill #04 - Auxiliary',
      'type': 'Ball Mill',
      'status': 'Maintenance',
      'drum': 'Drum #04',
      'capacity': '300 kg',
      'utilization': 0.30,
      'lastMaintenance': '2024-01-15',
      'nextMaintenance': '2024-01-22',
    },
  ];

  final List<Map<String, dynamic>> _maintenanceSchedule = [
    {
      'id': 'MAINT-001',
      'equipmentId': 'EQ-004',
      'equipmentName': 'Ball Mill #04',
      'type': 'Preventive',
      'scheduledDate': '2024-01-22',
      'status': 'Scheduled',
      'assignedTo': 'John Doe',
    },
    {
      'id': 'MAINT-002',
      'equipmentId': 'EQ-001',
      'equipmentName': 'Ball Mill #01',
      'type': 'Preventive',
      'scheduledDate': '2024-02-10',
      'status': 'Scheduled',
      'assignedTo': 'Jane Smith',
    },
    {
      'id': 'MAINT-003',
      'equipmentId': 'EQ-002',
      'equipmentName': 'Ball Mill #02',
      'type': 'Corrective',
      'scheduledDate': '2024-01-18',
      'status': 'In Progress',
      'assignedTo': 'Mike Johnson',
    },
  ];

  final List<Map<String, dynamic>> _maintenanceHistory = [
    {
      'id': 'MAINT-H-001',
      'equipmentName': 'Ball Mill #02',
      'type': 'Preventive',
      'completedDate': '2024-01-12',
      'duration': '4 hours',
      'performedBy': 'Jane Smith',
      'notes': 'Routine inspection and lubrication',
    },
    {
      'id': 'MAINT-H-002',
      'equipmentName': 'Ball Mill #01',
      'type': 'Corrective',
      'completedDate': '2024-01-10',
      'duration': '6 hours',
      'performedBy': 'John Doe',
      'notes': 'Bearing replacement',
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
            'EQUIPMENT & MAINTENANCE',
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
              onPressed: _showAddEquipmentDialog,
              tooltip: 'Add Equipment',
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
              Tab(text: 'Equipment'),
              Tab(text: 'Schedule'),
              Tab(text: 'History'),
            ],
          ),
        ),
        endDrawer: const OperatorDrawer(
          currentMenu: OperatorMenu.equipment,
          operatorName: 'Operator',
        ),
        body: TabBarView(
          children: [
            _buildEquipmentTab(),
            _buildScheduleTab(),
            _buildHistoryTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildEquipmentTab() {
    return SingleChildScrollView(
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
              _buildSummaryCard('Total Equipment', '4', Icons.settings_input_component_rounded, kGold),
              _buildSummaryCard('Running', '2', Icons.play_circle_outline_rounded, Colors.green),
              _buildSummaryCard('Maintenance', '1', Icons.build_circle_outlined, Colors.orange),
            ],
          ),
          const SizedBox(height: 24),

          // Equipment List
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Equipment List',
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
          ..._equipment.map((eq) => _buildEquipmentCard(eq)),
        ],
      ),
    );
  }

  Widget _buildScheduleTab() {
    return SingleChildScrollView(
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
              _buildSummaryCard('Scheduled', '2', Icons.event_rounded, kGold),
              _buildSummaryCard('In Progress', '1', Icons.sync_rounded, Colors.blue),
              _buildSummaryCard('Completed Today', '0', Icons.check_circle_outline_rounded, Colors.green),
            ],
          ),
          const SizedBox(height: 24),

          // Maintenance Schedule
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Maintenance Schedule',
                style: TextStyle(
                  color: context.textColor,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              ElevatedButton.icon(
                onPressed: _showScheduleMaintenanceDialog,
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('Schedule'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kGold,
                  foregroundColor: kBlack,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ..._maintenanceSchedule.map((maint) => _buildMaintenanceScheduleCard(maint)),
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
            'Maintenance History',
            style: TextStyle(
              color: context.textColor,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          ..._maintenanceHistory.map((history) => _buildMaintenanceHistoryCard(history)),
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

  Widget _buildEquipmentCard(Map<String, dynamic> eq) {
    final status = eq['status'];
    final statusColor = status == 'Running'
        ? Colors.green
        : (status == 'Maintenance' ? Colors.orange : Colors.red);
    
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
                child: Icon(
                  Icons.settings_input_component_rounded,
                  color: statusColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      eq['name'],
                      style: TextStyle(
                        color: context.textColor,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      eq['type'],
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
              _buildInfoChip('ID', eq['id']),
              const SizedBox(width: 8),
              _buildInfoChip('Drum', eq['drum']),
              const SizedBox(width: 8),
              _buildInfoChip('Capacity', eq['capacity']),
            ],
          ),
          const SizedBox(height: 16),
          if (status == 'Running') ...[
            Row(
              children: [
                Text(
                  'Utilization',
                  style: TextStyle(
                    color: context.mutedTextColor,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: LinearProgressIndicator(
                    value: eq['utilization'],
                    backgroundColor: kGold.withOpacity(0.1),
                    color: kGold,
                    minHeight: 6,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${(eq['utilization'] * 100).toInt()}%',
                  style: TextStyle(
                    color: context.textColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
          Row(
            children: [
              Expanded(
                child: _buildMaintenanceInfo('Last Maintenance', eq['lastMaintenance']),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildMaintenanceInfo('Next Maintenance', eq['nextMaintenance']),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showEquipmentDetails(eq),
                  icon: const Icon(Icons.visibility_outlined, size: 16),
                  label: const Text('Details'),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: kGold.withOpacity(0.3)),
                    foregroundColor: context.textColor,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _assignDrum(eq),
                  icon: const Icon(Icons.swap_horiz_rounded, size: 16),
                  label: const Text('Assign Drum'),
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

  Widget _buildMaintenanceScheduleCard(Map<String, dynamic> maint) {
    final status = maint['status'];
    final statusColor = status == 'Scheduled'
        ? kGold
        : (status == 'In Progress' ? Colors.blue : Colors.green);
    
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
                child: Icon(
                  Icons.build_rounded,
                  color: statusColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      maint['equipmentName'],
                      style: TextStyle(
                        color: context.textColor,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      maint['type'],
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
              _buildInfoChip('ID', maint['id']),
              const SizedBox(width: 8),
              _buildInfoChip('Scheduled', maint['scheduledDate']),
              const SizedBox(width: 8),
              _buildInfoChip('Assigned', maint['assignedTo']),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _updateMaintenanceStatus(maint),
                  icon: const Icon(Icons.edit_rounded, size: 16),
                  label: const Text('Update Status'),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: kGold.withOpacity(0.3)),
                    foregroundColor: context.textColor,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _viewMaintenanceDetails(maint),
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

  Widget _buildMaintenanceHistoryCard(Map<String, dynamic> history) {
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
                  color: Colors.green.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: Colors.green,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      history['equipmentName'],
                      style: TextStyle(
                        color: context.textColor,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      history['type'],
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
              _buildInfoChip('Completed', history['completedDate']),
              const SizedBox(width: 8),
              _buildInfoChip('Duration', history['duration']),
              const SizedBox(width: 8),
              _buildInfoChip('By', history['performedBy']),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: kGold.withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.note_rounded, color: kGold, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    history['notes'],
                    style: TextStyle(
                      color: context.textColor,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
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

  Widget _buildMaintenanceInfo(String label, String value) {
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

  void _showAddEquipmentDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.surfaceColor,
        title: Text(
          'Add New Equipment',
          style: TextStyle(color: context.textColor),
        ),
        content: const Text('Equipment registration form - UI only (no backend)'),
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
                  content: Text('Equipment added (mock)'),
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

  void _showScheduleMaintenanceDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.surfaceColor,
        title: Text(
          'Schedule Maintenance',
          style: TextStyle(color: context.textColor),
        ),
        content: const Text('Maintenance scheduling form - UI only (no backend)'),
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
                  content: Text('Maintenance scheduled (mock)'),
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

  void _showEquipmentDetails(Map<String, dynamic> eq) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.surfaceColor,
        title: Text(
          'Equipment Details: ${eq['id']}',
          style: TextStyle(color: context.textColor),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('Name', eq['name']),
              _buildDetailRow('Type', eq['type']),
              _buildDetailRow('Status', eq['status']),
              _buildDetailRow('Drum', eq['drum']),
              _buildDetailRow('Capacity', eq['capacity']),
              _buildDetailRow('Utilization', '${(eq['utilization'] * 100).toInt()}%'),
              _buildDetailRow('Last Maintenance', eq['lastMaintenance']),
              _buildDetailRow('Next Maintenance', eq['nextMaintenance']),
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

  void _assignDrum(Map<String, dynamic> eq) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.surfaceColor,
        title: Text(
          'Assign Drum to ${eq['name']}',
          style: TextStyle(color: context.textColor),
        ),
        content: const Text('Drum assignment form - UI only (no backend)'),
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
                  content: Text('Drum assigned (mock)'),
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

  void _updateMaintenanceStatus(Map<String, dynamic> maint) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Updating status for ${maint['id']} (mock)'),
        backgroundColor: kGold,
      ),
    );
  }

  void _viewMaintenanceDetails(Map<String, dynamic> maint) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.surfaceColor,
        title: Text(
          'Maintenance Details: ${maint['id']}',
          style: TextStyle(color: context.textColor),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('Equipment', maint['equipmentName']),
              _buildDetailRow('Type', maint['type']),
              _buildDetailRow('Scheduled Date', maint['scheduledDate']),
              _buildDetailRow('Status', maint['status']),
              _buildDetailRow('Assigned To', maint['assignedTo']),
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
