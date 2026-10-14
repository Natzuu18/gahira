import 'package:flutter/material.dart';
import '../../../infrastructure/repositories/supabase_equipment_repository.dart';
import '../../shared_widgets/appColor.dart';
import '../../shared_widgets/adminDrawer.dart';
import '../../shared_widgets/themeToggleButton.dart';

class DrumPage extends StatefulWidget {
  const DrumPage({super.key});

  @override
  State<DrumPage> createState() => _DrumPageState();
}

class _DrumPageState extends State<DrumPage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final _repository = SupabaseEquipmentRepository();
  List<Map<String, dynamic>> _drums = [];
  List<Map<String, dynamic>> _machines = [];
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

    machinesRes.fold((f) => null, (list) => _machines = list);
    drumsRes.fold(
      (failure) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(failure.message))),
      (list) => setState(() {
        _drums = list;
        _isLoading = false;
      }),
    );
  }

  void _showAddEditDialog([Map<String, dynamic>? drum]) {
    final isEdit = drum != null;
    final nameController = TextEditingController(text: drum?['drum_name']);
    final codeController = TextEditingController(text: drum?['drum_code']);
    final capacityController = TextEditingController(text: drum?['capacity']?.toString());
    String? selectedMachineId = drum?['machine_id'];
    String status = drum?['status'] ?? 'Available';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: context.surfaceColor,
          title: Text(isEdit ? 'Edit Drum' : 'Add Drum', style: const TextStyle(color: kGold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: selectedMachineId,
                  dropdownColor: context.surfaceColor,
                  decoration: const InputDecoration(labelText: 'Machine (Ball Mill)'),
                  items: _machines
                      .map((m) => DropdownMenuItem(value: m['machine_id'].toString(), child: Text(m['machine_name'], style: TextStyle(color: context.textColor))))
                      .toList(),
                  onChanged: (v) => setDialogState(() => selectedMachineId = v),
                ),
                _buildField(nameController, 'Drum Name'),
                _buildField(codeController, 'Drum Code'),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: status,
                  dropdownColor: context.surfaceColor,
                  decoration: const InputDecoration(labelText: 'Status'),
                  items: ['Available', 'In Use', 'Maintenance', 'Out of Order']
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
                  'drum_name': nameController.text,
                  'drum_code': codeController.text,
                  'machine_id': selectedMachineId,
                  'status': status,
                };
                if (isEdit) {
                  await _repository.updateDrum(drum['drum_id'], data);
                } else {
                  await _repository.addDrum(data);
                }
                Navigator.pop(context);
                _fetchData();
              },
              child: Text(isEdit ? 'Update' : 'Add', style: const TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField(TextEditingController controller, String label, {TextInputType? keyboardType}) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
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
        title: const Text('DRUMS', style: TextStyle(color: kGold, fontWeight: FontWeight.bold, letterSpacing: 2)),
        actions: [
          const ThemeToggleButton(),
          IconButton(icon: const Icon(Icons.menu_rounded, color: kGold), onPressed: () => _scaffoldKey.currentState?.openEndDrawer()),
        ],
      ),
      endDrawer: const AdminDrawer(currentMenu: AdminMenu.drums),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: kGold))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _drums.length,
              itemBuilder: (context, index) {
                final d = _drums[index];
                final statusLower = d['status']?.toString().toLowerCase() ?? 'available';
                final isMaintenance = statusLower == 'maintenance';
                final desc = d['description']?.toString();

                return Card(
                  color: context.surfaceColor,
                  child: Column(
                    children: [
                      ListTile(
                        leading: Icon(Icons.reorder, color: isMaintenance ? Colors.orange : kGold),
                        title: Text(d['drum_name'], style: TextStyle(color: context.textColor, fontWeight: FontWeight.bold)),
                        subtitle: Text('${d['drum_code']} | ${d['machines']?['machine_name'] ?? 'No Machine'}', style: TextStyle(color: context.mutedTextColor)),
                        trailing: _buildStatusChip(d['status'] ?? 'Available'),
                        onTap: () => _showAddEditDialog(d),
                      ),
                      if (isMaintenance && desc != null && desc.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.orange.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Row(
                                  children: [
                                    Icon(Icons.build_circle_outlined, color: Colors.orange, size: 14),
                                    SizedBox(width: 6),
                                    Text(
                                      'Maintenance Reason',
                                      style: TextStyle(
                                        color: Colors.orange,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  desc,
                                  style: TextStyle(
                                    color: context.textColor,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
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
    Color color = status == 'Available' ? Colors.green : (status == 'Out of Order' ? Colors.red : Colors.orange);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: color)),
      child: Text(status, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }
}
