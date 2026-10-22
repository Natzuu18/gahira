import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../infrastructure/repositories/supabase_equipment_repository.dart';
import '../../../infrastructure/repositories/supabase_service_request_repository.dart';
import 'maintenance_page.dart';
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
  final _serviceRequestRepository = SupabaseServiceRequestRepository();
  List<Map<String, dynamic>> _machines = [];
  bool _isLoading = true;
  final Set<String> _resolvingEmergencyEquipmentIds = {};

  String _searchQuery = '';
  String _selectedFilter = 'Fully In Use';

  @override
  void initState() {
    super.initState();
    _fetchMachines();
  }

  Future<void> _fetchMachines() async {
    setState(() => _isLoading = true);
    final result = await _repository.getMachines();
    result.fold(
      (failure) => ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(failure.message))),
      (list) => setState(() {
        _machines = list;
        // Sorting Logic: Sort based on whether status is 'in_use' or 'maintenance'
        _machines.sort((a, b) {
          final aInUse = a['status']?.toString().toLowerCase() == 'in_use'
              ? 1
              : 0;
          final bInUse = b['status']?.toString().toLowerCase() == 'in_use'
              ? 1
              : 0;
          return bInUse.compareTo(aInUse);
        });
        _isLoading = false;
      }),
    );
  }

  List<Map<String, dynamic>> get _filteredMachines {
    return _machines.where((m) {
      // 1. Search Query Filter
      final query = _searchQuery.toLowerCase().trim();
      final name = m['machine_name']?.toString().toLowerCase() ?? '';
      final code = m['machine_code']?.toString().toLowerCase() ?? '';
      final location = m['location']?.toString().toLowerCase() ?? '';
      final matchesSearch =
          query.isEmpty ||
          name.contains(query) ||
          code.contains(query) ||
          location.contains(query);

      if (!matchesSearch) return false;

      // 2. Status Filter
      final status = m['status']?.toString().toLowerCase() ?? 'available';
      final drums = m['drums'];
      final drumList = drums is List ? drums : const [];
      final hasAvailableDrum = drumList.any((drum) {
        return drum is Map &&
            drum['status']?.toString().toLowerCase() == 'available';
      });
      if (_selectedFilter == 'Fully In Use') {
        return drumList.isNotEmpty && !hasAvailableDrum;
      }
      if (_selectedFilter == 'Available') {
        return status == 'available' ||
            (status == 'in_use' && hasAvailableDrum);
      } else if (_selectedFilter == 'Maintenance') {
        return status == 'maintenance';
      }

      return true;
    }).toList();
  }

  void _showSetMaintenanceDialog(Map<String, dynamic> item, bool isMachine) {
    String selectedReason = 'Routine Check & Cleaning';
    String selectedSpanTime = '1 Day';
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
          final isCustomReason = selectedReason == 'Custom Reason / Other';
          final isCustomSpan = selectedSpanTime == 'Custom Duration';

          return AlertDialog(
            backgroundColor: context.surfaceColor,
            title: Row(
              children: [
                const Icon(Icons.build_circle_outlined, color: Colors.orange),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Set Maintenance: ${item['machine_name'] ?? item['drum_name']}',
                    style: TextStyle(
                      color: context.textColor,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Select or enter the reason for maintenance and expected duration.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),

                  // Reason Selection
                  Text(
                    'Reason for Maintenance',
                    style: TextStyle(
                      color: kGold,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: selectedReason,
                    dropdownColor: context.surfaceColor,
                    style: TextStyle(color: context.textColor),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: context.bgColor,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    items: predefinedReasons.map((r) {
                      return DropdownMenuItem(
                        value: r,
                        child: Text(
                          r,
                          style: TextStyle(color: context.textColor),
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null)
                        setDialogState(() => selectedReason = val);
                    },
                  ),

                  if (isCustomReason) ...[
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: customReasonController,
                      style: TextStyle(color: context.textColor),
                      decoration: InputDecoration(
                        hintText: 'Enter custom reason...',
                        hintStyle: TextStyle(
                          color: context.mutedTextColor,
                          fontSize: 12,
                        ),
                        filled: true,
                        fillColor: context.bgColor,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),

                  // Span Time Selection
                  Text(
                    'Maintenance Span Time / Duration',
                    style: TextStyle(
                      color: kGold,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: selectedSpanTime,
                    dropdownColor: context.surfaceColor,
                    style: TextStyle(color: context.textColor),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: context.bgColor,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    items: predefinedSpanTimes.map((st) {
                      return DropdownMenuItem(
                        value: st,
                        child: Text(
                          st,
                          style: TextStyle(color: context.textColor),
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null)
                        setDialogState(() => selectedSpanTime = val);
                    },
                  ),

                  if (isCustomSpan) ...[
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: customSpanController,
                      style: TextStyle(color: context.textColor),
                      decoration: InputDecoration(
                        hintText: 'Enter duration (e.g., 5 Hours, 4 Days)...',
                        hintStyle: TextStyle(
                          color: context.mutedTextColor,
                          fontSize: 12,
                        ),
                        filled: true,
                        fillColor: context.bgColor,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                onPressed: () async {
                  final finalReason =
                      isCustomReason &&
                          customReasonController.text.trim().isNotEmpty
                      ? customReasonController.text.trim()
                      : selectedReason;
                  final finalSpan =
                      isCustomSpan &&
                          customSpanController.text.trim().isNotEmpty
                      ? customSpanController.text.trim()
                      : selectedSpanTime;

                  final descText =
                      'Reason: $finalReason | Span Time: $finalSpan';

                  Navigator.pop(context);

                  if (isMachine) {
                    await _applyMachineMaintenance(
                      item,
                      descText,
                      finalReason,
                      finalSpan,
                    );
                  } else {
                    await _applyDrumMaintenance(
                      item,
                      descText,
                      finalReason,
                      finalSpan,
                    );
                  }
                },
                child: const Text(
                  'Confirm Maintenance',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _applyMachineMaintenance(
    Map<String, dynamic> machine,
    String descText,
    String reason,
    String spanTime,
  ) async {
    final machineId = machine['machine_id'].toString();
    setState(() => _isLoading = true);

    String? error;
    final machineResult = await _repository.updateMachine(machineId, {
      'status': 'maintenance',
      'description': descText,
    });
    machineResult.fold((failure) => error = failure.message, (_) {});

    final List<dynamic> drums = machine['drums'] ?? [];
    for (final drum in drums) {
      if (error != null) break;
      final drumId = drum['drum_id'].toString();
      final result = await _repository.updateDrum(drumId, {
        'status': 'maintenance',
        'description': descText,
      });
      result.fold((failure) => error = failure.message, (_) {});
    }

    if (error != null) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error!), backgroundColor: Colors.red),
        );
      }
      await _fetchMachines();
      return;
    }

    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final maintenanceResult = await _repository.addMaintenance({
      'machine_id': machineId,
      'maintenance_type': reason,
      'maintenance_date': todayStr,
      'start_time': '08:00:00',
      'end_time': '17:00:00',
      'description': descText,
      'remarks': 'Span time: $spanTime',
      'status': 'ongoing',
    });
    maintenanceResult.fold((failure) => error = failure.message, (_) {});

    if (error != null) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error!), backgroundColor: Colors.red),
        );
      }
      await _fetchMachines();
      return;
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${machine['machine_name']} set to Maintenance ($reason, $spanTime)',
          ),
          backgroundColor: Colors.orange,
        ),
      );
    }

    _fetchMachines();
  }

  Future<void> _restoreMachineAvailable(Map<String, dynamic> machine) async {
    final machineId = machine['machine_id'].toString();
    setState(() => _isLoading = true);

    await _repository.updateMachine(machineId, {
      'status': 'available',
      'description': null,
    });

    final List<dynamic> drums = machine['drums'] ?? [];
    for (final drum in drums) {
      final drumId = drum['drum_id'].toString();
      if (drum['status']?.toString().toLowerCase() == 'maintenance') {
        await _repository.updateDrum(drumId, {
          'status': 'available',
          'description': null,
        });
      }
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${machine['machine_name']} restored to Available.'),
          backgroundColor: Colors.green,
        ),
      );
    }

    _fetchMachines();
  }

  Future<void> _resolveEmergencyForEquipment({
    required String machineId,
    String? drumId,
    required String equipmentName,
  }) async {
    final adminId = Supabase.instance.client.auth.currentUser?.id;
    if (adminId == null) return;

    final equipmentId = drumId ?? machineId;
    if (_resolvingEmergencyEquipmentIds.contains(equipmentId)) return;
    setState(() => _resolvingEmergencyEquipmentIds.add(equipmentId));

    final batchesResult = await _serviceRequestRepository
        .getActiveMillingBatches();
    List<Map<String, dynamic>>? batches;
    batchesResult.fold<void>((failure) {
      if (mounted) {
        setState(() => _resolvingEmergencyEquipmentIds.remove(equipmentId));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(failure.message), backgroundColor: Colors.red),
        );
      }
    }, (value) {
      batches = value;
    });
    if (batches == null) return;

    Map<String, dynamic>? matchingBatch;
    for (final batch in batches!) {
      final matchesEquipment = drumId != null
          ? batch['drum_id']?.toString() == drumId
          : batch['machine_id']?.toString() == machineId;
      if (matchesEquipment) {
        matchingBatch = batch;
        break;
      }
    }

    if (matchingBatch == null) {
      if (mounted) {
        setState(() => _resolvingEmergencyEquipmentIds.remove(equipmentId));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No active service was found for $equipmentName.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    final result = await _serviceRequestRepository.resolveEmergencyStop(
      requestId: matchingBatch['service_request_id'].toString(),
      adminId: adminId,
    );
    if (!mounted) return;

    result.fold(
      (failure) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(failure.message), backgroundColor: Colors.red),
      ),
      (_) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '$equipmentName emergency resolved. The operator can continue the process.',
          ),
          backgroundColor: Colors.orange,
        ),
      ),
    );
    setState(() => _resolvingEmergencyEquipmentIds.remove(equipmentId));
    await _fetchMachines();
  }

  Future<void> _applyDrumMaintenance(
    Map<String, dynamic> drum,
    String descText,
    String reason,
    String spanTime,
  ) async {
    final drumId = drum['drum_id'].toString();
    setState(() => _isLoading = true);

    String? error;
    final drumResult = await _repository.updateDrum(drumId, {
      'status': 'maintenance',
      'description': descText,
    });
    drumResult.fold((failure) => error = failure.message, (_) {});

    if (error != null) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error!), backgroundColor: Colors.red),
        );
      }
      await _fetchMachines();
      return;
    }

    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final maintenanceResult = await _repository.addMaintenance({
      'machine_id': drum['machine_id'],
      'drum_id': drumId,
      'maintenance_type': reason,
      'maintenance_date': todayStr,
      'start_time': '08:00:00',
      'end_time': '17:00:00',
      'description': descText,
      'remarks': 'Span time: $spanTime',
      'status': 'ongoing',
    });
    maintenanceResult.fold((failure) => error = failure.message, (_) {});

    if (error != null) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error!), backgroundColor: Colors.red),
        );
      }
      await _fetchMachines();
      return;
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Drum "${drum['drum_name']}" set to Maintenance ($reason, $spanTime)',
          ),
          backgroundColor: Colors.orange,
        ),
      );
    }

    _fetchMachines();
  }

  Future<void> _restoreDrumAvailable(Map<String, dynamic> drum) async {
    final drumId = drum['drum_id'].toString();
    setState(() => _isLoading = true);

    await _repository.updateDrum(drumId, {
      'status': 'available',
      'description': null,
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Drum "${drum['drum_name']}" restored to Available.'),
          backgroundColor: Colors.green,
        ),
      );
    }

    _fetchMachines();
  }

  void _showAddEditDialog([Map<String, dynamic>? machine]) {
    final isEdit = machine != null;
    final nameController = TextEditingController(
      text: machine?['machine_name'],
    );
    final codeController = TextEditingController(
      text: machine?['machine_code'],
    );
    final typeController = TextEditingController(
      text: machine?['machine_type'] ?? 'Ball Mill',
    );
    final locController = TextEditingController(text: machine?['location']);

    String statusValue = 'available';
    if (machine != null) {
      statusValue = machine['status']?.toString().toLowerCase() ?? 'available';
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: context.surfaceColor,
          title: Text(
            isEdit ? 'Edit Machine' : 'Add Machine',
            style: const TextStyle(color: kGold),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildField(nameController, 'Machine Name'),
                const SizedBox(height: 20),
                _buildField(codeController, 'Machine Code'),
                const SizedBox(height: 20),
                _buildField(typeController, 'Type'),
                const SizedBox(height: 20),
                _buildField(locController, 'Location'),
                const SizedBox(height: 20),
                DropdownButtonFormField<String>(
                  value: statusValue,
                  dropdownColor: context.surfaceColor,
                  decoration: const InputDecoration(labelText: 'Status'),
                  items: const [
                    DropdownMenuItem(
                      value: 'available',
                      child: Text('Available'),
                    ),
                    DropdownMenuItem(
                      value: 'maintenance',
                      child: Text('Maintenance'),
                    ),
                    DropdownMenuItem(
                      value: 'inactive',
                      child: Text('Inactive'),
                    ),
                    DropdownMenuItem(value: 'in_use', child: Text('In Use')),
                  ],
                  onChanged: (v) => setDialogState(() => statusValue = v!),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
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
                  if (statusValue == 'maintenance') {
                    final List<dynamic> drums = machine['drums'] ?? [];
                    for (final drum in drums) {
                      await _repository.updateDrum(drum['drum_id'].toString(), {
                        'status': 'maintenance',
                      });
                    }
                  }
                } else {
                  await _repository.addMachine(data);
                }
                if (mounted) Navigator.pop(context);
                _fetchMachines();
              },
              child: Text(
                isEdit ? 'Update' : 'Add',
                style: const TextStyle(color: Colors.white),
              ),
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
    final descController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.surfaceColor,
        title: const Text(
          'Add Drum to Machine',
          style: TextStyle(
            color: kGold,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
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
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
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
              if (mounted) Navigator.pop(context);
              _fetchMachines();
            },
            child: const Text(
              'Add Drum',
              style: TextStyle(color: kBlack, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogoMark() {    return Image.asset(
      'assets/img/EGReS.png',
      width: 34,
      height: 34,
      fit: BoxFit.contain,
    );
  }

  Widget _buildSearchAndFilterHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: context.surfaceColor,
      child: Column(
        children: [
          // Search Bar
          TextField(
            style: TextStyle(color: context.textColor),
            cursorColor: kGold,
            decoration: InputDecoration(
              hintText: 'Search by machine name, code, or location...',
              hintStyle: TextStyle(color: context.mutedTextColor, fontSize: 13),
              prefixIcon: const Icon(Icons.search, color: kGold),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, color: kGold),
                      onPressed: () => setState(() => _searchQuery = ''),
                    )
                  : null,
              filled: true,
              fillColor: context.bgColor,
              contentPadding: const EdgeInsets.symmetric(
                vertical: 12,
                horizontal: 16,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: kGold.withValues(alpha: 0.2)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: kGold.withValues(alpha: 0.2)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: kGold, width: 1.5),
              ),
            ),
            onChanged: (val) => setState(() => _searchQuery = val),
          ),
          const SizedBox(height: 12),
          // Filter Chips & Operator Maintenance Request Reviews
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _buildFilterChip('Fully In Use'),
              _buildFilterChip('Available'),
              _buildFilterChip('Maintenance'),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  minimumSize: Size.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const MaintenancePage(),
                    ),
                  );
                  if (mounted) await _fetchMachines();
                },
                icon: const Icon(Icons.fact_check_outlined, size: 16),
                label: const Text(
                  'Review Requests',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label) {
    final isSelected = _selectedFilter == label;
    final displayLabel = label == 'Maintenance' ? 'On Maintenance' : label;
    return ChoiceChip(
      label: Text(
        displayLabel,
        style: TextStyle(
          color: isSelected ? kBlack : context.textColor,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          fontSize: 12,
        ),
      ),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() => _selectedFilter = label);
        }
      },
      selectedColor: kGold,
      backgroundColor: context.bgColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected ? kGold : kGold.withValues(alpha: 0.3),
        ),
      ),
      showCheckmark: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final displayedMachines = _filteredMachines;

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
        title: const Text(
          'MACHINES',
          style: TextStyle(
            color: kGold,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
          ),
        ),
        actions: const [ThemeToggleButton(), SizedBox(width: 8)],
      ),
      endDrawer: const AdminDrawer(currentMenu: AdminMenu.machines),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: kGold))
          : Column(
              children: [
                _buildSearchAndFilterHeader(),
                Expanded(
                  child: displayedMachines.isEmpty
                      ? Center(
                          child: Text(
                            'No machines found.',
                            style: TextStyle(
                              color: context.mutedTextColor,
                              fontSize: 13,
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: displayedMachines.length,
                          itemBuilder: (context, index) {
                            final m = displayedMachines[index];
                            final List<dynamic> drumsList = m['drums'] ?? [];
                            final isMachineInMaintenance =
                                m['status']?.toString().toLowerCase() ==
                                'maintenance';
                            final isMachineEmergencyStopped =
                                m['status']?.toString().toLowerCase() ==
                                'emergency_stop';

                            return Card(
                              color: context.surfaceColor,
                              margin: const EdgeInsets.only(bottom: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(
                                  color: isMachineEmergencyStopped
                                      ? Colors.red
                                      : Colors.transparent,
                                  width: isMachineEmergencyStopped ? 1.5 : 0,
                                ),
                              ),
                              child: ExpansionTile(
                                leading: const Icon(
                                  Icons.precision_manufacturing,
                                  color: kGold,
                                ),
                                title: Text(
                                  m['machine_name'],
                                  style: TextStyle(
                                    color: context.textColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: Text(
                                  '${m['machine_code']} | ${m['location']}',
                                  style: TextStyle(
                                    color: context.mutedTextColor,
                                  ),
                                ),
                                trailing: _buildStatusChip(m['status']),
                                childrenPadding: const EdgeInsets.all(16),
                                expandedAlignment: Alignment.centerLeft,
                                children: [
                                  // Allocated drums section header
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Allocated Drums (${drumsList.length})',
                                        style: const TextStyle(
                                          color: kGold,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                      TextButton.icon(
                                        onPressed: () => _showAddDrumDialog(
                                          m['machine_id'].toString(),
                                        ),
                                        icon: const Icon(
                                          Icons.add,
                                          size: 16,
                                          color: kGold,
                                        ),
                                        label: const Text(
                                          'Add Drum',
                                          style: TextStyle(
                                            color: kGold,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),

                                  if (drumsList.isEmpty)
                                    Text(
                                      'No drums allocated to this machine.',
                                      style: TextStyle(
                                        color: context.mutedTextColor,
                                        fontSize: 12,
                                      ),
                                    )
                                  else
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: drumsList.map((d) {
                                        final dStatus =
                                            d['status']
                                                ?.toString()
                                                .toLowerCase() ??
                                            'available';
                                        final isDrumMaintenance =
                                            dStatus == 'maintenance' ||
                                            isMachineInMaintenance;
                                        final isDrumEmergencyStopped =
                                            dStatus == 'emergency_stop';
                                        final dColor = isDrumMaintenance
                                            ? Colors.orange
                                            : (dStatus == 'available'
                                                  ? Colors.green
                                                  : Colors.red);
                                        final dStatusLabel =
                                            isMachineEmergencyStopped
                                            ? 'Machine Stop'
                                            : isMachineInMaintenance
                                            ? 'Machine Maint.'
                                            : (isDrumMaintenance
                                                  ? 'Maintenance'
                                                  : dStatus.toUpperCase());

                                        return InkWell(
                                          onTap: () {
                                            if (isMachineEmergencyStopped ||
                                                isDrumEmergencyStopped) {
                                              _resolveEmergencyForEquipment(
                                                machineId: m['machine_id']
                                                    .toString(),
                                                drumId: isDrumEmergencyStopped
                                                    ? d['drum_id'].toString()
                                                    : null,
                                                equipmentName:
                                                    isDrumEmergencyStopped
                                                    ? d['drum_name']?.toString() ??
                                                          'Drum'
                                                    : m['machine_name']
                                                          ?.toString() ??
                                                          'Machine',
                                              );
                                            } else if (isDrumMaintenance &&
                                                !isMachineInMaintenance) {
                                              _restoreDrumAvailable(d);
                                            } else if (!isMachineInMaintenance) {
                                              _showSetMaintenanceDialog(
                                                d,
                                                false,
                                              );
                                            } else {
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                const SnackBar(
                                                  content: Text(
                                                    'Cannot change drum status while parent machine is under Maintenance.',
                                                  ),
                                                  backgroundColor:
                                                      Colors.redAccent,
                                                ),
                                              );
                                            }
                                          },
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 6,
                                            ),
                                            decoration: BoxDecoration(
                                              color: context.bgColor,
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              border: Border.all(
                                                color: isMachineEmergencyStopped ||
                                                        isDrumEmergencyStopped
                                                    ? Colors.red
                                                    : isDrumMaintenance
                                                    ? Colors.orange.withValues(
                                                        alpha: 0.5,
                                                      )
                                                    : kGold.withValues(
                                                        alpha: 0.2,
                                                      ),
                                              ),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  isMachineEmergencyStopped ||
                                                          isDrumEmergencyStopped
                                                      ? Icons.warning_amber_rounded
                                                      : Icons.reorder_rounded,
                                                  size: 14,
                                                  color: isMachineEmergencyStopped ||
                                                          isDrumEmergencyStopped
                                                      ? Colors.red
                                                      : isDrumMaintenance
                                                      ? Colors.orange
                                                      : kGold,
                                                ),
                                                const SizedBox(width: 6),
                                                Text(
                                                  d['drum_name'] ?? 'Drum',
                                                  style: TextStyle(
                                                    color: context.textColor,
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                                const SizedBox(width: 6),
                                                Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 5,
                                                        vertical: 1,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: (isMachineEmergencyStopped ||
                                                                isDrumEmergencyStopped
                                                            ? Colors.red
                                                            : dColor).withValues(
                                                      alpha: 0.15,
                                                    ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          4,
                                                        ),
                                                  ),
                                                  child: Text(
                                                    dStatusLabel,
                                                    style: TextStyle(
                                                      color: isMachineEmergencyStopped ||
                                                              isDrumEmergencyStopped
                                                          ? Colors.red
                                                          : dColor,
                                                      fontSize: 9,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                    ),

                                  // Drum Maintenance Detail Banners
                                  ...drumsList
                                      .where((d) {
                                        final dStatus =
                                            d['status']
                                                ?.toString()
                                                .toLowerCase() ??
                                            'available';
                                        return dStatus == 'maintenance' ||
                                            isMachineInMaintenance;
                                      })
                                      .map((d) {
                                        final drumName =
                                            d['drum_name'] ?? 'Drum';
                                        final dDesc =
                                            (d['description'] != null &&
                                                d['description']
                                                    .toString()
                                                    .isNotEmpty)
                                            ? d['description'].toString()
                                            : (isMachineInMaintenance &&
                                                      m['description'] !=
                                                          null &&
                                                      m['description']
                                                          .toString()
                                                          .isNotEmpty
                                                  ? 'Inherited from Machine: ${m['description']}'
                                                  : 'Under maintenance');

                                        return Container(
                                          width: double.infinity,
                                          margin: const EdgeInsets.only(top: 8),
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                            color: Colors.orange.withValues(
                                              alpha: 0.08,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            border: Border.all(
                                              color: Colors.orange.withValues(
                                                alpha: 0.3,
                                              ),
                                            ),
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  const Icon(
                                                    Icons.build_circle_outlined,
                                                    color: Colors.orange,
                                                    size: 14,
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Text(
                                                    '$drumName Maintenance Reason',
                                                    style: const TextStyle(
                                                      color: Colors.orange,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 11,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                dDesc,
                                                style: TextStyle(
                                                  color: context.textColor,
                                                  fontSize: 11.5,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      }),

                                  // Maintenance Banner if machine is in maintenance
                                  if (isMachineInMaintenance &&
                                      m['description'] != null &&
                                      m['description']
                                          .toString()
                                          .isNotEmpty) ...[
                                    const SizedBox(height: 12),
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.orange.withValues(
                                          alpha: 0.1,
                                        ),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: Colors.orange.withValues(
                                            alpha: 0.3,
                                          ),
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Row(
                                            children: [
                                              Icon(
                                                Icons.build_circle_outlined,
                                                color: Colors.orange,
                                                size: 16,
                                              ),
                                              SizedBox(width: 6),
                                              Text(
                                                'MAINTENANCE DETAILS',
                                                style: TextStyle(
                                                  color: Colors.orange,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 11,
                                                  letterSpacing: 0.5,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            m['description'].toString(),
                                            style: TextStyle(
                                              color: context.textColor,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],

                                  const SizedBox(height: 16),
                                  const Divider(),
                                  const SizedBox(height: 8),

                                  // Actions Row: Set Maintenance & Precise Edit Button
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      // Maintenance Quick Action Toggle
                                      ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                              isMachineEmergencyStopped
                                              ? Colors.red.withValues(
                                                  alpha: 0.12,
                                                )
                                              : isMachineInMaintenance
                                              ? Colors.green.withValues(
                                                  alpha: 0.15,
                                                )
                                              : Colors.orange.withValues(
                                                  alpha: 0.15,
                                                ),
                                          foregroundColor:
                                              isMachineEmergencyStopped
                                              ? Colors.red
                                              : isMachineInMaintenance
                                              ? Colors.green
                                              : Colors.orange,
                                          elevation: 0,
                                          side: BorderSide(
                                            color: isMachineEmergencyStopped
                                                ? Colors.red
                                                : isMachineInMaintenance
                                                ? Colors.green
                                                : Colors.orange,
                                            width: 1.2,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 8,
                                          ),
                                        ),
                                        onPressed: () {
                                          if (isMachineEmergencyStopped) {
                                            _resolveEmergencyForEquipment(
                                              machineId: m['machine_id']
                                                  .toString(),
                                              equipmentName:
                                                  m['machine_name']?.toString() ??
                                                  'Machine',
                                            );
                                          } else if (isMachineInMaintenance) {
                                            _restoreMachineAvailable(m);
                                          } else {
                                            _showSetMaintenanceDialog(m, true);
                                          }
                                        },
                                        icon: Icon(
                                          isMachineEmergencyStopped
                                              ? Icons.check_circle_outline
                                              : isMachineInMaintenance
                                              ? Icons.build_circle
                                              : Icons.warning_amber_rounded,
                                          size: 16,
                                          color: isMachineEmergencyStopped
                                              ? Colors.red
                                              : isMachineInMaintenance
                                              ? Colors.green
                                              : Colors.orange,
                                        ),
                                        label: Text(
                                          isMachineEmergencyStopped
                                              ? 'Resolve Emergency'
                                              : isMachineInMaintenance
                                              ? 'Set Available'
                                              : 'Set Maintenance',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                            color: isMachineEmergencyStopped
                                                ? Colors.red
                                                : isMachineInMaintenance
                                                ? Colors.green
                                                : Colors.orange,
                                          ),
                                        ),
                                      ),

                                      // Precise Edit Machine Button
                                      OutlinedButton.icon(
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: kGold,
                                          side: const BorderSide(
                                            color: kGold,
                                            width: 1.2,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 14,
                                            vertical: 8,
                                          ),
                                        ),
                                        onPressed: () => _showAddEditDialog(m),
                                        icon: const Icon(
                                          Icons.edit_outlined,
                                          size: 16,
                                          color: kGold,
                                        ),
                                        label: const Text(
                                          'Edit Machine',
                                          style: TextStyle(
                                            color: kGold,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
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
    Color color = s == 'available'
        ? Colors.green
        : (s == 'inactive' || s == 'emergency_stop'
              ? Colors.red
              : Colors.orange);
    String label = status.toUpperCase();
    if (s == 'available') label = 'AVAILABLE';
    if (s == 'maintenance') label = 'MAINTENANCE';
    if (s == 'inactive') label = 'INACTIVE';
    if (s == 'in_use') label = 'IN USE';
    if (s == 'emergency_stop') label = 'EMERGENCY STOP';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
