import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../../core/config/env_config.dart';
import '../../domain/entities/availability_entity.dart';
import '../../infrastructure/repositories/supabase_availability_repository.dart';
import '../../infrastructure/supabase/supabase_config.dart';
import '../shared_widgets/appColor.dart';
import '../shared_widgets/adminDrawer.dart';
import '../shared_widgets/themeToggleButton.dart';
import 'approval_page.dart';

class AvailabilityPage extends StatefulWidget {
  const AvailabilityPage({
    super.key,
    this.embedInTab = false,
    this.showBackButton = false,
  });

  final bool embedInTab;
  final bool showBackButton;

  @override
  State<AvailabilityPage> createState() => _AvailabilityPageState();
}

class _AvailabilityPageState extends State<AvailabilityPage>
    with SingleTickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final _repository = SupabaseAvailabilityRepository();
  late final AnimationController _todayPulseController;

  List<AvailabilityEntity> _availabilities = [];
  List<PendingAccount> _pendingAccounts = [];
  bool _isLoading = true;

  Future<void> _sendSmsNotification(String phoneNumber, String message) async {
    final digits = phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');
    final recipient = digits.startsWith('63')
        ? digits
        : digits.startsWith('0')
        ? '63${digits.substring(1)}'
        : digits.startsWith('9')
        ? '63$digits'
        : digits;

    final response = await http.post(
      Uri.parse(EnvConfig.philsmsEndpoint),
      headers: {
        'Authorization': 'Bearer ${EnvConfig.philsmsApiKey.trim()}',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode({
        'recipient': recipient,
        'sender_id': EnvConfig.philsmsSenderId,
        'message': message,
      }),
    );

    if (response.statusCode >= 300) {
      throw StateError(
        'PhilSMS request failed (${response.statusCode}): ${response.body}',
      );
    }
  }

  DateTime _viewingMonth = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime? _selectedCalendarDate;

  @override
  void initState() {
    super.initState();
    _todayPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _fetchAvailabilities();
  }

  @override
  void dispose() {
    _todayPulseController.dispose();
    super.dispose();
  }

  Future<void> _fetchAvailabilities() async {
    setState(() => _isLoading = true);
    final result = await _repository.getAvailabilities();
    final approvalResult = await ApprovalService().fetchPendingAccounts();

    if (!mounted) return;

    result.fold(
      (failure) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error fetching availabilities: ${failure.message}'),
          ),
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
    DateTime dialogViewingMonth = DateTime(
      _viewingMonth.year,
      _viewingMonth.month,
    );
    TimeOfDay? startTime;
    TimeOfDay? endTime;
    final TextEditingController addressController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final firstDay = DateTime(
            dialogViewingMonth.year,
            dialogViewingMonth.month,
            1,
          );
          final daysInMonth = DateTime(
            dialogViewingMonth.year,
            dialogViewingMonth.month + 1,
            0,
          ).day;
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
                              dialogViewingMonth = DateTime(
                                dialogViewingMonth.year,
                                dialogViewingMonth.month - 1,
                              );
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
                                icon: const Icon(
                                  Icons.arrow_drop_down,
                                  color: kGold,
                                  size: 20,
                                ),
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
                                      DateFormat(
                                        'MMMM',
                                      ).format(DateTime(2025, m)),
                                      style: TextStyle(
                                        color: context.textColor,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  );
                                }),
                                onChanged: (newMonth) {
                                  if (newMonth != null) {
                                    setDialogState(() {
                                      dialogViewingMonth = DateTime(
                                        dialogViewingMonth.year,
                                        newMonth,
                                      );
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
                                icon: const Icon(
                                  Icons.arrow_drop_down,
                                  color: kGold,
                                  size: 20,
                                ),
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
                                      style: TextStyle(
                                        color: context.textColor,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  );
                                }),
                                onChanged: (newYear) {
                                  if (newYear != null) {
                                    setDialogState(() {
                                      dialogViewingMonth = DateTime(
                                        newYear,
                                        dialogViewingMonth.month,
                                      );
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
                              dialogViewingMonth = DateTime(
                                dialogViewingMonth.year,
                                dialogViewingMonth.month + 1,
                              );
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
                          .map(
                            (d) => SizedBox(
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
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 8),
                    // Calendar Grid
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 7,
                            mainAxisSpacing: 4,
                            crossAxisSpacing: 4,
                          ),
                      itemCount: daysInMonth + offset,
                      itemBuilder: (context, index) {
                        if (index < offset) return const SizedBox.shrink();

                        final day = index - offset + 1;
                        final date = DateTime(
                          dialogViewingMonth.year,
                          dialogViewingMonth.month,
                          day,
                        );
                        final now = DateTime.now();
                        final todayStart = DateTime(
                          now.year,
                          now.month,
                          now.day,
                        );
                        final isPast = date.isBefore(todayStart);

                        final isSelected = selectedDates.any(
                          (d) =>
                              d.year == date.year &&
                              d.month == date.month &&
                              d.day == date.day,
                        );
                        final isToday =
                            DateFormat('yyyy-MM-dd').format(now) ==
                            DateFormat('yyyy-MM-dd').format(date);

                        return InkWell(
                          onTap: isPast
                              ? null
                              : () {
                                  setDialogState(() {
                                    if (isSelected) {
                                      selectedDates.removeWhere(
                                        (d) =>
                                            d.year == date.year &&
                                            d.month == date.month &&
                                            d.day == date.day,
                                      );
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
                                      ? context.mutedTextColor.withValues(
                                          alpha: 0.25,
                                        )
                                      : (isSelected
                                            ? kBlack
                                            : context.textColor),
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
                              padding: const EdgeInsets.symmetric(
                                vertical: 12,
                                horizontal: 12,
                              ),
                              decoration: BoxDecoration(
                                color: context.surfaceColor,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: kGold.withValues(alpha: 0.25),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Start Time',
                                    style: TextStyle(
                                      color: kGold,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
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
                                      const Icon(
                                        Icons.access_time_rounded,
                                        color: kGold,
                                        size: 16,
                                      ),
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
                              padding: const EdgeInsets.symmetric(
                                vertical: 12,
                                horizontal: 12,
                              ),
                              decoration: BoxDecoration(
                                color: context.surfaceColor,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: kGold.withValues(alpha: 0.25),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'End Time',
                                    style: TextStyle(
                                      color: kGold,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
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
                                      const Icon(
                                        Icons.access_time_rounded,
                                        color: kGold,
                                        size: 16,
                                      ),
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
                          borderSide: BorderSide(
                            color: kGold.withValues(alpha: 0.5),
                          ),
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
                        style: const TextStyle(
                          color: kGold,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Colors.grey),
                ),
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
                child: const Text(
                  'Save Slots',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showEditTimeDialog(int index) {
    final item = _availabilities[index];
    TimeOfDay startTime = _parseTimeOfDay(item.startTime);
    TimeOfDay endTime = _parseTimeOfDay(item.endTime);
    bool sendSms = true;
    bool isSubmitting = false;

    final dateStr = DateFormat('yyyy-MM-dd').format(item.date);
    final itemAvailabilityId = item.availabilityId;

    // Find applicants booked for this specific slot
    final matchingApplicants = _pendingAccounts.where((acc) {
      if (itemAvailabilityId != null && acc.availabilityId != null) {
        if (acc.availabilityId == itemAvailabilityId) return true;
      }
      if (acc.availabilityId == null && acc.appointmentDate != null) {
        return DateFormat('yyyy-MM-dd').format(acc.appointmentDate!) == dateStr;
      }
      return false;
    }).toList();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (ctx, setModalState) {
          return AlertDialog(
            backgroundColor: ctx.surfaceColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Row(
              children: [
                Icon(Icons.access_time_rounded, color: kGold),
                SizedBox(width: 8),
                Text(
                  'Edit Schedule Time',
                  style: TextStyle(
                    color: kGold,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: kGold.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: kGold.withValues(alpha: 0.25)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.event_rounded,
                              color: kGold,
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              DateFormat(
                                'EEEE, MMMM d, yyyy',
                              ).format(item.date),
                              style: TextStyle(
                                color: ctx.textColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(
                              Icons.location_on_rounded,
                              color: kGold,
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                item.address,
                                style: TextStyle(
                                  color: ctx.mutedTextColor,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Interview Time Range',
                    style: TextStyle(
                      color: kGold,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final TimeOfDay? picked = await showTimePicker(
                              context: ctx,
                              initialTime: startTime,
                            );
                            if (picked != null)
                              setModalState(() => startTime = picked);
                          },
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: ctx.bgColor,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: kGold.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Start Time',
                                  style: TextStyle(
                                    color: kGold,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  startTime.format(ctx),
                                  style: TextStyle(
                                    color: ctx.textColor,
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
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
                              context: ctx,
                              initialTime: endTime,
                            );
                            if (picked != null)
                              setModalState(() => endTime = picked);
                          },
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: ctx.bgColor,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: kGold.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'End Time',
                                  style: TextStyle(
                                    color: kGold,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  endTime.format(ctx),
                                  style: TextStyle(
                                    color: ctx.textColor,
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (matchingApplicants.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.blue.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.people_alt_rounded,
                                color: Colors.blue,
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '${matchingApplicants.length} Applicant(s) Booked for this Slot',
                                style: const TextStyle(
                                  color: Colors.blue,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11.5,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          ...matchingApplicants.map(
                            (a) => Text(
                              '• ${a.fullName} (${a.phoneNumber})',
                              style: TextStyle(
                                color: ctx.textColor,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'Send time update SMS to booked applicants',
                        style: TextStyle(fontSize: 12),
                      ),
                      value: sendSms,
                      activeColor: kGold,
                      onChanged: (val) =>
                          setModalState(() => sendSms = val ?? true),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: kGold,
                  foregroundColor: kBlack,
                ),
                onPressed: isSubmitting
                    ? null
                    : () async {
                        setModalState(() => isSubmitting = true);
                        try {
                          final updatedEntity = AvailabilityEntity(
                            availabilityId: item.availabilityId,
                            date: item.date,
                            startTime: _formatTimeOfDay(startTime),
                            endTime: _formatTimeOfDay(endTime),
                            address: item.address,
                            status: item.status,
                          );
                          await _repository.updateAvailability(updatedEntity);

                          int smsSentCount = 0;
                          if (sendSms && matchingApplicants.isNotEmpty) {
                            final formattedStart = startTime.format(ctx);
                            final formattedEnd = endTime.format(ctx);
                            final formattedDate = DateFormat(
                              'MMMM d, yyyy',
                            ).format(item.date);

                            for (var app in matchingApplicants) {
                              final smsMsg =
                                  'Gahira: Hello ${app.fullName}! Your interview schedule time on $formattedDate has been updated to $formattedStart - $formattedEnd. Location: ${item.address}. Thank you!';
                              await _sendSmsNotification(
                                app.phoneNumber,
                                smsMsg,
                              );
                              smsSentCount++;
                            }
                          }

                          if (mounted) {
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Interview time updated. ${smsSentCount > 0 ? "$smsSentCount SMS notification(s) sent." : ""}',
                                ),
                                backgroundColor: Colors.green,
                              ),
                            );
                            _fetchAvailabilities();
                          }
                        } catch (e) {
                          setModalState(() => isSubmitting = false);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error updating schedule: $e'),
                                backgroundColor: Colors.redAccent,
                              ),
                            );
                          }
                        }
                      },
                child: isSubmitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          color: kBlack,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'Save Time',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showCancelScheduleDialog(
    AvailabilityEntity item,
    List<PendingAccount> matchingApplicants,
  ) {
    final reasonController = TextEditingController();
    AvailabilityEntity? selectedRescheduleSlot;
    bool shouldRescheduleApplicants = false;
    bool createNewRescheduleSlot = false;
    DateTime? rescheduleDate;
    TimeOfDay rescheduleStartTime = const TimeOfDay(hour: 9, minute: 0);
    TimeOfDay rescheduleEndTime = const TimeOfDay(hour: 10, minute: 0);
    bool sendSmsNotification = true;
    bool isSubmitting = false;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final futureOpenSlots = _availabilities.where((a) {
      final aDate = DateTime(a.date.year, a.date.month, a.date.day);
      return a.availabilityId != item.availabilityId &&
          aDate.isAfter(today) &&
          a.status.toLowerCase() == 'open';
    }).toList();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (ctx, setModalState) {
          return AlertDialog(
            backgroundColor: ctx.surfaceColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Row(
              children: [
                Icon(Icons.event_busy_rounded, color: Colors.redAccent),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Cancel Schedule',
                    style: TextStyle(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Schedule: ${DateFormat('EEEE, MMMM d, yyyy').format(item.date)} (${_displayTime(item.startTime)} - ${_displayTime(item.endTime)})',
                    style: TextStyle(
                      color: ctx.textColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 16),

                  Text(
                    'Reason for Cancellation *',
                    style: TextStyle(
                      color: kGold,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: reasonController,
                    maxLines: 2,
                    style: TextStyle(color: ctx.textColor, fontSize: 13),
                    decoration: InputDecoration(
                      hintText:
                          'e.g. Facility maintenance, emergency closure...',
                      filled: true,
                      fillColor: ctx.bgColor,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  if (matchingApplicants.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Colors.orange.withOpacity(0.3),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.warning_amber_rounded,
                                color: Colors.orange,
                                size: 18,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  '${matchingApplicants.length} Applicant(s) Booked',
                                  style: const TextStyle(
                                    color: Colors.orange,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          ...matchingApplicants.map(
                            (a) => Text(
                              '• ${a.fullName} (${a.phoneNumber})',
                              style: TextStyle(
                                color: ctx.textColor,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    Text(
                      'Reschedule Applicants To (Optional)',
                      style: TextStyle(
                        color: kGold,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'Reschedule these applicants',
                        style: TextStyle(fontSize: 12),
                      ),
                      value: shouldRescheduleApplicants,
                      activeColor: kGold,
                      onChanged: (value) {
                        setModalState(() {
                          shouldRescheduleApplicants = value ?? false;
                          if (!shouldRescheduleApplicants) {
                            selectedRescheduleSlot = null;
                          } else if (futureOpenSlots.isEmpty) {
                            createNewRescheduleSlot = true;
                          }
                        });
                      },
                    ),
                    if (shouldRescheduleApplicants) ...[
                      if (futureOpenSlots.isNotEmpty)
                        Wrap(
                          spacing: 8,
                          children: [
                            ChoiceChip(
                              label: const Text('Existing slot'),
                              selected: !createNewRescheduleSlot,
                              onSelected: (selected) {
                                if (selected) {
                                  setModalState(() {
                                    createNewRescheduleSlot = false;
                                    rescheduleDate = null;
                                  });
                                }
                              },
                            ),
                            ChoiceChip(
                              label: const Text('New date/time'),
                              selected: createNewRescheduleSlot,
                              onSelected: (selected) {
                                if (selected) {
                                  setModalState(() {
                                    createNewRescheduleSlot = true;
                                    selectedRescheduleSlot = null;
                                  });
                                }
                              },
                            ),
                          ],
                        ),
                      if (!createNewRescheduleSlot) ...[
                        const SizedBox(height: 8),
                        DropdownButtonFormField<AvailabilityEntity>(
                          value: selectedRescheduleSlot,
                          dropdownColor: ctx.surfaceColor,
                          style: TextStyle(color: ctx.textColor, fontSize: 12),
                          decoration: InputDecoration(
                            hintText: 'Select an open slot',
                            filled: true,
                            fillColor: ctx.bgColor,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          items: futureOpenSlots.map((slot) {
                            return DropdownMenuItem(
                              value: slot,
                              child: Text(
                                '${DateFormat('MMM d, yyyy').format(slot.date)} (${_displayTime(slot.startTime)})',
                                style: TextStyle(
                                  color: ctx.textColor,
                                  fontSize: 12,
                                ),
                              ),
                            );
                          }).toList(),
                          onChanged: (slot) {
                            setModalState(() => selectedRescheduleSlot = slot);
                          },
                        ),
                      ] else ...[
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.calendar_month, size: 18),
                          label: Text(
                            rescheduleDate == null
                                ? 'Choose appointment date'
                                : DateFormat(
                                    'EEEE, MMMM d, yyyy',
                                  ).format(rescheduleDate!),
                          ),
                          onPressed: () async {
                            final now = DateTime.now();
                            final today = DateTime(
                              now.year,
                              now.month,
                              now.day,
                            );
                            final picked = await showDatePicker(
                              context: ctx,
                              initialDate: rescheduleDate ?? today,
                              firstDate: today,
                              lastDate: DateTime(now.year + 10),
                            );
                            if (picked != null) {
                              setModalState(() => rescheduleDate = picked);
                            }
                          },
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                icon: const Icon(Icons.access_time, size: 18),
                                label: Text(
                                  'Start ${rescheduleStartTime.format(ctx)}',
                                ),
                                onPressed: () async {
                                  final picked = await showTimePicker(
                                    context: ctx,
                                    initialTime: rescheduleStartTime,
                                  );
                                  if (picked != null) {
                                    setModalState(
                                      () => rescheduleStartTime = picked,
                                    );
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton.icon(
                                icon: const Icon(Icons.access_time, size: 18),
                                label: Text(
                                  'End ${rescheduleEndTime.format(ctx)}',
                                ),
                                onPressed: () async {
                                  final picked = await showTimePicker(
                                    context: ctx,
                                    initialTime: rescheduleEndTime,
                                  );
                                  if (picked != null) {
                                    setModalState(
                                      () => rescheduleEndTime = picked,
                                    );
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 12),
                    ],

                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'Send SMS notification to applicants via PhilSMS',
                        style: TextStyle(fontSize: 12),
                      ),
                      value: sendSmsNotification,
                      activeColor: kGold,
                      onChanged: (val) => setModalState(
                        () => sendSmsNotification = val ?? true,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
                child: const Text(
                  'Close',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: isSubmitting
                    ? null
                    : () async {
                        final reasonText = reasonController.text.trim();
                        if (reasonText.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Please enter a cancellation reason.',
                              ),
                            ),
                          );
                          return;
                        }

                        if (shouldRescheduleApplicants) {
                          if (createNewRescheduleSlot) {
                            if (rescheduleDate == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Please choose a new appointment date.',
                                  ),
                                ),
                              );
                              return;
                            }

                            final startMinutes =
                                rescheduleStartTime.hour * 60 +
                                rescheduleStartTime.minute;
                            final endMinutes =
                                rescheduleEndTime.hour * 60 +
                                rescheduleEndTime.minute;
                            final selectedDateTime = DateTime(
                              rescheduleDate!.year,
                              rescheduleDate!.month,
                              rescheduleDate!.day,
                              rescheduleStartTime.hour,
                              rescheduleStartTime.minute,
                            );
                            if (endMinutes <= startMinutes) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'The end time must be after the start time.',
                                  ),
                                ),
                              );
                              return;
                            }
                            if (!selectedDateTime.isAfter(DateTime.now())) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Please choose a future appointment time.',
                                  ),
                                ),
                              );
                              return;
                            }
                          } else if (selectedRescheduleSlot == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Please select an existing slot or choose a new date and time.',
                                ),
                              ),
                            );
                            return;
                          }
                        }

                        setModalState(() => isSubmitting = true);

                        try {
                          AvailabilityEntity? destinationSlot =
                              selectedRescheduleSlot;
                          if (shouldRescheduleApplicants &&
                              createNewRescheduleSlot) {
                            final result = await _repository.addAvailability(
                              AvailabilityEntity(
                                date: rescheduleDate!,
                                startTime: _formatTimeOfDay(
                                  rescheduleStartTime,
                                ),
                                endTime: _formatTimeOfDay(rescheduleEndTime),
                                address: item.address,
                              ),
                            );
                            final createdSlot = result.fold(
                              (failure) => throw StateError(failure.message),
                              (slot) => slot,
                            );
                            if (createdSlot.availabilityId == null) {
                              throw StateError(
                                'The new appointment slot was created without an ID.',
                              );
                            }
                            destinationSlot = createdSlot;
                          }

                          if (shouldRescheduleApplicants &&
                              destinationSlot != null) {
                            await SupabaseConfig.client
                                .from('applications')
                                .update({
                                  'appointment_date': DateFormat(
                                    'yyyy-MM-dd',
                                  ).format(destinationSlot.date),
                                  'availability_id':
                                      destinationSlot.availabilityId,
                                })
                                .inFilter(
                                  'application_id',
                                  matchingApplicants
                                      .map((app) => app.applicationId)
                                      .toList(),
                                );
                          }

                          final updatedSlot = AvailabilityEntity(
                            availabilityId: item.availabilityId,
                            date: item.date,
                            startTime: item.startTime,
                            endTime: item.endTime,
                            address: item.address,
                            status: 'cancelled',
                          );
                          final updateResult = await _repository
                              .updateAvailability(updatedSlot);
                          updateResult.fold(
                            (failure) => throw StateError(failure.message),
                            (_) {},
                          );

                          int smsCount = 0;
                          if (sendSmsNotification &&
                              matchingApplicants.isNotEmpty) {
                            String reschedInfo =
                                shouldRescheduleApplicants &&
                                    destinationSlot != null
                                ? 'Your interview has been rescheduled to ${DateFormat('MMMM d, yyyy').format(destinationSlot.date)} (${_displayTime(destinationSlot.startTime)} - ${_displayTime(destinationSlot.endTime)}).'
                                : 'Please log in to your portal to select a new interview slot.';

                            for (var app in matchingApplicants) {
                              final smsMsg =
                                  'Gahira: Your scheduled interview on ${DateFormat('yyyy-MM-dd').format(item.date)} was cancelled. Reason: $reasonText. $reschedInfo';
                              await _sendSmsNotification(
                                app.phoneNumber,
                                smsMsg,
                              );
                              smsCount++;
                            }
                          }

                          if (mounted) {
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Schedule cancelled. ${smsCount > 0 ? "$smsCount SMS notification(s) sent." : ""}',
                                ),
                                backgroundColor: Colors.green,
                              ),
                            );
                            _fetchAvailabilities();
                          }
                        } catch (e) {
                          setModalState(() => isSubmitting = false);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Cancellation error: $e'),
                                backgroundColor: Colors.redAccent,
                              ),
                            );
                          }
                        }
                      },
                child: isSubmitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'Confirm Cancellation',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
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

  Widget _buildCalendarLegend() {
    Widget legendItem(Color color, String label) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(color: context.mutedTextColor, fontSize: 11),
        ),
      ],
    );

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 18,
        runSpacing: 8,
        children: [
          legendItem(Colors.green, 'Past appointment'),
          legendItem(Colors.redAccent, 'Cancelled'),
          legendItem(Colors.amber, 'Today'),
        ],
      ),
    );
  }

  Widget _buildAppointmentBanner(AvailabilityEntity item) {
    final dateStr = DateFormat('yyyy-MM-dd').format(item.date);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final itemDate = DateTime(item.date.year, item.date.month, item.date.day);
    final bool isPassed = itemDate.isBefore(today);
    final bool isToday = itemDate.isAtSameMomentAs(today);
    final bool isCancelled = item.status?.toLowerCase() == 'cancelled';
    final bool isUpcoming = !isPassed && !isToday && !isCancelled;
    final Color statusColor = isCancelled
        ? Colors.redAccent
        : isPassed
        ? Colors.green
        : Colors.amber;

    final itemAvailabilityId = item.availabilityId;

    final matchingApplicants = _pendingAccounts.where((acc) {
      if (itemAvailabilityId != null && acc.availabilityId != null) {
        if (acc.availabilityId == itemAvailabilityId) return true;
      }
      if (acc.availabilityId == null && acc.appointmentDate != null) {
        return DateFormat('yyyy-MM-dd').format(acc.appointmentDate!) == dateStr;
      }
      return false;
    }).toList();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: statusColor.withValues(
            alpha: isToday && !isCancelled ? 0.8 : 0.55,
          ),
          width: isToday ? 1.6 : 1.2,
        ),
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
          AnimatedBuilder(
            animation: _todayPulseController,
            builder: (context, child) {
              final pulse = _todayPulseController.value;
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(
                    alpha: isToday && !isCancelled ? 0.12 + pulse * 0.25 : 0.12,
                  ),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(15),
                  ),
                  border: Border(
                    bottom: BorderSide(
                      color: statusColor.withValues(alpha: 0.4),
                    ),
                  ),
                ),
                child: child,
              );
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.event_available_rounded,
                      color: statusColor,
                      size: 20,
                    ),
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: statusColor.withValues(alpha: 0.55),
                    ),
                  ),
                  child: Text(
                    isCancelled
                        ? 'CANCELLED'
                        : isPassed
                        ? 'PASSED'
                        : isToday
                        ? 'TODAY'
                        : matchingApplicants.isNotEmpty
                        ? 'BOOKED'
                        : 'OPEN SLOT',
                    style: TextStyle(
                      color: statusColor,
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
                      child: const Icon(
                        Icons.access_time_filled_rounded,
                        color: kGold,
                        size: 18,
                      ),
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
                      child: const Icon(
                        Icons.location_on_rounded,
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
                  ...matchingApplicants.map(
                    (applicant) => Container(
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
                              applicant.role == AccountRole.operator
                                  ? Icons.engineering
                                  : Icons.person,
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
                    ),
                  ),
                ] else ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: kGold.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: kGold.withValues(alpha: 0.15)),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 16,
                          color: kGold.withValues(alpha: 0.7),
                        ),
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
                    if (isUpcoming) ...[
                      TextButton.icon(
                        icon: const Icon(
                          Icons.access_time_rounded,
                          size: 16,
                          color: kGold,
                        ),
                        label: const Text(
                          'Edit Time',
                          style: TextStyle(color: kGold, fontSize: 12),
                        ),
                        onPressed: () {
                          final index = _availabilities.indexOf(item);
                          if (index != -1) _showEditTimeDialog(index);
                        },
                      ),
                      const SizedBox(width: 8),
                      TextButton.icon(
                        icon: const Icon(
                          Icons.event_busy_rounded,
                          size: 16,
                          color: Colors.redAccent,
                        ),
                        label: const Text(
                          'Cancel Schedule',
                          style: TextStyle(
                            color: Colors.redAccent,
                            fontSize: 12,
                          ),
                        ),
                        onPressed: () =>
                            _showCancelScheduleDialog(item, matchingApplicants),
                      ),
                    ] else ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: Colors.grey.withValues(alpha: 0.3),
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.lock_outline_rounded,
                              size: 14,
                              color: Colors.grey,
                            ),
                            SizedBox(width: 6),
                            Text(
                              'Locked (Current Date / Passed)',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
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
    final daysInMonth = DateTime(
      _viewingMonth.year,
      _viewingMonth.month + 1,
      0,
    ).day;
    final offset = firstDay.weekday % 7;

    // Filter availabilities for chosen display
    final List<AvailabilityEntity> monthAvailabilities = _availabilities.where((
      a,
    ) {
      return a.date.year == _viewingMonth.year &&
          a.date.month == _viewingMonth.month;
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
                          _viewingMonth = DateTime(
                            _viewingMonth.year,
                            _viewingMonth.month - 1,
                          );
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
                            icon: const Icon(
                              Icons.arrow_drop_down,
                              color: kGold,
                              size: 20,
                            ),
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
                                  style: TextStyle(
                                    color: context.textColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              );
                            }),
                            onChanged: (newMonth) {
                              if (newMonth != null) {
                                setState(() {
                                  _viewingMonth = DateTime(
                                    _viewingMonth.year,
                                    newMonth,
                                  );
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
                            icon: const Icon(
                              Icons.arrow_drop_down,
                              color: kGold,
                              size: 20,
                            ),
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
                                  style: TextStyle(
                                    color: context.textColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              );
                            }),
                            onChanged: (newYear) {
                              if (newYear != null) {
                                setState(() {
                                  _viewingMonth = DateTime(
                                    newYear,
                                    _viewingMonth.month,
                                  );
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
                          _viewingMonth = DateTime(
                            _viewingMonth.year,
                            _viewingMonth.month + 1,
                          );
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
                      .map(
                        (d) => SizedBox(
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
                        ),
                      )
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
                    final currentDate = DateTime(
                      _viewingMonth.year,
                      _viewingMonth.month,
                      day,
                    );
                    final dateStr = DateFormat(
                      'yyyy-MM-dd',
                    ).format(currentDate);

                    final daySlots = _availabilities.where((a) {
                      return DateFormat('yyyy-MM-dd').format(a.date) == dateStr;
                    }).toList();

                    final bool hasSlots = daySlots.isNotEmpty;
                    final bool isSelected =
                        _selectedCalendarDate != null &&
                        DateFormat(
                              'yyyy-MM-dd',
                            ).format(_selectedCalendarDate!) ==
                            dateStr;
                    final bool isToday =
                        DateFormat('yyyy-MM-dd').format(DateTime.now()) ==
                        dateStr;
                    final bool isCancelled =
                        hasSlots &&
                        daySlots.any(
                          (slot) => slot.status.toLowerCase() == 'cancelled',
                        );
                    final bool isPassed = currentDate.isBefore(
                      DateTime(
                        DateTime.now().year,
                        DateTime.now().month,
                        DateTime.now().day,
                      ),
                    );
                    final Color dateColor = isCancelled
                        ? Colors.redAccent
                        : isPassed
                        ? Colors.green
                        : kGold;

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
                      child: AnimatedBuilder(
                        animation: _todayPulseController,
                        builder: (context, child) {
                          final pulse = _todayPulseController.value;
                          return Container(
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? dateColor
                                  : isToday
                                  ? dateColor.withValues(
                                      alpha: 0.12 + pulse * 0.3,
                                    )
                                  : hasSlots
                                  ? dateColor.withValues(alpha: 0.15)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isSelected || isToday
                                    ? dateColor.withValues(
                                        alpha: isToday && !isCancelled
                                            ? 0.55 + pulse * 0.45
                                            : 1,
                                      )
                                    : hasSlots
                                    ? dateColor.withValues(alpha: 0.65)
                                    : context.textColor.withValues(alpha: 0.08),
                                width: isSelected || isToday ? 1.5 : 1,
                              ),
                            ),
                            child: child,
                          );
                        },
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Text(
                              day.toString(),
                              style: TextStyle(
                                color: isSelected
                                    ? kBlack
                                    : (hasSlots || isToday
                                          ? context.textColor
                                          : context.mutedTextColor.withValues(
                                              alpha: 0.3,
                                            )),
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
                                    color: isSelected ? kBlack : dateColor,
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

          _buildCalendarLegend(),
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
                  child: const Text(
                    'View All Month',
                    style: TextStyle(color: kGold, fontSize: 12),
                  ),
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
                  Icon(
                    Icons.event_busy_outlined,
                    color: context.mutedTextColor,
                    size: 36,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _selectedCalendarDate != null
                        ? 'No interview slots scheduled for ${DateFormat('MMMM d, yyyy').format(_selectedCalendarDate!)}.'
                        : 'No interview slots scheduled for ${DateFormat('MMMM yyyy').format(_viewingMonth)}.',
                    style: TextStyle(
                      color: context.mutedTextColor,
                      fontSize: 13,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: _showAddDialog,
                    style: ElevatedButton.styleFrom(backgroundColor: kGold),
                    icon: const Icon(
                      Icons.add_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                    label: const Text(
                      'Add Interview Slot',
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ),
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
        appBar: widget.showBackButton
            ? AppBar(
                backgroundColor: context.surfaceColor,
                elevation: 0,
                automaticallyImplyLeading: false,
                leading: IconButton(
                  tooltip: 'Back to dashboard',
                  icon: const Icon(Icons.arrow_back_rounded, color: kGold),
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
                title: const Text(
                  'APPOINTMENT CALENDAR',
                  style: TextStyle(
                    color: kGold,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                    fontSize: 15,
                  ),
                ),
                actions: [const ThemeToggleButton(), const SizedBox(width: 8)],
              )
            : null,
        body: bodyContent,
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _showAddDialog,
          backgroundColor: kGold,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add_rounded),
          label: const Text(
            'Add Slot',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
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
        actions: [const ThemeToggleButton(), const SizedBox(width: 8)],
      ),
      endDrawer: const AdminDrawer(currentMenu: AdminMenu.calendar),
      body: bodyContent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddDialog,
        backgroundColor: kGold,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'Add Slot',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
