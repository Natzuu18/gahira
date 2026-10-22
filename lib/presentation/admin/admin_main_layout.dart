import 'dart:async';

import 'package:flutter/material.dart';
import '../shared_widgets/appColor.dart';
import '../shared_widgets/curved_active_bottom_nav_bar.dart';
import 'admin_dashboard.dart';
import 'miner_client_list_page.dart';
import 'equipment/machine_page.dart';
import 'service_request_page.dart';
import 'admin_settings_page.dart';
import '../../infrastructure/notifications/push_notification_service.dart';

class AdminMainLayout extends StatefulWidget {
  const AdminMainLayout({super.key, this.initialIndex = 2, this.adminName = 'Admin'});

  final int initialIndex;
  final String adminName;

  @override
  State<AdminMainLayout> createState() => _AdminMainLayoutState();
}

class _AdminMainLayoutState extends State<AdminMainLayout> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    unawaited(PushNotificationService.instance.initializeForCurrentUser());
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      ServiceRequestPage(key: ValueKey('services_$_currentIndex')),
      MachinePage(key: ValueKey('machines_$_currentIndex')),
      AdminDashboardPage(key: ValueKey('dashboard_$_currentIndex'), adminName: widget.adminName),
      MinerClientListPage(key: ValueKey('miners_$_currentIndex')),
      AdminSettingsPage(key: ValueKey('settings_$_currentIndex'), adminName: widget.adminName),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: pages,
      ),
      bottomNavigationBar: CurvedActiveBottomNavBar(
        selectedIndex: _currentIndex,
        onTabSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: [
          const CurvedNavItem(
            icon: Icons.assignment_outlined,
            selectedIcon: Icons.assignment_rounded,
            label: 'Services',
            activeColor: Colors.lightBlueAccent,
          ),
          const CurvedNavItem(
            icon: Icons.precision_manufacturing_outlined,
            selectedIcon: Icons.precision_manufacturing_rounded,
            label: 'Machine',
            activeColor: Colors.orangeAccent,
          ),
          const CurvedNavItem(
            icon: Icons.dashboard_outlined,
            selectedIcon: Icons.dashboard_rounded,
            label: 'Dashboard',
            activeColor: kGold,
          ),
          CurvedNavItem(
            icon: Icons.people_outline_rounded,
            selectedIcon: Icons.people_alt_rounded,
            label: 'Users',
            activeColor: Colors.tealAccent.shade400,
          ),
          CurvedNavItem(
            icon: Icons.settings_outlined,
            selectedIcon: Icons.settings_rounded,
            label: 'User Settings',
            activeColor: Colors.purpleAccent.shade100,
          ),
        ],
      ),
    );
  }
}
