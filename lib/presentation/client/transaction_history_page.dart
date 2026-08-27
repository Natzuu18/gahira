import 'package:flutter/material.dart';

import '../shared_widgets/appColor.dart';
import '../shared_widgets/themeToggleButton.dart';
import 'client_drawer.dart';

// Gahira Ball Mill Management System - Transaction History Page
// Clients can view their complete financial transaction history

class TransactionHistoryPage extends StatefulWidget {
  const TransactionHistoryPage({super.key});

  @override
  State<TransactionHistoryPage> createState() => _TransactionHistoryPageState();
}

class _TransactionHistoryPageState extends State<TransactionHistoryPage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  String _selectedFilter = 'All';

  final List<Map<String, dynamic>> _mockTransactions = [
    {
      'id': 'TXN-2024-025',
      'type': 'Payment',
      'description': 'Payment for INV-2024-007',
      'amount': 18500.00,
      'date': '2024-01-14',
      'status': 'Completed',
    },
    {
      'id': 'TXN-2024-024',
      'type': 'Payment',
      'description': 'Payment for INV-2024-006',
      'amount': 32000.00,
      'date': '2024-01-09',
      'status': 'Completed',
    },
    {
      'id': 'TXN-2024-023',
      'type': 'Invoice',
      'description': 'Invoice for REQ-2024-015',
      'amount': -25000.00,
      'date': '2024-01-15',
      'status': 'Pending',
    },
    {
      'id': 'TXN-2024-022',
      'type': 'Payment',
      'description': 'Payment for INV-2024-005',
      'amount': 21000.00,
      'date': '2024-01-08',
      'status': 'Completed',
    },
    {
      'id': 'TXN-2024-021',
      'type': 'Refund',
      'description': 'Refund for overpayment',
      'amount': 1500.00,
      'date': '2024-01-05',
      'status': 'Completed',
    },
    {
      'id': 'TXN-2024-020',
      'type': 'Invoice',
      'description': 'Invoice for REQ-2024-011',
      'amount': -32000.00,
      'date': '2024-01-05',
      'status': 'Paid',
    },
    {
      'id': 'TXN-2024-019',
      'type': 'Payment',
      'description': 'Payment for INV-2024-004',
      'amount': 15000.00,
      'date': '2024-01-03',
      'status': 'Completed',
    },
    {
      'id': 'TXN-2024-018',
      'type': 'Invoice',
      'description': 'Invoice for REQ-2024-010',
      'amount': -21000.00,
      'date': '2024-01-02',
      'status': 'Paid',
    },
    {
      'id': 'TXN-2024-017',
      'type': 'Payment',
      'description': 'Payment for INV-2024-003',
      'amount': 28000.00,
      'date': '2023-12-28',
      'status': 'Completed',
    },
    {
      'id': 'TXN-2024-016',
      'type': 'Invoice',
      'description': 'Invoice for REQ-2024-009',
      'amount': -15000.00,
      'date': '2023-12-25',
      'status': 'Paid',
    },
    {
      'id': 'TXN-2024-015',
      'type': 'Payment',
      'description': 'Payment for INV-2024-002',
      'amount': 19500.00,
      'date': '2023-12-20',
      'status': 'Completed',
    },
    {
      'id': 'TXN-2024-014',
      'type': 'Invoice',
      'description': 'Invoice for REQ-2024-008',
      'amount': -17500.00,
      'date': '2023-12-18',
      'status': 'Paid',
    },
    {
      'id': 'TXN-2024-013',
      'type': 'Payment',
      'description': 'Payment for INV-2024-001',
      'amount': 22000.00,
      'date': '2023-12-15',
      'status': 'Completed',
    },
    {
      'id': 'TXN-2024-012',
      'type': 'Invoice',
      'description': 'Invoice for REQ-2024-007',
      'amount': -24000.00,
      'date': '2023-12-12',
      'status': 'Paid',
    },
    {
      'id': 'TXN-2024-011',
      'type': 'Payment',
      'description': 'Payment for INV-2023-015',
      'amount': 16500.00,
      'date': '2023-12-10',
      'status': 'Completed',
    },
  ];

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
          'GAHIRA',
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
      endDrawer: const ClientDrawer(
        currentMenu: ClientMenu.transactionHistory,
        clientName: 'Client',
      ),
      body: SingleChildScrollView(
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
              'View all your financial transactions',
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
                  _buildFilterChip('Refund'),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Summary
            _buildSummaryCard(),
            const SizedBox(height: 24),

            // Transaction list
            ..._filteredTransactions.map((txn) => _buildTransactionCard(txn)),
            const SizedBox(height: 24),

            // Export button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.download_outlined),
                label: const Text('Export Transactions'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: kGold,
                  side: BorderSide(color: kGold.withOpacity(0.5)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Map<String, dynamic>> get _filteredTransactions {
    if (_selectedFilter == 'All') return _mockTransactions;
    return _mockTransactions.where((t) => t['type'] == _selectedFilter).toList();
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
      selectedColor: kGold.withOpacity(0.2),
      labelStyle: TextStyle(
        color: selected ? kGold : context.textColor,
        fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
      ),
      checkmarkColor: kGold,
      side: BorderSide(color: kGold.withOpacity(0.3)),
    );
  }

  Widget _buildSummaryCard() {
    final totalPayments = _mockTransactions
        .where((t) => t['type'] == 'Payment' && t['status'] == 'Completed')
        .fold<double>(0.0, (sum, t) => sum + t['amount']);
    final totalInvoices = _mockTransactions
        .where((t) => t['type'] == 'Invoice')
        .fold<double>(0.0, (sum, t) => sum + t['amount'].abs());
    final totalRefunds = _mockTransactions
        .where((t) => t['type'] == 'Refund')
        .fold<double>(0.0, (sum, t) => sum + t['amount']);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kGold.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildSummaryItem('Total Paid', '₱${totalPayments.toStringAsFixed(2)}', Colors.green),
              _buildSummaryItem('Total Billed', '₱${totalInvoices.toStringAsFixed(2)}', kGold),
              _buildSummaryItem('Refunds', '₱${totalRefunds.toStringAsFixed(2)}', Colors.blue),
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
            fontSize: 18,
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
    final double amount = txn['amount'];
    final bool isPositive = amount > 0;
    final Color typeColor = _getTypeColor(type);
    final Color amountColor = isPositive ? Colors.green : kGold;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kGold.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: typeColor.withOpacity(0.1),
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
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: typeColor.withOpacity(0.1),
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
                '${isPositive ? '+' : ''}₱${amount.abs().toStringAsFixed(2)}',
                style: TextStyle(
                  color: amountColor,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                txn['date'],
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
      case 'Refund':
        return Icons.currency_exchange;
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
      case 'Refund':
        return Colors.blue;
      default:
        return Colors.grey;
    }
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
