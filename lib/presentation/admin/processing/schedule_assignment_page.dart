import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:dartz/dartz.dart' hide State;
import '../../../core/error/failures.dart';
import '../../../domain/entities/service_request_entity.dart';
import '../../../domain/entities/user_entity.dart';
import '../../../infrastructure/models/service_request_model.dart';
import '../../../infrastructure/repositories/supabase_processing_repository.dart';
import '../../../infrastructure/repositories/supabase_service_request_repository.dart';
import '../../../infrastructure/repositories/supabase_equipment_repository.dart';
import '../../../infrastructure/repositories/supabase_user_repository.dart';
import '../../../infrastructure/supabase/supabase_config.dart';
import '../../shared_widgets/appColor.dart';
import '../../shared_widgets/adminDrawer.dart';
import '../../shared_widgets/themeToggleButton.dart';

class ScheduleAssignmentPage extends StatefulWidget {
  const ScheduleAssignmentPage({super.key});

  @override
  State<ScheduleAssignmentPage> createState() => _ScheduleAssignmentPageState();
}

class _ScheduleAssignmentPageState extends State<ScheduleAssignmentPage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final _processingRepo = SupabaseProcessingRepository();
  final _requestRepo = SupabaseServiceRequestRepository();
  final _equipRepo = SupabaseEquipmentRepository();
  final _userRepo = SupabaseUserRepository();

  List<ServiceRequestModel> _approvedRequests = [];
  List<UserEntity> _allUsers = [];
  bool _isLoading = true;
  String _currentFilter = 'To Schedule'; // Options: 'To Schedule', 'Queue', 'Scheduled'

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    final requestsRes = await _requestRepo.getServiceRequests();
    final usersRes = await _userRepo.getAllUsers();

    requestsRes.fold((f) => null, (list) {
      _approvedRequests = list.where((r) => 
        r.status != ServiceRequestStatus.pendingOperatorVerification && 
        r.status != ServiceRequestStatus.draft &&
        r.status != ServiceRequestStatus.cancelled &&
        r.status != ServiceRequestStatus.returnedToMiner
      ).toList();
    });

    usersRes.fold((f) => null, (list) => _allUsers = list);

    setState(() => _isLoading = false);
  }

  String _getUserName(String id) {
    UserEntity? user;
    for (final u in _allUsers) {
      if (u.userId == id) {
        user = u;
        break;
      }
    }
    return user != null ? '${user.fname} ${user.lname}' : 'Unknown';
  }

  void _showAddDialogForRequest(ServiceRequestModel request) {
    DateTime selectedDate = DateTime.now();
    TimeOfDay selectedTime = TimeOfDay.now();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: context.surfaceColor,
          title: Text('Ref: ${request.id.substring(0, 8)}', style: const TextStyle(color: kGold, fontSize: 16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Set a specific time for processing or move directly to the general queue.', 
                style: TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 20),
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text('Date: ${DateFormat('yyyy-MM-dd').format(selectedDate)}', 
                  style: TextStyle(color: context.textColor, fontSize: 14)),
                trailing: const Icon(Icons.calendar_today, color: kGold, size: 18),
                onTap: () async {
                  final d = await showDatePicker(context: context, initialDate: selectedDate, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 90)));
                  if (d != null) setDialogState(() => selectedDate = d);
                },
              ),
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text('Time: ${selectedTime.format(context)}', 
                  style: TextStyle(color: context.textColor, fontSize: 14)),
                trailing: const Icon(Icons.access_time_rounded, color: kGold, size: 18),
                onTap: () async {
                  final t = await showTimePicker(context: context, initialTime: selectedTime);
                  if (t != null) setDialogState(() => selectedTime = t);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () async {
                final currentUserId = SupabaseConfig.client.auth.currentUser?.id;
                if (currentUserId == null) return;

                // ADD TO QUEUE Logic
                await _requestRepo.updateRequestStatus(
                  requestId: request.id,
                  status: ServiceRequestStatus.queued.name,
                  userId: currentUserId,
                );

                Navigator.pop(context);
                _loadData();
              },
              child: const Text('Add to Queue', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: kGold),
              onPressed: () async {
                final currentUserId = SupabaseConfig.client.auth.currentUser?.id;
                if (currentUserId == null) return;

                // EXACT SCHEDULE Logic
                final scheduledDateTime = DateTime(
                  selectedDate.year,
                  selectedDate.month,
                  selectedDate.day,
                  selectedTime.hour,
                  selectedTime.minute,
                );

                await _requestRepo.updateRequestStatus(
                  requestId: request.id,
                  status: ServiceRequestStatus.scheduled.name,
                  userId: currentUserId,
                  additionalData: {
                    'approved_at': scheduledDateTime.toIso8601String(),
                  }
                );

                Navigator.pop(context);
                _loadData();
              },
              child: const Text('Exact Schedule', style: TextStyle(color: kBlack, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  List<ServiceRequestModel> get _filteredRequests {
    switch (_currentFilter) {
      case 'Queue':
        return _approvedRequests.where((r) => r.status == ServiceRequestStatus.queued).toList();
      case 'Scheduled':
        return _approvedRequests.where((r) => r.status == ServiceRequestStatus.scheduled).toList();
      case 'To Schedule':
      default:
        return _approvedRequests.where((r) => r.status == ServiceRequestStatus.verified || r.status == ServiceRequestStatus.accepted).toList();
    }
  }

  Widget _buildFilterBar() {
    final filters = ['To Schedule', 'Queue', 'Scheduled'];
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      color: context.surfaceColor,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: filters.map((f) {
          final isSelected = _currentFilter == f;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: ChoiceChip(
                label: Center(
                  child: Text(
                    f.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? kBlack : context.textColor.withOpacity(0.6),
                    ),
                  ),
                ),
                selected: isSelected,
                onSelected: (val) => setState(() => _currentFilter = f),
                selectedColor: kGold,
                backgroundColor: context.bgColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                showCheckmark: false,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: context.bgColor,
      appBar: AppBar(
        backgroundColor: context.surfaceColor,
        title: const Text('SCHEDULE & ASSIGNMENT', style: TextStyle(color: kGold, fontWeight: FontWeight.bold, letterSpacing: 1.5, fontSize: 14)),
        actions: [
          const ThemeToggleButton(),
          IconButton(icon: const Icon(Icons.menu_rounded, color: kGold), onPressed: () => _scaffoldKey.currentState?.openEndDrawer()),
        ],
      ),
      endDrawer: const AdminDrawer(currentMenu: AdminMenu.scheduleAssignment),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: kGold))
          : Column(
              children: [
                _buildFilterBar(),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _filteredRequests.length,
                    itemBuilder: (context, index) {
                      final r = _filteredRequests[index];
                      return Card(
                        color: context.surfaceColor,
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: kGold.withOpacity(0.1)),
                        ),
                        child: ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: kGold.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.inventory_2_outlined, color: kGold, size: 20),
                          ),
                          title: Text(
                            'Sacks: ${r.materialDetails.numberOfSacks ?? 0}',
                            style: TextStyle(color: context.textColor, fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Requester: ${_getUserName(r.creatorId)}',
                                style: TextStyle(color: context.textColor, fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                              Text(
                                'Requested: ${DateFormat('MMM dd, yyyy • hh:mm a').format(r.createdAt)}',
                                style: TextStyle(color: context.mutedTextColor, fontSize: 11),
                              ),
                              if (r.status == ServiceRequestStatus.scheduled && r.approvedAt != null)
                                Text(
                                  'Scheduled for: ${DateFormat('MMM dd • hh:mm a').format(r.approvedAt!)}',
                                  style: const TextStyle(color: kGold, fontSize: 11, fontWeight: FontWeight.bold),
                                )
                              else if (r.status == ServiceRequestStatus.queued)
                                const Text(
                                  'In General Queue',
                                  style: TextStyle(color: Colors.orange, fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                            ],
                          ),
                          trailing: r.status == ServiceRequestStatus.verified || r.status == ServiceRequestStatus.accepted
                              ? IconButton(
                                  icon: const Icon(Icons.calendar_month_outlined, color: kGold),
                                  onPressed: () => _showAddDialogForRequest(r),
                                )
                              : Icon(Icons.check_circle_outline_rounded, color: Colors.green.withOpacity(0.5)),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }

Color _getStatusColor(ServiceRequestStatus status) {
  switch (status) {
    case ServiceRequestStatus.verified: return Colors.green;
    case ServiceRequestStatus.queued: return Colors.orange;
    case ServiceRequestStatus.scheduled: return kGold;
    case ServiceRequestStatus.processing: return Colors.blue;
    default: return Colors.grey;
  }
}
}
