import 'package:flutter/material.dart';

import '../shared_widgets/appColor.dart';
import '../shared_widgets/themeToggleButton.dart';
import 'package:gahira/main.dart';
import 'operator_dashboard.dart';
import 'service_verification_page.dart';
import 'client_service_page.dart';
import 'equipment_maintenance_page.dart';
import 'workforce_shift_page.dart';
import 'sms_notification_page.dart';
import 'emergency_stop_dialog.dart';
import '../shared_widgets/profile_activity_page.dart';
import 'operator_menu.dart';

class OperatorDrawer extends StatelessWidget {
  const OperatorDrawer({
    super.key,
    required this.currentMenu,
    this.operatorName = 'Operator',
  });

  final OperatorMenu currentMenu;
  final String operatorName;

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
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 18),
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
                        width: 48,
                        height: 48,
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
                  const SizedBox(height: 10),
                  Text(
                    operatorName,
                    style: TextStyle(
                      color: context.textColor,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Operator',
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
                padding: const EdgeInsets.symmetric(vertical: 4),
                children: [
                  _buildItem(
                    context,
                    icon: Icons.dashboard_rounded,
                    label: 'Dashboard',
                    menu: OperatorMenu.dashboard,
                    page: OperatorDashboardPage(operatorName: operatorName),
                  ),
                  _buildItem(
                    context,
                    icon: Icons.fact_check_outlined,
                    label: 'Service Verification',
                    menu: OperatorMenu.serviceVerification,
                    page: const ServiceVerificationPage(),
                  ),
                  _buildItem(
                    context,
                    icon: Icons.people_outline_rounded,
                    label: 'Miner Services',
                    menu: OperatorMenu.clientService,
                    page: const ClientServicePage(),
                  ),
                  _buildItem(
                    context,
                    icon: Icons.build_circle_outlined,
                    label: 'Equipment & Maintenance',
                    menu: OperatorMenu.equipment,
                    page: const EquipmentMaintenancePage(),
                  ),
                  _buildItem(
                    context,
                    icon: Icons.schedule_rounded,
                    label: 'Workforce & Shifts',
                    menu: OperatorMenu.workforce,
                    page: const WorkforceShiftPage(),
                  ),
                  _buildItem(
                    context,
                    icon: Icons.sms_outlined,
                    label: 'SMS Notifications',
                    menu: OperatorMenu.sms,
                    page: const SMSNotificationPage(),
                  ),
                  _buildItem(
                    context,
                    icon: Icons.manage_history_rounded,
                    label: 'Profile Activity',
                    menu: OperatorMenu.profileActivity,
                    page: const ProfileActivityPage(),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ElevatedButton.icon(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => const EmergencyStopDialog(),
                  );
                },
                icon: const Icon(Icons.warning_amber_rounded),
                label: const Text(
                  'EMERGENCY STOP',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 44),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
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
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }

  Widget _buildItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required OperatorMenu menu,
    required Widget page,
  }) {
    final bool selected = currentMenu == menu;
    return ListTile(
      dense: true,
      visualDensity: const VisualDensity(vertical: -1),
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
          final navigator = Navigator.of(context);
          final route = MaterialPageRoute<void>(builder: (_) => page);
          if (menu == OperatorMenu.profileActivity) {
            navigator.push(route);
          } else {
            navigator.pushReplacement(route);
          }
        }
      },
    );
  }
}
