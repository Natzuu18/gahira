import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../../domain/entities/service_request_entity.dart';
import '../../../infrastructure/repositories/supabase_equipment_repository.dart';
import '../../../infrastructure/repositories/supabase_service_request_repository.dart';
import '../../../application/services/service_request_service.dart';
import '../../presentation/shared_widgets/appColor.dart';
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
  final _estDurationController = TextEditingController(text: '30');
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _service = ServiceRequestService(_requestRepo);
    _loadData();
    // Periodically refresh the UI to update timer statuses and top-bar alerts
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final machinesRes = await _equipRepo.getMachines();
    final batchesRes = await _requestRepo.getMillingBatches(widget.request.id);
    final requestRes = await _requestRepo.getServiceRequests();
    
    setState(() {
      _machines = machinesRes.getOrElse(() => []);
      _existingBatches = batchesRes.getOrElse(() => []);
      
      requestRes.fold((_) => null, (list) {
        try {
          _currentRequest = list.firstWhere((r) => r.id == widget.request.id);
        } catch (_) {}
      });

      _isLoading = false;
    });
  }

  ServiceRequestEntity get _effectiveRequest => _currentRequest ?? widget.request;

  int get _totalSacksFromMiner => _effectiveRequest.materialDetails.numberOfSacks ?? 0;
  
  int get _sacksProcessedSoFar {
    int total = 0;
    for (var b in _existingBatches) {
      total += (b['input_sacks'] as int? ?? 0);
    }
    return total;
  }

  int get _remainingMinerSacks => _totalSacksFromMiner - _sacksProcessedSoFar;

  Duration get _totalMillingDuration {
    Duration total = Duration.zero;
    for (var b in _existingBatches) {
      if (b['status'] == 'completed' && b['completed_at'] != null) {
        final start = DateTime.parse(b['created_at']);
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
        title: Text('BATCH SACKING / MILLING', style: TextStyle(color: kGold, fontWeight: FontWeight.bold, letterSpacing: 1)),
        iconTheme: const IconThemeData(color: kGold),
      ),
      body: _isLoading 
        ? Center(child: CircularProgressIndicator(color: kGold))
        : _effectiveRequest.processingDetails.currentStage == ProcessingStage.unloading
          ? _buildUnloadingUI()
          : Column(
            children: [
              if (_existingBatches.any((b) => b['status'] == 'milling' && 
                  DateTime.now().isAfter(DateTime.parse(b['created_at']).toLocal().add(Duration(minutes: b['estimated_duration_minutes'] as int? ?? 30)))))
                Container(
                  width: double.infinity,
                  color: Colors.red,
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 20),
                      const SizedBox(width: 12),
                      const Text('ALERT: ONE OR MORE BATCHES EXCEEDED TIME', 
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                    ],
                  ),
                ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSummaryCard(),
                      const SizedBox(height: 24),
                      if (_remainingMinerSacks > 0) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Start New Batch', style: TextStyle(color: context.textColor, fontSize: 18, fontWeight: FontWeight.bold)),
                            if (_sacksProcessedSoFar == 0) // Only show skip if nothing processed yet
                              TextButton.icon(
                                onPressed: _handleSkipSacking,
                                icon: Icon(Icons.fast_forward_rounded, color: Colors.blue, size: 18),
                                label: Text('Skip Sacking', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildBatchForm(),
                      ] else ...[
                        _buildCompletionAlert(),
                      ],
                      const SizedBox(height: 32),
                      Text('Active & Past Batches', style: TextStyle(color: context.textColor, fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      ..._existingBatches.reversed.map((b) => _buildBatchCard(b)),
                    ],
                  ),
                ),
              ),
            ],
          ),
    );
  }

  Widget _buildSummaryCard() {
    final totalTime = _totalMillingDuration;
    final hours = totalTime.inHours;
    final minutes = totalTime.inMinutes % 60;
    final seconds = totalTime.inSeconds % 60;
    final timeStr = hours > 0 
        ? '${hours}h ${minutes}m ${seconds}s' 
        : (minutes > 0 ? '${minutes}m ${seconds}s' : '${seconds}s');

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
              _summaryItem('Processed', _sacksProcessedSoFar.toString()),
              _summaryItem('Total Milling Time', timeStr),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: _totalSacksFromMiner > 0 ? _sacksProcessedSoFar / _totalSacksFromMiner : 0,
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
        Text(label, style: TextStyle(color: context.mutedTextColor, fontSize: 11)),
        Text(value, style: TextStyle(color: context.textColor, fontSize: 18, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildBatchForm() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kGold.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Choose Machine', style: TextStyle(color: kGold, fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          _buildMachineSelector(),
          
          if (_selectedMachineId != null) ...[
            const SizedBox(height: 20),
            Text('Choose Drum', style: TextStyle(color: kGold, fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _buildDrumSelector(),
          ],

          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _buildInput('Sacks from Miner', _inputSacksController, hint: 'Max $_remainingMinerSacks'),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildInput('Resacked Quantity', _outputSacksController, hint: 'Resulting sacks'),
              ),
            ],
          ),

          const SizedBox(height: 20),
          _buildInput('Estimated Duration (Minutes)', _estDurationController, hint: 'e.g. 30'),
          
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _handleStartBatch,
            style: ElevatedButton.styleFrom(
              backgroundColor: kGold, 
              foregroundColor: kBlack,
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Start Batch Milling', style: TextStyle(fontWeight: FontWeight.bold)),
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
        final isSelected = _selectedMachineId == m['machine_id'];
        final inUse = m['status'] == 'in_use';
        
        return ChoiceChip(
          label: Text(m['machine_name']),
          selected: isSelected,
          onSelected: (val) {
            setState(() {
              _selectedMachineId = val ? m['machine_id'] : null;
              _selectedDrumId = null;
            });
          },
          selectedColor: kGold,
          backgroundColor: inUse ? Colors.red.withOpacity(0.1) : Colors.green.withOpacity(0.1),
          labelStyle: TextStyle(
            color: isSelected ? kBlack : (inUse ? Colors.red : Colors.green), 
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
          side: BorderSide(color: isSelected ? kGold : (inUse ? Colors.red.withOpacity(0.3) : Colors.green.withOpacity(0.3))),
        );
      }).toList(),
    );
  }

  Widget _buildDrumSelector() {
    final machine = _machines.firstWhere((m) => m['machine_id'] == _selectedMachineId);
    final List<dynamic> drums = machine['drums'] ?? [];
    
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: drums.map((d) {
        final isSelected = _selectedDrumId == d['drum_id'];
        final inUse = d['status'] == 'in_use';
        
        return ChoiceChip(
          label: Text(d['drum_name']),
          selected: isSelected,
          onSelected: inUse ? null : (val) {
            setState(() => _selectedDrumId = val ? d['drum_id'] : null);
          },
          selectedColor: kGold,
          backgroundColor: inUse ? Colors.red.withOpacity(0.1) : Colors.green.withOpacity(0.1),
          labelStyle: TextStyle(
            color: isSelected ? kBlack : (inUse ? Colors.red : Colors.green), 
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
          side: BorderSide(color: isSelected ? kGold : (inUse ? Colors.red.withOpacity(0.3) : Colors.green.withOpacity(0.3))),
        );
      }).toList(),
    );
  }

  Widget _buildInput(String label, TextEditingController controller, {String? hint}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: kGold, fontSize: 11, fontWeight: FontWeight.bold)),
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
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
      ],
    );
  }

  Widget _buildBatchCard(Map<String, dynamic> batch) {
    final isMilling = batch['status'] == 'milling';
    final createdAt = DateTime.parse(batch['created_at']).toLocal();
    final durationMinutes = batch['estimated_duration_minutes'] as int? ?? 30;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isMilling ? Colors.green.withOpacity(0.3) : context.textColor.withOpacity(0.05)),
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
                Text('Batch: ${batch['machines']?['machine_name']} - ${batch['drums']?['drum_name']}', 
                  style: TextStyle(color: context.textColor, fontWeight: FontWeight.bold, fontSize: 13)),
                Text('Input: ${batch['input_sacks']} sacks → Output: ${batch['output_sacks']} sacks', 
                  style: TextStyle(color: context.mutedTextColor, fontSize: 11)),
                if (isMilling)
                  Text('Started at: ${DateFormat('hh:mm a').format(createdAt)}', 
                    style: TextStyle(color: context.mutedTextColor, fontSize: 10)),
                if (!isMilling && batch['completed_at'] != null)
                  Text('Milled for: ${_calculateMillingDuration(createdAt, DateTime.parse(batch['completed_at']).toLocal())}',
                    style: const TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          if (isMilling)
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton(
                  onPressed: () => _handleCompleteBatch(batch),
                  style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                  child: const Text('Complete', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 13)),
                ),
                TextButton(
                  onPressed: () => _handleExtendBatch(batch),
                  style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                  child: const Text('Extend', style: TextStyle(color: Colors.blue, fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
        ],
      ),
    );
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
        title: const Text('Extend Milling Time', style: TextStyle(color: kGold, fontSize: 16, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Enter additional minutes needed for this batch:', style: TextStyle(fontSize: 13)),
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
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: kGold),
            onPressed: () => Navigator.pop(context, int.tryParse(controller.text)), 
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
      (l) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.message))),
      (_) => _loadData(),
    );
  }

  Widget _buildCompletionAlert() {
    final hasActiveBatches = _existingBatches.any((b) => b['status'] == 'milling');
    
    return Container(
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
          const Text('All miner sacks processed!', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          Text(hasActiveBatches 
            ? 'Wait for all active batches to finish milling before moving to unloading.' 
            : 'All batches completed. You can now proceed to the Unloading stage.', 
            textAlign: TextAlign.center,
            style: TextStyle(color: context.textColor, fontSize: 13)),
          
          if (!hasActiveBatches) ...[
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _handleProceedToUnloading,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('PROCEED TO UNLOADING', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ],
      ),
    );
  }

  void _handleProceedToUnloading() async {
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.message)));
        setState(() => _isLoading = false);
      },
      (_) => _loadData(), // Refresh to show unloading UI
    );
  }

  Widget _buildUnloadingUI() {
    final isStarted = _effectiveRequest.processingDetails.unloadingStartedAt != null;
    final isDone = _effectiveRequest.processingDetails.unloadingCompletedAt != null;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.unarchive_outlined, color: kGold, size: 64),
            const SizedBox(height: 24),
            Text('UNLOADING STAGE', style: TextStyle(color: context.textColor, fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Text('Empty the drums and prepare for washing.', textAlign: TextAlign.center, style: TextStyle(color: context.mutedTextColor)),
            
            const SizedBox(height: 48),
            if (!isStarted)
              ElevatedButton(
                onPressed: _handleStartUnloading,
                style: ElevatedButton.styleFrom(
                  backgroundColor: kGold,
                  foregroundColor: kBlack,
                  minimumSize: const Size(200, 60),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ),
                child: const Text('START UNLOADING', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              )
            else if (isStarted && !isDone) ...[
              UnloadingStopwatch(startTime: _effectiveRequest.processingDetails.unloadingStartedAt!),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _handleDoneUnloading,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(200, 60),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ),
                child: const Text('DONE UNLOADING', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ] else ...[
              _buildDurationSummary(_effectiveRequest.processingDetails.unloadingStartedAt!, _effectiveRequest.processingDetails.unloadingCompletedAt!),
              const SizedBox(height: 40),
              ElevatedButton(
                onPressed: _handleProceedToWashing,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('PROCEED TO WASHING', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDurationSummary(DateTime start, DateTime end) {
    final duration = end.difference(start);
    final m = duration.inMinutes;
    final s = duration.inSeconds % 60;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.green.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          const Text('UNLOADING COMPLETE', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 8),
          Text('Total Time: ${m}m ${s}s', style: TextStyle(color: context.textColor, fontSize: 28, fontWeight: FontWeight.bold)),
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
        'unloading_started_at': DateTime.now().toIso8601String(),
      },
    );
    _loadData();
  }

  void _handleDoneUnloading() async {
    final operatorId = Supabase.instance.client.auth.currentUser?.id;
    if (operatorId == null) return;

    setState(() => _isLoading = true);
    await _requestRepo.updateRequestStatus(
      requestId: _effectiveRequest.id,
      status: ServiceRequestStatus.processing.name,
      userId: operatorId,
      additionalData: {
        'unloading_completed_at': DateTime.now().toIso8601String(),
      },
    );
    _loadData();
  }

  void _handleSkipSacking() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Skip Sacking?'),
        content: const Text('This will skip the batching process and use the miner\'s original sacks for the next stages.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Skip', style: TextStyle(color: Colors.blue))),
        ],
      ),
    );

    if (confirm != true) return;

    final operatorId = Supabase.instance.client.auth.currentUser?.id;
    if (operatorId == null) return;

    setState(() => _isLoading = true);
    
    final result = await _service.updateProcessingStatus(
      requestId: widget.request.id,
      operatorId: operatorId,
      newStatus: ServiceRequestStatus.processing,
      currentStatus: widget.request.status.toString().split('.').last,
      newStage: ProcessingStage.washingSeparation,
      sackedQuantity: _totalSacksFromMiner,
      remarks: 'Operator skipped sacking/milling stage. Using original sacks.',
    );

    result.fold(
      (l) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.message)));
        setState(() => _isLoading = false);
      },
      (_) => Navigator.pop(context, true),
    );
  }

  void _handleProceedToWashing() async {
    final operatorId = Supabase.instance.client.auth.currentUser?.id;
    if (operatorId == null) return;

    setState(() => _isLoading = true);
    final result = await _service.updateProcessingStatus(
      requestId: widget.request.id,
      operatorId: operatorId,
      newStatus: ServiceRequestStatus.processing,
      currentStatus: widget.request.status.toString().split('.').last,
      newStage: ProcessingStage.washingSeparation,
    );

    result.fold(
      (l) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.message)));
        setState(() => _isLoading = false);
      },
      (_) => Navigator.pop(context, true),
    );
  }

  void _handleStartBatch() async {
    if (_selectedMachineId == null || _selectedDrumId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select machine and drum')));
      return;
    }
    
    // Safety check: ensure drum is still available
    final machine = _machines.firstWhere((m) => m['machine_id'] == _selectedMachineId);
    final drum = (machine['drums'] as List).firstWhere((d) => d['drum_id'] == _selectedDrumId);
    if (drum['status']?.toString().toLowerCase() == 'in_use') {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error: This drum was just taken by another batch')));
      _loadData(); // Refresh statuses
      return;
    }

    final input = int.tryParse(_inputSacksController.text) ?? 0;
    final output = int.tryParse(_outputSacksController.text) ?? 0;
    final duration = int.tryParse(_estDurationController.text) ?? 30;
    
    if (input <= 0 || output <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter valid sack quantities')));
      return;
    }
    
    if (input > _remainingMinerSacks) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Input sacks cannot exceed remaining miner sacks ($_remainingMinerSacks)')));
      return;
    }

    final operatorId = Supabase.instance.client.auth.currentUser?.id;
    if (operatorId == null) return;

    final result = await _service.startBatchMilling(
      requestId: widget.request.id,
      operatorId: operatorId,
      machineId: _selectedMachineId!,
      drumId: _selectedDrumId!,
      inputSacks: input,
      outputSacks: output,
      estimatedDurationMinutes: duration,
    );

    result.fold(
      (l) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.message))),
      (_) {
        _inputSacksController.clear();
        _outputSacksController.clear();
        _selectedMachineId = null;
        _selectedDrumId = null;
        _loadData();
      },
    );
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
      (l) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.message))),
      (_) => _loadData(),
    );
  }
}

class MillingTimerCircle extends StatefulWidget {
  final DateTime startTime;
  final int durationMinutes;

  const MillingTimerCircle({super.key, required this.startTime, required this.durationMinutes});

  @override
  State<MillingTimerCircle> createState() => _MillingTimerCircleState();
}

class _MillingTimerCircleState extends State<MillingTimerCircle> {
  late Timer _timer;
  late double _percentage;
  late String _timeLeft;
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _alertSounded = false;

  @override
  void initState() {
    super.initState();
    _calculateProgress();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() => _calculateProgress());
      }
    });
  }

  void _calculateProgress() {
    final now = DateTime.now(); // Local time
    final endTime = widget.startTime.add(Duration(minutes: widget.durationMinutes)); // startTime is now converted toLocal() in parent
    final totalDuration = endTime.difference(widget.startTime).inSeconds;
    final elapsed = now.difference(widget.startTime).inSeconds;

    if (elapsed >= totalDuration) {
      _percentage = 1.0;
      final over = elapsed - totalDuration;
      final m = (over ~/ 60).toString().padLeft(2, '0');
      final s = (over % 60).toString().padLeft(2, '0');
      _timeLeft = "+$m:$s";
      
      if (!_alertSounded) {
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
    try {
      print('DEBUG: Attempting to play alert sound from assets/sounds/emergency.mp3');
      await _audioPlayer.setReleaseMode(ReleaseMode.loop);
      await _audioPlayer.play(AssetSource('sounds/emergency.mp3'), volume: 1.0);
      print('DEBUG: Play command sent successfully');
    } catch (e) {
      print('AUDIO ERROR: Could not play emergency sound. Details: $e');
      print('Make sure the file exists at assets/sounds/emergency.mp3 and is registered in pubspec.yaml');
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
    return SizedBox(
      width: 54,
      height: 54,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: _percentage,
            backgroundColor: kGold.withOpacity(0.1),
            color: isOverdue ? Colors.red : kGold,
            strokeWidth: 4,
          ),
          Text(_timeLeft, style: TextStyle(
            fontSize: 9, 
            fontWeight: FontWeight.bold, 
            color: isOverdue ? Colors.red : kGold,
          )),
        ],
      ),
    );
  }
}

class UnloadingStopwatch extends StatefulWidget {
  final DateTime startTime;
  const UnloadingStopwatch({super.key, required this.startTime});

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
    final diff = DateTime.now().difference(widget.startTime);
    final m = diff.inMinutes.toString().padLeft(2, '0');
    final s = (diff.inSeconds % 60).toString().padLeft(2, '0');
    _displayTime = "$m:$s";
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
        const Text('UNLOADING IN PROGRESS', style: TextStyle(color: kGold, fontWeight: FontWeight.bold, fontSize: 12)),
        const SizedBox(height: 8),
        Text(_displayTime, style: TextStyle(color: context.textColor, fontSize: 48, fontWeight: FontWeight.bold, letterSpacing: 2)),
      ],
    );
  }
}
