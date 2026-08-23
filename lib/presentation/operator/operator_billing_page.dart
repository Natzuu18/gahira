import 'package:flutter/material.dart';

import '../shared_widgets/appColor.dart';
import '../shared_widgets/themeToggleButton.dart';
import 'operator_drawer.dart';

class OperatorBillingPage extends StatefulWidget {
  const OperatorBillingPage({super.key});

  @override
  State<OperatorBillingPage> createState() => _OperatorBillingPageState();
}

class _OperatorBillingPageState extends State<OperatorBillingPage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // Mock data
  final List<Map<String, dynamic>> _invoices = [
    {
      'id': 'INV-001',
      'clientId': 'CL-001',
      'clientName': 'ABC Mining Corp',
      'jobId': 'JOB-001',
      'serviceType': 'Gold Processing',
      'quantity': '500 kg',
      'rate': '₱100/kg',
      'amount': '₱50,000',
      'status': 'Paid',
      'invoiceDate': '2024-01-15',
      'dueDate': '2024-01-22',
    },
    {
      'id': 'INV-002',
      'clientId': 'CL-002',
      'clientName': 'Gold Corp Ltd',
      'jobId': 'JOB-002',
      'serviceType': 'Gold Processing',
      'quantity': '300 kg',
      'rate': '₱100/kg',
      'amount': '₱30,000',
      'status': 'Pending',
      'invoiceDate': '2024-01-16',
      'dueDate': '2024-01-23',
    },
    {
      'id': 'INV-003',
      'clientId': 'CL-001',
      'clientName': 'ABC Mining Corp',
      'jobId': 'JOB-003',
      'serviceType': 'Gold Processing',
      'quantity': '750 kg',
      'rate': '₱100/kg',
      'amount': '₱75,000',
      'status': 'Overdue',
      'invoiceDate': '2024-01-10',
      'dueDate': '2024-01-17',
    },
  ];

  final List<Map<String, dynamic>> _payments = [
    {
      'id': 'PAY-001',
      'invoiceId': 'INV-001',
      'clientName': 'ABC Mining Corp',
      'amount': '₱50,000',
      'paymentMethod': 'Bank Transfer',
      'paymentDate': '2024-01-18',
      'reference': 'REF-12345',
      'status': 'Completed',
    },
    {
      'id': 'PAY-002',
      'invoiceId': 'INV-004',
      'clientName': 'Silver Mining Co',
      'amount': '₱25,000',
      'paymentMethod': 'Cash',
      'paymentDate': '2024-01-15',
      'reference': 'CASH-67890',
      'status': 'Completed',
    },
  ];

  final List<Map<String, dynamic>> _expenses = [
    {
      'id': 'EXP-001',
      'category': 'Material',
      'description': 'Cyanide Purchase',
      'amount': '₱50,000',
      'date': '2024-01-10',
      'approvedBy': 'Admin',
    },
    {
      'id': 'EXP-002',
      'category': 'Maintenance',
      'description': 'Mill #02 Bearing Replacement',
      'amount': '₱15,000',
      'date': '2024-01-12',
      'approvedBy': 'Admin',
    },
    {
      'id': 'EXP-003',
      'category': 'Utilities',
      'description': 'Electricity Bill',
      'amount': '₱20,000',
      'date': '2024-01-15',
      'approvedBy': 'Admin',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
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
            'BILLING',
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
              icon: const Icon(Icons.add_rounded, color: kGold),
              onPressed: _showCreateInvoiceDialog,
              tooltip: 'Create Invoice',
            ),
            const ThemeToggleButton(),
            IconButton(
              icon: const Icon(Icons.menu_rounded, color: kGold),
              tooltip: 'Menu',
              onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
            ),
          ],
          bottom: TabBar(
            labelColor: kGold,
            unselectedLabelColor: context.mutedTextColor,
            indicatorColor: kGold,
            tabs: const [
              Tab(text: 'Invoices'),
              Tab(text: 'Payments'),
              Tab(text: 'Expenses'),
            ],
          ),
        ),
        endDrawer: const OperatorDrawer(
          currentMenu: OperatorMenu.billing,
          operatorName: 'Operator',
        ),
        body: TabBarView(
          children: [
            _buildInvoicesTab(),
            _buildPaymentsTab(),
            _buildExpensesTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildInvoicesTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 1.6,
            children: [
              _buildSummaryCard('Total Invoices', '3', Icons.receipt_long_rounded, kGold),
              _buildSummaryCard('Paid', '1', Icons.check_circle_outline_rounded, Colors.green),
              _buildSummaryCard('Pending', '1', Icons.pending_rounded, Colors.orange),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Invoices',
                style: TextStyle(
                  color: context.textColor,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_rounded, color: Colors.red, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      '1 Overdue',
                      style: TextStyle(
                        color: Colors.red,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ..._invoices.map((invoice) => _buildInvoiceCard(invoice)),
        ],
      ),
    );
  }

  Widget _buildPaymentsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 1.6,
            children: [
              _buildSummaryCard('Total Collected', '₱75,000', Icons.payments_rounded, kGold),
              _buildSummaryCard('This Month', '₱75,000', Icons.calendar_today_rounded, Colors.green),
              _buildSummaryCard('Transactions', '2', Icons.receipt_rounded, Colors.blue),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Payment Records',
                style: TextStyle(
                  color: context.textColor,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              ElevatedButton.icon(
                onPressed: _showRecordPaymentDialog,
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('Record Payment'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kGold,
                  foregroundColor: kBlack,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ..._payments.map((payment) => _buildPaymentCard(payment)),
        ],
      ),
    );
  }

  Widget _buildExpensesTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 1.6,
            children: [
              _buildSummaryCard('Total Expenses', '₱85,000', Icons.money_off_rounded, kGold),
              _buildSummaryCard('This Month', '₱85,000', Icons.calendar_today_rounded, Colors.orange),
              _buildSummaryCard('Categories', '3', Icons.category_rounded, Colors.blue),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Expense Records',
                style: TextStyle(
                  color: context.textColor,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              ElevatedButton.icon(
                onPressed: _showAddExpenseDialog,
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('Add Expense'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kGold,
                  foregroundColor: kBlack,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ..._expenses.map((expense) => _buildExpenseCard(expense)),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kGold.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: color, size: 24),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  color: context.textColor,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                title,
                style: TextStyle(
                  color: context.mutedTextColor,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInvoiceCard(Map<String, dynamic> invoice) {
    final status = invoice['status'];
    final statusColor = status == 'Paid'
        ? Colors.green
        : (status == 'Overdue' ? Colors.red : Colors.orange);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kGold.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.receipt_long_rounded, color: statusColor, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      invoice['clientName'],
                      style: TextStyle(
                        color: context.textColor,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      invoice['serviceType'],
                      style: TextStyle(
                        color: context.mutedTextColor,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: statusColor.withOpacity(0.3)),
                ),
                child: Text(
                  status,
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
          Row(
            children: [
              _buildInfoChip('ID', invoice['id']),
              const SizedBox(width: 8),
              _buildInfoChip('Job', invoice['jobId']),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildInfoChip('Qty', invoice['quantity']),
              const SizedBox(width: 8),
              _buildInfoChip('Rate', invoice['rate']),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total Amount',
                style: TextStyle(
                  color: context.mutedTextColor,
                  fontSize: 12,
                ),
              ),
              Text(
                invoice['amount'],
                style: TextStyle(
                  color: kGold,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildInfoChip('Invoice Date', invoice['invoiceDate']),
              const SizedBox(width: 8),
              _buildInfoChip('Due Date', invoice['dueDate']),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _viewInvoiceDetails(invoice),
                  icon: const Icon(Icons.visibility_outlined, size: 16),
                  label: const Text('Details'),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: kGold.withOpacity(0.3)),
                    foregroundColor: context.textColor,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (status == 'Pending' || status == 'Overdue')
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _recordPaymentForInvoice(invoice),
                    icon: const Icon(Icons.payment_rounded, size: 16),
                    label: const Text('Record Payment'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kGold,
                      foregroundColor: kBlack,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentCard(Map<String, dynamic> payment) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kGold.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.payments_rounded, color: Colors.green, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      payment['clientName'],
                      style: TextStyle(
                        color: context.textColor,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      payment['paymentMethod'],
                      style: TextStyle(
                        color: context.mutedTextColor,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                payment['amount'],
                style: TextStyle(
                  color: kGold,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildInfoChip('ID', payment['id']),
              const SizedBox(width: 8),
              _buildInfoChip('Invoice', payment['invoiceId']),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildInfoChip('Date', payment['paymentDate']),
              const SizedBox(width: 8),
              _buildInfoChip('Reference', payment['reference']),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildExpenseCard(Map<String, dynamic> expense) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kGold.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.money_off_rounded, color: Colors.orange, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      expense['description'],
                      style: TextStyle(
                        color: context.textColor,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      expense['category'],
                      style: TextStyle(
                        color: context.mutedTextColor,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                expense['amount'],
                style: TextStyle(
                  color: Colors.red,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildInfoChip('ID', expense['id']),
              const SizedBox(width: 8),
              _buildInfoChip('Date', expense['date']),
              const SizedBox(width: 8),
              _buildInfoChip('Approved By', expense['approvedBy']),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: kGold.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: kGold.withOpacity(0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              color: context.mutedTextColor,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: context.textColor,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
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

  void _showCreateInvoiceDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.surfaceColor,
        title: Text(
          'Create Invoice',
          style: TextStyle(color: context.textColor),
        ),
        content: const Text('Invoice creation form - UI only (no backend)'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: kGold),
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Invoice created (mock)'),
                  backgroundColor: kGold,
                ),
              );
            },
            child: const Text('Create', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showRecordPaymentDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.surfaceColor,
        title: Text(
          'Record Payment',
          style: TextStyle(color: context.textColor),
        ),
        content: const Text('Payment recording form - UI only (no backend)'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: kGold),
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Payment recorded (mock)'),
                  backgroundColor: kGold,
                ),
              );
            },
            child: const Text('Record', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showAddExpenseDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.surfaceColor,
        title: Text(
          'Add Expense',
          style: TextStyle(color: context.textColor),
        ),
        content: const Text('Expense recording form - UI only (no backend)'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: kGold),
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Expense added (mock)'),
                  backgroundColor: kGold,
                ),
              );
            },
            child: const Text('Add', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _viewInvoiceDetails(Map<String, dynamic> invoice) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.surfaceColor,
        title: Text(
          'Invoice Details: ${invoice['id']}',
          style: TextStyle(color: context.textColor),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('Client', invoice['clientName']),
              _buildDetailRow('Job ID', invoice['jobId']),
              _buildDetailRow('Service Type', invoice['serviceType']),
              _buildDetailRow('Quantity', invoice['quantity']),
              _buildDetailRow('Rate', invoice['rate']),
              _buildDetailRow('Amount', invoice['amount']),
              _buildDetailRow('Status', invoice['status']),
              _buildDetailRow('Invoice Date', invoice['invoiceDate']),
              _buildDetailRow('Due Date', invoice['dueDate']),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: Colors.grey)),
          ),
        ],
      ),
    );
  }

  void _recordPaymentForInvoice(Map<String, dynamic> invoice) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Recording payment for ${invoice['id']} (mock)'),
        backgroundColor: kGold,
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: TextStyle(
                color: context.mutedTextColor,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: context.textColor,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
