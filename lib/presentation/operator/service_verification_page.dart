import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../shared_widgets/appColor.dart';
import '../shared_widgets/themeToggleButton.dart';
import '../shared_widgets/pin_dialog.dart';
import 'operator_drawer.dart';
import '../../infrastructure/repositories/supabase_service_request_repository.dart';
import '../../infrastructure/repositories/supabase_user_repository.dart';
import '../../application/services/service_request_service.dart';
import '../../domain/entities/service_request_entity.dart';
import '../../domain/entities/user_entity.dart';
import '../../infrastructure/supabase/supabase_config.dart';
import '../../infrastructure/models/user_model.dart';

class ServiceVerificationPage extends StatefulWidget {
  const ServiceVerificationPage({super.key});

  @override
  State<ServiceVerificationPage> createState() => _ServiceVerificationPageState();
}

class _ServiceVerificationPageState extends State<ServiceVerificationPage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final SupabaseServiceRequestRepository _repository = SupabaseServiceRequestRepository();
  late final ServiceRequestService _service;
  final SupabaseUserRepository _userRepository = SupabaseUserRepository();

  List<ServiceRequestEntity> _requests = [];
  List<UserEntity> _allUsers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _service = ServiceRequestService(_repository);
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    setState(() => _isLoading = true);
    final requestsResult = await _repository.getServiceRequests();
    final usersResult = await _userRepository.getAllUsers();
    
    setState(() {
      _requests = requestsResult.fold((l) => [], (list) => list);
      _allUsers = usersResult.fold((l) => [], (list) => list);
      _isLoading = false;
    });
  }

  String _getMinerName(String id) {
    UserEntity? user;
    for (final u in _allUsers) {
      if (u.userId == id) {
        user = u;
        break;
      }
    }
    return user != null ? '${user.fname} ${user.lname}' : 'Unknown Miner';
  }

  @override
  Widget build(BuildContext context) {
    final pendingRequests = _requests.where((r) => r.status == ServiceRequestStatus.pendingOperatorVerification).toList();
    final verifiedRequests = _requests.where((r) => r.status != ServiceRequestStatus.pendingOperatorVerification).toList();

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: context.bgColor,
      appBar: AppBar(
        backgroundColor: context.surfaceColor,
        title: const Text('SERVICE VERIFICATION', style: TextStyle(color: kGold, fontWeight: FontWeight.bold, letterSpacing: 2, fontSize: 16)),
        actions: [
          const ThemeToggleButton(),
          IconButton(icon: const Icon(Icons.menu_rounded, color: kGold), onPressed: () => _scaffoldKey.currentState?.openEndDrawer()),
        ],
      ),
      endDrawer: const OperatorDrawer(currentMenu: OperatorMenu.dashboard), // Assuming dashboard for now
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showMinerDirectory,
        backgroundColor: kGold,
        foregroundColor: kBlack,
        icon: const Icon(Icons.add_rounded),
        label: const Text('CREATE REQUEST', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: kGold))
        : RefreshIndicator(
            onRefresh: _loadRequests,
            color: kGold,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildSectionTitle('PENDING VERIFICATION'),
                if (pendingRequests.isEmpty)
                  _buildEmptyState('No pending verification tasks.')
                else
                  ...pendingRequests.map((r) => _buildRequestCard(r, isPending: true)),
                
                const SizedBox(height: 32),
                _buildSectionTitle('VERIFICATION HISTORY'),
                ...verifiedRequests.map((r) => _buildRequestCard(r, isPending: false)),
              ],
            ),
          ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16, left: 4),
      child: Text(title, style: TextStyle(color: context.mutedTextColor, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
    );
  }

  Widget _buildEmptyState(String msg) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(color: context.surfaceColor, borderRadius: BorderRadius.circular(16)),
      child: Center(child: Text(msg, style: TextStyle(color: context.mutedTextColor, fontSize: 13))),
    );
  }

  Widget _buildRequestCard(ServiceRequestEntity request, {required bool isPending}) {
    final bool isGroup = request.participatingMinerIds.length > 1;
    final String timeStr = DateFormat('hh:mm a').format(request.createdAt);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isPending ? kGold.withOpacity(0.2) : context.textColor.withOpacity(0.05)),
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
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isGroup ? Colors.blue.withOpacity(0.1) : kGold.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      isGroup ? 'GROUP' : 'INDIVIDUAL',
                      style: TextStyle(
                        color: isGroup ? Colors.blue : kGold,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  Text(timeStr, style: TextStyle(color: context.mutedTextColor, fontSize: 11)),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                request.creatorName ?? 'Unknown Miner',
                style: TextStyle(color: context.textColor, fontWeight: FontWeight.bold, fontSize: 15),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.inventory_2_outlined, size: 14, color: kGold.withOpacity(0.7)),
                  const SizedBox(width: 6),
                  Text(
                    '${request.materialDetails.numberOfSacks ?? 0} Sacks • ${request.materialDetails.condition} • ${request.materialDetails.state}',
                    style: TextStyle(color: context.mutedTextColor, fontSize: 12),
                  ),
                ],
              ),
              if (!isPending) ...[
                const SizedBox(height: 12),
                _buildStatusBadge(request.status),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(ServiceRequestStatus status) {
    Color color = kGold;
    String label = status.toString().split('.').last.toUpperCase();
    
    if (status == ServiceRequestStatus.verified || status == ServiceRequestStatus.accepted) {
      color = Colors.green;
      label = 'IN QUEUE';
    }
    if (status == ServiceRequestStatus.returnedToMiner) {
      color = Colors.redAccent;
      label = 'INACCURATE';
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: color.withOpacity(0.5))),
      child: Text(label, style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold)),
    );
  }

  void _showRequestDetails(ServiceRequestEntity request) {
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
                _buildDetailRow('Primary Miner', request.creatorName ?? 'Unknown Miner'),
                if (request.participatingMinerIds.length > 1)
                  _buildDetailRow('Group Members', request.participatingMinerIds.where((id) => id != request.creatorId).map((id) => _getMinerName(id)).join(', ')),
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
              if (request.status == ServiceRequestStatus.verified || 
                  request.status == ServiceRequestStatus.accepted || 
                  request.status == ServiceRequestStatus.scheduled ||
                  request.status == ServiceRequestStatus.assigned ||
                  request.status == ServiceRequestStatus.processing) ...[
                const SizedBox(height: 40),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.withOpacity(0.3)),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle_rounded, color: Colors.green, size: 24),
                      SizedBox(width: 12),
                      Text('VERIFIED', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1.5)),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: context.surfaceColor,
                      foregroundColor: kGold,
                      side: const BorderSide(color: kGold),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      // TODO: Navigate to processing/workflow view for this request
                    },
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('SEE PROGRESS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        SizedBox(width: 8),
                        Icon(Icons.insights_rounded, size: 20),
                      ],
                    ),
                  ),
                ),
              ],
              if (request.status == ServiceRequestStatus.pendingOperatorVerification) ...[
                const SizedBox(height: 40),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kGold,
                      foregroundColor: kBlack,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      _showVerificationForm(request);
                    },
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('NEXT: VERIFY MATERIAL', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        SizedBox(width: 8),
                        Icon(Icons.arrow_forward_rounded, size: 20),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showVerificationForm(ServiceRequestEntity request) {
    final weightController = TextEditingController();
    final sackController = TextEditingController(text: (request.materialDetails.numberOfSacks ?? 0).toString());
    final estNumController = TextEditingController(text: '3');
    final remarksController = TextEditingController();
    
    // Pre-fill editable fields
    String currentCondition = request.materialDetails.condition ?? 'Rocky';
    String currentState = request.materialDetails.state ?? 'Dry';
    String otherState = ''; // For "Others" option

    if (currentState != 'Dry' && currentState != 'Wet') {
      otherState = currentState;
      currentState = 'Others';
    }

    String currentSource = request.materialDetails.source ?? '';
    
    bool isAccurate = true;
    String timeUnit = 'Hours';

    final List<String> conditionOptions = ['Rocky', 'Muddy', 'Sandy', 'Mixed', 'Clay'];
    final List<String> stateOptions = ['Dry', 'Wet', 'Others'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.bgColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 24, left: 24, right: 24, top: 24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Material Verification', style: TextStyle(color: kGold, fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 24),
                
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: sackController,
                        keyboardType: TextInputType.number,
                        style: TextStyle(color: context.textColor),
                        decoration: InputDecoration(
                          labelText: 'Actual Sacks', 
                          filled: true,
                          fillColor: context.surfaceColor,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                const Text('Correct Material Condition', style: TextStyle(color: kGold, fontSize: 12, fontWeight: FontWeight.bold)),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: conditionOptions.map((c) => Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Radio<String>(
                          value: c,
                          groupValue: currentCondition,
                          activeColor: kGold,
                          onChanged: (v) => setModalState(() => currentCondition = v!),
                        ),
                        Text(c, style: TextStyle(color: context.textColor, fontSize: 12)),
                      ],
                    )).toList(),
                  ),
                ),

                const SizedBox(height: 12),
                const Text('Correct Material State', style: TextStyle(color: kGold, fontSize: 12, fontWeight: FontWeight.bold)),
                Row(
                  children: stateOptions.map((s) => Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Radio<String>(
                        value: s,
                        groupValue: currentState,
                        activeColor: kGold,
                        onChanged: (v) => setModalState(() => currentState = v!),
                      ),
                      Text(s, style: TextStyle(color: context.textColor, fontSize: 12)),
                    ],
                  )).toList(),
                ),
                if (currentState == 'Others')
                  Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 16),
                    child: TextFormField(
                      initialValue: otherState,
                      onChanged: (v) => otherState = v,
                      style: TextStyle(color: context.textColor, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Specify material state',
                        filled: true,
                        fillColor: context.surfaceColor,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),

                const SizedBox(height: 20),
                TextFormField(
                  initialValue: currentSource,
                  readOnly: true, // Not changeable
                  enabled: false,
                  style: TextStyle(color: context.textColor.withOpacity(0.6)),
                  decoration: InputDecoration(
                    labelText: 'Source Name (Verified)', 
                    filled: true,
                    fillColor: context.surfaceColor.withOpacity(0.5),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                
                const SizedBox(height: 24),
                const Text('Processing Estimate', style: TextStyle(color: kGold, fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    SizedBox(
                      width: 80,
                      child: TextFormField(
                        controller: estNumController,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: context.textColor, fontWeight: FontWeight.bold),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: context.surfaceColor,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: context.surfaceColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: context.mutedTextColor.withOpacity(0.3)),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: timeUnit,
                            dropdownColor: context.surfaceColor,
                            isExpanded: true,
                            style: TextStyle(color: context.textColor, fontWeight: FontWeight.bold),
                            items: ['Minutes', 'Hours', 'Days']
                              .map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                            onChanged: (v) => setModalState(() => timeUnit = v!),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                const Text('Final Verdict', style: TextStyle(color: kGold, fontSize: 12, fontWeight: FontWeight.bold)),
                Row(
                  children: [
                    Expanded(
                      child: RadioListTile<bool>(
                        title: const Text('Information Accurate', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        value: true,
                        groupValue: isAccurate,
                        activeColor: Colors.green,
                        contentPadding: EdgeInsets.zero,
                        onChanged: (v) => setModalState(() => isAccurate = v!),
                      ),
                    ),
                    Expanded(
                      child: RadioListTile<bool>(
                        title: const Text('Information Inaccurate', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        value: false,
                        groupValue: isAccurate,
                        activeColor: Colors.redAccent,
                        contentPadding: EdgeInsets.zero,
                        onChanged: (v) => setModalState(() => isAccurate = v!),
                      ),
                    ),
                  ],
                ),
                
                TextFormField(
                  controller: remarksController,
                  style: TextStyle(color: context.textColor),
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: isAccurate ? 'General Remarks' : 'Notes for Miner', 
                    hintText: isAccurate ? 'Optional' : 'Explain discrepancies',
                    filled: true,
                    fillColor: context.surfaceColor,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),

                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kGold, 
                      foregroundColor: kBlack,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => _confirmWithPin(request, {
                      'sacks': int.tryParse(sackController.text) ?? 0,
                      'condition': currentCondition,
                      'state': currentState == 'Others' ? otherState : currentState,
                      'source': currentSource,
                      'isAccurate': isAccurate,
                      'time': '${estNumController.text} $timeUnit',
                      'remarks': remarksController.text,
                    }),
                    child: const Text('SUBMIT VERIFICATION', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _confirmWithPin(ServiceRequestEntity request, Map<String, dynamic> data) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => PinDialog(
        title: 'Operator Security PIN',
        onConfirm: (pin) async {
          final operatorId = Supabase.instance.client.auth.currentUser?.id;
          if (operatorId == null) return 'Session expired. Please re-login.';

          final result = await _service.verifyMaterial(
            requestId: request.id,
            operatorId: operatorId,
            actualSacks: data['sacks'],
            condition: data['condition'],
            state: data['state'],
            source: data['source'],
            estimatedTime: data['time'],
            isAccurate: data['isAccurate'],
            pin: pin,
            remarks: data['remarks'],
            currentStatus: request.status.name,
          );

          return result.fold(
            (l) => l.message,
            (_) {
              Navigator.pop(context); // Close bottom sheet
              _loadRequests();
              return null;
            },
          );
        },
      ),
    ).then((success) {
      if (success == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Verification submitted!'), 
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          )
        );
      }
    });
  }

  void _showMinerDirectory() {
    String searchQuery = '';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.bgColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: const EdgeInsets.all(24),
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Miner Directory', style: TextStyle(color: kGold, fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              TextField(
                decoration: InputDecoration(
                  hintText: 'Search miners...',
                  prefixIcon: const Icon(Icons.search, color: kGold),
                  filled: true,
                  fillColor: context.surfaceColor,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onChanged: (v) => setModalState(() => searchQuery = v),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView(
                  children: _allUsers
                    .where((u) => u.roleId.toLowerCase().contains('miner') && 
                                 ('${u.fname} ${u.lname}'.toLowerCase().contains(searchQuery.toLowerCase())))
                    .map((miner) => Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: context.surfaceColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: kGold.withOpacity(0.1)),
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: kGold.withOpacity(0.1),
                          child: Text(miner.fname[0].toUpperCase(), style: const TextStyle(color: kGold, fontWeight: FontWeight.bold)),
                        ),
                        title: Text('${miner.fname} ${miner.lname}', style: TextStyle(color: context.textColor, fontWeight: FontWeight.bold, fontSize: 14)),
                        subtitle: Text(miner.miningUnitName ?? 'Independent Miner', style: const TextStyle(fontSize: 11)),
                        trailing: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            _showCreateAssistedRequest(initialMinerId: miner.userId);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kGold.withOpacity(0.1),
                            foregroundColor: kGold,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: const BorderSide(color: kGold)),
                          ),
                          child: const Text('CREATE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    )).toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCreateAssistedRequest({String? initialMinerId}) {
    int currentStep = 1;
    final formKey = GlobalKey<FormState>();

    List<String> selectedMinerIds = initialMinerId != null ? [initialMinerId] : [];
    String minerSearchQuery = '';

    String condition = 'Rocky';
    String state = 'Dry';
    String otherState = '';
    int? sacks;
    String source = '';
    String estProcessingTime = '';
    String notes = '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.bgColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 20, left: 20, right: 20, top: 12),
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: kGold.withOpacity(0.3), borderRadius: BorderRadius.circular(2)))),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(currentStep == 1 ? 'Step 1: Miner Selection' : 'Step 2: Material Info', style: const TextStyle(color: kGold, fontSize: 20, fontWeight: FontWeight.bold)),
                      Text('$currentStep / 2', style: TextStyle(color: context.mutedTextColor, fontSize: 14, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 20),

                  if (currentStep == 1) ...[
                    const Text('Select additional miners for group requests.', style: TextStyle(fontSize: 13)),
                    const SizedBox(height: 16),
                    TextField(
                      decoration: InputDecoration(
                        hintText: 'Search miners...',
                        prefixIcon: const Icon(Icons.search, color: kGold),
                        filled: true,
                        fillColor: context.surfaceColor,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: kGold.withOpacity(0.2))),
                      ),
                      style: TextStyle(color: context.textColor),
                      onChanged: (v) => setModalState(() => minerSearchQuery = v),
                    ),
                    const SizedBox(height: 12),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 250),
                      child: ListView(
                        shrinkWrap: true,
                        children: _allUsers
                          .where((m) => m.roleId.toLowerCase().contains('miner') && 
                                       ('${m.fname} ${m.lname}'.toLowerCase().contains(minerSearchQuery.toLowerCase())))
                          .map((m) => CheckboxListTile(
                            title: Text('${m.fname} ${m.lname}', style: TextStyle(color: context.textColor, fontSize: 14)),
                            subtitle: Text(m.email, style: TextStyle(color: context.mutedTextColor, fontSize: 11)),
                            value: selectedMinerIds.contains(m.userId),
                            onChanged: (v) => setModalState(() => v! ? selectedMinerIds.add(m.userId) : selectedMinerIds.remove(m.userId)),
                            activeColor: kGold,
                            contentPadding: EdgeInsets.zero,
                            controlAffinity: ListTileControlAffinity.leading,
                          )).toList(),
                      ),
                    ),
                  ] else ...[
                    _buildFormLabel('Material Condition'),
                    Wrap(
                      spacing: 8,
                      children: ['Rocky', 'Muddy', 'Sandy', 'Mixed', 'Clay'].map((c) => Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Radio<String>(value: c, groupValue: condition, activeColor: kGold, onChanged: (v) => setModalState(() => condition = v!)),
                          Text(c, style: TextStyle(color: context.textColor, fontSize: 12)),
                        ],
                      )).toList(),
                    ),

                    _buildFormLabel('Material State'),
                    Wrap(
                      spacing: 8,
                      children: ['Dry', 'Wet', 'Others'].map((s) => Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Radio<String>(value: s, groupValue: state, activeColor: kGold, onChanged: (v) => setModalState(() => state = v!)),
                          Text(s, style: TextStyle(color: context.textColor, fontSize: 12)),
                        ],
                      )).toList(),
                    ),
                    if (state == 'Others')
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: TextFormField(
                          onChanged: (v) => otherState = v,
                          style: TextStyle(color: context.textColor, fontSize: 13),
                          decoration: InputDecoration(hintText: 'Specify state', filled: true, fillColor: context.surfaceColor, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                        ),
                      ),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          child: _buildAssistedInput('Actual Sacks', '0', (v) => sacks = int.tryParse(v), isNumber: true),
                        ),
                      ],
                    ),
                    
                    _buildAssistedInput('Est. Total Processing Time', 'e.g. 3 hours', (v) => estProcessingTime = v),
                    _buildAssistedInput('Source / Tunnel Name', 'Enter origin', (v) => source = v),
                    _buildAssistedInput('Additional Notes', 'Optional requirements', (v) => notes = v, maxLines: 2),
                  ],

                  const SizedBox(height: 32),
                  Row(
                    children: [
                      if (currentStep == 2) ...[
                        Expanded(child: OutlinedButton(onPressed: () => setModalState(() => currentStep = 1), style: OutlinedButton.styleFrom(side: const BorderSide(color: kGold), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), minimumSize: const Size(0, 54)), child: const Text('Back', style: TextStyle(color: kGold)))),
                        const SizedBox(width: 12),
                      ],
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            if (currentStep == 1) {
                              if (selectedMinerIds.isEmpty) return;
                              setModalState(() => currentStep = 2);
                            } else {
                              if (formKey.currentState!.validate()) {
                                Navigator.pop(context);
                                _confirmAssistedRequestSubmission(
                                  selectedMiners: _allUsers.where((u) => selectedMinerIds.contains(u.userId)).toList(),
                                  condition: condition,
                                  state: state == 'Others' ? otherState : state,
                                  sacks: sacks ?? 0,
                                  source: source,
                                  estTime: estProcessingTime,
                                  notes: notes,
                                );
                              }
                            }
                          },
                          style: ElevatedButton.styleFrom(backgroundColor: kGold, foregroundColor: kBlack, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), minimumSize: const Size(0, 54)),
                          child: Text(currentStep == 1 ? 'Next Step' : 'Review & Authorize', style: const TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _confirmAssistedRequestSubmission({
    required List<UserEntity> selectedMiners,
    required String condition,
    required String state,
    required int sacks,
    required String source,
    required String estTime,
    required String notes,
  }) {
    String authorizerId = selectedMiners.first.userId;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: context.surfaceColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Confirm Assisted Submission', style: TextStyle(color: kGold, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('One miner must authorize this record with their PIN.', style: TextStyle(fontSize: 12)),
                const SizedBox(height: 16),
                _buildReviewRow('Source', source),
                _buildReviewRow('Sacks', sacks.toString()),
                _buildReviewRow('Condition', condition),
                const SizedBox(height: 16),
                const Text('Who is authorizing?', style: TextStyle(color: kGold, fontSize: 11, fontWeight: FontWeight.bold)),
                ...selectedMiners.map((m) => RadioListTile<String>(
                  title: Text('${m.fname} ${m.lname}', style: TextStyle(color: context.textColor, fontSize: 13)),
                  value: m.userId,
                  groupValue: authorizerId,
                  activeColor: kGold,
                  contentPadding: EdgeInsets.zero,
                  onChanged: (v) => setDialogState(() => authorizerId = v!),
                )).toList(),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _authorizeAssistedPIN(
                  minerId: authorizerId,
                  allMinerIds: selectedMiners.map((m) => m.userId).toList(),
                  condition: condition,
                  state: state,
                  sacks: sacks,
                  source: source,
                  estTime: estTime,
                  notes: notes,
                );
              },
              style: ElevatedButton.styleFrom(backgroundColor: kGold, foregroundColor: kBlack),
              child: const Text('Verify PIN'),
            ),
          ],
        ),
      ),
    );
  }

  void _authorizeAssistedPIN({
    required String minerId,
    required List<String> allMinerIds,
    required String condition,
    required String state,
    required int sacks,
    required String source,
    required String estTime,
    required String notes,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => PinDialog(
        title: 'Miner PIN Verification',
        onConfirm: (pin) async {
          final operatorId = Supabase.instance.client.auth.currentUser?.id;
          if (operatorId == null) return 'Session expired.';
          
          final operatorName = _getMinerName(operatorId); // Reusing name helper

          final result = await _service.createRequest(
            creatorId: minerId,
            participatingMinerIds: allMinerIds,
            materialCondition: condition,
            materialState: state,
            numberOfSacks: sacks,
            source: source,
            notes: notes,
            processingRequirements: notes,
            estimatedTime: estTime,
            pin: pin,
            isOperatorAssisted: true,
            assistedByOperatorId: operatorId,
            assistedByOperatorName: operatorName,
          );

          return result.fold(
            (l) => l.message,
            (_) {
              _loadRequests();
              return null;
            }
          );
        },
      ),
    ).then((success) {
      if (success == true) {
         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Assisted request submitted successfully!'), backgroundColor: Colors.green));
      }
    });
  }

  Widget _buildFormLabel(String text) {
    return Padding(padding: const EdgeInsets.only(top: 12, bottom: 4), child: Text(text, style: const TextStyle(color: kGold, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1)));
  }

  Widget _buildAssistedInput(String label, String hint, Function(String) onChanged, {bool isNumber = false, bool isDecimal = false, int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        onChanged: onChanged,
        maxLines: maxLines,
        keyboardType: isNumber ? (isDecimal ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.number) : TextInputType.text,
        style: TextStyle(color: context.textColor, fontSize: 14),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          filled: true,
          fillColor: context.surfaceColor,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }

  Widget _buildReviewRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: TextStyle(color: context.mutedTextColor, fontSize: 12)),
        Text(value, style: TextStyle(color: context.textColor, fontWeight: FontWeight.bold, fontSize: 13)),
      ]),
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
