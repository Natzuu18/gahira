import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../infrastructure/repositories/supabase_processing_repository.dart';
import '../../shared_widgets/appColor.dart';
import '../../shared_widgets/adminDrawer.dart';
import '../billing_page.dart';
import '../../shared_widgets/themeToggleButton.dart';

class CompletedProcessingPage extends StatefulWidget {
  const CompletedProcessingPage({super.key});

  @override
  State<CompletedProcessingPage> createState() => _CompletedProcessingPageState();
}

class _CompletedProcessingPageState extends State<CompletedProcessingPage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final _repository = SupabaseProcessingRepository();
  List<Map<String, dynamic>> _tasks = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchTasks();
  }

  Future<void> _fetchTasks() async {
    setState(() => _isLoading = true);
    final result = await _repository.getProcessingTasks(status: 'Completed');
    result.fold(
      (failure) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(failure.message))),
      (list) => setState(() {
        _tasks = list;
        _isLoading = false;
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: context.bgColor,
      appBar: AppBar(
        backgroundColor: context.surfaceColor,
        title: const Text('COMPLETED PROCESSING', style: TextStyle(color: kGold, fontWeight: FontWeight.bold, letterSpacing: 1.5, fontSize: 14)),
        actions: [
          const ThemeToggleButton(),
          IconButton(icon: const Icon(Icons.menu_rounded, color: kGold), onPressed: () => _scaffoldKey.currentState?.openEndDrawer()),
        ],
      ),
      endDrawer: const AdminDrawer(currentMenu: AdminMenu.completedProcessing),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: kGold))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _tasks.length,
              itemBuilder: (context, index) {
                final t = _tasks[index];
                return Card(
                  color: context.surfaceColor,
                  child: ListTile(
                    leading: const Icon(Icons.check_circle, color: Colors.green),
                    title: Text(t['service_requests']?['service_type'] ?? 'Job Result', style: TextStyle(color: context.textColor, fontWeight: FontWeight.bold)),
                    subtitle: Text('Date: ${t['scheduled_date']}', style: TextStyle(color: context.mutedTextColor)),
                    trailing: const Icon(Icons.receipt_outlined, color: kGold),
                    onTap: () => _showSummaryDialog(t),
                  ),
                );
              },
            ),
    );
  }

  void _showSummaryDialog(Map<String, dynamic> task) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.surfaceColor,
        title: const Text('Processing Summary', style: TextStyle(color: kGold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildRow('Miner', '${task['service_requests']?['user']?['fname']} ${task['service_requests']?['user']?['lname']}'),
            _buildRow('Machine', task['machines']?['machine_name'] ?? 'N/A'),
            _buildRow('Drum', task['drums']?['drum_name'] ?? 'N/A'),
            _buildRow('Operator', task['operator']?['fname'] ?? 'N/A'),
            _buildRow('Date', task['scheduled_date']),
            const Divider(),
            const Text('Remarks:', style: TextStyle(color: kGold, fontWeight: FontWeight.bold, fontSize: 12)),
            Text(task['remarks'] ?? 'No remarks', style: TextStyle(color: context.textColor, fontSize: 13)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
          ElevatedButton(
            onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const BillingPage())),
            style: ElevatedButton.styleFrom(backgroundColor: kGold, foregroundColor: kBlack),
            child: const Text('Proceed to Billing'),
          ),
        ],
      ),
    );
  }

  Widget _buildRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text('$label: ', style: const TextStyle(color: kGold, fontWeight: FontWeight.bold, fontSize: 12)),
          Text(value, style: TextStyle(color: context.textColor, fontSize: 12)),
        ],
      ),
    );
  }
}
