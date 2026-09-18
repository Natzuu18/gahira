import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../shared_widgets/appColor.dart';
import '../../infrastructure/repositories/supabase_user_repository.dart';
import '../../main.dart';

class SetPinPage extends StatefulWidget {
  const SetPinPage({super.key});

  @override
  State<SetPinPage> createState() => _SetPinPageState();
}

class _SetPinPageState extends State<SetPinPage> {
  final _pinController = TextEditingController();
  final _confirmPinController = TextEditingController();
  bool _isLoading = false;
  String? _error;

  Future<void> _handleSetPin() async {
    final pin = _pinController.text;
    final confirm = _confirmPinController.text;

    if (pin.length != 6) {
      setState(() => _error = 'PIN must be exactly 6 digits');
      return;
    }
    if (pin != confirm) {
      setState(() => _error = 'PINs do not match');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      _goToLogin();
      return;
    }

    final repo = SupabaseUserRepository();
    final result = await repo.updateUserPin(userId, pin);

    if (!mounted) return;

    result.fold(
      (failure) {
        setState(() {
          _isLoading = false;
          _error = failure.message;
        });
      },
      (_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('PIN set successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        _goToLogin(); // Force re-login or go to dashboard? 
        // Usually, after setting mandatory security, we can proceed.
        // But login logic in main.dart handles redirection, so let's just go back to login 
        // to re-trigger the flow or handle it specifically.
        // Actually, better to just push them to the login page to be sure.
      },
    );
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
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.lock_person_rounded, color: kGold, size: 64),
                const SizedBox(height: 24),
                const Text(
                  'SET SECURITY PIN',
                  style: TextStyle(color: kGold, fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 2),
                ),
                const SizedBox(height: 12),
                Text(
                  'A 6-digit PIN is required for authorizing important actions.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: context.mutedTextColor, fontSize: 14),
                ),
                const SizedBox(height: 32),
                _buildPinField(_pinController, 'New 6-Digit PIN'),
                const SizedBox(height: 20),
                _buildPinField(_confirmPinController, 'Confirm PIN'),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 20),
                    child: Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
                  ),
                const SizedBox(height: 40),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleSetPin,
                    style: ElevatedButton.styleFrom(backgroundColor: kGold, foregroundColor: kBlack),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: kBlack)
                        : const Text('SAVE PIN', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPinField(TextEditingController controller, String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: kGold, fontSize: 12, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: true,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          style: TextStyle(color: context.textColor, fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 8),
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(6),
          ],
          decoration: InputDecoration(
            filled: true,
            fillColor: context.surfaceColor,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: kGold.withOpacity(0.2))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: kGold.withOpacity(0.2))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kGold, width: 1.5)),
          ),
        ),
      ],
    );
  }
}
