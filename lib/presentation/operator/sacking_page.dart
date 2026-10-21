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
  String? _selectedDrumId;
  final _inputSacksController = TextEditingController();
  final _outputSacksController = TextEditingController();
  final _millingSacksController = TextEditingController();
  final _estDurationController = TextEditingController(text: '30');
  Timer? _refreshTimer;
  bool _isSaving = false;
  bool _isResuming = false;

  @override
  void initState() {
    super.initState();
    _service = ServiceRequestService(_requestRepo);
    _loadData();
    // Periodically refresh the data from server to catch admin resolutions
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (mounted) _loadData(showLoading: false);
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _inputSacksController.dispose();
    _outputSacksController.dispose();
    _millingSacksController.dispose();
    _estDurationController.dispose();
    super.dispose();
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
      final selectedDrumStillAvailable = availableDrums.any(
        (drum) => drum['drum_id']?.toString() == _selectedDrumId,
      );
      final loadedBatches = batchesRes.getOrElse(() => <Map<String, dynamic>>[]);

      setState(() {
        _machines = machines;
        _selectedMachineId = machineToSelect?['machine_id']?.toString();
        if (!selectedDrumStillAvailable) {
          _selectedDrumId = availableDrums.isNotEmpty
              ? availableDrums.first['drum_id']?.toString()
              : null;
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
            ProcessingStage.washingSeparation => 'WASHING / SEPARATION',
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
        ProcessingStage.refining) {
      return _buildRefiningUI();
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
      ProcessingStage.refining => 4,
      ProcessingStage.completed => 5,
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

    final stages = <({String title, int rank, String result})>[
      (
        title: 'Sacking / Rebagging',
        rank: 0,
        result: '$_sacksProcessedSoFar / $_totalSacksFromMiner sacks',
      ),
      (
        title: 'Milling',
        rank: 1,
        result: '$_totalResackedSacks resacked sacks | '
            '${_formatDuration(_totalMillingDuration)}',
      ),
      (
        title: 'Unloading',
        rank: 2,
        result: formatDuration(
          details.unloadingStartedAt,
          details.unloadingCompletedAt,
        ),
      ),
      (
        title: 'Washing & Separation',
        rank: 3,
        result: formatDuration(
          details.washingStartedAt,
          details.washingCompletedAt,
        ),
      ),
      (title: 'Refining', rank: 4, result: 'Final stage'),
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
                final result = isComplete ||
                        (isCurrent && (stage.rank == 0 || stage.rank == 1))
                    ? stage.result
                    : isCurrent
                    ? (stage.rank == 2 && details.unloadingStartedAt != null
                          ? stage.result
                          : stage.rank == 3 && details.washingStartedAt != null
                          ? stage.result
                          : 'In progress')
                    : 'Waiting';
                return Container(
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
                      'Milling cannot proceed until every miner sack has been recorded in a sacking batch.',
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
            'Available total: $_availableResackedSacksTotal resacked sacks. Enter how many to mill in this batch.',
            style: TextStyle(color: context.mutedTextColor, fontSize: 12),
          ),
          const SizedBox(height: 12),
          _buildInput(
            'Resacked Sacks to Mill in This Batch',
            _millingSacksController,
            hint: 'Maximum $_availableResackedSacksTotal',
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
          ],
          const SizedBox(height: 16),
          _buildInput(
            'Estimated Milling Duration (Minutes)',
            _estDurationController,
            hint: 'e.g. 30',
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _isSaving || _availableResackedSacksTotal <= 0
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
                : const Text(
                    'START MILLING BATCH',
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
                    _selectedDrumId = null;
                    if (val) {
                      final drums = _availableDrums(m);
                      _selectedDrumId = drums.isNotEmpty
                          ? drums.first['drum_id']?.toString()
                          : null;
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
        final isSelected = _selectedDrumId == d['drum_id']?.toString();
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
                  setState(() => _selectedDrumId = val ? d['drum_id']?.toString() : null);
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
    final showResumeUI = isSREmergency && isResolved;

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
      child: Row(
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
                          ? 'Admin fixed the issue. You can continue.'
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
                  IconButton(
                    tooltip: 'Emergency stop this batch',
                    onPressed: () => _handleBatchEmergencyStop(batch),
                    icon: const Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.red,
                    ),
                  ),
                  IconButton(
                    onPressed: () => _handleCompleteBatch(batch),
                    tooltip: 'Complete batch',
                    icon: const Icon(
                      Icons.check_circle_rounded,
                      color: Colors.green,
                      size: 23,
                    ),
                  ),
                  IconButton(
                    onPressed: () => _handleExtendBatch(batch),
                    tooltip: 'Extend milling time',
                    icon: const Icon(
                      Icons.arrow_forward_rounded,
                      color: Colors.blue,
                      size: 23,
                    ),
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
    final hasActiveBatches = _hasUnfinishedMilling;

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
            hasActiveBatches
                ? 'Finish every ready and active milling batch before moving to unloading.'
                : 'All miner sacks are sacked and all resacked batches are milled. You can proceed to unloading.',
            textAlign: TextAlign.center,
            style: TextStyle(color: context.textColor, fontSize: 13),
          ),

          if (!hasActiveBatches) ...[
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _handleProceedToUnloading,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'PROCEED TO UNLOADING',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _handleProceedToUnloading() async {
    if (_hasUnfinishedMilling ||
        _sacksProcessedSoFar != _totalSacksFromMiner ||
        _totalSacksFromMiner <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Complete sacking and milling every batch before unloading.',
          ),
        ),
      );
      return;
    }
    final operatorId = Supabase.instance.client.auth.currentUser?.id;
    if (operatorId == null) return;

    setState(() => _isLoading = true);
    final result = await _service.updateProcessingStatus(
      requestId: _effectiveRequest.id,
      operatorId: operatorId,
      newStatus: ServiceRequestStatus.processing,
      currentStatus: _effectiveRequest.status.toString().split('.').last,
      newStage: ProcessingStage.unloading,
    );

    result.fold(
      (l) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l.message)));
        setState(() => _isLoading = false);
      },
      (_) => _loadData(), // Refresh to show unloading UI
    );
  }

  Widget _buildUnloadingUI() {
    final isStarted =
        _effectiveRequest.processingDetails.unloadingStartedAt != null;
    final isDone =
        _effectiveRequest.processingDetails.unloadingCompletedAt != null;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.unarchive_outlined, color: kGold, size: 64),
            const SizedBox(height: 24),
            Text(
              'UNLOADING STAGE',
              style: TextStyle(
                color: context.textColor,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Empty the drums and prepare for washing.',
              textAlign: TextAlign.center,
              style: TextStyle(color: context.mutedTextColor),
            ),

            const SizedBox(height: 48),
            if (!isStarted)
              ElevatedButton(
                onPressed: _handleStartUnloading,
                style: ElevatedButton.styleFrom(
                  backgroundColor: kGold,
                  foregroundColor: kBlack,
                  minimumSize: const Size(200, 60),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: const Text(
                  'START UNLOADING',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              )
            else if (isStarted && !isDone) ...[
              UnloadingStopwatch(
                startTime:
                    _effectiveRequest.processingDetails.unloadingStartedAt!,
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _handleDoneUnloading,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(200, 60),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: const Text(
                  'STOP UNLOADING',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ] else ...[
              _buildDurationSummary(
                _effectiveRequest.processingDetails.unloadingStartedAt!,
                _effectiveRequest.processingDetails.unloadingCompletedAt!,
                title: 'UNLOADING COMPLETE',
              ),
              const SizedBox(height: 40),
              ElevatedButton(
                onPressed: _handleProceedToWashing,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'PROCEED TO WASHING',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildWashingUI() {
    final startedAt = _effectiveRequest.processingDetails.washingStartedAt;
    final completedAt = _effectiveRequest.processingDetails.washingCompletedAt;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.water_drop_outlined, color: Colors.blue, size: 68),
            const SizedBox(height: 20),
            Text(
              'WASHING & SEPARATION',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: context.textColor,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'The service is now in the washing and separation stage.',
              textAlign: TextAlign.center,
              style: TextStyle(color: context.mutedTextColor),
            ),
            const SizedBox(height: 36),
            if (startedAt == null)
              ElevatedButton(
                onPressed: _isSaving ? null : _handleStartWashing,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 54),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'START WASHING & SEPARATION',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              )
            else if (completedAt == null) ...[
              UnloadingStopwatch(
                startTime: startedAt,
                label: 'WASHING & SEPARATION IN PROGRESS',
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _isSaving ? null : _handleStopWashing,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 54),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'STOP WASHING & SEPARATION',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ] else ...[
              _buildDurationSummary(
                startedAt,
                completedAt,
                title: 'WASHING & SEPARATION COMPLETE',
              ),
              const SizedBox(height: 28),
              ElevatedButton(
                onPressed: _isSaving ? null : _handleProceedToRefining,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 54),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'PROCEED TO REFINING',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
  Widget _buildRefiningUI() {
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
            Text(
              'The service is in the refining stage. Complete processing when refining is finished.',
              textAlign: TextAlign.center,
              style: TextStyle(color: context.mutedTextColor),
            ),
            const SizedBox(height: 36),
            ElevatedButton(
              onPressed: _isSaving ? null : _handleCompleteRefining,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 54),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'COMPLETE PROCESSING',
                style: TextStyle(fontWeight: FontWeight.bold),
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

  Future<void> _handleStartWashing() async {
    final operatorId = Supabase.instance.client.auth.currentUser?.id;
    if (operatorId == null) return;

    setState(() => _isSaving = true);
    final result = await _requestRepo.updateRequestStatus(
      requestId: _effectiveRequest.id,
      status: ServiceRequestStatus.processing.name,
      userId: operatorId,
      additionalData: {
        'washing_started_at': DateTime.now().toUtc().toIso8601String(),
      },
    );
    if (!mounted) return;
    final failureMessage = result.fold<String?>(
      (failure) => failure.message,
      (_) => null,
    );
    if (failureMessage != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(failureMessage)));
      setState(() => _isSaving = false);
      return;
    }

    await _loadData(showLoading: false);
    if (mounted) setState(() => _isSaving = false);
  }

  Future<void> _handleStopWashing() async {
    final operatorId = Supabase.instance.client.auth.currentUser?.id;
    if (operatorId == null) return;

    setState(() => _isSaving = true);
    final result = await _requestRepo.updateRequestStatus(
      requestId: _effectiveRequest.id,
      status: ServiceRequestStatus.processing.name,
      userId: operatorId,
      additionalData: {
        'washing_completed_at': DateTime.now().toUtc().toIso8601String(),
      },
    );
    if (!mounted) return;
    final failureMessage = result.fold<String?>(
      (failure) => failure.message,
      (_) => null,
    );
    if (failureMessage != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(failureMessage)));
      setState(() => _isSaving = false);
      return;
    }

    await _loadData(showLoading: false);
    if (mounted) setState(() => _isSaving = false);
  }

  void _handleProceedToWashing() async {
    final operatorId = Supabase.instance.client.auth.currentUser?.id;
    if (operatorId == null) return;

    setState(() => _isSaving = true);
    final result = await _service.updateProcessingStatus(
      requestId: _effectiveRequest.id,
      operatorId: operatorId,
      newStatus: ServiceRequestStatus.processing,
      currentStatus: _effectiveRequest.status.toString().split('.').last,
      newStage: ProcessingStage.washingSeparation,
    );

    result.fold((l) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l.message)));
      setState(() => _isSaving = false);
    }, (_) {
      setState(() => _isSaving = false);
      _loadData();
    });
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

  Future<void> _handleProceedToRefining() =>
      _advanceStage(ProcessingStage.refining);

  Future<void> _handleCompleteRefining() async {
    final operatorId = Supabase.instance.client.auth.currentUser?.id;
    if (operatorId == null || _isSaving) return;

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

          final result = await _service.updateProcessingStatus(
            requestId: _effectiveRequest.id,
            operatorId: operatorId,
            newStatus: ServiceRequestStatus.processingCompleted,
            currentStatus: _effectiveRequest.status.toString().split('.').last,
            newStage: ProcessingStage.completed,
            remarks: 'Processing completed after refining.',
          );
          return result.fold((failure) => failure.message, (_) => null);
        },
      ),
    );
    if (!mounted) return;
    if (authorized == true) {
      Navigator.pop(context, true);
    } else {
      setState(() => _isSaving = false);
    }
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

  Future<void> _handleProceedToMilling() async {
    if (_remainingMinerSacks != 0 ||
        _sacksProcessedSoFar != _totalSacksFromMiner ||
        _totalResackedSacks <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Complete sacking all miner sacks before milling.'),
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
      remarks: 'All miner sacks resacked; milling phase started.',
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

  Future<void> _handleStartMillingBatch() async {
    if (_isSaving) return;
    final millingSacks = int.tryParse(_millingSacksController.text) ?? 0;
    final availableSacks = _availableResackedSacksTotal;
    if (millingSacks <= 0 || millingSacks > availableSacks) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Enter a milling quantity from 1 to $availableSacks resacked sacks.',
          ),
        ),
      );
      return;
    }
    if (_selectedMachineId == null || _selectedDrumId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select machine and drum')),
      );
      return;
    }
    final machine = _machines.firstWhere(
      (item) => item['machine_id']?.toString() == _selectedMachineId,
    );
    final drum = (machine['drums'] as List).firstWhere(
      (item) => item['drum_id']?.toString() == _selectedDrumId,
    );
    if (drum['status']?.toString().toLowerCase() != 'available') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('That drum is no longer available.')),
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
    final result = await _service.startBatchMilling(
      requestId: widget.request.id,
      operatorId: operatorId,
      machineId: _selectedMachineId!,
      drumId: _selectedDrumId!,
      inputSacks: millingSacks,
      estimatedDurationMinutes: duration,
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
    _selectedMachineId = null;
    _selectedDrumId = null;
    _millingSacksController.clear();
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
