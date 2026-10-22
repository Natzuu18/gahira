import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/service_request_entity.dart';
import '../../infrastructure/repositories/supabase_service_request_repository.dart';
import '../shared_widgets/appColor.dart';
import '../shared_widgets/themeToggleButton.dart';
import '../miner/miner_drawer.dart';

// Gahira Ball Mill Management System - Transaction History Page
// Miners/Clients can view their complete financial transaction history from Supabase

class TransactionHistoryPage extends StatefulWidget {
  const TransactionHistoryPage({super.key});

  @override
  State<TransactionHistoryPage> createState() => _TransactionHistoryPageState();
}

class _TransactionHistoryPageState extends State<TransactionHistoryPage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final SupabaseServiceRequestRepository _repository =
      SupabaseServiceRequestRepository();

  List<ServiceRequestEntity> _requests = [];
  List<Map<String, dynamic>> _payments = [];
  bool _isLoading = true;
  String _selectedFilter = 'All';

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
      _payments = paymentsResult.fold((_) => [], (payments) => payments);
      _isLoading = false;
    });
  }

  /// Converts a ServiceRequestEntity into a flat transaction map for display.
  List<Map<String, dynamic>> get _allTransactions {
    final List<Map<String, dynamic>> txns = [];
    for (final r in _requests) {
      final fd = r.financialDetails;
      final refId = r.serviceReference;
      final bool isGroup = r.participatingMinerIds.length > 1;
      final String minerLabel = isGroup ? 'Korpo (Group)' : 'Gold Ore Processing';

      // Billing / Invoice entry — always present when totalBill > 0
      txns.add({
        'id': refId,
        'type': 'Invoice',
        'description': 'Invoice for $minerLabel',
        'amount': -(fd?.totalBill ?? 0),
        'date': r.updatedAt,
        'status': r.status == ServiceRequestStatus.completed
            ? 'Paid'
            : r.status == ServiceRequestStatus.partiallyPaid
                ? 'Partial'
                : 'Pending',
      });

      // Keep each installment as its own transaction for this service.
      final servicePayments = _payments
          .where((payment) =>
              payment['service_request_id']?.toString() == r.id)
          .toList();
      if (servicePayments.isNotEmpty) {
        for (final payment in servicePayments) {
          final paidAt = DateTime.tryParse(
            payment['payment_date']?.toString() ?? '',
          );
          txns.add({
            'id': payment['payment_id']?.toString() ?? refId,
            'type': 'Payment',
            'description': 'Payment for $refId',
            'amount': (payment['amount'] as num?)?.toDouble() ?? 0,
            'date': paidAt ?? r.updatedAt,
            'status': 'Completed',
            'receipt_url': payment['receipt_url']?.toString(),
          });
        }
      } else if ((fd?.paymentAmount ?? 0) > 0) {
        // Show legacy payments that predate the installment ledger.
        txns.add({
          'id': refId,
          'type': 'Payment',
          'description': 'Payment for $refId',
          'amount': fd!.paymentAmount,
          'date': fd.paymentDate ?? r.updatedAt,
          'status': 'Completed',
          'receipt_url': fd.paymentReceiptUrl,
        });
      }

      // Gold amount entry — only if gold was bought and miner receives proceeds
      if ((fd?.amountToMiner ?? 0) > 0) {
        txns.add({
          'id': refId,
          'type': 'Gold Sale',
          'description': 'Gold sale proceeds for $refId',
          'amount': fd!.amountToMiner,
          'date': r.updatedAt,
          'status': 'Completed',
        });
      }
    }

    // Sort by date descending
    txns.sort((a, b) {
      final DateTime da = a['date'] is DateTime ? a['date'] : DateTime.now();
      final DateTime db = b['date'] is DateTime ? b['date'] : DateTime.now();
      return db.compareTo(da);
    });

    return txns;
  }

  List<Map<String, dynamic>> get _filteredTransactions {
    if (_selectedFilter == 'All') return _allTransactions;
    return _allTransactions
        .where((t) => t['type'] == _selectedFilter)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final txns = _filteredTransactions;

    final totalPayments = _allTransactions
        .where((t) => t['type'] == 'Payment' && t['status'] == 'Completed')
        .fold<double>(0.0, (sum, t) => sum + (t['amount'] as double));
    final totalInvoices = _allTransactions
        .where((t) => t['type'] == 'Invoice')
        .fold<double>(0.0, (sum, t) => sum + (t['amount'] as double).abs());
    final totalGoldSales = _allTransactions
        .where((t) => t['type'] == 'Gold Sale')
        .fold<double>(0.0, (sum, t) => sum + (t['amount'] as double));

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
          'EGReS',
          style: TextStyle(
            color: kGold,
            fontWeight: FontWeight.bold,
            letterSpacing: 3,
            fontSize: 16,
          ),
        ),
        iconTheme: const IconThemeData(color: kGold),
        actions: [
          const ThemeToggleButton(),
          IconButton(
            icon: const Icon(Icons.menu_rounded, color: kGold),
            tooltip: 'Menu',
            onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
          ),
        ],
      ),
      endDrawer: MinerDrawer(
        currentMenu: MinerMenu.transactionHistory,
        minerName: 'Miner',
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: kGold))
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Text(
                      'Transaction History',
                      style: TextStyle(
                        color: context.textColor,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Complete financial log of all your payments and invoices',
                      style: TextStyle(
                        color: context.mutedTextColor,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Filter chips
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildFilterChip('All'),
                          const SizedBox(width: 8),
                          _buildFilterChip('Payment'),
                          const SizedBox(width: 8),
                          _buildFilterChip('Invoice'),
                          const SizedBox(width: 8),
                          _buildFilterChip('Gold Sale'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Summary card
                    _buildSummaryCard(
                      totalPayments,
                      totalInvoices,
                      totalGoldSales,
                    ),
                    const SizedBox(height: 24),

                    // Transaction list
                    if (txns.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(40),
                          child: Column(
                            children: [
                              Icon(
                                Icons.history_rounded,
                                size: 48,
                                color: context.mutedTextColor.withValues(alpha: 0.3),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _selectedFilter == 'All'
                                    ? 'No transactions yet.'
                                    : 'No "$_selectedFilter" transactions found.',
                                style: TextStyle(
                                  color: context.mutedTextColor,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      ...txns.map((txn) => _buildTransactionCard(txn)),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildFilterChip(String label) {
    final bool selected = _selectedFilter == label;
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (bool selected) {
        setState(() {
          _selectedFilter = selected ? label : 'All';
        });
      },
      backgroundColor: context.surfaceColor,
      selectedColor: kGold.withValues(alpha: 0.2),
      labelStyle: TextStyle(
        color: selected ? kGold : context.textColor,
        fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
      ),
      checkmarkColor: kGold,
      side: BorderSide(color: kGold.withValues(alpha: 0.3)),
    );
  }

  Widget _buildSummaryCard(
    double totalPayments,
    double totalInvoices,
    double totalGoldSales,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kGold.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildSummaryItem(
                'Total Paid',
                'P ${NumberFormat('#,##0').format(totalPayments)}',
                Colors.green,
              ),
              _buildSummaryItem(
                'Total Billed',
                'P ${NumberFormat('#,##0').format(totalInvoices)}',
                kGold,
              ),
              _buildSummaryItem(
                'Gold Sales',
                'P ${NumberFormat('#,##0').format(totalGoldSales)}',
                Colors.blue,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: context.mutedTextColor,
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _buildTransactionCard(Map<String, dynamic> txn) {
    final String type = txn['type'];
    final double amount = txn['amount'] as double;
    final bool isPositive = amount > 0;
    final Color typeColor = _getTypeColor(type);
    final Color amountColor = isPositive ? Colors.green : kGold;
    final DateTime date = txn['date'] is DateTime
        ? txn['date']
        : DateTime.now();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kGold.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: typeColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _getTypeIcon(type),
              color: typeColor,
              size: 22,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  txn['description'],
                  style: TextStyle(
                    color: context.textColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      txn['id'],
                      style: TextStyle(
                        color: context.mutedTextColor,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: typeColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        type,
                        style: TextStyle(
                          color: typeColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${isPositive ? '+' : ''}P ${NumberFormat('#,##0.00').format(amount.abs())}',
                style: TextStyle(
                  color: amountColor,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                DateFormat('MMM dd, yyyy').format(date),
                style: TextStyle(
                  color: context.mutedTextColor,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'Payment':
        return Icons.payment_outlined;
      case 'Invoice':
        return Icons.receipt_long_outlined;
      case 'Gold Sale':
        return Icons.auto_awesome;
      default:
        return Icons.account_balance_wallet_outlined;
    }
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'Payment':
        return Colors.green;
      case 'Invoice':
        return kGold;
      case 'Gold Sale':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  Widget _buildLogoMark() {    return Image.asset(
      'assets/img/EGReS.png',
      width: 34,
      height: 34,
      fit: BoxFit.contain,
    );
  }
}
