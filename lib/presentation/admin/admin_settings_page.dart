import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../shared_widgets/appColor.dart';
import '../shared_widgets/themeToggleButton.dart';
import 'gold_transactions_page.dart';
import 'billing_page.dart';
import 'expenses_page.dart';
import 'payments_history_page.dart';
import 'report_page.dart';
import '../../main.dart';

class AdminSettingsPage extends StatefulWidget {
  const AdminSettingsPage({super.key, this.adminName = 'Admin'});

  final String adminName;

  @override
  State<AdminSettingsPage> createState() => _AdminSettingsPageState();
}

class _AdminSettingsPageState extends State<AdminSettingsPage> {
  String _email = '';

  @override
  void initState() {
    super.initState();
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      _email = user.email ?? '';
    }
  }

  void _logout() async {
    await Supabase.instance.client.auth.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
          'USER SETTINGS',
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
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User Header Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: context.surfaceColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: kGold.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: kGold, width: 2),
                      color: context.bgColor,
                    ),
                    child: const Icon(Icons.person, color: kGold, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.adminName,
                          style: TextStyle(
                            color: context.textColor,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (_email.isNotEmpty)
                          Text(
                            _email,
                            style: TextStyle(
                              color: context.mutedTextColor,
                              fontSize: 13,
                            ),
                          ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: kGold.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'Administrator',
                            style: TextStyle(
                              color: kGold,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            _buildSectionHeader('FINANCIAL MANAGEMENT'),
            const SizedBox(height: 8),
            _buildSettingTile(
              icon: Icons.paid_outlined,
              title: 'Gold Transactions',
              subtitle: 'Manage gold purchases and buying prices',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const GoldTransactionsPage()),
              ),
            ),
            _buildSettingTile(
              icon: Icons.receipt_long_outlined,
              title: 'Financial Handling',
              subtitle: 'Invoices, billing, and settlement status',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const BillingPage()),
              ),
            ),
            _buildSettingTile(
              icon: Icons.trending_down_rounded,
              title: 'Refinery Expenses',
              subtitle: 'Track operational expenses and fees',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ExpensesPage()),
              ),
            ),
            _buildSettingTile(
              icon: Icons.payments_outlined,
              title: 'Payment History',
              subtitle: 'View recorded payment transactions',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PaymentsHistoryPage()),
              ),
            ),

            const SizedBox(height: 24),
            _buildSectionHeader('REPORTS & LOGS'),
            const SizedBox(height: 8),
            _buildSettingTile(
              icon: Icons.bar_chart_rounded,
              title: 'Reports & Analytics',
              subtitle: 'Generate system & financial reports',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ReportPage()),
              ),
            ),

            const SizedBox(height: 24),
            _buildSectionHeader('ACCOUNT SECURITY'),
            const SizedBox(height: 8),
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: context.surfaceColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.withOpacity(0.3)),
              ),
              child: ListTile(
                leading: const Icon(Icons.logout_rounded, color: Colors.red),
                title: const Text(
                  'Log Out',
                  style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  'Sign out of your administrator account',
                  style: TextStyle(color: context.mutedTextColor, fontSize: 12),
                ),
                onTap: _logout,
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: TextStyle(
        color: context.mutedTextColor,
        fontSize: 11,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildSettingTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kGold.withOpacity(0.1)),
      ),
      child: ListTile(
        leading: Icon(icon, color: kGold),
        title: Text(
          title,
          style: TextStyle(
            color: context.textColor,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(color: context.mutedTextColor, fontSize: 12),
        ),
        trailing: const Icon(Icons.chevron_right_rounded, color: kGold),
        onTap: onTap,
      ),
    );
  }
}
