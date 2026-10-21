import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../infrastructure/repositories/supabase_user_repository.dart';
import '../../domain/entities/user_entity.dart';
import '../shared_widgets/appColor.dart';
import '../shared_widgets/themeToggleButton.dart';

class WorkforceShiftPage extends StatefulWidget {
  const WorkforceShiftPage({super.key});

  @override
  State<WorkforceShiftPage> createState() => _WorkforceShiftPageState();
}

class _WorkforceShiftPageState extends State<WorkforceShiftPage> {
  final SupabaseUserRepository _userRepository = SupabaseUserRepository();

  List<UserEntity> _operators = [];
  Map<String, String> _assignedMachines = {};
  bool _isLoading = true;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _currentUserId = Supabase.instance.client.auth.currentUser?.id;
    _loadData();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    final operatorsRes = await _userRepository.getOperators();
    final machineAssignments = <String, Set<String>>{};
    try {
      final ongoingServices = await Supabase.instance.client
          .from('ongoing_services')
          .select('operator_id, machines:machine_id(machine_name)');
      for (final row in ongoingServices) {
        final operatorId = row['operator_id']?.toString();
        final machine = row['machines'];
        final machineName = machine is Map
            ? machine['machine_name']?.toString()
            : null;
        if (operatorId != null && machineName != null && machineName.isNotEmpty) {
          machineAssignments.putIfAbsent(operatorId, () => <String>{}).add(
            machineName,
          );
        }
      }
    } catch (error) {
      debugPrint('Could not load operator machine assignments: $error');
    }

    if (!mounted) return;
    setState(() {
      _operators = operatorsRes.fold((l) => [], (r) => r);
      _assignedMachines = machineAssignments.map(
        (operatorId, names) => MapEntry(operatorId, names.join(', ')),
      );
      _isLoading = false;
    });
  }

  String _getAssignedMachine(String userId) {
    return _assignedMachines[userId] ?? 'None';
  }

  Future<void> _toggleDutyStatus(UserEntity operator) async {
    final newStatus = operator.status == 'active' ? 'approved' : 'active';
    setState(() => _isLoading = true);

    final res = await _userRepository.updateUserStatus(
      operator.userId,
      newStatus,
    );
    res.fold(
      (l) => ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l.message))),
      (_) => _loadData(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
        actions: [const ThemeToggleButton()],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: kGold))
          : _buildOperatorsTab(),
    );
  }

  Widget _buildOperatorsTab() {
    return RefreshIndicator(
      onRefresh: _loadData,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _operators.length,
            itemBuilder: (context, index) {
              final op = _operators[index];
              final isMe = op.userId == _currentUserId;
              final onDuty = op.status == 'active';

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: context.surfaceColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isMe ? kGold : kGold.withOpacity(0.1),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: onDuty
                              ? Colors.green.withOpacity(0.1)
                              : Colors.grey.withOpacity(0.1),
                          child: Icon(
                            Icons.person,
                            color: onDuty ? Colors.green : Colors.grey,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${op.fname} ${op.lname}${isMe ? ' (You)' : ''}',
                                style: TextStyle(
                                  color: context.textColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                onDuty ? 'ON DUTY' : 'OFF DUTY',
                                style: TextStyle(
                                  color: onDuty ? Colors.green : Colors.grey,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
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
                    const Divider(height: 18),
                    Wrap(
                      spacing: 20,
                      runSpacing: 8,
                      children: [
                        _buildMiniInfo(
                          'Assigned Machine',
                          _getAssignedMachine(op.userId),
                        ),
                        _buildMiniInfo(
                          'Contact',
                          op.contactNum.isEmpty ? 'Not provided' : op.contactNum,
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildMiniInfo(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(color: context.mutedTextColor, fontSize: 10),
        ),
        Text(
          value,
          style: TextStyle(
            color: context.textColor,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildLogoMark() {    return Image.asset(
      'assets/img/EGReS.png',
      width: 34,
      height: 34,
      fit: BoxFit.contain,
    );
  }
}
