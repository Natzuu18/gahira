import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../infrastructure/repositories/supabase_service_request_repository.dart';
import '../../domain/entities/service_request_entity.dart';
import '../shared_widgets/appColor.dart';
import '../shared_widgets/themeToggleButton.dart';
import '../shared_widgets/notification_bell_button.dart';
import '../shared_widgets/monitoring_page.dart';
import '../miner/miner_drawer.dart';

class ProcessingStatusPage extends StatefulWidget {
  const ProcessingStatusPage({super.key});

  @override
  State<ProcessingStatusPage> createState() => _ProcessingStatusPageState();
}

class _ProcessingStatusPageState extends State<ProcessingStatusPage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final _repository = SupabaseServiceRequestRepository();
  List<ServiceRequestEntity> _requests = [];
  bool _isLoading = true;
  bool _isRefreshing = false;
  bool _refreshQueued = false;
  RealtimeChannel? _realtimeChannel;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _subscribeToRealtime();
    _loadData();
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) _loadData(showLoading: false);
    });
  }

  void _subscribeToRealtime() {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    _realtimeChannel = Supabase.instance.client
        .channel('miner-processing-status-$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'service_requests',
          callback: (payload) {
            final record = payload.newRecord.isNotEmpty
                ? payload.newRecord
                : payload.oldRecord;
            final participants = record['participating_miners'];
            final isMine = record['user_id']?.toString() == userId ||
                (participants is List && participants.contains(userId));
            // Delete events may contain only the primary key. Refresh to
            // remove any completed service the miner can no longer review.
            if (isMine || !record.containsKey('user_id')) {
              _loadData(showLoading: false);
            }
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'milling_batches',
          callback: (payload) {
            final record = payload.newRecord.isNotEmpty
                ? payload.newRecord
                : payload.oldRecord;
            final requestId = record['service_request_id']?.toString();
            if (requestId != null &&
                _requests.any((request) => request.id == requestId)) {
              _loadData(showLoading: false);
            }
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'ongoing_services',
          callback: (payload) {
            final record = payload.newRecord.isNotEmpty
                ? payload.newRecord
                : payload.oldRecord;
            final requestId = record['service_request_id']?.toString();
            if (requestId != null &&
                _requests.any((request) => request.id == requestId)) {
              _loadData(showLoading: false);
            }
          },
        )
        .subscribe();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    final channel = _realtimeChannel;
    if (channel != null) {
      unawaited(Supabase.instance.client.removeChannel(channel));
    }
    super.dispose();
  }

  Future<void> _loadData({bool showLoading = true}) async {
    if (_isRefreshing) {
      _refreshQueued = true;
      return;
    }
    _isRefreshing = true;
    if (showLoading && mounted) setState(() => _isLoading = true);

    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      final result = await _repository.getServiceRequests();
      if (mounted) {
        setState(() {
          _requests = result.getOrElse(() => []).where((request) {
            final belongsToMiner = request.creatorId == userId ||
                request.participatingMinerIds.contains(userId);
            final isProcessStatus = {
              ServiceRequestStatus.processing,
              ServiceRequestStatus.emergencyStop,
              ServiceRequestStatus.processingCompleted,
              ServiceRequestStatus.goldHandoff,
              ServiceRequestStatus.completed,
            }.contains(request.status);
            return userId != null && belongsToMiner && isProcessStatus;
          }).toList()
            ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: context.bgColor,
      appBar: AppBar(
        backgroundColor: context.surfaceColor,
        elevation: 0,
        title: const Text('PROCESSING TRACKER', style: TextStyle(color: kGold, fontWeight: FontWeight.bold, letterSpacing: 2, fontSize: 16)),
        iconTheme: const IconThemeData(color: kGold),
        actions: const [
          NotificationBellButton(),
          ThemeToggleButton(),
          SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: kGold))
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  _buildSectionTitle('ACTIVE PROCESSING'),
                  if (_requests.where((r) => r.status != ServiceRequestStatus.completed).isEmpty)
                    _buildEmptyState('No active processing jobs.')
                  else
                    ..._requests.where((r) => r.status != ServiceRequestStatus.completed).map((r) => _buildMonitorCard(r)),
                  
                  const SizedBox(height: 32),
                  _buildSectionTitle('COMPLETED HISTORY'),
                  if (_requests.where((r) => r.status == ServiceRequestStatus.completed).isEmpty)
                    _buildEmptyState('Completed services will appear here for review.')
                  else
                    ..._requests.where((r) => r.status == ServiceRequestStatus.completed).map((r) => _buildMonitorCard(r)),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16, left: 4),
      child: Text(title, style: TextStyle(color: context.mutedTextColor, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
    );
  }

  Widget _buildEmptyState(String msg) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(color: context.surfaceColor, borderRadius: BorderRadius.circular(16)),
      child: Center(child: Text(msg, style: TextStyle(color: context.mutedTextColor, fontSize: 13))),
    );
  }

  Widget _buildMonitorCard(ServiceRequestEntity request) {
    final bool isDone = request.status == ServiceRequestStatus.completed;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kGold.withOpacity(0.1)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: (isDone ? Colors.green : kGold).withOpacity(0.1), shape: BoxShape.circle),
          child: Icon(isDone ? Icons.check_circle : Icons.sync, color: isDone ? Colors.green : kGold),
        ),
        title: Text(request.materialDetails.sourceType ?? 'Service Request', style: TextStyle(color: context.textColor, fontWeight: FontWeight.bold)),
        subtitle: Text('${request.serviceReference} • ${request.status.name}', style: const TextStyle(fontSize: 12)),
        trailing: TextButton.icon(
          onPressed: () => _openProcess(request, isDone),
          icon: Icon(isDone ? Icons.history_rounded : Icons.visibility_outlined),
          label: Text(isDone ? 'Review' : 'View'),
        ),
        onTap: () => _openProcess(request, isDone),
      ),
    );
  }

  void _openProcess(ServiceRequestEntity request, bool isDone) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MonitoringPage(
          request: request,
          title: isDone ? 'PROCESS REVIEW' : 'LIVE PROCESS MONITORING',
        ),
      ),
    );
  }
}
