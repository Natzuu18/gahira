import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../domain/entities/availability_entity.dart';
import '../../infrastructure/repositories/supabase_availability_repository.dart';
import '../shared_widgets/appColor.dart';
import '../shared_widgets/adminDrawer.dart';

class AvailabilityPage extends StatefulWidget {
  const AvailabilityPage({super.key});

  @override
  State<AvailabilityPage> createState() => _AvailabilityPageState();
}

class _AvailabilityPageState extends State<AvailabilityPage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final _repository = SupabaseAvailabilityRepository();
  List<AvailabilityEntity> _availabilities = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchAvailabilities();
  }

  Future<void> _fetchAvailabilities() async {
    setState(() => _isLoading = true);
    final result = await _repository.getAvailabilities();
    result.fold(
      (failure) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error fetching availabilities: ${failure.message}')),
          );
        }
      },
      (list) {
        setState(() {
          _availabilities = list;
          _isLoading = false;
        });
      },
    );
  }

  void _showAddDialog() {
    final Set<DateTime> selectedDates = {};
    DateTime viewingMonth = DateTime(DateTime.now().year, DateTime.now().month);
    TimeOfDay? startTime;
    TimeOfDay? endTime;
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
                    // Time Range Selection
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final TimeOfDay? picked = await showTimePicker(
                                context: context,
                                initialTime: startTime ?? TimeOfDay.now(),
                              );
                              if (picked != null) {
                                setDialogState(() {
                                  startTime = picked;
                                });
                              }
                            },
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                              decoration: BoxDecoration(
                                color: context.surfaceColor,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: kGold.withValues(alpha: 0.25)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Start', style: TextStyle(color: kGold, fontSize: 10, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 4),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        startTime == null
                                            ? '--:--'
                                            : startTime!.format(context),
                                        style: TextStyle(
                                          color: startTime == null
                                              ? context.mutedTextColor
                                              : context.textColor,
                                          fontSize: 13,
                                        ),
                                      ),
                                      const Icon(Icons.access_time_rounded, color: kGold, size: 16),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final TimeOfDay? picked = await showTimePicker(
                                context: context,
                                initialTime: endTime ?? TimeOfDay.now(),
                              );
                              if (picked != null) {
                                setDialogState(() {
                                  endTime = picked;
                                });
                              }
                            },
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                              decoration: BoxDecoration(
                                color: context.surfaceColor,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: kGold.withValues(alpha: 0.25)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('End', style: TextStyle(color: kGold, fontSize: 10, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 4),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        endTime == null
                                            ? '--:--'
                                            : endTime!.format(context),
                                        style: TextStyle(
                                          color: endTime == null
                                              ? context.mutedTextColor
                                              : context.textColor,
                                          fontSize: 13,
                                        ),
                                      ),
                                      const Icon(Icons.access_time_rounded, color: kGold, size: 16),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
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
                onPressed: () async {
                  if (selectedDates.isNotEmpty &&
                      startTime != null &&
                      endTime != null &&
                      addressController.text.isNotEmpty) {
                    final startStr = _formatTimeOfDay(startTime!);
                    final endStr = _formatTimeOfDay(endTime!);

                    for (var date in selectedDates) {
                      final entity = AvailabilityEntity(
                        date: date,
                        startTime: startStr,
                        endTime: endStr,
                        address: addressController.text,
                      );
                      final result = await _repository.addAvailability(entity);

                      if (mounted) {
                        result.fold(
                          (failure) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error: ${failure.message}'),
                                backgroundColor: Colors.redAccent,
                              ),
                            );
                          },
                          (saved) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Saved: ${DateFormat('yyyy-MM-dd').format(saved.date)} '
                                  '[${_displayTime(saved.startTime)} - ${_displayTime(saved.endTime)}] '
                                  'at ${saved.address} (Status: ${saved.status})',
                                ),
                                backgroundColor: Colors.green,
                              ),
                            );
                          },
                        );
                      }
                    }
                    _fetchAvailabilities();
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

  void _showEditDialog(int index) {
    final item = _availabilities[index];
    DateTime selectedDate = item.date;
    DateTime viewingMonth = DateTime(selectedDate.year, selectedDate.month);
    
    TimeOfDay startTime = _parseTimeOfDay(item.startTime);
    TimeOfDay endTime = _parseTimeOfDay(item.endTime);
    
    final TextEditingController addressController = TextEditingController(text: item.address);

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
              'Edit Availability',
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
                        final isSelected = selectedDate.year == date.year &&
                            selectedDate.month == date.month &&
                            selectedDate.day == date.day;
                        final isToday = DateFormat('yyyy-MM-dd').format(DateTime.now()) ==
                            DateFormat('yyyy-MM-dd').format(date);

                        return InkWell(
                          onTap: () {
                            setDialogState(() {
                              selectedDate = date;
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
                    // Time Range Selection
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final TimeOfDay? picked = await showTimePicker(
                                context: context,
                                initialTime: startTime,
                              );
                              if (picked != null) {
                                setDialogState(() {
                                  startTime = picked;
                                });
                              }
                            },
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                              decoration: BoxDecoration(
                                color: context.surfaceColor,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: kGold.withValues(alpha: 0.25)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Start', style: TextStyle(color: kGold, fontSize: 10, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 4),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        startTime.format(context),
                                        style: TextStyle(
                                          color: context.textColor,
                                          fontSize: 13,
                                        ),
                                      ),
                                      const Icon(Icons.access_time_rounded, color: kGold, size: 16),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final TimeOfDay? picked = await showTimePicker(
                                context: context,
                                initialTime: endTime,
                              );
                              if (picked != null) {
                                setDialogState(() {
                                  endTime = picked;
                                });
                              }
                            },
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                              decoration: BoxDecoration(
                                color: context.surfaceColor,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: kGold.withValues(alpha: 0.25)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('End', style: TextStyle(color: kGold, fontSize: 10, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 4),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        endTime.format(context),
                                        style: TextStyle(
                                          color: context.textColor,
                                          fontSize: 13,
                                        ),
                                      ),
                                      const Icon(Icons.access_time_rounded, color: kGold, size: 16),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
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
                onPressed: () async {
                  if (addressController.text.isNotEmpty) {
                    final updatedEntity = AvailabilityEntity(
                      availabilityId: item.availabilityId,
                      date: selectedDate,
                      startTime: _formatTimeOfDay(startTime),
                      endTime: _formatTimeOfDay(endTime),
                      address: addressController.text,
                      status: item.status,
                    );
                    final result =
                        await _repository.updateAvailability(updatedEntity);

                    if (mounted) {
                      result.fold(
                        (failure) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error: ${failure.message}'),
                              backgroundColor: Colors.redAccent,
                            ),
                          );
                        },
                        (saved) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Updated: ${DateFormat('yyyy-MM-dd').format(saved.date)} '
                                '[${_displayTime(saved.startTime)} - ${_displayTime(saved.endTime)}] '
                                '(Status: ${saved.status})',
                              ),
                              backgroundColor: Colors.green,
                            ),
                          );
                        },
                      );
                    }
                    _fetchAvailabilities();
                    Navigator.pop(context);
                  }
                },
                child:
                    const Text('Update', style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      ),
    );
  }

  String _formatTimeOfDay(TimeOfDay time) {
    final now = DateTime.now();
    final dt = DateTime(now.year, now.month, now.day, time.hour, time.minute);
    return DateFormat('HH:mm:ss').format(dt);
  }

  String _displayTime(String timeStr) {
    try {
      final dt = DateFormat('HH:mm:ss').parse(timeStr);
      return DateFormat('hh:mm a').format(dt);
    } catch (e) {
      return timeStr;
    }
  }

  TimeOfDay _parseTimeOfDay(String timeStr) {
    final parts = timeStr.split(':');
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
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
        adminName: 'Admin',
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: kGold))
        : Padding(
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
                          DateFormat('yyyy-MM-dd').format(item.date),
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
                            '${_displayTime(item.startTime)} - ${_displayTime(item.endTime)}',
                            style: const TextStyle(color: kGold, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    subtitle: Text(
                      item.address,
                      style: TextStyle(color: context.mutedTextColor),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, color: kGold),
                          onPressed: () => _showEditDialog(index),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                          onPressed: () async {
                            await _repository.deleteAvailability(item.availabilityId!);
                            _fetchAvailabilities();
                          },
                        ),
                      ],
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
