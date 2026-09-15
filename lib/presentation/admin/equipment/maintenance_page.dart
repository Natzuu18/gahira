import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../infrastructure/repositories/supabase_equipment_repository.dart';
import '../../shared_widgets/appColor.dart';
import '../../shared_widgets/adminDrawer.dart';
import '../../shared_widgets/themeToggleButton.dart';

class MaintenancePage extends StatefulWidget {
  const MaintenancePage({super.key});

  @override
  State<MaintenancePage> createState() => _MaintenancePageState();
}

class _MaintenancePageState extends State<MaintenancePage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final _repository = SupabaseEquipmentRepository();
  List<Map<String, dynamic>> _schedules = [];
  List<Map<String, dynamic>> _machines = [];
  List<Map<String, dynamic>> _drums = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    final machinesRes = await _repository.getMachines();
    final drumsRes = await _repository.getDrums();
    final schedulesRes = await _repository.getMaintenanceSchedules();

    machinesRes.fold((f) => null, (list) => _machines = list);
    drumsRes.fold((f) => null, (list) => _drums = list);
    schedulesRes.fold(
      (failure) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(failure.message))),
      (list) => setState(() {
        _schedules = list;
        _isLoading = false;
      }),
    );
  }

  void _showAddDialog() {
    String? selectedMachineId;
    String? selectedDrumId;
    String maintenanceType = 'Routine Check';
    DateTime selectedDate = DateTime.now();
    final descController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: context.surfaceColor,
          title: const Text('Schedule Maintenance', style: TextStyle(color: kGold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: selectedMachineId,
                  dropdownColor: context.surfaceColor,
                  decoration: const InputDecoration(labelText: 'Machine'),
                  items: _machines
                      .map((m) => DropdownMenuItem(value: m['machine_id'].toString(), child: Text(m['machine_name'], style: TextStyle(color: context.textColor))))
                      .toList(),
                  onChanged: (v) => setDialogState(() {
                    selectedMachineId = v;
                    selectedDrumId = null;
                  }),
                ),
                DropdownButtonFormField<String>(
                  value: selectedDrumId,
                  dropdownColor: context.surfaceColor,
                  decoration: const InputDecoration(labelText: 'Drum (Optional)'),
                  items: _drums
                      .where((d) => d['machine_id'].toString() == selectedMachineId)
                      .map((d) => DropdownMenuItem(value: d['drum_id'].toString(), child: Text(d['drum_name'], style: TextStyle(color: context.textColor))))
                      .toList(),
                  onChanged: (v) => setDialogState(() => selectedDrumId = v),
                ),
                DropdownButtonFormField<String>(
                  value: maintenanceType,
                  dropdownColor: context.surfaceColor,
                  decoration: const InputDecoration(labelText: 'Maintenance Type'),
                  items: ['Routine Check', 'Repair', 'Replacement', 'Emergency']
                      .map((s) => DropdownMenuItem(value: s, child: Text(s, style: TextStyle(color: context.textColor))))
                      .toList(),
                  onChanged: (v) => setDialogState(() => maintenanceType = v!),
                ),
                const SizedBox(height: 16),
                ListTile(
                  title: Text('Date: ${DateFormat('yyyy-MM-dd').format(selectedDate)}', style: TextStyle(color: context.textColor)),
                  trailing: const Icon(Icons.calendar_today, color: kGold),
                  onTap: () async {
                    final d = await showDatePicker(context: context, initialDate: selectedDate, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)));
                    if (d != null) setDialogState(() => selectedDate = d);
                  },
                ),
                _buildField(descController, 'Description'),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: kGold),
              onPressed: () async {
                final data = {
                  'machine_id': selectedMachineId,
                  'drum_id': selectedDrumId,
                  'maintenance_type': maintenanceType,
                  'maintenance_date': DateFormat('yyyy-MM-dd').format(selectedDate),
                  'description': descController.text,
                  'status': 'Scheduled',
                };
                await _repository.addMaintenance(data);
                Navigator.pop(context);
                _fetchData();
              },
              child: const Text('Schedule', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField(TextEditingController controller, String label) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(labelText: label),
      style: TextStyle(color: context.textColor),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: context.bgColor,
      appBar: AppBar(
        backgroundColor: context.surfaceColor,
        title: const Text('MAINTENANCE', style: TextStyle(color: kGold, fontWeight: FontWeight.bold, letterSpacing: 2)),
        actions: [
          const ThemeToggleButton(),
          IconButton(icon: const Icon(Icons.menu_rounded, color: kGold), onPressed: () => _scaffoldKey.currentState?.openEndDrawer()),
        ],
      ),
      endDrawer: const AdminDrawer(currentMenu: AdminMenu.maintenance),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: kGold))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _schedules.length,
              itemBuilder: (context, index) {
                final s = _schedules[index];
                return Card(
                  color: context.surfaceColor,
                  child: ExpansionTile(
                    leading: Icon(Icons.build_circle, color: _getStatusColor(s['status'])),
                    title: Text(s['maintenance_type'], style: TextStyle(color: context.textColor, fontWeight: FontWeight.bold)),
                    subtitle: Text('${s['maintenance_date']} | ${s['machines']?['machine_name'] ?? 'N/A'}', style: TextStyle(color: context.mutedTextColor)),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Drum: ${s['drums']?['drum_name'] ?? 'All Drums'}', style: TextStyle(color: context.textColor)),
                            Text('Description: ${s['description'] ?? 'No description'}', style: TextStyle(color: context.mutedTextColor)),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                if (s['status'] == 'Scheduled')
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                                    onPressed: () => _updateStatus(s['maintenance_id'], 'In Progress'),
                                    child: const Text('Start'),
                                  ),
                                if (s['status'] == 'In Progress')
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                                    onPressed: () => _updateStatus(s['maintenance_id'], 'Completed'),
                                    child: const Text('Complete'),
                                  ),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                  onPressed: () => _updateStatus(s['maintenance_id'], 'Cancelled'),
                                  child: const Text('Cancel'),
                                ),
                              ],
                            )
                          ],
                        ),
                      ),
                    ],
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

  Future<void> _updateStatus(String id, String status) async {
    await _repository.updateMaintenanceStatus(id, status);
    _fetchData();
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Scheduled': return Colors.blue;
      case 'In Progress': return Colors.orange;
      case 'Completed': return Colors.green;
      case 'Cancelled': return Colors.red;
      default: return Colors.grey;
    }
  }
}
