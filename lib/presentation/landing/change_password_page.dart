import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../shared_widgets/appColor.dart';
import '../../infrastructure/repositories/supabase_user_repository.dart';
import '../../domain/entities/user_entity.dart';
import '../admin/admin_main_layout.dart';
import '../operator/operator_main_layout.dart';
import '../client/client_dashboard.dart';
import '../miner/miner_dashboard.dart';
import '../../main.dart';

class ChangePasswordPage extends StatefulWidget {
  final bool isPinOnly;

  const ChangePasswordPage({super.key, this.isPinOnly = false});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _pinController = TextEditingController();
  final _confirmPinController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePass = true;
  bool _obscureConfirmPass = true;
  bool _showPin = false;
  String? _error;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _pinController.dispose();
    _confirmPinController.dispose();
    super.dispose();
  }

  Future<void> _handleSaveSetup() async {
    if (!_formKey.currentState!.validate()) return;

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      _goToLogin();
      return;
    }

    // PIN Validation
    final pin = _pinController.text.trim();
    final confirmPin = _confirmPinController.text.trim();
    if (pin.length != 6) {
      setState(() => _error = 'Security PIN must be exactly 6 digits');
      return;
    }
    if (pin != confirmPin) {
      setState(() => _error = 'Security PINs do not match');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final userRepo = SupabaseUserRepository();

      // 1. Update Password if required
      if (!widget.isPinOnly) {
        await Supabase.instance.client.auth.updateUser(
          UserAttributes(password: _passwordController.text.trim()),
        );
      }

      // 2. Update Security PIN
      final pinResult = await userRepo.updateUserPin(user.id, pin);

      if (pinResult.isLeft()) {
        final failure = pinResult.fold((f) => f, (_) => null);
        setState(() {
          _isLoading = false;
          _error = failure?.message ?? 'Failed to update Security PIN';
        });
        return;
      }

      // 3. Fetch User Profile & Role for direct Dashboard Navigation!
      final profileResult = await userRepo.getUserById(user.id);

      if (!mounted) return;

      profileResult.fold(
        (failure) {
          _goToLogin();
        },
        (userEntity) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Account setup complete! Welcome to Gahira.'),
              backgroundColor: Colors.green,
            ),
          );

          // Direct Navigation to Dashboard without logging in again!
          _navigateDirectToDashboard(userEntity);
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Error during setup: ${e.toString()}';
        });
      }
    }
  }

  void _navigateDirectToDashboard(UserEntity userEntity) {
    final role = userEntity.roleId.toLowerCase();
    final name = '${userEntity.fname} ${userEntity.lname}'.trim();

    if (role == 'admin') {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => AdminMainLayout(adminName: name)),
        (route) => false,
      );
    } else if (role == 'operator') {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => OperatorMainLayout(operatorName: name)),
        (route) => false,
      );
    } else if (role == 'client') {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => ClientDashboardPage(clientName: name)),
        (route) => false,
      );
    } else {
      // miner
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => MinerDashboardPage(minerName: name)),
        (route) => false,
      );
    }
  }

  void _goToLogin() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bgColor,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.shield_outlined, color: kGold, size: 60),
                  const SizedBox(height: 20),
                  Text(
                    widget.isPinOnly ? 'SET SECURITY PIN' : 'ACCOUNT SECURITY SETUP',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: kGold,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.isPinOnly
                        ? 'Set a 6-digit security PIN for authorizing transactions.'
                        : 'Set your new personal password and 6-digit security PIN to secure your account.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: context.mutedTextColor, fontSize: 13.5),
                  ),
                  const SizedBox(height: 28),

                  // PASSWORD SECTION (Only if not pin only)
                  if (!widget.isPinOnly) ...[
                    _buildLabel('New Password'),
                    const SizedBox(height: 8),
                    _buildPasswordField(
                      controller: _passwordController,
                      hint: 'Enter new password (min. 8 characters)',
                      obscureText: _obscurePass,
                      onToggleObscure: () => setState(() => _obscurePass = !_obscurePass),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Password is required';
                        if (v.trim().length < 8) return 'Password must be at least 8 characters';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    _buildLabel('Confirm Password'),
                    const SizedBox(height: 8),
                    _buildPasswordField(
                      controller: _confirmPasswordController,
                      hint: 'Confirm your new password',
                      obscureText: _obscureConfirmPass,
                      onToggleObscure: () => setState(() => _obscureConfirmPass = !_obscureConfirmPass),
                      validator: (v) {
                        if (v != _passwordController.text) return 'Passwords do not match';
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 16),
                  ],

                  // SECURITY PIN SECTION
                  _buildLabel('New 6-Digit Security PIN'),
                  const SizedBox(height: 8),
                  _buildPinField(_pinController, 'Enter 6-digit PIN'),
                  const SizedBox(height: 16),

                  _buildLabel('Confirm Security PIN'),
                  const SizedBox(height: 8),
                  _buildPinField(_confirmPinController, 'Confirm 6-digit PIN'),
                  const SizedBox(height: 10),

                  // Show PIN Toggle
                  Align(
                    alignment: Alignment.centerRight,
                    child: InkWell(
                      onTap: () => setState(() => _showPin = !_showPin),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _showPin ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                            size: 18,
                            color: kGold,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _showPin ? 'Hide PIN' : 'Show PIN',
                            style: const TextStyle(color: kGold, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),

                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.redAccent, fontSize: 12.5, fontWeight: FontWeight.bold),
                    ),
                  ],

                  const SizedBox(height: 32),

                  SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _handleSaveSetup,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kGold,
                        foregroundColor: kBlack,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: _isLoading
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: kBlack))
                          : const Text(
                              'SAVE & CONTINUE TO DASHBOARD',
                              style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(color: kGold, fontSize: 12.5, fontWeight: FontWeight.bold),
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String hint,
    required bool obscureText,
    required VoidCallback onToggleObscure,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      validator: validator,
      style: TextStyle(color: context.textColor),
      cursorColor: kGold,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: context.mutedTextColor, fontSize: 13),
        prefixIcon: Icon(Icons.lock_outline, color: kGold.withValues(alpha: 0.8)),
        suffixIcon: IconButton(
          icon: Icon(obscureText ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: kGold),
          onPressed: onToggleObscure,
        ),
        filled: true,
        fillColor: context.surfaceColor,
        contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: kGold.withValues(alpha: 0.25))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: kGold.withValues(alpha: 0.25))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kGold, width: 1.6)),
      ),
    );
  }

  Widget _buildPinField(TextEditingController controller, String hint) {
    return TextFormField(
      controller: controller,
      obscureText: !_showPin,
      keyboardType: TextInputType.number,
      textAlign: TextAlign.center,
      style: TextStyle(
        color: context.textColor,
        fontSize: 18,
        fontWeight: FontWeight.bold,
        letterSpacing: _showPin ? 4 : 8,
      ),
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(6),
      ],
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: context.mutedTextColor, fontSize: 13, letterSpacing: 0),
        filled: true,
        fillColor: context.surfaceColor,
        contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: kGold.withValues(alpha: 0.25))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: kGold.withValues(alpha: 0.25))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kGold, width: 1.6)),
      ),
    );
  }
}
