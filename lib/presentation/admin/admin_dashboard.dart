import 'package:flutter/material.dart';

import '../shared_widgets/appColor.dart';
import '../shared_widgets/themeToggleButton.dart';
import '../shared_widgets/adminDrawer.dart';
import '../shared_widgets/emergency_alert_banner.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key, this.adminName = 'Admin'});

  final String adminName;

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

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
          style: TextStyle(color: kGold, fontWeight: FontWeight.bold, letterSpacing: 2, fontSize: 16),
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
      endDrawer: AdminDrawer(
        currentMenu: AdminMenu.dashboard,
        adminName: widget.adminName,
      ),
      body: Column(
        children: [
          const EmergencyAlertBanner(isAdmin: true),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async => await Future.delayed(const Duration(seconds: 1)),
              color: kGold,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 24),
                    _buildSectionTitle('Requests & Reviews', Icons.pending_actions_rounded),
                    Row(
                      children: [
                        Expanded(child: _buildStatCard('Pending Services', '05', Colors.orange)),
                        const SizedBox(width: 12),
                        Expanded(child: _buildStatCard('Owner Reviews', '03', kGold)),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _buildSectionTitle('Operations', Icons.settings_input_component_rounded),
                    Row(
                      children: [
                        Expanded(child: _buildStatCard('Scheduled', '12', Colors.blue)),
                        const SizedBox(width: 12),
                        Expanded(child: _buildStatCard('Active Now', '08', Colors.green)),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _buildSectionTitle('Resources', Icons.engineering_outlined),
                    Row(
                      children: [
                        Expanded(child: _buildStatCard('Avail. Operators', '04', Colors.teal)),
                        const SizedBox(width: 12),
                        Expanded(child: _buildStatCard('Equip. Avail.', '85%', Colors.deepPurpleAccent)),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _buildSectionTitle('Financials', Icons.account_balance_wallet_outlined),
                    _buildFinancialItem('Payment Verifications', '02 awaiting', kGold, Icons.fact_check_outlined),
                    _buildFinancialItem('Pending Billing', '04 invoices', Colors.orange, Icons.receipt_long_outlined),
                    _buildFinancialItem('Unpaid/Partial Bills', '₱45,200.00', Colors.redAccent, Icons.money_off_csred_rounded),
                    const SizedBox(height: 24),
                    _buildSectionTitle('Recent Activities', Icons.history_rounded),
                    _buildActivityItem('Service Request #SR-102 approved', '30 mins ago'),
                    _buildActivityItem('Drum #05 maintenance completed', '2 hours ago'),
                    _buildActivityItem('Payment received from Miner: Mark', '4 hours ago'),
                    _buildActivityItem('New operator application: Sarah', 'Yesterday'),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Welcome back,', style: TextStyle(color: context.mutedTextColor, fontSize: 14)),
        Text(widget.adminName, style: TextStyle(color: context.textColor, fontSize: 24, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildSectionTitle(String title, IconData icon, [Color color = kGold]) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Text(title.toUpperCase(), style: TextStyle(color: context.textColor.withOpacity(0.8), fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.1)),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: context.surfaceColor, borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withOpacity(0.2))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: context.mutedTextColor, fontSize: 11, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildFinancialItem(String label, String value, Color color, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(color: context.surfaceColor, borderRadius: BorderRadius.circular(10), border: Border.all(color: context.textColor.withOpacity(0.05))),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color.withOpacity(0.7)),
          const SizedBox(width: 16),
          Expanded(child: Text(label, style: TextStyle(color: context.textColor, fontSize: 13, fontWeight: FontWeight.w500))),
          Text(value, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildActivityItem(String message, String time) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Row(
        children: [
          Container(width: 6, height: 6, decoration: const BoxDecoration(color: kGold, shape: BoxShape.circle)),
          const SizedBox(width: 16),
          Expanded(child: Text(message, style: TextStyle(color: context.textColor.withOpacity(0.9), fontSize: 13))),
          Text(time, style: TextStyle(color: context.mutedTextColor, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildLogoMark() {
    return Container(
      width: 34, height: 34,
      decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: kGold, width: 1.6), color: context.bgColor),
      child: const Icon(Icons.settings_input_component_rounded, color: kGold, size: 16),
    );
  }
}
