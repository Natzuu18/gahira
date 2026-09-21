import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../application/services/service_request_service.dart';
import '../../domain/entities/service_request_entity.dart';
import '../../infrastructure/repositories/supabase_service_request_repository.dart';
import '../../infrastructure/repositories/supabase_user_repository.dart';
import '../../domain/entities/user_entity.dart';
import '../shared_widgets/appColor.dart';
import '../shared_widgets/themeToggleButton.dart';
import 'operator_drawer.dart';
import 'sacking_page.dart';

enum WorkflowFilter { all, queued, scheduledToday }

class ProcessingWorkflowPage extends StatefulWidget {
  const ProcessingWorkflowPage({super.key});

  @override
  State<ProcessingWorkflowPage> createState() => _ProcessingWorkflowPageState();
}

class _ProcessingWorkflowPageState extends State<ProcessingWorkflowPage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final SupabaseServiceRequestRepository _repository =
      SupabaseServiceRequestRepository();
  final SupabaseUserRepository _userRepository = SupabaseUserRepository();
  late final ServiceRequestService _service;

  List<ServiceRequestEntity> _requests = [];
  List<UserEntity> _allUsers = [];
  bool _isLoading = true;
  WorkflowFilter _currentFilter = WorkflowFilter.all;

  @override
  void initState() {
    super.initState();
    _service = ServiceRequestService(_repository);
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    
    try {
      final result = await _repository.getServiceRequests();
      final usersResult = await _userRepository.getAllUsers();
      
      if (!mounted) return;
      
      String? errorMessage;
      result.fold(
        (l) => errorMessage = 'Workflow: ${l.message}',
        (list) => _requests = list,
      );
      
      usersResult.fold(
        (l) => errorMessage = (errorMessage ?? '') + ' Users: ${l.message}',
        (list) => _allUsers = list,
      );

      if (errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $errorMessage'),
            backgroundColor: Colors.red,
          ),
        );
      }

      setState(() => _isLoading = false);
    } catch (e) {
      print('Critical Workflow Load Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Workflow Error: $e'), backgroundColor: Colors.red),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  String _getMinerName(ServiceRequestEntity request) {
    if (request.creatorName != null && request.creatorName!.isNotEmpty) {
      return request.creatorName!;
    }
    
    UserEntity? user;
    for (final u in _allUsers) {
      if (u.userId == request.creatorId) {
        user = u;
        break;
      }
    }
    return user != null ? '${user.fname} ${user.lname}' : 'Unknown Miner';
  }

  @override
  Widget build(BuildContext context) {
    // 1. Available Jobs: Requests that are 'queued' or 'scheduled'
    final allAvailable = _requests.where((r) {
      return r.status == ServiceRequestStatus.queued || 
             r.status == ServiceRequestStatus.scheduled;
    }).toList();

    final availableJobs = allAvailable.where((r) {
      switch (_currentFilter) {
        case WorkflowFilter.queued:
          return r.status == ServiceRequestStatus.queued;
        case WorkflowFilter.scheduledToday:
          if (r.status != ServiceRequestStatus.scheduled) return false;
          if (r.processingDetails.scheduledDate == null) return false;
          final now = DateTime.now();
          final sched = r.processingDetails.scheduledDate!;
          return sched.year == now.year && sched.month == now.month && sched.day == now.day;
        case WorkflowFilter.all:
        default:
          return true;
      }
    }).toList();

    // 2. My Active Processing: Processing requests CLAIMED by ME
    final myActiveProcessing = _requests.where((r) => 
      r.status == ServiceRequestStatus.processing
      // Additional check: operator_id in ongoing_services matches ME (if we had that logic)
    ).toList();

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: context.bgColor,
      appBar: AppBar(
        backgroundColor: context.surfaceColor,
        elevation: 0,
        title: const Text('WORKFLOW',
            style: TextStyle(
                color: kGold,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
                fontSize: 18)),
        iconTheme: const IconThemeData(color: kGold),
        actions: [
          const ThemeToggleButton(),
          IconButton(
              icon: const Icon(Icons.menu_rounded, color: kGold),
              onPressed: () => _scaffoldKey.currentState?.openEndDrawer()),
        ],
      ),
      endDrawer: const OperatorDrawer(
          currentMenu: OperatorMenu.processing, operatorName: 'Operator'),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: kGold))
          : RefreshIndicator(
              onRefresh: _loadTasks,
              color: kGold,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  _buildSectionHeader('My Active Processing', Icons.play_circle_fill_rounded, Colors.green),
                  if (myActiveProcessing.isEmpty)
                    _buildEmptySection('You are not currently processing any jobs.')
                  else
                    ...myActiveProcessing.map((r) => _buildJobCard(r, true)),
                  const SizedBox(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildSectionHeader('Available to Process', Icons.assignment_returned_rounded, kGold),
                      Text('${availableJobs.length} total', style: TextStyle(color: context.mutedTextColor, fontSize: 12)),
                    ],
                  ),
                  _buildFilterChips(),
                  const SizedBox(height: 16),
                  if (availableJobs.isEmpty)
                    _buildEmptySection(_getEmptyMessage())
                  else
                    ...availableJobs.map((r) => _buildAvailableJobCard(r)),
                ],
              ),
            ),
    );
  }

  String _getEmptyMessage() {
    switch (_currentFilter) {
      case WorkflowFilter.queued: return 'No queued jobs available.';
      case WorkflowFilter.scheduledToday: return 'No jobs scheduled for today.';
      case WorkflowFilter.all: return 'No unclaimed jobs in the queue.';
    }
  }

  Widget _buildFilterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _filterChip(WorkflowFilter.all, 'All Requests'),
          const SizedBox(width: 8),
          _filterChip(WorkflowFilter.queued, 'Queued'),
          const SizedBox(width: 8),
          _filterChip(WorkflowFilter.scheduledToday, 'Scheduled Today'),
        ],
      ),
    );
  }

  Widget _filterChip(WorkflowFilter filter, String label) {
    final isSelected = _currentFilter == filter;
    return ChoiceChip(
      label: Text(label, style: TextStyle(
        color: isSelected ? kBlack : context.textColor,
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      )),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) setState(() => _currentFilter = filter);
      },
      selectedColor: kGold,
      backgroundColor: context.surfaceColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: isSelected ? kGold : kGold.withOpacity(0.3)),
      ),
      elevation: isSelected ? 2 : 0,
      pressElevation: 4,
    );
  }

  Widget _buildAvailableJobCard(ServiceRequestEntity request) {
     return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kGold.withOpacity(0.1)),
      ),
      child: InkWell(
        onTap: () => _showRequestDetails(request),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(request.materialDetails.sourceType ?? 'N/A',
                          style: TextStyle(color: context.textColor, fontWeight: FontWeight.bold, fontSize: 16)),
                      Text('ID: ${request.id.substring(0, 8).toUpperCase()}',
                          style: TextStyle(color: context.mutedTextColor, fontSize: 11)),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                    child: Text(request.status.toString().split('.').last.toUpperCase(), style: const TextStyle(color: Colors.orange, fontSize: 9, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const Divider(height: 24),
              _buildInfoRow(Icons.shopping_bag_outlined, 'Sacks', '${request.materialDetails.numberOfSacks ?? 0}'),
              if (request.status == ServiceRequestStatus.scheduled && request.processingDetails.scheduledDate != null)
                _buildInfoRow(Icons.event_available_rounded, 'Scheduled', 
                  '${request.processingDetails.scheduledDate!.day}/${request.processingDetails.scheduledDate!.month} ${request.processingDetails.scheduledDate!.hour.toString().padLeft(2, '0')}:${request.processingDetails.scheduledDate!.minute.toString().padLeft(2, '0')}'),
              _buildInfoRow(Icons.history_rounded, 'Created', '${request.createdAt.day}/${request.createdAt.month}'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => _handleClaim(request),
                style: ElevatedButton.styleFrom(
                    backgroundColor: kGold,
                    foregroundColor: kBlack,
                    minimumSize: const Size(double.infinity, 45),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                child: const Text('Claim & Start Processing', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleClaim(ServiceRequestEntity request) async {
    final currentOperatorId = Supabase.instance.client.auth.currentUser?.id;
    if (currentOperatorId == null) return;

    final result = await _service.claimAndStartService(
      requestId: request.id,
      operatorId: currentOperatorId,
      currentStatus: request.status.toString().split('.').last,
    );

    result.fold(
      (l) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.message))),
      (_) => _loadTasks(),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Text(title,
              style: TextStyle(
                  color: context.textColor,
                  fontSize: 16,
                  fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildEmptySection(String message) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32),
      alignment: Alignment.center,
      child: Text(message, style: TextStyle(color: context.mutedTextColor, fontSize: 13)),
    );
  }

  Widget _buildJobCard(ServiceRequestEntity request, bool isActive) {
    final stage = request.processingDetails.currentStage;
    final bool isSackingStage = stage == ProcessingStage.none || stage == ProcessingStage.rebagging || stage == ProcessingStage.millingCrushing;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kGold.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: InkWell(
        onTap: () => _showRequestDetails(request, isActive: isActive),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(request.materialDetails.sourceType ?? 'N/A',
                          style: TextStyle(color: context.textColor, fontWeight: FontWeight.bold, fontSize: 16)),
                      Text('ID: ${request.id.substring(0, 8).toUpperCase()}',
                          style: TextStyle(color: context.mutedTextColor, fontSize: 11, letterSpacing: 1)),
                    ],
                  ),
                  _buildStageBadge(stage),
                ],
              ),
              const Divider(height: 32),
              _buildInfoRow(Icons.shopping_bag_outlined, 'Initial Sacks', '${request.materialDetails.numberOfSacks ?? 0}'),
              if (request.processingDetails.sackedQuantity != null)
                _buildInfoRow(Icons.inventory_2_rounded, 'Processed Sacks', '${request.processingDetails.sackedQuantity}'),
              _buildInfoRow(Icons.timer_outlined, 'Est. Time', request.processingDetails.estimatedTime ?? 'N/A'),
              if (isActive && !isSackingStage) ...[
                const SizedBox(height: 16),
                _buildProgressIndicator(stage),
              ],
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  if (isSackingStage) {
                    _navigateToSacking(request);
                  } else {
                    _handleAction(request);
                  }
                },
                style: ElevatedButton.styleFrom(
                    backgroundColor: isActive ? kGold : kGold.withOpacity(0.1),
                    foregroundColor: isActive ? kBlack : kGold,
                    elevation: isActive ? 2 : 0,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                child: Text(
                  isSackingStage ? (request.processingDetails.currentStage == ProcessingStage.millingCrushing ? 'MANAGE BATCHES' : 'START SACKING') : _getActionLabel(request),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToSacking(ServiceRequestEntity request) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => SackingPage(request: request)),
    );
    if (result == true) {
      _loadTasks();
    }
  }

  String _getActionLabel(ServiceRequestEntity request) {
    if (request.status != ServiceRequestStatus.processing) {
      return 'Start Processing';
    }
    final nextStage = _getNextStage(request.processingDetails.currentStage);
    if (nextStage == ProcessingStage.completed) {
      return 'Complete Processing';
    }
    return 'Move to ${_getStageName(nextStage)}';
  }

  void _handleAction(ServiceRequestEntity request) async {
    final currentOperatorId = Supabase.instance.client.auth.currentUser?.id;
    if (currentOperatorId == null) return;

    if (request.status != ServiceRequestStatus.processing) {
      // Transition from Assigned -> Processing (Starts at Rebagging)
      final result = await _service.updateProcessingStatus(
        requestId: request.id,
        operatorId: currentOperatorId,
        newStatus: ServiceRequestStatus.processing,
        currentStatus: request.status.toString().split('.').last,
        newStage: ProcessingStage.rebagging,
      );
      result.fold(
        (l) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.message))),
        (_) => _loadTasks(),
      );
    } else {
      // Transition to next stage
      final nextStage = _getNextStage(request.processingDetails.currentStage);
      final newStatus = (nextStage == ProcessingStage.completed) 
          ? ServiceRequestStatus.processingCompleted 
          : ServiceRequestStatus.processing;

      final result = await _service.updateProcessingStatus(
        requestId: request.id,
        operatorId: currentOperatorId,
        newStatus: newStatus,
        currentStatus: request.status.toString().split('.').last,
        newStage: nextStage,
      );
      result.fold(
        (l) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.message))),
        (_) => _loadTasks(),
      );
    }
  }

  ProcessingStage _getNextStage(ProcessingStage current) {
    switch (current) {
      case ProcessingStage.none: return ProcessingStage.rebagging;
      case ProcessingStage.rebagging: return ProcessingStage.loading;
      case ProcessingStage.loading: return ProcessingStage.millingCrushing;
      case ProcessingStage.millingCrushing: return ProcessingStage.unloading;
      case ProcessingStage.unloading: return ProcessingStage.washingSeparation;
      case ProcessingStage.washingSeparation: return ProcessingStage.refining;
      case ProcessingStage.refining: return ProcessingStage.completed;
      default: return ProcessingStage.completed;
    }
  }

  String _getStageName(ProcessingStage stage) {
    switch (stage) {
      case ProcessingStage.rebagging: return 'Rebagging';
      case ProcessingStage.loading: return 'Loading';
      case ProcessingStage.millingCrushing: return 'Milling / Crushing';
      case ProcessingStage.unloading: return 'Unloading';
      case ProcessingStage.washingSeparation: return 'Washing / Separation';
      case ProcessingStage.refining: return 'Refining';
      case ProcessingStage.completed: return 'Completed';
      default: return 'Pending';
    }
  }

  Widget _buildStageBadge(ProcessingStage stage) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: kGold.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kGold.withOpacity(0.2)),
      ),
      child: Text(
        _getStageName(stage).toUpperCase(),
        style: const TextStyle(color: kGold, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5),
      ),
    );
  }

  Widget _buildProgressIndicator(ProcessingStage stage) {
    final stages = [
      ProcessingStage.rebagging,
      ProcessingStage.loading,
      ProcessingStage.millingCrushing,
      ProcessingStage.unloading,
      ProcessingStage.washingSeparation,
      ProcessingStage.refining,
    ];
    final currentIndex = stages.indexOf(stage);
    final progress = (currentIndex + 1) / stages.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Processing Progress', style: TextStyle(color: context.mutedTextColor, fontSize: 11)),
            Text('${(progress * 100).toInt()}%', style: const TextStyle(color: kGold, fontSize: 11, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: kGold.withOpacity(0.1),
            color: kGold,
            minHeight: 8,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: kGold.withOpacity(0.7)),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(color: context.mutedTextColor, fontSize: 13)),
          const Spacer(),
          Text(value, style: TextStyle(color: context.textColor, fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  void _showRequestDetails(ServiceRequestEntity request, {bool isActive = false}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.bgColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.8,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(color: context.mutedTextColor.withOpacity(0.3), borderRadius: BorderRadius.circular(2)),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Full Information', style: TextStyle(color: kGold, fontSize: 22, fontWeight: FontWeight.bold)),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                ],
              ),
              const SizedBox(height: 24),
              _buildDetailSection('MINER DETAILS', [
                _buildDetailRow('Primary Miner', _getMinerName(request)),
                if (request.participatingMinerIds.length > 1)
                  _buildDetailRow('Group Members', request.participatingMinerIds.where((id) => id != request.creatorId).map((id) {
                     // Since we don't have participants' names in the entity, 
                     // we still do a lookup in _allUsers for them.
                     UserEntity? user;
                     for(var u in _allUsers) { if(u.userId == id) { user = u; break; } }
                     return user != null ? '${user.fname} ${user.lname}' : 'Unknown Miner';
                  }).join(', ')),
              ]),
              const SizedBox(height: 24),
              _buildDetailSection('MATERIAL SUMMARY', [
                _buildDetailRow('Condition', request.materialDetails.condition ?? 'N/A'),
                _buildDetailRow('State', request.materialDetails.state ?? 'N/A'),
                _buildDetailRow('Sacks', '${request.materialDetails.numberOfSacks ?? 0}'),
                _buildDetailRow('Source Type', request.materialDetails.sourceType ?? 'N/A'),
                _buildDetailRow('Source Name', request.materialDetails.source ?? 'N/A'),
              ]),
              if (request.materialDetails.photoUrls.isNotEmpty) ...[
                const SizedBox(height: 24),
                const Text('MATERIAL PHOTOS', style: TextStyle(color: kGold, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                const SizedBox(height: 12),
                SizedBox(
                  height: 100,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: request.materialDetails.photoUrls.length,
                    itemBuilder: (context, index) => Container(
                      width: 100,
                      margin: const EdgeInsets.only(right: 12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: kGold.withOpacity(0.2)),
                        image: DecorationImage(image: NetworkImage(request.materialDetails.photoUrls[index]), fit: BoxFit.cover),
                      ),
                    ),
                  ),
                ),
              ],
              if (request.materialDetails.notes != null && request.materialDetails.notes!.isNotEmpty) ...[
                const SizedBox(height: 24),
                _buildDetailSection('MINER NOTES', [
                  Text(request.materialDetails.notes!, style: TextStyle(color: context.textColor, fontSize: 13, height: 1.5)),
                ]),
              ],
              const SizedBox(height: 32),
              if (isActive && request.status == ServiceRequestStatus.processing && 
                  (request.processingDetails.currentStage == ProcessingStage.none || 
                   request.processingDetails.currentStage == ProcessingStage.rebagging ||
                   request.processingDetails.currentStage == ProcessingStage.millingCrushing))
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _navigateToSacking(request);
                    },
                    icon: const Icon(Icons.shopping_bag_outlined, size: 20),
                    label: Text(request.processingDetails.currentStage == ProcessingStage.millingCrushing 
                      ? 'MANAGE BATCHES' 
                      : 'START SACKING / MILLING', 
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kGold,
                      foregroundColor: kBlack,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: TextStyle(color: kGold.withOpacity(0.7), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
        const SizedBox(height: 12),
        ...children,
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: context.mutedTextColor, fontSize: 13)),
          Text(value, style: TextStyle(color: context.textColor, fontWeight: FontWeight.bold, fontSize: 14)),
        ],
      ),
    );
  }
}
