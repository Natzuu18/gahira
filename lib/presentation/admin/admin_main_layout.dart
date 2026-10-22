import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../shared_widgets/appColor.dart';
import '../shared_widgets/curved_active_bottom_nav_bar.dart';
import 'admin_dashboard.dart';
import 'equipment/machine_page.dart';
import 'service_request_page.dart';
import 'admin_settings_page.dart';
import 'admin_finance_page.dart';
import '../../infrastructure/notifications/push_notification_service.dart';

class AdminMainLayout extends StatefulWidget {
  const AdminMainLayout({
    super.key,
    this.initialIndex = 2,
    this.adminName = 'Admin',
  });

  final int initialIndex;
  final String adminName;

  @override
  State<AdminMainLayout> createState() => _AdminMainLayoutState();
}

class _AdminMainLayoutState extends State<AdminMainLayout> {
  late int _currentIndex;
  int _pendingBillingCount = 0;
  RealtimeChannel? _billingChannel;
  Timer? _billingCountTimer;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    unawaited(PushNotificationService.instance.initializeForCurrentUser());
    _loadPendingBillingCount();
    _subscribeToBillingChanges();
    _billingCountTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _loadPendingBillingCount(),
    );
  }

  void _subscribeToBillingChanges() {
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id ?? 'admin';
    _billingChannel = client
        .channel('admin-pending-billings-$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'service_requests',
          callback: (_) => _loadPendingBillingCount(),
        )
        .subscribe();
  }

  Future<void> _loadPendingBillingCount() async {
    try {
      final rows = await Supabase.instance.client
          .from('service_requests')
          .select('service_request_id')
          .inFilter('status', const [
            'processingCompleted',
            'goldHandoff',
            'partiallyPaid',
          ]);
      if (mounted) {
        setState(() => _pendingBillingCount = (rows as List).length);
      }
    } catch (_) {
      // Keep the current badge value if the billing count cannot refresh.
    }
  }

  @override
  void dispose() {
    _billingCountTimer?.cancel();
    final channel = _billingChannel;
    if (channel != null) {
      unawaited(Supabase.instance.client.removeChannel(channel));
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      ServiceRequestPage(key: ValueKey('services_$_currentIndex')),
      MachinePage(key: ValueKey('machines_$_currentIndex')),
      AdminDashboardPage(
        key: ValueKey('dashboard_$_currentIndex'),
        adminName: widget.adminName,
      ),
      AdminFinancePage(key: ValueKey('finance_$_currentIndex')),
      AdminSettingsPage(
        key: ValueKey('settings_$_currentIndex'),
        adminName: widget.adminName,
      ),
    ];

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: pages),
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
            icon: Icons.account_balance_wallet_outlined,
            selectedIcon: Icons.account_balance_wallet_rounded,
            label: 'Finance',
            activeColor: Colors.tealAccent.shade400,
            badgeCount: _pendingBillingCount,
          ),
          CurvedNavItem(
            icon: Icons.settings_outlined,
            selectedIcon: Icons.settings_rounded,
            label: 'Settings',
            activeColor: Colors.purpleAccent.shade100,
          ),
        ],
      ),
    );
  }
}
