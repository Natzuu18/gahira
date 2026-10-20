import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../infrastructure/repositories/supabase_equipment_repository.dart';
import '../shared_widgets/appColor.dart';
import '../shared_widgets/themeToggleButton.dart';

class EquipmentMaintenancePage extends StatefulWidget {
  const EquipmentMaintenancePage({super.key});

  @override
  State<EquipmentMaintenancePage> createState() =>
      _EquipmentMaintenancePageState();
}

class _EquipmentMaintenancePageState extends State<EquipmentMaintenancePage> {
  final SupabaseEquipmentRepository _repository = SupabaseEquipmentRepository();

  List<Map<String, dynamic>> _machines = [];
  List<Map<String, dynamic>> _drums = [];
  List<Map<String, dynamic>> _maintenance = [];
  bool _isLoading = true;
  String _machineQuery = '';
  String _drumQuery = '';
  String _maintenanceQuery = '';

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
          actions: [const ThemeToggleButton()],
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
    final query = _machineQuery.trim().toLowerCase();
    final machines = _machines.where((machine) {
      final searchable = [
        machine['machine_name'],
        machine['machine_code'],
        machine['machine_type'],
        machine['status'],
      ].whereType<Object>().join(' ').toLowerCase();
      return searchable.contains(query);
    }).toList();

    return RefreshIndicator(
      onRefresh: _loadData,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildSearchField(
                hint: 'Search machines by name, code, type, or status',
                onChanged: (value) => setState(() => _machineQuery = value),
              ),
              const SizedBox(height: 12),
              if (machines.isEmpty)
                _buildSearchEmptyState('No machines match your search.')
              else
                ...machines.map(
                  (machine) => _buildEquipmentCard(
                    id: machine['machine_id'],
                    name: machine['machine_name'],
                    code: machine['machine_code'],
                    type: machine['machine_type'] ?? 'N/A',
                    status: machine['status'],
                    isMachine: true,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDrumsTab() {
    final query = _drumQuery.trim().toLowerCase();
    final drums = _drums.where((drum) {
      final searchable = [
        drum['drum_name'],
        drum['drum_code'],
        drum['capacity'],
        drum['status'],
        drum['machines']?['machine_name'],
      ].whereType<Object>().join(' ').toLowerCase();
      return searchable.contains(query);
    }).toList();

    return RefreshIndicator(
      onRefresh: _loadData,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildSearchField(
                hint: 'Search drums by name, code, machine, or status',
                onChanged: (value) => setState(() => _drumQuery = value),
              ),
              const SizedBox(height: 12),
              if (drums.isEmpty)
                _buildSearchEmptyState('No drums match your search.')
              else
                ...drums.map(
                  (drum) => _buildEquipmentCard(
                    id: drum['drum_id'],
                    name: drum['drum_name'],
                    code: drum['drum_code'],
                    type: 'Drum (Cap: ${drum['capacity'] ?? 'N/A'})',
                    status: drum['status'],
                    isMachine: false,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMaintenanceTab() {
    final query = _maintenanceQuery.trim().toLowerCase();
    final maintenance = _maintenance.where((item) {
      final searchable = [
        item['maintenance_type'],
        item['maintenance_date'],
        item['status'],
        item['description'],
        item['machines']?['machine_name'],
        item['drums']?['drum_name'],
      ].whereType<Object>().join(' ').toLowerCase();
      return searchable.contains(query);
    }).toList();

    return RefreshIndicator(
      onRefresh: _loadData,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildSearchField(
                hint: 'Search maintenance by equipment, reason, or status',
                onChanged: (value) =>
                    setState(() => _maintenanceQuery = value),
              ),
              const SizedBox(height: 12),
              if (maintenance.isEmpty)
                _buildSearchEmptyState('No maintenance records match your search.')
              else
                ...maintenance.map(_buildMaintenanceCard),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchField({
    required String hint,
    required ValueChanged<String> onChanged,
  }) {
    return TextField(
      onChanged: onChanged,
      style: TextStyle(color: context.textColor),
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: const Icon(Icons.search_rounded, color: kGold),
        suffixIcon: Icon(Icons.tune_rounded, color: context.mutedTextColor),
        filled: true,
        fillColor: context.surfaceColor,
        contentPadding: const EdgeInsets.symmetric(vertical: 13),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: kGold.withValues(alpha: 0.18)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: kGold.withValues(alpha: 0.18)),
        ),
      ),
    );
  }

  Widget _buildSearchEmptyState(String message) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 42, horizontal: 20),
      child: Column(
        children: [
          Icon(Icons.search_off_rounded, color: context.mutedTextColor, size: 36),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: context.mutedTextColor, fontSize: 13),
          ),
        ],
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
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
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
                  isMachine
                      ? Icons.settings_input_component_rounded
                      : Icons.inventory_2_rounded,
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
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
              OutlinedButton.icon(
                onPressed: () => _showMaintenanceRequestDialog(
                  initialMachineId: isMachine ? id : null,
                  initialDrumId: isMachine ? null : id,
                  initialIsMachine: isMachine,
                ),
                icon: const Icon(Icons.build_circle_outlined, size: 16),
                label: const Text('Request Maintenance'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: kGold,
                  side: BorderSide(color: kGold.withValues(alpha: 0.45)),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
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

    final equipmentName =
        maint['machines']?['machine_name'] ??
        maint['drums']?['drum_name'] ??
        'Unknown';
    final remarks = maint['remarks']?.toString() ?? '';

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
                child: Icon(Icons.build_rounded, color: statusColor, size: 24),
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
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
              _buildInfoChip(
                'TIME',
                '${maint['start_time']} - ${maint['end_time']}',
              ),
            ],
          ),
          if (remarks.isNotEmpty && !remarks.startsWith('Evidence photo: ')) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: kGold.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                remarks,
                style: TextStyle(color: context.textColor, fontSize: 13),
              ),
            ),
          ],
          if (remarks.startsWith('Evidence photo: ')) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(
                remarks.substring('Evidence photo: '.length),
                height: 150,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          ],
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

  void _showMaintenanceRequestDialog({
    String? initialMachineId,
    String? initialDrumId,
    bool initialIsMachine = true,
  }) {
    String? selectedMachineId = initialMachineId;
    String? selectedDrumId = initialDrumId;
    if (initialDrumId != null) {
      final selectedDrum = _drums.cast<Map<String, dynamic>?>().firstWhere(
        (drum) => drum?['drum_id']?.toString() == initialDrumId,
        orElse: () => null,
      );
      selectedMachineId ??= selectedDrum?['machine_id']?.toString();
    }
    var isMachine = initialIsMachine;
    final reasonController = TextEditingController();
    PlatformFile? selectedPhoto;
    var isSubmitting = false;
    String? errorMessage;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setModalState) {
          final availableDrums = _drums
              .where(
                (drum) =>
                    drum['machine_id']?.toString() == selectedMachineId,
              )
              .toList();

          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
            ),
            child: Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.88,
              ),
              decoration: BoxDecoration(
                color: context.surfaceColor,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: context.mutedTextColor.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
                      shrinkWrap: true,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: kGold.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(
                                Icons.build_circle_outlined,
                                color: kGold,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Request Maintenance',
                                style: TextStyle(
                                  color: context.textColor,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: isSubmitting
                                  ? null
                                  : () => Navigator.pop(sheetContext),
                              icon: const Icon(Icons.close_rounded),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Send a maintenance request to an administrator. Equipment status will remain unchanged until it is reviewed.',
                          style: TextStyle(
                            color: context.mutedTextColor,
                            fontSize: 12,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          'REQUEST FOR',
                          style: TextStyle(
                            color: kGold,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 8),
                        SegmentedButton<bool>(
                          segments: const [
                            ButtonSegment<bool>(
                              value: true,
                              icon: Icon(Icons.precision_manufacturing),
                              label: Text('Machine'),
                            ),
                            ButtonSegment<bool>(
                              value: false,
                              icon: Icon(Icons.inventory_2_rounded),
                              label: Text('Drum'),
                            ),
                          ],
                          selected: {isMachine},
                          onSelectionChanged: isSubmitting
                              ? null
                              : (selection) => setModalState(() {
                                  isMachine = selection.first;
                                  selectedDrumId = null;
                                }),
                        ),
                        const SizedBox(height: 14),
                        DropdownButtonFormField<String>(
                          value: selectedMachineId,
                          dropdownColor: context.surfaceColor,
                          decoration: const InputDecoration(
                            labelText: 'Machine',
                            prefixIcon: Icon(Icons.precision_manufacturing),
                          ),
                          items: _machines
                              .map(
                                (machine) => DropdownMenuItem<String>(
                                  value: machine['machine_id'].toString(),
                                  child: Text(
                                    machine['machine_name']?.toString() ??
                                        'Machine',
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: isSubmitting
                              ? null
                              : (id) => setModalState(() {
                                  selectedMachineId = id;
                                  selectedDrumId = null;
                                }),
                        ),
                        if (!isMachine) ...[
                          const SizedBox(height: 14),
                          DropdownButtonFormField<String>(
                            value: selectedDrumId,
                            dropdownColor: context.surfaceColor,
                            decoration: const InputDecoration(
                              labelText: 'Drum',
                              prefixIcon: Icon(Icons.inventory_2_rounded),
                            ),
                            hint: Text(
                              availableDrums.isEmpty
                                  ? 'No drums for this machine'
                                  : 'Select drum',
                            ),
                            items: availableDrums
                                .map(
                                  (drum) => DropdownMenuItem<String>(
                                    value: drum['drum_id'].toString(),
                                    child: Text(
                                      drum['drum_name']?.toString() ?? 'Drum',
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: isSubmitting || availableDrums.isEmpty
                                ? null
                                : (id) => setModalState(
                                    () => selectedDrumId = id,
                                  ),
                          ),
                        ],
                        const SizedBox(height: 14),
                        TextField(
                          controller: reasonController,
                          enabled: !isSubmitting,
                          minLines: 3,
                          maxLines: 5,
                          style: TextStyle(color: context.textColor),
                          decoration: const InputDecoration(
                            labelText: 'Reason for maintenance',
                            hintText:
                                'Describe the fault or maintenance needed...',
                            alignLabelWithHint: true,
                          ),
                        ),
                        const SizedBox(height: 14),
                        OutlinedButton.icon(
                          onPressed: isSubmitting
                              ? null
                              : () async {
                                  try {
                                    final result = await FilePicker.platform
                                        .pickFiles(
                                          type: FileType.image,
                                          withData: true,
                                        );
                                    if (result != null &&
                                        result.files.isNotEmpty) {
                                      setModalState(() {
                                        selectedPhoto = result.files.single;
                                        errorMessage = null;
                                      });
                                    }
                                  } catch (error) {
                                    setModalState(
                                      () => errorMessage =
                                          'Could not select the photo: $error',
                                    );
                                  }
                                },
                          icon: const Icon(Icons.add_a_photo_outlined),
                          label: Text(
                            selectedPhoto == null
                                ? 'Add supporting photo'
                                : 'Change photo',
                          ),
                        ),
                        if (selectedPhoto?.bytes != null) ...[
                          const SizedBox(height: 10),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.memory(
                              selectedPhoto!.bytes!,
                              height: 150,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            selectedPhoto!.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: context.mutedTextColor,
                              fontSize: 11,
                            ),
                          ),
                        ],
                        if (errorMessage != null) ...[
                          const SizedBox(height: 10),
                          Text(
                            errorMessage!,
                            style: const TextStyle(
                              color: Colors.redAccent,
                              fontSize: 12,
                            ),
                          ),
                        ],
                        const SizedBox(height: 18),
                        FilledButton.icon(
                          onPressed: isSubmitting
                              ? null
                              : () async {
                                  final operatorId = Supabase
                                      .instance
                                      .client
                                      .auth
                                      .currentUser
                                      ?.id;
                                  if (operatorId == null) {
                                    setModalState(
                                      () => errorMessage =
                                          'Your session has expired. Please sign in again.',
                                    );
                                    return;
                                  }
                                  if (selectedMachineId == null ||
                                      (!isMachine && selectedDrumId == null)) {
                                    setModalState(
                                      () => errorMessage =
                                          'Select the machine and drum for this request.',
                                    );
                                    return;
                                  }
                                  if (reasonController.text.trim().isEmpty) {
                                    setModalState(
                                      () => errorMessage =
                                          'Enter a reason for the maintenance request.',
                                    );
                                    return;
                                  }
                                  if (selectedPhoto?.bytes == null) {
                                    setModalState(
                                      () => errorMessage =
                                          'Add a supporting photo before submitting.',
                                    );
                                    return;
                                  }

                                  setModalState(() {
                                    isSubmitting = true;
                                    errorMessage = null;
                                  });
                                  final result = await _repository
                                      .submitOperatorMaintenanceRequest(
                                        machineId: selectedMachineId,
                                        drumId: isMachine
                                            ? null
                                            : selectedDrumId,
                                        maintenanceType: isMachine
                                            ? 'Machine Maintenance Request'
                                            : 'Drum Maintenance Request',
                                        reason: reasonController.text.trim(),
                                        operatorId: operatorId,
                                        photo: selectedPhoto!,
                                      );
                                  if (!sheetContext.mounted) return;
                                  result.fold(
                                    (failure) => setModalState(() {
                                      isSubmitting = false;
                                      errorMessage = failure.message;
                                    }),
                                    (_) {
                                      Navigator.pop(sheetContext);
                                      _loadData();
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Maintenance request sent to the admin for review.',
                                          ),
                                        ),
                                      );
                                    },
                                  );
                                },
                          icon: isSubmitting
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.send_rounded),
                          label: Text(
                            isSubmitting ? 'Sending request...' : 'Send request',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    ).whenComplete(reasonController.dispose);
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
