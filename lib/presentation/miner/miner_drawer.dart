import 'package:flutter/material.dart';
import '../shared_widgets/appColor.dart';
import '../shared_widgets/themeToggleButton.dart';
import 'package:gahira/main.dart';
import 'miner_dashboard.dart';
import '../client/service_requests_page.dart';
import '../client/processing_status_page.dart';
import '../client/billing_page.dart';
import '../client/transaction_history_page.dart';
import '../client/client_profile_page.dart';

enum MinerMenu {
  dashboard,
  serviceRequests,
  processingStatus,
  billing,
  transactionHistory,
  profile
}

class MinerDrawer extends StatelessWidget {
  const MinerDrawer({
    super.key,
    required this.currentMenu,
    this.minerName = 'Miner',
  });

  final MinerMenu currentMenu;
  final String minerName;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: context.surfaceColor,
      child: SafeArea(
        child: Column(
          children: [
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
                        child: Icon(Icons.person, color: kGold.withOpacity(0.9)),
                      ),
                      const ThemeToggleButton(),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    minerName,
                    style: TextStyle(
                      color: context.textColor,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Miner / Client',
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
              menu: MinerMenu.dashboard,
              page: MinerDashboardPage(minerName: minerName),
            ),
            _buildItem(
              context,
              icon: Icons.description_outlined,
              label: 'Service Requests',
              menu: MinerMenu.serviceRequests,
              page: const ServiceRequestsPage(),
            ),
            _buildItem(
              context,
              icon: Icons.settings_input_component_rounded,
              label: 'Processing Status',
              menu: MinerMenu.processingStatus,
              page: const ProcessingStatusPage(),
            ),
            _buildItem(
              context,
              icon: Icons.receipt_long_outlined,
              label: 'Billing',
              menu: MinerMenu.billing,
              page: const BillingPage(),
            ),
            _buildItem(
              context,
              icon: Icons.account_balance_wallet_outlined,
              label: 'Transaction History',
              menu: MinerMenu.transactionHistory,
              page: const TransactionHistoryPage(),
            ),
            _buildItem(
              context,
              icon: Icons.person_outline,
              label: 'Profile',
              menu: MinerMenu.profile,
              page: const ClientProfilePage(),
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
    required MinerMenu menu,
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
        Navigator.of(context).pop();
        if (!selected) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => page),
          );
        }
      },
    );
  }
}
