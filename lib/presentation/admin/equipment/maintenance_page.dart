import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../infrastructure/repositories/supabase_equipment_repository.dart';
import '../../shared_widgets/appColor.dart';
import '../../shared_widgets/themeToggleButton.dart';

class MaintenancePage extends StatefulWidget {
  const MaintenancePage({super.key});

  @override
  State<MaintenancePage> createState() => _MaintenancePageState();
}

class _MaintenancePageState extends State<MaintenancePage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final _repository = SupabaseEquipmentRepository();
  List<Map<String, dynamic>> _schedules = [];
  bool _isLoading = true;
  String _selectedFilter = 'All'; // 'All', 'Pending Review', 'In Progress', 'Completed', 'Cancelled'

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    final schedulesRes = await _repository.getMaintenanceSchedules();

    schedulesRes.fold(
      (failure) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(failure.message)));
        }
        setState(() => _isLoading = false);
      },
      (list) => setState(() {
        _schedules = list;
        _isLoading = false;
      }),
    );
  }

  List<Map<String, dynamic>> get _filteredSchedules {
    if (_selectedFilter == 'All') return _schedules;
    return _schedules.where((s) {
      final st = (s['status'] ?? '').toString().toLowerCase();
      if (_selectedFilter == 'Pending Review') {
        return st == 'scheduled' || st == 'pending';
      } else if (_selectedFilter == 'In Progress') {
        return st == 'in progress' || st == 'ongoing';
      } else if (_selectedFilter == 'Completed') {
        return st == 'completed';
      } else if (_selectedFilter == 'Cancelled') {
        return st == 'cancelled' || st == 'rejected';
      }
      return true;
    }).toList();
  }

  Future<void> _updateStatus(Map<String, dynamic> item, String newStatus) async {
    final String maintId = item['maintenance_id'].toString();
    final String? machineId = item['machine_id']?.toString();
    final String? drumId = item['drum_id']?.toString();

    await _repository.updateMaintenanceStatus(maintId, newStatus);

    // Synchronize machine/drum availability status
    final lowerStatus = newStatus.toLowerCase();
    if (lowerStatus == 'completed' || lowerStatus == 'cancelled' || lowerStatus == 'rejected') {
      if (machineId != null && machineId.isNotEmpty) {
        await _repository.updateMachine(machineId, {'status': 'available'});
      }
      if (drumId != null && drumId.isNotEmpty) {
        await _repository.updateDrum(drumId, {'status': 'available'});
      }
    } else if (lowerStatus == 'in progress' || lowerStatus == 'ongoing' || lowerStatus == 'scheduled') {
      final desc = item['description']?.toString() ?? 'Under maintenance';
      if (machineId != null && machineId.isNotEmpty) {
        await _repository.updateMachine(machineId, {'status': 'maintenance', 'description': desc});
      }
      if (drumId != null && drumId.isNotEmpty) {
        await _repository.updateDrum(drumId, {'status': 'maintenance', 'description': desc});
      }
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Maintenance status updated to $newStatus'), backgroundColor: Colors.green),
      );
    }
    _fetchData();
  }

  Color _getStatusColor(String status) {
    final st = status.toLowerCase();
    if (st == 'scheduled' || st == 'pending') return Colors.blue;
    if (st == 'in progress' || st == 'ongoing') return Colors.orange;
    if (st == 'completed') return Colors.green;
    if (st == 'cancelled' || st == 'rejected') return Colors.redAccent;
    return kGold;
  }

  String _formatStatusLabel(String status) {
    final st = status.toLowerCase();
    if (st == 'scheduled' || st == 'pending') return 'PENDING REVIEW';
    if (st == 'in progress' || st == 'ongoing') return 'IN PROGRESS';
    if (st == 'completed') return 'COMPLETED';
    if (st == 'cancelled' || st == 'rejected') return 'CANCELLED / REJECTED';
    return status.toUpperCase();
  }

  Widget _buildLogoMark() {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: kGold, width: 1.6),
        color: context.bgColor,
      ),
      child: const Icon(
        Icons.settings_input_component_rounded,
        color: kGold,
        size: 16,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredList = _filteredSchedules;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: context.bgColor,
      appBar: AppBar(
        backgroundColor: context.surfaceColor,
        leadingWidth: 64,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16),
          child: _buildLogoMark(),
        ),
        title: const Text(
          'MAINTENANCE REVIEWS',
          style: TextStyle(
            color: kGold,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
            fontSize: 16,
          ),
        ),
        actions: const [
          ThemeToggleButton(),
          SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: kGold))
          : Column(
              children: [
                // Filter Header Chips
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  color: context.surfaceColor,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: ['All', 'Pending Review', 'In Progress', 'Completed', 'Cancelled'].map((filter) {
                        final isSelected = _selectedFilter == filter;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: ChoiceChip(
                            label: Text(filter),
                            selected: isSelected,
                            selectedColor: kGold.withOpacity(0.2),
                            labelStyle: TextStyle(
                              color: isSelected ? kGold : context.textColor,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              fontSize: 12,
                            ),
                            onSelected: (selected) {
                              if (selected) {
                                setState(() => _selectedFilter = filter);
                              }
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                const Divider(height: 1),

                // List Content
                Expanded(
                  child: filteredList.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.build_circle_outlined, color: context.mutedTextColor, size: 48),
                              const SizedBox(height: 12),
                              Text(
                                'No operator maintenance requests found.',
                                style: TextStyle(color: context.textColor, fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Requests submitted by operators will appear here for review.',
                                style: TextStyle(color: context.mutedTextColor, fontSize: 12),
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _fetchData,
                          color: kGold,
                          child: ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: filteredList.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final item = filteredList[index];
                              return _buildReviewCard(item);
                            },
                          ),
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildReviewCard(Map<String, dynamic> item) {
    final status = (item['status'] ?? 'Scheduled').toString();
    final statusColor = _getStatusColor(status);
    final statusLabel = _formatStatusLabel(status);

    final machineName = item['machines']?['machine_name'] ?? 'N/A Machine';
    final drumName = item['drums']?['drum_name'] ?? 'All Drums';
    final maintType = item['maintenance_type'] ?? 'General Maintenance';
    final maintDate = item['maintenance_date'] ?? 'N/A Date';
    final description = item['description'] ?? 'No additional description provided.';
    final remarksValue = item['remarks']?.toString() ?? '';
    const evidencePrefix = 'Evidence photo: ';
    final evidenceUrl = remarksValue.startsWith(evidencePrefix)
        ? remarksValue.substring(evidencePrefix.length)
        : null;
    final remarks = evidenceUrl == null ? remarksValue : '';

    final lowerStatus = status.toLowerCase();
    final isPending = lowerStatus == 'scheduled' || lowerStatus == 'pending';
    final isInProgress = lowerStatus == 'in progress' || lowerStatus == 'ongoing';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.textColor.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.build_circle_rounded, color: statusColor, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      maintType,
                      style: TextStyle(
                        color: context.textColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Machine: $machineName • Drum: $drumName',
                      style: TextStyle(color: context.mutedTextColor, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: statusColor.withOpacity(0.4)),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),
          const Divider(),
          const SizedBox(height: 8),

          Row(
            children: [
              Icon(Icons.calendar_today_rounded, size: 14, color: kGold.withOpacity(0.8)),
              const SizedBox(width: 6),
              Text(
                'Requested Date: $maintDate',
                style: TextStyle(color: context.textColor, fontSize: 12, fontWeight: FontWeight.w500),
              ),
            ],
          ),

          if (description.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: context.bgColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: context.textColor.withOpacity(0.06)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Operator Description:',
                    style: TextStyle(color: kGold, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: TextStyle(color: context.textColor, fontSize: 12),
                  ),
                  if (remarks.isNotEmpty && remarks != description) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Remarks: $remarks',
                      style: TextStyle(color: context.mutedTextColor, fontSize: 11, fontStyle: FontStyle.italic),
                    ),
                  ],
                ],
              ),
            ),
          ],

          if (evidenceUrl != null && evidenceUrl.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Supporting Photo',
              style: TextStyle(
                color: kGold,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(
                evidenceUrl,
                height: 190,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  height: 70,
                  alignment: Alignment.center,
                  color: context.bgColor,
                  child: Text(
                    'Supporting photo could not be loaded.',
                    style: TextStyle(color: context.mutedTextColor),
                  ),
                ),
              ),
            ),
          ],

          const SizedBox(height: 16),

          // Admin Review Action Buttons
          Row(
            children: [
              if (isPending) ...[
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.play_arrow_rounded, size: 18),
                    label: const Text('Approve & Start', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    onPressed: () => _updateStatus(item, 'ongoing'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.redAccent),
                      foregroundColor: Colors.redAccent,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.close_rounded, size: 18),
                    label: const Text('Reject', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    onPressed: () => _updateStatus(item, 'Cancelled'),
                  ),
                ),
              ] else if (isInProgress) ...[
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.check_circle_rounded, size: 18),
                    label: const Text('Mark Completed', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    onPressed: () => _updateStatus(item, 'Completed'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.redAccent),
                      foregroundColor: Colors.redAccent,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.cancel_outlined, size: 18),
                    label: const Text('Cancel Request', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    onPressed: () => _updateStatus(item, 'Cancelled'),
                  ),
                ),
              ] else ...[
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: context.bgColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Request $statusLabel',
                      style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
