import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/services.dart';
import 'package:dartz/dartz.dart' hide State;

import '../../core/error/failures.dart';
import '../shared_widgets/appColor.dart';
import '../shared_widgets/themeToggleButton.dart';
import '../shared_widgets/pin_dialog.dart';
import 'operator_drawer.dart';
import 'processing_workflow_page.dart';
import '../../infrastructure/repositories/supabase_user_repository.dart';
import '../../infrastructure/repositories/supabase_service_request_repository.dart';
import '../../application/services/service_request_service.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/entities/service_request_entity.dart';
import '../../infrastructure/models/service_request_model.dart';

import 'service_verification_page.dart';

class OperatorDashboardPage extends StatefulWidget {
  const OperatorDashboardPage({super.key, this.operatorName = 'Operator'});

  final String operatorName;

  @override
  State<OperatorDashboardPage> createState() => _OperatorDashboardPageState();
}

class _OperatorDashboardPageState extends State<OperatorDashboardPage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final SupabaseUserRepository _userRepository = SupabaseUserRepository();
  final SupabaseServiceRequestRepository _requestRepository =
      SupabaseServiceRequestRepository();
  late final ServiceRequestService _service;

  List<UserEntity> _allMiners = [];
  bool _isLoadingMiners = false;
  bool _isAvailable = true; // Simulating "Operator Becomes Available"

  // Mock data for dashboard visuals
  final List<Map<String, dynamic>> _millStatus = [
    {
      'name': 'Mill #01 - Primary',
      'status': 'Running',
      'rpm': 45.2,
      'load': 0.85
    },
    {
      'name': 'Mill #02 - Secondary',
      'status': 'Running',
      'rpm': 42.8,
      'load': 0.78
    },
    {'name': 'Mill #03 - Tertiary', 'status': 'Stopped', 'rpm': 0.0, 'load': 0.0},
    {
      'name': 'Mill #04 - Auxiliary',
      'status': 'Maintenance',
      'rpm': 12.5,
      'load': 0.30
    },
  ];

  final List<Map<String, dynamic>> _activeJobs = [
    {
      'id': 'JOB-001',
      'client': 'ABC Mining',
      'stage': 'Grinding',
      'progress': 0.65
    },
    {'id': 'JOB-002', 'client': 'Gold Corp', 'stage': 'Crushing', 'progress': 0.30},
    {
      'id': 'JOB-003',
      'client': 'Silver Ltd',
      'stage': 'Processing',
      'progress': 0.85
    },
  ];

  final List<Map<String, dynamic>> _activityLog = [
    {'message': 'Job JOB-001 moved to Grinding stage', 'time': '10 min ago'},
    {'message': 'Mill #02 maintenance completed', 'time': '1 hour ago'},
    {'message': 'Shift change: Morning to Afternoon', 'time': '2 hours ago'},
    {'message': 'New material delivery received', 'time': '3 hours ago'},
  ];

  @override
  void initState() {
    super.initState();
    _service = ServiceRequestService(_requestRepository);
    _loadMiners();
  }

  Future<void> _loadMiners() async {
    setState(() => _isLoadingMiners = true);
    final result = await _userRepository.getMinersAndClients();
    setState(() {
      _allMiners = result.fold(
        (l) => [],
        (users) => users.where((u) => u.roleId == 'miner').toList(),
      );
      _isLoadingMiners = false;
    });
  }

  void _showCreateAssistedRequest() {
    if (!_isAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be available to create requests.')),
      );
      return;
    }

    int currentStep = 1;
    final formKey = GlobalKey<FormState>();

    // Step 1: Miner Selection
    List<String> selectedMinerIds = [];
    String minerSearchQuery = '';

    // Step 2: Material Details
    String condition = '';
    int? sacks;
    double weight = 0;
    String source = '';
    String estProcessingTime = '';
    String notes = '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.bgColor,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                left: 20,
                right: 20,
                top: 12),
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                            color: kGold.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(2)),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          currentStep == 1
                              ? 'Step 1: Search & Select Miner(s)'
                              : 'Step 2: Material Information',
                          style: const TextStyle(
                              color: kGold,
                              fontSize: 20,
                              fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '$currentStep / 2',
                          style: TextStyle(
                              color: context.mutedTextColor,
                              fontSize: 14,
                              fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    if (currentStep == 1) ...[
                      const Text(
                        'Select the miner(s) who are physically present for processing.',
                        style: TextStyle(fontSize: 13),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        decoration: InputDecoration(
                          hintText: 'Search by name...',
                          prefixIcon: const Icon(Icons.search, color: kGold),
                          filled: true,
                          fillColor: context.surfaceColor,
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: kGold.withOpacity(0.2))),
                        ),
                        style: TextStyle(color: context.textColor),
                        onChanged: (v) => setModalState(() => minerSearchQuery = v),
                      ),
                      const SizedBox(height: 12),
                      if (_isLoadingMiners)
                        const Center(child: CircularProgressIndicator(color: kGold))
                      else
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 300),
                          child: ListView(
                            shrinkWrap: true,
                            children: _allMiners
                                .where((m) =>
                                    m.fname.toLowerCase().contains(minerSearchQuery.toLowerCase()) ||
                                    m.lname.toLowerCase().contains(minerSearchQuery.toLowerCase()))
                                .map((m) => CheckboxListTile(
                                      title: Text('${m.fname} ${m.lname}',
                                          style: TextStyle(color: context.textColor, fontSize: 14)),
                                      subtitle: Text(m.email, style: TextStyle(color: context.mutedTextColor, fontSize: 11)),
                                      value: selectedMinerIds.contains(m.userId),
                                      onChanged: (v) => setModalState(() => v!
                                          ? selectedMinerIds.add(m.userId)
                                          : selectedMinerIds.remove(m.userId)),
                                      activeColor: kGold,
                                      contentPadding: EdgeInsets.zero,
                                      controlAffinity: ListTileControlAffinity.leading,
                                    ))
                                .toList(),
                          ),
                        ),
                    ] else ...[
                      _buildValidatedInput(
                        context,
                        label: 'Material Condition',
                        hint: 'e.g. Wet, Dry, Muddy',
                        onChanged: (v) => condition = v,
                      ),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _buildValidatedInput(
                              context,
                              label: 'Number of Sacks',
                              hint: 'Optional',
                              keyboardType: TextInputType.number,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                              onChanged: (v) => sacks = int.tryParse(v),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildValidatedInput(
                              context,
                              label: 'Estimated Weight (kg)',
                              hint: '0.0',
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                              onChanged: (v) => weight = double.tryParse(v) ?? 0,
                              validator: (v) {
                                if (v == null || v.isEmpty) return 'Required';
                                if (double.tryParse(v) == null || double.parse(v) <= 0) return 'Invalid';
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                      _buildValidatedInput(
                        context,
                        label: 'Source (Tunnel)',
                        hint: 'Tunnel origin',
                        onChanged: (v) => source = v,
                      ),
                      _buildValidatedInput(
                        context,
                        label: 'Est. Total Processing Time',
                        hint: 'e.g. 3 hours, 1 day',
                        onChanged: (v) => estProcessingTime = v,
                        validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                      ),
                      _buildValidatedInput(
                        context,
                        label: 'Additional Notes',
                        hint: 'Processing requirements...',
                        maxLines: 2,
                        onChanged: (v) => notes = v,
                      ),
                    ],

                    const SizedBox(height: 32),
                    Row(
                      children: [
                        if (currentStep == 2) ...[
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => setModalState(() => currentStep = 1),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: kGold),
                                minimumSize: const Size(double.infinity, 54),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: const Text('Back', style: TextStyle(color: kGold, fontWeight: FontWeight.bold)),
                            ),
                          ),
                          const SizedBox(width: 12),
                        ],
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              if (currentStep == 1) {
                                if (selectedMinerIds.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select at least one miner.')));
                                  return;
                                }
                                setModalState(() => currentStep = 2);
                              } else {
                                if (formKey.currentState!.validate()) {
                                  Navigator.pop(context);
                                  _confirmAssistedRequest(
                                    primaryMinerId: selectedMinerIds.first,
                                    participatingIds: selectedMinerIds,
                                    condition: condition,
                                    sacks: sacks,
                                    weight: weight,
                                    source: source,
                                    estTime: estProcessingTime,
                                    notes: notes,
                                  );
                                }
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: kGold,
                              foregroundColor: kBlack,
                              minimumSize: const Size(double.infinity, 54),
                              elevation: 2,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: Text(
                                currentStep == 1 ? 'Next: Material Info' : 'Review & Authorize',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _confirmAssistedRequest({
    required String primaryMinerId,
    required List<String> participatingIds,
    required String condition,
    int? sacks,
    required double weight,
    required String source,
    required String estTime,
    required String notes,
  }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Review Request Details', style: TextStyle(color: kGold, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Please ask the primary Miner to verify these details and enter their PIN to authorize.', style: TextStyle(fontSize: 13)),
            const SizedBox(height: 20),
            _buildReviewRow(context, 'Weight', '$weight kg'),
            if (sacks != null) _buildReviewRow(context, 'Sacks', sacks.toString()),
            _buildReviewRow(context, 'Est. Time', estTime),
            _buildReviewRow(context, 'Participants', '${participatingIds.length} Miner(s)'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Back', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _authorizeWithMinerPin(
                minerId: primaryMinerId,
                participatingIds: participatingIds,
                condition: condition,
                sacks: sacks,
                weight: weight,
                source: source,
                estTime: estTime,
                notes: notes,
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: kGold, foregroundColor: kBlack),
            child: const Text('Miner Authorize'),
          ),
        ],
      ),
    );
  }

  void _authorizeWithMinerPin({
    required String minerId,
    required List<String> participatingIds,
    required String condition,
    int? sacks,
    required double weight,
    required String source,
    required String estTime,
    required String notes,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => PinDialog(
        title: 'Miner Authorization PIN',
        onConfirm: (pin) async {
          final currentOperatorId = Supabase.instance.client.auth.currentUser?.id;
          if (currentOperatorId == null) return 'Session expired. Please re-login.';

          final result = await _service.createRequest(
            creatorId: minerId,
            participatingMinerIds: participatingIds,
            materialType: 'Ore', 
            materialCondition: condition,
            numberOfSacks: sacks,
            materialWeight: weight,
            source: source,
            notes: notes,
            processingRequirements: notes,
            estimatedTime: estTime,
            pin: pin,
            isOperatorAssisted: true,
            assistedByOperatorId: currentOperatorId,
          );

          return result.fold(
            (l) => l.message,
            (_) => null,
          );
        },
      ),
    ).then((success) {
      if (success == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Service request created and forwarded to Owner!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });
  }

  Widget _buildValidatedInput(
    BuildContext context, {
    required String label,
    required String hint,
    TextInputType? keyboardType,
    int maxLines = 1,
    required Function(String) onChanged,
    String? Function(String?)? validator,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: context.mutedTextColor, fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          TextFormField(
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: context.mutedTextColor.withOpacity(0.3)),
              filled: true,
              fillColor: context.surfaceColor,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: kGold.withOpacity(0.2))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: kGold.withOpacity(0.2))),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kGold, width: 1.5)),
            ),
            style: TextStyle(color: context.textColor),
            keyboardType: keyboardType,
            maxLines: maxLines,
            onChanged: onChanged,
            validator: validator,
            inputFormatters: inputFormatters,
            autovalidateMode: AutovalidateMode.onUserInteraction,
          ),
        ],
      ),
    );
  }

  Widget _buildReviewRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: context.mutedTextColor, fontSize: 13)),
          Text(value, style: TextStyle(color: context.textColor, fontWeight: FontWeight.bold, fontSize: 14)),
        ],
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
        elevation: 0,
        leadingWidth: 64,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16),
          child: _buildLogoMark(context),
        ),
        title: const Text(
          'GAHIRA',
          style: TextStyle(color: kGold, fontWeight: FontWeight.bold, letterSpacing: 3, fontSize: 16),
        ),
        iconTheme: const IconThemeData(color: kGold),
        actions: [
          const ThemeToggleButton(),
          IconButton(
            icon: const Icon(Icons.menu_rounded, color: kGold),
            onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
          ),
        ],
      ),
      endDrawer: OperatorDrawer(
        currentMenu: OperatorMenu.dashboard,
        operatorName: widget.operatorName,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateAssistedRequest,
        backgroundColor: kGold,
        foregroundColor: kBlack,
        child: const Icon(Icons.add_rounded),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Availability Toggle & Welcome
            Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Welcome back,', style: TextStyle(color: context.mutedTextColor, fontSize: 14)),
                    Text(widget.operatorName, style: TextStyle(color: context.textColor, fontSize: 24, fontWeight: FontWeight.bold)),
                  ],
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => setState(() => _isAvailable = !_isAvailable),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _isAvailable ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _isAvailable ? Colors.green : Colors.red),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.circle, color: _isAvailable ? Colors.green : Colors.red, size: 8),
                        const SizedBox(width: 8),
                        Text(
                          _isAvailable ? 'AVAILABLE' : 'BUSY',
                          style: TextStyle(color: _isAvailable ? Colors.green : Colors.red, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // Quick Actions
            Text('Quick Actions', style: TextStyle(color: context.textColor, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildQuickActionButton(
                    context,
                    'Service Verification',
                    Icons.fact_check_outlined,
                    () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ServiceVerificationPage())),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildQuickActionButton(
                    context,
                    'Workflow',
                    Icons.settings_input_component_rounded,
                    () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ProcessingWorkflowPage())),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // Pending Verification Preview
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Recent Requests', style: TextStyle(color: context.textColor, fontSize: 18, fontWeight: FontWeight.bold)),
                TextButton(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ServiceVerificationPage())),
                  child: const Text('View All', style: TextStyle(color: kGold)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            FutureBuilder<Either<Failure, List<ServiceRequestModel>>>(
              future: _requestRepository.getServiceRequests(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: kGold));
                final list = snapshot.data?.fold((l) => [], (r) => r) ?? [];
                if (list.isEmpty) return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(color: context.surfaceColor, borderRadius: BorderRadius.circular(12)),
                  child: const Center(child: Text('No recent requests', style: TextStyle(color: Colors.grey))),
                );
                
                return Column(
                  children: list.take(3).map((r) => Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(color: context.surfaceColor, borderRadius: BorderRadius.circular(12)),
                    child: ListTile(
                      title: Text(r.materialDetails.type, style: TextStyle(color: context.textColor, fontWeight: FontWeight.bold, fontSize: 14)),
                      subtitle: Text('Ref: ${r.id.substring(0,8).toUpperCase()}', style: const TextStyle(fontSize: 12)),
                      trailing: const Icon(Icons.chevron_right, color: kGold),
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ServiceVerificationPage())),
                    ),
                  )).toList(),
                );
              }
            ),
            const SizedBox(height: 32),

            // Active Metrics (Placeholders for now)
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 1.5,
              children: [
                _buildMetricCard(context, 'Total Mills', '12', Icons.settings_input_component_rounded, kGold),
                _buildMetricCard(context, 'My Active Jobs', '02', Icons.play_circle_outline_rounded, Colors.green),
                _buildMetricCard(context, 'Maintenance', '01', Icons.build_circle_outlined, Colors.orange),
                _buildMetricCard(context, 'Avg Efficiency', '96%', Icons.bar_chart_rounded, Colors.blue),
              ],
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard(BuildContext context, String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kGold.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: color, size: 24),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: TextStyle(color: context.textColor, fontSize: 20, fontWeight: FontWeight.bold)),
              Text(title, style: TextStyle(color: context.mutedTextColor, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionButton(BuildContext context, String label, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
        decoration: BoxDecoration(
          color: context.surfaceColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kGold.withOpacity(0.1)),
        ),
        child: Column(
          children: [
            Icon(icon, color: kGold, size: 28),
            const SizedBox(height: 8),
            Text(label, textAlign: TextAlign.center, style: TextStyle(color: context.textColor, fontWeight: FontWeight.w500, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Widget _buildLogoMark(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: kGold, width: 1.6),
        color: context.bgColor,
      ),
      child: const Icon(Icons.settings_input_component_rounded, color: kGold, size: 16),
    );
  }
}
