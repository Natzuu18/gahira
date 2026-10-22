import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../application/services/service_request_service.dart';
import '../../infrastructure/repositories/supabase_service_request_repository.dart';
import '../shared_widgets/appColor.dart';

class OperatorEmergencyStopFab extends StatefulWidget {
  const OperatorEmergencyStopFab({super.key});

  @override
  State<OperatorEmergencyStopFab> createState() =>
      _OperatorEmergencyStopFabState();
}

class _OperatorEmergencyStopFabState extends State<OperatorEmergencyStopFab> {
  final _repository = SupabaseServiceRequestRepository();
  late final ServiceRequestService _service =
      ServiceRequestService(_repository);

  List<_ActiveServiceEquipment> _activeEquipment = [];
  bool _isLoading = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadActiveEquipment();
  }

  Future<void> _loadActiveEquipment() async {
    final operatorId = Supabase.instance.client.auth.currentUser?.id;
    if (operatorId == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      final rows = await Supabase.instance.client
          .from('ongoing_services')
          .select(
            'machine_id, drum_id, machines:machine_id(machine_name), '
            'drums:drum_id(drum_name), '
            'service_requests!inner(service_request_id, status)',
          )
          .eq('operator_id', operatorId)
          .eq('service_requests.status', 'processing');

      final equipment = rows.map((row) {
        final machine = _asMap(row['machines']);
        final drum = _asMap(row['drums']);
        return _ActiveServiceEquipment(
          machineId: row['machine_id']?.toString(),
          machineName: machine['machine_name']?.toString() ?? 'Machine',
          drumId: row['drum_id']?.toString(),
          drumName: drum['drum_name']?.toString(),
        );
      }).toList();

      if (mounted) {
        setState(() {
          _activeEquipment = equipment;
          _isLoading = false;
        });
      }
    } catch (error) {
      debugPrint('Could not load active operator equipment: $error');
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

  Future<void> _openStopOptions() async {
    final targets = <_StopTarget>[];
    final seenMachines = <String>{};
    final seenDrums = <String>{};
    for (final equipment in _activeEquipment) {
      final machineId = equipment.machineId;
      if (machineId != null && seenMachines.add(machineId)) {
        targets.add(
          _StopTarget(
            id: machineId,
            name: equipment.machineName,
            isMachine: true,
            machineName: equipment.machineName,
          ),
        );
      }
      final drumId = equipment.drumId;
      if (drumId != null && seenDrums.add(drumId)) {
        targets.add(
          _StopTarget(
            id: drumId,
            name: equipment.drumName ?? 'Drum',
            isMachine: false,
            machineName: equipment.machineName,
          ),
        );
      }
    }

    final target = await showModalBottomSheet<_StopTarget>(
      context: context,
      backgroundColor: context.surfaceColor,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.7,
          ),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 4, 4, 14),
                child: Text(
                  'EMERGENCY STOP',
                  style: TextStyle(
                    color: context.textColor,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              Text(
                'Machines with your active services',
                style: TextStyle(
                  color: context.mutedTextColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              for (final target in targets.where((target) => target.isMachine))
                _targetTile(
                  sheetContext,
                  target,
                  title: 'Machine Emergency Stop',
                  subtitle: target.name,
                ),
              const SizedBox(height: 8),
              Text(
                'Drums under your active services',
                style: TextStyle(
                  color: context.mutedTextColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              for (final target in targets.where((target) => !target.isMachine))
                _targetTile(
                  sheetContext,
                  target,
                  title: target.name,
                  subtitle: 'Machine: ${target.machineName}',
                ),
            ],
          ),
        ),
      ),
    );

    if (target != null) await _confirmAndStop(target);
  }

  Widget _targetTile(
    BuildContext sheetContext,
    _StopTarget target, {
    required String title,
    required String subtitle,
  }) {
    return Card(
      color: context.bgColor,
      margin: const EdgeInsets.only(top: 8),
      child: ListTile(
        leading: Icon(
          target.isMachine
              ? Icons.precision_manufacturing_rounded
              : Icons.settings_input_component_rounded,
          color: Colors.redAccent,
        ),
        title: Text(title, style: TextStyle(color: context.textColor)),
        subtitle: Text(subtitle, style: TextStyle(color: context.mutedTextColor)),
        trailing: FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Colors.redAccent,
            foregroundColor: Colors.white,
          ),
          onPressed: () => Navigator.pop(sheetContext, target),
          child: const Text('STOP'),
        ),
      ),
    );
  }

  Future<void> _confirmAndStop(_StopTarget target) async {
    final reasonController = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: dialogContext.surfaceColor,
        title: Text(
          'Stop ${target.isMachine ? 'machine' : 'drum'}?',
          style: TextStyle(color: dialogContext.textColor),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              target.name,
              style: TextStyle(color: dialogContext.mutedTextColor),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              maxLines: 2,
              style: TextStyle(color: dialogContext.textColor),
              decoration: const InputDecoration(
                labelText: 'Reason for stop',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              final value = reasonController.text.trim();
              if (value.isEmpty) return;
              Navigator.pop(dialogContext, value);
            },
            child: const Text('CONFIRM STOP'),
          ),
        ],
      ),
    );
    reasonController.dispose();
    if (reason == null || !mounted) return;

    final operatorId = Supabase.instance.client.auth.currentUser?.id;
    if (operatorId == null) return;
    setState(() => _isSubmitting = true);
    final result = await _service.triggerEmergencyStop(
      operatorId: operatorId,
      reason: reason,
      machineId: target.isMachine ? target.id : null,
      drumId: target.isMachine ? null : target.id,
      stopEntireMachine: target.isMachine,
    );
    if (!mounted) return;

    result.fold(
      (failure) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(failure.message),
          backgroundColor: Colors.redAccent,
        ),
      ),
      (_) => ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Emergency stop triggered.'),
          backgroundColor: Colors.redAccent,
        ),
      ),
    );
    await _loadActiveEquipment();
    if (mounted) setState(() => _isSubmitting = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _activeEquipment.isEmpty) {
      return const SizedBox.shrink();
    }
    return FloatingActionButton.small(
      heroTag: 'operator-emergency-stop',
      tooltip: 'Emergency stop active service equipment',
      onPressed: _isSubmitting ? null : _openStopOptions,
      backgroundColor: Colors.redAccent,
      foregroundColor: Colors.white,
      child: const Icon(Icons.warning_rounded, size: 22),
    );
  }
}

class _ActiveServiceEquipment {
  const _ActiveServiceEquipment({
    required this.machineId,
    required this.machineName,
    required this.drumId,
    required this.drumName,
  });

  final String? machineId;
  final String machineName;
  final String? drumId;
  final String? drumName;
}

class _StopTarget {
  const _StopTarget({
    required this.id,
    required this.name,
    required this.isMachine,
    required this.machineName,
  });

  final String id;
  final String name;
  final bool isMachine;
  final String machineName;
}
