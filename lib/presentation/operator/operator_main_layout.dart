import 'package:flutter/material.dart';

import '../shared_widgets/appColor.dart';
import '../shared_widgets/curved_active_bottom_nav_bar.dart';
import '../shared_widgets/profile_activity_page.dart';
import 'client_service_page.dart';
import 'emergency_stop_dialog.dart';
import 'equipment_maintenance_page.dart';
import 'operator_dashboard.dart';
import 'processing_workflow_page.dart';
import 'service_verification_page.dart';
import 'sms_notification_page.dart';
import 'workforce_shift_page.dart';
import 'operator_menu.dart';

class OperatorMainLayout extends StatefulWidget {
  const OperatorMainLayout({super.key, this.operatorName = 'Operator'});

  final String operatorName;

  @override
  State<OperatorMainLayout> createState() => _OperatorMainLayoutState();
}

class _OperatorMainLayoutState extends State<OperatorMainLayout> {
  int _pageIndex = 0;
  bool _profileActivityOpen = false;

  int get _selectedTabIndex => switch (_pageIndex) {
    0 => 2,
    1 => 0,
    2 => 1,
    3 => 3,
    _ => 4,
  };

  int _pageIndexForTab(int index) => switch (index) {
    0 => 1,
    1 => 2,
    2 => 0,
    3 => 3,
    _ => _pageIndex,
  };

  void _selectMenu(OperatorMenu menu) {
    if (menu == OperatorMenu.profileActivity) {
      _openProfileActivity();
      return;
    }

    if (_profileActivityOpen) {
      Navigator.of(context).pop();
    }
    setState(() {
      _pageIndex = switch (menu) {
        OperatorMenu.dashboard => 0,
        OperatorMenu.serviceVerification => 1,
        OperatorMenu.clientService => 2,
        OperatorMenu.processing => 3,
        OperatorMenu.equipment => 4,
        OperatorMenu.workforce => 5,
        OperatorMenu.sms => 6,
        OperatorMenu.profileActivity => 0,
      };
    });
  }

  Future<void> _openProfileActivity() async {
    _profileActivityOpen = true;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ProfileActivityPage(
          bottomNavigationBar: _buildNavigationBar(isProfileActivity: true),
        ),
      ),
    );
    _profileActivityOpen = false;
  }

  void _selectProfileActivityTab(int index) {
    if (index == 4) {
      _showMoreMenu();
      return;
    }
    Navigator.of(context).pop();
    setState(() => _pageIndex = _pageIndexForTab(index));
  }

  void _showMoreMenu() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.surfaceColor,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            _buildMoreItem(
              sheetContext,
              icon: Icons.build_circle_outlined,
              label: 'Equipment & Maintenance',
              menu: OperatorMenu.equipment,
            ),
            _buildMoreItem(
              sheetContext,
              icon: Icons.schedule_rounded,
              label: 'Workforce & Shifts',
              menu: OperatorMenu.workforce,
            ),
            _buildMoreItem(
              sheetContext,
              icon: Icons.sms_outlined,
              label: 'SMS Notifications',
              menu: OperatorMenu.sms,
            ),
            _buildMoreItem(
              sheetContext,
              icon: Icons.manage_history_rounded,
              label: 'Profile Activity',
              menu: OperatorMenu.profileActivity,
            ),
            const Divider(),
            ListTile(
              leading: const Icon(
                Icons.warning_amber_rounded,
                color: Colors.red,
              ),
              title: const Text('Emergency Stop'),
              onTap: () {
                Navigator.pop(sheetContext);
                showDialog<void>(
                  context: context,
                  builder: (_) => const EmergencyStopDialog(),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout_rounded, color: kGold),
              title: const Text('Log out'),
              onTap: () {
                Navigator.pop(sheetContext);
                Navigator.of(
                  context,
                ).pushNamedAndRemoveUntil('/', (route) => false);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMoreItem(
    BuildContext sheetContext, {
    required IconData icon,
    required String label,
    required OperatorMenu menu,
  }) {
    return ListTile(
      leading: Icon(icon, color: kGold),
      title: Text(label, style: TextStyle(color: context.textColor)),
      onTap: () {
        Navigator.pop(sheetContext);
        _selectMenu(menu);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      OperatorDashboardPage(
        operatorName: widget.operatorName,
        onNavigate: _selectMenu,
      ),
      const ServiceVerificationPage(),
      const ClientServicePage(),
      const ProcessingWorkflowPage(),
      const EquipmentMaintenancePage(),
      const WorkforceShiftPage(),
      const SMSNotificationPage(),
    ];

    return Scaffold(
      body: IndexedStack(index: _pageIndex, children: pages),
      bottomNavigationBar: _buildNavigationBar(),
    );
  }

  Widget _buildNavigationBar({bool isProfileActivity = false}) {
    return CurvedActiveBottomNavBar(
      selectedIndex: isProfileActivity ? 4 : _selectedTabIndex,
      onTabSelected: isProfileActivity
          ? _selectProfileActivityTab
          : (index) {
              if (index == 4) {
                _showMoreMenu();
              } else {
                setState(() => _pageIndex = _pageIndexForTab(index));
              }
            },
      items: const [
        CurvedNavItem(
          icon: Icons.fact_check_outlined,
          selectedIcon: Icons.fact_check_rounded,
          label: 'Verify',
          activeColor: Colors.orangeAccent,
        ),
        CurvedNavItem(
          icon: Icons.people_outline_rounded,
          selectedIcon: Icons.people_alt_rounded,
          label: 'Miners',
          activeColor: Colors.tealAccent,
        ),
        CurvedNavItem(
          icon: Icons.dashboard_outlined,
          selectedIcon: Icons.dashboard_rounded,
          label: 'Dashboard',
          activeColor: kGold,
        ),
        CurvedNavItem(
          icon: Icons.settings_input_component_outlined,
          selectedIcon: Icons.settings_input_component_rounded,
          label: 'Workflow',
          activeColor: Colors.lightBlueAccent,
        ),
        CurvedNavItem(
          icon: Icons.more_horiz_rounded,
          selectedIcon: Icons.more_horiz_rounded,
          label: 'More',
          activeColor: Colors.purpleAccent,
        ),
      ],
    );
  }
}
