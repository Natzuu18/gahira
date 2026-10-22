import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/service_request_entity.dart';
import '../../infrastructure/repositories/supabase_service_request_repository.dart';
import '../shared_widgets/appColor.dart';
import '../shared_widgets/themeToggleButton.dart';
import '../operator/sacking_page.dart'; // Reusing the Timer Circle

class MonitoringPage extends StatefulWidget {
  final ServiceRequestEntity request;
  final String title;
  final bool isAdmin;

  const MonitoringPage({
    super.key,
    required this.request,
    this.title = 'PROCESS MONITORING',
    this.isAdmin = false,
  });

  @override
  State<MonitoringPage> createState() => _MonitoringPageState();
}

class _MonitoringPageState extends State<MonitoringPage> {
  final _requestRepo = SupabaseServiceRequestRepository();
  final ScrollController _stageScrollController = ScrollController();
  
  ServiceRequestEntity? _currentRequest;
  List<Map<String, dynamic>> _batches = [];
  ProcessingStage? _selectedStage;
  bool _isLoading = true;
  bool _isRefreshing = false;
  bool _refreshQueued = false;
  bool _isResolvingEmergency = false;
  bool _canScrollStagesLeft = false;
  bool _canScrollStagesRight = true;
  Timer? _refreshTimer;
  RealtimeChannel? _realtimeChannel;

  @override
  void initState() {
    super.initState();
    _stageScrollController.addListener(_updateStageScrollButtons);
    _subscribeToRealtime();
    _loadData();
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted) _loadData(showLoading: false);
    });
  }

  void _subscribeToRealtime() {
    final client = Supabase.instance.client;
    _realtimeChannel = client
        .channel('miner-process-${widget.request.id}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'service_requests',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'service_request_id',
            value: widget.request.id,
          ),
          callback: (_) => _loadData(showLoading: false),
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
          callback: (_) => _loadData(showLoading: false),
        )
        .subscribe();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _stageScrollController
      ..removeListener(_updateStageScrollButtons)
      ..dispose();
    final channel = _realtimeChannel;
    if (channel != null) {
      unawaited(Supabase.instance.client.removeChannel(channel));
    }
    super.dispose();
  }

  void _updateStageScrollButtons() {
    if (!_stageScrollController.hasClients) return;
    final position = _stageScrollController.position;
    final canScrollLeft = position.pixels > 1;
    final canScrollRight = position.pixels < position.maxScrollExtent - 1;
    if (canScrollLeft != _canScrollStagesLeft ||
        canScrollRight != _canScrollStagesRight) {
      setState(() {
        _canScrollStagesLeft = canScrollLeft;
        _canScrollStagesRight = canScrollRight;
      });
    }
  }

  void _scrollStages(bool forward) {
    if (!_stageScrollController.hasClients) return;
    final offset = _stageScrollController.offset + (forward ? 220 : -220);
    _stageScrollController.animateTo(
      offset
          .clamp(0, _stageScrollController.position.maxScrollExtent)
          .toDouble(),
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  Future<void> _loadData({bool showLoading = true}) async {
    if (_isRefreshing) {
      _refreshQueued = true;
      return;
    }
    _isRefreshing = true;
    if (showLoading && mounted) setState(() => _isLoading = true);

    try {
      final batchesRes = await _requestRepo.getMillingBatches(widget.request.id);
      final requestRes = await _requestRepo.getServiceRequests();

      if (mounted) {
        setState(() {
          _batches = batchesRes.getOrElse(() => []);
          requestRes.fold((_) => null, (list) {
            try {
              _currentRequest = list.firstWhere(
                (request) => request.id == widget.request.id,
              );
            } catch (_) {}
          });
          _isLoading = false;
        });
      }
    } finally {
      _isRefreshing = false;
      if (_refreshQueued && mounted) {
        _refreshQueued = false;
        unawaited(_loadData(showLoading: false));
      }
    }
  }

  ServiceRequestEntity get _effectiveRequest => _currentRequest ?? widget.request;

  ProcessingStage get _liveStage =>
      _effectiveRequest.processingDetails.currentStage;

  ProcessingStage get _displayStage => _selectedStage ?? _liveStage;

  bool get _hasActiveEquipmentEmergency => _batches.any((batch) {
    if (batch['status'] != 'milling') return false;
    final drumStopped =
        batch['drums']?['status']?.toString().toLowerCase() == 'emergency_stop';
    final machineStopped =
        batch['machines']?['status']?.toString().toLowerCase() ==
        'emergency_stop';
    return drumStopped || machineStopped;
  });

  bool get _isResolvedAwaitingOperator =>
      _effectiveRequest.emergencyResolvedAt != null &&
      _effectiveRequest.emergencyStoppedAt != null;

  Future<void> _resolveEmergency() async {
    if (_isResolvingEmergency) return;
    final adminId = Supabase.instance.client.auth.currentUser?.id;
    if (adminId == null) return;

    setState(() => _isResolvingEmergency = true);
    final result = await _requestRepo.resolveEmergencyStop(
      requestId: widget.request.id,
      adminId: adminId,
    );
    if (!mounted) return;

    result.fold(
      (failure) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(failure.message), backgroundColor: Colors.red),
        );
      },
      (_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Emergency issue resolved.')),
        );
      },
    );
    setState(() => _isResolvingEmergency = false);
    await _loadData(showLoading: false);
  }

  @override
  Widget build(BuildContext context) {
    final stage = _liveStage;

    return Scaffold(
      backgroundColor: context.bgColor,
      appBar: AppBar(
        backgroundColor: context.surfaceColor,
        title: Text(widget.title, style: const TextStyle(color: kGold, fontWeight: FontWeight.bold, letterSpacing: 1, fontSize: 16)),
        iconTheme: const IconThemeData(color: kGold),
        actions: const [ThemeToggleButton()],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: kGold))
        : SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_effectiveRequest.status == ServiceRequestStatus.emergencyStop ||
                    _hasActiveEquipmentEmergency ||
                    _isResolvedAwaitingOperator)
                  _buildEmergencyAlert(),
                _buildStatusHeader(),
                const SizedBox(height: 24),
                _buildWorkflowProgress(),
                const SizedBox(height: 32),
                
                _buildSelectedStageSection(_displayStage),
              ],
            ),
          ),
    );
  }

  Widget _buildEmergencyAlert() {
    final isResolved = _isResolvedAwaitingOperator;
    final alertColor = isResolved ? Colors.orange : Colors.red;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: alertColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: alertColor.withOpacity(0.4), blurRadius: 12, spreadRadius: 2)],
      ),
      child: Column(
        children: [
          Icon(
            isResolved ? Icons.check_circle_outline : Icons.emergency_share_rounded,
            color: Colors.white,
            size: 48,
          ),
          const SizedBox(height: 16),
          Text(
            isResolved ? 'ISSUE RESOLVED' : 'EMERGENCY STOP ACTIVE',
            style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Text(_effectiveRequest.emergencyReason ?? 'No reason provided', 
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 14, fontStyle: FontStyle.italic)),
          if (_effectiveRequest.emergencyStoppedAt != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text('Stopped at: ${DateFormat('hh:mm:ss a').format(_effectiveRequest.emergencyStoppedAt!.toLocal())}', 
                style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 11)),
            ),
          const SizedBox(height: 20),
          Text(
            isResolved
                ? 'The issue is resolved. Waiting for the operator to continue the process.'
                : _effectiveRequest.status == ServiceRequestStatus.emergencyStop
                ? 'Operations have been halted. Technical team notified.'
                : 'The affected drum or machine is halted. Other equipment may continue operating.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusHeader() {
    final stage = _effectiveRequest.processingDetails.currentStage;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kGold.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: kGold.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(_getStageIcon(stage), color: kGold, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Current Stage', style: TextStyle(color: context.mutedTextColor, fontSize: 11, fontWeight: FontWeight.bold)),
                Text(
                  (_isResolvedAwaitingOperator
                          ? 'Waiting for Operator'
                          : _effectiveRequest.status ==
                                ServiceRequestStatus.emergencyStop
                          ? 'Emergency Stop'
                          : _getStageName(stage))
                      .toUpperCase(),
                  style: TextStyle(color: context.textColor, fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          _buildLiveBadge(),
        ],
      ),
    );
  }

  Widget _buildLiveBadge() {
    final isPaused =
        _effectiveRequest.status == ServiceRequestStatus.emergencyStop &&
        !_isResolvedAwaitingOperator;
    final isWaiting = _isResolvedAwaitingOperator;
    final badgeColor = isWaiting
        ? Colors.orange
        : isPaused
        ? Colors.red
        : Colors.green;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: badgeColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.fiber_manual_record, color: badgeColor, size: 10),
          const SizedBox(width: 4),
          Text(
            isWaiting ? 'WAITING' : isPaused ? 'PAUSED' : 'LIVE',
            style: TextStyle(
              color: badgeColor,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkflowProgress() {
    final stages = ProcessingStage.values.where((s) => s != ProcessingStage.none).toList();
    final currentStage = _liveStage;
    final currentIndex = stages.indexOf(currentStage);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'TAP A STAGE TO REVIEW ITS PROGRESS',
          style: TextStyle(
            color: context.mutedTextColor,
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.7,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            IconButton(
              tooltip: 'Scroll to previous stages',
              onPressed: _canScrollStagesLeft
                  ? () => _scrollStages(false)
                  : null,
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.chevron_left_rounded),
              color: kGold,
            ),
            Expanded(
              child: Scrollbar(
                controller: _stageScrollController,
                thumbVisibility: true,
                child: SingleChildScrollView(
                  controller: _stageScrollController,
                  scrollDirection: Axis.horizontal,
                  child: Row(
            children: stages.map((stage) {
              final index = stages.indexOf(stage);
              final isCurrent = stage == currentStage;
              final isSelected = stage == _displayStage;
              final isComplete = _isStageComplete(stage, index, currentIndex);
              final color = isCurrent
                  ? kGold
                  : isComplete
                  ? Colors.green
                  : context.mutedTextColor;

              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => setState(() => _selectedStage = stage),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 104,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: color.withOpacity(isSelected ? 0.17 : 0.07),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? color : color.withOpacity(0.3),
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              isCurrent
                                  ? Icons.radio_button_checked_rounded
                                  : isComplete
                                  ? Icons.check_circle_rounded
                                  : Icons.circle_outlined,
                              color: color,
                              size: 14,
                            ),
                            const SizedBox(width: 5),
                            Expanded(
                              child: Text(
                                'STEP ${index + 1}',
                                style: TextStyle(
                                  color: color,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 7),
                        Text(
                          _getStageName(stage),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: context.textColor,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isCurrent ? 'CURRENT' : isComplete ? 'DONE' : 'WAITING',
                          style: TextStyle(color: color, fontSize: 8),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
                  ),
                ),
              ),
            ),
            IconButton(
              tooltip: 'Scroll to more stages',
              onPressed: _canScrollStagesRight
                  ? () => _scrollStages(true)
                  : null,
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.chevron_right_rounded),
              color: kGold,
            ),
          ],
        ),
      ],
    );
  }

  bool _isStageComplete(ProcessingStage stage, int index, int currentIndex) {
    final processing = _effectiveRequest.processingDetails;
    switch (stage) {
      case ProcessingStage.rebagging:
        final minerSacks = _effectiveRequest.materialDetails.numberOfSacks ?? 0;
        final sackedSacks = _batches
            .where((batch) => batch['batch_kind'] != 'milling')
            .fold<int>(
              0,
              (total, batch) =>
                  total + ((batch['input_sacks'] as num?)?.toInt() ?? 0),
            );
        return minerSacks > 0 && sackedSacks >= minerSacks;
      case ProcessingStage.loading:
        return currentIndex > index;
      case ProcessingStage.millingCrushing:
        final minerSacks = _effectiveRequest.materialDetails.numberOfSacks ?? 0;
        final sackedSacks = _batches
            .where((batch) => batch['batch_kind'] != 'milling')
            .fold<int>(
              0,
              (total, batch) =>
                  total + ((batch['input_sacks'] as num?)?.toInt() ?? 0),
            );
        return currentIndex > index &&
            minerSacks > 0 &&
            sackedSacks >= minerSacks &&
            !_batches.any(
              (batch) => batch['status'] == 'milling' ||
                  batch['status'] == 'ready_to_mill',
            );
      case ProcessingStage.unloading:
        return processing.unloadingCompletedAt != null;
      case ProcessingStage.washingSeparation:
        final washableBatches = _batches
            .where(
              (batch) =>
                  batch['batch_kind'] == 'milling' &&
                  batch['status'] == 'completed' &&
                  batch['unloading_completed_at'] != null,
            )
            .toList();
        return washableBatches.isNotEmpty &&
            washableBatches.every(
              (batch) => batch['washing_completed_at'] != null,
            );
      case ProcessingStage.separation:
        return processing.separationCompletedAt != null;
      case ProcessingStage.refining:
        return currentIndex > index ||
            _effectiveRequest.status == ServiceRequestStatus.completed ||
            processing.currentStage == ProcessingStage.completed;
      case ProcessingStage.completed:
        return _effectiveRequest.status == ServiceRequestStatus.completed ||
            processing.currentStage == ProcessingStage.completed;
      case ProcessingStage.none:
        return false;
    }
  }

  Widget _buildSelectedStageSection(ProcessingStage stage) {
    switch (stage) {
      case ProcessingStage.rebagging:
        return _buildSackingSection();
      case ProcessingStage.loading:
        return _buildLoadingSection();
      case ProcessingStage.millingCrushing:
        return _buildMillingSection();
      case ProcessingStage.unloading:
        return _buildUnloadingSection();
      case ProcessingStage.washingSeparation:
        return _buildWashingSection();
      case ProcessingStage.separation:
        return _buildSeparationSection();
      case ProcessingStage.refining:
      case ProcessingStage.completed:
        return _buildRefiningSection(stage);
      case ProcessingStage.none:
        return _buildGeneralInfoSection();
    }
  }

  Widget _buildSackingSection() {
    final totalMinerSacks = _effectiveRequest.materialDetails.numberOfSacks ?? 0;
    final sackingBatches = _batches
        .where((batch) => batch['batch_kind'] != 'milling')
        .toList();
    final sackedSacks = sackingBatches.fold<int>(
      0,
      (total, batch) => total + ((batch['input_sacks'] as num?)?.toInt() ?? 0),
    );
    final resackedSacks = sackingBatches.fold<int>(
      0,
      (total, batch) => total + ((batch['output_sacks'] as num?)?.toInt() ?? 0),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _stageSummaryCard(
          title: 'SACKING / REBAGGING PROGRESS',
          rows: [
            ('Miner sacks recorded', '$sackedSacks / $totalMinerSacks'),
            ('Resacked sacks ready for milling', '$resackedSacks'),
            ('Miner sacks remaining', '${(totalMinerSacks - sackedSacks).clamp(0, totalMinerSacks)}'),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          'SACKING BATCHES',
          style: TextStyle(color: context.textColor, fontSize: 15, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        if (sackingBatches.isEmpty)
          _stageMessage('The operator has not recorded a sacking batch yet.')
        else
          ...sackingBatches.reversed.map(_buildBatchMonitoringCard),
      ],
    );
  }

  Widget _buildLoadingSection() => _stageMessage(
    'The operator is preparing sacks and equipment for milling.',
  );

  Widget _buildWashingSection() {
    final unloadedBatches = _batches
        .where(
          (batch) =>
              batch['batch_kind'] == 'milling' &&
              batch['status'] == 'completed' &&
              batch['unloading_completed_at'] != null,
        )
        .toList();
    final washedBatches = unloadedBatches
        .where((batch) => batch['washing_completed_at'] != null)
        .length;
    final activeBatches = unloadedBatches
        .where(
          (batch) =>
              batch['washing_started_at'] != null &&
              batch['washing_completed_at'] == null,
        )
        .length;
    return _stageSummaryCard(
      title: 'WASHING PROGRESS',
      rows: [
        ('Batches washed', '$washedBatches / ${unloadedBatches.length}'),
        ('Currently washing', '$activeBatches'),
      ],
      message: unloadedBatches.isEmpty
          ? 'No unloaded batches are ready for washing.'
          : washedBatches == unloadedBatches.length
          ? 'All unloaded batches are washed.'
          : 'The operator is washing unloaded batches.',
      icon: Icons.water_drop_outlined,
      color: Colors.blue,
    );
  }

  Widget _buildSeparationSection() {
    final processing = _effectiveRequest.processingDetails;
    return _buildTimedStageSection(
      title: 'SEPARATION PROGRESS',
      startedAt: processing.separationStartedAt,
      completedAt: processing.separationCompletedAt,
      waitingMessage: 'Separation has not started yet.',
      runningMessage: 'The operator is separating the washed material.',
    );
  }

  Widget _buildRefiningSection(ProcessingStage stage) {
    final complete = stage == ProcessingStage.completed ||
        _effectiveRequest.status == ServiceRequestStatus.completed;
    return _stageSummaryCard(
      title: complete ? 'PROCESS COMPLETED' : 'REFINING PROGRESS',
      rows: [
        ('Status', complete ? 'Completed' : 'Waiting for refining'),
        ('Current service stage', _getStageName(_liveStage)),
      ],
      icon: complete ? Icons.verified_rounded : Icons.auto_awesome_rounded,
      color: complete ? Colors.green : kGold,
    );
  }

  Widget _buildTimedStageSection({
    required String title,
    required DateTime? startedAt,
    required DateTime? completedAt,
    required String waitingMessage,
    required String runningMessage,
  }) {
    final isCurrent = _liveStage == _displayStage;
    final elapsed = startedAt == null
        ? null
        : (completedAt ?? DateTime.now()).difference(startedAt.toLocal());
    final safeElapsed = elapsed == null || elapsed.isNegative
        ? Duration.zero
        : elapsed;

    return _stageSummaryCard(
      title: title,
      rows: [
        ('Started', startedAt == null ? 'Not started' : DateFormat('MMM d, yyyy  hh:mm a').format(startedAt.toLocal())),
        ('Finished', completedAt == null ? (startedAt == null ? '—' : 'In progress') : DateFormat('MMM d, yyyy  hh:mm a').format(completedAt.toLocal())),
        if (completedAt != null) ('Total time', _formatElapsed(safeElapsed)),
      ],
      message: startedAt == null
          ? waitingMessage
          : completedAt == null
          ? runningMessage
          : 'This stage is complete.',
      trailing: startedAt != null && completedAt == null && isCurrent
          ? UnloadingStopwatch(startTime: startedAt.toLocal())
          : null,
    );
  }

  String _formatElapsed(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    final seconds = duration.inSeconds % 60;
    if (hours > 0) return '${hours}h ${minutes}m ${seconds}s';
    if (minutes > 0) return '${minutes}m ${seconds}s';
    return '${seconds}s';
  }

  Widget _stageSummaryCard({
    required String title,
    required List<(String, String)> rows,
    String? message,
    Widget? trailing,
    IconData icon = Icons.info_outline_rounded,
    Color color = kGold,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          if (message != null) ...[
            const SizedBox(height: 12),
            Text(message, style: TextStyle(color: context.mutedTextColor, fontSize: 12)),
          ],
          for (final row in rows) ...[
            const SizedBox(height: 12),
            _infoRow(row.$1, row.$2),
          ],
          if (trailing != null) ...[
            const SizedBox(height: 16),
            Center(child: trailing),
          ],
        ],
      ),
    );
  }

  Widget _stageMessage(String message) => _stageSummaryCard(
    title: _getStageName(_displayStage).toUpperCase(),
    rows: const [],
    message: message,
  );

  Widget _buildMillingSection() {
    final millingBatches = _batches
        .where(
          (batch) =>
              batch['batch_kind'] == 'milling' ||
              (batch['batch_kind'] != 'sacking' && batch['machine_id'] != null),
        )
        .toList();
    final totalResacked = _batches
        .where(
          (batch) =>
              batch['batch_kind'] == 'sacking' ||
              (batch['batch_kind'] != 'milling' && batch['machine_id'] == null),
        )
        .fold<int>(
          0,
          (total, batch) =>
              total + ((batch['output_sacks'] as num?)?.toInt() ?? 0),
        );
    final totalMilled = millingBatches.fold<int>(
      0,
      (total, batch) => total + ((batch['input_sacks'] as num?)?.toInt() ?? 0),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _stageSummaryCard(
          title: 'MILLING PROGRESS',
          rows: [
            ('Resacked sacks prepared', '$totalResacked'),
            ('Sacks milled or in progress', '$totalMilled'),
            ('Prepared sacks remaining', '${(totalResacked - totalMilled).clamp(0, totalResacked)}'),
          ],
        ),
        const SizedBox(height: 12),
        Text('MILLING BATCHES', style: TextStyle(color: context.textColor, fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        if (millingBatches.isEmpty)
          Center(child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Text('Waiting for operator to start batches...', style: TextStyle(color: context.mutedTextColor)),
          ))
        else
          ...millingBatches.reversed.map(_buildBatchMonitoringCard),
      ],
    );
  }

  Widget _buildBatchMonitoringCard(Map<String, dynamic> batch) {
    final isMilling = batch['status'] == 'milling';
    final isDrumEmergency =
        batch['drums']?['status']?.toString().toLowerCase() == 'emergency_stop';
    final isMachineEmergency =
        batch['machines']?['status']?.toString().toLowerCase() ==
        'emergency_stop';
    final isEmergencyPaused =
        _effectiveRequest.status == ServiceRequestStatus.emergencyStop ||
        isDrumEmergency ||
        isMachineEmergency;
    final isResolvedAwaitingOperator = _isResolvedAwaitingOperator;
    final isReadyToMill = batch['status'] == 'ready_to_mill';
    final isMillingRun = batch['batch_kind'] == 'milling';
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
          color: isMilling || isReadyToMill
              ? kGold.withOpacity(0.3)
              : context.textColor.withOpacity(0.05),
        ),
      ),
      child: Row(
        children: [
          if (isMilling)
            MillingTimerCircle(
              startTime: createdAt,
              durationMinutes: durationMinutes,
              isPaused: isEmergencyPaused || isResolvedAwaitingOperator,
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
                      : '${batch['machines']?['machine_name'] ?? 'Machine'} - ${batch['drums']?['drum_name'] ?? 'Drum'}',
                  style: TextStyle(
                    color: context.textColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                Text(
                  isMillingRun
                      ? 'Milling ${batch['input_sacks']} resacked sacks'
                      : isReadyToMill
                      ? '${batch['input_sacks']} miner sacks sacked | ${batch['output_sacks']} resacked sacks'
                      : '${batch['input_sacks']} In | ${batch['output_sacks']} Out',
                  style: TextStyle(color: context.mutedTextColor, fontSize: 11),
                ),
                if (isMilling)
                  Text(
                    isResolvedAwaitingOperator
                        ? 'Issue resolved — waiting for operator to continue'
                        : isEmergencyPaused
                        ? 'Emergency paused'
                        : 'Processing...',
                    style: TextStyle(
                      color: isResolvedAwaitingOperator
                          ? Colors.orange
                          : isEmergencyPaused
                          ? Colors.red
                          : kGold.withOpacity(0.8),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                else if (isReadyToMill)
                  Text('Waiting for milling', style: TextStyle(color: kGold.withOpacity(0.8), fontSize: 10, fontWeight: FontWeight.bold))
                else
                  Text('Completed', style: TextStyle(color: Colors.green.withOpacity(0.8), fontSize: 10, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          if (widget.isAdmin &&
              isEmergencyPaused &&
              !isResolvedAwaitingOperator) ...[
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: _isResolvingEmergency ? null : _resolveEmergency,
              icon: _isResolvingEmergency
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check_circle_outline, size: 16),
              label: const Text('Resolve'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildUnloadingSection() {
    return _buildTimedStageSection(
      title: 'UNLOADING PROGRESS',
      startedAt: _effectiveRequest.processingDetails.unloadingStartedAt,
      completedAt: _effectiveRequest.processingDetails.unloadingCompletedAt,
      waitingMessage: 'The operator is preparing to unload.',
      runningMessage: 'The operator is unloading the drums.',
    );
  }

  Widget _buildGeneralInfoSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          _infoRow('Material', _effectiveRequest.materialDetails.condition ?? 'N/A'),
          _infoRow('Total Sacks', (_effectiveRequest.materialDetails.numberOfSacks ?? 0).toString()),
          _infoRow('Assigned To', 'Operator Team'),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: context.mutedTextColor, fontSize: 13)),
          Text(value, style: TextStyle(color: context.textColor, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  IconData _getStageIcon(ProcessingStage stage) {
    if (_effectiveRequest.status == ServiceRequestStatus.emergencyStop) return Icons.emergency_share_rounded;
    switch (stage) {
      case ProcessingStage.rebagging: return Icons.shopping_bag_outlined;
      case ProcessingStage.loading: return Icons.upload_file_rounded;
      case ProcessingStage.millingCrushing: return Icons.settings_input_component_rounded;
      case ProcessingStage.unloading: return Icons.unarchive_outlined;
      case ProcessingStage.washingSeparation: return Icons.waves_rounded;
      case ProcessingStage.separation: return Icons.filter_alt_outlined;
      case ProcessingStage.refining: return Icons.auto_awesome_rounded;
      case ProcessingStage.completed: return Icons.verified_rounded;
      default: return Icons.hourglass_empty_rounded;
    }
  }

  String _getStageName(ProcessingStage stage) {
    switch (stage) {
      case ProcessingStage.rebagging: return 'Sacking';
      case ProcessingStage.loading: return 'Loading';
      case ProcessingStage.millingCrushing: return 'Milling';
      case ProcessingStage.unloading: return 'Unloading';
      case ProcessingStage.washingSeparation: return 'Washing';
      case ProcessingStage.separation: return 'Separation';
      case ProcessingStage.refining: return 'Refining';
      case ProcessingStage.completed: return 'Completed';
      default: return 'Queued';
    }
  }
}
