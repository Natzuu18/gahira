import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../shared_widgets/appColor.dart';
import '../shared_widgets/themeToggleButton.dart';

class OperatorUserPage extends StatefulWidget {
  const OperatorUserPage({
    super.key,
    required this.operatorName,
    required this.onOpenProfileActivity,
    required this.onLogout,
  });

  final String operatorName;
  final VoidCallback onOpenProfileActivity;
  final VoidCallback onLogout;

  @override
  State<OperatorUserPage> createState() => _OperatorUserPageState();
}

class _OperatorUserPageState extends State<OperatorUserPage> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _middleNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  String _email = '';

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _middleNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    _email = user.email ?? '';
    try {
      final data = await Supabase.instance.client
          .from('users')
          .select('fname, mname, lname, contact_num, address')
          .eq('userId', user.id)
          .maybeSingle();

      if (data != null) {
        _firstNameController.text = data['fname']?.toString() ?? '';
        _middleNameController.text = data['mname']?.toString() ?? '';
        _lastNameController.text = data['lname']?.toString() ?? '';
        _phoneController.text = data['contact_num']?.toString() ?? '';
        _addressController.text = data['address']?.toString() ?? '';
      } else {
        _firstNameController.text = widget.operatorName;
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not load account information: $error')),
        );
      }
    }

    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    setState(() => _isSaving = true);
    try {
      await Supabase.instance.client
          .from('users')
          .update({
            'fname': _firstNameController.text.trim(),
            'mname': _middleNameController.text.trim(),
            'lname': _lastNameController.text.trim(),
            'contact_num': _phoneController.text.trim(),
            'address': _addressController.text.trim(),
          })
          .eq('userId', user.id);

      if (mounted) {
        FocusScope.of(context).unfocus();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Your information has been updated.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not update information: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fullName = [
      _firstNameController.text,
      _lastNameController.text,
    ].where((part) => part.trim().isNotEmpty).join(' ');

    return Scaffold(
      backgroundColor: context.bgColor,
      appBar: AppBar(
        backgroundColor: context.surfaceColor,
        title: const Text(
          'USER',
          style: TextStyle(
            color: kGold,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
            fontSize: 16,
          ),
        ),
        actions: const [ThemeToggleButton()],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: kGold))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: context.surfaceColor,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: kGold.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          color: kGold.withValues(alpha: 0.13),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.person_rounded, color: kGold),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              fullName.isEmpty ? widget.operatorName : fullName,
                              style: TextStyle(
                                color: context.textColor,
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              _email.isEmpty ? 'Operator account' : _email,
                              style: TextStyle(
                                color: context.mutedTextColor,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                _sectionTitle(context, 'UPDATE YOUR INFORMATION'),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: context.surfaceColor,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: context.textColor.withValues(alpha: 0.06),
                    ),
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        _textField(
                          context,
                          controller: _firstNameController,
                          label: 'First Name',
                          validator: (value) => value == null || value.trim().isEmpty
                              ? 'Enter your first name'
                              : null,
                        ),
                        const SizedBox(height: 12),
                        _textField(
                          context,
                          controller: _middleNameController,
                          label: 'Middle Name (Optional)',
                        ),
                        const SizedBox(height: 12),
                        _textField(
                          context,
                          controller: _lastNameController,
                          label: 'Last Name',
                          validator: (value) => value == null || value.trim().isEmpty
                              ? 'Enter your last name'
                              : null,
                        ),
                        const SizedBox(height: 12),
                        _textField(
                          context,
                          controller: _phoneController,
                          label: 'Phone Number',
                          keyboardType: TextInputType.phone,
                        ),
                        const SizedBox(height: 12),
                        _textField(
                          context,
                          controller: _addressController,
                          label: 'Address',
                          maxLines: 2,
                        ),
                        const SizedBox(height: 18),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _isSaving ? null : _saveProfile,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: kGold,
                              foregroundColor: kBlack,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            icon: _isSaving
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: kBlack,
                                    ),
                                  )
                                : const Icon(Icons.save_outlined),
                            label: Text(
                              _isSaving ? 'SAVING...' : 'SAVE INFORMATION',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                _sectionTitle(context, 'ACCOUNT & ACTIONS'),
                _optionTile(
                  context,
                  icon: Icons.manage_history_rounded,
                  title: 'Profile Activity',
                  subtitle: 'Review recent account activity',
                  onTap: widget.onOpenProfileActivity,
                ),
                _optionTile(
                  context,
                  icon: Icons.logout_rounded,
                  title: 'Log out',
                  subtitle: 'Sign out of this operator account',
                  onTap: widget.onLogout,
                ),
              ],
            ),
    );
  }

  Widget _textField(
    BuildContext context, {
    required TextEditingController controller,
    required String label,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) => TextFormField(
    controller: controller,
    validator: validator,
    keyboardType: keyboardType,
    maxLines: maxLines,
    style: TextStyle(color: context.textColor),
    decoration: InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: context.mutedTextColor),
      filled: true,
      fillColor: context.bgColor,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: context.textColor.withValues(alpha: 0.1)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: kGold),
      ),
    ),
  );

  Widget _sectionTitle(BuildContext context, String title) => Padding(
    padding: const EdgeInsets.only(left: 4, bottom: 10),
    child: Text(
      title,
      style: TextStyle(
        color: context.mutedTextColor,
        fontSize: 11,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.2,
      ),
    ),
  );

  Widget _optionTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color color = kGold,
  }) => Card(
    color: context.surfaceColor,
    elevation: 0,
    margin: const EdgeInsets.only(bottom: 8),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
      side: BorderSide(color: context.textColor.withValues(alpha: 0.06)),
    ),
    child: ListTile(
      leading: Icon(icon, color: color),
      title: Text(
        title,
        style: TextStyle(color: context.textColor, fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: context.mutedTextColor, fontSize: 12),
      ),
      trailing: Icon(Icons.chevron_right_rounded, color: context.mutedTextColor),
      onTap: onTap,
    ),
  );
}
