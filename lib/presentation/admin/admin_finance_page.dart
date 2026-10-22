import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../domain/entities/service_request_entity.dart';
import '../../infrastructure/repositories/supabase_service_request_repository.dart';
import '../shared_widgets/appColor.dart';
import '../shared_widgets/themeToggleButton.dart';
import 'billing_page.dart';
import 'expenses_page.dart';
import 'gold_transactions_page.dart';
import 'payments_history_page.dart';
import 'report_page.dart';

class AdminFinancePage extends StatefulWidget {
  const AdminFinancePage({super.key});

  @override
  State<AdminFinancePage> createState() => _AdminFinancePageState();
}

class _AdminFinancePageState extends State<AdminFinancePage> {
  final _repository = SupabaseServiceRequestRepository();
  bool _showBalance = false;
  bool _loading = true;
  int _assessmentCount = 0;
  int _settlementCount = 0;
  double _totalBills = 0;

  @override
  void initState() {
    super.initState();
    _loadFinancialSummary();
  }

  Future<void> _loadFinancialSummary() async {
    final result = await _repository.getServiceRequests();
    if (!mounted) return;
    result.fold(
      (_) => setState(() => _loading = false),
      (requests) {
        final assess = requests.where(
          (request) => request.status == ServiceRequestStatus.processingCompleted,
        );
        final settlements = requests.where(
          (request) =>
              request.status == ServiceRequestStatus.goldHandoff ||
              request.status == ServiceRequestStatus.partiallyPaid,
        );
        setState(() {
          _assessmentCount = assess.length;
          _settlementCount = settlements.length;
          _totalBills = requests.fold<double>(
            0,
            (sum, request) => sum + (request.financialDetails?.totalBill ?? 0),
          );
          _loading = false;
        });
      },
    );
  }

  void _open(BuildContext context, Widget page) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bgColor,
      appBar: AppBar(
        backgroundColor: context.surfaceColor,
        elevation: 0,
        title: const Text(
          'FINANCE',
          style: TextStyle(
            color: kGold,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
            fontSize: 16,
          ),
        ),
        actions: const [ThemeToggleButton()],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Financial Management',
            style: TextStyle(
              color: context.textColor,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Manage service billing, payments, gold transactions, and expenses.',
            style: TextStyle(color: context.mutedTextColor, fontSize: 14),
          ),
          const SizedBox(height: 24),
          _buildMoneyPreview(context),
          const SizedBox(height: 20),
          _FinanceOption(
            icon: Icons.receipt_long_outlined,
            title: 'Billing & Settlement',
            subtitle: 'Prepare service bills and manage settlement balances.',
            indicators: [
              if (_assessmentCount > 0) 'Assess $_assessmentCount',
              if (_settlementCount > 0) 'Settle $_settlementCount',
            ],
            onTap: () => _open(context, const BillingPage()),
          ),
          _FinanceOption(
            icon: Icons.payments_outlined,
            title: 'Payment History',
            subtitle: 'Review payment activity and recorded transactions.',
            onTap: () => _open(context, const PaymentsHistoryPage()),
          ),
          _FinanceOption(
            icon: Icons.monetization_on_outlined,
            title: 'Gold Transactions',
            subtitle: 'Review gold purchases, weights, and values.',
            onTap: () => _open(context, const GoldTransactionsPage()),
          ),
          _FinanceOption(
            icon: Icons.trending_down_rounded,
            title: 'Expenses',
            subtitle: 'Track service expenses and refinery overhead.',
            onTap: () => _open(context, const ExpensesPage()),
          ),
          _FinanceOption(
            icon: Icons.analytics_outlined,
            title: 'Financial Reports',
            subtitle: 'View and export finance and operations reports.',
            onTap: () => _open(context, const ReportPage()),
          ),
        ],
      ),
    );
  }

  Widget _buildMoneyPreview(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF98702A), Color(0xFF604515)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('Total bills', style: TextStyle(color: Colors.white70)),
              ),
              IconButton(
                tooltip: _showBalance ? 'Hide amount' : 'Show amount',
                onPressed: () => setState(() => _showBalance = !_showBalance),
                icon: Icon(
                  _showBalance ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          if (_loading)
            const Text(
              'Loading…',
              style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
            )
          else if (_showBalance)
            TweenAnimationBuilder<double>(
              key: const ValueKey('total-bills-count-up'),
              tween: Tween<double>(begin: 0, end: _totalBills),
              duration: const Duration(milliseconds: 1600),
              curve: Curves.easeOutCubic,
              builder: (context, value, _) => Text(
                NumberFormat.currency(symbol: '₱', decimalDigits: 2).format(value),
                style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
              ),
            )
          else
            const Text(
              '₱ ••••••',
              style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
            ),
          const SizedBox(height: 4),
          Text(
            'Combined billed amount across service requests',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _FinanceOption extends StatelessWidget {
  const _FinanceOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.indicators = const [],
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final List<String> indicators;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: context.surfaceColor,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: kGold.withValues(alpha: 0.15)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Icon(icon, color: kGold, size: 26),
        title: Text(
          title,
          style: TextStyle(
            color: context.textColor,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(color: context.mutedTextColor, fontSize: 12),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final indicator in indicators) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  indicator,
                  style: const TextStyle(color: Colors.deepOrange, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 4),
            ],
            const Icon(Icons.chevron_right_rounded, color: kGold),
          ],
        ),
        onTap: onTap,
      ),
    );
  }
}

