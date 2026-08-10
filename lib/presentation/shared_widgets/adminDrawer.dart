import 'package:flutter/material.dart';

import 'appColor.dart';
import 'themeToggleButton.dart';
import '../../main.dart';
import '../admin/admin_dashboard.dart';
import '../admin/approval_page.dart';
import '../admin/report_page.dart';
import '../admin/billing_page.dart';

// Shared drawer menu used across every admin page.
// Drop <AdminDrawer currentMenu: AdminMenu.xxx> into any page's
// `endDrawer:` so the menu (and its navigation) stays consistent.

enum AdminMenu { dashboard, approval, report, billing }

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
            // Header with name at the top
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

            _buildItem(
              context,
              icon: Icons.dashboard_rounded,
              label: 'Dashboard',
              menu: AdminMenu.dashboard,
              page: const AdminDashboardPage(),
            ),
            _buildItem(
              context,
              icon: Icons.fact_check_outlined,
              label: 'Approval',
              menu: AdminMenu.approval,
              page: const ApprovalPage(),
            ),
            _buildItem(
              context,
              icon: Icons.bar_chart_rounded,
              label: 'Report',
              menu: AdminMenu.report,
              page: const ReportPage(),
            ),
            _buildItem(
              context,
              icon: Icons.receipt_long_outlined,
              label: 'Billing',
              menu: AdminMenu.billing,
              page: const BillingPage(),
            ),

            const Spacer(),
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

  Widget _buildItem(
      BuildContext context, {
        required IconData icon,
        required String label,
        required AdminMenu menu,
        required Widget page,
      }) {
    final bool selected = currentMenu == menu;
    return ListTile(
      leading: Icon(icon, color: selected ? kGold : kGold.withOpacity(0.7)),
      title: Text(
        label,
        style: TextStyle(
          color: selected ? kGold : context.textColor.withOpacity(0.85),
          fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
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
}