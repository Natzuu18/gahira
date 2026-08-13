import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../shared_widgets/appColor.dart';
import '../shared_widgets/adminDrawer.dart';

class AvailabilityPage extends StatefulWidget {
  const AvailabilityPage({super.key});

  @override
  State<AvailabilityPage> createState() => _AvailabilityPageState();
}

class _AvailabilityPageState extends State<AvailabilityPage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final List<Map<String, String>> _availabilities = [
    {'date': '2026-08-20', 'time': '09:00 AM', 'address': 'Main Office, 123 Street'},
    {'date': '2026-08-22', 'time': '02:00 PM', 'address': 'Branch A, 456 Avenue'},
  ];

  void _showAddDialog() {
    final Set<DateTime> selectedDates = {};
    DateTime viewingMonth = DateTime(DateTime.now().year, DateTime.now().month);
    TimeOfDay? selectedTime;
    final TextEditingController addressController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final firstDay = DateTime(viewingMonth.year, viewingMonth.month, 1);
          final daysInMonth = DateTime(viewingMonth.year, viewingMonth.month + 1, 0).day;
          final offset = firstDay.weekday % 7;

          return AlertDialog(
            backgroundColor: context.surfaceColor,
            title: Text(
              'Add Availabilities',
              style: TextStyle(color: context.textColor),
            ),
            content: SizedBox(
              width: 350,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Month Navigation
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.chevron_left, color: kGold),
                          onPressed: () {
                            setDialogState(() {
                              viewingMonth = DateTime(viewingMonth.year, viewingMonth.month - 1);
                            });
                          },
                        ),
                        Text(
                          DateFormat('MMMM yyyy').format(viewingMonth),
                          style: TextStyle(
                            color: context.textColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.chevron_right, color: kGold),
                          onPressed: () {
                            setDialogState(() {
                              viewingMonth = DateTime(viewingMonth.year, viewingMonth.month + 1);
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Days of week
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: ['S', 'M', 'T', 'W', 'T', 'F', 'S']
                          .map((d) => SizedBox(
                                width: 35,
                                child: Text(
                                  d,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: kGold.withValues(alpha: 0.5),
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ))
                          .toList(),
                    ),
                    const SizedBox(height: 8),
                    // Calendar Grid
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 7,
                        mainAxisSpacing: 4,
                        crossAxisSpacing: 4,
                      ),
                      itemCount: daysInMonth + offset,
                      itemBuilder: (context, index) {
                        if (index < offset) return const SizedBox.shrink();

                        final day = index - offset + 1;
                        final date = DateTime(viewingMonth.year, viewingMonth.month, day);
                        final isSelected = selectedDates.any((d) =>
                            d.year == date.year &&
                            d.month == date.month &&
                            d.day == date.day);
                        final isToday = DateFormat('yyyy-MM-dd').format(DateTime.now()) ==
                            DateFormat('yyyy-MM-dd').format(date);

                        return InkWell(
                          onTap: () {
                            setDialogState(() {
                              if (isSelected) {
                                selectedDates.removeWhere((d) =>
                                    d.year == date.year &&
                                    d.month == date.month &&
                                    d.day == date.day);
                              } else {
                                selectedDates.add(date);
                              }
                            });
                          },
                          borderRadius: BorderRadius.circular(4),
                          child: Container(
                            decoration: BoxDecoration(
                              color: isSelected ? kGold : Colors.transparent,
                              borderRadius: BorderRadius.circular(4),
                              border: isToday
                                  ? Border.all(color: kGold, width: 1)
                                  : null,
                            ),
                            child: Center(
                              child: Text(
                                day.toString(),
                                style: TextStyle(
                                  color: isSelected
                                      ? kBlack
                                      : context.textColor,
                                  fontWeight: isSelected || isToday
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    // Time Selection
                    InkWell(
                      onTap: () async {
                        final TimeOfDay? picked = await showTimePicker(
                          context: context,
                          initialTime: selectedTime ?? TimeOfDay.now(),
                        );
                        if (picked != null) {
                          setDialogState(() {
                            selectedTime = picked;
                          });
                        }
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                        decoration: BoxDecoration(
                          color: context.surfaceColor,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: kGold.withValues(alpha: 0.25)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              selectedTime == null
                                  ? 'Select Time'
                                  : selectedTime!.format(context),
                              style: TextStyle(
                                color: selectedTime == null
                                    ? context.mutedTextColor
                                    : context.textColor,
                              ),
                            ),
                            const Icon(Icons.access_time_rounded, color: kGold),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: addressController,
                      style: TextStyle(color: context.textColor),
                      decoration: InputDecoration(
                        labelText: 'Interview Address',
                        labelStyle: TextStyle(color: context.mutedTextColor),
                        enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: kGold.withValues(alpha: 0.5)),
                        ),
                        focusedBorder: const UnderlineInputBorder(
                          borderSide: BorderSide(color: kGold),
                        ),
                      ),
                    ),
                    if (selectedDates.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        '${selectedDates.length} dates selected',
                        style: TextStyle(color: kGold, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: kGold),
                onPressed: () {
                  if (selectedDates.isNotEmpty && 
                      selectedTime != null && 
                      addressController.text.isNotEmpty) {
                    setState(() {
                      final timeStr = selectedTime!.format(context);
                      for (var date in selectedDates) {
                        _availabilities.add({
                          'date': DateFormat('yyyy-MM-dd').format(date),
                          'time': timeStr,
                          'address': addressController.text,
                        });
                      }
                      // Sort by date then time
                      _availabilities.sort((a, b) {
                        int dateComp = a['date']!.compareTo(b['date']!);
                        if (dateComp != 0) return dateComp;
                        return a['time']!.compareTo(b['time']!);
                      });
                    });
                    Navigator.pop(context);
                  }
                },
                child: const Text('Save', style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
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
        title: const Text(
          'AVAILABILITY',
          style: TextStyle(
            color: kGold,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
            fontSize: 16,
          ),
        ),
        iconTheme: const IconThemeData(color: kGold),
        actions: [
          IconButton(
            icon: const Icon(Icons.menu_rounded, color: kGold),
            onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
          ),
        ],
      ),
      endDrawer: AdminDrawer(
        currentMenu: AdminMenu.availability,
        adminName: 'Admin', // In real app, get from auth state
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Manage Availability Dates',
              style: TextStyle(
                color: context.textColor,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Set dates and locations for operator interviews.',
              style: TextStyle(color: context.mutedTextColor),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: _availabilities.isEmpty
                  ? Center(
                child: Text(
                  'No availability dates set.',
                  style: TextStyle(color: context.mutedTextColor),
                ),
              )
                  : ListView.separated(
                itemCount: _availabilities.length,
                separatorBuilder: (context, index) => Divider(
                  color: kGold.withValues(alpha: 0.1),
                ),
                itemBuilder: (context, index) {
                  final item = _availabilities[index];
                  return ListTile(
                    contentPadding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    title: Row(
                      children: [
                        Text(
                          item['date']!,
                          style: TextStyle(
                            color: context.textColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: kGold.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            item['time'] ?? 'No time',
                            style: const TextStyle(color: kGold, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    subtitle: Text(
                      item['address']!,
                      style: TextStyle(color: context.mutedTextColor),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                      onPressed: () {
                        setState(() {
                          _availabilities.removeAt(index);
                        });
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDialog,
        backgroundColor: kGold,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
