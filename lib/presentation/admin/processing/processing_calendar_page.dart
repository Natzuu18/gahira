import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../infrastructure/repositories/supabase_processing_repository.dart';
import '../../shared_widgets/appColor.dart';
import '../../shared_widgets/adminDrawer.dart';
import '../../shared_widgets/themeToggleButton.dart';

class ProcessingCalendarPage extends StatefulWidget {
  const ProcessingCalendarPage({super.key});

  @override
  State<ProcessingCalendarPage> createState() => _ProcessingCalendarPageState();
}

class _ProcessingCalendarPageState extends State<ProcessingCalendarPage> {
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
    final result = await _repository.getProcessingTasks();
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
    // Simple grouping by date
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    for (var t in _tasks) {
      final date = t['scheduled_date'];
      grouped.putIfAbsent(date, () => []).add(t);
    }
    final sortedDates = grouped.keys.toList()..sort();

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: context.bgColor,
      appBar: AppBar(
        backgroundColor: context.surfaceColor,
        title: const Text('CALENDAR', style: TextStyle(color: kGold, fontWeight: FontWeight.bold, letterSpacing: 1.5, fontSize: 14)),
        actions: [
          const ThemeToggleButton(),
          IconButton(icon: const Icon(Icons.menu_rounded, color: kGold), onPressed: () => _scaffoldKey.currentState?.openEndDrawer()),
        ],
      ),
      endDrawer: const AdminDrawer(currentMenu: AdminMenu.calendar),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: kGold))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: sortedDates.length,
              itemBuilder: (context, index) {
                final date = sortedDates[index];
                final dayTasks = grouped[date]!;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        DateFormat('EEEE, MMM dd, yyyy').format(DateTime.parse(date)),
                        style: const TextStyle(color: kGold, fontWeight: FontWeight.bold),
                      ),
                    ),
                    ...dayTasks.map((t) => Card(
                      color: context.surfaceColor,
                      child: ListTile(
                        dense: true,
                        leading: Icon(Icons.circle, color: _getStatusColor(t['status']), size: 12),
                        title: Text(t['service_requests']?['service_type'] ?? 'Operation', style: TextStyle(color: context.textColor, fontSize: 13, fontWeight: FontWeight.bold)),
                        subtitle: Text('${t['machines']?['machine_name']} | ${t['operator']?['fname']}', style: TextStyle(color: context.mutedTextColor, fontSize: 11)),
                      ),
                    )).toList(),
                    const SizedBox(height: 16),
                  ],
                );
              },
            ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Active': return Colors.green;
      case 'Completed': return Colors.grey;
      case 'Scheduled': return Colors.blue;
      default: return Colors.orange;
    }
  }
}
