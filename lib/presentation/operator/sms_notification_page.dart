import 'package:flutter/material.dart';

import '../shared_widgets/appColor.dart';
import '../shared_widgets/themeToggleButton.dart';
import 'operator_drawer.dart';

class SMSNotificationPage extends StatefulWidget {
  const SMSNotificationPage({super.key});

  @override
  State<SMSNotificationPage> createState() => _SMSNotificationPageState();
}

class _SMSNotificationPageState extends State<SMSNotificationPage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _recipientController = TextEditingController();

  // Mock data
  final List<Map<String, dynamic>> _notifications = [
    {
      'id': 'SMS-001',
      'type': 'Processing Update',
      'recipient': '+63 912 345 6789',
      'recipientName': 'John Smith',
      'message': 'Your gold processing job JOB-001 has moved to Grinding stage.',
      'status': 'Delivered',
      'sentDate': '2024-01-17 10:30 AM',
    },
    {
      'id': 'SMS-002',
      'type': 'Payment Confirmation',
      'recipient': '+63 923 456 7890',
      'recipientName': 'Jane Doe',
      'message': 'Payment of ₱50,000 for invoice INV-001 has been received.',
      'status': 'Delivered',
      'sentDate': '2024-01-17 09:15 AM',
    },
    {
      'id': 'SMS-003',
      'type': 'Maintenance Reminder',
      'recipient': '+63 934 567 8901',
      'recipientName': 'Mike Johnson',
      'message': 'Scheduled maintenance for Mill #04 on 2024-01-22 at 08:00 AM.',
      'status': 'Pending',
      'sentDate': '2024-01-17 08:00 AM',
    },
    {
      'id': 'SMS-004',
      'type': 'Schedule Notification',
      'recipient': '+63 912 345 6789',
      'recipientName': 'John Smith',
      'message': 'Your processing job is scheduled for 2024-01-18 at 09:00 AM.',
      'status': 'Delivered',
      'sentDate': '2024-01-16 03:00 PM',
    },
  ];

  final List<Map<String, dynamic>> _templates = [
    {
      'id': 'TPL-001',
      'name': 'Processing Update',
      'category': 'Processing',
      'message': 'Your gold processing job {JOB_ID} has moved to {STAGE} stage.',
    },
    {
      'id': 'TPL-002',
      'name': 'Payment Confirmation',
      'category': 'Billing',
      'message': 'Payment of {AMOUNT} for invoice {INVOICE_ID} has been received.',
    },
    {
      'id': 'TPL-003',
      'name': 'Maintenance Reminder',
      'category': 'Maintenance',
      'message': 'Scheduled maintenance for {EQUIPMENT} on {DATE} at {TIME}.',
    },
    {
      'id': 'TPL-004',
      'name': 'Schedule Notification',
      'category': 'Processing',
      'message': 'Your processing job is scheduled for {DATE} at {TIME}.',
    },
    {
      'id': 'TPL-005',
      'name': 'Emergency Alert',
      'category': 'Emergency',
      'message': 'URGENT: {ALERT_MESSAGE}. Please contact us immediately.',
    },
  ];

  @override
  void dispose() {
    _messageController.dispose();
    _recipientController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
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
            'SMS NOTIFICATIONS',
            style: TextStyle(
              color: kGold,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
              fontSize: 16,
            ),
          ),
          iconTheme: const IconThemeData(color: kGold),
          actions: [
            IconButton(
              icon: const Icon(Icons.send_rounded, color: kGold),
              onPressed: _showComposeDialog,
              tooltip: 'Compose SMS',
            ),
            const ThemeToggleButton(),
            IconButton(
              icon: const Icon(Icons.menu_rounded, color: kGold),
              tooltip: 'Menu',
              onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
            ),
          ],
          bottom: TabBar(
            labelColor: kGold,
            unselectedLabelColor: context.mutedTextColor,
            indicatorColor: kGold,
            tabs: const [
              Tab(text: 'History'),
              Tab(text: 'Templates'),
            ],
          ),
        ),
        endDrawer: const OperatorDrawer(
          currentMenu: OperatorMenu.sms,
          operatorName: 'Operator',
        ),
        body: TabBarView(
          children: [
            _buildHistoryTab(),
            _buildTemplatesTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 1.6,
            children: [
              _buildSummaryCard('Total Sent', '4', Icons.sms_rounded, kGold),
              _buildSummaryCard('Delivered', '3', Icons.check_circle_outline_rounded, Colors.green),
              _buildSummaryCard('Pending', '1', Icons.pending_rounded, Colors.orange),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Notification History',
                style: TextStyle(
                  color: context.textColor,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: kGold.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: kGold.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.filter_list_rounded, color: kGold, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      'Filter',
                      style: TextStyle(
                        color: kGold,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ..._notifications.map((notification) => _buildNotificationCard(notification)),
        ],
      ),
    );
  }

  Widget _buildTemplatesTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 1.6,
            children: [
              _buildSummaryCard('Total Templates', '5', Icons.description_rounded, kGold),
              _buildSummaryCard('Processing', '2', Icons.settings_rounded, Colors.blue),
              _buildSummaryCard('Other', '3', Icons.category_rounded, Colors.orange),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Message Templates',
                style: TextStyle(
                  color: context.textColor,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              ElevatedButton.icon(
                onPressed: _showCreateTemplateDialog,
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('Create Template'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kGold,
                  foregroundColor: kBlack,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ..._templates.map((template) => _buildTemplateCard(template)),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kGold.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: color, size: 24),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  color: context.textColor,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                title,
                style: TextStyle(
                  color: context.mutedTextColor,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationCard(Map<String, dynamic> notification) {
    final status = notification['status'];
    final statusColor = status == 'Delivered' ? Colors.green : Colors.orange;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kGold.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.sms_rounded, color: statusColor, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notification['recipientName'],
                      style: TextStyle(
                        color: context.textColor,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      notification['recipient'],
                      style: TextStyle(
                        color: context.mutedTextColor,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: statusColor.withOpacity(0.3)),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: kGold.withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.message_rounded, color: kGold, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    notification['message'],
                    style: TextStyle(
                      color: context.textColor,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildInfoChip('Type', notification['type']),
              const SizedBox(width: 8),
              _buildInfoChip('Sent', notification['sentDate']),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _resendNotification(notification),
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text('Resend'),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: kGold.withOpacity(0.3)),
                    foregroundColor: context.textColor,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _viewNotificationDetails(notification),
                  icon: const Icon(Icons.visibility_outlined, size: 16),
                  label: const Text('Details'),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: kGold.withOpacity(0.3)),
                    foregroundColor: context.textColor,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTemplateCard(Map<String, dynamic> template) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kGold.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: kGold.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.description_rounded, color: kGold, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      template['name'],
                      style: TextStyle(
                        color: context.textColor,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      template['category'],
                      style: TextStyle(
                        color: context.mutedTextColor,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: kGold.withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.message_rounded, color: kGold, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    template['message'],
                    style: TextStyle(
                      color: context.textColor,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _useTemplate(template),
                  icon: const Icon(Icons.send_rounded, size: 16),
                  label: const Text('Use Template'),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: kGold.withOpacity(0.3)),
                    foregroundColor: context.textColor,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _editTemplate(template),
                  icon: const Icon(Icons.edit_rounded, size: 16),
                  label: const Text('Edit'),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: kGold.withOpacity(0.3)),
                    foregroundColor: context.textColor,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: kGold.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: kGold.withOpacity(0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              color: context.mutedTextColor,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: context.textColor,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
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

  void _showComposeDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.surfaceColor,
        title: Text(
          'Compose SMS',
          style: TextStyle(color: context.textColor),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _recipientController,
                style: TextStyle(color: context.textColor),
                decoration: InputDecoration(
                  labelText: 'Recipient Phone',
                  labelStyle: TextStyle(color: context.mutedTextColor),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: kGold.withOpacity(0.5)),
                  ),
                  focusedBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: kGold),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _messageController,
                style: TextStyle(color: context.textColor),
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: 'Message',
                  labelStyle: TextStyle(color: context.mutedTextColor),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: kGold.withOpacity(0.5)),
                  ),
                  focusedBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: kGold),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: kGold),
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('SMS sent (mock)'),
                  backgroundColor: kGold,
                ),
              );
              _messageController.clear();
              _recipientController.clear();
            },
            child: const Text('Send', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showCreateTemplateDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.surfaceColor,
        title: Text(
          'Create Template',
          style: TextStyle(color: context.textColor),
        ),
        content: const Text('Template creation form - UI only (no backend)'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: kGold),
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Template created (mock)'),
                  backgroundColor: kGold,
                ),
              );
            },
            child: const Text('Create', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _resendNotification(Map<String, dynamic> notification) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Resending to ${notification['recipient']} (mock)'),
        backgroundColor: kGold,
      ),
    );
  }

  void _viewNotificationDetails(Map<String, dynamic> notification) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.surfaceColor,
        title: Text(
          'Notification Details: ${notification['id']}',
          style: TextStyle(color: context.textColor),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('Type', notification['type']),
              _buildDetailRow('Recipient', notification['recipient']),
              _buildDetailRow('Recipient Name', notification['recipientName']),
              _buildDetailRow('Status', notification['status']),
              _buildDetailRow('Sent Date', notification['sentDate']),
              const SizedBox(height: 12),
              Text(
                'Message:',
                style: TextStyle(
                  color: context.mutedTextColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: kGold.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  notification['message'],
                  style: TextStyle(
                    color: context.textColor,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: Colors.grey)),
          ),
        ],
      ),
    );
  }

  void _useTemplate(Map<String, dynamic> template) {
    _messageController.text = template['message'];
    _showComposeDialog();
  }

  void _editTemplate(Map<String, dynamic> template) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Editing template ${template['id']} (mock)'),
        backgroundColor: kGold,
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: TextStyle(
                color: context.mutedTextColor,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: context.textColor,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
