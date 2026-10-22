import 'package:flutter/material.dart';
import '../admin/admin_main_layout.dart';
import 'appColor.dart';

Widget buildAdminBottomNavBar(BuildContext context, {int selectedIndex = 3}) {
  return Container(
    decoration: BoxDecoration(
      color: context.surfaceColor,
      border: Border(
        top: BorderSide(color: kGold.withValues(alpha: 0.2), width: 1),
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.1),
          blurRadius: 8,
          offset: const Offset(0, -2),
        ),
      ],
    ),
    child: SafeArea(
      child: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: (index) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (_) => AdminMainLayout(initialIndex: index),
            ),
            (route) => false,
          );
        },
        backgroundColor: context.surfaceColor,
        indicatorColor: kGold.withValues(alpha: 0.2),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.assignment_outlined, color: kGold),
            selectedIcon: Icon(Icons.assignment_rounded, color: kGold),
            label: 'Services',
          ),
          NavigationDestination(
            icon: Icon(Icons.precision_manufacturing_outlined, color: kGold),
            selectedIcon: Icon(
              Icons.precision_manufacturing_rounded,
              color: kGold,
            ),
            label: 'Machine',
          ),
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined, color: kGold),
            selectedIcon: Icon(Icons.dashboard_rounded, color: kGold),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined, color: kGold),
            selectedIcon: Icon(
              Icons.account_balance_wallet_rounded,
              color: kGold,
            ),
            label: 'Finance',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined, color: kGold),
            selectedIcon: Icon(Icons.settings_rounded, color: kGold),
            label: 'Settings',
          ),
        ],
      ),
    ),
  );
}
