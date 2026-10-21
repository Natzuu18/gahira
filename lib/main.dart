import 'package:flutter/material.dart';

import './core/navigation/app_scaffold_messenger.dart';
import './core/auth/remember_me_session.dart';
import './presentation/shared_widgets/appColor.dart';
import './presentation/admin/admin_main_layout.dart';
import './presentation/client/miner_main_layout.dart';
import './presentation/operator/operator_main_layout.dart';
import './presentation/shared_widgets/themeToggleButton.dart';
import './presentation/landing/landing_page.dart';
import './presentation/landing/change_password_page.dart';
import './presentation/landing/remembered_session_page.dart';
import './presentation/landing/set_pin_page.dart';

import './infrastructure/supabase/supabase_config.dart';
import './infrastructure/repositories/supabase_auth_repository.dart';
import './application/services/auth_service.dart';
import './application/dtos/login_request_dto.dart';
import './application/dtos/user_dto.dart';
import './core/error/failures.dart';
import './domain/entities/user_entity.dart';

// Gahira Ball Mill Management System - Login Page
// Simple, clean design in gold & black (with light mode support).

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SupabaseConfig.init();

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
          navigatorKey: appNavigatorKey,
          scaffoldMessengerKey: appScaffoldMessengerKey,
          title: 'EGReS - EMELIO GOLD REFINERY SERVICE MANAGEMENT SYSTEM',
          debugShowCheckedModeBanner: false,
          themeMode: mode,
          theme: buildAppTheme(Brightness.light),
          darkTheme: buildAppTheme(Brightness.dark),
          home: const StartupSessionGate(),
        );
      },
    );
  }
}

final appNavigatorKey = GlobalKey<NavigatorState>();

class StartupSessionGate extends StatefulWidget {
  const StartupSessionGate({super.key});

  @override
  State<StartupSessionGate> createState() => _StartupSessionGateState();
}

class _StartupSessionGateState extends State<StartupSessionGate> {
  late Future<Widget> _startupPage;

  @override
  void initState() {
    super.initState();
    _startupPage = _resolveStartupPage();
  }

  Future<Widget> _resolveStartupPage() async {
    final auth = SupabaseConfig.client.auth;
    final session = auth.currentSession;
    final expiresAt = await RememberMeSession.expiresAt;

    if (session == null) {
      if (expiresAt != null) {
        await RememberMeSession.clear();
        return const LoginPage(sessionExpired: true);
      }
      return const LandingPage();
    }

    if (expiresAt == null) {
      await auth.signOut();
      return const LandingPage();
    }

    if (!expiresAt.isAfter(DateTime.now())) {
      await RememberMeSession.signOut();
      return const LoginPage(sessionExpired: true);
    }

    final result = await SupabaseAuthRepository().getCurrentUser();
    final user = result.fold(
      (failure) => throw StateError(failure.message),
      (user) => user,
    );

    if (user == null || user.pinHash == null) {
      await RememberMeSession.signOut();
      return const LoginPage(sessionExpired: true);
    }

    return _rememberedSessionPage(
      user: user,
      expiresAt: expiresAt,
      initiallyUnlocked: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Widget>(
      future: _startupPage,
      builder: (context, snapshot) {
        if (snapshot.hasData) return snapshot.data!;
        if (snapshot.hasError) {
          return Scaffold(
            backgroundColor: context.bgColor,
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.wifi_off_rounded,
                      color: Colors.orangeAccent,
                      size: 40,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Unable to restore your account: ${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: context.textColor),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () {
                        setState(() => _startupPage = _resolveStartupPage());
                      },
                      child: const Text(
                        'Retry',
                        style: TextStyle(color: kGold),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        return Scaffold(
          backgroundColor: context.bgColor,
          body: const Center(child: CircularProgressIndicator(color: kGold)),
        );
      },
    );
  }
}

Widget _rememberedSessionPage({
  required UserEntity user,
  required DateTime expiresAt,
  required bool initiallyUnlocked,
}) {
  return RememberedSessionPage(
    user: user,
    expiresAt: expiresAt,
    dashboard: _dashboardFor(user.roleId, '${user.fname} ${user.lname}'),
    initiallyUnlocked: initiallyUnlocked,
    onChangeUser: _replaceWithLogin,
    onSessionExpired: () => _replaceWithLogin(sessionExpired: true),
  );
}

Future<void> _replaceWithLogin({bool sessionExpired = false}) async {
  final navigator = appNavigatorKey.currentState;
  if (navigator == null) {
    throw StateError('Unable to open the login page.');
  }
  await navigator.pushAndRemoveUntil<void>(
    MaterialPageRoute<void>(
      builder: (_) => LoginPage(sessionExpired: sessionExpired),
    ),
    (_) => false,
  );
}

Future<void> logoutAndNavigateToLogin(BuildContext context) async {
  try {
    await RememberMeSession.signOut();
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not sign out: $error')));
    }
    return;
  }

  if (!context.mounted) return;
  Navigator.of(context).pushAndRemoveUntil<void>(
    MaterialPageRoute<void>(builder: (_) => const LoginPage()),
    (_) => false,
  );
}

Widget _dashboardFor(String role, String name) {
  final normalizedRole = role.toLowerCase();
  if (normalizedRole == 'admin') {
    return AdminMainLayout(adminName: name);
  }
  if (normalizedRole == 'operator') {
    return OperatorMainLayout(operatorName: name);
  }
  if (normalizedRole == 'client' || normalizedRole == 'miner') {
    return MinerMainLayout(minerName: name);
  }
  return Scaffold(
    backgroundColor: appNavigatorKey.currentContext?.bgColor,
    body: Center(
      child: Text('The $role dashboard is currently under development.'),
    ),
  );
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, this.sessionExpired = false});

  final bool sessionExpired;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _rememberMe = false;

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
    _emailController.dispose();
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

  void _handleLogin() async {
    if (_formKey.currentState!.validate()) {
      _setLoading(true);

      final authService = AuthService(SupabaseAuthRepository());
      final result = await authService.login(
        LoginRequestDto(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        ),
      );

      if (!mounted) return;
      _setLoading(false);

      await result.fold<Future<void>>(
        (failure) async {
          String message = failure.message;
          IconData icon = Icons.error_outline;
          Color color = Colors.redAccent;

          if (failure is NetworkFailure) {
            message = failure.message.contains('Check your internet')
                ? failure.message
                : "Connection Error: Check your internet.";
            icon = Icons.wifi_off_rounded;
            color = Colors.orangeAccent;
          } else if (failure is AuthFailure) {
            // Only use the hardcoded message if it's a generic "Invalid login credentials" from Supabase
            if (failure.message.toLowerCase().contains(
              'invalid login credentials',
            )) {
              message = "Invalid Credentials: Please try again.";
            } else {
              message = failure.message;
            }
            icon = Icons.lock_person_outlined;
            color = Colors.redAccent;
          }

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(icon, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(child: Text(message)),
                ],
              ),
              backgroundColor: color,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        },
        (userDto) async {
          debugPrint(
            'Login successful: ${userDto.fname} ${userDto.lname} - Role: ${userDto.roleId}',
          );
          await _goToDashboard(
            userDto.roleId,
            '${userDto.fname} ${userDto.lname}',
            pinSet: userDto.pinHash != null,
            user: userDto,
          );
        },
      );
    }
  }

  Future<void> _goToDashboard(
    String role,
    String name, {
    bool pinSet = true,
    required UserDto user,
  }) async {
    final String normalizedRole = role.toLowerCase();

    if (normalizedRole == 'change_password_required') {
      await RememberMeSession.clear();
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const ChangePasswordPage()),
      );
      return;
    }

    if (!pinSet) {
      await RememberMeSession.clear();
      if (!mounted) return;
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => const SetPinPage()));
      return;
    }

    final dashboard = _dashboardFor(role, name);
    if (_rememberMe) {
      late final DateTime expiresAt;
      try {
        expiresAt = await RememberMeSession.rememberForSevenDays();
      } catch (error) {
        Object message = error;
        try {
          await SupabaseConfig.client.auth.signOut();
        } catch (signOutError) {
          message = '$error. Could not safely end the session: $signOutError';
        }
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not enable Remember me: $message'),
            backgroundColor: Colors.redAccent,
          ),
        );
        return;
      }
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => _rememberedSessionPage(
            user: user.toEntity(),
            expiresAt: expiresAt,
            initiallyUnlocked: true,
          ),
        ),
      );
    } else {
      await RememberMeSession.clear();
      if (!mounted) return;
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute<void>(builder: (_) => dashboard));
    }
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 40,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (widget.sessionExpired) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.orange.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: Colors.orange.withValues(alpha: 0.4),
                              ),
                            ),
                            child: const Text(
                              'Your 7-day remembered session has expired. Please log in again.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.orangeAccent),
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],
                        // Logo / mark
                        Center(
                          child: _buildLogoMark(
                            context,
                            size: 88,
                            iconSize: 40,
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'EGReS',
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

                        // Email field
                        _buildLabel('Email'),
                        const SizedBox(height: 8),
                        _buildTextField(
                          context,
                          controller: _emailController,
                          hint: 'Enter your email',
                          icon: Icons.email_outlined,
                          validator: (v) {
                            if (v == null || v.isEmpty)
                              return 'Email is required';
                            if (!v.contains('@')) return 'Enter a valid email';
                            return null;
                          },
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
                              () => _obscurePassword = !_obscurePassword,
                            ),
                          ),
                        ),

                        CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                          activeColor: kGold,
                          value: _rememberMe,
                          onChanged: _isLoading
                              ? null
                              : (value) {
                                  setState(() => _rememberMe = value ?? false);
                                },
                          title: Text(
                            'Remember me',
                            style: TextStyle(
                              color: context.textColor,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Contact your administrator to reset your password.',
                                  ),
                                ),
                              );
                            },
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
                              disabledBackgroundColor: kGold.withOpacity(0.6),
                              foregroundColor: Colors.white,
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

                        const SizedBox(height: 12),
                        Text(
                          'Sign in with the account provided by your administrator.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: context.mutedTextColor,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Expanded(
                              child: Divider(color: kGold.withOpacity(0.15)),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              child: Text(
                                'v1.0',
                                style: TextStyle(
                                  color: kGold.withOpacity(0.4),
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Divider(color: kGold.withOpacity(0.15)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            Positioned(
              top: 4,
              left: 4,
              child: IconButton(
                tooltip: 'Back to landing page',
                onPressed: () => Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const LandingPage()),
                ),
                icon: const Icon(Icons.arrow_back_rounded),
                color: context.textColor,
              ),
            ),

            // Light/dark mode toggle, top-right
            const Positioned(top: 4, right: 4, child: ThemeToggleButton()),

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
                          child: _buildLogoMark(
                            context,
                            size: 72,
                            iconSize: 32,
                          ),
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

  Widget _buildLogoMark(
    BuildContext context, {
    required double size,
    required double iconSize,
  }) {
    return Image.asset(
      'assets/img/EGReS.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
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
        contentPadding: const EdgeInsets.symmetric(
          vertical: 16,
          horizontal: 16,
        ),
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
}
