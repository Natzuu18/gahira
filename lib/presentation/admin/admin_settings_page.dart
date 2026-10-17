import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../shared_widgets/appColor.dart';
import '../shared_widgets/themeToggleButton.dart';
import 'gold_transactions_page.dart';
import 'billing_page.dart';
import 'expenses_page.dart';
import 'report_page.dart';
import '../../main.dart';

class AdminSettingsPage extends StatefulWidget {
  const AdminSettingsPage({super.key, this.adminName = 'Admin'});

  final String adminName;

  @override
  State<AdminSettingsPage> createState() => _AdminSettingsPageState();
}

class _AdminSettingsPageState extends State<AdminSettingsPage> {
  String _email = '';
  String _adminName = '';
  String _fname = '';
  String _mname = '';
  String _lname = '';
  String _phone = '';
  String _address = '';

  @override
  void initState() {
    super.initState();
    _adminName = widget.adminName;
    _fetchAdminProfile();
  }

  Future<void> _fetchAdminProfile() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      setState(() => _email = user.email ?? '');
      try {
        final res = await Supabase.instance.client
            .from('users')
            .select()
            .eq('userId', user.id)
            .maybeSingle();

        if (res != null) {
          setState(() {
            _fname = res['fname'] ?? '';
            _mname = res['mname'] ?? '';
            _lname = res['lname'] ?? '';
            _phone = res['contact_num'] ?? '';
            _address = res['address'] ?? '';
            final fullName = '$_fname ${_mname.isNotEmpty ? '$_mname ' : ''}$_lname'.trim();
            if (fullName.isNotEmpty) {
              _adminName = fullName;
            }
          });
        }
      } catch (e) {
        debugPrint('Error fetching admin profile: $e');
      }
    }
  }

  void _showAccountSettingsDialog() {
    final fnameController = TextEditingController(text: _fname);
    final mnameController = TextEditingController(text: _mname);
    final lnameController = TextEditingController(text: _lname);
    final phoneController = TextEditingController(text: _phone);
    final addressController = TextEditingController(text: _address);
    final passwordController = TextEditingController();
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          return AlertDialog(
            backgroundColor: ctx.surfaceColor,
            title: const Row(
              children: [
                Icon(Icons.manage_accounts_rounded, color: kGold),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Admin Account Settings',
                    style: TextStyle(color: kGold, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Update your admin account details.', style: TextStyle(color: ctx.mutedTextColor, fontSize: 12)),
                  const SizedBox(height: 16),
                  _buildDialogField(ctx, fnameController, 'First Name'),
                  const SizedBox(height: 12),
                  _buildDialogField(ctx, mnameController, 'Middle Name (Optional)'),
                  const SizedBox(height: 12),
                  _buildDialogField(ctx, lnameController, 'Last Name'),
                  const SizedBox(height: 12),
                  _buildDialogField(ctx, phoneController, 'Contact Number', keyboardType: TextInputType.phone),
                  const SizedBox(height: 12),
                  _buildDialogField(ctx, addressController, 'Address'),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 8),
                  Text('Change Password (Optional)', style: TextStyle(color: kGold, fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: passwordController,
                    obscureText: true,
                    style: TextStyle(color: ctx.textColor),
                    decoration: InputDecoration(
                      labelText: 'New Password',
                      hintText: 'Leave blank to keep current password',
                      hintStyle: TextStyle(color: ctx.mutedTextColor, fontSize: 11),
                      filled: true,
                      fillColor: ctx.bgColor,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
                child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: kGold, foregroundColor: kBlack),
                onPressed: isSubmitting
                    ? null
                    : () async {
                        setModalState(() => isSubmitting = true);
                        try {
                          final user = Supabase.instance.client.auth.currentUser;
                          if (user != null) {
                            await Supabase.instance.client.from('users').update({
                              'fname': fnameController.text.trim(),
                              'mname': mnameController.text.trim(),
                              'lname': lnameController.text.trim(),
                              'contact_num': phoneController.text.trim(),
                              'address': addressController.text.trim(),
                            }).eq('userId', user.id);

                            if (passwordController.text.trim().length >= 6) {
                              await Supabase.instance.client.auth.updateUser(
                                UserAttributes(password: passwordController.text.trim()),
                              );
                            }

                            if (mounted) {
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Account information updated successfully!'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                              _fetchAdminProfile();
                            }
                          }
                        } catch (e) {
                          setModalState(() => isSubmitting = false);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Failed to update: $e'),
                                backgroundColor: Colors.redAccent,
                              ),
                            );
                          }
                        }
                      },
                child: isSubmitting
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: kBlack, strokeWidth: 2))
                    : const Text('Save Changes', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDialogField(BuildContext ctx, TextEditingController controller, String label, {TextInputType? keyboardType}) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      style: TextStyle(color: ctx.textColor),
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: ctx.bgColor,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _logout() async {
    await Supabase.instance.client.auth.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
          'USER SETTINGS',
          style: TextStyle(
            color: kGold,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
            fontSize: 16,
          ),
        ),
        actions: const [
          ThemeToggleButton(),
          SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User Header Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: context.surfaceColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: kGold.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: kGold, width: 2),
                      color: context.bgColor,
                    ),
                    child: const Icon(Icons.person, color: kGold, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _adminName.isNotEmpty ? _adminName : widget.adminName,
                          style: TextStyle(
                            color: context.textColor,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (_email.isNotEmpty)
                          Text(
                            _email,
                            style: TextStyle(
                              color: context.mutedTextColor,
                              fontSize: 13,
                            ),
                          ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: kGold.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'Administrator',
                            style: TextStyle(
                              color: kGold,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, color: kGold),
                    tooltip: 'Edit Profile',
                    onPressed: _showAccountSettingsDialog,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            _buildSectionHeader('ACCOUNT & SECURITY'),
            const SizedBox(height: 8),
            _buildSettingTile(
              icon: Icons.manage_accounts_outlined,
              title: 'Account Settings',
              subtitle: 'Update admin profile, contact, and password',
              onTap: _showAccountSettingsDialog,
            ),

            const SizedBox(height: 24),
            _buildSectionHeader('FINANCIAL MANAGEMENT'),
            const SizedBox(height: 8),
            _buildSettingTile(
              icon: Icons.paid_outlined,
              title: 'Gold Transactions',
              subtitle: 'Manage gold purchases and buying prices',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const GoldTransactionsPage()),
              ),
            ),
            _buildSettingTile(
              icon: Icons.receipt_long_outlined,
              title: 'Financial Handling',
              subtitle: 'Invoices, billing, and settlement status',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const BillingPage()),
              ),
            ),
            _buildSettingTile(
              icon: Icons.trending_down_rounded,
              title: 'Refinery Expenses',
              subtitle: 'Track operational expenses and fees',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ExpensesPage()),
              ),
            ),

            const SizedBox(height: 24),
            _buildSectionHeader('REPORTS & LOGS'),
            const SizedBox(height: 8),
            _buildSettingTile(
              icon: Icons.bar_chart_rounded,
              title: 'Reports & Analytics',
              subtitle: 'Generate system & financial reports',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ReportPage()),
              ),
            ),

            const SizedBox(height: 24),
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: context.surfaceColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
              ),
              child: ListTile(
                leading: const Icon(Icons.logout_rounded, color: Colors.red),
                title: const Text(
                  'Log Out',
                  style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  'Sign out of your administrator account',
                  style: TextStyle(color: context.mutedTextColor, fontSize: 12),
                ),
                onTap: _logout,
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: TextStyle(
        color: context.mutedTextColor,
        fontSize: 11,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildSettingTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kGold.withValues(alpha: 0.1)),
      ),
      child: ListTile(
        leading: Icon(icon, color: kGold),
        title: Text(
          title,
          style: TextStyle(
            color: context.textColor,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(color: context.mutedTextColor, fontSize: 12),
        ),
        trailing: const Icon(Icons.chevron_right_rounded, color: kGold),
        onTap: onTap,
      ),
    );
  }
}
