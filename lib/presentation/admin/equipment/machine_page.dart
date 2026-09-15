import 'package:flutter/material.dart';
import '../../../infrastructure/repositories/supabase_equipment_repository.dart';
import '../../shared_widgets/appColor.dart';
import '../../shared_widgets/adminDrawer.dart';
import '../../shared_widgets/themeToggleButton.dart';

class MachinePage extends StatefulWidget {
  const MachinePage({super.key});

  @override
  State<MachinePage> createState() => _MachinePageState();
}

class _MachinePageState extends State<MachinePage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final _repository = SupabaseEquipmentRepository();
  List<Map<String, dynamic>> _machines = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchMachines();
  }

  Future<void> _fetchMachines() async {
    setState(() => _isLoading = true);
    final result = await _repository.getMachines();
    result.fold(
      (failure) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(failure.message))),
      (list) => setState(() {
        _machines = list;
        _isLoading = false;
      }),
    );
  }

  void _showAddEditDialog([Map<String, dynamic>? machine]) {
    final isEdit = machine != null;
    final nameController = TextEditingController(text: machine?['machine_name']);
    final codeController = TextEditingController(text: machine?['machine_code']);
    final typeController = TextEditingController(text: machine?['machine_type'] ?? 'Ball Mill');
    final locController = TextEditingController(text: machine?['location']);
    String status = machine?['status'] ?? 'Available';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: context.surfaceColor,
          title: Text(isEdit ? 'Edit Machine' : 'Add Machine', style: const TextStyle(color: kGold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildField(nameController, 'Machine Name'),
                _buildField(codeController, 'Machine Code'),
                _buildField(typeController, 'Type'),
                _buildField(locController, 'Location'),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: status,
                  dropdownColor: context.surfaceColor,
                  decoration: const InputDecoration(labelText: 'Status'),
                  items: ['Available', 'Under Maintenance', 'Out of Order']
                      .map((s) => DropdownMenuItem(value: s, child: Text(s, style: TextStyle(color: context.textColor))))
                      .toList(),
                  onChanged: (v) => setDialogState(() => status = v!),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: kGold),
              onPressed: () async {
                final data = {
                  'machine_name': nameController.text,
                  'machine_code': codeController.text,
                  'machine_type': typeController.text,
                  'location': locController.text,
                  'status': status,
                };
                if (isEdit) {
                  await _repository.updateMachine(machine['machine_id'], data);
                } else {
                  await _repository.addMachine(data);
                }
                Navigator.pop(context);
                _fetchMachines();
              },
              child: Text(isEdit ? 'Update' : 'Add', style: const TextStyle(color: Colors.white)),
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
        title: const Text('MACHINES', style: TextStyle(color: kGold, fontWeight: FontWeight.bold, letterSpacing: 2)),
        actions: [
          const ThemeToggleButton(),
          IconButton(icon: const Icon(Icons.menu_rounded, color: kGold), onPressed: () => _scaffoldKey.currentState?.openEndDrawer()),
        ],
      ),
      endDrawer: const AdminDrawer(currentMenu: AdminMenu.machines),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: kGold))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _machines.length,
              itemBuilder: (context, index) {
                final m = _machines[index];
                return Card(
                  color: context.surfaceColor,
                  child: ListTile(
                    leading: const Icon(Icons.precision_manufacturing, color: kGold),
                    title: Text(m['machine_name'], style: TextStyle(color: context.textColor, fontWeight: FontWeight.bold)),
                    subtitle: Text('${m['machine_code']} | ${m['location']}', style: TextStyle(color: context.mutedTextColor)),
                    trailing: _buildStatusChip(m['status']),
                    onTap: () => _showAddEditDialog(m),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: kGold,
        onPressed: () => _showAddEditDialog(),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color color = status == 'Available' ? Colors.green : (status == 'Out of Order' ? Colors.red : Colors.orange);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: color)),
      child: Text(status, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }
}
