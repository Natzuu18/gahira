import 'package:flutter/material.dart';
import '../../domain/entities/user_entity.dart';
import '../../infrastructure/repositories/supabase_user_repository.dart';
import '../shared_widgets/appColor.dart';
import '../shared_widgets/adminDrawer.dart';
import '../shared_widgets/themeToggleButton.dart';

class MinerClientListPage extends StatefulWidget {
  const MinerClientListPage({super.key});

  @override
  State<MinerClientListPage> createState() => _MinerClientListPageState();
}

class _MinerClientListPageState extends State<MinerClientListPage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final _repository = SupabaseUserRepository();
  
  List<UserEntity> _users = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchUsers();
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

  void _showUserDetails(UserEntity user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.surfaceColor,
        title: Text(
          'User Details',
          style: TextStyle(color: context.textColor, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('Full Name', '${user.fname} ${user.lname}'),
            _buildDetailRow('Email', user.email),
            _buildDetailRow('Contact', user.contactNum),
            _buildDetailRow('Role', user.roleId.toUpperCase()),
            _buildDetailRow('Status', user.status.toUpperCase()),
            _buildDetailRow('Associated Unit', user.miningUnitName ?? 'Not set up'),
            _buildDetailRow('Address', user.address),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: kGold)),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.bold, color: kGold, fontSize: 13)),
          Expanded(child: Text(value, style: TextStyle(color: context.textColor, fontSize: 13))),
        ],
      ),
    );
  }

  Future<void> _deleteUser(UserEntity user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: Text('Are you sure you want to delete ${user.fname} ${user.lname}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
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
          title: Text('$actionText User'),
          content: Text('Are you sure you want to set ${user.fname} to $newStatus?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(actionText, style: TextStyle(color: currentlyActive ? Colors.red : Colors.green)),
            ),
          ],
        ),
      );

      if (confirmed == true) {
        // Fetch original user data to ensure we have the UUID for role_id if possible,
        // or just rely on the repository mapping we just added.
        final result = await _repository.updateUser(UserEntity(
          userId: user.userId,
          fname: user.fname,
          mname: user.mname,
          lname: user.lname,
          address: user.address,
          email: user.email,
          contactNum: user.contactNum,
          roleId: user.roleId, // This is "miner" or "operator"
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

  void _showInactiveUsersModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        builder: (_, scrollController) => Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'INACTIVE USERS',
                  style: TextStyle(color: kGold, fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ),
              const Divider(),
              Expanded(
                child: FutureBuilder(
                  future: _repository.getInactiveUsers(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator(color: kGold));
                    }
                    if (snapshot.hasError) {
                      return Center(child: Text('Error: ${snapshot.error}'));
                    }
                    final List<UserEntity> inactiveUsers = snapshot.data?.fold((_) => [], (list) => list) ?? [];
                    if (inactiveUsers.isEmpty) {
                      return const Center(child: Text('No inactive users found.'));
                    }
                    return ListView.separated(
                      controller: scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: inactiveUsers.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final user = inactiveUsers[index];
                        return ListTile(
                          tileColor: Theme.of(context).cardColor,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          leading: const CircleAvatar(child: Icon(Icons.person_off_outlined)),
                          title: Text('${user.fname} ${user.lname}'),
                          subtitle: Text(user.email),
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

  void _showEditUserDialog(UserEntity user) {
    final firstNameController = TextEditingController(text: user.fname);
    final middleNameController = TextEditingController(text: user.mname);
    final lastNameController = TextEditingController(text: user.lname);
    final phoneController = TextEditingController(text: user.contactNum);
    final addressController = TextEditingController(text: user.address);
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.surfaceColor,
        title: Text(
          'Edit User Information',
          style: TextStyle(color: context.textColor, fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildEditTextField(firstNameController, 'First Name'),
                const SizedBox(height: 12),
                _buildEditTextField(middleNameController, 'Middle Name (Optional)', required: false),
                const SizedBox(height: 12),
                _buildEditTextField(lastNameController, 'Last Name'),
                const SizedBox(height: 12),
                _buildEditTextField(phoneController, 'Phone Number', keyboardType: TextInputType.phone),
                const SizedBox(height: 12),
                _buildEditTextField(addressController, 'Address', maxLines: 2),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: kGold),
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                final updatedUser = UserEntity(
                  userId: user.userId,
                  fname: firstNameController.text.trim(),
                  mname: middleNameController.text.trim(),
                  lname: lastNameController.text.trim(),
                  address: addressController.text.trim(),
                  email: user.email, // Email usually stays fixed as it is the login identifier
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
                      const SnackBar(content: Text('User information updated'), backgroundColor: Colors.green),
                    );
                    _fetchUsers();
                  },
                );
              }
            },
            child: const Text('Update', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

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

  void _showUserOptions(UserEntity user) {
    final bool isActive = user.status == 'active' || user.status == 'approved';
    
    showModalBottomSheet(
      context: context,
      backgroundColor: context.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: context.textColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Manage: ${user.fname} ${user.lname}',
                  style: TextStyle(
                    color: kGold,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              const Divider(height: 1),
              
              // --- View / Information Sections ---
              _buildOptionItem(
                icon: Icons.settings_input_component_rounded,
                label: 'View Associated Ball Mill / Plant',
                onTap: () {
                  Navigator.pop(context);
                  _showPlaceholderDialog('Associated Units', 'Viewing units for ${user.fname}...');
                },
              ),
              _buildOptionItem(
                icon: Icons.history_rounded,
                label: 'View Service Request History',
                onTap: () {
                  Navigator.pop(context);
                  _showPlaceholderDialog('Request History', 'Fetching requests for ${user.fname}...');
                },
              ),
              _buildOptionItem(
                icon: Icons.receipt_long_outlined,
                label: 'View Billing & Payment Records',
                onTap: () {
                  Navigator.pop(context);
                  _showPlaceholderDialog('Financial Records', 'Loading records for ${user.fname}...');
                },
              ),
              
              const Divider(height: 1),

              // --- Administrative Actions ---
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
              const SizedBox(height: 12),
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

  void _showPlaceholderDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.surfaceColor,
        title: Text(title, style: const TextStyle(color: kGold, fontWeight: FontWeight.bold)),
        content: Text(message, style: TextStyle(color: context.textColor)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: Colors.grey)),
          ),
        ],
      ),
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
          'MINERS & CLIENTS',
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
            icon: const Icon(Icons.person_off_outlined, color: kGold),
            onPressed: _showInactiveUsersModal,
            tooltip: 'View Inactive Users',
          ),
          const ThemeToggleButton(),
          IconButton(
            icon: const Icon(Icons.menu_rounded, color: kGold),
            onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
          ),
        ],
      ),
      endDrawer: const AdminDrawer(currentMenu: AdminMenu.minerList),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: kGold))
          : _errorMessage != null
              ? _buildErrorState()
              : _users.isEmpty
                  ? _buildEmptyState()
                  : RefreshIndicator(
                      onRefresh: _fetchUsers,
                      color: kGold,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _users.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final user = _users[index];
                          return _buildUserCard(user);
                        },
                      ),
                    ),
    );
  }

  Widget _buildUserCard(UserEntity user) {
    final bool isActive = user.status == 'active';
    
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
          const SizedBox(height: 12),
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
                    icon: const Icon(Icons.edit_outlined, size: 20, color: Colors.blue),
                    onPressed: () => _showEditUserDialog(user),
                    tooltip: 'Edit User',
                  ),
                  IconButton(
                    icon: const Icon(Icons.more_horiz_rounded, size: 24, color: kGold),
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
