import 'dart:async';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../../domain/entities/service_request_entity.dart';
import '../../../infrastructure/repositories/supabase_equipment_repository.dart';
import '../../../infrastructure/repositories/supabase_service_request_repository.dart';
import '../../../application/services/service_request_service.dart';
import '../../presentation/shared_widgets/appColor.dart';
import '../../presentation/shared_widgets/pin_dialog.dart';
import '../../main.dart';

class SackingPage extends StatefulWidget {
  final ServiceRequestEntity request;
  const SackingPage({super.key, required this.request});

  @override
  State<SackingPage> createState() => _SackingPageState();
}

class _SackingPageState extends State<SackingPage> {
  final _equipRepo = SupabaseEquipmentRepository();
  final _requestRepo = SupabaseServiceRequestRepository();
  late final ServiceRequestService _service;

  List<Map<String, dynamic>> _machines = [];
  List<Map<String, dynamic>> _existingBatches = [];
  bool _isLoading = true;
  ServiceRequestEntity? _currentRequest;

  String? _selectedMachineId;
  final Set<String> _selectedDrumIds = <String>{};
  final _inputSacksController = TextEditingController();
  final _outputSacksController = TextEditingController();
  final _estDurationController = TextEditingController(text: '30');
  Timer? _refreshTimer;
  RealtimeChannel? _realtimeChannel;
  bool _isSaving = false;
  bool _isResuming = false;
  bool _showMillingActionLabels = false;
  String? _completionSmsFailure;

  @override
  void initState() {
    super.initState();
    _service = ServiceRequestService(_requestRepo);
    _subscribeToRequestUpdates();
    _loadData();
    // Periodically refresh the data from server to catch admin resolutions
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (mounted) _loadData(showLoading: false);
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    final channel = _realtimeChannel;
    if (channel != null) {
      unawaited(Supabase.instance.client.removeChannel(channel));
    }
    _inputSacksController.dispose();
    _outputSacksController.dispose();
    _estDurationController.dispose();
    super.dispose();
  }

  void _subscribeToRequestUpdates() {
    final client = Supabase.instance.client;
    _realtimeChannel = client
        .channel('operator-process-${widget.request.id}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'service_requests',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'service_request_id',
            value: widget.request.id,
          ),
          callback: (_) {
            if (mounted) unawaited(_loadData(showLoading: false));
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'milling_batches',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'service_request_id',
            value: widget.request.id,
          ),
          callback: (_) {
            if (mounted) unawaited(_loadData(showLoading: false));
          },
        )
        .subscribe();
  }

  Future<void> _loadData({bool showLoading = true}) async {
    if (showLoading) setState(() => _isLoading = true);

    final machinesRes = await _equipRepo.getMachines();
    final batchesRes = await _requestRepo.getMillingBatches(widget.request.id);
    final requestRes = await _requestRepo.getServiceRequests();

    if (mounted) {
      final machines = machinesRes.getOrElse(() => []);
      final availableMachines = machines.where(_machineHasAvailableDrum).toList();
      final selectedMachine = availableMachines.cast<Map<String, dynamic>?>().firstWhere(
        (machine) => machine?['machine_id']?.toString() == _selectedMachineId,
        orElse: () => null,
      );
      final machineToSelect = selectedMachine ??
          (availableMachines.isNotEmpty ? availableMachines.first : null);
      final availableDrums = machineToSelect == null
          ? <dynamic>[]
          : _availableDrums(machineToSelect);
      final availableDrumIds = availableDrums
          .map((drum) => drum['drum_id']?.toString())
          .whereType<String>()
          .toSet();
      final loadedBatches = batchesRes.getOrElse(() => <Map<String, dynamic>>[]);

      setState(() {
        _machines = machines;
        _selectedMachineId = machineToSelect?['machine_id']?.toString();
        _selectedDrumIds.removeWhere((drumId) => !availableDrumIds.contains(drumId));
        if (_selectedDrumIds.isEmpty && availableDrums.isNotEmpty) {
          _selectedDrumIds.add(availableDrums.first['drum_id'].toString());
        }
        _existingBatches = loadedBatches;

        requestRes.fold((_) => null, (list) {
          try {
            _currentRequest = list.firstWhere((r) => r.id == widget.request.id);
          } catch (_) {}
        });

        _isLoading = false;
      });
    }
  }

  List<dynamic> _availableDrums(Map<String, dynamic> machine) {
    final drums = machine['drums'];
    if (drums is! List) return <dynamic>[];
    return drums.where((drum) {
      if (drum is! Map) return false;
      return (drum['status']?.toString().toLowerCase() ?? 'available') ==
          'available';
    }).toList();
  }

  bool _machineHasAvailableDrum(Map<String, dynamic> machine) {
    final status = machine['status']?.toString().toLowerCase() ?? 'available';
    return status == 'available' && _availableDrums(machine).isNotEmpty;
  }

  ServiceRequestEntity get _effectiveRequest =>
      _currentRequest ?? widget.request;

  int get _totalSacksFromMiner =>
      _effectiveRequest.materialDetails.numberOfSacks ?? 0;

  int get _sacksProcessedSoFar {
    int total = 0;
    for (var b in _existingBatches) {
      if (b['batch_kind'] == 'milling') continue;
      total += (b['input_sacks'] as int? ?? 0);
    }
    return total;
  }

  int get _remainingMinerSacks => _totalSacksFromMiner - _sacksProcessedSoFar;

  int get _totalResackedSacks => _existingBatches.fold<int>(
    0,
    (total, batch) => batch['batch_kind'] == 'sacking'
        ? total + ((batch['output_sacks'] as num?)?.toInt() ?? 0)
        : total,
  );

  int get _availableResackedSacksTotal {
    final prepared = _existingBatches
        .where((batch) => batch['batch_kind'] == 'sacking')
        .fold<int>(
          0,
          (total, batch) =>
              total + ((batch['output_sacks'] as num?)?.toInt() ?? 0),
        );
    final allocated = _existingBatches
        .where((batch) => batch['batch_kind'] == 'milling')
        .fold<int>(
          0,
          (total, batch) =>
              total + ((batch['input_sacks'] as num?)?.toInt() ?? 0),
        );
    return (prepared - allocated).clamp(0, prepared).toInt();
  }

  bool get _hasUnfinishedMilling =>
      _availableResackedSacksTotal > 0 ||
      _existingBatches.any((batch) => batch['status'] == 'milling');

  bool get _hasActiveMillingBatch =>
      _existingBatches.any((batch) => batch['status'] == 'milling');

  bool get _allMillingWorkComplete =>
      _totalSacksFromMiner > 0 &&
      _remainingMinerSacks == 0 &&
      _availableResackedSacksTotal == 0 &&
      !_hasActiveMillingBatch;

  bool get _hasMoreSackingOrMillingWork =>
      _remainingMinerSacks > 0 || _availableResackedSacksTotal > 0;

  bool _batchNeedsUnloading(Map<String, dynamic> batch) =>
      batch['batch_kind'] == 'milling' &&
      batch['status'] == 'completed' &&
      batch['unloading_completed_at'] == null;

  bool _batchIsUnloading(Map<String, dynamic> batch) =>
      _batchNeedsUnloading(batch) && batch['unloading_started_at'] != null;

  bool get _allMillingBatchesUnloaded {
    final millingBatches = _existingBatches
        .where((batch) => batch['batch_kind'] == 'milling')
        .toList();
    return millingBatches.every(
      (batch) =>
          batch['status'] == 'completed' &&
          batch['unloading_completed_at'] != null,
    );
  }

  bool get _hasUnloadedMillingBatch => _existingBatches.any(
    (batch) =>
        batch['batch_kind'] == 'milling' &&
        batch['status'] == 'completed' &&
        batch['unloading_completed_at'] != null,
  );

  List<Map<String, dynamic>> get _unloadedMillingBatches => _existingBatches
      .where(
        (batch) =>
            batch['batch_kind'] == 'milling' &&
            batch['status'] == 'completed' &&
            batch['unloading_completed_at'] != null,
      )
      .toList();

  List<Map<String, dynamic>> get _unloadingMillingBatchesInProgress =>
      _existingBatches.where(_batchIsUnloading).toList();

  List<Map<String, dynamic>> get _washingMillingBatchesInProgress =>
      _unloadedMillingBatches
          .where(
            (batch) =>
                batch['washing_started_at'] != null &&
                batch['washing_completed_at'] == null,
          )
          .toList();

  int get _washedMillingBatchCount => _unloadedMillingBatches
      .where((batch) => batch['washing_completed_at'] != null)
      .length;

  bool get _allUnloadedMillingBatchesWashed =>
      _unloadedMillingBatches.isNotEmpty &&
      _unloadedMillingBatches.every(
        (batch) => batch['washing_completed_at'] != null,
      );

  bool get _canStartSeparation =>
      _allMillingWorkComplete &&
      _allMillingBatchesUnloaded &&
      _allUnloadedMillingBatchesWashed;

  bool get _canProceedToRefining =>
      _canStartSeparation &&
      _effectiveRequest.processingDetails.separationCompletedAt != null;

  bool get _hasMillingBatches => _existingBatches.any(
    (batch) => batch['batch_kind'] == 'milling',
  );

  Duration get _totalMillingDuration {
    Duration total = Duration.zero;
    for (var b in _existingBatches) {
      if (b['status'] == 'completed' && b['completed_at'] != null) {
        final start = DateTime.parse(
          b['milling_started_at']?.toString() ?? b['created_at'].toString(),
        );
        final end = DateTime.parse(b['completed_at']);
        total += end.difference(start);
      }
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bgColor,
      appBar: AppBar(
        backgroundColor: context.surfaceColor,
        title: Text(
          switch (_effectiveRequest.processingDetails.currentStage) {
            ProcessingStage.rebagging => 'SACKING / REBAGGING',
            ProcessingStage.millingCrushing => 'MILLING',
            ProcessingStage.washingSeparation => 'WASHING',
            ProcessingStage.separation => 'SEPARATION',
            ProcessingStage.refining => 'REFINING',
            _ => 'BATCH SACKING / MILLING',
          },
          style: TextStyle(
            color: kGold,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
        iconTheme: const IconThemeData(color: kGold),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: kGold))
          : Column(
              children: [
                _buildProcessFlow(),
                Expanded(child: _buildCurrentStageContent()),
              ],
            ),
    );
  }

  Widget _buildCurrentStageContent() {
    if (_effectiveRequest.processingDetails.currentStage ==
        ProcessingStage.rebagging) {
      return _buildSackingUI();
    }
    if (_effectiveRequest.processingDetails.currentStage ==
        ProcessingStage.millingCrushing) {
      return _buildMillingUI();
    }
    if (_effectiveRequest.processingDetails.currentStage ==
        ProcessingStage.unloading) {
      return _buildUnloadingUI();
    }
    if (_effectiveRequest.processingDetails.currentStage ==
        ProcessingStage.washingSeparation) {
      return _buildWashingUI();
    }
    if (_effectiveRequest.processingDetails.currentStage ==
        ProcessingStage.separation) {
      return _buildSeparationUI();
    }
    if (_effectiveRequest.processingDetails.currentStage ==
        ProcessingStage.refining) {
      return _buildRefiningUI();
    }
    if (_effectiveRequest.processingDetails.currentStage ==
        ProcessingStage.completed) {
      return _buildCompletedProcessingUI();
    }
    return _buildSackingUI();
  }

  Widget _buildProcessFlow() {
    final details = _effectiveRequest.processingDetails;
    final currentStage = details.currentStage;
    final currentRank = switch (currentStage) {
      ProcessingStage.none ||
      ProcessingStage.rebagging ||
      ProcessingStage.loading => 0,
      ProcessingStage.millingCrushing => 1,
      ProcessingStage.unloading => 2,
      ProcessingStage.washingSeparation => 3,
      ProcessingStage.separation => 4,
      ProcessingStage.refining => 5,
      ProcessingStage.completed => 6,
    };

    String formatDuration(DateTime? start, DateTime? end) {
      if (start == null || end == null) return 'In progress';
      var duration = end.difference(_correctLegacyUnloadingTimestamp(start, end));
      if (duration.isNegative) duration = Duration.zero;
      final hours = duration.inHours;
      final minutes = duration.inMinutes % 60;
      final seconds = duration.inSeconds % 60;
      if (hours > 0) return '${hours}h ${minutes}m ${seconds}s';
      if (minutes > 0) return '${minutes}m ${seconds}s';
      return '${seconds}s';
    }

    final millingBatches = _existingBatches
        .where((batch) => batch['batch_kind'] == 'milling')
        .toList();
    final unloadedBatchCount = millingBatches
        .where((batch) => batch['unloading_completed_at'] != null)
        .length;
    final unloadingResult = millingBatches.isEmpty
        ? formatDuration(
            details.unloadingStartedAt,
            details.unloadingCompletedAt,
          )
        : '$unloadedBatchCount / ${millingBatches.length} batches unloaded';

    final stages = <({
      String title,
      int rank,
      String result,
      ProcessingStage destination,
    })>[
      (
        title: 'Sacking / Rebagging',
        rank: 0,
        result: '$_sacksProcessedSoFar / $_totalSacksFromMiner sacks',
        destination: ProcessingStage.rebagging,
      ),
      (
        title: 'Milling',
        rank: 1,
        result: '$_totalResackedSacks resacked sacks | '
            '${_formatDuration(_totalMillingDuration)}',
        destination: ProcessingStage.millingCrushing,
      ),
      (
        title: 'Unloading',
        rank: 2,
        result: unloadingResult,
        destination: ProcessingStage.unloading,
      ),
      (
        title: 'Washing',
        rank: 3,
        result: _unloadedMillingBatches.isEmpty
            ? formatDuration(
                details.washingStartedAt,
                details.washingCompletedAt,
              )
            : '$_washedMillingBatchCount / ${_unloadedMillingBatches.length} batches washed',
        destination: ProcessingStage.washingSeparation,
      ),
      (
        title: 'Separation',
        rank: 4,
        result: formatDuration(
          details.separationStartedAt,
          details.separationCompletedAt,
        ),
        destination: ProcessingStage.separation,
      ),
      (
        title: 'Refining',
        rank: 5,
        result: details.refiningStartedAt == null
            ? 'Not started'
            : formatDuration(
                details.refiningStartedAt,
                details.refiningCompletedAt,
              ),
        destination: ProcessingStage.refining,
      ),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 10, 0, 12),
      color: context.surfaceColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 16, bottom: 8),
            child: Text(
              'PROCESS FLOW & RESULTS',
              style: TextStyle(
                color: kGold.withOpacity(0.85),
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
          ),
          LayoutBuilder(
            builder: (context, constraints) {
              final cardWidth = constraints.maxWidth >= 700 ? 176.0 : 148.0;
              final baseScrollBehavior = ScrollConfiguration.of(context);
              return ScrollConfiguration(
                behavior: baseScrollBehavior.copyWith(
                  scrollbars: false,
                  dragDevices: {
                    ...baseScrollBehavior.dragDevices,
                    PointerDeviceKind.mouse,
                  },
                ),
                child: SizedBox(
                  height: 88,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: stages.length,
                    separatorBuilder: (_, _) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Icon(
                        Icons.chevron_right_rounded,
                        color: context.mutedTextColor.withOpacity(0.6),
                        size: 20,
                      ),
                    ),
                    itemBuilder: (context, index) {
                final stage = stages[index];
                final isComplete = currentRank > stage.rank;
                final isCurrent = currentRank == stage.rank;
                final color = isComplete
                    ? Colors.green
                    : isCurrent
                    ? kGold
                    : context.mutedTextColor;
                final canSelect = _canSelectProcessStage(
                  stage.destination,
                  currentStage,
                );
                final result = isComplete ||
                        (isCurrent && (stage.rank == 0 || stage.rank == 1))
                    ? stage.result
                    : isCurrent
                    ? (stage.rank == 2 && details.unloadingStartedAt != null
                          ? stage.result
                          : stage.rank == 3 &&
                                (_unloadedMillingBatches.isNotEmpty ||
                                    details.washingStartedAt != null)
                          ? stage.result
                          : stage.rank == 4 &&
                                details.separationStartedAt != null
                          ? stage.result
                          : 'In progress')
                    : stage.rank == 2 && millingBatches.isNotEmpty
                    ? stage.result
                    : 'Waiting';
                return Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    onTap: canSelect
                        ? () => _handleProcessFlowTap(stage.destination)
                        : null,
                    mouseCursor: canSelect
                        ? SystemMouseCursors.click
                        : SystemMouseCursors.basic,
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      width: cardWidth,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: color.withOpacity(0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Row(
                            children: [
                              Icon(
                                isComplete
                                    ? Icons.check_circle_rounded
                                    : isCurrent
                                    ? Icons.radio_button_checked_rounded
                                    : Icons.circle_outlined,
                                color: color,
                                size: 14,
                              ),
                              const SizedBox(width: 5),
                              Expanded(
                                child: Text(
                                  stage.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: context.textColor,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 5),
                          Text(
                            result,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: color, fontSize: 10),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
                    },
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  bool _canSelectProcessStage(
    ProcessingStage destination,
    ProcessingStage currentStage,
  ) {
    final currentRank = switch (currentStage) {
      ProcessingStage.rebagging => 0,
      ProcessingStage.millingCrushing => 1,
      ProcessingStage.unloading => 2,
      ProcessingStage.washingSeparation => 3,
      ProcessingStage.separation => 4,
      ProcessingStage.refining => 5,
      ProcessingStage.completed => 6,
      ProcessingStage.none || ProcessingStage.loading => -1,
    };
    return switch (destination) {
      ProcessingStage.rebagging =>
        currentStage == ProcessingStage.rebagging ||
            _remainingMinerSacks > 0 ||
            _sacksProcessedSoFar > 0,
      ProcessingStage.millingCrushing =>
        currentStage == ProcessingStage.millingCrushing || _hasMillingBatches,
      ProcessingStage.unloading => _hasMillingBatches,
      ProcessingStage.washingSeparation =>
        currentStage == ProcessingStage.washingSeparation ||
            currentRank > 3 ||
            _hasUnloadedMillingBatch,
      ProcessingStage.separation =>
        currentStage == ProcessingStage.separation ||
            currentRank > 4 ||
            _canStartSeparation,
      ProcessingStage.refining =>
        currentStage == ProcessingStage.refining ||
            currentRank > 5 ||
            (_allMillingWorkComplete &&
                _allMillingBatchesUnloaded &&
                _allUnloadedMillingBatchesWashed &&
                _effectiveRequest.processingDetails.separationCompletedAt !=
                    null),
      _ => false,
    };
  }

  Future<void> _handleProcessFlowTap(ProcessingStage destination) async {
    if (destination == _effectiveRequest.processingDetails.currentStage) return;

    switch (destination) {
      case ProcessingStage.rebagging:
        await _returnToOperationStage(
          ProcessingStage.rebagging,
          'Opened sacking from the process flow for review.',
          resetWashing: _remainingMinerSacks > 0,
        );
        break;
      case ProcessingStage.millingCrushing:
        await _returnToOperationStage(
          ProcessingStage.millingCrushing,
          'Opened milling from the process flow.',
          resetWashing: _hasMoreSackingOrMillingWork,
        );
        break;
      case ProcessingStage.unloading:
        await _advanceStage(ProcessingStage.unloading);
        break;
      case ProcessingStage.washingSeparation:
        await _advanceStage(ProcessingStage.washingSeparation);
        break;
      case ProcessingStage.separation:
        await _advanceStage(ProcessingStage.separation);
        break;
      case ProcessingStage.refining:
        if (_effectiveRequest.processingDetails.currentStage ==
            ProcessingStage.completed) {
          await _advanceStage(ProcessingStage.refining);
        } else {
          await _handleProceedToRefining();
        }
        break;
      case ProcessingStage.none ||
          ProcessingStage.loading ||
          ProcessingStage.completed:
        return;
    }
  }

  String _formatDuration(Duration duration) {
    final safeDuration = duration.isNegative ? Duration.zero : duration;
    final hours = safeDuration.inHours;
    final minutes = safeDuration.inMinutes % 60;
    final seconds = safeDuration.inSeconds % 60;
    if (hours > 0) return '${hours}h ${minutes}m ${seconds}s';
    if (minutes > 0) return '${minutes}m ${seconds}s';
    return '${seconds}s';
  }

  Widget _buildSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kGold.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kGold.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _summaryItem('Original Sacks', _totalSacksFromMiner.toString()),
              _summaryItem('Sacked', _sacksProcessedSoFar.toString()),
              _summaryItem('Resacked', _totalResackedSacks.toString()),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: _totalSacksFromMiner > 0
                  ? _sacksProcessedSoFar / _totalSacksFromMiner
                  : 0,
              backgroundColor: kGold.withOpacity(0.1),
              color: kGold,
              minHeight: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryItem(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(color: context.mutedTextColor, fontSize: 11),
        ),
        Text(
          value,
          style: TextStyle(
            color: context.textColor,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildBatchForm() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kGold.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'SACKING BATCH',
            style: TextStyle(
              color: kGold,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Record each group of miner sacks after it has been resacked. All miner sacks must be accounted for before milling can begin.',
            style: TextStyle(color: context.mutedTextColor, fontSize: 12),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildInput(
                  'Miner Sacks Sacked',
                  _inputSacksController,
                  hint: 'Max $_remainingMinerSacks',
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildInput(
                  'Resacked Quantity',
                  _outputSacksController,
                  hint: 'Resulting sacks',
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _isSaving ? null : _handleSaveSackingBatch,
            style: ElevatedButton.styleFrom(
              backgroundColor: kGold,
              foregroundColor: kBlack,
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: kBlack,
                    ),
                  )
                : const Text(
                    'SAVE SACKING BATCH',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _isSaving ? null : _handleSkipRemainingSacking,
            icon: const Icon(Icons.skip_next_rounded),
            label: const Text('SKIP REMAINING SACKING'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.green,
              side: const BorderSide(color: Colors.green),
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSackingUI() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSummaryCard(),
          const SizedBox(height: 18),
          if (_remainingMinerSacks > 0)
            _buildBatchForm()
          else
            _buildSackingCompletionAlert(),
          if (_availableResackedSacksTotal > 0 || _hasMillingBatches) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _isSaving ? null : _handleProceedToMilling,
              icon: const Icon(Icons.arrow_forward_rounded),
              label: const Text('GO TO MILLING'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.green,
                side: const BorderSide(color: Colors.green),
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),
          Text(
            'Sacking Batches',
            style: TextStyle(
              color: context.textColor,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          if (_existingBatches.isEmpty)
            Text(
              'No sacking batches recorded yet.',
              style: TextStyle(color: context.mutedTextColor),
            )
          else
            ..._existingBatches.reversed.map(_buildBatchCard),
        ],
      ),
    );
  }

  Widget _buildSackingCompletionAlert() {
    final allSacksAccountedFor =
        _sacksProcessedSoFar == _totalSacksFromMiner &&
        _totalSacksFromMiner > 0;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: (allSacksAccountedFor ? Colors.green : Colors.orange)
            .withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: (allSacksAccountedFor ? Colors.green : Colors.orange)
              .withOpacity(0.3),
        ),
      ),
      child: Column(
        children: [
          Icon(
            allSacksAccountedFor
                ? Icons.inventory_2_rounded
                : Icons.warning_amber_rounded,
            color: allSacksAccountedFor ? Colors.green : Colors.orange,
            size: 42,
          ),
          const SizedBox(height: 12),
          Text(
            allSacksAccountedFor
                ? 'All miner sacks are resacked'
                : 'Sacking required before milling',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: allSacksAccountedFor ? Colors.green : Colors.orange,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Resacked sacks ready for milling: $_totalResackedSacks',
            textAlign: TextAlign.center,
            style: TextStyle(color: context.textColor, fontSize: 13),
          ),
          if (allSacksAccountedFor) ...[
            const SizedBox(height: 18),
            ElevatedButton(
              onPressed: _isSaving ? null : _handleProceedToMilling,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'PROCEED TO MILLING',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMillingUI() {
    final hasOverdueBatch = _existingBatches.any((batch) {
      if (batch['status'] != 'milling') return false;
      final startedAt = DateTime.parse(
        batch['milling_started_at']?.toString() ??
            batch['created_at'].toString(),
      ).toLocal();
      final duration = batch['estimated_duration_minutes'] as int? ?? 30;
      return DateTime.now().isAfter(startedAt.add(Duration(minutes: duration)));
    });
    return Column(
      children: [
        if (hasOverdueBatch)
          Container(
            width: double.infinity,
            color: Colors.red,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.white, size: 20),
                SizedBox(width: 12),
                Text(
                  'ALERT: ONE OR MORE BATCHES EXCEEDED TIME',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSummaryCard(),
                const SizedBox(height: 18),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: kGold.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: kGold.withOpacity(0.2)),
                  ),
                  child: Text(
                    'Total resacked: $_totalResackedSacks | Available to mill: $_availableResackedSacksTotal',
                    style: TextStyle(
                      color: context.textColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
                if (_remainingMinerSacks > 0) ...[
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: _isSaving ? null : _handleReturnToSacking,
                    icon: const Icon(Icons.arrow_back_rounded),
                    label: Text(
                      'RETURN TO SACKING ($_remainingMinerSacks SACKS LEFT)',
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: kGold,
                      side: BorderSide(color: kGold.withOpacity(0.7)),
                      minimumSize: const Size(double.infinity, 46),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
                if (_availableResackedSacksTotal > 0) ...[
                  const SizedBox(height: 18),
                  _buildMillingBatchForm(),
                ],
                const SizedBox(height: 18),
                if (!_hasUnfinishedMilling &&
                    _sacksProcessedSoFar == _totalSacksFromMiner &&
                    _totalSacksFromMiner > 0)
                  _buildCompletionAlert()
                else if (!_hasUnfinishedMilling)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange.withOpacity(0.3)),
                    ),
                    child: const Text(
                      'No sacks are ready to mill yet. Return to sacking and record the remaining miner sacks.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.orange),
                    ),
                  ),
                const SizedBox(height: 24),
                Text(
                  'Milling Batches',
                  style: TextStyle(
                    color: context.textColor,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                if (_existingBatches.isEmpty)
                  Text(
                    'No sacking batches have been recorded.',
                    style: TextStyle(color: context.mutedTextColor),
                  )
                else
                  ..._existingBatches.reversed.map(_buildBatchCard),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMillingBatchForm() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kGold.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'START MILLING BATCH',
            style: TextStyle(
              color: kGold,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Each selected drum starts one milling batch for one resacked sack. '
            'Available to mill: $_availableResackedSacksTotal.',
            style: TextStyle(color: context.mutedTextColor, fontSize: 12),
          ),
          const SizedBox(height: 16),
          const Text(
            'Choose machine',
            style: TextStyle(
              color: kGold,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          _buildMachineSelector(),
          if (_machines.where(_machineHasAvailableDrum).isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'No available machine with an available drum.',
                style: TextStyle(color: context.mutedTextColor, fontSize: 12),
              ),
            ),
          if (_selectedMachineId != null) ...[
            const SizedBox(height: 16),
            const Text(
              'Choose drum',
              style: TextStyle(
                color: kGold,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            _buildDrumSelector(),
            if (_selectedDrumIds.length > _availableResackedSacksTotal)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Select no more than $_availableResackedSacksTotal drums; each drum mills 1 sack.',
                  style: const TextStyle(color: Colors.orange, fontSize: 12),
                ),
              ),
          ],
          const SizedBox(height: 16),
          _buildInput(
            'Estimated Milling Duration (Minutes)',
            _estDurationController,
            hint: 'e.g. 30',
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _isSaving ||
                    _selectedDrumIds.isEmpty ||
                    _selectedDrumIds.length > _availableResackedSacksTotal
                ? null
                : _handleStartMillingBatch,
            style: ElevatedButton.styleFrom(
              backgroundColor: kGold,
              foregroundColor: kBlack,
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: kBlack,
                    ),
                  )
                : Text(
                    'START MILLING (${_selectedDrumIds.length} DRUM${_selectedDrumIds.length == 1 ? '' : 'S'})',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildMachineSelector() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _machines.map((m) {
        if (!_machineHasAvailableDrum(m)) return const SizedBox.shrink();
        final isSelected = _selectedMachineId == m['machine_id']?.toString();
        final status = m['status']?.toString().toLowerCase();
        final inUse = status == 'in_use';
        final isEmergency = status == 'emergency_stop';

        Color bgColor = Colors.green.withOpacity(0.1);
        Color textColor = Colors.green;
        if (inUse) {
          bgColor = Colors.red.withOpacity(0.1);
          textColor = Colors.red;
        } else if (isEmergency) {
          bgColor = Colors.orange.withOpacity(0.1);
          textColor = Colors.orange;
        }

        return ChoiceChip(
          label: Text(m['machine_name']),
          selected: isSelected,
          onSelected: isEmergency
              ? null
              : (val) {
                  setState(() {
                    _selectedMachineId = val ? m['machine_id']?.toString() : null;
                    _selectedDrumIds.clear();
                    if (val) {
                      final drums = _availableDrums(m);
                      if (drums.isNotEmpty) {
                        _selectedDrumIds.add(drums.first['drum_id'].toString());
                      }
                    }
                  });
                },
          selectedColor: kGold,
          backgroundColor: bgColor,
          labelStyle: TextStyle(
            color: isSelected ? kBlack : textColor,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
          side: BorderSide(
            color: isSelected ? kGold : textColor.withOpacity(0.3),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDrumSelector() {
    final machine = _machines.firstWhere(
      (m) => m['machine_id']?.toString() == _selectedMachineId,
    );
    final List<dynamic> drums = _availableDrums(machine);

    if (drums.isEmpty) {
      return Text(
        'No available drums for this machine.',
        style: TextStyle(color: context.mutedTextColor, fontSize: 12),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: drums.map((d) {
        final drumId = d['drum_id']?.toString();
        final isSelected = drumId != null && _selectedDrumIds.contains(drumId);
        final status = d['status']?.toString().toLowerCase();
        final inUse = status == 'in_use';
        final isEmergency = status == 'emergency_stop';

        Color bgColor = Colors.green.withOpacity(0.1);
        Color textColor = Colors.green;
        if (inUse) {
          bgColor = Colors.red.withOpacity(0.1);
          textColor = Colors.red;
        } else if (isEmergency) {
          bgColor = Colors.orange.withOpacity(0.1);
          textColor = Colors.orange;
        }

        return ChoiceChip(
          label: Text(d['drum_name']),
          selected: isSelected,
          onSelected: (inUse || isEmergency)
              ? null
              : (val) {
                  if (val &&
                      !_selectedDrumIds.contains(drumId) &&
                      _selectedDrumIds.length >= _availableResackedSacksTotal) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Each selected drum needs one available sack.',
                        ),
                      ),
                    );
                    return;
                  }
                  setState(() {
                    if (drumId == null) return;
                    if (val) {
                      _selectedDrumIds.add(drumId);
                    } else {
                      _selectedDrumIds.remove(drumId);
                    }
                  });
                },
          selectedColor: kGold,
          backgroundColor: bgColor,
          labelStyle: TextStyle(
            color: isSelected ? kBlack : textColor,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
          side: BorderSide(
            color: isSelected ? kGold : textColor.withOpacity(0.3),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildInput(
    String label,
    TextEditingController controller, {
    String? hint,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: kGold,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: TextStyle(color: context.textColor),
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: context.bgColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBatchCard(Map<String, dynamic> batch) {
    final isMilling = batch['status'] == 'milling';
    final isReadyToMill = batch['status'] == 'ready_to_mill';
    final isMillingRun = batch['batch_kind'] == 'milling';
    final isCompletedMilling =
        isMillingRun &&
        batch['status'] == 'completed' &&
        _batchNeedsUnloading(batch);
    final drumStatus = batch['drums']?['status']?.toString().toLowerCase();
    final isDrumEmergency = drumStatus == 'emergency_stop';
    final isSREmergency =
        _effectiveRequest.status == ServiceRequestStatus.emergencyStop;

    // Resolved logic: If Admin set the timestamp, we treat it as resolved
    // even if the background equipment sync is still processing.
    final isResolved = _effectiveRequest.emergencyResolvedAt != null;

    // Halted logic: If physically stopped AND not resolved yet.
    // If resolved, we want the "Continue" UI regardless of the request status.
    final isHalted = (isDrumEmergency || isSREmergency) && !isResolved;

    // Resume UI: If logically stopped (emergencyStop status) BUT physically ready (isResolved)
    final showResumeUI = isResolved && _effectiveRequest.emergencyStoppedAt != null;

    final createdAt = DateTime.parse(
      batch['milling_started_at']?.toString() ?? batch['created_at'].toString(),
    ).toLocal();
    final durationMinutes = batch['estimated_duration_minutes'] as int? ?? 30;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: (isHalted || showResumeUI)
              ? (isResolved
                    ? Colors.orange.withOpacity(0.3)
                    : Colors.red.withOpacity(0.3))
              : (isMilling
                    ? Colors.green.withOpacity(0.3)
                    : context.textColor.withOpacity(0.05)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isMilling)
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                tooltip: _showMillingActionLabels
                    ? 'Hide milling action labels'
                    : 'Show milling action labels',
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(
                  width: 32,
                  height: 32,
                ),
                onPressed: () => setState(
                  () => _showMillingActionLabels =
                      !_showMillingActionLabels,
                ),
                icon: Icon(
                  Icons.info_outline_rounded,
                  color: _showMillingActionLabels
                      ? kGold
                      : context.mutedTextColor,
                  size: 19,
                ),
              ),
            ),
          Row(
            children: [
          if (isMilling)
            MillingTimerCircle(
              startTime: createdAt,
              durationMinutes: durationMinutes,
              isPaused: isHalted || showResumeUI,
              pausedAt: _effectiveRequest.emergencyStoppedAt,
            )
          else if (isReadyToMill)
            const Icon(Icons.inventory_2_outlined, color: kGold, size: 40)
          else
            const Icon(Icons.check_circle, color: Colors.green, size: 40),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                      isMillingRun
                          ? 'Milling batch: ${batch['machines']?['machine_name'] ?? 'Machine'} - ${batch['drums']?['drum_name'] ?? 'Drum'}'
                          : isReadyToMill
                          ? 'Sacking batch ready to mill'
                      : 'Batch: ${batch['machines']?['machine_name'] ?? 'Machine'} - ${batch['drums']?['drum_name'] ?? 'Drum'}',
                  style: TextStyle(
                    color: (isHalted || showResumeUI)
                        ? (isResolved ? Colors.orange : Colors.red)
                        : context.textColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                Text(
                  isMillingRun
                      ? 'Milling ${batch['input_sacks']} resacked sacks'
                      : isReadyToMill
                      ? 'Sacked: ${batch['input_sacks']} miner sacks | Resacked: ${batch['output_sacks']}'
                      : 'Sacked: ${batch['input_sacks']} sacks | Resacked: ${batch['output_sacks']} sacks',
                  style: TextStyle(color: context.mutedTextColor, fontSize: 11),
                ),
                if (isMilling)
                  Text(
                    (isHalted || showResumeUI)
                        ? (isResolved ? 'ISSUE RESOLVED' : 'EMERGENCY PAUSED')
                        : 'Started at: ${DateFormat('hh:mm a').format(createdAt)}',
                    style: TextStyle(
                      color: (isHalted || showResumeUI)
                          ? (isResolved ? Colors.orange : Colors.red)
                          : context.mutedTextColor,
                      fontSize: 10,
                      fontWeight: (isHalted || showResumeUI)
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                if (isHalted || showResumeUI)
                  Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text(
                      isResolved
                          ? 'Admin resolved the issue. Continue when ready.'
                          : 'Wait for admin to resolve.',
                      style: TextStyle(
                        color: isResolved ? Colors.orange : Colors.red,
                        fontSize: 9,
                        fontStyle: FontStyle.italic,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                if ((isHalted || showResumeUI) &&
                    _effectiveRequest.emergencyStoppedAt != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 5),
                    child: Text(
                      'Stopped ${DateFormat('MMM d, yyyy • h:mm a').format(_effectiveRequest.emergencyStoppedAt!.toLocal())}\nReason: ${_effectiveRequest.emergencyReason ?? 'Not provided'}',
                      style: TextStyle(
                        color: Colors.red.shade700,
                        fontSize: 10,
                      ),
                    ),
                  ),
                if (isReadyToMill)
                  const Text(
                    'Ready for the milling stage',
                    style: TextStyle(
                      color: kGold,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                if (!isMilling &&
                    !isReadyToMill &&
                    batch['completed_at'] != null)
                  Text(
                    'Milled for: ${_calculateMillingDuration(createdAt, DateTime.parse(batch['completed_at']).toLocal())}',
                    style: const TextStyle(
                      color: Colors.green,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                if (isCompletedMilling) ...[
                  const SizedBox(height: 8),
                  if (_batchIsUnloading(batch)) ...[
                    UnloadingStopwatch(
                      startTime: DateTime.parse(
                        batch['unloading_started_at'].toString(),
                      ),
                      label: 'UNLOADING IN PROGRESS',
                    ),
                    TextButton.icon(
                      onPressed: _isSaving
                          ? null
                          : () => _handleCompleteBatchUnloading(batch),
                      icon: const Icon(Icons.check_rounded, size: 16),
                      label: const Text('FINISH UNLOADING'),
                    ),
                  ] else
                    OutlinedButton.icon(
                      onPressed: _isSaving
                          ? null
                          : () => _handleStartBatchUnloading(batch),
                      icon: const Icon(Icons.unarchive_outlined, size: 16),
                      label: const Text('GO TO UNLOADING & START'),
                    ),
                ],
                if (isMillingRun &&
                    batch['status'] == 'completed' &&
                    batch['unloading_completed_at'] != null)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      'UNLOADING COMPLETE',
                      style: TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (isMilling)
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (showResumeUI)
                  ElevatedButton.icon(
                    onPressed: _isResuming
                        ? null
                        : () => _handleResumeProcessing(),
                    icon: const Icon(Icons.play_arrow_rounded, size: 16),
                    label: const Text(
                      'CONTINUE PROCESSING',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      minimumSize: const Size(120, 36),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  )
                else if (isHalted)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.withOpacity(0.3)),
                    ),
                    child: const Text(
                      'SYSTEM HALTED',
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                  )
                else ...[
                  _buildMillingActionButton(
                    label: 'STOP',
                    tooltip: 'Emergency stop this batch',
                    icon: Icons.warning_amber_rounded,
                    color: Colors.red,
                    onPressed: () => _handleBatchEmergencyStop(batch),
                  ),
                  _buildMillingActionButton(
                    label: 'COMPLETE',
                    tooltip: 'Complete batch',
                    icon: Icons.check_circle_rounded,
                    color: Colors.green,
                    onPressed: () => _handleCompleteBatch(batch),
                  ),
                  _buildMillingActionButton(
                    label: 'EXTEND',
                    tooltip: 'Extend milling time',
                    icon: Icons.arrow_forward_rounded,
                    color: Colors.blue,
                    onPressed: () => _handleExtendBatch(batch),
                  ),
                ],
              ],
            ),
          if (isHalted || showResumeUI)
            Icon(
              isResolved ? Icons.check_circle_rounded : Icons.emergency_rounded,
              color: isResolved ? Colors.orange : Colors.red,
              size: 28,
            ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMillingActionButton({
    required String label,
    required String tooltip,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    if (!_showMillingActionLabels) {
      return IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        icon: Icon(icon, color: color, size: 23),
      );
    }

    return SizedBox(
      width: 96,
      height: 32,
      child: TextButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 15),
        label: Text(
          label,
          style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold),
        ),
        style: TextButton.styleFrom(
          foregroundColor: color,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          visualDensity: VisualDensity.compact,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
    );
  }

  Future<void> _handleBatchEmergencyStop(
    Map<String, dynamic> batch,
  ) async {
    if (_isSaving) return;
    final operatorId = Supabase.instance.client.auth.currentUser?.id;
    final machineId = batch['machine_id']?.toString();
    final drumId = batch['drum_id']?.toString();
    if (operatorId == null || machineId == null || drumId == null) return;

    final reasonController = TextEditingController();
    var stopEntireMachine = false;
    PlatformFile? evidencePhoto;
    final decision = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Emergency stop'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Choose what to stop:'),
                RadioListTile<bool>(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('This drum only'),
                  value: false,
                  groupValue: stopEntireMachine,
                  onChanged: (value) => setDialogState(
                    () => stopEntireMachine = value ?? false,
                  ),
                ),
                RadioListTile<bool>(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Entire machine and all its drums'),
                  value: true,
                  groupValue: stopEntireMachine,
                  onChanged: (value) => setDialogState(
                    () => stopEntireMachine = value ?? false,
                  ),
                ),
                TextField(
                  controller: reasonController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Reason for stopping',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () async {
                    final selection = await FilePicker.platform.pickFiles(
                      type: FileType.image,
                      allowMultiple: false,
                      withData: true,
                    );
                    if (selection == null || selection.files.isEmpty) return;
                    final file = selection.files.first;
                    if (file.size > 10 * 1024 * 1024) {
                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                        const SnackBar(
                          content: Text('Photo must be 10 MB or smaller.'),
                        ),
                      );
                      return;
                    }
                    if (file.bytes == null) {
                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                        const SnackBar(
                          content: Text('Could not read the selected photo.'),
                        ),
                      );
                      return;
                    }
                    // Let the native picker and its pointer events finish
                    // before rebuilding the dialog with the selected image.
                    await Future<void>.delayed(
                      const Duration(milliseconds: 100),
                    );
                    if (!dialogContext.mounted) return;
                    setDialogState(() => evidencePhoto = file);
                  },
                  icon: const Icon(Icons.add_a_photo_outlined),
                  label: Text(
                    evidencePhoto == null
                        ? 'Attach photo evidence (optional)'
                        : 'Change evidence photo',
                  ),
                ),
                if (evidencePhoto?.bytes != null) ...[
                  const SizedBox(height: 8),
                  Center(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.memory(
                        evidencePhoto!.bytes!,
                        height: 120,
                        width: 220,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () => setDialogState(
                        () => evidencePhoto = null,
                      ),
                      icon: const Icon(Icons.delete_outline, size: 16),
                      label: const Text('Remove photo'),
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Text(
                  'Current time: ${DateFormat('MMM d, yyyy - h:mm a').format(DateTime.now())}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () {
                final reason = reasonController.text.trim();
                if (reason.isEmpty) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(content: Text('Please enter a reason.')),
                  );
                  return;
                }
                Navigator.pop(dialogContext, {
                  'reason': reason,
                  'stopEntireMachine': stopEntireMachine,
                  'photo': evidencePhoto,
                });
              },
              icon: const Icon(Icons.warning_amber_rounded),
              label: const Text('Stop'),
            ),
          ],
        ),
      ),
    );
    reasonController.dispose();
    if (!mounted || decision == null) return;

    setState(() => _isSaving = true);
    String? evidenceUrl;
    final photo = decision['photo'] as PlatformFile?;
    if (photo != null) {
      final uploadResult = await _requestRepo.uploadEmergencyEvidence(
        requestId: _effectiveRequest.id,
        photo: photo,
      );
      final uploadFailure = uploadResult.fold<String?>(
        (error) => error.message,
        (url) {
          evidenceUrl = url;
          return null;
        },
      );
      if (!mounted) return;
      if (uploadFailure != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(uploadFailure)),
        );
        setState(() => _isSaving = false);
        return;
      }
    }
    final result = await _service.triggerEmergencyStop(
      requestId: _effectiveRequest.id,
      operatorId: operatorId,
      reason: decision['reason'] as String,
      evidenceUrl: evidenceUrl,
      machineId: machineId,
      drumId: drumId,
      stopEntireMachine: decision['stopEntireMachine'] as bool,
    );
    if (!mounted) return;
    final failure = result.fold<String?>(
      (error) => error.message,
      (_) => null,
    );
    if (failure != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(failure)),
      );
      setState(() => _isSaving = false);
      return;
    }
    await _loadData(showLoading: false);
    if (mounted) setState(() => _isSaving = false);
  }

  void _handleResumeProcessing() async {
    final operatorId = Supabase.instance.client.auth.currentUser?.id;
    if (operatorId == null) return;

    setState(() => _isResuming = true);

    final result = await _requestRepo.resumeProcessing(
      requestId: _effectiveRequest.id,
      operatorId: operatorId,
    );

    if (mounted) {
      result.fold((l) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l.message)));
        setState(() => _isResuming = false);
      }, (_) => _loadData());
    }
  }

  String _calculateMillingDuration(DateTime start, DateTime end) {
    final diff = end.difference(start);
    final hours = diff.inHours;
    final minutes = diff.inMinutes % 60;
    final seconds = diff.inSeconds % 60;

    if (hours > 0) return '${hours}h ${minutes}m ${seconds}s';
    if (minutes > 0) return '${minutes}m ${seconds}s';
    return '${seconds}s';
  }

  void _handleExtendBatch(Map<String, dynamic> batch) async {
    final operatorId = Supabase.instance.client.auth.currentUser?.id;
    if (operatorId == null) return;

    final controller = TextEditingController(text: '5');

    final int? additionalMins = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.surfaceColor,
        title: const Text(
          'Extend Milling Time',
          style: TextStyle(
            color: kGold,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter additional minutes needed for this batch:',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              autofocus: true,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: TextStyle(color: context.textColor),
              decoration: const InputDecoration(
                suffixText: 'Minutes',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: kGold),
            onPressed: () =>
                Navigator.pop(context, int.tryParse(controller.text)),
            child: const Text('Extend', style: TextStyle(color: kBlack)),
          ),
        ],
      ),
    );

    if (additionalMins == null || additionalMins <= 0) return;

    final result = await _service.extendBatchMilling(
      batchId: batch['batch_id'],
      additionalMinutes: additionalMins,
      requestId: widget.request.id,
      operatorId: operatorId,
    );

    result.fold(
      (l) => ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l.message))),
      (_) => _loadData(),
    );
  }

  Widget _buildCompletionAlert() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.green.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          const Icon(Icons.verified_rounded, color: Colors.green, size: 48),
          const SizedBox(height: 16),
          const Text(
            'All resacked batches milled!',
            style: TextStyle(
              color: Colors.green,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _allMillingBatchesUnloaded
                ? 'All milling batches are unloaded. Washing and separation can begin.'
                : 'Start unloading each completed batch here. You can continue sacking or milling while unloading runs.',
            textAlign: TextAlign.center,
            style: TextStyle(color: context.textColor, fontSize: 13),
          ),
          if (_allMillingBatchesUnloaded) ...[
            const SizedBox(height: 18),
            ElevatedButton(
              onPressed: _isSaving ? null : _handleProceedToWashing,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 48),
              ),
              child: const Text('PROCEED TO WASHING'),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _handleStartBatchUnloading(
    Map<String, dynamic> batch,
  ) async {
    if (_isSaving || !_batchNeedsUnloading(batch)) return;
    final operatorId = Supabase.instance.client.auth.currentUser?.id;
    if (operatorId == null) return;

    setState(() => _isSaving = true);
    if (_effectiveRequest.processingDetails.currentStage !=
        ProcessingStage.unloading) {
      final stageResult = await _service.updateProcessingStatus(
        requestId: _effectiveRequest.id,
        operatorId: operatorId,
        newStatus: ServiceRequestStatus.processing,
        currentStatus: _effectiveRequest.status.name,
        newStage: ProcessingStage.unloading,
        remarks: 'Moved to unloading and started a milling batch.',
      );
      final stageFailure = stageResult.fold<String?>(
        (value) => value.message,
        (_) => null,
      );
      if (stageFailure != null) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(stageFailure)));
          setState(() => _isSaving = false);
        }
        return;
      }
    }
    final result = await _service.startBatchUnloading(
      batchId: batch['batch_id'].toString(),
      requestId: _effectiveRequest.id,
      operatorId: operatorId,
    );
    if (!mounted) return;
    final failure = result.fold<String?>((value) => value.message, (_) => null);
    if (failure != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(failure)),
      );
    }
    await _loadData(showLoading: false);
    if (mounted) setState(() => _isSaving = false);
  }

  Future<void> _handleCompleteBatchUnloading(
    Map<String, dynamic> batch,
  ) async {
    if (_isSaving || !_batchIsUnloading(batch)) return;
    final operatorId = Supabase.instance.client.auth.currentUser?.id;
    if (operatorId == null) return;

    setState(() => _isSaving = true);
    final result = await _service.completeBatchUnloading(
      batchId: batch['batch_id'].toString(),
      requestId: _effectiveRequest.id,
      operatorId: operatorId,
    );
    if (!mounted) return;
    final failure = result.fold<String?>((value) => value.message, (_) => null);
    if (failure != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(failure)),
      );
    }
    await _loadData(showLoading: false);
    if (mounted) setState(() => _isSaving = false);
  }

  Future<void> _handleFinishAllUnloading() async {
    final operatorId = Supabase.instance.client.auth.currentUser?.id;
    final runningBatches = _unloadingMillingBatchesInProgress;
    if (operatorId == null || _isSaving || runningBatches.isEmpty) return;

    setState(() => _isSaving = true);
    final failures = <String>[];
    for (final batch in runningBatches) {
      final result = await _service.completeBatchUnloading(
        batchId: batch['batch_id'].toString(),
        requestId: _effectiveRequest.id,
        operatorId: operatorId,
      );
      result.fold<void>(
        (failure) => failures.add(failure.message),
        (_) {},
      );
    }
    if (!mounted) return;
    if (failures.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Some batches could not finish unloading: ${failures.first}')),
      );
    }
    await _loadData(showLoading: false);
    if (mounted) setState(() => _isSaving = false);
  }

  Widget _buildUnloadingUI() {
    final millingBatches = _existingBatches
        .where((batch) => batch['batch_kind'] == 'milling')
        .toList();
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Icon(Icons.unarchive_outlined, color: kGold, size: 52),
        const SizedBox(height: 12),
        Text(
          'UNLOADING STAGE',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: context.textColor,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Unload each completed milling batch. Work on other batches can continue while an unloading timer runs.',
          textAlign: TextAlign.center,
          style: TextStyle(color: context.mutedTextColor),
        ),
        const SizedBox(height: 20),
        if (millingBatches.isEmpty)
          Text(
            'No milling batches are available yet.',
            textAlign: TextAlign.center,
            style: TextStyle(color: context.mutedTextColor),
          )
        else
          ...millingBatches.map(_buildUnloadingBatchItem),
        if (_unloadingMillingBatchesInProgress.isNotEmpty) ...[
          const SizedBox(height: 4),
          OutlinedButton.icon(
            onPressed: _isSaving ? null : _handleFinishAllUnloading,
            icon: const Icon(Icons.done_all_rounded),
            label: Text(
              'FINISH ALL UNLOADING (${_unloadingMillingBatchesInProgress.length})',
            ),
          ),
        ],
        if (_hasUnloadedMillingBatch) ...[
          const SizedBox(height: 8),
          Text(
            'A batch marked DONE with unloading is ready to move to washing.',
            textAlign: TextAlign.center,
            style: TextStyle(color: context.mutedTextColor, fontSize: 12),
          ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: _isSaving ? null : _handleProceedToWashing,
            icon: const Icon(Icons.water_drop_outlined),
            label: const Text('PROCEED TO WASHING'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 52),
            ),
          ),
        ] else ...[
          const SizedBox(height: 8),
          Text(
            'Finish unloading at least one completed batch before washing.',
            textAlign: TextAlign.center,
            style: TextStyle(color: context.mutedTextColor, fontSize: 12),
          ),
        ],
      ],
    );
  }

  Widget _buildUnloadingBatchItem(Map<String, dynamic> batch) {
    final batchIsMilled = batch['status'] == 'completed';
    final isUnloaded = batch['unloading_completed_at'] != null;
    final startedAt = DateTime.tryParse(
      batch['unloading_started_at']?.toString() ?? '',
    );
    const title = 'Milling batch';
    final subtitle =
        '${batch['machines']?['machine_name'] ?? 'Machine'} · ${batch['drums']?['drum_name'] ?? 'Drum'}';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isUnloaded
              ? Colors.green.withOpacity(0.35)
              : kGold.withOpacity(0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isUnloaded
                    ? Icons.check_circle_rounded
                    : Icons.unarchive_outlined,
                color: isUnloaded ? Colors.green : kGold,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: context.textColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '$subtitle · ${batch['input_sacks'] ?? 1} sack',
                      style: TextStyle(
                        color: context.mutedTextColor,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                isUnloaded
                    ? 'DONE'
                    : startedAt != null
                    ? 'IN PROGRESS'
                    : batchIsMilled
                    ? 'READY'
                    : 'MILLING',
                style: TextStyle(
                  color: isUnloaded ? Colors.green : kGold,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          if (startedAt != null && !isUnloaded) ...[
            const SizedBox(height: 12),
            UnloadingStopwatch(startTime: startedAt),
          ],
          if (batchIsMilled && !isUnloaded) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: startedAt == null
                  ? OutlinedButton.icon(
                      onPressed: _isSaving
                          ? null
                          : () => _handleStartBatchUnloading(batch),
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: const Text('START UNLOADING'),
                    )
                  : ElevatedButton.icon(
                      onPressed: _isSaving
                          ? null
                          : () => _handleCompleteBatchUnloading(batch),
                      icon: const Icon(Icons.check_rounded),
                      label: const Text('FINISH UNLOADING'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildWashingUI() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Icon(Icons.water_drop_outlined, color: Colors.blue, size: 52),
        const SizedBox(height: 12),
        Text(
          'WASHING',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: context.textColor,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Each unloaded batch has its own washing timer. Other batches can continue through production.',
          textAlign: TextAlign.center,
          style: TextStyle(color: context.mutedTextColor),
        ),
        const SizedBox(height: 20),
        if (_unloadedMillingBatches.isEmpty)
          Text(
            'No unloaded batches are ready for washing yet.',
            textAlign: TextAlign.center,
            style: TextStyle(color: context.mutedTextColor),
          )
        else
          ..._unloadedMillingBatches.map(_buildWashingBatchItem),
        if (_washingMillingBatchesInProgress.isNotEmpty) ...[
          const SizedBox(height: 4),
          OutlinedButton.icon(
            onPressed: _isSaving ? null : _handleFinishAllWashing,
            icon: const Icon(Icons.done_all_rounded),
            label: Text(
              'FINISH ALL WASHING (${_washingMillingBatchesInProgress.length})',
            ),
          ),
        ],
        if (_canStartSeparation) ...[
          const SizedBox(height: 12),
          Text(
            'The miner will be asked to come to the facility. Start the separation timer manually when work begins.',
            textAlign: TextAlign.center,
            style: TextStyle(color: context.mutedTextColor, fontSize: 12),
          ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: _isSaving ? null : _handleProceedToSeparation,
            icon: const Icon(Icons.arrow_forward_rounded),
            label: const Text('GO TO SEPARATION & SEND SMS'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 52),
            ),
          ),
        ] else ...[
          const SizedBox(height: 8),
          _buildReturnToOperationsActions(),
          Text(
            'Separation starts after production, unloading, and washing are complete.',
            textAlign: TextAlign.center,
            style: TextStyle(color: context.mutedTextColor, fontSize: 12),
          ),
        ],
      ],
    );
  }

  Widget _buildWashingBatchItem(Map<String, dynamic> batch) {
    final startedAt = DateTime.tryParse(
      batch['washing_started_at']?.toString() ?? '',
    );
    final completedAt = DateTime.tryParse(
      batch['washing_completed_at']?.toString() ?? '',
    );
    final isComplete = completedAt != null;
    final machineName = batch['machines']?['machine_name'] ?? 'Machine';
    final drumName = batch['drums']?['drum_name'] ?? 'Drum';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isComplete
              ? Colors.green.withOpacity(0.35)
              : Colors.blue.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isComplete
                    ? Icons.check_circle_rounded
                    : Icons.water_drop_outlined,
                color: isComplete ? Colors.green : Colors.blue,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Milling batch',
                      style: TextStyle(
                        color: context.textColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '$machineName · $drumName · ${batch['input_sacks'] ?? 1} sack',
                      style: TextStyle(
                        color: context.mutedTextColor,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                isComplete ? 'DONE' : startedAt == null ? 'READY' : 'IN PROGRESS',
                style: TextStyle(
                  color: isComplete ? Colors.green : Colors.blue,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          if (startedAt != null && !isComplete) ...[
            const SizedBox(height: 12),
            UnloadingStopwatch(
              startTime: startedAt,
              label: 'WASHING & SEPARATION IN PROGRESS',
            ),
          ],
          if (!isComplete) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: startedAt == null
                  ? OutlinedButton.icon(
                      onPressed: _isSaving
                          ? null
                          : () => _handleStartBatchWashing(batch),
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: const Text('START WASHING'),
                    )
                  : ElevatedButton.icon(
                      onPressed: _isSaving
                          ? null
                          : () => _handleCompleteBatchWashing(batch),
                      icon: const Icon(Icons.check_rounded),
                      label: const Text('FINISH WASHING'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
            ),
          ] else if (startedAt != null) ...[
            const SizedBox(height: 10),
            Text(
              'Washing time: ${_formatDuration(completedAt.difference(startedAt))}',
              style: TextStyle(color: Colors.green, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSeparationUI() {
    final startedAt = _effectiveRequest.processingDetails.separationStartedAt;
    final completedAt =
        _effectiveRequest.processingDetails.separationCompletedAt;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.waves_rounded, color: Colors.teal, size: 64),
            const SizedBox(height: 20),
            Text(
              'SEPARATION',
              style: TextStyle(
                color: context.textColor,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Separate the washed material before refining.',
              textAlign: TextAlign.center,
              style: TextStyle(color: context.mutedTextColor),
            ),
            const SizedBox(height: 28),
            if (!_canStartSeparation)
              Column(
                children: [
                  Text(
                    'Finish all production, unloading, and batch washing first.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: context.mutedTextColor),
                  ),
                  const SizedBox(height: 20),
                  _buildReturnToOperationsActions(),
                ],
              )
            else if (startedAt == null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ElevatedButton.icon(
                    onPressed: _isSaving ? null : _handleStartSeparation,
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text('START SEPARATION'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 54),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _isSaving ? null : _handleSendSeparationSms,
                    icon: const Icon(Icons.sms_outlined),
                    label: const Text('RESEND MINER SMS'),
                  ),
                ],
              )
            else if (completedAt == null) ...[
              UnloadingStopwatch(
                startTime: startedAt,
                label: 'SEPARATION IN PROGRESS',
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _isSaving ? null : _handleCompleteSeparation,
                icon: const Icon(Icons.check_rounded),
                label: const Text('FINISH SEPARATION'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 54),
                ),
              ),
            ] else ...[
              _buildDurationSummary(
                startedAt,
                completedAt,
                title: 'SEPARATION COMPLETE',
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isSaving ? null : _handleProceedToRefining,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 54),
                ),
                child: const Text('PROCEED TO REFINING'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _handleProceedToSeparation() async {
    if (!_canStartSeparation) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Finish all production, unloading, and batch washing before separation.',
          ),
        ),
      );
      return;
    }
    if (_effectiveRequest.processingDetails.separationStartedAt != null) {
      await _advanceStage(ProcessingStage.separation);
      await _handleSendSeparationSms();
      return;
    }

    final operatorId = Supabase.instance.client.auth.currentUser?.id;
    if (operatorId == null || _isSaving) return;
    setState(() => _isSaving = true);

    final stageResult = await _service.updateProcessingStatus(
      requestId: _effectiveRequest.id,
      operatorId: operatorId,
      newStatus: ServiceRequestStatus.processing,
      currentStatus: _effectiveRequest.status.name,
      newStage: ProcessingStage.separation,
      remarks: 'All production and batch washing completed; miner notified to begin separation.',
    );
    final stageFailure = stageResult.fold<String?>(
      (failure) => failure.message,
      (_) => null,
    );
    if (stageFailure != null) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(stageFailure)));
        setState(() => _isSaving = false);
      }
      return;
    }

    final smsResult = await _requestRepo.sendSeparationStartSms(
      _effectiveRequest.id,
    );
    if (!mounted) return;
    final smsFailure = smsResult.fold<String?>(
      (failure) => failure.message,
      (_) => null,
    );
    if (smsFailure != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(smsFailure)));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Miner notified by SMS to begin separation.')),
      );
    }
    await _loadData(showLoading: false);
    if (mounted) setState(() => _isSaving = false);
  }

  Future<void> _handleSendSeparationSms() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    final result = await _requestRepo.sendSeparationStartSms(
      _effectiveRequest.id,
    );
    if (!mounted) return;
    result.fold<void>(
      (failure) => ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(failure.message))),
      (_) => ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Miner notified by SMS to begin separation.')),
      ),
    );
    setState(() => _isSaving = false);
  }

  Future<void> _handleStartSeparation() async {
    if (!_canStartSeparation || _isSaving) return;
    final operatorId = Supabase.instance.client.auth.currentUser?.id;
    if (operatorId == null) return;

    setState(() => _isSaving = true);
    final result = await _requestRepo.updateRequestStatus(
      requestId: _effectiveRequest.id,
      status: ServiceRequestStatus.processing.name,
      userId: operatorId,
      additionalData: {
        'separation_started_at': DateTime.now().toUtc().toIso8601String(),
      },
    );
    if (!mounted) return;
    final failure = result.fold<String?>((value) => value.message, (_) => null);
    if (failure != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(failure)));
    }
    await _loadData(showLoading: false);
    if (mounted) setState(() => _isSaving = false);
  }

  Future<void> _handleCompleteSeparation() async {
    if (_isSaving) return;
    final operatorId = Supabase.instance.client.auth.currentUser?.id;
    if (operatorId == null) return;

    setState(() => _isSaving = true);
    final result = await _requestRepo.updateRequestStatus(
      requestId: _effectiveRequest.id,
      status: ServiceRequestStatus.processing.name,
      userId: operatorId,
      additionalData: {
        'separation_completed_at': DateTime.now().toUtc().toIso8601String(),
      },
    );
    if (!mounted) return;
    final failure = result.fold<String?>((value) => value.message, (_) => null);
    if (failure != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(failure)));
    }
    await _loadData(showLoading: false);
    if (mounted) setState(() => _isSaving = false);
  }

  Widget _buildReturnToOperationsActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Continue the remaining production and unloading work before refining.',
          textAlign: TextAlign.center,
          style: TextStyle(color: context.mutedTextColor),
        ),
        const SizedBox(height: 16),
        if (_remainingMinerSacks > 0)
          OutlinedButton.icon(
            onPressed: _isSaving ? null : _handleReturnToSacking,
            icon: const Icon(Icons.inventory_2_outlined),
            label: Text('RETURN TO SACKING ($_remainingMinerSacks LEFT)'),
          ),
        if (_availableResackedSacksTotal > 0) ...[
          if (_remainingMinerSacks > 0) const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _isSaving ? null : _handleReturnToMilling,
            icon: const Icon(Icons.arrow_back_rounded),
            label: Text('RETURN TO MILLING ($_availableResackedSacksTotal READY)'),
          ),
        ],
        if (_hasMillingBatches && !_allMillingBatchesUnloaded) ...[
          if (_remainingMinerSacks > 0 || _availableResackedSacksTotal > 0)
            const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _isSaving
                ? null
                : () => _advanceStage(ProcessingStage.unloading),
            icon: const Icon(Icons.unarchive_outlined),
            label: const Text('RETURN TO UNLOADING'),
          ),
        ],
      ],
    );
  }

  Widget _buildRefiningUI() {
    final startedAt = _effectiveRequest.processingDetails.refiningStartedAt;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.auto_awesome_outlined, color: kGold, size: 68),
            const SizedBox(height: 20),
            Text(
              'REFINING',
              style: TextStyle(
                color: context.textColor,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            if (startedAt == null) ...[
              Text(
                'Start the refining timer when refining work begins.',
                textAlign: TextAlign.center,
                style: TextStyle(color: context.mutedTextColor),
              ),
              const SizedBox(height: 36),
              ElevatedButton.icon(
                onPressed: _isSaving ? null : _handleStartRefining,
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('START REFINING'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 54),
                ),
              ),
            ] else ...[
              UnloadingStopwatch(
                startTime: startedAt,
                label: 'REFINING IN PROGRESS',
              ),
              const SizedBox(height: 18),
              Text(
                'After refining is complete, enter your operator PIN to finalize processing. The miner and administrator will be notified, and the request will be submitted for billing.',
                textAlign: TextAlign.center,
                style: TextStyle(color: context.mutedTextColor),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _isSaving ? null : _handleCompleteRefining,
                icon: const Icon(Icons.verified_outlined),
                label: const Text('FINALIZE PROCESSING'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 54),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCompletedProcessingUI() {
    final startedAt = _effectiveRequest.processingDetails.refiningStartedAt;
    final completedAt = _effectiveRequest.processingDetails.refiningCompletedAt;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.task_alt_rounded, color: Colors.green, size: 64),
            const SizedBox(height: 16),
            Text(
              'PROCESSING COMPLETE',
              style: TextStyle(
                color: context.textColor,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (startedAt != null && completedAt != null) ...[
              const SizedBox(height: 18),
              _buildDurationSummary(
                startedAt,
                completedAt,
                title: 'REFINING TIME',
              ),
            ],
            const SizedBox(height: 16),
            Text(
              _completionSmsFailure == null
                  ? 'Processing is complete. The miner and administrator have been notified.'
                  : 'Processing is complete, but one or more SMS notifications could not be sent: $_completionSmsFailure',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _completionSmsFailure == null
                    ? context.mutedTextColor
                    : Colors.orange,
              ),
            ),
            if (_completionSmsFailure != null) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _isSaving ? null : _handleResendCompletionSms,
                icon: const Icon(Icons.sms_outlined),
                label: const Text('RESEND NOTIFICATIONS'),
              ),
            ],
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context, true),
              icon: const Icon(Icons.done_rounded),
              label: const Text('COMPLETE'),
              style: ElevatedButton.styleFrom(
                backgroundColor: kGold,
                foregroundColor: Colors.black,
                minimumSize: const Size(double.infinity, 52),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDurationSummary(
    DateTime start,
    DateTime end, {
    required String title,
  }) {
    final correctedStart = _correctLegacyUnloadingTimestamp(start, end);
    var duration = end.difference(correctedStart);
    if (duration.isNegative) duration = Duration.zero;
    final h = duration.inHours;
    final m = duration.inMinutes % 60;
    final s = duration.inSeconds % 60;
    final totalTime = h > 0 ? '${h}h ${m}m ${s}s' : '${m}m ${s}s';
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.green.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            title,
            style: TextStyle(
              color: Colors.green,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Total Time: $totalTime',
            style: TextStyle(
              color: context.textColor,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  void _handleStartUnloading() async {
    final operatorId = Supabase.instance.client.auth.currentUser?.id;
    if (operatorId == null) return;

    setState(() => _isLoading = true);
    await _requestRepo.updateRequestStatus(
      requestId: _effectiveRequest.id,
      status: ServiceRequestStatus.processing.name,
      userId: operatorId,
      additionalData: {
        'unloading_started_at': DateTime.now().toUtc().toIso8601String(),
      },
    );
    _loadData();
  }

  Future<void> _handleDoneUnloading() async {
    final operatorId = Supabase.instance.client.auth.currentUser?.id;
    if (operatorId == null) return;

    setState(() => _isLoading = true);
    final releaseResult = await _requestRepo.releaseEquipmentForServiceRequest(
      _effectiveRequest.id,
    );
    if (!mounted) return;

    String? releaseError;
    releaseResult.fold<void>(
      (failure) {
        releaseError = failure.message;
      },
      (_) {},
    );
    if (releaseError != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(releaseError!)));
      setState(() => _isLoading = false);
      return;
    }

    final result = await _requestRepo.updateRequestStatus(
      requestId: _effectiveRequest.id,
      status: ServiceRequestStatus.processing.name,
      userId: operatorId,
      additionalData: {
        'unloading_completed_at': DateTime.now().toUtc().toIso8601String(),
      },
    );
    if (!mounted) return;
    result.fold<void>(
      (failure) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(failure.message)));
        setState(() => _isLoading = false);
      },
      (_) {
        _loadData();
      },
    );
  }

  Future<void> _handleProceedToWashing() async {
    if (!_hasUnloadedMillingBatch) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Unload at least one completed milling batch before washing.',
          ),
        ),
      );
      return;
    }
    await _advanceStage(ProcessingStage.washingSeparation);
  }

  Future<void> _handleStartBatchWashing(
    Map<String, dynamic> batch,
  ) async {
    final operatorId = Supabase.instance.client.auth.currentUser?.id;
    if (operatorId == null || _isSaving) return;

    setState(() => _isSaving = true);
    final result = await _service.startBatchWashing(
      batchId: batch['batch_id'].toString(),
      requestId: _effectiveRequest.id,
      operatorId: operatorId,
    );
    if (!mounted) return;
    final failure = result.fold<String?>((value) => value.message, (_) => null);
    if (failure != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(failure)));
    }
    await _loadData(showLoading: false);
    if (mounted) setState(() => _isSaving = false);
  }

  Future<void> _handleCompleteBatchWashing(
    Map<String, dynamic> batch,
  ) async {
    final operatorId = Supabase.instance.client.auth.currentUser?.id;
    if (operatorId == null || _isSaving) return;

    setState(() => _isSaving = true);
    final result = await _service.completeBatchWashing(
      batchId: batch['batch_id'].toString(),
      requestId: _effectiveRequest.id,
      operatorId: operatorId,
    );
    if (!mounted) return;
    final failure = result.fold<String?>((value) => value.message, (_) => null);
    if (failure != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(failure)));
    }
    await _loadData(showLoading: false);
    if (mounted) setState(() => _isSaving = false);
  }

  Future<void> _handleFinishAllWashing() async {
    final operatorId = Supabase.instance.client.auth.currentUser?.id;
    final runningBatches = _washingMillingBatchesInProgress;
    if (operatorId == null || _isSaving || runningBatches.isEmpty) return;

    setState(() => _isSaving = true);
    final failures = <String>[];
    for (final batch in runningBatches) {
      final result = await _service.completeBatchWashing(
        batchId: batch['batch_id'].toString(),
        requestId: _effectiveRequest.id,
        operatorId: operatorId,
      );
      result.fold<void>(
        (failure) => failures.add(failure.message),
        (_) {},
      );
    }
    if (!mounted) return;
    if (failures.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Some batches could not finish washing: ${failures.first}')),
      );
    }
    await _loadData(showLoading: false);
    if (mounted) setState(() => _isSaving = false);
  }

  Future<void> _advanceStage(ProcessingStage stage) async {
    final operatorId = Supabase.instance.client.auth.currentUser?.id;
    if (operatorId == null || _isSaving) return;

    setState(() => _isSaving = true);
    final result = await _service.updateProcessingStatus(
      requestId: _effectiveRequest.id,
      operatorId: operatorId,
      newStatus: ServiceRequestStatus.processing,
      currentStatus: _effectiveRequest.status.toString().split('.').last,
      newStage: stage,
    );
    result.fold(
      (failure) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(failure.message)),
        );
        setState(() => _isSaving = false);
      },
      (_) {
        setState(() => _isSaving = false);
        _loadData();
      },
    );
  }

  Future<void> _handleProceedToRefining() async {
    if (!_canProceedToRefining) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Complete production, batch washing, and separation before refining.',
          ),
        ),
      );
      return;
    }
    await _advanceStage(ProcessingStage.refining);
  }

  Future<void> _handleCompleteRefining() async {
    final operatorId = Supabase.instance.client.auth.currentUser?.id;
    final refiningStartedAt =
        _effectiveRequest.processingDetails.refiningStartedAt;
    if (operatorId == null || _isSaving || refiningStartedAt == null) return;

    setState(() => _isSaving = true);
    final authorized = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PinDialog(
        title: 'Operator Security PIN',
        onConfirm: (pin) async {
          final pinResult = await _requestRepo.verifyUserPin(operatorId, pin);
          String? pinError;
          bool? pinIsValid;
          pinResult.fold<void>(
            (failure) {
              pinError = failure.message;
            },
            (isValid) {
              pinIsValid = isValid;
            },
          );
          if (pinError != null) return pinError;
          if (pinIsValid != true) return 'Incorrect PIN';
          return null;
        },
      ),
    );
    if (!mounted) return;
    if (authorized != true) {
      setState(() => _isSaving = false);
      return;
    }

    final completionResult = await _service.updateProcessingStatus(
      requestId: _effectiveRequest.id,
      operatorId: operatorId,
      newStatus: ServiceRequestStatus.processingCompleted,
      currentStatus: _effectiveRequest.status.name,
      newStage: ProcessingStage.completed,
      refiningCompletedAt: DateTime.now(),
      remarks:
          'Refining finalized with operator PIN confirmation; request submitted for billing.',
    );
    final completionFailure = completionResult.fold<String?>(
      (failure) => failure.message,
      (_) => null,
    );
    if (completionFailure != null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(completionFailure)),
        );
        setState(() => _isSaving = false);
      }
      return;
    }

    final smsResult = await _requestRepo.sendProcessingCompletionSms(
      _effectiveRequest.id,
    );
    if (!mounted) return;
    setState(() {
      _completionSmsFailure = smsResult.fold<String?>(
        (failure) => failure.message,
        (_) => null,
      );
    });
    await _loadData(showLoading: false);
    if (mounted) setState(() => _isSaving = false);
  }

  Future<void> _handleStartRefining() async {
    if (!_canProceedToRefining || _isSaving) return;
    final operatorId = Supabase.instance.client.auth.currentUser?.id;
    if (operatorId == null) return;

    setState(() => _isSaving = true);
    final result = await _service.updateProcessingStatus(
      requestId: _effectiveRequest.id,
      operatorId: operatorId,
      newStatus: ServiceRequestStatus.processing,
      currentStatus: _effectiveRequest.status.name,
      newStage: ProcessingStage.refining,
      refiningStartedAt: DateTime.now(),
      remarks: 'Refining timer started by the operator.',
    );
    if (!mounted) return;
    final failure = result.fold<String?>((value) => value.message, (_) => null);
    if (failure != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(failure)));
      setState(() => _isSaving = false);
      return;
    }
    await _loadData(showLoading: false);
    if (mounted) setState(() => _isSaving = false);
  }

  Future<void> _handleResendCompletionSms() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    final result = await _requestRepo.sendProcessingCompletionSms(
      _effectiveRequest.id,
    );
    if (!mounted) return;
    setState(() {
      _completionSmsFailure = result.fold<String?>(
        (failure) => failure.message,
        (_) => null,
      );
      _isSaving = false;
    });
  }

  Future<void> _handleSaveSackingBatch() async {
    if (_isSaving) return;
    final input = int.tryParse(_inputSacksController.text) ?? 0;
    final output = int.tryParse(_outputSacksController.text) ?? 0;
    if (input <= 0 || output <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter valid sack quantities')),
      );
      return;
    }

    if (input > _remainingMinerSacks) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Input sacks cannot exceed remaining miner sacks ($_remainingMinerSacks)',
          ),
        ),
      );
      return;
    }

    final operatorId = Supabase.instance.client.auth.currentUser?.id;
    if (operatorId == null) return;
    setState(() => _isSaving = true);
    final result = await _service.recordSackingBatch(
      requestId: widget.request.id,
      operatorId: operatorId,
      inputSacks: input,
      outputSacks: output,
    );
    final failure = result.fold<String?>((value) => value.message, (_) => null);
    if (!mounted) return;
    if (failure != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(failure)));
      setState(() => _isSaving = false);
      return;
    }
    _inputSacksController.clear();
    _outputSacksController.clear();
    await _loadData(showLoading: false);
    if (mounted) setState(() => _isSaving = false);
  }

  Future<void> _handleSkipRemainingSacking() async {
    if (_isSaving || _remainingMinerSacks <= 0) return;

    final sacksToKeep = _remainingMinerSacks;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Skip remaining sacking?'),
        content: Text(
          'The remaining $sacksToKeep sacks will be marked ready for milling '
          'without rebagging. Their sack count will stay $sacksToKeep.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('GO BACK'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('SKIP SACKING'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final operatorId = Supabase.instance.client.auth.currentUser?.id;
    if (operatorId == null) return;
    setState(() => _isSaving = true);

    final result = await _service.recordSackingBatch(
      requestId: widget.request.id,
      operatorId: operatorId,
      inputSacks: sacksToKeep,
      outputSacks: sacksToKeep,
      skippedSacking: true,
    );
    final failure = result.fold<String?>((value) => value.message, (_) => null);
    if (!mounted) return;
    if (failure != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(failure)),
      );
      setState(() => _isSaving = false);
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$sacksToKeep sacks kept unchanged and ready for milling.'),
      ),
    );
    await _loadData(showLoading: false);
    if (mounted) setState(() => _isSaving = false);
  }

  Future<void> _handleProceedToMilling() async {
    if (_availableResackedSacksTotal <= 0 && !_hasMillingBatches) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Record at least one sacking batch before milling.'),
        ),
      );
      return;
    }
    final operatorId = Supabase.instance.client.auth.currentUser?.id;
    if (operatorId == null) return;
    setState(() => _isSaving = true);
    final result = await _service.updateProcessingStatus(
      requestId: _effectiveRequest.id,
      operatorId: operatorId,
      newStatus: ServiceRequestStatus.processing,
      currentStatus: _effectiveRequest.status.name,
      newStage: ProcessingStage.millingCrushing,
      resetWashingTimestamps: _hasMoreSackingOrMillingWork,
      remarks: _remainingMinerSacks > 0
          ? 'Started milling prepared sacks; $_remainingMinerSacks miner sacks remain for sacking.'
          : 'All miner sacks are recorded; milling phase started.',
    );
    if (!mounted) return;
    final failure = result.fold<String?>((value) => value.message, (_) => null);
    if (failure != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(failure)));
      setState(() => _isSaving = false);
      return;
    }
    await _loadData(showLoading: false);
    if (mounted) setState(() => _isSaving = false);
  }

  Future<void> _handleReturnToSacking() async {
    if (_remainingMinerSacks <= 0) return;
    await _returnToOperationStage(
      ProcessingStage.rebagging,
      'Returned to sacking to process the remaining miner sacks.',
      resetWashing: true,
    );
  }

  Future<void> _handleReturnToMilling() async {
    if (_availableResackedSacksTotal <= 0) return;
    await _returnToOperationStage(
      ProcessingStage.millingCrushing,
      'Returned to milling to process the remaining resacked sacks.',
      resetWashing: true,
    );
  }

  Future<void> _returnToOperationStage(
    ProcessingStage stage,
    String remarks, {
    bool resetWashing = false,
  }) async {
    if (_isSaving) return;
    final operatorId = Supabase.instance.client.auth.currentUser?.id;
    if (operatorId == null) return;

    setState(() => _isSaving = true);
    final result = await _service.updateProcessingStatus(
      requestId: _effectiveRequest.id,
      operatorId: operatorId,
      newStatus: ServiceRequestStatus.processing,
      currentStatus: _effectiveRequest.status.name,
      newStage: stage,
      resetWashingTimestamps: resetWashing,
      remarks: remarks,
    );
    if (!mounted) return;
    final failure = result.fold<String?>((value) => value.message, (_) => null);
    if (failure != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(failure)),
      );
      setState(() => _isSaving = false);
      return;
    }
    await _loadData(showLoading: false);
    if (mounted) setState(() => _isSaving = false);
  }

  Future<void> _handleStartMillingBatch() async {
    if (_isSaving) return;
    final availableSacks = _availableResackedSacksTotal;
    final selectedDrumIds = _selectedDrumIds.toList();
    if (selectedDrumIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select at least one drum for milling.'),
        ),
      );
      return;
    }
    if (selectedDrumIds.length > availableSacks) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Only $availableSacks sacks are ready; select no more than $availableSacks drums.',
          ),
        ),
      );
      return;
    }
    if (_selectedMachineId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a machine.')),
      );
      return;
    }
    final machineId = _selectedMachineId!;
    final machine = _machines.firstWhere(
      (item) => item['machine_id']?.toString() == machineId,
    );
    final availableDrumIds = _availableDrums(machine)
        .map((drum) => drum['drum_id']?.toString())
        .whereType<String>()
        .toSet();
    if (selectedDrumIds.any((drumId) => !availableDrumIds.contains(drumId))) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('A selected drum is no longer available.')),
      );
      await _loadData(showLoading: false);
      return;
    }
    final duration = int.tryParse(_estDurationController.text) ?? 0;
    if (duration <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid milling duration.')),
      );
      return;
    }
    final operatorId = Supabase.instance.client.auth.currentUser?.id;
    if (operatorId == null) return;
    setState(() => _isSaving = true);
    var startedBatchCount = 0;
    String? failure;
    for (final drumId in selectedDrumIds) {
      final result = await _service.startBatchMilling(
        requestId: widget.request.id,
        operatorId: operatorId,
        machineId: machineId,
        drumId: drumId,
        inputSacks: 1,
        estimatedDurationMinutes: duration,
      );
      failure = result.fold<String?>((value) => value.message, (_) => null);
      if (failure != null) break;
      startedBatchCount++;
    }
    if (!mounted) return;
    if (failure != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        SnackBar(
          content: Text(
            startedBatchCount == 0
                ? failure
                : 'Started $startedBatchCount of ${selectedDrumIds.length} batches. $failure',
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Started $startedBatchCount milling ${startedBatchCount == 1 ? 'batch' : 'batches'}; 1 sack per drum.',
          ),
        ),
      );
    }
    await _loadData(showLoading: false);
    if (mounted) {
      setState(() => _isSaving = false);
    }
  }

  void _handleCompleteBatch(Map<String, dynamic> batch) async {
    final operatorId = Supabase.instance.client.auth.currentUser?.id;
    if (operatorId == null) return;

    final result = await _service.completeBatchMilling(
      batchId: batch['batch_id'],
      machineId: batch['machine_id'],
      drumId: batch['drum_id'],
      requestId: widget.request.id,
      operatorId: operatorId,
    );

    result.fold(
      (l) => ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l.message))),
      (_) => _loadData(),
    );
  }
}

class MillingTimerCircle extends StatefulWidget {
  final DateTime startTime;
  final int durationMinutes;
  final bool isPaused;
  final DateTime? pausedAt;

  const MillingTimerCircle({
    super.key,
    required this.startTime,
    required this.durationMinutes,
    this.isPaused = false,
    this.pausedAt,
  });

  @override
  State<MillingTimerCircle> createState() => _MillingTimerCircleState();
}

class _MillingTimerCircleState extends State<MillingTimerCircle> {
  late Timer _timer;
  double _percentage = 0.0;
  String _timeLeft = "00:00";
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _alertSounded = false;

  @override
  void initState() {
    super.initState();
    _calculateProgress();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted && !widget.isPaused) {
        setState(() => _calculateProgress());
      }
    });
  }

  void _calculateProgress() {
    final now = widget.isPaused && widget.pausedAt != null
        ? widget.pausedAt!.toLocal()
        : DateTime.now();
    final endTime = widget.startTime.add(
      Duration(minutes: widget.durationMinutes),
    );
    final totalDuration = endTime.difference(widget.startTime).inSeconds;
    final elapsed = now.difference(widget.startTime).inSeconds;

    if (elapsed >= totalDuration) {
      _percentage = 1.0;
      final over = elapsed - totalDuration;
      final m = (over ~/ 60).toString().padLeft(2, '0');
      final s = (over % 60).toString().padLeft(2, '0');
      _timeLeft = "+$m:$s";

      if (!_alertSounded && !widget.isPaused) {
        print('Timer complete: Playing alert sound');
        _playAlertSound();
        _alertSounded = true;
      }
    } else {
      _percentage = elapsed / totalDuration;
      if (_percentage < 0) _percentage = 0; // Guard against skew
      final remaining = totalDuration - elapsed;
      final m = (remaining ~/ 60).toString().padLeft(2, '0');
      final s = (remaining % 60).toString().padLeft(2, '0');
      _timeLeft = "$m:$s";
      _alertSounded = false;
    }
  }

  Future<void> _playAlertSound() async {
    if (widget.isPaused) return;
    try {
      print(
        'DEBUG: Attempting to play alert sound from assets/sounds/emergency.mp3',
      );
      await _audioPlayer.setReleaseMode(ReleaseMode.loop);
      await _audioPlayer.play(AssetSource('sounds/emergency.mp3'), volume: 1.0);
      print('DEBUG: Play command sent successfully');
    } catch (e) {
      print('AUDIO ERROR: Could not play emergency sound. Details: $e');
      print(
        'Make sure the file exists at assets/sounds/emergency.mp3 and is registered in pubspec.yaml',
      );
    }
  }

  @override
  void didUpdateWidget(MillingTimerCircle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPaused) {
      _audioPlayer.stop();
    }
    if (oldWidget.isPaused != widget.isPaused ||
        oldWidget.startTime != widget.startTime ||
        oldWidget.pausedAt != widget.pausedAt) {
      setState(_calculateProgress);
    }
  }

  @override
  void dispose() {
    _timer.cancel();
    _audioPlayer.stop();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isOverdue = _timeLeft.startsWith('+');
    final Color displayColor = widget.isPaused
        ? Colors.red
        : (isOverdue ? Colors.red : kGold);

    return SizedBox(
      width: 54,
      height: 54,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: _percentage,
            backgroundColor: displayColor.withOpacity(0.1),
            color: displayColor,
            strokeWidth: 4,
          ),
          Text(
            _timeLeft,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.bold,
              color: displayColor,
            ),
          ),
        ],
      ),
    );
  }
}

class UnloadingStopwatch extends StatefulWidget {
  final DateTime startTime;
  final String label;
  const UnloadingStopwatch({
    super.key,
    required this.startTime,
    this.label = 'UNLOADING IN PROGRESS',
  });

  @override
  State<UnloadingStopwatch> createState() => _UnloadingStopwatchState();
}

class _UnloadingStopwatchState extends State<UnloadingStopwatch> {
  late Timer _timer;
  late String _displayTime;

  @override
  void initState() {
    super.initState();
    _updateTime();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _updateTime());
    });
  }

  void _updateTime() {
    final now = DateTime.now();
    var diff = now.difference(
      _correctLegacyUnloadingTimestamp(widget.startTime, now),
    );
    if (diff.isNegative) diff = Duration.zero;
    final h = diff.inHours.toString().padLeft(2, '0');
    final m = (diff.inMinutes % 60).toString().padLeft(2, '0');
    final s = (diff.inSeconds % 60).toString().padLeft(2, '0');
    _displayTime = '$h:$m:$s';
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          widget.label,
          style: TextStyle(
            color: kGold,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _displayTime,
          style: TextStyle(
            color: context.textColor,
            fontSize: 48,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
          ),
        ),
      ],
    );
  }
}

DateTime _correctLegacyUnloadingTimestamp(DateTime timestamp, DateTime end) {
  if (timestamp.isAfter(end)) {
    // Older unloading timestamps were saved without a timezone and read
    // back as UTC. Correct those values using the device offset.
    return timestamp.subtract(DateTime.now().timeZoneOffset);
  }
  return timestamp;
}
