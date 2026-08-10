import 'package:flutter/material.dart';

import './components/appColor.dart';
import './admin/admin_dashboard.dart';
import './components/themeToggleButton.dart';

// Gahira Ball Mill Management System - Login Page
// Simple, clean design in gold & black (with light mode support).

void main() {
  runApp(const GahiraApp());
}

class GahiraApp extends StatelessWidget {
  const GahiraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeModeNotifier,
      builder: (context, mode, _) {
        return MaterialApp(
          title: 'Gahira Ball Mill Management System',
          debugShowCheckedModeBanner: false,
          themeMode: mode,
          theme: buildAppTheme(Brightness.light),
          darkTheme: buildAppTheme(Brightness.dark),
          home: const LoginPage(),
        );
      },
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;

  late final AnimationController _spinController;

  @override
  void initState() {
    super.initState();
    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _spinController.dispose();
    super.dispose();
  }

  void _setLoading(bool value) {
    setState(() => _isLoading = value);
    if (value) {
      _spinController.repeat();
    } else {
      _spinController.stop();
      _spinController.reset();
    }
  }

  void _handleLogin() {
    if (_formKey.currentState!.validate()) {
      _setLoading(true);
      // TODO: replace with a real authentication call.
      Future.delayed(const Duration(seconds: 2), () {
        if (!mounted) return;
        _setLoading(false);
        _goToDashboard();
      });
    }
  }

  void _handleOAuth(String provider) {
    _setLoading(true);
    // TODO: hook up real OAuth flow (e.g. google_sign_in, msal_flutter).
    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      _setLoading(false);
      _goToDashboard();
    });
  }

  void _goToDashboard() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const AdminDashboardPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bgColor,
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: SingleChildScrollView(
                padding:
                const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Logo / mark
                        Center(child: _buildLogoMark(context, size: 88, iconSize: 40)),
                        const SizedBox(height: 20),
                        const Text(
                          'GAHIRA',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: kGold,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 4,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'BALL MILL MANAGEMENT SYSTEM',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: kGold.withOpacity(0.7),
                            fontSize: 12,
                            letterSpacing: 2,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 40),

                        // Username field
                        _buildLabel('Username'),
                        const SizedBox(height: 8),
                        _buildTextField(
                          context,
                          controller: _usernameController,
                          hint: 'Enter your username',
                          icon: Icons.person_outline,
                          validator: (v) => (v == null || v.isEmpty)
                              ? 'Username is required'
                              : null,
                        ),
                        const SizedBox(height: 20),

                        // Password field
                        _buildLabel('Password'),
                        const SizedBox(height: 8),
                        _buildTextField(
                          context,
                          controller: _passwordController,
                          hint: 'Enter your password',
                          icon: Icons.lock_outline,
                          obscureText: _obscurePassword,
                          validator: (v) => (v == null || v.isEmpty)
                              ? 'Password is required'
                              : null,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              color: kGold.withOpacity(0.7),
                            ),
                            onPressed: () => setState(
                                    () => _obscurePassword = !_obscurePassword),
                          ),
                        ),

                        const SizedBox(height: 10),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () {},
                            style: TextButton.styleFrom(
                              foregroundColor: kGold,
                              padding: EdgeInsets.zero,
                            ),
                            child: const Text('Forgot password?'),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Login button
                        SizedBox(
                          height: 52,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _handleLogin,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: kGold,
                              disabledBackgroundColor:
                              kGold.withOpacity(0.6),
                              foregroundColor: kBlack,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              elevation: 0,
                            ),
                            child: const Text(
                              'LOG IN',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.5,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // OR divider
                        Row(
                          children: [
                            Expanded(
                                child: Divider(color: kGold.withOpacity(0.2))),
                            Padding(
                              padding:
                              const EdgeInsets.symmetric(horizontal: 12),
                              child: Text(
                                'OR CONTINUE WITH',
                                style: TextStyle(
                                  color: kGold.withOpacity(0.5),
                                  fontSize: 11,
                                  letterSpacing: 1,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Expanded(
                                child: Divider(color: kGold.withOpacity(0.2))),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // OAuth buttons
                        _buildOAuthButton(
                          context,
                          label: 'Continue with Google',
                          asset: _GAsset(),
                          onPressed:
                          _isLoading ? null : () => _handleOAuth('Google'),
                        ),
                        const SizedBox(height: 12),
                        _buildOAuthButton(
                          context,
                          label: 'Continue with Microsoft',
                          asset: Icon(Icons.window_rounded,
                              color: kGold.withOpacity(0.9), size: 18),
                          onPressed: _isLoading
                              ? null
                              : () => _handleOAuth('Microsoft'),
                        ),

                        const SizedBox(height: 28),
                        Row(
                          children: [
                            Expanded(
                                child: Divider(color: kGold.withOpacity(0.15))),
                            Padding(
                              padding:
                              const EdgeInsets.symmetric(horizontal: 12),
                              child: Text(
                                'v1.0',
                                style: TextStyle(
                                  color: kGold.withOpacity(0.4),
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            Expanded(
                                child: Divider(color: kGold.withOpacity(0.15))),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Light/dark mode toggle, top-right
            const Positioned(
              top: 4,
              right: 4,
              child: ThemeToggleButton(),
            ),

            // Full-screen loading overlay with spinning logo
            IgnorePointer(
              ignoring: !_isLoading,
              child: AnimatedOpacity(
                opacity: _isLoading ? 1 : 0,
                duration: const Duration(milliseconds: 200),
                child: Container(
                  color: context.bgColor.withOpacity(0.9),
                  width: double.infinity,
                  height: double.infinity,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        RotationTransition(
                          turns: _spinController,
                          child: _buildLogoMark(context, size: 72, iconSize: 32),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Signing in...',
                          style: TextStyle(
                            color: kGold.withOpacity(0.85),
                            fontSize: 13,
                            letterSpacing: 1,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogoMark(BuildContext context,
      {required double size, required double iconSize}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: kGold, width: 2),
        color: context.surfaceColor,
      ),
      child: Icon(
        Icons.settings_input_component_rounded,
        color: kGold,
        size: iconSize,
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: kGold,
        fontSize: 13,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildTextField(
      BuildContext context, {
        required TextEditingController controller,
        required String hint,
        required IconData icon,
        bool obscureText = false,
        Widget? suffixIcon,
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
        hintStyle: TextStyle(color: context.mutedTextColor),
        prefixIcon: Icon(icon, color: kGold.withOpacity(0.8)),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: context.surfaceColor,
        contentPadding:
        const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: kGold.withOpacity(0.25)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: kGold.withOpacity(0.25)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: kGold, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
      ),
    );
  }

  Widget _buildOAuthButton(
      BuildContext context, {
        required String label,
        required Widget asset,
        required VoidCallback? onPressed,
      }) {
    return SizedBox(
      height: 48,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: context.surfaceColor,
          side: BorderSide(color: kGold.withOpacity(0.3)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            asset,
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                color: context.textColor,
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Small "G" mark placeholder so no external asset/package is required.
// Swap this for the real Google "G" logo asset if you have one.
class _GAsset extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 18,
      height: 18,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: kGold.withOpacity(0.8), width: 1.2),
      ),
      child: Text(
        'G',
        style: TextStyle(
          color: kGold.withOpacity(0.9),
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}