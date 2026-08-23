import 'package:flutter/material.dart';

import '../shared_widgets/appColor.dart';
import '../shared_widgets/themeToggleButton.dart';
import 'package:gahira/main.dart';
import 'operator_dashboard.dart';
import 'client_service_page.dart';
import 'processing_workflow_page.dart';
import 'material_procurement_page.dart';
import 'equipment_maintenance_page.dart';
import 'workforce_shift_page.dart';
import 'operator_billing_page.dart';
import 'sms_notification_page.dart';

enum OperatorMenu { 
  dashboard, 
  clientService, 
  processing, 
  materials, 
  equipment, 
  workforce, 
  billing, 
  sms 
}

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

            const SizedBox(height: 8),

            _buildItem(
              context,
              icon: Icons.dashboard_rounded,
              label: 'Dashboard',
              menu: OperatorMenu.dashboard,
              page: OperatorDashboardPage(operatorName: operatorName),
            ),
            _buildItem(
              context,
              icon: Icons.people_outline_rounded,
              label: 'Client Service',
              menu: OperatorMenu.clientService,
              page: const ClientServicePage(),
            ),
            _buildItem(
              context,
              icon: Icons.settings_input_component_rounded,
              label: 'Processing Workflow',
              menu: OperatorMenu.processing,
              page: const ProcessingWorkflowPage(),
            ),
            _buildItem(
              context,
              icon: Icons.inventory_2_outlined,
              label: 'Raw Materials',
              menu: OperatorMenu.materials,
              page: const MaterialProcurementPage(),
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
              icon: Icons.receipt_long_outlined,
              label: 'Billing',
              menu: OperatorMenu.billing,
              page: const OperatorBillingPage(),
            ),
            _buildItem(
              context,
              icon: Icons.sms_outlined,
              label: 'SMS Notifications',
              menu: OperatorMenu.sms,
              page: const SMSNotificationPage(),
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
    required OperatorMenu menu,
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
