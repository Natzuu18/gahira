import 'package:flutter/material.dart';
import '../../infrastructure/repositories/supabase_equipment_repository.dart';
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
  final SupabaseEquipmentRepository _repository = SupabaseEquipmentRepository();

  List<Map<String, dynamic>> _machines = [];
  List<Map<String, dynamic>> _drums = [];
  List<Map<String, dynamic>> _maintenance = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final machinesRes = await _repository.getMachines();
    final drumsRes = await _repository.getDrums();
    final maintRes = await _repository.getMaintenanceSchedules();

    setState(() {
      _machines = machinesRes.fold((l) => [], (r) => r);
      _drums = drumsRes.fold((l) => [], (r) => r);
      _maintenance = maintRes.fold((l) => [], (r) => r);
      _isLoading = false;
    });
  }

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
              Tab(text: 'Machines'),
              Tab(text: 'Drums'),
              Tab(text: 'Maintenance'),
            ],
          ),
        ),
        endDrawer: const OperatorDrawer(
          currentMenu: OperatorMenu.equipment,
          operatorName: 'Operator',
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: kGold))
            : TabBarView(
                children: [
                  _buildMachinesTab(),
                  _buildDrumsTab(),
                  _buildMaintenanceTab(),
                ],
              ),
      ),
    );
  }

  Widget _buildMachinesTab() {
    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: _machines.length,
        itemBuilder: (context, index) {
          final machine = _machines[index];
          return _buildEquipmentCard(
            id: machine['machine_id'],
            name: machine['machine_name'],
            code: machine['machine_code'],
            type: machine['machine_type'] ?? 'N/A',
            status: machine['status'],
            isMachine: true,
          );
        },
      ),
    );
  }

  Widget _buildDrumsTab() {
    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: _drums.length,
        itemBuilder: (context, index) {
          final drum = _drums[index];
          return _buildEquipmentCard(
            id: drum['drum_id'],
            name: drum['drum_name'],
            code: drum['drum_code'],
            type: 'Drum (Cap: ${drum['capacity'] ?? 'N/A'})',
            status: drum['status'],
            isMachine: false,
          );
        },
      ),
    );
  }

  Widget _buildMaintenanceTab() {
    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: _maintenance.length,
        itemBuilder: (context, index) {
          final maint = _maintenance[index];
          return _buildMaintenanceCard(maint);
        },
      ),
    );
  }

  Widget _buildEquipmentCard({
    required String id,
    required String name,
    required String code,
    required String type,
    required String status,
    required bool isMachine,
  }) {
    final statusColor = status.toLowerCase() == 'available'
        ? Colors.green
        : (status.toLowerCase() == 'maintenance' ? Colors.orange : Colors.red);

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
                  isMachine ? Icons.settings_input_component_rounded : Icons.inventory_2_rounded,
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
                      name,
                      style: TextStyle(
                        color: context.textColor,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      type,
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
                  status.toUpperCase(),
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
              _buildInfoChip('CODE', code),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () => _showUpdateStatusDialog(id, name, status, isMachine),
                icon: const Icon(Icons.edit_note_rounded, size: 16),
                label: const Text('Update Status'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kGold,
                  foregroundColor: kBlack,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMaintenanceCard(Map<String, dynamic> maint) {
    final status = maint['status'];
    final statusColor = status.toLowerCase() == 'scheduled'
        ? kGold
        : (status.toLowerCase() == 'ongoing' ? Colors.blue : Colors.green);

    final equipmentName = maint['machines']?['machine_name'] ?? maint['drums']?['drum_name'] ?? 'Unknown';

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
                      equipmentName,
                      style: TextStyle(
                        color: context.textColor,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      maint['maintenance_type'] ?? 'General Maintenance',
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
                  status.toUpperCase(),
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
              _buildInfoChip('DATE', maint['maintenance_date']),
              const SizedBox(width: 8),
              _buildInfoChip('TIME', '${maint['start_time']} - ${maint['end_time']}'),
            ],
          ),
          if (maint['remarks'] != null && maint['remarks'].toString().isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: kGold.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                maint['remarks'],
                style: TextStyle(color: context.textColor, fontSize: 13),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showMaintenanceNotesDialog(maint),
                  icon: const Icon(Icons.add_comment_rounded, size: 16),
                  label: const Text('Update Notes'),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: kGold.withOpacity(0.3)),
                    foregroundColor: context.textColor,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (status.toLowerCase() != 'completed')
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _updateMaintenanceStatus(maint['maintenance_id'], 'completed'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.withOpacity(0.8),
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Mark Complete'),
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

  void _showUpdateStatusDialog(String id, String name, String currentStatus, bool isMachine) {
    String selectedStatus = currentStatus.toLowerCase();
    final statuses = ['available', 'in_use', 'maintenance', 'inactive'];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: context.surfaceColor,
          title: Text('Update Condition: $name'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: statuses.map((status) => RadioListTile<String>(
              title: Text(status.toUpperCase(), style: TextStyle(color: context.textColor)),
              value: status,
              groupValue: selectedStatus,
              activeColor: kGold,
              onChanged: (val) => setDialogState(() => selectedStatus = val!),
            )).toList(),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: kGold),
              onPressed: () async {
                final res = isMachine 
                  ? await _repository.updateMachine(id, {'status': selectedStatus})
                  : await _repository.updateDrum(id, {'status': selectedStatus});
                
                Navigator.pop(context);
                res.fold(
                  (l) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.message))),
                  (_) => _loadData(),
                );
              },
              child: const Text('Update', style: TextStyle(color: kBlack)),
            ),
          ],
        ),
      ),
    );
  }

  void _showMaintenanceNotesDialog(Map<String, dynamic> maint) {
    final TextEditingController controller = TextEditingController(text: maint['remarks'] ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.surfaceColor,
        title: const Text('Update Maintenance Notes'),
        content: TextField(
          controller: controller,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: 'Enter maintenance details, parts replaced, etc.',
            border: OutlineInputBorder(),
          ),
          style: TextStyle(color: context.textColor),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: kGold),
            onPressed: () async {
              final res = await _repository.updateMaintenance(maint['maintenance_id'], {'remarks': controller.text});
              Navigator.pop(context);
              res.fold(
                (l) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.message))),
                (_) => _loadData(),
              );
            },
            child: const Text('Save', style: TextStyle(color: kBlack)),
          ),
        ],
      ),
    );
  }

  Future<void> _updateMaintenanceStatus(String id, String status) async {
    final res = await _repository.updateMaintenanceStatus(id, status);
    res.fold(
      (l) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.message))),
      (_) => _loadData(),
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
