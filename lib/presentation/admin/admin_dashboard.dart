import 'package:flutter/material.dart';

import '../shared_widgets/appColor.dart';
import '../shared_widgets/themeToggleButton.dart';
import '../shared_widgets/adminDrawer.dart';
import '../shared_widgets/emergency_alert_banner.dart';
import 'approval_page.dart';
import 'billing_page.dart';
import 'service_request_page.dart';
import 'processing/processing_calendar_page.dart';

// Gahira Ball Mill Management System - Admin Dashboard
class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key, this.adminName = 'Admin'});

  final String adminName;

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: context.bgColor,
      appBar: AppBar(
        backgroundColor: context.surfaceColor,
        elevation: 0,
        leadingWidth: 64,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16),
          child: _buildLogoMark(),
        ),
        title: const Text(
          'DASHBOARD',
          style: TextStyle(
            color: kGold,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
            fontSize: 16,
          ),
        ),
        iconTheme: const IconThemeData(color: kGold),
        actions: [
          const ThemeToggleButton(),
          IconButton(
            icon: const Icon(Icons.menu_rounded, color: kGold),
            tooltip: 'Menu',
            onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
          ),
        ],
      ),
      endDrawer: AdminDrawer(
        currentMenu: AdminMenu.dashboard,
        adminName: widget.adminName,
      ),
      body: Column(
        children: [
          const EmergencyAlertBanner(isAdmin: true),
          Expanded(
            child: SingleChildScrollView(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1120),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeader(),
                        const SizedBox(height: 8),
                        Text(
                          'Choose a work area to continue.',
                          style: TextStyle(
                            color: context.mutedTextColor,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 28),
                        Text(
                          'WORKSPACE',
                          style: TextStyle(
                            color: context.mutedTextColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 12),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final columns = constraints.maxWidth >= 900
                                ? 4
                                : constraints.maxWidth >= 600
                                ? 2
                                : 1;
                            final tileWidth = columns == 1
                                ? constraints.maxWidth
                                : (constraints.maxWidth - 12) / 2;
                            return Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: [
                                _buildWorkflowLink(
                                  context,
                                  width: tileWidth,
                                  title: 'Service requests',
                                  description:
                                      'Review and manage incoming work.',
                                  icon: Icons.description_outlined,
                                  page: const ServiceRequestPage(),
                                ),
                                _buildWorkflowLink(
                                  context,
                                  width: tileWidth,
                                  title: 'Reviews and approvals',
                                  description:
                                      'Handle registrations and pending reviews.',
                                  icon: Icons.fact_check_outlined,
                                  page: const ApprovalPage(),
                                ),
                                _buildWorkflowLink(
                                  context,
                                  width: tileWidth,
                                  title: 'Processing schedule',
                                  description:
                                      'View upcoming and assigned processing.',
                                  icon: Icons.calendar_month_outlined,
                                  page: const ProcessingCalendarPage(),
                                ),
                                _buildWorkflowLink(
                                  context,
                                  width: tileWidth,
                                  title: 'Financial handling',
                                  description:
                                      'Prepare bills and record payments.',
                                  icon: Icons.receipt_long_outlined,
                                  page: const BillingPage(),
                                ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Welcome back,',
          style: TextStyle(color: context.mutedTextColor, fontSize: 14),
        ),
        Text(
          widget.adminName,
          style: TextStyle(
            color: context.textColor,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildWorkflowLink(
    BuildContext context, {
    required double width,
    required String title,
    required String description,
    required IconData icon,
    required Widget page,
  }) {
    return SizedBox(
      width: width,
      height: 152,
      child: Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () =>
              Navigator.push(context, MaterialPageRoute(builder: (_) => page)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: kGold.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(icon, color: kGold, size: 20),
                    ),
                    const Spacer(),
                    Icon(
                      Icons.arrow_forward_rounded,
                      color: context.mutedTextColor,
                      size: 18,
                    ),
                  ],
                ),
                const Spacer(),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: context.textColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: context.mutedTextColor,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogoMark() {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: kGold, width: 1.6),
        color: context.bgColor,
      ),
      child: const Icon(
        Icons.settings_input_component_rounded,
        color: kGold,
        size: 16,
      ),
    );
  }
}
