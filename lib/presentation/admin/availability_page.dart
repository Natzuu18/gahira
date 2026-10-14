import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../domain/entities/availability_entity.dart';
import '../../infrastructure/repositories/supabase_availability_repository.dart';
import '../shared_widgets/appColor.dart';
import '../shared_widgets/adminDrawer.dart';
import '../shared_widgets/themeToggleButton.dart';
import 'approval_page.dart';

class AvailabilityPage extends StatefulWidget {
  const AvailabilityPage({super.key, this.embedInTab = false});

  final bool embedInTab;

  @override
  State<AvailabilityPage> createState() => _AvailabilityPageState();
}

class _AvailabilityPageState extends State<AvailabilityPage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final _repository = SupabaseAvailabilityRepository();
  
  List<AvailabilityEntity> _availabilities = [];
  List<PendingAccount> _pendingAccounts = [];
  bool _isLoading = true;

  DateTime _viewingMonth = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime? _selectedCalendarDate;

  @override
  void initState() {
    super.initState();
    _fetchAvailabilities();
  }

  Future<void> _fetchAvailabilities() async {
    setState(() => _isLoading = true);
    final result = await _repository.getAvailabilities();
    final approvalResult = await ApprovalService().fetchPendingAccounts();

    if (!mounted) return;

    result.fold(
      (failure) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching availabilities: ${failure.message}')),
        );
      },
      (list) {
        setState(() {
          _availabilities = list;
          _pendingAccounts = approvalResult.getOrElse(() => []);
          _isLoading = false;
        });
      },
    );
  }

  void _showAddDialog() {
    final Set<DateTime> selectedDates = {};
    DateTime dialogViewingMonth = DateTime(_viewingMonth.year, _viewingMonth.month);
    TimeOfDay? startTime;
    TimeOfDay? endTime;
    final TextEditingController addressController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final firstDay = DateTime(dialogViewingMonth.year, dialogViewingMonth.month, 1);
          final daysInMonth = DateTime(dialogViewingMonth.year, dialogViewingMonth.month + 1, 0).day;
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
                              dialogViewingMonth = DateTime(dialogViewingMonth.year, dialogViewingMonth.month - 1);
                            });
                          },
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            DropdownButtonHideUnderline(
                              child: DropdownButton<int>(
                                value: dialogViewingMonth.month,
                                dropdownColor: context.surfaceColor,
                                icon: const Icon(Icons.arrow_drop_down, color: kGold, size: 20),
                                style: TextStyle(
                                  color: context.textColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                                items: List.generate(12, (i) {
                                  final m = i + 1;
                                  return DropdownMenuItem<int>(
                                    value: m,
                                    child: Text(
                                      DateFormat('MMMM').format(DateTime(2025, m)),
                                      style: TextStyle(color: context.textColor, fontWeight: FontWeight.bold),
                                    ),
                                  );
                                }),
                                onChanged: (newMonth) {
                                  if (newMonth != null) {
                                    setDialogState(() {
                                      dialogViewingMonth = DateTime(dialogViewingMonth.year, newMonth);
                                    });
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 6),
                            DropdownButtonHideUnderline(
                              child: DropdownButton<int>(
                                value: dialogViewingMonth.year,
                                dropdownColor: context.surfaceColor,
                                icon: const Icon(Icons.arrow_drop_down, color: kGold, size: 20),
                                style: TextStyle(
                                  color: context.textColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                                items: List.generate(10, (i) {
                                  final y = DateTime.now().year - 2 + i;
                                  return DropdownMenuItem<int>(
                                    value: y,
                                    child: Text(
                                      y.toString(),
                                      style: TextStyle(color: context.textColor, fontWeight: FontWeight.bold),
                                    ),
                                  );
                                }),
                                onChanged: (newYear) {
                                  if (newYear != null) {
                                    setDialogState(() {
                                      dialogViewingMonth = DateTime(newYear, dialogViewingMonth.month);
                                    });
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.chevron_right, color: kGold),
                          onPressed: () {
                            setDialogState(() {
                              dialogViewingMonth = DateTime(dialogViewingMonth.year, dialogViewingMonth.month + 1);
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
                        final date = DateTime(dialogViewingMonth.year, dialogViewingMonth.month, day);
                        final now = DateTime.now();
                        final todayStart = DateTime(now.year, now.month, now.day);
                        final isPast = date.isBefore(todayStart);

                        final isSelected = selectedDates.any((d) =>
                            d.year == date.year &&
                            d.month == date.month &&
                            d.day == date.day);
                        final isToday = DateFormat('yyyy-MM-dd').format(now) ==
                            DateFormat('yyyy-MM-dd').format(date);

                        return InkWell(
                          onTap: isPast
                              ? null
                              : () {
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
                                  color: isPast
                                      ? context.mutedTextColor.withValues(alpha: 0.25)
                                      : (isSelected ? kBlack : context.textColor),
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
                                  const Text('Start Time', style: TextStyle(color: kGold, fontSize: 10, fontWeight: FontWeight.bold)),
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
                                  const Text('End Time', style: TextStyle(color: kGold, fontSize: 10, fontWeight: FontWeight.bold)),
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
                        labelText: 'Interview Address / Location',
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
                        '${selectedDates.length} date(s) selected',
                        style: const TextStyle(color: kGold, fontSize: 12, fontWeight: FontWeight.w600),
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
                      await _repository.addAvailability(entity);
                    }
                    _fetchAvailabilities();
                    if (mounted) Navigator.pop(context);
                  }
                },
                child: const Text('Save Slots', style: TextStyle(color: Colors.white)),
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
    DateTime dialogViewingMonth = DateTime(selectedDate.year, selectedDate.month);
    
    TimeOfDay startTime = _parseTimeOfDay(item.startTime);
    TimeOfDay endTime = _parseTimeOfDay(item.endTime);
    
    final TextEditingController addressController = TextEditingController(text: item.address);

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final firstDay = DateTime(dialogViewingMonth.year, dialogViewingMonth.month, 1);
          final daysInMonth = DateTime(dialogViewingMonth.year, dialogViewingMonth.month + 1, 0).day;
          final offset = firstDay.weekday % 7;

          return AlertDialog(
            backgroundColor: context.surfaceColor,
            title: Text(
              'Edit Availability Slot',
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
                              dialogViewingMonth = DateTime(dialogViewingMonth.year, dialogViewingMonth.month - 1);
                            });
                          },
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            DropdownButtonHideUnderline(
                              child: DropdownButton<int>(
                                value: dialogViewingMonth.month,
                                dropdownColor: context.surfaceColor,
                                icon: const Icon(Icons.arrow_drop_down, color: kGold, size: 20),
                                style: TextStyle(
                                  color: context.textColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                                items: List.generate(12, (i) {
                                  final m = i + 1;
                                  return DropdownMenuItem<int>(
                                    value: m,
                                    child: Text(
                                      DateFormat('MMMM').format(DateTime(2025, m)),
                                      style: TextStyle(color: context.textColor, fontWeight: FontWeight.bold),
                                    ),
                                  );
                                }),
                                onChanged: (newMonth) {
                                  if (newMonth != null) {
                                    setDialogState(() {
                                      dialogViewingMonth = DateTime(dialogViewingMonth.year, newMonth);
                                    });
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 6),
                            DropdownButtonHideUnderline(
                              child: DropdownButton<int>(
                                value: dialogViewingMonth.year,
                                dropdownColor: context.surfaceColor,
                                icon: const Icon(Icons.arrow_drop_down, color: kGold, size: 20),
                                style: TextStyle(
                                  color: context.textColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                                items: List.generate(10, (i) {
                                  final y = DateTime.now().year - 2 + i;
                                  return DropdownMenuItem<int>(
                                    value: y,
                                    child: Text(
                                      y.toString(),
                                      style: TextStyle(color: context.textColor, fontWeight: FontWeight.bold),
                                    ),
                                  );
                                }),
                                onChanged: (newYear) {
                                  if (newYear != null) {
                                    setDialogState(() {
                                      dialogViewingMonth = DateTime(newYear, dialogViewingMonth.month);
                                    });
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.chevron_right, color: kGold),
                          onPressed: () {
                            setDialogState(() {
                              dialogViewingMonth = DateTime(dialogViewingMonth.year, dialogViewingMonth.month + 1);
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
                        final date = DateTime(dialogViewingMonth.year, dialogViewingMonth.month, day);
                        final now = DateTime.now();
                        final todayStart = DateTime(now.year, now.month, now.day);
                        final isPast = date.isBefore(todayStart);

                        final isSelected = selectedDate.year == date.year &&
                            selectedDate.month == date.month &&
                            selectedDate.day == date.day;
                        final isToday = DateFormat('yyyy-MM-dd').format(now) ==
                            DateFormat('yyyy-MM-dd').format(date);

                        return InkWell(
                          onTap: isPast
                              ? null
                              : () {
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
                                  color: isPast
                                      ? context.mutedTextColor.withValues(alpha: 0.25)
                                      : (isSelected ? kBlack : context.textColor),
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
                                  const Text('Start Time', style: TextStyle(color: kGold, fontSize: 10, fontWeight: FontWeight.bold)),
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
                                  const Text('End Time', style: TextStyle(color: kGold, fontSize: 10, fontWeight: FontWeight.bold)),
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
                    await _repository.updateAvailability(updatedEntity);
                    _fetchAvailabilities();
                    if (mounted) Navigator.pop(context);
                  }
                },
                child: const Text('Update Slot', style: TextStyle(color: Colors.white)),
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
      try {
        final dt = DateFormat('HH:mm').parse(timeStr);
        return DateFormat('hh:mm a').format(dt);
      } catch (_) {
        return timeStr;
      }
    }
  }

  TimeOfDay _parseTimeOfDay(String timeStr) {
    final parts = timeStr.split(':');
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  Widget _buildAppointmentBanner(AvailabilityEntity item) {
    final dateStr = DateFormat('yyyy-MM-dd').format(item.date);
    final matchingApplicants = _pendingAccounts.where((acc) {
      if (acc.appointmentDate == null) return false;
      return DateFormat('yyyy-MM-dd').format(acc.appointmentDate!) == dateStr;
    }).toList();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kGold.withValues(alpha: 0.3), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner Top Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: kGold.withValues(alpha: 0.12),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
              border: Border(
                bottom: BorderSide(color: kGold.withValues(alpha: 0.2)),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.event_available_rounded, color: kGold, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      DateFormat('EEEE, MMMM d, yyyy').format(item.date),
                      style: TextStyle(
                        color: context.textColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: matchingApplicants.isNotEmpty
                        ? Colors.blue.withValues(alpha: 0.15)
                        : Colors.green.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: matchingApplicants.isNotEmpty
                          ? Colors.blue.withValues(alpha: 0.4)
                          : Colors.green.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Text(
                    matchingApplicants.isNotEmpty ? 'BOOKED' : 'OPEN SLOT',
                    style: TextStyle(
                      color: matchingApplicants.isNotEmpty ? Colors.blue : Colors.green,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Banner Content
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Interview Time Banner Row
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: kGold.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.access_time_filled_rounded, color: kGold, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'INTERVIEW TIME',
                          style: TextStyle(
                            color: kGold.withValues(alpha: 0.8),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                        Text(
                          '${_displayTime(item.startTime)} - ${_displayTime(item.endTime)}',
                          style: TextStyle(
                            color: context.textColor,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Location Row
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: kGold.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.location_on_rounded, color: kGold, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'INTERVIEW LOCATION',
                            style: TextStyle(
                              color: kGold.withValues(alpha: 0.8),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                            ),
                          ),
                          Text(
                            item.address,
                            style: TextStyle(
                              color: context.textColor,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Applicants Section / Sub-banner
                if (matchingApplicants.isNotEmpty) ...[
                  Text(
                    'BOOKED APPLICANTS FOR INTERVIEW',
                    style: TextStyle(
                      color: context.mutedTextColor,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...matchingApplicants.map((applicant) => Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: context.surfaceColor,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: kGold.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: kGold.withValues(alpha: 0.2),
                          child: Icon(
                            applicant.role == AccountRole.operator ? Icons.engineering : Icons.person,
                            color: kGold,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                applicant.fullName,
                                style: TextStyle(
                                  color: context.textColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                              Text(
                                '${applicant.role == AccountRole.operator ? "Operator Applicant" : "Miner Applicant"} • Phone: ${applicant.phoneNumber}',
                                style: TextStyle(
                                  color: context.mutedTextColor,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  )),
                ] else ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: kGold.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: kGold.withValues(alpha: 0.15)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, size: 16, color: kGold.withValues(alpha: 0.7)),
                        const SizedBox(width: 8),
                        Text(
                          'No applicants assigned to this interview slot yet.',
                          style: TextStyle(
                            color: context.mutedTextColor,
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 8),

                // Action Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      icon: const Icon(Icons.edit_outlined, size: 16, color: kGold),
                      label: const Text('Edit Slot', style: TextStyle(color: kGold, fontSize: 12)),
                      onPressed: () {
                        final index = _availabilities.indexOf(item);
                        if (index != -1) _showEditDialog(index);
                      },
                    ),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      icon: const Icon(Icons.delete_outline, size: 16, color: Colors.redAccent),
                      label: const Text('Delete', style: TextStyle(color: Colors.redAccent, fontSize: 12)),
                      onPressed: () async {
                        await _repository.deleteAvailability(item.availabilityId!);
                        _fetchAvailabilities();
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: context.bgColor,
        body: const Center(child: CircularProgressIndicator(color: kGold)),
      );
    }

    final currentYear = DateTime.now().year;
    final firstDay = DateTime(_viewingMonth.year, _viewingMonth.month, 1);
    final daysInMonth = DateTime(_viewingMonth.year, _viewingMonth.month + 1, 0).day;
    final offset = firstDay.weekday % 7;

    // Filter availabilities for chosen display
    final List<AvailabilityEntity> monthAvailabilities = _availabilities.where((a) {
      return a.date.year == _viewingMonth.year && a.date.month == _viewingMonth.month;
    }).toList();

    List<AvailabilityEntity> visibleAvailabilities = monthAvailabilities;
    if (_selectedCalendarDate != null) {
      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedCalendarDate!);
      visibleAvailabilities = _availabilities.where((a) {
        return DateFormat('yyyy-MM-dd').format(a.date) == dateStr;
      }).toList();
    }

    final bodyContent = SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Title
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Interview Appointments Schedule',
                style: TextStyle(
                  color: context.textColor,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Manage interview dates, times, and applicant appointments.',
                style: TextStyle(color: context.mutedTextColor, fontSize: 13),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Calendar Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.surfaceColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: kGold.withValues(alpha: 0.2)),
            ),
            child: Column(
              children: [
                // Month Navigation Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left, color: kGold),
                      onPressed: () {
                        setState(() {
                          _viewingMonth = DateTime(_viewingMonth.year, _viewingMonth.month - 1);
                          _selectedCalendarDate = null;
                        });
                      },
                    ),
                    Row(
                      children: [
                        DropdownButtonHideUnderline(
                          child: DropdownButton<int>(
                            value: _viewingMonth.month,
                            dropdownColor: context.surfaceColor,
                            icon: const Icon(Icons.arrow_drop_down, color: kGold, size: 20),
                            style: TextStyle(
                              color: context.textColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                            items: List.generate(12, (i) {
                              final m = i + 1;
                              return DropdownMenuItem<int>(
                                value: m,
                                child: Text(
                                  DateFormat('MMMM').format(DateTime(2025, m)),
                                  style: TextStyle(color: context.textColor, fontWeight: FontWeight.bold),
                                ),
                              );
                            }),
                            onChanged: (newMonth) {
                              if (newMonth != null) {
                                setState(() {
                                  _viewingMonth = DateTime(_viewingMonth.year, newMonth);
                                  _selectedCalendarDate = null;
                                });
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        DropdownButtonHideUnderline(
                          child: DropdownButton<int>(
                            value: _viewingMonth.year,
                            dropdownColor: context.surfaceColor,
                            icon: const Icon(Icons.arrow_drop_down, color: kGold, size: 20),
                            style: TextStyle(
                              color: context.textColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                            items: List.generate(10, (i) {
                              final y = currentYear - 2 + i;
                              return DropdownMenuItem<int>(
                                value: y,
                                child: Text(
                                  y.toString(),
                                  style: TextStyle(color: context.textColor, fontWeight: FontWeight.bold),
                                ),
                              );
                            }),
                            onChanged: (newYear) {
                              if (newYear != null) {
                                setState(() {
                                  _viewingMonth = DateTime(newYear, _viewingMonth.month);
                                  _selectedCalendarDate = null;
                                });
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right, color: kGold),
                      onPressed: () {
                        setState(() {
                          _viewingMonth = DateTime(_viewingMonth.year, _viewingMonth.month + 1);
                          _selectedCalendarDate = null;
                        });
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 12),

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
                                color: kGold.withValues(alpha: 0.6),
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ))
                      .toList(),
                ),

                const SizedBox(height: 8),

                // Month Grid
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7,
                    mainAxisSpacing: 6,
                    crossAxisSpacing: 6,
                  ),
                  itemCount: daysInMonth + offset,
                  itemBuilder: (context, index) {
                    if (index < offset) return const SizedBox.shrink();

                    final day = index - offset + 1;
                    final currentDate = DateTime(_viewingMonth.year, _viewingMonth.month, day);
                    final dateStr = DateFormat('yyyy-MM-dd').format(currentDate);

                    final daySlots = _availabilities.where((a) {
                      return DateFormat('yyyy-MM-dd').format(a.date) == dateStr;
                    }).toList();

                    final bool hasSlots = daySlots.isNotEmpty;
                    final bool isSelected = _selectedCalendarDate != null &&
                        DateFormat('yyyy-MM-dd').format(_selectedCalendarDate!) == dateStr;
                    final bool isToday = DateFormat('yyyy-MM-dd').format(DateTime.now()) == dateStr;

                    return InkWell(
                      onTap: () {
                        setState(() {
                          if (isSelected) {
                            _selectedCalendarDate = null;
                          } else {
                            _selectedCalendarDate = currentDate;
                          }
                        });
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        decoration: BoxDecoration(
                          color: isSelected
                              ? kGold
                              : (hasSlots
                                  ? kGold.withValues(alpha: 0.15)
                                  : Colors.transparent),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelected
                                ? kGold
                                : (isToday
                                    ? kGold
                                    : (hasSlots
                                        ? kGold.withValues(alpha: 0.4)
                                        : context.textColor.withValues(alpha: 0.08))),
                            width: isSelected || isToday ? 1.5 : 1,
                          ),
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Text(
                              day.toString(),
                              style: TextStyle(
                                color: isSelected
                                    ? kBlack
                                    : (hasSlots
                                        ? context.textColor
                                        : context.mutedTextColor.withValues(alpha: 0.3)),
                                fontWeight: (hasSlots || isToday || isSelected)
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                            if (hasSlots)
                              Positioned(
                                bottom: 4,
                                child: Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: isSelected ? kBlack : kGold,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Appointment Banners Section Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _selectedCalendarDate != null
                    ? 'APPOINTMENTS ON ${DateFormat('MMM d, yyyy').format(_selectedCalendarDate!).toUpperCase()}'
                    : 'ALL APPOINTMENTS IN ${DateFormat('MMMM yyyy').format(_viewingMonth).toUpperCase()}',
                style: const TextStyle(
                  color: kGold,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  letterSpacing: 1.1,
                ),
              ),
              if (_selectedCalendarDate != null)
                TextButton(
                  onPressed: () => setState(() => _selectedCalendarDate = null),
                  child: const Text('View All Month', style: TextStyle(color: kGold, fontSize: 12)),
                ),
            ],
          ),

          const SizedBox(height: 12),

          // Appointment Banners List
          if (visibleAvailabilities.isEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: context.surfaceColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: kGold.withValues(alpha: 0.1)),
              ),
              child: Column(
                children: [
                  Icon(Icons.event_busy_outlined, color: context.mutedTextColor, size: 36),
                  const SizedBox(height: 8),
                  Text(
                    _selectedCalendarDate != null
                        ? 'No interview slots scheduled for ${DateFormat('MMMM d, yyyy').format(_selectedCalendarDate!)}.'
                        : 'No interview slots scheduled for ${DateFormat('MMMM yyyy').format(_viewingMonth)}.',
                    style: TextStyle(color: context.mutedTextColor, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: _showAddDialog,
                    style: ElevatedButton.styleFrom(backgroundColor: kGold),
                    icon: const Icon(Icons.add_rounded, color: Colors.white, size: 16),
                    label: const Text('Add Interview Slot', style: TextStyle(color: Colors.white, fontSize: 12)),
                  ),
                ],
              ),
            ),
          ] else ...[
            ...visibleAvailabilities.map(_buildAppointmentBanner),
          ],

          const SizedBox(height: 80),
        ],
      ),
    );

    if (widget.embedInTab) {
      return Scaffold(
        backgroundColor: context.bgColor,
        body: bodyContent,
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _showAddDialog,
          backgroundColor: kGold,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Add Slot', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      );
    }

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: context.bgColor,
      appBar: AppBar(
        backgroundColor: context.surfaceColor,
        elevation: 0,
        title: const Text(
          'INTERVIEW SCHEDULE',
          style: TextStyle(
            color: kGold,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
            fontSize: 16,
          ),
        ),
        actions: [
          const ThemeToggleButton(),
          const SizedBox(width: 8),
        ],
      ),
      endDrawer: const AdminDrawer(currentMenu: AdminMenu.calendar),
      body: bodyContent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddDialog,
        backgroundColor: kGold,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Slot', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }
}
