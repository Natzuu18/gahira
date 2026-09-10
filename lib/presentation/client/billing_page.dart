import 'package:flutter/material.dart';

import '../shared_widgets/appColor.dart';
import '../shared_widgets/themeToggleButton.dart';
import 'client_drawer.dart';

// Gahira Ball Mill Management System - Billing Page
// Clients can view their bills, make payments, and view payment history

class BillingPage extends StatefulWidget {
  const BillingPage({super.key});

  @override
  State<BillingPage> createState() => _BillingPageState();
}

class _BillingPageState extends State<BillingPage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  final List<Map<String, dynamic>> _mockBills = [
    {
      'id': 'INV-2024-008',
      'requestId': 'REQ-2024-015',
      'title': 'Gold Ore Processing',
      'amount': 25000.00,
      'dueDate': '2024-01-25',
      'status': 'Unpaid',
      'issueDate': '2024-01-15',
    },
    {
      'id': 'INV-2024-007',
      'requestId': 'REQ-2024-012',
      'title': 'Gold Ore Processing',
      'amount': 18500.00,
      'dueDate': '2024-01-15',
      'status': 'Paid',
      'issueDate': '2024-01-10',
      'paidDate': '2024-01-14',
    },
    {
      'id': 'INV-2024-006',
      'requestId': 'REQ-2024-011',
      'title': 'Mixed Metal Processing',
      'amount': 32000.00,
      'dueDate': '2024-01-10',
      'status': 'Paid',
      'issueDate': '2024-01-05',
      'paidDate': '2024-01-09',
    },
    {
      'id': 'INV-2024-005',
      'requestId': 'REQ-2024-010',
      'title': 'Gold Ore Processing',
      'amount': 21000.00,
      'dueDate': '2024-01-28',
      'status': 'Unpaid',
      'issueDate': '2024-01-18',
    },
    {
      'id': 'INV-2024-004',
      'requestId': 'REQ-2024-009',
      'title': 'Silver Refining',
      'amount': 15000.00,
      'dueDate': '2024-01-30',
      'status': 'Unpaid',
      'issueDate': '2024-01-20',
    },
  ];

  @override
  Widget build(BuildContext context) {
    final unpaidBills = _mockBills.where((b) => b['status'] == 'Unpaid').toList();
    final paidBills = _mockBills.where((b) => b['status'] == 'Paid').toList();
    final totalDue = unpaidBills.fold<double>(0.0, (sum, bill) => sum + bill['amount']);
    final totalPaid = paidBills.fold<double>(0.0, (sum, bill) => sum + bill['amount']);

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
        currentMenu: ClientMenu.billing,
        clientName: 'Client',
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Text(
              'Billing',
              style: TextStyle(
                color: context.textColor,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'View and manage your invoices and payments',
              style: TextStyle(
                color: context.mutedTextColor,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),

            // Summary Cards
            Row(
              children: [
                Expanded(
                  child: _buildSummaryCard(
                    'Total Due',
                    '₱${totalDue.toStringAsFixed(2)}',
                    Icons.account_balance_wallet_outlined,
                    Colors.orange,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildSummaryCard(
                    'Total Paid',
                    '₱${totalPaid.toStringAsFixed(2)}',
                    Icons.check_circle_outline,
                    Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // Unpaid Bills Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Unpaid Bills (${unpaidBills.length})',
                  style: TextStyle(
                    color: context.textColor,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (unpaidBills.isNotEmpty)
                  ElevatedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.payment, size: 18),
                    label: const Text('Pay All'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kGold,
                      foregroundColor: kBlack,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (unpaidBills.isEmpty)
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: context.surfaceColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: kGold.withOpacity(0.1)),
                ),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.check_circle_outline, 
                          color: Colors.green, size: 48),
                      const SizedBox(height: 16),
                      Text(
                        'All caught up!',
                        style: TextStyle(
                          color: context.textColor,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'You have no unpaid bills',
                        style: TextStyle(
                          color: context.mutedTextColor,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              ...unpaidBills.map((bill) => _buildBillCard(bill)),

            const SizedBox(height: 32),

            // Paid Bills Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Payment History (${paidBills.length})',
                  style: TextStyle(
                    color: context.textColor,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton(
                  onPressed: () {},
                  child: const Text('View All', style: TextStyle(color: kGold)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...paidBills.take(3).map((bill) => _buildBillCard(bill)),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kGold.withOpacity(0.1)),
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
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              color: context.mutedTextColor,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBillCard(Map<String, dynamic> bill) {
    final bool isPaid = bill['status'] == 'Paid';
    final Color statusColor = isPaid ? Colors.green : Colors.orange;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kGold.withOpacity(0.1)),
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
                  color: statusColor.withOpacity(0.1),
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
                      bill['title'],
                      style: TextStyle(
                        color: context.textColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      bill['id'],
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
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  bill['status'],
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
              _buildDetailItem('Issue Date', bill['issueDate']),
              _buildDetailItem('Due Date', bill['dueDate']),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Amount',
                style: TextStyle(
                  color: context.mutedTextColor,
                  fontSize: 12,
                ),
              ),
              Text(
                '₱${bill['amount'].toStringAsFixed(2)}',
                style: TextStyle(
                  color: kGold,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          if (isPaid && bill.containsKey('paidDate'))
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 14),
                  const SizedBox(width: 6),
                  Text(
                    'Paid on ${bill['paidDate']}',
                    style: TextStyle(
                      color: Colors.green,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 16),
          if (!isPaid)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _showPaymentDialog(bill),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kGold,
                  foregroundColor: kBlack,
                ),
                child: const Text('Pay Now'),
              ),
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

  void _showPaymentDialog(Map<String, dynamic> bill) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.surfaceColor,
        title: Text(
          'Make Payment',
          style: TextStyle(color: context.textColor),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Invoice: ${bill['id']}',
              style: TextStyle(
                color: context.textColor,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Amount: ₱${bill['amount'].toStringAsFixed(2)}',
              style: TextStyle(
                color: kGold,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'This is a placeholder for the payment form.',
              style: TextStyle(color: context.mutedTextColor),
            ),
            const SizedBox(height: 8),
            _buildPlaceholderItem('Payment method selection'),
            _buildPlaceholderItem('Card details or bank transfer'),
            _buildPlaceholderItem('Confirmation'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel', style: TextStyle(color: kGold)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Payment processed successfully!'),
                  backgroundColor: Colors.green,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: kGold,
              foregroundColor: kBlack,
            ),
            child: const Text('Confirm Payment'),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholderItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, bottom: 4),
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline, color: kGold, size: 16),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(color: context.mutedTextColor, fontSize: 13),
          ),
        ],
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
