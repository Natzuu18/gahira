import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../infrastructure/repositories/supabase_processing_repository.dart';
import '../../../infrastructure/repositories/supabase_service_request_repository.dart';
import '../../../infrastructure/repositories/supabase_equipment_repository.dart';
import '../../../infrastructure/repositories/supabase_user_repository.dart';
import '../../shared_widgets/appColor.dart';
import '../../shared_widgets/adminDrawer.dart';
import '../../shared_widgets/themeToggleButton.dart';

class ScheduleAssignmentPage extends StatefulWidget {
  const ScheduleAssignmentPage({super.key});

  @override
  State<ScheduleAssignmentPage> createState() => _ScheduleAssignmentPageState();
}

class _ScheduleAssignmentPageState extends State<ScheduleAssignmentPage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final _processingRepo = SupabaseProcessingRepository();
  final _requestRepo = SupabaseServiceRequestRepository();
  final _equipRepo = SupabaseEquipmentRepository();
  final _userRepo = SupabaseUserRepository();

  List<Map<String, dynamic>> _tasks = [];
  List<Map<String, dynamic>> _approvedRequests = [];
  List<Map<String, dynamic>> _machines = [];
  List<Map<String, dynamic>> _drums = [];
  List<dynamic> _operators = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    final tasksRes = await _processingRepo.getProcessingTasks();
    final requestsRes = await _requestRepo.getServiceRequests(); // Filter for Approved later
    final machinesRes = await _equipRepo.getMachines();
    final drumsRes = await _equipRepo.getDrums();
    final usersRes = await _userRepo.getAllUsers(); // Filter for Operators

    tasksRes.fold((f) => null, (list) => _tasks = list);
    requestsRes.fold((f) => null, (list) => _approvedRequests = list.where((r) => r['status'] == 'Approved').toList());
    machinesRes.fold((f) => null, (list) => _machines = list);
    drumsRes.fold((f) => null, (list) => _drums = list);
    usersRes.fold((f) => null, (list) => _operators = list.where((u) => u.roleId == 'operator').toList());

    setState(() => _isLoading = false);
  }

  void _showAddDialog() {
    String? selectedRequestId;
    String? selectedMachineId;
    String? selectedDrumId;
    String? selectedOperatorId;
    DateTime selectedDate = DateTime.now();
    TimeOfDay selectedTime = const TimeOfDay(hour: 8, minute: 0);

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: context.surfaceColor,
          title: const Text('New Assignment', style: TextStyle(color: kGold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: selectedRequestId,
                  dropdownColor: context.surfaceColor,
                  decoration: const InputDecoration(labelText: 'Approved Request'),
                  items: _approvedRequests.map((r) => DropdownMenuItem(
                    value: r['service_request_id'].toString(), 
                    child: Text('${r['id'] ?? 'SR'} - ${r['minerName'] ?? 'Miner'}', style: TextStyle(color: context.textColor, fontSize: 12))
                  )).toList(),
                  onChanged: (v) => setDialogState(() => selectedRequestId = v),
                ),
                DropdownButtonFormField<String>(
                  value: selectedMachineId,
                  dropdownColor: context.surfaceColor,
                  decoration: const InputDecoration(labelText: 'Machine'),
                  items: _machines.where((m) => m['status'] == 'Available').map((m) => DropdownMenuItem(
                    value: m['machine_id'].toString(), 
                    child: Text(m['machine_name'], style: TextStyle(color: context.textColor))
                  )).toList(),
                  onChanged: (v) => setDialogState(() {
                    selectedMachineId = v;
                    selectedDrumId = null;
                  }),
                ),
                DropdownButtonFormField<String>(
                  value: selectedDrumId,
                  dropdownColor: context.surfaceColor,
                  decoration: const InputDecoration(labelText: 'Drum'),
                  items: _drums.where((d) => d['machine_id'].toString() == selectedMachineId && d['status'] == 'Available').map((d) => DropdownMenuItem(
                    value: d['drum_id'].toString(), 
                    child: Text(d['drum_name'], style: TextStyle(color: context.textColor))
                  )).toList(),
                  onChanged: (v) => setDialogState(() => selectedDrumId = v),
                ),
                DropdownButtonFormField<String>(
                  value: selectedOperatorId,
                  dropdownColor: context.surfaceColor,
                  decoration: const InputDecoration(labelText: 'Operator'),
                  items: _operators.map((o) => DropdownMenuItem(
                    value: o.userId.toString(), 
                    child: Text('${o.fname} ${o.lname}', style: TextStyle(color: context.textColor))
                  )).toList(),
                  onChanged: (v) => setDialogState(() => selectedOperatorId = v),
                ),
                const SizedBox(height: 16),
                ListTile(
                  dense: true,
                  title: Text('Date: ${DateFormat('yyyy-MM-dd').format(selectedDate)}', style: TextStyle(color: context.textColor)),
                  trailing: const Icon(Icons.calendar_today, color: kGold, size: 18),
                  onTap: () async {
                    final d = await showDatePicker(context: context, initialDate: selectedDate, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 90)));
                    if (d != null) setDialogState(() => selectedDate = d);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: kGold),
              onPressed: () async {
                if (selectedRequestId == null || selectedMachineId == null || selectedDrumId == null || selectedOperatorId == null) return;
                
                final data = {
                  'service_request_id': selectedRequestId,
                  'machine_id': selectedMachineId,
                  'drum_id': selectedDrumId,
                  'operator_id': selectedOperatorId,
                  'scheduled_date': DateFormat('yyyy-MM-dd').format(selectedDate),
                  'status': 'Scheduled',
                };
                await _processingRepo.createProcessingTask(data);
                Navigator.pop(context);
                _loadData();
              },
              child: const Text('Assign', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: context.bgColor,
      appBar: AppBar(
        backgroundColor: context.surfaceColor,
        title: const Text('SCHEDULE & ASSIGNMENT', style: TextStyle(color: kGold, fontWeight: FontWeight.bold, letterSpacing: 1.5, fontSize: 14)),
        actions: [
          const ThemeToggleButton(),
          IconButton(icon: const Icon(Icons.menu_rounded, color: kGold), onPressed: () => _scaffoldKey.currentState?.openEndDrawer()),
        ],
      ),
      endDrawer: const AdminDrawer(currentMenu: AdminMenu.scheduleAssignment),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: kGold))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _tasks.length,
              itemBuilder: (context, index) {
                final t = _tasks[index];
                return Card(
                  color: context.surfaceColor,
                  child: ListTile(
                    leading: const Icon(Icons.assignment_ind, color: kGold),
                    title: Text('Task #${t['processing_id'].toString().substring(0, 8)}', style: TextStyle(color: context.textColor, fontWeight: FontWeight.bold)),
                    subtitle: Text('${t['scheduled_date']} | Machine: ${t['machines']?['machine_name']} | Op: ${t['operator']?['fname']}', style: TextStyle(color: context.mutedTextColor, fontSize: 12)),
                    trailing: _buildStatusChip(t['status']),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: kGold,
        onPressed: _showAddDialog,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color color = Colors.blue;
    if (status == 'Active') color = Colors.green;
    if (status == 'Completed') color = Colors.grey;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: color)),
      child: Text(status, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }
}
