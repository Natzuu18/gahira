import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:dartz/dartz.dart' hide State;
import '../../core/error/failures.dart';
import '../../domain/entities/user_entity.dart';
import '../../infrastructure/repositories/supabase_service_request_repository.dart';
import '../../infrastructure/repositories/supabase_user_repository.dart';
import '../../infrastructure/supabase/supabase_config.dart';
import '../shared_widgets/appColor.dart';
import '../shared_widgets/adminDrawer.dart';
import '../shared_widgets/themeToggleButton.dart';
import '../shared_widgets/audit_trail_viewer.dart';
import 'approval_page.dart';
import 'availability_page.dart';
import 'add_miner_page.dart';

class MinerClientListPage extends StatefulWidget {
  const MinerClientListPage({super.key});

  @override
  State<MinerClientListPage> createState() => _MinerClientListPageState();
}

class _MinerClientListPageState extends State<MinerClientListPage> with SingleTickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final _repository = SupabaseUserRepository();
  final _serviceRequestRepository = SupabaseServiceRequestRepository();
  late TabController _tabController;
  
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedRoleFilter = 'All'; // 'All', 'miner', 'operator', 'client'
  String _selectedMonthFilter = 'All'; // 'All' or 'January 2025'

  List<UserEntity> _users = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging && _tabController.index == 0) {
        _fetchUsers();
      }
    });
    _fetchUsers();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  List<UserEntity> get _filteredUsers {
    return _users.where((user) {
      // 1. Search Query Filter
      if (_searchQuery.isNotEmpty) {
        final fullName = '${user.fname} ${user.mname ?? ''} ${user.lname}'.toLowerCase();
        final email = user.email.toLowerCase();
        final phone = user.contactNum.toLowerCase();
        if (!fullName.contains(_searchQuery) &&
            !email.contains(_searchQuery) &&
            !phone.contains(_searchQuery)) {
          return false;
        }
      }

      // 2. Role Filter
      if (_selectedRoleFilter != 'All') {
        final r = user.roleId.toLowerCase();
        if (_selectedRoleFilter == 'miner') {
          if (r != 'miner' && r != 'client') return false;
        } else if (r != _selectedRoleFilter.toLowerCase()) {
          return false;
        }
      }

      // 3. Month Approved / Registered Filter
      if (_selectedMonthFilter != 'All') {
        if (user.createdAt == null) return false;
        final monthStr = DateFormat('MMMM yyyy').format(user.createdAt!);
        if (monthStr != _selectedMonthFilter) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  List<String> get _availableMonths {
    final Set<String> months = {'All'};
    for (var u in _users) {
      if (u.createdAt != null) {
        months.add(DateFormat('MMMM yyyy').format(u.createdAt!));
      }
    }
    return months.toList();
  }

  void _showFilterModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: context.textColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'FILTER DIRECTORY',
                      style: TextStyle(
                        color: kGold,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _selectedRoleFilter = 'All';
                          _selectedMonthFilter = 'All';
                        });
                        setModalState(() {});
                      },
                      child: const Text('Reset', style: TextStyle(color: Colors.redAccent)),
                    ),
                  ],
                ),
                const Divider(),
                const SizedBox(height: 8),

                // Role Filter Options
                Text(
                  'User Role',
                  style: TextStyle(
                    color: context.mutedTextColor,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: ['All', 'miner', 'operator'].map((role) {
                    final isSelected = _selectedRoleFilter == role;
                    final label = role == 'All'
                        ? 'All Roles'
                        : (role == 'miner' ? 'Miner' : 'Operator');
                    return ChoiceChip(
                      label: Text(label),
                      selected: isSelected,
                      selectedColor: kGold.withOpacity(0.2),
                      labelStyle: TextStyle(
                        color: isSelected ? kGold : context.textColor,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        fontSize: 12,
                      ),
                      onSelected: (selected) {
                        if (selected) {
                          setState(() => _selectedRoleFilter = role);
                          setModalState(() {});
                        }
                      },
                    );
                  }).toList(),
                ),

                const SizedBox(height: 16),

                // Approved Month Filter Options
                Text(
                  'Month Approved / Registered',
                  style: TextStyle(
                    color: context.mutedTextColor,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _availableMonths.contains(_selectedMonthFilter)
                      ? _selectedMonthFilter
                      : 'All',
                  dropdownColor: context.surfaceColor,
                  style: TextStyle(color: context.textColor, fontSize: 13),
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  items: _availableMonths.map((m) {
                    return DropdownMenuItem(
                      value: m,
                      child: Text(m == 'All' ? 'All Months' : m),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _selectedMonthFilter = val);
                      setModalState(() {});
                    }
                  },
                ),

                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kGold,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Apply Filters', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _fetchUsers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await _repository.getMinersAndClients();
    
    result.fold(
      (failure) {
        setState(() {
          _isLoading = false;
          _errorMessage = failure.message;
        });
      },
      (list) {
        setState(() {
          _users = list;
          _isLoading = false;
        });
      },
    );
  }

  // --- SLIDING SHEET: VIEW USER DETAILS ---
  void _showUserDetails(UserEntity user) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          maxChildSize: 0.9,
          minChildSize: 0.45,
          expand: false,
          builder: (_, controller) => Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: context.textColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: kGold.withOpacity(0.15),
                      child: const Icon(Icons.person, color: kGold, size: 28),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${user.fname} ${user.lname}',
                            style: TextStyle(
                              color: context.textColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                          Text(
                            user.email,
                            style: TextStyle(color: context.mutedTextColor, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    _buildStatusBadge(user.status),
                  ],
                ),
                const Divider(height: 24),
                Expanded(
                  child: ListView(
                    controller: controller,
                    children: [
                      _buildDetailRow('Full Name', '${user.fname} ${user.mname != null && user.mname!.isNotEmpty ? "${user.mname} " : ""}${user.lname}'),
                      _buildDetailRow('Email Address', user.email),
                      _buildDetailRow('Contact Number', user.contactNum),
                      _buildDetailRow('Role', user.roleId.toUpperCase()),
                      _buildDetailRow('Account Status', user.status.toUpperCase()),
                      _buildDetailRow('Associated Unit', user.miningUnitName ?? 'Not set up'),
                      _buildDetailRow('Address', user.address),
                      const SizedBox(height: 16),
                      const Text(
                        'ATTACHED APPLICATION DOCUMENTS',
                        style: TextStyle(
                          color: kGold,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 8),
                      FutureBuilder<List<Map<String, String>>>(
                        future: _fetchUserApplicationDocuments(user.userId),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              child: Center(child: CircularProgressIndicator(color: kGold, strokeWidth: 2)),
                            );
                          }
                          final documents = snapshot.data ?? [];
                          if (documents.isEmpty) {
                            return Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: context.bgColor,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: context.textColor.withOpacity(0.08)),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.folder_off_outlined, color: context.mutedTextColor, size: 20),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'No application documents attached.',
                                      style: TextStyle(color: context.mutedTextColor, fontSize: 12),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }

                          return Column(
                            children: documents.map((doc) {
                              final isPdf = doc['type'] == 'pdf';
                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: context.bgColor,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: context.textColor.withOpacity(0.08)),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 36,
                                      height: 36,
                                      decoration: BoxDecoration(
                                        color: kGold.withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Icon(
                                        isPdf ? Icons.picture_as_pdf_outlined : Icons.insert_drive_file_outlined,
                                        color: kGold,
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            doc['label'] ?? 'Attached Document',
                                            style: TextStyle(
                                              color: context.textColor,
                                              fontWeight: FontWeight.w600,
                                              fontSize: 13,
                                            ),
                                          ),
                                          Text(
                                            'Tap to view / download',
                                            style: TextStyle(color: context.mutedTextColor, fontSize: 11),
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.download_rounded, color: kGold, size: 20),
                                      tooltip: 'Download / View Document',
                                      onPressed: () => _openDocumentUrl(doc['url']!),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.open_in_new, color: kGold, size: 18),
                                      tooltip: 'Open in Browser',
                                      onPressed: () => _openDocumentUrl(doc['url']!),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kGold,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: Text(
                      'Edit ${_profileTypeLabel(user)} Profile',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      _showEditUserSheet(user);
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<List<Map<String, String>>> _fetchUserApplicationDocuments(String userId) async {
    final List<Map<String, String>> docs = [];
    try {
      final appResponse = await SupabaseConfig.client
          .from('applications')
          .select('document_id')
          .eq('user_id', userId);

      for (final app in (appResponse as List)) {
        final docId = app['document_id']?.toString();
        if (docId != null && docId.isNotEmpty) {
          final url = SupabaseConfig.client.storage.from('userFiles').getPublicUrl(docId);
          final lower = docId.toLowerCase();
          String label = 'Application Document';
          String type = 'other';
          if (lower.contains('.png') || lower.contains('.jpg') || lower.contains('.jpeg') || lower.contains('id') || lower.contains('doc_')) {
            label = 'Valid ID / Document';
            type = 'image';
          } else if (lower.contains('.pdf')) {
            label = 'Application Document (PDF)';
            type = 'pdf';
          }
          docs.add({
            'id': docId,
            'label': label,
            'url': url,
            'type': type,
          });
        }
      }

      final personalResponse = await SupabaseConfig.client
          .from('personal_details')
          .select('document_id')
          .eq('user_id', userId);

      for (final pd in (personalResponse as List)) {
        final docId = pd['document_id']?.toString();
        if (docId != null && docId.isNotEmpty) {
          final url = SupabaseConfig.client.storage.from('userFiles').getPublicUrl(docId);
          if (!docs.any((d) => d['id'] == docId)) {
            docs.add({
              'id': docId,
              'label': 'Personal Detail Document',
              'url': url,
              'type': docId.toLowerCase().contains('.pdf') ? 'pdf' : 'image',
            });
          }
        }
      }
    } catch (e) {
      debugPrint('Error fetching miner documents: $e');
    }
    return docs;
  }

  void _openDocumentUrl(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open/download document in browser.')),
        );
      }
    }
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold, color: kGold, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(color: context.textColor, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  // --- SLIDING SHEET: EDIT USER INFORMATION ---
  void _showEditUserSheet(UserEntity user) {
    final profileType = _profileTypeLabel(user);
    final firstNameController = TextEditingController(text: user.fname);
    final middleNameController = TextEditingController(text: user.mname);
    final lastNameController = TextEditingController(text: user.lname);
    final phoneController = TextEditingController(text: user.contactNum);
    final addressController = TextEditingController(text: user.address);
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: DraggableScrollableSheet(
            initialChildSize: 0.75,
            maxChildSize: 0.95,
            minChildSize: 0.5,
            expand: false,
            builder: (_, controller) => Padding(
              padding: const EdgeInsets.all(20.0),
              child: Form(
                key: formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: context.textColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'EDIT $profileType INFORMATION',
                          style: const TextStyle(
                            color: kGold,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, color: kGold),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const Divider(height: 16),
                    Expanded(
                      child: ListView(
                        controller: controller,
                        children: [
                          _buildEditTextField(firstNameController, 'First Name'),
                          const SizedBox(height: 14),
                          _buildEditTextField(middleNameController, 'Middle Name (Optional)', required: false),
                          const SizedBox(height: 14),
                          _buildEditTextField(lastNameController, 'Last Name'),
                          const SizedBox(height: 14),
                          _buildEditTextField(phoneController, 'Phone Number', keyboardType: TextInputType.phone),
                          const SizedBox(height: 14),
                          _buildEditTextField(addressController, 'Address', maxLines: 2),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kGold,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () async {
                          if (formKey.currentState!.validate()) {
                            final updatedUser = UserEntity(
                              userId: user.userId,
                              fname: firstNameController.text.trim(),
                              mname: middleNameController.text.trim(),
                              lname: lastNameController.text.trim(),
                              address: addressController.text.trim(),
                              email: user.email,
                              contactNum: phoneController.text.trim(),
                              roleId: user.roleId,
                              status: user.status,
                            );

                            final result = await _repository.updateUser(updatedUser);
                            if (!mounted) return;
                            Navigator.pop(context);

                            result.fold(
                              (failure) => ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Update failed: ${failure.message}'), backgroundColor: Colors.redAccent),
                              ),
                              (_) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      '$profileType information updated successfully',
                                    ),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                                _fetchUsers();
                              },
                            );
                          }
                        },
                        child: const Text('Save Changes', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  String _profileTypeLabel(UserEntity user) => switch (
    user.roleId.toLowerCase()
  ) {
    'operator' => 'Operator',
    'client' => 'Client',
    _ => 'Miner',
  };

  Widget _buildEditTextField(
    TextEditingController controller, 
    String label, {
    bool required = true, 
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      style: TextStyle(color: context.textColor, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: context.mutedTextColor, fontSize: 13),
        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: kGold.withOpacity(0.3))),
        focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: kGold)),
      ),
      validator: (v) => (required && (v == null || v.isEmpty)) ? 'Required' : null,
    );
  }

  // --- ACTIONS: DELETE & STATUS TOGGLE ---
  Future<void> _deleteUser(UserEntity user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.surfaceColor,
        title: Text('Confirm Delete', style: TextStyle(color: context.textColor, fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to delete ${user.fname} ${user.lname}?', style: TextStyle(color: context.textColor)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final result = await _repository.deleteUser(user.userId);
      result.fold(
        (failure) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(failure.message))),
        (_) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User deleted successfully')));
          _fetchUsers();
        },
      );
    }
  }

  Future<void> _toggleUserStatus(UserEntity user) async {
    final bool currentlyActive = user.status == 'active';
    final String newStatus = currentlyActive ? 'inactive' : 'active';
    final String actionText = currentlyActive ? 'Deactivate' : 'Activate';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.surfaceColor,
        title: Text('$actionText User', style: TextStyle(color: context.textColor, fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to set ${user.fname} ${user.lname} to $newStatus?', style: TextStyle(color: context.textColor)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(actionText, style: TextStyle(color: currentlyActive ? Colors.redAccent : Colors.green)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final result = await _repository.updateUser(UserEntity(
        userId: user.userId,
        fname: user.fname,
        mname: user.mname,
        lname: user.lname,
        address: user.address,
        email: user.email,
        contactNum: user.contactNum,
        roleId: user.roleId,
        status: newStatus,
      ));
      
      result.fold(
        (failure) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(failure.message))),
        (_) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('User set to $newStatus')));
          _fetchUsers();
        },
      );
    }
  }

  // --- SLIDING SHEET: INACTIVE USERS ---
  void _showInactiveUsersModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        expand: false,
        builder: (_, scrollController) => Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: context.textColor.withOpacity(0.2), borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 16),
              const Text(
                'INACTIVE USERS',
                style: TextStyle(color: kGold, fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const Divider(height: 24),
              Expanded(
                child: FutureBuilder(
                  future: _repository.getInactiveUsers(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator(color: kGold));
                    }
                    if (snapshot.hasError) {
                      return Center(child: Text('Error: ${snapshot.error}', style: TextStyle(color: context.textColor)));
                    }
                    final List<UserEntity> inactiveUsers = snapshot.data?.fold((_) => [], (list) => list) ?? [];
                    if (inactiveUsers.isEmpty) {
                      return Center(child: Text('No inactive users found.', style: TextStyle(color: context.textColor)));
                    }
                    return ListView.separated(
                      controller: scrollController,
                      itemCount: inactiveUsers.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final user = inactiveUsers[index];
                        return ListTile(
                          tileColor: context.bgColor,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          leading: const CircleAvatar(child: Icon(Icons.person_off_outlined)),
                          title: Text('${user.fname} ${user.lname}', style: TextStyle(color: context.textColor, fontWeight: FontWeight.bold)),
                          subtitle: Text(user.email, style: TextStyle(color: context.mutedTextColor, fontSize: 12)),
                          trailing: IconButton(
                            icon: const Icon(Icons.person_add_alt_1_outlined, color: Colors.green),
                            onPressed: () {
                              Navigator.pop(context);
                              _toggleUserStatus(user);
                            },
                            tooltip: 'Reactivate',
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- MAIN SLIDING SHEET: 3-DOTS OPTIONS MENU ---
  void _showUserOptions(UserEntity user) {
    final bool isActive = user.status == 'active' || user.status == 'approved';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.65,
          maxChildSize: 0.9,
          minChildSize: 0.35,
          expand: false,
          builder: (_, controller) => Column(
            children: [
              const SizedBox(height: 12),
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: context.textColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: kGold.withOpacity(0.15),
                      child: const Icon(Icons.person, color: kGold, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${user.fname} ${user.lname}',
                            style: TextStyle(
                              color: context.textColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            '${user.email} • ${user.roleId.toUpperCase()}',
                            style: TextStyle(
                              color: context.mutedTextColor,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _buildStatusBadge(user.status),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView(
                  controller: controller,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  children: [
                    _buildOptionItem(
                      icon: Icons.folder_open_outlined,
                      label: 'View Uploaded Documents & ID',
                      onTap: () {
                        Navigator.pop(context);
                        _showUserDetails(user);
                      },
                    ),
                    _buildOptionItem(
                      icon: Icons.settings_input_component_rounded,
                      label: 'View Associated Ball Mill / Plant',
                      onTap: () {
                        Navigator.pop(context);
                        _showMiningUnitModal(user);
                      },
                    ),
                    _buildOptionItem(
                      icon: Icons.history_rounded,
                      label: 'View Service Request History',
                      onTap: () {
                        Navigator.pop(context);
                        _showServiceRequestsModal(user);
                      },
                    ),
                    _buildOptionItem(
                      icon: Icons.receipt_long_outlined,
                      label: 'View Billing & Payment Records',
                      onTap: () {
                        Navigator.pop(context);
                        _showBillingRecordsModal(user);
                      },
                    ),
                    const Divider(height: 16, indent: 16, endIndent: 16),
                    _buildOptionItem(
                      icon: isActive ? Icons.block_flipped : Icons.check_circle_outline,
                      iconColor: isActive ? Colors.orange : Colors.green,
                      label: isActive ? 'Deactivate User Account' : 'Reactivate User Account',
                      onTap: () {
                        Navigator.pop(context);
                        _toggleUserStatus(user);
                      },
                    ),
                    _buildOptionItem(
                      icon: Icons.delete_forever_rounded,
                      iconColor: Colors.redAccent,
                      label: 'Permanently Delete User',
                      onTap: () {
                        Navigator.pop(context);
                        _deleteUser(user);
                      },
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOptionItem({
    required IconData icon, 
    required String label, 
    required VoidCallback onTap,
    Color? iconColor,
  }) {
    return ListTile(
      leading: Icon(icon, color: iconColor ?? kGold, size: 22),
      title: Text(
        label,
        style: TextStyle(
          color: iconColor ?? context.textColor, 
          fontSize: 14, 
          fontWeight: FontWeight.w500
        ),
      ),
      trailing: Icon(Icons.chevron_right_rounded, color: context.mutedTextColor, size: 18),
      onTap: onTap,
    );
  }

  // --- SLIDING SHEET: ASSOCIATED MINING UNIT ---
  void _showMiningUnitModal(UserEntity user) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.5,
          maxChildSize: 0.8,
          minChildSize: 0.3,
          expand: false,
          builder: (_, controller) => Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: context.textColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'ASSOCIATED MINING UNIT',
                  style: TextStyle(
                    color: kGold,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  'User: ${user.fname} ${user.lname}',
                  style: TextStyle(color: context.mutedTextColor, fontSize: 13),
                ),
                const Divider(height: 24),
                Expanded(
                  child: FutureBuilder<Map<String, dynamic>?>(
                    future: _fetchMiningUnitDetails(user),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator(color: kGold));
                      }
                      final unit = snapshot.data;
                      if (unit == null) {
                        return Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.location_off_outlined, color: Colors.orange, size: 48),
                              const SizedBox(height: 12),
                              Text(
                                'No Associated Mining Unit',
                                style: TextStyle(color: context.textColor, fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'This user is not currently linked to any ball mill or processing plant.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: context.mutedTextColor, fontSize: 13),
                              ),
                            ],
                          ),
                        );
                      }
                      return ListView(
                        controller: controller,
                        children: [
                          _buildDetailRow('Unit Name', unit['name']?.toString() ?? 'N/A'),
                          _buildDetailRow('Unit Type', unit['type']?.toString() ?? 'N/A'),
                          _buildDetailRow('Location', unit['location']?.toString() ?? 'Not specified'),
                          _buildDetailRow('Created At', unit['created_at'] != null ? DateFormat.yMMMd().format(DateTime.parse(unit['created_at'])) : 'N/A'),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<Map<String, dynamic>?> _fetchMiningUnitDetails(UserEntity user) async {
    if (user.miningUnitId == null || user.miningUnitId!.isEmpty) {
      if (user.miningUnitName != null && user.miningUnitName!.isNotEmpty) {
        return {
          'name': user.miningUnitName,
          'type': user.miningUnitType ?? 'Mining Unit',
          'location': 'Assigned Unit',
        };
      }
      return null;
    }
    try {
      final response = await SupabaseConfig.client
          .from('mining_units')
          .select()
          .eq('id', user.miningUnitId!)
          .maybeSingle();
      return response;
    } catch (_) {
      return null;
    }
  }

  // --- SLIDING SHEET: SERVICE REQUEST HISTORY ---
  void _showServiceRequestsModal(UserEntity user) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          maxChildSize: 0.9,
          minChildSize: 0.4,
          expand: false,
          builder: (_, controller) => Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: context.textColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'SERVICE REQUEST HISTORY',
                  style: TextStyle(
                    color: kGold,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  'History for ${user.fname} ${user.lname}',
                  style: TextStyle(color: context.mutedTextColor, fontSize: 13),
                ),
                const Divider(height: 24),
                Expanded(
                  child: FutureBuilder<List<Map<String, dynamic>>>(
                    future: _fetchUserServiceRequests(user.userId),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator(color: kGold));
                      }
                      if (snapshot.hasError) {
                        return Center(child: Text('Error loading requests: ${snapshot.error}', style: const TextStyle(color: Colors.redAccent)));
                      }
                      final requests = snapshot.data ?? [];
                      if (requests.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.history_toggle_off_rounded, color: context.mutedTextColor, size: 48),
                              const SizedBox(height: 12),
                              Text(
                                'No Service Requests Found',
                                style: TextStyle(color: context.textColor, fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'This miner has no recorded service requests yet.',
                                style: TextStyle(color: context.mutedTextColor, fontSize: 13),
                              ),
                            ],
                          ),
                        );
                      }
                      return ListView.separated(
                        controller: controller,
                        itemCount: requests.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final req = requests[index];
                          final dateStr = req['request_date'] ?? req['created_at'];
                          final formattedDate = dateStr != null ? DateFormat.yMMMd().format(DateTime.parse(dateStr)) : 'N/A';
                          final status = (req['status'] ?? 'pending').toString();
                          final serviceType = (req['service_type'] ?? 'Processing').toString();
                          final quantity = req['quantity']?.toString() ?? '1';

                          return Container(
                            decoration: BoxDecoration(
                              color: context.bgColor,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: context.textColor.withOpacity(0.08)),
                            ),
                            child: Column(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        backgroundColor: kGold.withOpacity(0.1),
                                        child: const Icon(Icons.assignment_outlined, color: kGold, size: 20),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              serviceType,
                                              style: TextStyle(color: context.textColor, fontWeight: FontWeight.bold, fontSize: 14),
                                            ),
                                            Text(
                                              'Quantity: $quantity sacks • Date: $formattedDate',
                                              style: TextStyle(color: context.mutedTextColor, fontSize: 12),
                                            ),
                                          ],
                                        ),
                                      ),
                                      _buildStatusBadge(status),
                                    ],
                                  ),
                                ),
                                ExpansionTile(
                                  tilePadding: const EdgeInsets.symmetric(horizontal: 12),
                                  childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                                  leading: const Icon(Icons.history_rounded, color: kGold, size: 20),
                                  title: const Text(
                                    'Audit Trail',
                                    style: TextStyle(color: kGold, fontSize: 13, fontWeight: FontWeight.w600),
                                  ),
                                  children: [
                                    FutureBuilder<Either<Failure, List<Map<String, dynamic>>>>(
                                      future: _serviceRequestRepository.getAuditTrails(
                                        req['service_request_id']?.toString() ?? '',
                                      ),
                                      builder: (context, auditSnapshot) {
                                        if (auditSnapshot.hasData) {
                                          return auditSnapshot.data!.fold(
                                            (failure) => Text(
                                              'Error loading audit trail: ${failure.message}',
                                              style: const TextStyle(color: Colors.redAccent),
                                            ),
                                            (trails) => AuditTrailViewer(auditTrails: trails),
                                          );
                                        }
                                        return const Padding(
                                          padding: EdgeInsets.all(16),
                                          child: Center(
                                            child: CircularProgressIndicator(color: kGold),
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<List<Map<String, dynamic>>> _fetchUserServiceRequests(String userId) async {
    try {
      final response = await SupabaseConfig.client
          .from('service_requests')
          .select()
          .or('user_id.eq.$userId,participating_miners.cs.{$userId}')
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (_) {
      return [];
    }
  }

  // --- SLIDING SHEET: BILLING RECORDS ---
  void _showBillingRecordsModal(UserEntity user) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          maxChildSize: 0.9,
          minChildSize: 0.4,
          expand: false,
          builder: (_, controller) => Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: context.textColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'BILLING & FINANCIAL RECORDS',
                  style: TextStyle(
                    color: kGold,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  'Financial records for ${user.fname} ${user.lname}',
                  style: TextStyle(color: context.mutedTextColor, fontSize: 13),
                ),
                const Divider(height: 24),
                Expanded(
                  child: FutureBuilder<List<Map<String, dynamic>>>(
                    future: _fetchUserBillingRecords(user.userId),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator(color: kGold));
                      }
                      if (snapshot.hasError) {
                        return Center(child: Text('Error loading financial records: ${snapshot.error}', style: const TextStyle(color: Colors.redAccent)));
                      }
                      final records = snapshot.data ?? [];
                      if (records.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.receipt_long_outlined, color: context.mutedTextColor, size: 48),
                              const SizedBox(height: 12),
                              Text(
                                'No Billing Records Found',
                                style: TextStyle(color: context.textColor, fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'This miner has no billing or financial records.',
                                style: TextStyle(color: context.mutedTextColor, fontSize: 13),
                              ),
                            ],
                          ),
                        );
                      }
                      return ListView.separated(
                        controller: controller,
                        itemCount: records.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final rec = records[index];
                          final amount = rec['total_due'] ?? rec['total_bill'] ?? rec['share_amount'] ?? 0;
                          final paid = rec['amount_paid'] ?? rec['payment_amount'] ?? 0;
                          final status = (rec['status'] ?? 'unpaid').toString();
                          final dateStr = rec['last_payment_at'] ?? rec['created_at'];
                          final formattedDate = dateStr != null ? DateFormat.yMMMd().format(DateTime.parse(dateStr)) : 'N/A';

                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: context.bgColor,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: context.textColor.withOpacity(0.08)),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: kGold.withOpacity(0.1),
                                  child: const Icon(Icons.payments_outlined, color: kGold, size: 20),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Due: ₱${amount.toString()}',
                                        style: TextStyle(color: context.textColor, fontWeight: FontWeight.bold, fontSize: 14),
                                      ),
                                      Text(
                                        'Paid: ₱${paid.toString()} • Date: $formattedDate',
                                        style: TextStyle(color: context.mutedTextColor, fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                                _buildStatusBadge(status),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<List<Map<String, dynamic>>> _fetchUserBillingRecords(String userId) async {
    try {
      final response = await SupabaseConfig.client
          .from('service_participant_financials')
          .select()
          .eq('user_id', userId)
          .order('last_payment_at', ascending: false);
      if ((response as List).isNotEmpty) {
        return List<Map<String, dynamic>>.from(response);
      }
      final reqResponse = await SupabaseConfig.client
          .from('service_requests')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(reqResponse);
    } catch (_) {
      return [];
    }
  }

  Widget _buildDirectoryContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: kGold));
    }
    if (_errorMessage != null) {
      return _buildErrorState();
    }

    final filteredList = _filteredUsers;

    return Column(
      children: [
        // Search & Filter Header Bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  style: TextStyle(color: context.textColor, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Search by name, email, or phone...',
                    hintStyle: TextStyle(color: context.mutedTextColor, fontSize: 12),
                    prefixIcon: const Icon(Icons.search_rounded, color: kGold, size: 20),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, color: kGold, size: 18),
                            onPressed: () {
                              setState(() {
                                _searchController.clear();
                                _searchQuery = '';
                              });
                            },
                          )
                        : null,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                    filled: true,
                    fillColor: context.surfaceColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: kGold.withOpacity(0.2)),
                    ),
                  ),
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val.trim().toLowerCase();
                    });
                  },
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: _showFilterModal,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: (_selectedRoleFilter != 'All' || _selectedMonthFilter != 'All')
                        ? kGold.withOpacity(0.2)
                        : context.surfaceColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: (_selectedRoleFilter != 'All' || _selectedMonthFilter != 'All')
                          ? kGold
                          : kGold.withOpacity(0.2),
                    ),
                  ),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      const Icon(Icons.filter_list_rounded, color: kGold, size: 22),
                      if (_selectedRoleFilter != 'All' || _selectedMonthFilter != 'All')
                        Positioned(
                          right: -2,
                          top: -2,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        // List Content
        Expanded(
          child: filteredList.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.search_off_rounded, color: context.mutedTextColor, size: 48),
                      const SizedBox(height: 12),
                      Text(
                        'No matching users found.',
                        style: TextStyle(color: context.textColor, fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Try adjusting your search terms or filters.',
                        style: TextStyle(color: context.mutedTextColor, fontSize: 12),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _fetchUsers,
                  color: kGold,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredList.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final user = filteredList[index];
                      return _buildUserCard(user);
                    },
                  ),
                ),
        ),
      ],
    );
  }

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
          'MINERS',
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
            icon: const Icon(Icons.person_add_alt_1_outlined, color: kGold),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AddMinerPage()),
              );
              _fetchUsers();
            },
            tooltip: 'Add Miner',
          ),
          IconButton(
            icon: const Icon(Icons.person_off_outlined, color: kGold),
            onPressed: _showInactiveUsersModal,
            tooltip: 'View Inactive Users',
          ),
          const ThemeToggleButton(),
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: kGold,
          unselectedLabelColor: context.mutedTextColor,
          indicatorColor: kGold,
          tabs: const [
            Tab(text: 'Directory'),
            Tab(text: 'Requests'),
            Tab(text: 'Schedule'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildDirectoryContent(),
          const ApprovalPage(embedInTab: true),
          const AvailabilityPage(embedInTab: true),
        ],
      ),
    );
  }

  Widget _buildUserCard(UserEntity user) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.textColor.withOpacity(0.08)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: kGold.withOpacity(0.1),
                child: const Icon(Icons.person_outline, color: kGold),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${user.fname} ${user.lname}',
                      style: TextStyle(
                        color: context.textColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      user.email,
                      style: TextStyle(color: context.mutedTextColor, fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.foundation_outlined, size: 12, color: kGold.withOpacity(0.7)),
                        const SizedBox(width: 4),
                        Text(
                          user.miningUnitName ?? 'Unit: Not set up',
                          style: TextStyle(
                            color: user.miningUnitName != null ? context.textColor.withOpacity(0.8) : Colors.orangeAccent,
                            fontSize: 11,
                            fontWeight: user.miningUnitName != null ? FontWeight.w500 : FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              _buildStatusBadge(user.status),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Role: ${user.roleId.toUpperCase()}',
                style: TextStyle(color: context.textColor.withOpacity(0.7), fontSize: 12, fontWeight: FontWeight.w500),
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.visibility_outlined, size: 20, color: kGold),
                    onPressed: () => _showUserDetails(user),
                    tooltip: 'View Details',
                  ),
                  IconButton(
                    icon: const Icon(Icons.more_vert_rounded, size: 22, color: kGold),
                    onPressed: () => _showUserOptions(user),
                    tooltip: 'More Options',
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    switch (status) {
      case 'active':
        color = Colors.green;
        break;
      case 'inactive':
        color = Colors.red;
        break;
      default:
        color = Colors.orange;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.people_outline, color: context.mutedTextColor, size: 48),
          const SizedBox(height: 16),
          Text('No miners or clients found.', style: TextStyle(color: context.textColor)),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
            const SizedBox(height: 16),
            Text(_errorMessage ?? 'An error occurred', textAlign: TextAlign.center, style: TextStyle(color: context.textColor)),
            const SizedBox(height: 24),
            ElevatedButton(onPressed: _fetchUsers, child: const Text('Retry')),
          ],
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
      child: const Icon(Icons.settings_input_component_rounded, color: kGold, size: 16),
    );
  }
}
