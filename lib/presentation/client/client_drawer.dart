import 'package:flutter/material.dart';

import '../shared_widgets/appColor.dart';
import '../shared_widgets/themeToggleButton.dart';
import 'package:gahira/main.dart';
import 'client_dashboard.dart';
import 'service_requests_page.dart';
import 'processing_status_page.dart';
import 'billing_page.dart';
import 'transaction_history_page.dart';
import 'client_profile_page.dart';
import '../shared_widgets/profile_activity_page.dart';
import '../shared_widgets/notification_inbox_page.dart';

// Shared drawer menu used across every client page.
// Drop <ClientDrawer currentMenu: ClientMenu.xxx> into any page's
// `endDrawer:` so the menu (and its navigation) stays consistent.

enum ClientMenu {
  dashboard,
  serviceRequests,
  processingStatus,
  billing,
  transactionHistory,
  profile,
  profileActivity,
  notifications,
}

class ClientDrawer extends StatelessWidget {
  const ClientDrawer({
    super.key,
    required this.currentMenu,
    this.clientName = 'Client',
  });

  final ClientMenu currentMenu;
  final String clientName;

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
                        child: Icon(
                          Icons.person,
                          color: kGold.withOpacity(0.9),
                        ),
                      ),
                      const ThemeToggleButton(),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    clientName,
                    style: TextStyle(
                      color: context.textColor,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Client',
                    style: TextStyle(
                      color: kGold.withOpacity(0.7),
                      fontSize: 12,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  _buildItem(
                    context,
                    icon: Icons.dashboard_rounded,
                    label: 'Dashboard',
                    menu: ClientMenu.dashboard,
                    page: ClientDashboardPage(clientName: clientName),
                  ),
                  _buildItem(
                    context,
                    icon: Icons.description_outlined,
                    label: 'Service Requests',
                    menu: ClientMenu.serviceRequests,
                    page: const ServiceRequestsPage(),
                  ),
                  _buildItem(
                    context,
                    icon: Icons.settings_input_component_rounded,
                    label: 'Processing Status',
                    menu: ClientMenu.processingStatus,
                    page: const ProcessingStatusPage(),
                  ),
                  _buildItem(
                    context,
                    icon: Icons.receipt_long_outlined,
                    label: 'Billing',
                    menu: ClientMenu.billing,
                    page: const BillingPage(),
                  ),
                  _buildItem(
                    context,
                    icon: Icons.account_balance_wallet_outlined,
                    label: 'Transaction History',
                    menu: ClientMenu.transactionHistory,
                    page: const TransactionHistoryPage(),
                  ),
                  _buildItem(
                    context,
                    icon: Icons.notifications_outlined,
                    label: 'Notifications',
                    menu: ClientMenu.notifications,
                    page: const NotificationInboxPage(),
                  ),
                  _buildItem(
                    context,
                    icon: Icons.person_outline,
                    label: 'Profile',
                    menu: ClientMenu.profile,
                    page: const ClientProfilePage(),
                  ),
                  _buildItem(
                    context,
                    icon: Icons.manage_history_rounded,
                    label: 'Profile Activity',
                    menu: ClientMenu.profileActivity,
                    page: const ProfileActivityPage(),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Divider(color: kGold.withOpacity(0.15)),
            ),
            ListTile(
              leading: Icon(
                Icons.logout_rounded,
                color: kGold.withOpacity(0.7),
              ),
              title: Text(
                'Log out',
                style: TextStyle(color: context.textColor.withOpacity(0.85)),
              ),
              onTap: () => logoutAndNavigateToLogin(context),
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
    required ClientMenu menu,
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
          final navigator = Navigator.of(context);
          final route = MaterialPageRoute<void>(builder: (_) => page);
          if (menu == ClientMenu.notifications) {
            navigator.push(route);
          } else {
            navigator.pushReplacement(route);
          }
        }
      },
    );
  }
}
