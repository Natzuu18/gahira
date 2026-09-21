import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../infrastructure/repositories/supabase_user_repository.dart';
import '../../infrastructure/repositories/supabase_service_request_repository.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/entities/service_request_entity.dart';
import '../shared_widgets/appColor.dart';
import '../shared_widgets/themeToggleButton.dart';
import 'operator_drawer.dart';

class WorkforceShiftPage extends StatefulWidget {
  const WorkforceShiftPage({super.key});

  @override
  State<WorkforceShiftPage> createState() => _WorkforceShiftPageState();
}

class _WorkforceShiftPageState extends State<WorkforceShiftPage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final SupabaseUserRepository _userRepository = SupabaseUserRepository();
  final SupabaseServiceRequestRepository _requestRepository = SupabaseServiceRequestRepository();

  List<UserEntity> _operators = [];
  List<ServiceRequestEntity> _activeRequests = [];
  bool _isLoading = true;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _currentUserId = Supabase.instance.client.auth.currentUser?.id;
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    final operatorsRes = await _userRepository.getOperators();
    final requestsRes = await _requestRepository.getServiceRequests();

    setState(() {
      _operators = operatorsRes.fold((l) => [], (r) => r);
      _activeRequests = requestsRes.fold(
        (l) => [], 
        (r) => r.where((req) => req.status == ServiceRequestStatus.processing).toList()
      );
      _isLoading = false;
    });
  }

  // Find what an operator is working on
  String _getAssignedTask(String userId) {
    // For now, check if the operator is the "assisted_by" or if we had a proper assignment link
    // Based on claimAndStartService, the operator is recorded in ongoing_services
    // Since ongoing_services isn't fully mapped to the entity list yet, 
    // we'll check isOperatorAssisted or simulated assignment for now.
    
    final task = _activeRequests.firstWhere(
      (r) => r.assistedByOperatorId == userId, 
      orElse: () => ServiceRequestEntity(
        id: '', 
        creatorId: '', 
        participatingMinerIds: const [], 
        materialDetails: const MaterialDetails(),
        processingDetails: const ProcessingDetails(requirements: '', assignedOperatorIds: []), 
        status: ServiceRequestStatus.draft, 
        createdAt: DateTime.now(), 
        updatedAt: DateTime.now(),
      )
    );
    
    return task.id.isNotEmpty ? 'Ref: ${task.id.substring(0, 8).toUpperCase()}' : 'None';
  }

  Future<void> _toggleDutyStatus(UserEntity operator) async {
    final newStatus = operator.status == 'active' ? 'approved' : 'active';
    setState(() => _isLoading = true);
    
    final res = await _userRepository.updateUserStatus(operator.userId, newStatus);
    res.fold(
      (l) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.message))),
      (_) => _loadData(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: context.bgColor,
        appBar: AppBar(
          backgroundColor: context.surfaceColor,
          elevation: 0,
          leadingWidth: 64,
          leading: Padding(
            padding: const EdgeInsets.only(left: 16),
            child: _buildLogoMark(),
          ),
          title: const Text(
            'WORKFORCE',
            style: TextStyle(
              color: kGold,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
              fontSize: 16,
            ),
          ),
          iconTheme: const IconThemeData(color: kGold),
          actions: [
            const ThemeToggleButton(),
            IconButton(
              icon: const Icon(Icons.menu_rounded, color: kGold),
              onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
            ),
          ],
          bottom: TabBar(
            labelColor: kGold,
            unselectedLabelColor: context.mutedTextColor,
            indicatorColor: kGold,
            tabs: const [
              Tab(text: 'Team Status'),
              Tab(text: 'Active Tasks'),
            ],
          ),
        ),
        endDrawer: const OperatorDrawer(
          currentMenu: OperatorMenu.workforce,
          operatorName: 'Operator',
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: kGold))
            : TabBarView(
                children: [
                  _buildOperatorsTab(),
                  _buildActiveTasksTab(),
                ],
              ),
      ),
    );
  }

  Widget _buildOperatorsTab() {
    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: _operators.length,
        itemBuilder: (context, index) {
          final op = _operators[index];
          final isMe = op.userId == _currentUserId;
          final onDuty = op.status == 'active';
          
          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.surfaceColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isMe ? kGold : kGold.withOpacity(0.1)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: onDuty ? Colors.green.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                      child: Icon(Icons.person, color: onDuty ? Colors.green : Colors.grey),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${op.fname} ${op.lname}${isMe ? ' (You)' : ''}',
                            style: TextStyle(color: context.textColor, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            onDuty ? 'ON DUTY' : 'OFF DUTY',
                            style: TextStyle(color: onDuty ? Colors.green : Colors.grey, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    if (isMe)
                      Switch(
                        value: onDuty,
                        activeColor: kGold,
                        onChanged: (val) => _toggleDutyStatus(op),
                      ),
                  ],
                ),
                const Divider(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildMiniInfo('Assigned Task', _getAssignedTask(op.userId)),
                    _buildMiniInfo('Contact', op.email.split('@')[0]),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildActiveTasksTab() {
    if (_activeRequests.isEmpty) {
      return const Center(child: Text('No active processing tasks.'));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _activeRequests.length,
      itemBuilder: (context, index) {
        final req = _activeRequests[index];
        return Card(
          color: context.surfaceColor,
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            title: Text(req.materialDetails.sourceType ?? 'Processing', style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('Stage: ${req.processingDetails.currentStage.name.toUpperCase()}'),
            trailing: Text(req.id.substring(0, 8).toUpperCase(), style: const TextStyle(color: kGold, fontSize: 12)),
          ),
        );
      },
    );
  }

  Widget _buildMiniInfo(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: context.mutedTextColor, fontSize: 10)),
        Text(value, style: TextStyle(color: context.textColor, fontSize: 12, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildLogoMark() {
    return Container(
      width: 34, height: 34,
      decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: kGold, width: 1.6), color: context.bgColor),
      child: const Icon(Icons.settings_input_component_rounded, color: kGold, size: 16),
    );
  }
}
