import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:gahira/main.dart';
import '../../../domain/entities/service_request_entity.dart';
import '../../../infrastructure/repositories/supabase_service_request_repository.dart';
import '../shared_widgets/appColor.dart';
import '../shared_widgets/adminDrawer.dart';

class EmergencyMonitorPage extends StatefulWidget {
  const EmergencyMonitorPage({super.key});

  @override
  State<EmergencyMonitorPage> createState() => _EmergencyMonitorPageState();
}

class _EmergencyMonitorPageState extends State<EmergencyMonitorPage> {
  final _repository = SupabaseServiceRequestRepository();
  List<ServiceRequestEntity> _emergencies = [];
  bool _isLoading = true;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadEmergencies();
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) => _loadEmergencies(showLoading: false));
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadEmergencies({bool showLoading = true}) async {
    if (showLoading) setState(() => _isLoading = true);
    
    final result = await _repository.getServiceRequests();
    result.fold(
      (l) => null,
      (list) {
        final filtered = list.where((r) => r.status == ServiceRequestStatus.emergencyStop).toList();
        // Sort by most recent stopped at
        filtered.sort((a, b) => (b.emergencyStoppedAt ?? DateTime.now()).compareTo(a.emergencyStoppedAt ?? DateTime.now()));
        
        if (mounted) {
          setState(() {
            _emergencies = filtered;
            _isLoading = false;
          });
        }
      }
    );
  }

  Future<void> _handleResolve(ServiceRequestEntity request) async {
    final adminId = Supabase.instance.client.auth.currentUser?.id;
    if (adminId == null) return;

    final result = await _repository.resolveEmergencyStop(
      requestId: request.id,
      adminId: adminId,
    );

    result.fold(
      (l) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.message), backgroundColor: Colors.red)),
      (_) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Emergency resolved. Drum/Machine status reset.')));
        _loadEmergencies();
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bgColor,
      appBar: AppBar(
        backgroundColor: context.surfaceColor,
        elevation: 0,
        title: Text('EMERGENCY MONITOR', style: TextStyle(color: kGold, fontWeight: FontWeight.bold, letterSpacing: 1.5, fontSize: 16)),
        iconTheme: IconThemeData(color: kGold),
      ),
      endDrawer: AdminDrawer(currentMenu: AdminMenu.emergencyMonitor), // Using dedicated menu item
      body: _isLoading 
        ? Center(child: CircularProgressIndicator(color: kGold))
        : RefreshIndicator(
            onRefresh: _loadTasks,
            color: kGold,
            child: _emergencies.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _emergencies.length,
                  itemBuilder: (context, index) => _buildEmergencyCard(_emergencies[index]),
                ),
          ),
    );
  }

  // Helper for RefreshIndicator since refresh requires Future<void>
  Future<void> _loadTasks() async {
    await _loadEmergencies();
  }

  Widget _buildEmergencyCard(ServiceRequestEntity sr) {
    final isResolved = sr.emergencyResolvedAt != null;
    final timeStr = sr.emergencyStoppedAt != null 
        ? DateFormat('MMM dd, hh:mm a').format(sr.emergencyStoppedAt!.toLocal()) 
        : 'Unknown Time';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isResolved ? Colors.orange.withOpacity(0.3) : Colors.red.withOpacity(0.3)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isResolved ? Colors.orange.withOpacity(0.1) : Colors.red.withOpacity(0.1),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Icon(isResolved ? Icons.check_circle_outline : Icons.warning_amber_rounded, color: isResolved ? Colors.orange : Colors.red, size: 20),
                const SizedBox(width: 12),
                Text(isResolved ? 'ISSUE RESOLVED' : 'ACTIVE EMERGENCY', 
                  style: TextStyle(color: isResolved ? Colors.orange : Colors.red, fontWeight: FontWeight.bold, fontSize: 12)),
                const Spacer(),
                Text(timeStr, style: TextStyle(color: context.mutedTextColor, fontSize: 11)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Service Ref: ${sr.id.substring(0, 8).toUpperCase()}', style: TextStyle(color: context.textColor, fontWeight: FontWeight.bold)),
                    Text(sr.creatorName ?? 'Miner', style: TextStyle(color: kGold, fontSize: 13, fontWeight: FontWeight.w500)),
                  ],
                ),
                const SizedBox(height: 16),
                const Text('CAUSE OF STOP:', style: TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
                const SizedBox(height: 4),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: context.bgColor, borderRadius: BorderRadius.circular(8)),
                  child: Text(sr.emergencyReason ?? 'No reason provided.', 
                    style: TextStyle(color: context.textColor, fontSize: 13, height: 1.5)),
                ),
                const SizedBox(height: 20),
                if (!isResolved)
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: () => _handleResolve(sr),
                      icon: const Icon(Icons.verified_user_outlined, size: 18),
                      label: const Text('RESOLVE ISSUE & RESET EQUIPMENT', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  )
                else
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(color: Colors.orange.withOpacity(0.05), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.orange.withOpacity(0.2))),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.hourglass_empty_rounded, color: Colors.orange, size: 16),
                        SizedBox(width: 8),
                        Text('Waiting for operator to resume...', style: TextStyle(color: Colors.orange, fontSize: 12, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.health_and_safety_outlined, color: Colors.green.withOpacity(0.2), size: 80),
          const SizedBox(height: 24),
          Text('All Systems Clear', style: TextStyle(color: context.textColor, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('No active emergency stops detected.', style: TextStyle(color: context.mutedTextColor, fontSize: 14)),
        ],
      ),
    );
  }
}
