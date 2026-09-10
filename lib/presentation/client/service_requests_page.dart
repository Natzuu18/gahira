import 'package:flutter/material.dart';

import '../shared_widgets/appColor.dart';
import '../shared_widgets/themeToggleButton.dart';
import 'client_drawer.dart';

// Gahira Ball Mill Management System - Service Requests Page
// Clients can view and submit service requests for gold processing

class ServiceRequestsPage extends StatefulWidget {
  const ServiceRequestsPage({super.key});

  @override
  State<ServiceRequestsPage> createState() => _ServiceRequestsPageState();
}

class _ServiceRequestsPageState extends State<ServiceRequestsPage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  String _selectedFilter = 'All';

  final List<Map<String, dynamic>> _mockRequests = [
    {
      'id': 'REQ-2024-015',
      'title': 'Gold Ore Processing',
      'status': 'In Progress',
      'date': '2024-01-15',
      'materialType': 'Gold Ore',
      'quantity': '500 kg',
      'estimatedWeight': '12.5 kg',
    },
    {
      'id': 'REQ-2024-014',
      'title': 'Silver Refining',
      'status': 'Scheduled',
      'date': '2024-01-18',
      'materialType': 'Silver',
      'quantity': '300 kg',
      'estimatedWeight': '8.2 kg',
    },
    {
      'id': 'REQ-2024-013',
      'title': 'Copper Concentration',
      'status': 'Pending',
      'date': '2024-01-20',
      'materialType': 'Copper',
      'quantity': '750 kg',
      'estimatedWeight': '45.0 kg',
    },
    {
      'id': 'REQ-2024-012',
      'title': 'Gold Ore Processing',
      'status': 'Completed',
      'date': '2024-01-10',
      'materialType': 'Gold Ore',
      'quantity': '400 kg',
      'estimatedWeight': '10.8 kg',
    },
    {
      'id': 'REQ-2024-011',
      'title': 'Mixed Metal Processing',
      'status': 'Completed',
      'date': '2024-01-05',
      'materialType': 'Mixed',
      'quantity': '600 kg',
      'estimatedWeight': '28.5 kg',
    },
    {
      'id': 'REQ-2024-010',
      'title': 'Gold Ore Processing',
      'status': 'Approved',
      'date': '2024-01-22',
      'materialType': 'Gold Ore',
      'quantity': '350 kg',
      'estimatedWeight': '9.2 kg',
    },
    {
      'id': 'REQ-2024-009',
      'title': 'Silver Refining',
      'status': 'Pending',
      'date': '2024-01-25',
      'materialType': 'Silver',
      'quantity': '200 kg',
      'estimatedWeight': '5.5 kg',
    },
  ];

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
          'GAHIRA',
          style: TextStyle(
            color: kGold,
            fontWeight: FontWeight.bold,
            letterSpacing: 3,
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
      endDrawer: const ClientDrawer(
        currentMenu: ClientMenu.serviceRequests,
        clientName: 'Client',
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showNewRequestDialog,
        backgroundColor: kGold,
        foregroundColor: kBlack,
        child: const Icon(Icons.add_rounded),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Text(
              'Service Requests',
              style: TextStyle(
                color: context.textColor,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'View and manage your processing service requests',
              style: TextStyle(
                color: context.mutedTextColor,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),

            // Filter chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('All'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Pending'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Approved'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Scheduled'),
                  const SizedBox(width: 8),
                  _buildFilterChip('In Progress'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Completed'),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Request list
            ..._filteredRequests.map((request) => _buildRequestCard(request)),
            const SizedBox(height: 80), // Space for FAB
          ],
        ),
      ),
    );
  }

  List<Map<String, dynamic>> get _filteredRequests {
    if (_selectedFilter == 'All') return _mockRequests;
    return _mockRequests.where((r) => r['status'] == _selectedFilter).toList();
  }

  Widget _buildFilterChip(String label) {
    final bool selected = _selectedFilter == label;
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (bool selected) {
        setState(() {
          _selectedFilter = selected ? label : 'All';
        });
      },
      backgroundColor: context.surfaceColor,
      selectedColor: kGold.withOpacity(0.2),
      labelStyle: TextStyle(
        color: selected ? kGold : context.textColor,
        fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
      ),
      checkmarkColor: kGold,
      side: BorderSide(color: kGold.withOpacity(0.3)),
    );
  }

  Widget _buildRequestCard(Map<String, dynamic> request) {
    final String status = request['status'];
    final Color statusColor = _getStatusColor(status);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kGold.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.description_outlined,
                  color: statusColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      request['title'],
                      style: TextStyle(
                        color: context.textColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      request['id'],
                      style: TextStyle(
                        color: context.mutedTextColor,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
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
          const Divider(height: 1),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildDetailItem('Material', request['materialType']),
              const SizedBox(width: 24),
              _buildDetailItem('Quantity', request['quantity']),
              const SizedBox(width: 24),
              _buildDetailItem('Est. Weight', request['estimatedWeight']),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.calendar_today_outlined,
                  color: context.mutedTextColor, size: 14),
              const SizedBox(width: 4),
              Text(
                'Date: ${request['date']}',
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

  Widget _buildDetailItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(color: context.mutedTextColor, fontSize: 10),
        ),
        Text(
          value,
          style: TextStyle(
            color: context.textColor,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'In Progress':
        return Colors.green;
      case 'Scheduled':
        return Colors.blue;
      case 'Pending':
        return Colors.orange;
      case 'Approved':
        return Colors.teal;
      case 'Completed':
        return Colors.purple;
      default:
        return kGold;
    }
  }

  void _showNewRequestDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.surfaceColor,
        title: Text(
          'New Service Request',
          style: TextStyle(color: context.textColor),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'This is a placeholder for the new service request form.',
                style: TextStyle(color: context.mutedTextColor),
              ),
              const SizedBox(height: 16),
              Text(
                'In a full implementation, this would include:',
                style: TextStyle(color: context.textColor),
              ),
              const SizedBox(height: 8),
              _buildPlaceholderItem('Material type selection'),
              _buildPlaceholderItem('Quantity input'),
              _buildPlaceholderItem('Estimated weight'),
              _buildPlaceholderItem('Special instructions'),
              _buildPlaceholderItem('Preferred schedule'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel', style: TextStyle(color: kGold)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: kGold,
              foregroundColor: kBlack,
            ),
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholderItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, bottom: 4),
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline, color: kGold, size: 16),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(color: context.mutedTextColor, fontSize: 13),
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
}
