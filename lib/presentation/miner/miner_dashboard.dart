import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../shared_widgets/appColor.dart';
import '../shared_widgets/themeToggleButton.dart';
import '../shared_widgets/pin_dialog.dart';
import '../client/service_requests_page.dart';
import 'miner_drawer.dart';
import '../../infrastructure/repositories/supabase_user_repository.dart';
import '../../infrastructure/repositories/supabase_service_request_repository.dart';
import '../../application/services/service_request_service.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/entities/service_request_entity.dart';

class MinerDashboardPage extends StatefulWidget {
  const MinerDashboardPage({super.key, this.minerName = 'Miner'});

  final String minerName;

  @override
  State<MinerDashboardPage> createState() => _MinerDashboardPageState();
}

class _MinerDashboardPageState extends State<MinerDashboardPage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final SupabaseUserRepository _userRepository = SupabaseUserRepository();
  final SupabaseServiceRequestRepository _requestRepository =
      SupabaseServiceRequestRepository();
  late final ServiceRequestService _service;

  List<UserEntity> _otherMiners = [];
  bool _isLoadingMiners = false;

  @override
  void initState() {
    super.initState();
    _service = ServiceRequestService(_requestRepository);
    _loadMiners();
  }

  Future<void> _loadMiners() async {
    setState(() => _isLoadingMiners = true);
    final result = await _userRepository.getMinersAndClients();
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;

    setState(() {
      _otherMiners = result.fold(
        (l) => [],
        (users) => users
            .where((u) => u.userId != currentUserId && u.roleId == 'miner')
            .toList(),
      );
      _isLoadingMiners = false;
    });

    _checkActionRequired();
  }

  bool _hasActionRequired = false;
  Future<void> _checkActionRequired() async {
    final result = await _requestRepository.getServiceRequests();
    result.fold((l) => null, (requests) {
      setState(() {
        _hasActionRequired =
            requests.any((r) => r.status == ServiceRequestStatus.returnedToMiner);
      });
    });
  }

  void _showCreateRequestWorkflow() {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    if (currentUserId == null) return;

    int currentStep = 1;
    final formKey = GlobalKey<FormState>();

    // Step 1: Miner Selection
    bool forMyselfOnly = true;
    List<String> participatingIds = [];
    String minerSearchQuery = '';

    // Step 2: Material Information
    String materialType = '';
    String materialCondition = '';
    int? numberOfSacks;
    double weight = 0;
    String source = '';
    String notes = '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.bgColor,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              left: 20,
              right: 20,
              top: 20,
            ),
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
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          currentStep == 1
                              ? 'Step 1: Miner Selection'
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
                    const SizedBox(height: 24),
                    if (currentStep == 1) ...[
                      Text('Are you creating this request as a group?',
                          style: TextStyle(
                              color: context.textColor,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      RadioListTile<bool>(
                        title: Text('Create for myself only',
                            style: TextStyle(color: context.textColor)),
                        value: true,
                        groupValue: forMyselfOnly,
                        activeColor: kGold,
                        onChanged: (v) => setModalState(() => forMyselfOnly = v!),
                      ),
                      RadioListTile<bool>(
                        title: Text('Add another Miner (Group)',
                            style: TextStyle(color: context.textColor)),
                        value: false,
                        groupValue: forMyselfOnly,
                        activeColor: kGold,
                        onChanged: (v) => setModalState(() => forMyselfOnly = v!),
                      ),
                      if (!forMyselfOnly) ...[
                        const SizedBox(height: 16),
                        TextField(
                          decoration: InputDecoration(
                            hintText: 'Search miners by name...',
                            prefixIcon: const Icon(Icons.search, color: kGold),
                            filled: true,
                            fillColor: context.surfaceColor,
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide:
                                    BorderSide(color: kGold.withOpacity(0.2))),
                          ),
                          style: TextStyle(color: context.textColor),
                          onChanged: (v) =>
                              setModalState(() => minerSearchQuery = v),
                        ),
                        const SizedBox(height: 12),
                        if (_isLoadingMiners)
                          const Center(
                              child: CircularProgressIndicator(color: kGold))
                        else if (_otherMiners.isEmpty)
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text('No other miners available.',
                                style: TextStyle(
                                    color: context.mutedTextColor,
                                    fontSize: 13)),
                          )
                        else
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxHeight: 200),
                            child: ListView(
                              shrinkWrap: true,
                              children: _otherMiners
                                  .where((m) =>
                                      m.fname.toLowerCase().contains(
                                          minerSearchQuery.toLowerCase()) ||
                                      m.lname.toLowerCase().contains(
                                          minerSearchQuery.toLowerCase()))
                                  .map((m) => CheckboxListTile(
                                        title: Text('${m.fname} ${m.lname}',
                                            style: TextStyle(
                                                color: context.textColor)),
                                        subtitle: Text(m.email,
                                            style: TextStyle(
                                                color: context.mutedTextColor,
                                                fontSize: 12)),
                                        value: participatingIds.contains(m.userId),
                                        activeColor: kGold,
                                        onChanged: (selected) {
                                          setModalState(() {
                                            if (selected!) {
                                              participatingIds.add(m.userId);
                                            } else {
                                              participatingIds.remove(m.userId);
                                            }
                                          });
                                        },
                                      ))
                                  .toList(),
                            ),
                          ),
                      ],
                    ] else ...[
                      _buildValidatedInput(
                        label: 'Material Type',
                        hint: 'e.g. Gold Ore, Silver',
                        onChanged: (v) => materialType = v,
                        validator: (v) => (v == null || v.isEmpty)
                            ? 'Material type is required'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      _buildValidatedInput(
                        label: 'Material Condition',
                        hint: 'e.g. Wet, Dry, Muddy',
                        onChanged: (v) => materialCondition = v,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _buildValidatedInput(
                              label: 'Number of Sacks',
                              hint: 'Optional',
                              keyboardType: TextInputType.number,
                              onChanged: (v) => numberOfSacks = int.tryParse(v),
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildValidatedInput(
                              label: 'Est. Weight (kg)',
                              hint: '0.0',
                              keyboardType: const TextInputType.numberWithOptions(
                                  decimal: true),
                              onChanged: (v) => weight = double.tryParse(v) ?? 0,
                              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                              validator: (v) {
                                if (v == null || v.isEmpty) {
                                  return 'Weight is required';
                                }
                                final val = double.tryParse(v);
                                if (val == null || val <= 0) {
                                  return 'Enter a valid weight';
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildValidatedInput(
                        label: 'Source (Tunnel)',
                        hint: 'Which tunnel did this come from?',
                        onChanged: (v) => source = v,
                      ),
                      const SizedBox(height: 16),
                      _buildValidatedInput(
                        label: 'Additional Notes',
                        hint: 'Any other processing requirements...',
                        maxLines: 2,
                        onChanged: (v) => notes = v,
                      ),
                      const SizedBox(height: 16),
                      Text('Upload Photo/Document',
                          style: TextStyle(
                              color: context.mutedTextColor,
                              fontSize: 12,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                              content: Text('Photo upload coming soon!')));
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          decoration: BoxDecoration(
                            color: context.surfaceColor,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: kGold.withOpacity(0.3),
                                style: BorderStyle.solid),
                          ),
                          child: Center(
                            child: Column(
                              children: [
                                Icon(Icons.add_a_photo_outlined,
                                    color: kGold.withOpacity(0.7)),
                                const SizedBox(height: 4),
                                Text('Add Attachment (Optional)',
                                    style: TextStyle(
                                        color: kGold.withOpacity(0.7),
                                        fontSize: 12)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 32),
                    Row(
                      children: [
                        if (currentStep == 2) ...[
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () =>
                                  setModalState(() => currentStep = 1),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: kGold),
                                minimumSize: const Size(double.infinity, 50),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                              child: const Text('Back',
                                  style: TextStyle(
                                      color: kGold, fontWeight: FontWeight.bold)),
                            ),
                          ),
                          const SizedBox(width: 12),
                        ],
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              if (currentStep == 1) {
                                if (!forMyselfOnly && participatingIds.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content: Text(
                                              'Please select at least one other miner for a group request.')));
                                  return;
                                }
                                setModalState(() => currentStep = 2);
                              } else {
                                if (formKey.currentState!.validate()) {
                                  Navigator.pop(context);
                                  _showReviewDialog(
                                    materialType: materialType,
                                    materialCondition: materialCondition,
                                    numberOfSacks: numberOfSacks,
                                    weight: weight,
                                    source: source,
                                    notes: notes,
                                    participatingIds: [
                                      currentUserId,
                                      ...participatingIds
                                    ],
                                  );
                                }
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: kGold,
                              foregroundColor: kBlack,
                              minimumSize: const Size(double.infinity, 50),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            child: Text(
                                currentStep == 1 ? 'Next Step' : 'Review & Submit',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 16)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showReviewDialog({
    required String materialType,
    required String materialCondition,
    int? numberOfSacks,
    required double weight,
    required String source,
    required String notes,
    required List<String> participatingIds,
  }) {
    bool isCertified = false;
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return AlertDialog(
            backgroundColor: context.surfaceColor,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('Review Request Details',
                style: TextStyle(color: kGold, fontWeight: FontWeight.bold)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Please check the entered information for accuracy.',
                      style: TextStyle(
                          color: context.mutedTextColor, fontSize: 13)),
                  const SizedBox(height: 16),
                  _buildReviewItem('Material Type', materialType),
                  if (materialCondition.isNotEmpty)
                    _buildReviewItem('Condition', materialCondition),
                  if (numberOfSacks != null)
                    _buildReviewItem('Sacks', numberOfSacks.toString()),
                  _buildReviewItem('Est. Weight', '$weight kg'),
                  if (source.isNotEmpty) _buildReviewItem('Source', source),
                  _buildReviewItem(
                      'Participants', '${participatingIds.length} Miner(s)'),
                  const SizedBox(height: 12),
                  const Text('Additional Notes:',
                      style: TextStyle(
                          color: kGold,
                          fontSize: 12,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: context.bgColor.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      notes.isEmpty ? 'None' : notes,
                      style: TextStyle(
                          color: context.textColor,
                          fontWeight: FontWeight.w500,
                          fontSize: 13),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Divider(),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                        'I certify that the information above is accurate and ready for verification.',
                        style: TextStyle(fontSize: 12)),
                    value: isCertified,
                    activeColor: kGold,
                    onChanged: (v) => setModalState(() => isCertified = v!),
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child:
                      const Text('Go Back', style: TextStyle(color: Colors.grey))),
              ElevatedButton(
                onPressed: isCertified
                    ? () {
                        Navigator.pop(context);
                        _showPinConfirmation(
                          materialType: materialType,
                          materialCondition: materialCondition,
                          numberOfSacks: numberOfSacks,
                          weight: weight,
                          source: source,
                          notes: notes,
                          participatingIds: participatingIds,
                        );
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                    backgroundColor: kGold, foregroundColor: kBlack),
                child: const Text('Authorize & Submit',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showPinConfirmation({
    required String materialType,
    required String materialCondition,
    int? numberOfSacks,
    required double weight,
    required String source,
    required String notes,
    required List<String> participatingIds,
  }) {
    showDialog(
      context: context,
      builder: (context) => PinDialog(
        title: 'Authorize Submission',
        onConfirm: (pin) async {
          final currentUserId = Supabase.instance.client.auth.currentUser?.id;
          if (currentUserId == null) return;

          final result = await _service.createRequest(
            creatorId: currentUserId,
            participatingMinerIds: participatingIds,
            materialType: materialType,
            materialCondition: materialCondition,
            numberOfSacks: numberOfSacks,
            materialWeight: weight,
            source: source,
            notes: notes,
            processingRequirements: notes, // Mapping notes to requirements
            pin: pin,
          );

          result.fold(
            (l) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(l.message), backgroundColor: Colors.redAccent)),
            (_) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Request submitted for Operator verification!'),
                  backgroundColor: Colors.green,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildValidatedInput({
    required String label,
    required String hint,
    TextInputType? keyboardType,
    int maxLines = 1,
    required Function(String) onChanged,
    String? Function(String?)? validator,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(color: context.mutedTextColor, fontSize: 12)),
        const SizedBox(height: 6),
        TextFormField(
          maxLines: maxLines,
          keyboardType: keyboardType,
          onChanged: onChanged,
          validator: validator,
          inputFormatters: inputFormatters,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          style: TextStyle(color: context.textColor),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle:
                TextStyle(color: context.mutedTextColor.withOpacity(0.3)),
            filled: true,
            fillColor: context.surfaceColor,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: kGold.withOpacity(0.2))),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: kGold.withOpacity(0.2))),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: kGold)),
            errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide:
                    const BorderSide(color: Colors.redAccent, width: 1)),
            focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide:
                    const BorderSide(color: Colors.redAccent, width: 1.5)),
            errorStyle: const TextStyle(color: Colors.redAccent, fontSize: 11),
          ),
        ),
      ],
    );
  }

  Widget _buildReviewItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(color: context.mutedTextColor, fontSize: 13)),
          Text(value,
              style: TextStyle(
                  color: context.textColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 14)),
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
          child: _buildLogoMark(),
        ),
        title: const Text(
          'GAHIRA',
          style: TextStyle(
              color: kGold,
              fontWeight: FontWeight.bold,
              letterSpacing: 3,
              fontSize: 16),
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
      endDrawer: MinerDrawer(
        currentMenu: MinerMenu.dashboard,
        minerName: widget.minerName,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateRequestWorkflow,
        backgroundColor: kGold,
        foregroundColor: kBlack,
        child: const Icon(Icons.add_rounded),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Welcome back,',
                style: TextStyle(color: context.mutedTextColor, fontSize: 14)),
            Text(widget.minerName,
                style: TextStyle(
                    color: context.textColor,
                    fontSize: 24,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 32),
            _buildMetricCard(
                'My Total Requests', '0', Icons.description_outlined, kGold),
            const SizedBox(height: 24),
            if (_hasActionRequired) ...[
              _buildActionRequiredCard(),
              const SizedBox(height: 24),
            ],
            Text('Quick Actions',
                style: TextStyle(
                    color: context.textColor,
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildQuickActionButton(
                      'New Request', Icons.add_circle_outline,
                      _showCreateRequestWorkflow),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildQuickActionButton(
                      'History', Icons.history_rounded, () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const ServiceRequestsPage()),
                    );
                  }),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionRequiredCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.red),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Action Required',
                    style: TextStyle(
                        color: Colors.red, fontWeight: FontWeight.bold)),
                Text('One or more requests were returned for corrections.',
                    style:
                        TextStyle(color: context.textColor, fontSize: 12)),
              ],
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const ServiceRequestsPage()),
              );
            },
            child: const Text('View',
                style:
                    TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(
      String title, String value, IconData icon, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kGold.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(width: 20),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value,
                  style: TextStyle(
                      color: context.textColor,
                      fontSize: 28,
                      fontWeight: FontWeight.bold)),
              Text(title,
                  style:
                      TextStyle(color: context.mutedTextColor, fontSize: 14)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionButton(
      String label, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: context.surfaceColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kGold.withOpacity(0.1)),
        ),
        child: Column(
          children: [
            Icon(icon, color: kGold, size: 28),
            const SizedBox(height: 8),
            Text(label,
                style: TextStyle(
                    color: context.textColor, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
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
      child: const Icon(Icons.settings_input_component_rounded,
          color: kGold, size: 16),
    );
  }
}
