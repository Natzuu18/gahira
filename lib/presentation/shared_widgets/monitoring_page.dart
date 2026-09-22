import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../domain/entities/service_request_entity.dart';
import '../../infrastructure/repositories/supabase_service_request_repository.dart';
import '../shared_widgets/appColor.dart';
import '../shared_widgets/themeToggleButton.dart';
import '../operator/sacking_page.dart'; // Reusing the Timer Circle

class MonitoringPage extends StatefulWidget {
  final ServiceRequestEntity request;
  final String title;

  const MonitoringPage({super.key, required this.request, this.title = 'PROCESS MONITORING'});

  @override
  State<MonitoringPage> createState() => _MonitoringPageState();
}

class _MonitoringPageState extends State<MonitoringPage> {
  final _requestRepo = SupabaseServiceRequestRepository();
  
  ServiceRequestEntity? _currentRequest;
  List<Map<String, dynamic>> _batches = [];
  bool _isLoading = true;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadData();
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (mounted) _loadData(showLoading: false);
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadData({bool showLoading = true}) async {
    if (showLoading) setState(() => _isLoading = true);
    
    final batchesRes = await _requestRepo.getMillingBatches(widget.request.id);
    final requestRes = await _requestRepo.getServiceRequests();
    
    if (mounted) {
      setState(() {
        _batches = batchesRes.getOrElse(() => []);
        requestRes.fold((_) => null, (list) {
          try {
            _currentRequest = list.firstWhere((r) => r.id == widget.request.id);
          } catch (_) {}
        });
        _isLoading = false;
      });
    }
  }

  ServiceRequestEntity get _effectiveRequest => _currentRequest ?? widget.request;

  @override
  Widget build(BuildContext context) {
    final stage = _effectiveRequest.processingDetails.currentStage;
    final isUnloading = stage == ProcessingStage.unloading;

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
                if (_effectiveRequest.status == ServiceRequestStatus.emergencyStop)
                  _buildEmergencyAlert(),
                _buildStatusHeader(),
                const SizedBox(height: 24),
                _buildWorkflowProgress(),
                const SizedBox(height: 32),
                
                if (isUnloading) 
                  _buildUnloadingSection()
                else if (stage == ProcessingStage.millingCrushing || stage == ProcessingStage.rebagging)
                  _buildMillingSection()
                else
                  _buildGeneralInfoSection(),
              ],
            ),
          ),
    );
  }

  Widget _buildEmergencyAlert() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.red,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.red.withOpacity(0.4), blurRadius: 12, spreadRadius: 2)],
      ),
      child: Column(
        children: [
          const Icon(Icons.emergency_share_rounded, color: Colors.white, size: 48),
          const SizedBox(height: 16),
          const Text('EMERGENCY STOP ACTIVE', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
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
          const Text('Operations have been halted. Technical team notified.', 
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
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
                Text(_getStageName(stage).toUpperCase(), style: TextStyle(color: context.textColor, fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          _buildLiveBadge(),
        ],
      ),
    );
  }

  Widget _buildLiveBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.withOpacity(0.3)),
      ),
      child: const Row(
        children: [
          Icon(Icons.fiber_manual_record, color: Colors.red, size: 10),
          SizedBox(width: 4),
          Text('LIVE', style: TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildWorkflowProgress() {
    final stages = ProcessingStage.values.where((s) => s != ProcessingStage.none).toList();
    final currentStage = _effectiveRequest.processingDetails.currentStage;
    final currentIndex = stages.indexOf(currentStage);

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: stages.map((s) {
            final index = stages.indexOf(s);
            final isCompleted = index < currentIndex;
            final isCurrent = index == currentIndex;
            
            return Expanded(
              child: Column(
                children: [
                  Container(
                    height: 4,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      color: isCompleted ? Colors.green : (isCurrent ? kGold : context.mutedTextColor.withOpacity(0.2)),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(_getStageName(s).split(' ')[0], 
                    style: TextStyle(
                      color: isCurrent ? kGold : context.mutedTextColor, 
                      fontSize: 9, 
                      fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildMillingSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('MILLING BATCHES', style: TextStyle(color: context.textColor, fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        if (_batches.isEmpty)
          Center(child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Text('Waiting for operator to start batches...', style: TextStyle(color: context.mutedTextColor)),
          ))
        else
          ..._batches.reversed.map((b) => _buildBatchMonitoringCard(b)),
      ],
    );
  }

  Widget _buildBatchMonitoringCard(Map<String, dynamic> batch) {
    final isMilling = batch['status'] == 'milling';
    final createdAt = DateTime.parse(batch['created_at']).toLocal();
    final durationMinutes = batch['estimated_duration_minutes'] as int? ?? 30;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isMilling ? kGold.withOpacity(0.3) : context.textColor.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          if (isMilling)
            MillingTimerCircle(startTime: createdAt, durationMinutes: durationMinutes)
          else
            const Icon(Icons.check_circle, color: Colors.green, size: 40),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${batch['machines']?['machine_name']} - ${batch['drums']?['drum_name']}', 
                  style: TextStyle(color: context.textColor, fontWeight: FontWeight.bold, fontSize: 13)),
                Text('${batch['input_sacks']} In → ${batch['output_sacks']} Out', 
                  style: TextStyle(color: context.mutedTextColor, fontSize: 11)),
                if (isMilling)
                  Text('Processing...', style: TextStyle(color: kGold.withOpacity(0.8), fontSize: 10, fontWeight: FontWeight.bold))
                else
                  Text('Completed', style: TextStyle(color: Colors.green.withOpacity(0.8), fontSize: 10, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUnloadingSection() {
    final isStarted = _effectiveRequest.processingDetails.unloadingStartedAt != null;
    final isDone = _effectiveRequest.processingDetails.unloadingCompletedAt != null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kGold.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          const Icon(Icons.unarchive_outlined, color: kGold, size: 48),
          const SizedBox(height: 16),
          const Text('UNLOADING PROGRESS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 24),
          if (!isStarted)
            Text('Operator is preparing to unload...', style: TextStyle(color: context.mutedTextColor))
          else if (isStarted && !isDone)
            UnloadingStopwatch(startTime: _effectiveRequest.processingDetails.unloadingStartedAt!.toLocal())
          else
            Text('Unloading Finished', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
        ],
      ),
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
      case ProcessingStage.refining: return Icons.auto_awesome_rounded;
      case ProcessingStage.completed: return Icons.verified_rounded;
      default: return Icons.hourglass_empty_rounded;
    }
  }

  String _getStageName(ProcessingStage stage) {
    if (_effectiveRequest.status == ServiceRequestStatus.emergencyStop) return 'Emergency Stop';
    switch (stage) {
      case ProcessingStage.rebagging: return 'Sacking';
      case ProcessingStage.loading: return 'Loading';
      case ProcessingStage.millingCrushing: return 'Milling';
      case ProcessingStage.unloading: return 'Unloading';
      case ProcessingStage.washingSeparation: return 'Washing';
      case ProcessingStage.refining: return 'Refining';
      case ProcessingStage.completed: return 'Completed';
      default: return 'Queued';
    }
  }
}
