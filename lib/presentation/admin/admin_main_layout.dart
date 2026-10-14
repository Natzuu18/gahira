import 'package:flutter/material.dart';
import '../shared_widgets/appColor.dart';
import 'admin_dashboard.dart';
import 'miner_client_list_page.dart';
import 'equipment/machine_page.dart';
import 'service_request_page.dart';
import 'admin_settings_page.dart';

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
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      MinerClientListPage(key: ValueKey('miners_$_currentIndex')),
      MachinePage(key: ValueKey('machines_$_currentIndex')),
      AdminDashboardPage(key: ValueKey('dashboard_$_currentIndex'), adminName: widget.adminName),
      ServiceRequestPage(key: ValueKey('services_$_currentIndex')),
      AdminSettingsPage(key: ValueKey('settings_$_currentIndex'), adminName: widget.adminName),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: pages,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: context.surfaceColor,
          border: Border(
            top: BorderSide(
              color: kGold.withOpacity(0.2),
              width: 1,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: NavigationBar(
            selectedIndex: _currentIndex,
            onDestinationSelected: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            backgroundColor: context.surfaceColor,
            indicatorColor: kGold.withOpacity(0.2),
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.people_outline_rounded, color: kGold),
                selectedIcon: Icon(Icons.people_alt_rounded, color: kGold),
                label: 'Miners',
              ),
              NavigationDestination(
                icon: Icon(Icons.precision_manufacturing_outlined, color: kGold),
                selectedIcon: Icon(Icons.precision_manufacturing_rounded, color: kGold),
                label: 'Machine',
              ),
              NavigationDestination(
                icon: Icon(Icons.dashboard_outlined, color: kGold),
                selectedIcon: Icon(Icons.dashboard_rounded, color: kGold),
                label: 'Dashboard',
              ),
              NavigationDestination(
                icon: Icon(Icons.assignment_outlined, color: kGold),
                selectedIcon: Icon(Icons.assignment_rounded, color: kGold),
                label: 'Services',
              ),
              NavigationDestination(
                icon: Icon(Icons.settings_outlined, color: kGold),
                selectedIcon: Icon(Icons.settings_rounded, color: kGold),
                label: 'User Settings',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
