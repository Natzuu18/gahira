import 'package:flutter/material.dart';

import '../shared_widgets/curved_active_bottom_nav_bar.dart';
import '../shared_widgets/profile_activity_page.dart';
import 'client_service_page.dart';
import 'equipment_maintenance_page.dart';
import 'operator_dashboard.dart';
import 'service_verification_page.dart';
import 'sms_notification_page.dart';
import 'workforce_shift_page.dart';
import 'operator_user_page.dart';
import 'operator_emergency_stop_fab.dart';
import 'operator_menu.dart';

class OperatorMainLayout extends StatefulWidget {
  const OperatorMainLayout({super.key, this.operatorName = 'Operator'});

  final String operatorName;

  @override
  State<OperatorMainLayout> createState() => _OperatorMainLayoutState();
}

class _OperatorMainLayoutState extends State<OperatorMainLayout> {
  int _pageIndex = 0;
  int _pendingServiceRequestCount = 0;

  int get _selectedTabIndex => switch (_pageIndex) {
    0 => 2,
    1 => 0,
    3 => 1,
    4 => 3,
    _ => 4,
  };

  int _pageIndexForTab(int index) => switch (index) {
    0 => 1,
    1 => 3,
    2 => 0,
    3 => 4,
    _ => 6,
  };

  void _selectMenu(OperatorMenu menu) {
    if (menu == OperatorMenu.profileActivity) {
      _openProfileActivity();
      return;
    }

    setState(() {
      _pageIndex = switch (menu) {
        OperatorMenu.dashboard => 0,
        OperatorMenu.serviceVerification => 1,
        OperatorMenu.clientService => 2,
        OperatorMenu.equipment => 3,
        OperatorMenu.workforce => 4,
        OperatorMenu.sms => 5,
        OperatorMenu.user => 6,
        OperatorMenu.profileActivity => 6,
      };
    });
  }

  Future<void> _openProfileActivity() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ProfileActivityPage(
          bottomNavigationBar: _buildNavigationBar(isProfileActivity: true),
        ),
      ),
    );
  }

  void _selectProfileActivityTab(int index) {
    Navigator.of(context).pop();
    setState(() => _pageIndex = _pageIndexForTab(index));
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      OperatorDashboardPage(
        operatorName: widget.operatorName,
        onNavigate: _selectMenu,
      ),
      ServiceVerificationPage(
        onPendingCountChanged: (count) {
          if (!mounted || count == _pendingServiceRequestCount) return;
          setState(() => _pendingServiceRequestCount = count);
        },
      ),
      const ClientServicePage(),
      const EquipmentMaintenancePage(),
      const WorkforceShiftPage(),
      const SMSNotificationPage(),
      OperatorUserPage(
        operatorName: widget.operatorName,
        onOpenProfileActivity: _openProfileActivity,
        onLogout: () => Navigator.of(context).pushNamedAndRemoveUntil(
          '/',
          (route) => false,
        ),
      ),
    ];

    return Scaffold(
      body: IndexedStack(index: _pageIndex, children: pages),
      bottomNavigationBar: _buildNavigationBar(),
      floatingActionButton: AnimatedSlide(
        offset: _pageIndex == 1 ? const Offset(0, -1.35) : Offset.zero,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeInOut,
        child: const OperatorEmergencyStopFab(),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  Widget _buildNavigationBar({bool isProfileActivity = false}) {
    return CurvedActiveBottomNavBar(
      selectedIndex: isProfileActivity ? 4 : _selectedTabIndex,
      onTabSelected: isProfileActivity
          ? _selectProfileActivityTab
          : (index) {
              setState(() => _pageIndex = _pageIndexForTab(index));
            },
      items: [
        CurvedNavItem(
          icon: Icons.assignment_outlined,
          selectedIcon: Icons.assignment_rounded,
          label: 'Services',
          activeColor: Colors.orangeAccent,
          badgeCount: _pendingServiceRequestCount,
        ),
        CurvedNavItem(
          icon: Icons.precision_manufacturing_outlined,
          selectedIcon: Icons.precision_manufacturing_rounded,
          label: 'Machine',
          activeColor: Colors.tealAccent,
        ),
        CurvedNavItem(
          icon: Icons.dashboard_outlined,
          selectedIcon: Icons.dashboard_rounded,
          label: 'Dashboard',
        ),
        CurvedNavItem(
          icon: Icons.settings_input_component_outlined,
          selectedIcon: Icons.settings_input_component_rounded,
          label: 'Workforce',
          activeColor: Colors.lightBlueAccent,
        ),
        CurvedNavItem(
          icon: Icons.person_outline_rounded,
          selectedIcon: Icons.person_rounded,
          label: 'User',
          activeColor: Colors.purpleAccent,
        ),
      ],
    );
  }
}
