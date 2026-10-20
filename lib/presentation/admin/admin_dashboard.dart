import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../shared_widgets/appColor.dart';
import '../shared_widgets/themeToggleButton.dart';
import '../shared_widgets/emergency_alert_banner.dart';
import 'approval_page.dart';
import 'billing_page.dart';
import 'payments_history_page.dart';
import 'availability_page.dart';
import '../../domain/entities/availability_entity.dart';
import '../../domain/entities/service_request_entity.dart';
import '../../infrastructure/repositories/supabase_availability_repository.dart';
import '../../infrastructure/repositories/supabase_service_request_repository.dart';

// Gahira Ball Mill Management System - Admin Dashboard
class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key, this.adminName = 'Admin'});

  final String adminName;

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

enum _DashboardPeriod { week, month }

class _AdminDashboardPageState extends State<AdminDashboardPage>
    with SingleTickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final _serviceRepository = SupabaseServiceRequestRepository();
  final _availabilityRepository = SupabaseAvailabilityRepository();
  late final AnimationController _todayPulseController;

  List<ServiceRequestEntity> _serviceRequests = [];
  List<AvailabilityEntity> _todayAvailabilities = [];
  List<PendingAccount> _pendingApplications = [];
  bool _isLoadingOverview = true;
  _DashboardPeriod _period = _DashboardPeriod.week;

  @override
  void initState() {
    super.initState();
    _todayPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _loadOverview();
  }

  @override
  void dispose() {
    _todayPulseController.dispose();
    super.dispose();
  }

  Future<void> _loadOverview() async {
    final serviceResult = await _serviceRepository.getServiceRequests();
    final applicationResult = await ApprovalService().fetchPendingAccounts();
    final availabilityResult = await _availabilityRepository
        .getAvailabilities();
    if (!mounted) return;

    setState(() {
      _serviceRequests = serviceResult.fold((_) => [], (requests) => requests);
      _todayAvailabilities = availabilityResult.fold(
        (_) => [],
        (availability) => availability,
      );
      _pendingApplications = applicationResult.fold(
        (_) => [],
        (accounts) => accounts,
      );
      _isLoadingOverview = false;
    });
  }

  List<ServiceRequestEntity> get _periodRequests {
    final now = DateTime.now();
    final start = _period == _DashboardPeriod.week
        ? DateTime(now.year, now.month, now.day - (now.weekday - 1))
        : DateTime(now.year, now.month);
    final end = _period == _DashboardPeriod.week
        ? start.add(const Duration(days: 7))
        : DateTime(now.year, now.month + 1);
    return _serviceRequests
        .where(
          (request) =>
              !request.updatedAt.isBefore(start) &&
              request.updatedAt.isBefore(end),
        )
        .toList();
  }

  List<ServiceRequestEntity> get _paymentTransactions {
    final transactions = _serviceRequests
        .where(
          (request) =>
              (request.financialDetails?.paymentAmount ?? 0) > 0 ||
              request.status == ServiceRequestStatus.completed ||
              request.status == ServiceRequestStatus.partiallyPaid,
        )
        .toList();
    transactions.sort(
      (a, b) => (b.financialDetails?.paymentDate ?? b.updatedAt).compareTo(
        a.financialDetails?.paymentDate ?? a.updatedAt,
      ),
    );
    return transactions.take(4).toList();
  }

  List<ServiceRequestEntity> get _pendingPayments {
    final requests = _serviceRequests.where((request) {
      if (request.status == ServiceRequestStatus.processingCompleted) {
        return true;
      }
      if (request.status != ServiceRequestStatus.goldHandoff &&
          request.status != ServiceRequestStatus.partiallyPaid) {
        return false;
      }
      return _outstandingBalance(request) > 0;
    }).toList()..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return requests;
  }

  double _outstandingBalance(ServiceRequestEntity request) {
    final financialDetails = request.financialDetails;
    if (financialDetails == null) return 0;

    final participants = financialDetails.participantBreakdown;
    if (participants != null && participants.isNotEmpty) {
      return participants.fold<double>(
        0,
        (total, participant) =>
            total + math.max(participant.totalDue - participant.amountPaid, 0),
      );
    }

    if (financialDetails.remainingBalance != null) {
      return math.max(financialDetails.remainingBalance!, 0);
    }
    if (request.status == ServiceRequestStatus.goldHandoff) {
      return math.max(financialDetails.totalBill, 0);
    }
    return math.max(
      financialDetails.totalBill - financialDetails.paymentAmount,
      0,
    );
  }

  List<AvailabilityEntity> get _todayAppointments {
    final now = DateTime.now();
    return _todayAvailabilities
        .where(
          (availability) =>
              availability.date.year == now.year &&
              availability.date.month == now.month &&
              availability.date.day == now.day,
        )
        .toList();
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
          'DASHBOARD',
          style: TextStyle(
            color: kGold,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
            fontSize: 16,
          ),
        ),
        iconTheme: const IconThemeData(color: kGold),
        actions: const [ThemeToggleButton(), SizedBox(width: 8)],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1120),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeader(),
                        const SizedBox(height: 20),
                        EmergencyAlertBanner(
                          isAdmin: true,
                          companion:
                              !_isLoadingOverview &&
                                  _todayAppointments.isNotEmpty
                              ? _buildTodayAppointments()
                              : null,
                        ),
                        const SizedBox(height: 20),
                        _buildServiceOverview(),
                        const SizedBox(height: 24),
                        _buildPendingApplications(),
                        const SizedBox(height: 24),
                        _buildPendingPayments(),
                        const SizedBox(height: 24),
                        _buildPaymentTransactions(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceOverview() {
    final requests = _periodRequests;
    final counts = <ServiceRequestStatus, int>{
      for (final status in ServiceRequestStatus.values)
        status: requests.where((request) => request.status == status).length,
    }..removeWhere((status, count) => count == 0);
    final total = requests.length;
    final chartColors = _statusColors;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kGold.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SERVICES PROCESSED',
                      style: TextStyle(
                        color: context.textColor,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Updated this ${_period.name}',
                      style: TextStyle(
                        color: context.mutedTextColor,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              SegmentedButton<_DashboardPeriod>(
                segments: const [
                  ButtonSegment(
                    value: _DashboardPeriod.week,
                    label: Text('Week'),
                  ),
                  ButtonSegment(
                    value: _DashboardPeriod.month,
                    label: Text('Month'),
                  ),
                ],
                selected: {_period},
                onSelectionChanged: (selection) =>
                    setState(() => _period = selection.first),
                showSelectedIcon: false,
                style: ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  textStyle: const WidgetStatePropertyAll(
                    TextStyle(fontSize: 12),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_isLoadingOverview)
            const SizedBox(
              height: 150,
              child: Center(child: CircularProgressIndicator(color: kGold)),
            )
          else if (total == 0)
            _buildDashboardEmpty('No service updates in this ${_period.name}.')
          else
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 420),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: ScaleTransition(
                  scale: Tween<double>(begin: 0.97, end: 1).animate(animation),
                  child: child,
                ),
              ),
              child: Column(
                key: ValueKey(
                  '${_period.name}:$total:${counts.entries.map((e) => '${e.key.name}-${e.value}').join(',')}',
                ),
                children: [
                  SizedBox(
                    height: 176,
                    child: Center(
                      child: SizedBox(
                        width: 170,
                        height: 170,
                        child: CustomPaint(
                          painter: _ServiceStatusPiePainter(
                            counts: counts,
                            colors: chartColors,
                            total: total,
                          ),
                          child: Center(
                            child: Container(
                              width: 94,
                              height: 94,
                              decoration: BoxDecoration(
                                color: context.surfaceColor,
                                shape: BoxShape.circle,
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    '$total',
                                    style: TextStyle(
                                      color: context.textColor,
                                      fontSize: 23,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    'services',
                                    style: TextStyle(
                                      color: context.mutedTextColor,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...counts.entries.map(
                    (entry) => _buildStatusCount(
                      entry.key,
                      entry.value,
                      chartColors[entry.key]!,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTodayAppointments() {
    final appointments = _todayAppointments;
    if (appointments.isEmpty) return const SizedBox.shrink();

    return AnimatedBuilder(
      animation: _todayPulseController,
      builder: (context, child) {
        final pulse = _todayPulseController.value;
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(
              0xFFFFC629,
            ).withValues(alpha: 0.08 + pulse * 0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: const Color(
                0xFFFFC629,
              ).withValues(alpha: 0.35 + pulse * 0.45),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFFC629).withValues(alpha: pulse * 0.12),
                blurRadius: 14,
                spreadRadius: 1,
              ),
            ],
          ),
          child: child,
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.today_rounded,
                color: Color(0xFFB88924),
                size: 20,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  "TODAY'S APPOINTMENTS",
                  style: TextStyle(
                    color: context.textColor,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              Text(
                '${appointments.length}',
                style: const TextStyle(
                  color: Color(0xFFB88924),
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_isLoadingOverview)
            const LinearProgressIndicator(
              color: Color(0xFFFFC629),
              minHeight: 2,
            )
          else ...[
            ...appointments.take(3).map((appointment) {
              final applicantCount = _pendingApplications
                  .where(
                    (applicant) =>
                        applicant.availabilityId ==
                            appointment.availabilityId ||
                        (applicant.availabilityId == null &&
                            applicant.appointmentDate != null &&
                            applicant.appointmentDate!.year ==
                                appointment.date.year &&
                            applicant.appointmentDate!.month ==
                                appointment.date.month &&
                            applicant.appointmentDate!.day ==
                                appointment.date.day),
                  )
                  .length;
              final cancelled = appointment.status.toLowerCase() == 'cancelled';
              return Padding(
                padding: const EdgeInsets.only(top: 7),
                child: Row(
                  children: [
                    Icon(
                      cancelled
                          ? Icons.event_busy_rounded
                          : Icons.access_time_rounded,
                      color: cancelled
                          ? Colors.redAccent
                          : const Color(0xFFB88924),
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${_formatAppointmentTime(appointment.startTime)} · $applicantCount applicant${applicantCount == 1 ? '' : 's'}${cancelled ? ' · Cancelled' : ''}',
                        style: TextStyle(
                          color: cancelled
                              ? Colors.redAccent
                              : context.textColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
            if (appointments.length > 3)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  '+${appointments.length - 3} more slots today',
                  style: TextStyle(color: context.mutedTextColor, fontSize: 11),
                ),
              ),
          ],
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AvailabilityPage(
                      embedInTab: true,
                      showBackButton: true,
                    ),
                  ),
                );
                if (mounted) _loadOverview();
              },
              icon: const Icon(Icons.calendar_month_rounded, size: 16),
              label: const Text('Open appointment calendar'),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFB88924),
                visualDensity: VisualDensity.compact,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatAppointmentTime(String time) {
    try {
      return DateFormat('h:mm a').format(DateFormat('HH:mm:ss').parse(time));
    } catch (_) {
      try {
        return DateFormat('h:mm a').format(DateFormat('HH:mm').parse(time));
      } catch (_) {
        return time;
      }
    }
  }

  Widget _buildStatusCount(
    ServiceRequestStatus status,
    int count,
    Color color,
  ) {
    final label = _statusLabel(status);
    final total = _periodRequests.length;
    final percentage = total == 0 ? 0 : (count * 100 / total).round();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOut,
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: context.textColor, fontSize: 12),
            ),
          ),
          Text(
            '$count',
            style: TextStyle(
              color: context.textColor,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 38,
            child: Text(
              '$percentage%',
              textAlign: TextAlign.end,
              style: TextStyle(color: context.mutedTextColor, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingApplications() {
    final applications = _pendingApplications.take(4).toList();
    return _buildDashboardSection(
      title: 'PENDING APPLICATIONS',
      icon: Icons.person_add_alt_1_rounded,
      accent: const Color(0xFF3D9B8F),
      actionLabel: 'View all',
      onAction: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ApprovalPage()),
      ),
      child: _isLoadingOverview
          ? const LinearProgressIndicator(
              color: Color(0xFF3D9B8F),
              minHeight: 2,
            )
          : applications.isEmpty
          ? _buildDashboardEmpty('No pending applications.')
          : Column(
              children: applications
                  .map((application) => _buildApplicationRow(application))
                  .toList(),
            ),
    );
  }

  Widget _buildApplicationRow(PendingAccount application) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          _buildWhiteIcon(
            Icons.person_outline_rounded,
            const Color(0xFF159E8C),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  application.fullName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: context.textColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${application.role.name} · ${DateFormat('MMM d').format(application.requestedAt)}',
                  style: TextStyle(color: context.mutedTextColor, fontSize: 11),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.schedule_rounded,
            color: Color(0xFF159E8C),
            size: 18,
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentTransactions() {
    final transactions = _paymentTransactions;
    return _buildDashboardSection(
      title: 'PAYMENT TRANSACTIONS',
      icon: Icons.payments_rounded,
      accent: const Color(0xFF4B83C3),
      actionLabel: 'View all',
      onAction: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const PaymentsHistoryPage()),
      ),
      child: _isLoadingOverview
          ? const LinearProgressIndicator(
              color: Color(0xFF4B83C3),
              minHeight: 2,
            )
          : transactions.isEmpty
          ? _buildDashboardEmpty('No payment transactions recorded.')
          : Column(children: transactions.map(_buildPaymentRow).toList()),
    );
  }

  Widget _buildPendingPayments() {
    final requests = _pendingPayments;
    final totalOutstanding = requests.fold<double>(
      0,
      (total, request) => total + _outstandingBalance(request),
    );
    return _buildDashboardSection(
      title: 'PENDING PAYMENTS / BILLS',
      icon: Icons.receipt_long_rounded,
      accent: const Color(0xFFD18C27),
      actionLabel: 'Open billing',
      onAction: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const BillingPage()),
      ),
      child: _isLoadingOverview
          ? const LinearProgressIndicator(
              color: Color(0xFFD18C27),
              minHeight: 2,
            )
          : requests.isEmpty
          ? _buildDashboardEmpty('No outstanding bills or payments.')
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(2, 10, 2, 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${requests.length} pending item${requests.length == 1 ? '' : 's'}',
                        style: TextStyle(
                          color: context.mutedTextColor,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        '₱${NumberFormat('#,##0.00').format(totalOutstanding)} due',
                        style: const TextStyle(
                          color: Color(0xFFD18C27),
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                ...requests.take(4).map(_buildPendingPaymentRow),
              ],
            ),
    );
  }

  Widget _buildPendingPaymentRow(ServiceRequestEntity request) {
    final reference =
        request.billingId ??
        'SR-${request.id.substring(0, math.min(6, request.id.length)).toUpperCase()}';
    final statusLabel = switch (request.status) {
      ServiceRequestStatus.processingCompleted => 'Bill pending',
      ServiceRequestStatus.partiallyPaid => 'Partially paid',
      _ => 'Unpaid',
    };
    final balanceLabel =
        request.status == ServiceRequestStatus.processingCompleted
        ? 'Not billed'
        : '₱${NumberFormat('#,##0.00').format(_outstandingBalance(request))}';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          _buildWhiteIcon(
            Icons.account_balance_wallet_outlined,
            const Color(0xFFD18C27),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  request.creatorName ?? 'Miner',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: context.textColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$reference · $statusLabel',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: context.mutedTextColor, fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            balanceLabel,
            style: const TextStyle(
              color: Color(0xFFD18C27),
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentRow(ServiceRequestEntity request) {
    final amount = request.financialDetails?.paymentAmount ?? 0;
    final date = request.financialDetails?.paymentDate ?? request.updatedAt;
    final statusColor = _statusColors[request.status] ?? Colors.blueGrey;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          _buildWhiteIcon(Icons.receipt_long_rounded, const Color(0xFF347FD1)),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  request.creatorName ??
                      'Service ${request.id.substring(0, math.min(6, request.id.length))}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: context.textColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  DateFormat('MMM d, yyyy').format(date),
                  style: TextStyle(color: context.mutedTextColor, fontSize: 11),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '₱${NumberFormat('#,##0.00').format(amount)}',
                style: const TextStyle(
                  color: Color(0xFF388A5B),
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                _statusLabel(request.status),
                style: TextStyle(
                  color: statusColor,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardSection({
    required String title,
    required IconData icon,
    required Color accent,
    required String actionLabel,
    required VoidCallback onAction,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accent.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _buildWhiteIcon(icon, accent, size: 32, iconSize: 17),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: context.textColor,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              TextButton(
                onPressed: onAction,
                child: Text(
                  actionLabel,
                  style: TextStyle(color: accent, fontSize: 12),
                ),
              ),
            ],
          ),
          Divider(height: 1, color: accent.withValues(alpha: 0.15)),
          const SizedBox(height: 5),
          child,
        ],
      ),
    );
  }

  Widget _buildDashboardEmpty(String message) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 22),
    child: Center(
      child: Text(
        message,
        style: TextStyle(color: context.mutedTextColor, fontSize: 12),
      ),
    ),
  );

  Widget _buildWhiteIcon(
    IconData icon,
    Color foreground, {
    double size = 34,
    double iconSize = 18,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Icon(icon, color: foreground, size: iconSize),
    );
  }

  static const Map<ServiceRequestStatus, Color> _statusColors = {
    ServiceRequestStatus.draft: Color(0xFF9AA4B2),
    ServiceRequestStatus.pendingOperatorVerification: Color(0xFFFFB938),
    ServiceRequestStatus.returnedToMiner: Color(0xFFFF786B),
    ServiceRequestStatus.accepted: Color(0xFF42B8A8),
    ServiceRequestStatus.verified: Color(0xFF5D9EF5),
    ServiceRequestStatus.queued: Color(0xFF8C8FF0),
    ServiceRequestStatus.scheduled: Color(0xFF36B8D0),
    ServiceRequestStatus.assigned: Color(0xFF36B982),
    ServiceRequestStatus.processing: Color(0xFFFF9747),
    ServiceRequestStatus.processingCompleted: Color(0xFF54C878),
    ServiceRequestStatus.goldHandoff: Color(0xFFFFD34F),
    ServiceRequestStatus.partiallyPaid: Color(0xFFBA91FF),
    ServiceRequestStatus.completed: Color(0xFF2DBB70),
    ServiceRequestStatus.cancelled: Color(0xFFFF666D),
    ServiceRequestStatus.emergencyStop: Color(0xFFFF424D),
  };

  String _statusLabel(ServiceRequestStatus status) => switch (status) {
    ServiceRequestStatus.pendingOperatorVerification => 'Pending verification',
    ServiceRequestStatus.returnedToMiner => 'Returned',
    ServiceRequestStatus.processingCompleted => 'Processed',
    ServiceRequestStatus.partiallyPaid => 'Partially paid',
    ServiceRequestStatus.goldHandoff => 'Gold handoff',
    ServiceRequestStatus.emergencyStop => 'Emergency stop',
    _ =>
      status.name
          .replaceAllMapped(RegExp(r'([A-Z])'), (match) => ' ${match[0]}')
          .trim()
          .split(' ')
          .map((word) => word[0].toUpperCase() + word.substring(1))
          .join(' '),
  };

  Widget _buildHeader() {
    final isDark = context.isDarkMode;
    final goldTint = isDark ? const Color(0xFFFFD66B) : const Color(0xFFE4B443);
    final companionTint = isDark
        ? const Color(0xFF53D5C3)
        : const Color(0xFF2C9F91);
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                goldTint.withValues(alpha: isDark ? 0.18 : 0.22),
                companionTint.withValues(alpha: isDark ? 0.12 : 0.10),
                context.surfaceColor.withValues(alpha: isDark ? 0.82 : 0.78),
              ],
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: goldTint.withValues(alpha: 0.42)),
            boxShadow: [
              BoxShadow(
                color: goldTint.withValues(alpha: isDark ? 0.10 : 0.13),
                blurRadius: 22,
                offset: const Offset(0, 7),
              ),
            ],
          ),
          child: Row(
            children: [
              _buildWhiteIcon(
                Icons.waving_hand_rounded,
                goldTint,
                size: 46,
                iconSize: 23,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome back,',
                      style: TextStyle(
                        color: companionTint,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.adminName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: context.textColor,
                        fontSize: 23,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 4,
                height: 42,
                decoration: BoxDecoration(
                  color: goldTint,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          ),
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
      child: const Icon(
        Icons.settings_input_component_rounded,
        color: kGold,
        size: 16,
      ),
    );
  }
}

class _ServiceStatusPiePainter extends CustomPainter {
  const _ServiceStatusPiePainter({
    required this.counts,
    required this.colors,
    required this.total,
  });

  final Map<ServiceRequestStatus, int> counts;
  final Map<ServiceRequestStatus, Color> colors;
  final int total;

  @override
  void paint(Canvas canvas, Size size) {
    if (total == 0) return;

    final bounds = Offset.zero & size;
    final center = bounds.center;
    final radius = math.min(size.width, size.height) / 2;
    var startAngle = -math.pi / 2;

    for (final entry in counts.entries) {
      final sweepAngle = entry.value / total * math.pi * 2;
      final paint = Paint()
        ..color = colors[entry.key] ?? Colors.blueGrey
        ..style = PaintingStyle.fill;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        true,
        paint,
      );
      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant _ServiceStatusPiePainter oldDelegate) =>
      oldDelegate.counts != counts ||
      oldDelegate.colors != colors ||
      oldDelegate.total != total;
}
