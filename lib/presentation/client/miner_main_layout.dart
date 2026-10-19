import 'package:flutter/material.dart';
import '../shared_widgets/appColor.dart';
import '../shared_widgets/curved_active_bottom_nav_bar.dart';
import 'service_requests_page.dart';
import 'processing_status_page.dart';
import '../miner/miner_dashboard.dart';
import 'billing_page.dart';
import 'client_profile_page.dart';

class MinerMainLayout extends StatefulWidget {
  const MinerMainLayout({super.key, this.initialIndex = 2, this.minerName = 'Miner'});

  final int initialIndex;
  final String minerName;

  @override
  State<MinerMainLayout> createState() => _MinerMainLayoutState();
}

class _MinerMainLayoutState extends State<MinerMainLayout> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      ServiceRequestsPage(key: ValueKey('requests_$_currentIndex')),
      ProcessingStatusPage(key: ValueKey('status_$_currentIndex')),
      MinerDashboardPage(key: ValueKey('dashboard_$_currentIndex'), minerName: widget.minerName),
      BillingPage(key: ValueKey('billing_$_currentIndex')),
      ClientProfilePage(key: ValueKey('profile_$_currentIndex')),
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
          CurvedNavItem(
            icon: Icons.insights_outlined,
            selectedIcon: Icons.insights_rounded,
            label: 'Tracker',
            activeColor: Colors.greenAccent.shade400,
          ),
          const CurvedNavItem(
            icon: Icons.dashboard_outlined,
            selectedIcon: Icons.dashboard_rounded,
            label: 'Dashboard',
            activeColor: kGold,
          ),
          const CurvedNavItem(
            icon: Icons.receipt_long_outlined,
            selectedIcon: Icons.receipt_long_rounded,
            label: 'Billing',
            activeColor: Colors.orangeAccent,
          ),
          CurvedNavItem(
            icon: Icons.person_outline_rounded,
            selectedIcon: Icons.person_rounded,
            label: 'Profile',
            activeColor: Colors.purpleAccent.shade100,
          ),
        ],
      ),
    );
  }
}
