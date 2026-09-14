import 'package:flutter/material.dart';

import 'appColor.dart';
import 'themeToggleButton.dart';
import 'package:gahira/main.dart';
import '../admin/admin_dashboard.dart';
import '../admin/approval_page.dart';
import '../admin/report_page.dart';
import '../admin/billing_page.dart';
import '../admin/availability_page.dart';
import '../admin/miner_client_list_page.dart';
import '../admin/add_miner_page.dart';
import '../admin/service_request_page.dart';

// Shared drawer menu used across every admin page.
// Drop <AdminDrawer currentMenu: AdminMenu.xxx> into any page's
// `endDrawer:` so the menu (and its navigation) stays consistent.

enum AdminMenu {
  dashboard,
  // Miners
  minerList,
  registrationRequests,
  addMiner,
  availability,
  // Service Requests
  serviceRequest,
  // Processing
  scheduleAssignment,
  calendar,
  activeProcessing,
  completedProcessing,
  // Equipment
  machines,
  drums,
  maintenance,
  // Gold Buying & Billing
  goldTransactions,
  bills,
  expenses,
  payments,
  // Others
  notification,
  reports,
  activityLogs
}

class AdminDrawer extends StatelessWidget {
  const AdminDrawer({
    super.key,
    required this.currentMenu,
    this.adminName = 'Admin',
  });

  final AdminMenu currentMenu;
  final String adminName;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: context.surfaceColor,
      child: SafeArea(
        child: Column(
          children: [
            // Header remains fixed at the top
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
              decoration: BoxDecoration(
                color: context.bgColor,
                border: Border(
                  bottom: BorderSide(color: kGold.withOpacity(0.2)),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: kGold, width: 1.6),
                          color: context.surfaceColor,
                        ),
                        child:
                        Icon(Icons.person, color: kGold.withOpacity(0.9)),
                      ),
                      const ThemeToggleButton(),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    adminName,
                    style: TextStyle(
                      color: context.textColor,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Administrator',
                    style: TextStyle(
                      color: kGold.withOpacity(0.7),
                      fontSize: 12,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // Scrollable Menu Content
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _buildItem(
                      context,
                      icon: Icons.dashboard_rounded,
                      label: 'Dashboard',
                      menu: AdminMenu.dashboard,
                      page: const AdminDashboardPage(),
                    ),

                    // --- MINERS AND CLIENTS ---
                    _buildExpansionTile(
                      context,
                      icon: Icons.people_outline,
                      label: 'Miners and Clients',
                      menus: [
                        AdminMenu.minerList,
                        AdminMenu.registrationRequests,
                        AdminMenu.addMiner,
                        AdminMenu.availability // Moving this back here per previous prompt
                      ],
                      children: [
                        _buildSubItem(
                          context,
                          icon: Icons.list_alt_rounded,
                          label: 'Miner and Client List',
                          menu: AdminMenu.minerList,
                          page: const MinerClientListPage(),
                        ),
                        _buildSubItem(
                          context,
                          icon: Icons.fact_check_outlined,
                          label: 'Registration Requests',
                          menu: AdminMenu.registrationRequests,
                          page: const ApprovalPage(),
                        ),
                        _buildSubItem(
                          context,
                          icon: Icons.person_add_outlined,
                          label: 'Add Miner',
                          menu: AdminMenu.addMiner,
                          page: const AddMinerPage(),
                        ),
                        _buildSubItem(
                          context,
                          icon: Icons.event_available_rounded,
                          label: 'Availability',
                          menu: AdminMenu.availability,
                          page: const AvailabilityPage(),
                        ),
                      ],
                    ),

                    _buildItem(
                      context,
                      icon: Icons.assignment_outlined,
                      label: 'Service Requests',
                      menu: AdminMenu.serviceRequest,
                      page: const ServiceRequestPage(),
                    ),

                    // --- PROCESSING ---
                    _buildExpansionTile(
                      context,
                      icon: Icons.settings_input_component_rounded,
                      label: 'Processing',
                      menus: [
                        AdminMenu.scheduleAssignment,
                        AdminMenu.calendar,
                        AdminMenu.activeProcessing,
                        AdminMenu.completedProcessing
                      ],
                      children: [
                        _buildSubItem(
                          context,
                          icon: Icons.assignment_ind_outlined,
                          label: 'Schedule & Assignment',
                          menu: AdminMenu.scheduleAssignment,
                          page: _PlaceholderPage(title: 'Schedule & Assignment'),
                        ),
                        _buildSubItem(
                          context,
                          icon: Icons.calendar_today_outlined,
                          label: 'Calendar',
                          menu: AdminMenu.calendar,
                          page: _PlaceholderPage(title: 'Calendar'),
                        ),
                        _buildSubItem(
                          context,
                          icon: Icons.play_circle_outline_rounded,
                          label: 'Active Processing',
                          menu: AdminMenu.activeProcessing,
                          page: _PlaceholderPage(title: 'Active Processing'),
                        ),
                        _buildSubItem(
                          context,
                          icon: Icons.check_circle_outline_rounded,
                          label: 'Completed Processing',
                          menu: AdminMenu.completedProcessing,
                          page: _PlaceholderPage(title: 'Completed Processing'),
                        ),
                      ],
                    ),

                    // --- EQUIPMENT ---
                    _buildExpansionTile(
                      context,
                      icon: Icons.construction_rounded,
                      label: 'Equipment',
                      menus: [AdminMenu.machines, AdminMenu.drums, AdminMenu.maintenance],
                      children: [
                        _buildSubItem(
                          context,
                          icon: Icons.precision_manufacturing_outlined,
                          label: 'Machines',
                          menu: AdminMenu.machines,
                          page: _PlaceholderPage(title: 'Machines'),
                        ),
                        _buildSubItem(
                          context,
                          icon: Icons.reorder_rounded,
                          label: 'Drums',
                          menu: AdminMenu.drums,
                          page: _PlaceholderPage(title: 'Drums'),
                        ),
                        _buildSubItem(
                          context,
                          icon: Icons.build_circle_outlined,
                          label: 'Maintenance',
                          menu: AdminMenu.maintenance,
                          page: _PlaceholderPage(title: 'Maintenance'),
                        ),
                      ],
                    ),

                    // --- GOLD BUYING & BILLING ---
                    _buildExpansionTile(
                      context,
                      icon: Icons.account_balance_wallet_outlined,
                      label: 'Gold Buying & Billing',
                      menus: [
                        AdminMenu.goldTransactions,
                        AdminMenu.bills,
                        AdminMenu.expenses,
                        AdminMenu.payments
                      ],
                      children: [
                        _buildSubItem(
                          context,
                          icon: Icons.paid_outlined,
                          label: 'Gold Transactions',
                          menu: AdminMenu.goldTransactions,
                          page: _PlaceholderPage(title: 'Gold Transactions'),
                        ),
                        _buildSubItem(
                          context,
                          icon: Icons.receipt_long_outlined,
                          label: 'Bills',
                          menu: AdminMenu.bills,
                          page: const BillingPage(),
                        ),
                        _buildSubItem(
                          context,
                          icon: Icons.trending_down_rounded,
                          label: 'Expenses',
                          menu: AdminMenu.expenses,
                          page: _PlaceholderPage(title: 'Expenses'),
                        ),
                        _buildSubItem(
                          context,
                          icon: Icons.payments_outlined,
                          label: 'Payments',
                          menu: AdminMenu.payments,
                          page: _PlaceholderPage(title: 'Payments'),
                        ),
                      ],
                    ),

                    _buildItem(
                      context,
                      icon: Icons.notifications_outlined,
                      label: 'Notifications',
                      menu: AdminMenu.notification,
                      page: _PlaceholderPage(title: 'Notifications'),
                    ),
                    _buildItem(
                      context,
                      icon: Icons.bar_chart_rounded,
                      label: 'Reports & Records',
                      menu: AdminMenu.reports,
                      page: const ReportPage(),
                    ),
                    _buildItem(
                      context,
                      icon: Icons.history_rounded,
                      label: 'Activity Logs',
                      menu: AdminMenu.activityLogs,
                      page: _PlaceholderPage(title: 'Activity Logs'),
                    ),
                  ],
                ),
              ),
            ),

            // Footer remains fixed at the bottom
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Divider(color: kGold.withOpacity(0.15)),
            ),
            ListTile(
              leading: Icon(Icons.logout_rounded, color: kGold.withOpacity(0.7)),
              title: Text(
                'Log out',
                style: TextStyle(color: context.textColor.withOpacity(0.85)),
              ),
              onTap: () {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginPage()),
                      (route) => false,
                );
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildExpansionTile(
    BuildContext context, {
    required IconData icon,
    required String label,
    required List<AdminMenu> menus,
    required List<Widget> children,
  }) {
    final bool isSelected = menus.contains(currentMenu);
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        leading: Icon(
          icon,
          color: isSelected ? kGold : kGold.withOpacity(0.7),
        ),
        title: Text(
          label,
          style: TextStyle(
            color: isSelected ? kGold : context.textColor.withOpacity(0.85),
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            fontSize: 14,
          ),
        ),
        initiallyExpanded: isSelected,
        children: children,
      ),
    );
  }

  Widget _buildItem(
      BuildContext context, {
        required IconData icon,
        required String label,
        required AdminMenu menu,
        required Widget page,
      }) {
    final bool selected = currentMenu == menu;
    return ListTile(
      dense: true,
      visualDensity: VisualDensity.compact,
      leading: Icon(icon, color: selected ? kGold : kGold.withOpacity(0.7)),
      title: Text(
        label,
        style: TextStyle(
          color: selected ? kGold : context.textColor.withOpacity(0.85),
          fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          fontSize: 14,
        ),
      ),
      selected: selected,
      selectedTileColor: kGold.withOpacity(0.08),
      onTap: () {
        Navigator.of(context).pop(); // close drawer first
        if (!selected) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => page),
          );
        }
      },
    );
  }

  Widget _buildSubItem(
      BuildContext context, {
        required IconData icon,
        required String label,
        required AdminMenu menu,
        required Widget page,
      }) {
    final bool selected = currentMenu == menu;
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.only(left: 48),
      visualDensity: VisualDensity.compact,
      leading: Icon(icon, color: selected ? kGold : kGold.withOpacity(0.6), size: 20),
      title: Text(
        label,
        style: TextStyle(
          color: selected ? kGold : context.textColor.withOpacity(0.7),
          fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          fontSize: 13,
        ),
      ),
      selected: selected,
      selectedTileColor: kGold.withOpacity(0.05),
      onTap: () {
        Navigator.of(context).pop(); // close drawer first
        if (!selected) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => page),
          );
        }
      },
    );
  }
}

class _PlaceholderPage extends StatelessWidget {
  final String title;
  const _PlaceholderPage({required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bgColor,
      appBar: AppBar(
        backgroundColor: context.surfaceColor,
        title: Text(
          title.toUpperCase(),
          style: const TextStyle(color: kGold, fontWeight: FontWeight.bold, letterSpacing: 2),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: kGold),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.construction_rounded, color: kGold, size: 64),
            const SizedBox(height: 24),
            Text(
              'Under Development',
              style: TextStyle(color: context.textColor, fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'The $title page is currently being built.',
              style: TextStyle(color: context.mutedTextColor, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}
