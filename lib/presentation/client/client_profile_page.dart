import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../shared_widgets/appColor.dart';
import '../shared_widgets/themeToggleButton.dart';
import '../shared_widgets/profile_activity_page.dart';
import '../shared_widgets/profile_picture_editor.dart';
import 'package:gahira/main.dart';
import '../../domain/entities/user_entity.dart';
import '../../infrastructure/repositories/supabase_user_repository.dart';

// Gahira Ball Mill Management System - Client Profile Page
// Clients can view and manage their profile information and settings

class ClientProfilePage extends StatefulWidget {
  const ClientProfilePage({super.key});

  @override
  State<ClientProfilePage> createState() => _ClientProfilePageState();
}

class _ClientProfilePageState extends State<ClientProfilePage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final SupabaseUserRepository _userRepository = SupabaseUserRepository();
  UserEntity? _miner;
  bool _loadingProfile = true;

  bool _notificationsEnabled = true;
  bool _emailNotifications = true;
  bool _smsNotifications = false;
  bool _processingUpdates = true;
  bool _billingAlerts = true;

  @override
  void initState() {
    super.initState();
    _loadMinerProfile();
  }

  Future<void> _loadMinerProfile() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      if (mounted) setState(() => _loadingProfile = false);
      return;
    }
    final result = await _userRepository.getUserById(userId);
    if (!mounted) return;
    result.fold(
      (_) => setState(() => _loadingProfile = false),
      (user) => setState(() {
        _miner = user;
        _loadingProfile = false;
      }),
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
          'EGReS',
          style: TextStyle(
            color: kGold,
            fontWeight: FontWeight.bold,
            letterSpacing: 3,
            fontSize: 16,
          ),
        ),
        iconTheme: const IconThemeData(color: kGold),
        actions: const [ThemeToggleButton(), SizedBox(width: 8)],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Text(
              'Profile',
              style: TextStyle(
                color: context.textColor,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Manage your miner account and preferences',
              style: TextStyle(color: context.mutedTextColor, fontSize: 14),
            ),
            const SizedBox(height: 32),

            // Profile Information Card
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: context.surfaceColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: kGold.withOpacity(0.1)),
              ),
              child: Column(
                children: [
                  const ProfilePictureEditor(size: 80),
                  const SizedBox(height: 16),
                  Text(
                    _loadingProfile
                        ? 'Loading miner profile…'
                        : (_miner == null
                            ? 'Miner profile unavailable'
                            : '${_miner!.fname} ${_miner!.lname}'.trim()),
                    style: TextStyle(
                      color: context.textColor,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _miner?.email ??
                        Supabase.instance.client.auth.currentUser?.email ??
                        '',
                    style: TextStyle(
                      color: context.mutedTextColor,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: kGold.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _miner?.status.isNotEmpty == true
                          ? _miner!.status.toUpperCase()
                          : 'MINER',
                      style: TextStyle(
                        color: kGold,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _miner == null ? null : _editMinerProfile,
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('Edit Profile'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: kGold,
                        side: BorderSide(color: kGold.withOpacity(0.6)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Contact Information
            Text(
              'Contact Information',
              style: TextStyle(
                color: context.textColor,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildInfoCard(
              Icons.phone_outlined,
              'Phone',
              _miner?.contactNum.isNotEmpty == true
                  ? _miner!.contactNum
                  : 'Not provided',
            ),
            const SizedBox(height: 12),
            _buildInfoCard(
              Icons.email_outlined,
              'Email',
              _miner?.email ??
                  Supabase.instance.client.auth.currentUser?.email ??
                  'Not provided',
            ),
            const SizedBox(height: 12),
            _buildInfoCard(
              Icons.location_on_outlined,
              'Address',
              _miner?.address.isNotEmpty == true
                  ? _miner!.address
                  : 'Not provided',
            ),
            if ((_miner?.miningUnitName?.isNotEmpty ?? false) ||
                (_miner?.miningUnitType?.isNotEmpty ?? false)) ...[
              const SizedBox(height: 12),
              _buildInfoCard(
                Icons.factory_outlined,
                _miner?.miningUnitType ?? 'Mining Unit',
                _miner?.miningUnitName ?? 'Not provided',
              ),
            ],
            const SizedBox(height: 32),

            // Notification Preferences
            Text(
              'Notification Preferences',
              style: TextStyle(
                color: context.textColor,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildNotificationCard(
              'Push Notifications',
              'Receive in-app notifications',
              _notificationsEnabled,
              (value) => setState(() => _notificationsEnabled = value),
            ),
            const SizedBox(height: 12),
            _buildNotificationCard(
              'Email Notifications',
              'Receive updates via email',
              _emailNotifications,
              (value) => setState(() => _emailNotifications = value),
            ),
            const SizedBox(height: 12),
            _buildNotificationCard(
              'SMS Notifications',
              'Receive SMS alerts',
              _smsNotifications,
              (value) => setState(() => _smsNotifications = value),
            ),
            const SizedBox(height: 32),

            // Specific Notifications
            Text(
              'Specific Notifications',
              style: TextStyle(
                color: context.textColor,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildNotificationCard(
              'Processing Updates',
              'Get notified about job progress',
              _processingUpdates,
              (value) => setState(() => _processingUpdates = value),
            ),
            const SizedBox(height: 12),
            _buildNotificationCard(
              'Billing Alerts',
              'Receive payment reminders',
              _billingAlerts,
              (value) => setState(() => _billingAlerts = value),
            ),
            const SizedBox(height: 32),

            // Account Actions
            Text(
              'Account Actions',
              style: TextStyle(
                color: context.textColor,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildActionButton(
              Icons.manage_history_rounded,
              'Profile Activity',
              () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ProfileActivityPage()),
              ),
            ),
            const SizedBox(height: 12),
            _buildActionButton(Icons.lock_outline, 'Change Password', () {}),
            const SizedBox(height: 12),
            _buildActionButton(Icons.help_outline, 'Help & Support', () {}),
            const SizedBox(height: 12),
            _buildActionButton(
              Icons.description_outlined,
              'Terms & Conditions',
              () {},
            ),
            const SizedBox(height: 12),
            _buildActionButton(
              Icons.privacy_tip_outlined,
              'Privacy Policy',
              () {},
            ),
            const SizedBox(height: 32),

            // Logout Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => logoutAndNavigateToLogin(context),
                icon: const Icon(Icons.logout_rounded),
                label: const Text('Log Out'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.withOpacity(0.1),
                  foregroundColor: Colors.red,
                  side: BorderSide(color: Colors.red.withOpacity(0.3)),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Future<void> _editMinerProfile() async {
    final miner = _miner;
    if (miner == null) return;

    final formKey = GlobalKey<FormState>();
    final firstNameController = TextEditingController(text: miner.fname);
    final lastNameController = TextEditingController(text: miner.lname);
    final phoneController = TextEditingController(text: miner.contactNum);
    final addressController = TextEditingController(text: miner.address);
    var isSaving = false;

    final updatedMiner = await showDialog<UserEntity>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          backgroundColor: context.surfaceColor,
          title: Text(
            'Edit Miner Profile',
            style: TextStyle(color: context.textColor),
          ),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _profileEditField(firstNameController, 'First name'),
                  const SizedBox(height: 12),
                  _profileEditField(lastNameController, 'Last name'),
                  const SizedBox(height: 12),
                  _profileEditField(
                    phoneController,
                    'Phone number',
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 12),
                  _profileEditField(
                    addressController,
                    'Address',
                    maxLines: 2,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSaving ? null : () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isSaving
                  ? null
                  : () async {
                      if (!(formKey.currentState?.validate() ?? false)) return;
                      setDialogState(() => isSaving = true);
                      final result = await _userRepository.updateUser(
                        UserEntity(
                          userId: miner.userId,
                          fname: firstNameController.text.trim(),
                          mname: miner.mname,
                          lname: lastNameController.text.trim(),
                          address: addressController.text.trim(),
                          email: miner.email,
                          contactNum: phoneController.text.trim(),
                          roleId: miner.roleId,
                          status: miner.status,
                          miningUnitId: miner.miningUnitId,
                          miningUnitName: miner.miningUnitName,
                          miningUnitType: miner.miningUnitType,
                          pinHash: miner.pinHash,
                          createdAt: miner.createdAt,
                        ),
                      );
                      result.fold(
                        (failure) {
                          if (!dialogContext.mounted) return;
                          setDialogState(() => isSaving = false);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(failure.message)),
                          );
                        },
                        (user) => Navigator.pop(dialogContext, user),
                      );
                    },
              child: isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save Changes'),
            ),
          ],
        ),
      ),
    );

    firstNameController.dispose();
    lastNameController.dispose();
    phoneController.dispose();
    addressController.dispose();

    if (updatedMiner != null && mounted) {
      setState(() => _miner = updatedMiner);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Miner profile updated successfully.')),
      );
    }
  }

  Widget _profileEditField(
    TextEditingController controller,
    String label, {
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      style: TextStyle(color: context.textColor),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: context.mutedTextColor),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: kGold.withOpacity(0.25)),
          borderRadius: BorderRadius.circular(10),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: kGold),
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      validator: (value) => value == null || value.trim().isEmpty
          ? 'Please enter your $label.'
          : null,
    );
  }

  Widget _buildInfoCard(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kGold.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: kGold.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: kGold, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(color: context.mutedTextColor, fontSize: 12),
                ),
                Text(
                  value,
                  style: TextStyle(
                    color: context.textColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationCard(
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kGold.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: context.textColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(color: context.mutedTextColor, fontSize: 12),
                ),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged, activeColor: kGold),
        ],
      ),
    );
  }

  Widget _buildActionButton(IconData icon, String label, VoidCallback onTap) {
    return Container(
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kGold.withOpacity(0.05)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(icon, color: kGold.withOpacity(0.8), size: 22),
                const SizedBox(width: 16),
                Text(
                  label,
                  style: TextStyle(
                    color: context.textColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                Icon(
                  Icons.chevron_right_rounded,
                  color: context.mutedTextColor,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogoMark() {
    return Image.asset(
      'assets/img/EGReS.png',
      width: 34,
      height: 34,
      fit: BoxFit.contain,
    );
  }
}
