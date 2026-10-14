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
    String maintenanceReason = 'Routine Check & Cleaning';
    String spanTime = '1 Day';
    DateTime selectedDate = DateTime.now();
    final customReasonController = TextEditingController();
    final customSpanController = TextEditingController();

    final predefinedReasons = [
      'Routine Check & Cleaning',
      'Drum Belt Repair',
      'Bearing Lubrication',
      'Motor Overhaul',
      'Emergency Breakdown Repair',
      'Component Replacement',
      'Custom Reason / Other',
    ];

    final predefinedSpanTimes = [
      '1 Hour',
      '2 Hours',
      '4 Hours',
      '8 Hours',
      '1 Day',
      '2 Days',
      '3 Days',
      '1 Week',
      'Custom Duration',
    ];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final isCustomReason = maintenanceReason == 'Custom Reason / Other';
          final isCustomSpan = spanTime == 'Custom Duration';

          return AlertDialog(
            backgroundColor: context.surfaceColor,
            title: const Text('Schedule Maintenance', style: TextStyle(color: kGold, fontWeight: FontWeight.bold)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<String>(
                    value: selectedMachineId,
                    dropdownColor: context.surfaceColor,
                    style: TextStyle(color: context.textColor),
                    decoration: const InputDecoration(labelText: 'Machine'),
                    items: _machines
                        .map((m) => DropdownMenuItem(value: m['machine_id'].toString(), child: Text(m['machine_name'], style: TextStyle(color: context.textColor))))
                        .toList(),
                    onChanged: (v) => setDialogState(() {
                      selectedMachineId = v;
                      selectedDrumId = null;
                    }),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: selectedDrumId,
                    dropdownColor: context.surfaceColor,
                    style: TextStyle(color: context.textColor),
                    decoration: const InputDecoration(labelText: 'Drum (Optional)'),
                    items: _drums
                        .where((d) => d['machine_id'].toString() == selectedMachineId)
                        .map((d) => DropdownMenuItem(value: d['drum_id'].toString(), child: Text(d['drum_name'], style: TextStyle(color: context.textColor))))
                        .toList(),
                    onChanged: (v) => setDialogState(() => selectedDrumId = v),
                  ),
                  const SizedBox(height: 12),
                  
                  // Maintenance Reason Selection
                  Text('Reason for Maintenance', style: TextStyle(color: kGold, fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  DropdownButtonFormField<String>(
                    value: maintenanceReason,
                    dropdownColor: context.surfaceColor,
                    style: TextStyle(color: context.textColor),
                    decoration: const InputDecoration(border: OutlineInputBorder()),
                    items: predefinedReasons
                        .map((s) => DropdownMenuItem(value: s, child: Text(s, style: TextStyle(color: context.textColor))))
                        .toList(),
                    onChanged: (v) => setDialogState(() => maintenanceReason = v!),
                  ),
                  if (isCustomReason) ...[
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: customReasonController,
                      style: TextStyle(color: context.textColor),
                      decoration: const InputDecoration(hintText: 'Enter custom reason...', border: OutlineInputBorder()),
                    ),
                  ],

                  const SizedBox(height: 12),

                  // Span Time Selection
                  Text('Span Time / Duration', style: TextStyle(color: kGold, fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  DropdownButtonFormField<String>(
                    value: spanTime,
                    dropdownColor: context.surfaceColor,
                    style: TextStyle(color: context.textColor),
                    decoration: const InputDecoration(border: OutlineInputBorder()),
                    items: predefinedSpanTimes
                        .map((st) => DropdownMenuItem(value: st, child: Text(st, style: TextStyle(color: context.textColor))))
                        .toList(),
                    onChanged: (v) => setDialogState(() => spanTime = v!),
                  ),
                  if (isCustomSpan) ...[
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: customSpanController,
                      style: TextStyle(color: context.textColor),
                      decoration: const InputDecoration(hintText: 'Enter span time (e.g. 3 Days)...', border: OutlineInputBorder()),
                    ),
                  ],

                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('Start Date: ${DateFormat('yyyy-MM-dd').format(selectedDate)}', style: TextStyle(color: context.textColor, fontSize: 13)),
                    trailing: const Icon(Icons.calendar_today, color: kGold),
                    onTap: () async {
                      final d = await showDatePicker(context: context, initialDate: selectedDate, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)));
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
                  final finalReason = isCustomReason && customReasonController.text.trim().isNotEmpty
                      ? customReasonController.text.trim()
                      : maintenanceReason;
                  final finalSpan = isCustomSpan && customSpanController.text.trim().isNotEmpty
                      ? customSpanController.text.trim()
                      : spanTime;

                  final descText = 'Reason: $finalReason | Span Time: $finalSpan';

                  final data = {
                    'machine_id': selectedMachineId,
                    'drum_id': selectedDrumId,
                    'maintenance_type': finalReason,
                    'maintenance_date': DateFormat('yyyy-MM-dd').format(selectedDate),
                    'description': descText,
                    'remarks': 'Span time: $finalSpan',
                    'status': 'Scheduled',
                  };
                  await _repository.addMaintenance(data);

                  // Update machine/drum status to maintenance if scheduled for today
                  if (selectedMachineId != null) {
                    await _repository.updateMachine(selectedMachineId!, {
                      'status': 'maintenance',
                      'description': descText,
                    });
                  }
                  if (selectedDrumId != null) {
                    await _repository.updateDrum(selectedDrumId!, {
                      'status': 'maintenance',
                      'description': descText,
                    });
                  }

                  if (mounted) Navigator.pop(context);
                  _fetchData();
                },
                child: const Text('Schedule', style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: context.bgColor,
      appBar: AppBar(
        backgroundColor: context.surfaceColor,
        leadingWidth: 64,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16),
          child: _buildLogoMark(),
        ),
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
