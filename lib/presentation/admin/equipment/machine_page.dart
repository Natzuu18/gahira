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
        // Sorting Logic: Sort based on occupied capacity or whether status is 'in_use' first
        _machines.sort((a, b) {
          final aInUse = a['status']?.toString().toLowerCase() == 'in_use' ? 1 : 0;
          final bInUse = b['status']?.toString().toLowerCase() == 'in_use' ? 1 : 0;
          return bInUse.compareTo(aInUse);
        });
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
    
    // Normalize DB enum values to match dialog labels
    // DB enum expectation values: 'available', 'in_use', 'maintenance', 'inactive'
    String statusValue = 'available';
    if (machine != null) {
      statusValue = machine['status']?.toString().toLowerCase() ?? 'available';
    }

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
                  value: statusValue,
                  dropdownColor: context.surfaceColor,
                  decoration: const InputDecoration(labelText: 'Status'),
                  items: const [
                    DropdownMenuItem(value: 'available', child: Text('Available')),
                    DropdownMenuItem(value: 'maintenance', child: Text('Maintenance')),
                    DropdownMenuItem(value: 'inactive', child: Text('Inactive')),
                    DropdownMenuItem(value: 'in_use', child: Text('In Use')),
                  ],
                  onChanged: (v) => setDialogState(() => statusValue = v!),
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
                  'status': statusValue,
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

  void _showAddDrumDialog(String machineId) {
    final nameController = TextEditingController();
    final codeController = TextEditingController();
    final capController = TextEditingController();
    final descController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.surfaceColor,
        title: const Text('Add Drum to Machine', style: TextStyle(color: kGold, fontSize: 16, fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildField(nameController, 'Drum Name'),
              _buildField(codeController, 'Drum Code'),
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
                'machine_id': machineId,
                'drum_name': nameController.text,
                'drum_code': codeController.text,
                'description': descController.text,
                'status': 'available',
              };
              await _repository.addDrum(data);
              Navigator.pop(context);
              _fetchMachines();
            },
            child: const Text('Add Drum', style: TextStyle(color: kBlack, fontWeight: FontWeight.bold)),
          )
        ],
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
                final List<dynamic> drumsList = m['drums'] ?? [];
                
                return Card(
                  color: context.surfaceColor,
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ExpansionTile(
                    leading: const Icon(Icons.precision_manufacturing, color: kGold),
                    title: Text(m['machine_name'], style: TextStyle(color: context.textColor, fontWeight: FontWeight.bold)),
                    subtitle: Text('${m['machine_code']} | ${m['location']}', style: TextStyle(color: context.mutedTextColor)),
                    trailing: _buildStatusChip(m['status']),
                    childrenPadding: const EdgeInsets.all(16),
                    expandedAlignment: Alignment.centerLeft,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Allocated Drums (${drumsList.length})', style: const TextStyle(color: kGold, fontWeight: FontWeight.bold, fontSize: 13)),
                          TextButton.icon(
                            onPressed: () => _showAddDrumDialog(m['machine_id']),
                            icon: const Icon(Icons.add, size: 16, color: kGold),
                            label: const Text('Add Drum', style: TextStyle(color: kGold, fontSize: 12, fontWeight: FontWeight.bold)),
                          )
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (drumsList.isEmpty)
                        Text('No drums allocated to this machine.', style: TextStyle(color: context.mutedTextColor, fontSize: 12))
                      else
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: drumsList.map((d) {
                            final dStatus = d['status']?.toString().toLowerCase() ?? 'available';
                            final dColor = dStatus == 'available' ? Colors.green : Colors.orange;
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: context.bgColor,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: kGold.withOpacity(0.15)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.reorder_rounded, size: 14, color: kGold),
                                  const SizedBox(width: 6),
                                  Text(d['drum_name'] ?? 'Drum', style: TextStyle(color: context.textColor, fontSize: 12)),
                                  const SizedBox(width: 6),
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: BoxDecoration(color: dColor, shape: BoxShape.circle),
                                  )
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      const SizedBox(height: 12),
                      const Divider(),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () => _showAddEditDialog(m),
                          child: const Text('Edit Machine details', style: TextStyle(color: Colors.grey, fontSize: 12)),
                        ),
                      )
                    ],
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
    final s = status.toLowerCase();
    Color color = s == 'available' ? Colors.green : (s == 'inactive' ? Colors.red : Colors.orange);
    String label = status.toUpperCase();
    if (s == 'available') label = 'AVAILABLE';
    if (s == 'maintenance') label = 'MAINTENANCE';
    if (s == 'inactive') label = 'INACTIVE';
    if (s == 'in_use') label = 'IN USE';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: color)),
      child: Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }
}
