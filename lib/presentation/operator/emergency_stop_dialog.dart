import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../application/services/service_request_service.dart';
import '../../infrastructure/repositories/supabase_service_request_repository.dart';
import '../shared_widgets/appColor.dart';

class EmergencyStopDialog extends StatefulWidget {
  const EmergencyStopDialog({super.key});

  @override
  State<EmergencyStopDialog> createState() => _EmergencyStopDialogState();
}

class _EmergencyStopDialogState extends State<EmergencyStopDialog> {
  final _requestRepo = SupabaseServiceRequestRepository();
  late final ServiceRequestService _service;

  List<Map<String, dynamic>> _machines = [];
  String? _selectedMachineId;
  String? _selectedDrumId;

  final _reasonController = TextEditingController();
  bool _isLoading = true;
  bool _isSubmitting = false;
  bool _isMachineScope = true;

  @override
  void initState() {
    super.initState();
    _service = ServiceRequestService(_requestRepo);
    _loadEquipment();
  }

  Future<void> _loadEquipment() async {
    final operatorId = Supabase.instance.client.auth.currentUser?.id;
    if (operatorId == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      // Limit the selector to equipment on services this operator currently
      // handles. Never populate it from the full equipment inventory.
      final rows = await Supabase.instance.client
          .from('ongoing_services')
          .select(
            'machine_id, drum_id, machines:machine_id(machine_id, machine_name), '
            'drums:drum_id(drum_id, drum_name), '
            'service_requests!inner(service_request_id, status)',
          )
          .eq('operator_id', operatorId)
          .eq('service_requests.status', 'processing');

      final machinesById = <String, Map<String, dynamic>>{};
      for (final row in rows) {
        final machineValue = row['machines'];
        final drumValue = row['drums'];
        final machine = _asMap(machineValue);
        final drum = _asMap(drumValue);
        final machineId = row['machine_id']?.toString();
        if (machineId == null) continue;
        final entry = machinesById.putIfAbsent(machineId, () => {
          'machine_id': machineId,
          'machine_name': machine['machine_name']?.toString() ?? 'Machine',
          'drums': <Map<String, dynamic>>[],
        });
        final drumId = row['drum_id']?.toString();
        final drums = entry['drums'] as List<Map<String, dynamic>>;
        if (drumId != null && !drums.any((item) => item['drum_id'] == drumId)) {
          drums.add({
            'drum_id': drumId,
            'drum_name': drum['drum_name']?.toString() ?? 'Drum',
          });
        }
      }

      if (mounted) {
        setState(() {
          _machines = machinesById.values.toList();
          _isLoading = false;
          _selectedMachineId = _machines.isEmpty
              ? null
              : _machines.first['machine_id'].toString();
        });
      }
    } catch (error) {
      debugPrint('Could not load operator emergency-stop equipment: $error');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is List && value.isNotEmpty && value.first is Map) {
      return Map<String, dynamic>.from(value.first as Map);
    }
    return const {};
  }

  Future<void> _handleSubmit() async {
    if (_isMachineScope && _selectedMachineId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select a machine')));
      return;
    }
    if (!_isMachineScope && _selectedDrumId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select a drum')));
      return;
    }
    if (_reasonController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please provide a reason')));
      return;
    }

    setState(() => _isSubmitting = true);
    final operatorId = Supabase.instance.client.auth.currentUser?.id;

    final result = await _service.triggerEmergencyStop(
      operatorId: operatorId ?? 'Unknown',
      reason: _reasonController.text.trim(),
      machineId: _selectedMachineId,
      drumId: _selectedDrumId,
      stopEntireMachine: _isMachineScope,
    );

    if (mounted) {
      result.fold(
        (l) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l.message), backgroundColor: Colors.red),
          );
          setState(() => _isSubmitting = false);
        },
        (_) {
          Navigator.pop(context, true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('EMERGENCY STOP TRIGGERED'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: context.surfaceColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Colors.red, width: 2),
      ),
      title: const Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.red),
          SizedBox(width: 12),
          Text(
            'EMERGENCY STOP',
            style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
          ),
        ],
      ),
      content: _isLoading
          ? const SizedBox(
              height: 100,
              child: Center(
                child: CircularProgressIndicator(color: Colors.red),
              ),
            )
          : SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Stop one selected drum or the entire machine and all of its drums. Active services using the stopped equipment will be halted.',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 14),
                  if (_machines.isEmpty)
                    const Text(
                      'No equipment is assigned to your active services.',
                      style: TextStyle(color: Colors.red, fontSize: 12),
                    ),

                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: const Text(
                            'Entire Machine',
                            style: TextStyle(fontSize: 11),
                          ),
                          selected: _isMachineScope,
                          selectedColor: Colors.red,
                          labelStyle: TextStyle(
                            color: _isMachineScope ? Colors.white : null,
                          ),
                          onSelected: (val) => setState(() {
                            _isMachineScope = true;
                            _selectedDrumId = null;
                          }),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ChoiceChip(
                          label: const Text(
                            'Specific Drum',
                            style: TextStyle(fontSize: 11),
                          ),
                          selected: !_isMachineScope,
                          selectedColor: Colors.red,
                          labelStyle: TextStyle(
                            color: !_isMachineScope ? Colors.white : null,
                          ),
                          onSelected: (val) => setState(() {
                            _isMachineScope = false;
                          }),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),
                  const Text(
                    'Select Machine',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _selectedMachineId,
                    dropdownColor: context.surfaceColor,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12),
                    ),
                    items: _machines
                        .map(
                          (m) => DropdownMenuItem<String>(
                            value: m['machine_id'].toString(),
                            child: Text(
                              m['machine_name'],
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: _machines.isEmpty ? null : (val) => setState(() {
                      _selectedMachineId = val;
                      _selectedDrumId = null;
                    }),
                  ),

                  if (!_isMachineScope && _selectedMachineId != null) ...[
                    const SizedBox(height: 14),
                    const Text(
                      'Select Specific Drum',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: _selectedDrumId,
                      dropdownColor: context.surfaceColor,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12),
                      ),
                      items:
                          (_machines.firstWhere(
                                    (m) =>
                                        m['machine_id'].toString() ==
                                        _selectedMachineId,
                                  )['drums']
                                  as List)
                              .map(
                                (d) => DropdownMenuItem<String>(
                                  value: d['drum_id'].toString(),
                                  child: Text(
                                    d['drum_name'],
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                ),
                              )
                              .toList(),
                      onChanged: (val) => setState(() => _selectedDrumId = val),
                    ),
                  ],

                  const SizedBox(height: 20),
                  const Text(
                    'Reason for Stop',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _reasonController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      hintText: 'e.g. Mechanical failure, fire, injury...',
                      hintStyle: TextStyle(fontSize: 12),
                      border: OutlineInputBorder(),
                    ),
                    style: const TextStyle(fontSize: 13),
                  ),

                  if (_selectedMachineId != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _isMachineScope
                            ? 'NOTE: ALL services on THIS MACHINE will be halted.'
                            : 'NOTE: Only services on THIS DRUM will be halted.',
                        style: const TextStyle(
                          color: Colors.red,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
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
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isSubmitting || _machines.isEmpty ? null : _handleSubmit,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
          child: _isSubmitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : const Text(
                  'TRIGGER STOP',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
        ),
      ],
    );
  }
}
