import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../application/services/service_request_service.dart';
import '../../domain/entities/service_request_entity.dart';
import '../../infrastructure/repositories/supabase_service_request_repository.dart';
import '../shared_widgets/appColor.dart';
import '../shared_widgets/themeToggleButton.dart';

class BillingPage extends StatefulWidget {
  const BillingPage({super.key});

  @override
  State<BillingPage> createState() => _BillingPageState();
}

class _BillingPageState extends State<BillingPage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final SupabaseServiceRequestRepository _repository =
      SupabaseServiceRequestRepository();
  final ServiceRequestService _service = ServiceRequestService(
    SupabaseServiceRequestRepository(),
  );

  List<ServiceRequestEntity> _requests = [];
  Map<String, List<Map<String, dynamic>>> _paymentHistory = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    final result = await _repository.getServiceRequests();
    final paymentsResult = await _repository.getParticipantPaymentHistory(
      userId,
    );
    if (!mounted) return;

    setState(() {
      _requests = result.fold(
        (_) => [],
        (list) => list
            .where(
              (r) =>
                  (r.creatorId == userId ||
                      r.participatingMinerIds.contains(userId)) &&
                  (r.financialDetails?.totalBill ?? 0) > 0,
            )
            .toList()
          ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt)),
      );
      _paymentHistory = paymentsResult.fold(
        (_) => <String, List<Map<String, dynamic>>>{},
        (payments) {
          final history = <String, List<Map<String, dynamic>>>{};
          for (final payment in payments) {
            final requestId = payment['service_request_id']?.toString();
            if (requestId == null) continue;
            history.putIfAbsent(requestId, () => []).add(payment);
          }
          return history;
        },
      );
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    bool billReady(ServiceRequestEntity request) => {
      ServiceRequestStatus.goldHandoff,
      ServiceRequestStatus.partiallyPaid,
      ServiceRequestStatus.processingCompleted,
      ServiceRequestStatus.completed,
    }.contains(request.status);

    final unpaid = _requests
        .where(
          (r) =>
              billReady(r) &&
              _remainingBalance(r) > 0 &&
              (!_isGroupRequest(r) || _participantFinancial(r) != null),
        )
        .toList();

    final paid = _requests
        .where(
          (r) =>
              billReady(r) &&
              _remainingBalance(r) <= 0 &&
              (!_isGroupRequest(r) || _participantFinancial(r) != null),
        )
        .toList();

    final double totalDue = unpaid.fold(
      0,
      (sum, r) => sum + _remainingBalance(r),
    );
    final double totalPaid = _requests.fold(0, (sum, request) {
      final participant = _isGroupRequest(request)
          ? _participantFinancial(request)
          : null;
      return sum +
          (participant?.amountPaid ??
              (request.financialDetails?.paymentAmount ?? 0));
    });

    return DefaultTabController(
      length: 2,
      child: Scaffold(
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
            'BILLING & TRANSACTIONS',
            style: TextStyle(
              color: kGold,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
              fontSize: 16,
            ),
          ),
          actions: const [
            ThemeToggleButton(),
            SizedBox(width: 8),
          ],
          bottom: TabBar(
            labelColor: kGold,
            unselectedLabelColor: context.mutedTextColor,
            indicatorColor: kGold,
            tabs: [
              Tab(text: 'BILLING (${unpaid.length})'),
              Tab(text: 'PAID (${paid.length})'),
            ],
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: kGold))
            : RefreshIndicator(
                onRefresh: _loadData,
                child: TabBarView(
                  children: [
                    _buildBillingTab(unpaid, totalDue),
                    _buildPaidTab(paid, totalPaid),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildBillingTab(List<ServiceRequestEntity> unpaid, double totalDue) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Billing & Invoices',
            style: TextStyle(
              color: context.textColor,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Your outstanding processing bills and settlements',
            style: TextStyle(color: context.mutedTextColor, fontSize: 13),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _buildSummaryCard(
                  'Total Due',
                  'P ${NumberFormat('#,##0.00').format(totalDue)}',
                  Icons.account_balance_wallet_outlined,
                  Colors.orange,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildSummaryCard(
                  'Pending Bills',
                  '${unpaid.length}',
                  Icons.receipt_long_outlined,
                  kGold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          Text(
            'Unpaid Bills (${unpaid.length})',
            style: TextStyle(
              color: context.textColor,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          if (unpaid.isEmpty)
            _buildEmptyState(
              Icons.check_circle_outline,
              Colors.green,
              'All caught up!',
              'You have no outstanding bills.',
            )
          else
            ...unpaid.map((r) => _buildBillCard(r, isPaid: false)),
        ],
      ),
    );
  }

  Widget _buildPaidTab(List<ServiceRequestEntity> paid, double totalPaid) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Payment History',
            style: TextStyle(
              color: context.textColor,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Your completed and settled service request bills',
            style: TextStyle(color: context.mutedTextColor, fontSize: 13),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _buildSummaryCard(
                  'Total Paid',
                  'P ${NumberFormat('#,##0.00').format(totalPaid)}',
                  Icons.check_circle_outline,
                  Colors.green,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildSummaryCard(
                  'Completed',
                  '${paid.length}',
                  Icons.history_rounded,
                  Colors.blue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          Text(
            'Paid Invoices (${paid.length})',
            style: TextStyle(
              color: context.textColor,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          if (paid.isEmpty)
            _buildEmptyState(
              Icons.history_rounded,
              context.mutedTextColor,
              'No paid invoices yet.',
              'Completed payments will appear here.',
            )
          else
            ...paid.map((r) => _buildBillCard(r, isPaid: true)),
        ],
      ),
    );
  }

  Widget _buildBillCard(ServiceRequestEntity request, {required bool isPaid}) {
    final fd = request.financialDetails;
    final Color statusColor = isPaid ? Colors.green : Colors.orange;
    final bool isGroup = _isGroupRequest(request);
    final participant = isGroup ? _participantFinancial(request) : null;
    final userId = Supabase.instance.client.auth.currentUser?.id;
    final bool canPay = !isPaid &&
        (isGroup || request.creatorId == userId) &&
        _remainingBalance(request) > 0;
    final String refId = 'SR-${request.id.substring(0, 5).toUpperCase()}';

    String statusLabel;
    if (_remainingBalance(request) <= 0) {
      statusLabel = 'Paid';
    } else if (isGroup
        ? (participant?.amountPaid ?? 0) > 0
        : request.status == ServiceRequestStatus.partiallyPaid) {
      statusLabel = 'Partial';
    } else {
      statusLabel = 'Unpaid';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kGold.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isPaid ? Icons.receipt_long : Icons.receipt_long_outlined,
                  color: statusColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isGroup ? 'Korpo (Group)' : 'Gold Ore Processing',
                      style: TextStyle(
                        color: context.textColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      refId,
                      style: TextStyle(
                        color: context.mutedTextColor,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildDetailItem(
                'Date',
                DateFormat('MMM dd, yyyy').format(request.updatedAt),
              ),
              if (!isGroup && fd?.paymentDate != null)
                _buildDetailItem(
                  'Paid On',
                  DateFormat('MMM dd, yyyy').format(fd!.paymentDate!),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (!isGroup) Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Processing Fee',
                style: TextStyle(color: context.mutedTextColor, fontSize: 12),
              ),
              Text(
                'P ${NumberFormat('#,##0.00').format(fd?.processingFee ?? 0)}',
                style: TextStyle(color: context.textColor, fontSize: 13),
              ),
            ],
          ),
          if (!isGroup && (fd?.otherExpenses ?? 0) > 0) ...[
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Other Expenses',
                  style: TextStyle(color: context.mutedTextColor, fontSize: 12),
                ),
                Text(
                  'P ${NumberFormat('#,##0.00').format(fd?.otherExpenses ?? 0)}',
                  style: TextStyle(color: context.textColor, fontSize: 13),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isGroup ? 'Your Share' : 'Total Bill',
                style: TextStyle(color: context.mutedTextColor, fontSize: 12),
              ),
              Text(
                'P ${NumberFormat('#,##0.00').format(participant?.totalDue ?? fd?.totalBill ?? 0)}',
                style: const TextStyle(
                  color: kGold,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          if (isPaid && !isGroup && fd?.paymentReceiptUrl != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 14),
                const SizedBox(width: 6),
                Text(
                  'Payment confirmed',
                  style: const TextStyle(
                    color: Colors.green,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
          if (!isPaid && _remainingBalance(request) > 0) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withValues(alpha: 0.2)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Balance Due',
                    style: TextStyle(
                      color: context.mutedTextColor,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'P ${NumberFormat('#,##0.00').format(_remainingBalance(request))}',
                    style: const TextStyle(
                      color: Colors.orange,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (canPay) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _showMinerPaymentDialog(request),
                icon: const Icon(Icons.payment_outlined),
                label: const Text('Pay Bill'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kGold,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                ),
              ),
            ),
          ],
          _buildPaymentHistory(request),
        ],
      ),
    );
  }

  bool _isGroupRequest(ServiceRequestEntity request) =>
      request.participatingMinerIds.length > 1;

  ParticipantFinancial? _participantFinancial(ServiceRequestEntity request) {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return null;
    for (final participant
        in request.financialDetails?.participantBreakdown ?? const []) {
      if (participant.userId == userId) return participant;
    }
    return null;
  }

  double _remainingBalance(ServiceRequestEntity request) {
    if (_isGroupRequest(request)) {
      final participant = _participantFinancial(request);
      if (participant == null) return 0;
      return (participant.totalDue - participant.amountPaid)
          .clamp(0, double.infinity)
          .toDouble();
    }
    final fd = request.financialDetails;
    return (fd?.remainingBalance ??
            ((fd?.totalBill ?? 0) - (fd?.paymentAmount ?? 0)))
        .clamp(0, double.infinity)
        .toDouble();
  }

  Widget _buildPaymentHistory(ServiceRequestEntity request) {
    final payments = _paymentHistory[request.id] ?? const [];
    final displayPayments =
        !_isGroupRequest(request) &&
        payments.isEmpty &&
            (request.financialDetails?.paymentAmount ?? 0) > 0
        ? [
            {
              'amount': request.financialDetails!.paymentAmount,
              'receipt_url': request.financialDetails!.paymentReceiptUrl,
              'payment_date': request.financialDetails!.paymentDate?.toIso8601String(),
            },
          ]
        : payments;
    if (displayPayments.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(),
          const SizedBox(height: 6),
          Text(
            'Payment history',
            style: TextStyle(
              color: context.textColor,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 8),
          ...displayPayments.map((payment) {
            final date = DateTime.tryParse(
              payment['payment_date']?.toString() ?? '',
            );
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_outline,
                      color: Colors.green, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      date == null ? 'Payment' : DateFormat('MMM dd, yyyy').format(date),
                      style: TextStyle(color: context.mutedTextColor, fontSize: 12),
                    ),
                  ),
                  if ((payment['receipt_url']?.toString().isNotEmpty ?? false))
                    const Padding(
                      padding: EdgeInsets.only(right: 8),
                      child: Icon(Icons.receipt_outlined, color: kGold, size: 16),
                    ),
                  Text(
                    'P ${NumberFormat('#,##0.00').format((payment['amount'] as num?)?.toDouble() ?? 0)}',
                    style: TextStyle(
                      color: context.textColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Future<void> _showMinerPaymentDialog(ServiceRequestEntity request) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    final fd = request.financialDetails;
    final remaining = _remainingBalance(request);
    double amount = remaining;
    PlatformFile? receipt;
    bool saving = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.bgColor,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            MediaQuery.of(sheetContext).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pay service bill',
                  style: TextStyle(
                    color: context.textColor,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Balance due: P ${NumberFormat('#,##0.00').format(remaining)}',
                  style: TextStyle(color: context.mutedTextColor),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  initialValue: remaining.toStringAsFixed(2),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Payment amount',
                    prefixText: 'P ',
                    filled: true,
                    fillColor: context.surfaceColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onChanged: (value) => setSheetState(
                    () => amount = double.tryParse(value) ?? 0,
                  ),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: saving
                      ? null
                      : () async {
                          final picked = await FilePicker.platform.pickFiles(
                            type: FileType.image,
                            withData: true,
                          );
                          if (picked != null && picked.files.isNotEmpty) {
                            setSheetState(() => receipt = picked.files.first);
                          }
                        },
                  icon: Icon(
                    receipt == null
                        ? Icons.cloud_upload_outlined
                        : Icons.check_circle_outline,
                  ),
                  label: Text(receipt?.name ?? 'Upload payment receipt'),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: saving
                        ? null
                        : () async {
                            if (amount <= 0 || amount > remaining) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Enter an amount greater than zero and no more than the balance due.',
                                  ),
                                ),
                              );
                              return;
                            }
                            if (receipt?.bytes == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Upload a receipt to continue.'),
                                ),
                              );
                              return;
                            }

                            setSheetState(() => saving = true);
                            final upload = await _repository.uploadRequestPhotos(
                              [receipt!],
                            );
                            String? receiptUrl;
                            String? uploadError;
                            upload.fold(
                              (failure) => uploadError = failure.message,
                              (urls) {
                                if (urls.isNotEmpty) {
                                  receiptUrl = urls.first;
                                } else {
                                  uploadError = 'Receipt upload failed.';
                                }
                              },
                            );
                            if (uploadError != null || receiptUrl == null) {
                              setSheetState(() => saving = false);
                              if (sheetContext.mounted) {
                                ScaffoldMessenger.of(sheetContext).showSnackBar(
                                  SnackBar(content: Text(uploadError ?? 'Receipt upload failed.')),
                                );
                              }
                              return;
                            }

                            final newBalance = (remaining - amount)
                                .clamp(0, double.infinity)
                                .toDouble();
                            final paidBefore =
                                ((fd?.totalBill ?? 0) - remaining)
                                    .clamp(0, double.infinity)
                                    .toDouble();
                            final result = _isGroupRequest(request)
                                ? await _service.recordGroupMinerPayment(
                                    requestId: request.id,
                                    paymentAmount: amount,
                                    receiptUrl: receiptUrl!,
                                  )
                                : await _service.recordMinerPayment(
                                    requestId: request.id,
                                    minerId: userId,
                                    paymentAmount: amount,
                                    totalPaid: paidBefore + amount,
                                    remainingBalance: newBalance,
                                    receiptUrl: receiptUrl!,
                                    paymentDate: DateTime.now(),
                                    currentStatus: request.status.name,
                                  );

                            if (!sheetContext.mounted) return;
                            result.fold(
                              (failure) {
                                setSheetState(() => saving = false);
                                ScaffoldMessenger.of(sheetContext).showSnackBar(
                                  SnackBar(content: Text(failure.message)),
                                );
                              },
                              (_) {
                                Navigator.pop(sheetContext);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      newBalance <= 0
                                          ? 'Payment complete. This service is now paid.'
                                          : 'Partial payment recorded. Remaining balance: P ${NumberFormat('#,##0.00').format(newBalance)}',
                                    ),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                                _loadData();
                              },
                            );
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kGold,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text(saving ? 'Processing…' : 'Submit payment'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kGold.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              color: context.textColor,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(color: context.mutedTextColor, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailItem(String label, String value) {
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
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(
    IconData icon,
    Color color,
    String title,
    String subtitle,
  ) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kGold.withValues(alpha: 0.1)),
      ),
      child: Center(
        child: Column(
          children: [
            Icon(icon, color: color, size: 48),
            const SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(
                color: context.textColor,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(color: context.mutedTextColor, fontSize: 14),
              textAlign: TextAlign.center,
            ),
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
      child: const Icon(
        Icons.settings_input_component_rounded,
        color: kGold,
        size: 16,
      ),
    );
  }
}
