import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../domain/entities/service_request_entity.dart';
import '../../infrastructure/repositories/supabase_service_request_repository.dart';
import '../shared_widgets/appColor.dart';
import '../shared_widgets/themeToggleButton.dart';
import '../shared_widgets/adminDrawer.dart';

class PaymentsHistoryPage extends StatefulWidget {
  const PaymentsHistoryPage({super.key});

  @override
  State<PaymentsHistoryPage> createState() => _PaymentsHistoryPageState();
}

class _PaymentsHistoryPageState extends State<PaymentsHistoryPage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final SupabaseServiceRequestRepository _repository =
      SupabaseServiceRequestRepository();

  List<ServiceRequestEntity> _paymentRequests = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final result = await _repository.getServiceRequests();
    setState(() {
      _paymentRequests = result.fold(
        (l) => [],
        (r) => r
            .where(
              (req) =>
                  (req.financialDetails?.paymentAmount ?? 0) > 0 ||
                  req.status == ServiceRequestStatus.completed ||
                  req.status == ServiceRequestStatus.partiallyPaid,
            )
            .toList(),
      );
      // Sort by latest payment date if available, otherwise created at
      _paymentRequests.sort((a, b) {
        final dateA = a.financialDetails?.paymentDate ?? a.updatedAt;
        final dateB = b.financialDetails?.paymentDate ?? b.updatedAt;
        return dateB.compareTo(dateA);
      });
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    double totalCollections = _paymentRequests.fold(
      0,
      (sum, r) => sum + (r.financialDetails?.paymentAmount ?? 0),
    );

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: context.bgColor,
      appBar: AppBar(
        backgroundColor: context.surfaceColor,
        elevation: 0,
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back_rounded, color: kGold),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: const Text(
          'PAYMENT HISTORY',
          style: TextStyle(
            color: kGold,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
            fontSize: 16,
          ),
        ),
        actions: [
          const ThemeToggleButton(),
          IconButton(
            icon: const Icon(Icons.menu_rounded, color: kGold),
            onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
          ),
        ],
      ),
      endDrawer: const AdminDrawer(currentMenu: AdminMenu.payments),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: kGold))
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildSummaryHeader(totalCollections),
                  const SizedBox(height: 20),
                  Text(
                    'Recent Payments',
                    style: TextStyle(
                      color: context.textColor,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_paymentRequests.isEmpty)
                    _buildEmptyState()
                  else
                    ..._paymentRequests.map((r) => _buildPaymentCard(r)),
                ],
              ),
            ),
    );
  }

  Widget _buildSummaryHeader(double total) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [kGold.withOpacity(0.15), kGold.withOpacity(0.05)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kGold.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.account_balance_wallet_rounded,
                color: kGold,
                size: 20,
              ),
              const SizedBox(width: 10),
              Text(
                'TOTAL COLLECTIONS (CASH)',
                style: TextStyle(
                  color: context.mutedTextColor,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'P ${NumberFormat("#,##0.00").format(total)}',
            style: TextStyle(
              color: context.textColor,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentCard(ServiceRequestEntity request) {
    final fd = request.financialDetails;
    final bool isGroup = request.participatingMinerIds.length > 1;
    final String dateStr = fd?.paymentDate != null
        ? DateFormat('MMM dd, yyyy • hh:mm a').format(fd!.paymentDate!)
        : DateFormat('MMM dd, yyyy • hh:mm a').format(request.updatedAt);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kGold.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isGroup
                            ? 'Korpo (Group)'
                            : (request.creatorName ?? 'Miner'),
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        dateStr,
                        style: TextStyle(
                          color: context.mutedTextColor,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'P ${NumberFormat("#,##0.00").format(fd?.paymentAmount ?? 0)}',
                      style: const TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      'CASH',
                      style: TextStyle(
                        color: context.mutedTextColor,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 8,
              children: [
                _buildMiniInfo(
                  'REF ID',
                  'SR-${request.id.substring(0, 5).toUpperCase()}',
                ),
                _buildStatusChip(request.status),
                if (fd?.paymentReceiptUrl != null)
                  TextButton.icon(
                    onPressed: () => _showReceipt(fd!.paymentReceiptUrl!),
                    icon: const Icon(
                      Icons.receipt_long_rounded,
                      size: 16,
                      color: kGold,
                    ),
                    label: const Text(
                      'VIEW RECEIPT',
                      style: TextStyle(
                        color: kGold,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  )
                else
                  Text(
                    'NO RECEIPT',
                    style: TextStyle(
                      color: context.mutedTextColor,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniInfo(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(color: context.mutedTextColor, fontSize: 9),
        ),
        Text(
          value,
          style: TextStyle(
            color: context.textColor,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  void _showReceipt(String url) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.topRight,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                url,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return const Center(
                    child: CircularProgressIndicator(color: kGold),
                  );
                },
                errorBuilder: (context, error, stackTrace) => Container(
                  padding: const EdgeInsets.all(40),
                  color: context.surfaceColor,
                  child: const Column(
                    children: [
                      Icon(
                        Icons.broken_image_rounded,
                        color: Colors.red,
                        size: 48,
                      ),
                      SizedBox(height: 16),
                      Text('Could not load receipt image'),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(ServiceRequestStatus status) {
    Color color = Colors.green;
    if (status == ServiceRequestStatus.partiallyPaid) color = Colors.purple;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status == ServiceRequestStatus.completed ? 'PAID' : 'PARTIAL',
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40.0),
        child: Column(
          children: [
            Icon(
              Icons.history_rounded,
              size: 48,
              color: context.mutedTextColor.withOpacity(0.2),
            ),
            const SizedBox(height: 16),
            Text(
              'No payment records found.',
              style: TextStyle(color: context.mutedTextColor),
            ),
          ],
        ),
      ),
    );
  }
}
