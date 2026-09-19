import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../infrastructure/repositories/supabase_processing_repository.dart';
import '../../shared_widgets/appColor.dart';
import '../../shared_widgets/adminDrawer.dart';
import '../../shared_widgets/themeToggleButton.dart';

class ActiveProcessingPage extends StatefulWidget {
  const ActiveProcessingPage({super.key});

  @override
  State<ActiveProcessingPage> createState() => _ActiveProcessingPageState();
}

class _ActiveProcessingPageState extends State<ActiveProcessingPage> {
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
    final result = await _repository.getProcessingTasks(status: 'Active');
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
        title: const Text('ACTIVE PROCESSING', style: TextStyle(color: kGold, fontWeight: FontWeight.bold, letterSpacing: 1.5, fontSize: 14)),
        actions: [
          const ThemeToggleButton(),
          IconButton(icon: const Icon(Icons.menu_rounded, color: kGold), onPressed: () => _scaffoldKey.currentState?.openEndDrawer()),
        ],
      ),
      endDrawer: const AdminDrawer(currentMenu: AdminMenu.activeProcessing),
      body: RefreshIndicator(
        onRefresh: _fetchTasks,
        color: kGold,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: kGold))
            : _tasks.isEmpty
                ? const Center(child: Text('No active processing jobs.'))
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _tasks.length,
                    itemBuilder: (context, index) {
                      final t = _tasks[index];
                      return Card(
                        color: context.surfaceColor,
                        child: ListTile(
                          leading: const Icon(Icons.play_circle_fill, color: Colors.green),
                          title: Text(t['service_requests']?['purpose'] ?? 'Processing', style: TextStyle(color: context.textColor, fontWeight: FontWeight.bold)),
                          subtitle: Text('Machine: ${t['machines']?['machine_name']} | Operator: ${t['operator']?['fname']}', style: TextStyle(color: context.mutedTextColor)),
                          trailing: ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: kGold),
                            onPressed: () => _showCompletionDialog(t),
                            child: const Text('Complete', style: TextStyle(color: Colors.white, fontSize: 10)),
                          ),
                        ),
                      );
                    },
                  ),
      ),
    );
  }

  void _showCompletionDialog(Map<String, dynamic> task) {
    final remarksController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.surfaceColor,
        title: const Text('Complete Job', style: TextStyle(color: kGold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: remarksController,
              decoration: const InputDecoration(labelText: 'Operator Remarks'),
              maxLines: 2,
              style: TextStyle(color: context.textColor),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () async {
              await _repository.updateTaskStatus(
                task['processing_id'], 
                'Completed', 
                remarks: remarksController.text,
              );
              Navigator.pop(context);
              _fetchTasks();
            },
            child: const Text('Finish', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
