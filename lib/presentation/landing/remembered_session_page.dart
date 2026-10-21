import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import '../../core/auth/remember_me_session.dart';
import '../../domain/entities/user_entity.dart';
import '../../infrastructure/repositories/supabase_service_request_repository.dart';
import '../shared_widgets/appColor.dart';

class RememberedSessionPage extends StatefulWidget {
  const RememberedSessionPage({
    super.key,
    required this.user,
    required this.expiresAt,
    required this.dashboard,
    required this.onChangeUser,
    required this.onSessionExpired,
    this.initiallyUnlocked = false,
  });

  final UserEntity user;
  final DateTime expiresAt;
  final Widget dashboard;
  final Future<void> Function() onChangeUser;
  final Future<void> Function() onSessionExpired;
  final bool initiallyUnlocked;

  @override
  State<RememberedSessionPage> createState() => _RememberedSessionPageState();
}

class _RememberedSessionPageState extends State<RememberedSessionPage>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  final _pinController = TextEditingController();
  final _serviceRequestRepository = SupabaseServiceRequestRepository();
  late bool _isUnlocked;
  bool _isWorking = false;
  bool _isEndingSession = false;
  bool _lockOnResume = false;
  String? _error;
  Timer? _expiryTimer;
  AnimationController? _reflectionControllerValue;

  AnimationController get _reflectionController =>
      _reflectionControllerValue ??= AnimationController(
        vsync: this,
      duration: const Duration(milliseconds: 5500),
      )..repeat();

  @override
  void initState() {
    super.initState();
    _isUnlocked = widget.initiallyUnlocked;
    WidgetsBinding.instance.addObserver(this);
    _scheduleExpiry();
    _expireIfNeeded();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _expiryTimer?.cancel();
    _reflectionControllerValue?.dispose();
    _pinController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused) {
      _lockOnResume = true;
    } else if (state == AppLifecycleState.resumed) {
      if (_lockOnResume && _isUnlocked) {
        setState(() {
          _isUnlocked = false;
          _pinController.clear();
        });
      }
      _lockOnResume = false;
      _expireIfNeeded();
    }
  }

  void _scheduleExpiry() {
    final remaining = widget.expiresAt.difference(DateTime.now());
    if (remaining <= Duration.zero) {
      _expireIfNeeded();
      return;
    }
    _expiryTimer = Timer(remaining, _expireSession);
  }

  Future<void> _expireIfNeeded() async {
    if (!widget.expiresAt.isAfter(DateTime.now())) {
      await _expireSession();
    }
  }

  Future<void> _expireSession() async {
    if (_isEndingSession) return;
    _isEndingSession = true;
    try {
      await RememberMeSession.signOut();
      await widget.onSessionExpired();
    } catch (error) {
      if (mounted) {
        setState(() {
          _isEndingSession = false;
          _error = 'Could not expire this session. Please try again: $error';
        });
      }
    }
  }

  Future<void> _changeUser() async {
    setState(() {
      _isWorking = true;
      _error = null;
    });
    try {
      await RememberMeSession.signOut();
      await widget.onChangeUser();
    } catch (error) {
      if (mounted) {
        setState(() {
          _isWorking = false;
          _error = 'Could not sign out. Please try again: $error';
        });
      }
    }
  }

  Future<void> _unlock() async {
    if (_pinController.text.length != 6 || _isWorking) return;
    setState(() {
      _isWorking = true;
      _error = null;
    });

    final result = await _serviceRequestRepository.verifyUserPin(
      widget.user.userId,
      _pinController.text,
    );
    if (!mounted) return;

    result.fold(
      (failure) {
        setState(() {
          _isWorking = false;
          _pinController.clear();
          _error = failure.message;
        });
      },
      (isValid) {
        setState(() {
          _isWorking = false;
          if (isValid) {
            _isUnlocked = true;
          } else {
            _pinController.clear();
            _error = 'Incorrect PIN. Please try again.';
          }
        });
        _expireIfNeeded();
      },
    );
  }

  void _addDigit(String digit) {
    if (_isWorking || _pinController.text.length >= 6) return;
    setState(() {
      _pinController.text += digit;
      _error = null;
    });
    if (_pinController.text.length == 6) _unlock();
  }

  void _removeDigit() {
    if (_isWorking || _pinController.text.isEmpty) return;
    setState(() {
      _pinController.text = _pinController.text.substring(
        0,
        _pinController.text.length - 1,
      );
      _error = null;
    });
  }

  Widget _buildKeypadButton(
    BuildContext context, {
    required String? digit,
    required VoidCallback? onPressed,
    IconData? icon,
  }) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: SizedBox(
          height: 58,
          child: digit == null && icon == null
              ? const SizedBox.shrink()
              : Material(
                  color: kGold.withValues(alpha: 0.08),
                  shape: CircleBorder(
                    side: BorderSide(color: kGold.withValues(alpha: 0.24)),
                  ),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    splashColor: kGold.withValues(alpha: 0.2),
                    onTap: onPressed,
                    child: Center(
                      child: icon != null
                          ? Icon(icon, color: kGold, size: 23)
                          : Text(
                              digit!,
                              style: TextStyle(
                                color: context.textColor,
                                fontSize: 23,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isEndingSession || (_error != null && _isUnlocked)) {
      return Scaffold(
        backgroundColor: context.bgColor,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.lock_clock_rounded,
                  color: Colors.orangeAccent,
                  size: 48,
                ),
                const SizedBox(height: 16),
                Text(
                  _error ??
                      'Your 7-day remembered session has expired. Signing out…',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: context.textColor),
                ),
                if (!_isEndingSession) ...[
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: _expireSession,
                    child: const Text('Retry sign out'),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    if (_isUnlocked) return widget.dashboard;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final glassFill = isDark
        ? Colors.white.withValues(alpha: 0.07)
        : Colors.white.withValues(alpha: 0.66);

    return Scaffold(
      backgroundColor: context.bgColor,
      body: Stack(
        children: [
          Positioned(
            top: -100,
            right: -70,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    kGold.withValues(alpha: isDark ? 0.2 : 0.16),
                    kGold.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -110,
            left: -80,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    kGold.withValues(alpha: isDark ? 0.14 : 0.11),
                    kGold.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: ClipRect(
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        context.surfaceColor.withValues(
                          alpha: isDark ? 0.22 : 0.18,
                        ),
                        kGold.withValues(alpha: isDark ? 0.055 : 0.075),
                        context.bgColor.withValues(alpha: isDark ? 0.34 : 0.12),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: BackdropFilter(
                      filter: ui.ImageFilter.blur(sigmaX: 22, sigmaY: 22),
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(24, 30, 24, 22),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              glassFill,
                              kGold.withValues(alpha: isDark ? 0.07 : 0.12),
                              glassFill.withValues(alpha: isDark ? 0.04 : 0.4),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(
                            color: kGold.withValues(alpha: 0.42),
                            width: 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: kGold.withValues(
                                alpha: isDark ? 0.12 : 0.16,
                              ),
                              blurRadius: 32,
                              spreadRadius: 1,
                            ),
                            BoxShadow(
                              color: Colors.black.withValues(
                                alpha: isDark ? 0.24 : 0.06,
                              ),
                              blurRadius: 24,
                              offset: const Offset(0, 14),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'EGReS',
                              style: TextStyle(
                                color: context.mutedTextColor,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 4,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Container(
                              width: 58,
                              height: 58,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: kGold.withValues(alpha: isDark ? 0.1 : 0.12),
                                border: Border.all(
                                  color: kGold.withValues(alpha: 0.7),
                                  width: 1.4,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: kGold.withValues(alpha: 0.12),
                                    blurRadius: 16,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.settings_input_component_rounded,
                                color: kGold,
                                size: 30,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Welcome back, ${widget.user.fname}',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: context.textColor,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              widget.user.email,
                              style: TextStyle(color: context.mutedTextColor),
                            ),
                            const SizedBox(height: 24),
                            Text(
                              'Enter your 6-digit PIN to continue',
                              style: TextStyle(color: context.mutedTextColor),
                            ),
                            const SizedBox(height: 24),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(6, (index) {
                                final isFilled =
                                    index < _pinController.text.length;
                                return Container(
                                  width: 15,
                                  height: 15,
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 9,
                                  ),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isFilled
                                        ? kGold
                                        : Colors.transparent,
                                    border: Border.all(
                                      color: isFilled
                                          ? kGold
                                          : context.mutedTextColor.withValues(
                                              alpha: 0.7,
                                            ),
                                      width: 1.5,
                                    ),
                                  ),
                                );
                              }),
                            ),
                            const SizedBox(height: 18),
                            if (_isWorking)
                              const SizedBox(
                                height: 24,
                                width: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: kGold,
                                ),
                              )
                            else
                              Column(
                                children: [
                                  for (final row in const [
                                    ['1', '2', '3'],
                                    ['4', '5', '6'],
                                    ['7', '8', '9'],
                                  ])
                                    Row(
                                      children: row
                                          .map(
                                            (digit) => _buildKeypadButton(
                                              context,
                                              digit: digit,
                                              onPressed: () => _addDigit(digit),
                                            ),
                                          )
                                          .toList(),
                                    ),
                                  Row(
                                    children: [
                                      _buildKeypadButton(
                                        context,
                                        digit: null,
                                        onPressed: null,
                                      ),
                                      _buildKeypadButton(
                                        context,
                                        digit: '0',
                                        onPressed: () => _addDigit('0'),
                                      ),
                                      _buildKeypadButton(
                                        context,
                                        digit: null,
                                        icon: Icons.backspace_outlined,
                                        onPressed: _removeDigit,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            if (_error != null) ...[
                              const SizedBox(height: 8),
                              Text(
                                _error!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.redAccent),
                              ),
                            ],
                            const SizedBox(height: 8),
                            TextButton(
                              onPressed: _isWorking ? null : _changeUser,
                              child: const Text(
                                'Change user',
                                style: TextStyle(color: kGold),
                              ),
                            ),
                            Text(
                              'Your session expires ${widget.expiresAt.toLocal()}',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: context.mutedTextColor,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _reflectionController,
                builder: (context, child) => CustomPaint(
                  painter: _GlassReflectionPainter(
                    progress: _reflectionController.value,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GlassReflectionPainter extends CustomPainter {
  const _GlassReflectionPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final diagonal = Offset(size.width, size.height);
    final length = diagonal.distance;
    final angle = math.atan2(size.height, size.width);
    final center = Offset(size.width * progress, size.height * progress);
    final reflectionWidth = size.shortestSide * 0.3;

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle);
    final paint = Paint()
      ..shader = const LinearGradient(
        colors: [
          Colors.transparent,
          Color(0x16FFFFFF),
          Color(0x52FFFFFF),
          Color(0x16FFFFFF),
          Colors.transparent,
        ],
        stops: [0, 0.4, 0.5, 0.6, 1],
      ).createShader(
        Rect.fromLTWH(-reflectionWidth / 2, -length, reflectionWidth, length * 2),
      );
    canvas.drawRect(
      Rect.fromLTWH(-reflectionWidth / 2, -length, reflectionWidth, length * 2),
      paint,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _GlassReflectionPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
