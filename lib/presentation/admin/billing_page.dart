import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../shared_widgets/appColor.dart';
import '../shared_widgets/themeToggleButton.dart';
import '../shared_widgets/adminDrawer.dart';

class BillingPage extends StatefulWidget {
  const BillingPage({super.key});

  @override
  State<BillingPage> createState() => _BillingPageState();
}

class _BillingPageState extends State<BillingPage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _searchController = TextEditingController();
  String _filterStatus = 'All';

  final List<Map<String, dynamic>> _invoices = [
    {
      'id': 'INV-001',
      'client': 'Juan Dela Cruz',
      'amount': 15000.0,
      'date': '2026-08-10',
      'status': 'Paid',
    },
    {
      'id': 'INV-002',
      'client': 'Maria Clara',
      'amount': 8500.50,
      'date': '2026-08-12',
      'status': 'Pending',
    },
    {
      'id': 'INV-003',
      'client': 'Sisa Millers',
      'amount': 22000.0,
      'date': '2026-08-05',
      'status': 'Overdue',
    },
    {
      'id': 'INV-004',
      'client': 'Crisostomo Ibarra',
      'amount': 12300.75,
      'date': '2026-08-13',
      'status': 'Pending',
    },
  ];

  List<Map<String, dynamic>> get _filteredInvoices {
    return _invoices.where((inv) {
      final matchesSearch = inv['client'].toLowerCase().contains(_searchController.text.toLowerCase()) ||
          inv['id'].toLowerCase().contains(_searchController.text.toLowerCase());
      final matchesStatus = _filterStatus == 'All' || inv['status'] == _filterStatus;
      return matchesSearch && matchesStatus;
    }).toList();
  }

  double get _totalBilled => _invoices.fold(0, (sum, item) => sum + item['amount']);
  double get _totalCollected => _invoices
      .where((inv) => inv['status'] == 'Paid')
      .fold(0, (sum, item) => sum + item['amount']);
  double get _totalPending => _invoices
      .where((inv) => inv['status'] != 'Paid')
      .fold(0, (sum, item) => sum + item['amount']);

  void _markAsPaid(String id) {
    setState(() {
      final index = _invoices.indexWhere((inv) => inv['id'] == id);
      if (index != -1) {
        _invoices[index]['status'] = 'Paid';
      }
    });
  }

  Future<void> _printReceipt(Map<String, dynamic> inv) async {
    final doc = pw.Document();
    final format = NumberFormat.currency(symbol: 'PHP ', decimalDigits: 2);

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Padding(
            padding: const pw.EdgeInsets.all(32),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Header
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('GAHIRA BALL MILL',
                            style: pw.TextStyle(
                                fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColors.amber900)),
                        pw.Text('Management System - Official Receipt',
                            style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text('Receipt No: ${inv['id']}',
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        pw.Text('Date: ${DateFormat('MMMM d, yyyy').format(DateTime.parse(inv['date']))}'),
                      ],
                    ),
                  ],
                ),
                pw.SizedBox(height: 40),
                pw.Divider(),
                pw.SizedBox(height: 20),

                // Client Info
                pw.Text('BILL TO:',
                    style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
                pw.Text(inv['client'], style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 40),

                // Table Header
                pw.Container(
                  color: PdfColors.grey200,
                  padding: const pw.EdgeInsets.all(8),
                  child: pw.Row(
                    children: [
                      pw.Expanded(
                          flex: 3,
                          child: pw.Text('Description', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                      pw.Expanded(
                          flex: 1,
                          child: pw.Text('Amount',
                              textAlign: pw.TextAlign.right, style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                    ],
                  ),
                ),

                // Table Content
                pw.Container(
                  padding: const pw.EdgeInsets.all(8),
                  child: pw.Row(
                    children: [
                      pw.Expanded(flex: 3, child: pw.Text('Mill Operations Service Fee')),
                      pw.Expanded(
                          flex: 1, child: pw.Text(format.format(inv['amount']), textAlign: pw.TextAlign.right)),
                    ],
                  ),
                ),
                pw.Divider(),

                // Total
                pw.SizedBox(height: 20),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.end,
                  children: [
                    pw.Text('TOTAL: ', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                    pw.Text(format.format(inv['amount']),
                        style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.amber900)),
                  ],
                ),

                pw.Spacer(),

                // Footer
                pw.Divider(),
                pw.SizedBox(height: 10),
                pw.Center(
                  child: pw.Column(
                    children: [
                      pw.Text('Thank you for choosing Gahira Ball Mill Services!',
                          style: pw.TextStyle(fontStyle: pw.FontStyle.italic)),
                      pw.Text('This is a computer-generated receipt.',
                          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey)),
                    ],
                  ),
                ),
                if (inv['status'] == 'Paid')
                  pw.Align(
                    alignment: pw.Alignment.centerRight,
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(8),
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: PdfColors.green, width: 2),
                      ),
                      child: pw.Text('PAID',
                          style: pw.TextStyle(fontSize: 20, color: PdfColors.green, fontWeight: pw.FontWeight.bold)),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => doc.save());
  }

  void _showCreateInvoiceDialog() {
    final clientController = TextEditingController();
    final amountController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.surfaceColor,
        title: const Text('Create New Invoice', style: TextStyle(color: kGold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: clientController,
              style: TextStyle(color: context.textColor),
              decoration: InputDecoration(
                labelText: 'Client Name',
                labelStyle: TextStyle(color: context.mutedTextColor),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: kGold.withValues(alpha: 0.5))),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              style: TextStyle(color: context.textColor),
              decoration: InputDecoration(
                labelText: 'Amount (PHP)',
                labelStyle: TextStyle(color: context.mutedTextColor),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: kGold.withValues(alpha: 0.5))),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: kGold),
            onPressed: () {
              if (clientController.text.isNotEmpty && amountController.text.isNotEmpty) {
                setState(() {
                  final newId = 'INV-00${_invoices.length + 1}';
                  _invoices.insert(0, {
                    'id': newId,
                    'client': clientController.text,
                    'amount': double.tryParse(amountController.text) ?? 0.0,
                    'date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
                    'status': 'Pending',
                  });
                });
                Navigator.pop(context);
              }
            },
            child: const Text('Create', style: TextStyle(color: kBlack)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(symbol: '₱', decimalDigits: 2);

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
          'GAHIRA BILLING',
          style: TextStyle(
            color: kGold,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
            fontSize: 16,
          ),
        ),
        iconTheme: const IconThemeData(color: kGold),
        actions: [
          const ThemeToggleButton(),
          IconButton(
            icon: const Icon(Icons.menu_rounded, color: kGold),
            onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
          ),
        ],
      ),
      endDrawer: const AdminDrawer(currentMenu: AdminMenu.billing),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Summary Row ---
            Row(
              children: [
                Expanded(
                  child: _buildSummaryCard(
                    'TOTAL BILLED',
                    currencyFormat.format(_totalBilled),
                    Icons.account_balance_wallet_outlined,
                    kGold,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildSummaryCard(
                    'COLLECTED',
                    currencyFormat.format(_totalCollected),
                    Icons.check_circle_outline,
                    Colors.green,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildSummaryCard(
                    'PENDING',
                    currencyFormat.format(_totalPending),
                    Icons.pending_actions_outlined,
                    Colors.orange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),

            // --- Filters and Search ---
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: (v) => setState(() {}),
                    style: TextStyle(color: context.textColor),
                    decoration: InputDecoration(
                      hintText: 'Search client or invoice ID...',
                      hintStyle: TextStyle(color: context.mutedTextColor, fontSize: 13),
                      prefixIcon: const Icon(Icons.search, color: kGold, size: 20),
                      filled: true,
                      fillColor: context.surfaceColor,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: kGold.withValues(alpha: 0.2)),
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: context.surfaceColor,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: kGold.withValues(alpha: 0.2)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _filterStatus,
                      dropdownColor: context.surfaceColor,
                      style: TextStyle(color: context.textColor, fontSize: 13),
                      items: ['All', 'Paid', 'Pending', 'Overdue']
                          .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                          .toList(),
                      onChanged: (v) => setState(() => _filterStatus = v!),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // --- Invoice List ---
            Text(
              'RECENT INVOICES',
              style: TextStyle(
                color: kGold,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 12),
            _filteredInvoices.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 40),
                      child: Text('No invoices found.', style: TextStyle(color: context.mutedTextColor)),
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _filteredInvoices.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final inv = _filteredInvoices[index];
                      return _buildInvoiceTile(context, inv, currencyFormat);
                    },
                  ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateInvoiceDialog,
        backgroundColor: kGold,
        child: const Icon(Icons.add, color: kBlack),
      ),
    );
  }

  Widget _buildSummaryCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 12),
          Text(
            label,
            style: TextStyle(color: context.mutedTextColor, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.5),
          ),
          const SizedBox(height: 4),
          FittedBox(
            child: Text(
              value,
              style: TextStyle(color: context.textColor, fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInvoiceTile(BuildContext context, Map<String, dynamic> inv, NumberFormat format) {
    final status = inv['status'] as String;
    Color statusColor;
    switch (status) {
      case 'Paid':
        statusColor = Colors.green;
        break;
      case 'Overdue':
        statusColor = Colors.redAccent;
        break;
      default:
        statusColor = Colors.orange;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kGold.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      inv['id'],
                      style: const TextStyle(color: kGold, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        status.toUpperCase(),
                        style: TextStyle(color: statusColor, fontSize: 9, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  inv['client'],
                  style: TextStyle(color: context.textColor, fontWeight: FontWeight.w600, fontSize: 15),
                ),
                Text(
                  DateFormat('MMMM d, yyyy').format(DateTime.parse(inv['date'])),
                  style: TextStyle(color: context.mutedTextColor, fontSize: 11),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                format.format(inv['amount']),
                style: TextStyle(color: context.textColor, fontWeight: FontWeight.bold, fontSize: 15),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.print_outlined, color: kGold, size: 20),
                    tooltip: 'Print Receipt',
                    onPressed: () => _printReceipt(inv),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  if (status != 'Paid') ...[
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () => _markAsPaid(inv['id']),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(0, 0),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text(
                        'Mark Paid',
                        style: TextStyle(color: kGold, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ],
              ),
            ],
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
      child: const Icon(Icons.settings_input_component_rounded, color: kGold, size: 16),
    );
  }
}
