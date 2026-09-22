import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../application/services/service_request_service.dart';
import '../../infrastructure/repositories/supabase_service_request_repository.dart';
import '../../infrastructure/repositories/supabase_equipment_repository.dart';
import '../shared_widgets/appColor.dart';

class EmergencyStopDialog extends StatefulWidget {
  const EmergencyStopDialog({super.key});

  @override
  State<EmergencyStopDialog> createState() => _EmergencyStopDialogState();
}

class _EmergencyStopDialogState extends State<EmergencyStopDialog> {
  final _requestRepo = SupabaseServiceRequestRepository();
  final _equipRepo = SupabaseEquipmentRepository();
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
    final result = await _equipRepo.getMachines();
    if (mounted) {
      setState(() {
        _machines = result.getOrElse(() => []);
        _isLoading = false;
      });
    }
  }

  Future<void> _handleSubmit() async {
    if (_isMachineScope && _selectedMachineId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a machine')));
      return;
    }
    if (!_isMachineScope && _selectedDrumId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a drum')));
      return;
    }
    if (_reasonController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please provide a reason')));
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
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.message), backgroundColor: Colors.red));
          setState(() => _isSubmitting = false);
        },
        (_) {
          Navigator.pop(context, true);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('EMERGENCY STOP TRIGGERED'), 
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ));
        }
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: context.surfaceColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Colors.red, width: 2)),
      title: const Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.red),
          SizedBox(width: 12),
          Text('EMERGENCY STOP', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
        ],
      ),
      content: _isLoading 
        ? const SizedBox(height: 100, child: Center(child: CircularProgressIndicator(color: Colors.red)))
        : SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Choose the scope of the emergency stop.', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                const SizedBox(height: 20),
                
                Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        label: const Text('Entire Machine', style: TextStyle(fontSize: 11)),
                        selected: _isMachineScope,
                        selectedColor: Colors.red,
                        labelStyle: TextStyle(color: _isMachineScope ? Colors.white : null),
                        onSelected: (val) => setState(() {
                          _isMachineScope = true;
                          _selectedDrumId = null;
                        }),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ChoiceChip(
                        label: const Text('Specific Drum', style: TextStyle(fontSize: 11)),
                        selected: !_isMachineScope,
                        selectedColor: Colors.red,
                        labelStyle: TextStyle(color: !_isMachineScope ? Colors.white : null),
                        onSelected: (val) => setState(() {
                          _isMachineScope = false;
                        }),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 20),
                const Text('Select Machine', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _selectedMachineId,
                  dropdownColor: context.surfaceColor,
                  isExpanded: true,
                  decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12)),
                  items: _machines.map((m) => DropdownMenuItem<String>(
                    value: m['machine_id'].toString(),
                    child: Text(m['machine_name'], style: const TextStyle(fontSize: 13)),
                  )).toList(),
                  onChanged: (val) => setState(() {
                    _selectedMachineId = val;
                    _selectedDrumId = null;
                  }),
                ),

                if (!_isMachineScope && _selectedMachineId != null) ...[
                  const SizedBox(height: 20),
                  const Text('Select Specific Drum', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _selectedDrumId,
                    dropdownColor: context.surfaceColor,
                    isExpanded: true,
                    decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12)),
                    items: (_machines.firstWhere((m) => m['machine_id'].toString() == _selectedMachineId)['drums'] as List)
                      .map((d) => DropdownMenuItem<String>(
                        value: d['drum_id'].toString(),
                        child: Text(d['drum_name'], style: const TextStyle(fontSize: 13)),
                      )).toList(),
                    onChanged: (val) => setState(() => _selectedDrumId = val),
                  ),
                ],
                
                const SizedBox(height: 20),
                const Text('Reason for Stop', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
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
                    decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                    child: Text(
                      _isMachineScope 
                        ? 'NOTE: ALL services on THIS MACHINE will be halted.' 
                        : 'NOTE: Only services on THIS DRUM will be halted.',
                      style: const TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ],
            ),
          ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: _isSubmitting ? null : _handleSubmit,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
          child: _isSubmitting 
            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : const Text('TRIGGER STOP', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
