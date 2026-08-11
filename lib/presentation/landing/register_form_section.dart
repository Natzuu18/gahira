import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../application/dtos/registration_dto.dart';
import '../../application/services/registration_service.dart';
import '../../domain/entities/registration_enums.dart';
import '../../infrastructure/repositories/supabase_registration_repository.dart';
import '../shared_widgets/appColor.dart';

/// A self-contained "Create your account" form section, meant to be
/// embedded directly inside another page's scrollable Column, e.g.:
///
/// Column(
///   children: [
///     ...otherSections,
///     const RegisterFormSection(),
///     ...moreSections,
///   ],
/// )
class RegisterFormSection extends StatefulWidget {
  const RegisterFormSection({super.key});

  @override
  State<RegisterFormSection> createState() => _RegisterFormSectionState();
}

class _RegisterFormSectionState extends State<RegisterFormSection> {
  final _formKey = GlobalKey<FormState>();

  final _firstNameController = TextEditingController();
  final _middleNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  final _businessNameController = TextEditingController();
  final _otpController = TextEditingController();

  UserRole _role = UserRole.client;

  // Phone verification (required for both roles). The phone number must be
  // confirmed via a one-time SMS code before the form can be submitted.
  // Once submitted, the same verified number is where the backend sends the
  // account's temporary password.
  bool _otpSent = false;
  bool _isSendingOtp = false;
  bool _isVerifyingOtp = false;
  bool _isPhoneVerified = false;
  String? _phoneVerifyError;

  // Client-only fields.
  ClientType _clientType = ClientType.individual;
  PlatformFile? _clientDocumentFile;
  String? _clientDocumentError;

  // Operator-only fields.
  PlatformFile? _resumeFile;
  String? _resumeError;
  DateTime? _appointmentDate;
  String? _appointmentError;

  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    // If the person edits the phone number after sending a code or getting
    // verified, that code/verification no longer applies to the new number.
    _phoneController.addListener(() {
      if (_isPhoneVerified || _otpSent) {
        _resetPhoneVerification();
      }
    });
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _middleNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _businessNameController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _pickResume() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    setState(() {
      _resumeFile = result.files.single;
      _resumeError = null;
    });
  }

  void _removeResume() {
    setState(() => _resumeFile = null);
  }

  Future<void> _pickClientDocument() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx', 'jpg', 'jpeg', 'png'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    setState(() {
      _clientDocumentFile = result.files.single;
      _clientDocumentError = null;
    });
  }

  void _removeClientDocument() {
    setState(() => _clientDocumentFile = null);
  }

  /// Basic format check only — doesn't confirm the number is reachable.
  /// That's what the OTP step below is for.
  String? _phoneFormatValidator(String? v) {
    if (v == null || v.trim().isEmpty) {
      return 'Phone number is required';
    }
    final digitsOnly = v.replaceAll(RegExp(r'[^0-9]'), '');
    if (digitsOnly.length < 7) {
      return 'Enter a valid phone number';
    }
    return null;
  }

  Future<void> _sendOtp() async {
    final formatError = _phoneFormatValidator(_phoneController.text);
    if (formatError != null) {
      setState(() => _phoneVerifyError = formatError);
      return;
    }

    setState(() {
      _isSendingOtp = true;
      _phoneVerifyError = null;
    });

    final service = RegistrationService(SupabaseRegistrationRepository());
    final result = await service.sendPhoneOtp(_phoneController.text.trim());

    if (!mounted) return;
    
    result.fold(
      (failure) {
        setState(() {
          _isSendingOtp = false;
          _phoneVerifyError = failure.message;
        });
      },
      (_) {
        setState(() {
          _isSendingOtp = false;
          _otpSent = true;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Verification code sent to ${_phoneController.text.trim()}',
            ),
            backgroundColor: Colors.blueGrey.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      },
    );
  }

  Future<void> _verifyOtp() async {
    final code = _otpController.text.trim();
    if (code.length != 6) {
      setState(() => _phoneVerifyError = 'Enter the 6-digit code');
      return;
    }

    setState(() {
      _isVerifyingOtp = true;
      _phoneVerifyError = null;
    });

    final service = RegistrationService(SupabaseRegistrationRepository());
    final result = await service.verifyPhoneOtp(
      phoneNumber: _phoneController.text.trim(),
      code: code,
    );

    if (!mounted) return;
    
    result.fold(
      (failure) {
        setState(() {
          _isVerifyingOtp = false;
          _phoneVerifyError = failure.message;
        });
      },
      (isValid) {
        setState(() {
          _isVerifyingOtp = false;
          if (isValid) {
            _isPhoneVerified = true;
            _otpSent = false;
            _otpController.clear();
          } else {
            _phoneVerifyError = 'Incorrect code, please try again';
          }
        });
      },
    );
  }

  void _resetPhoneVerification() {
    setState(() {
      _isPhoneVerified = false;
      _otpSent = false;
      _otpController.clear();
      _phoneVerifyError = null;
    });
  }

  Future<void> _pickAppointmentDate() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final picked = await showDatePicker(
      context: context,
      initialDate: _appointmentDate ?? today.add(const Duration(days: 1)),
      firstDate: today,
      lastDate: today.add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: kGold,
              onPrimary: kBlack,
              surface: context.surfaceColor,
              onSurface: context.textColor,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked == null) return;

    setState(() {
      _appointmentDate = picked;
      _appointmentError = null;
    });
  }

  void _clearAppointmentDate() {
    setState(() => _appointmentDate = null);
  }

  /// Formats a date like "Monday, Aug 10, 2026" without needing the intl
  /// package.
  String _formatAppointmentDate(DateTime date) {
    const weekdays = [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday',
      'Friday', 'Saturday', 'Sunday',
    ];
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final weekday = weekdays[date.weekday - 1];
    final month = months[date.month - 1];
    return '$weekday, $month ${date.day}, ${date.year}';
  }

  Future<void> _handleRegister() async {
    final formValid = _formKey.currentState!.validate();

    // File uploads and the appointment date aren't Form fields, so we
    // validate them manually alongside the form, scoped to the active role.
    // (Phone verification is currently bypassed).
    setState(() {
      _resumeError = (_role == UserRole.operator && _resumeFile == null)
          ? 'Please attach your resume'
          : null;
      _appointmentError =
      (_role == UserRole.operator && _appointmentDate == null)
          ? 'Please select an appointment date'
          : null;
      _clientDocumentError =
      (_role == UserRole.client && _clientDocumentFile == null)
          ? 'Please attach a valid ID or business document'
          : null;
    });

    if (!formValid ||
        _resumeError != null ||
        _appointmentError != null ||
        _clientDocumentError != null) {
      return;
    }

    setState(() => _isSubmitting = true);

    final service = RegistrationService(SupabaseRegistrationRepository());
    final registrationDto = RegistrationDto(
      firstName: _firstNameController.text.trim(),
      middleName: _middleNameController.text.trim(),
      lastName: _lastNameController.text.trim(),
      phone: _phoneController.text.trim(),
      email: _emailController.text.trim(),
      address: _addressController.text.trim(),
      role: _role.name,
      clientType: _role == UserRole.client ? _clientType.name : null,
      businessName: _role == UserRole.client ? _businessNameController.text.trim() : null,
      clientDocumentBase64: _clientDocumentFile?.bytes != null ? base64Encode(_clientDocumentFile!.bytes!) : null,
      clientDocumentName: _clientDocumentFile?.name,
      resumeBase64: _resumeFile?.bytes != null ? base64Encode(_resumeFile!.bytes!) : null,
      resumeName: _resumeFile?.name,
      appointmentDate: _appointmentDate?.toIso8601String(),
    );

    final result = await service.register(registrationDto);

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    result.fold(
      (failure) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text(failure.message)),
              ],
            ),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      },
      (userDto) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle_outline, color: Colors.white),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Account created. Your temporary '
                        'password was sent by SMS — please change your '
                        'password after logging in.',
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      color: context.surfaceColor.withOpacity(0.4),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'CREATE YOUR ACCOUNT',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: kGold,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Sign up to start managing your mill operations.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: kGold.withOpacity(0.7),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 24),

                // --- Account type: Client / Operator ---
                _buildLabel('I am signing up as'),
                const SizedBox(height: 8),
                _buildRoleSelector(context),
                const SizedBox(height: 22),

                // --- Name fields ---
                _buildLabel('First Name'),
                const SizedBox(height: 8),
                _buildTextField(
                  context,
                  controller: _firstNameController,
                  hint: 'Enter your first name',
                  icon: Icons.badge_outlined,
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'First name is required'
                      : null,
                ),
                const SizedBox(height: 18),

                _buildLabel('Middle Name (optional)'),
                const SizedBox(height: 8),
                _buildTextField(
                  context,
                  controller: _middleNameController,
                  hint: 'Enter your middle name',
                  icon: Icons.badge_outlined,
                ),
                const SizedBox(height: 18),

                _buildLabel('Last Name'),
                const SizedBox(height: 8),
                _buildTextField(
                  context,
                  controller: _lastNameController,
                  hint: 'Enter your last name',
                  icon: Icons.badge_outlined,
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Last name is required'
                      : null,
                ),
                const SizedBox(height: 18),

                _buildLabel('Phone Number'),
                const SizedBox(height: 8),
                _buildPhoneVerificationField(context),
                const SizedBox(height: 18),

                _buildLabel('Gmail'),
                const SizedBox(height: 8),
                _buildTextField(
                  context,
                  controller: _emailController,
                  hint: 'yourname@gmail.com',
                  icon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Gmail address is required';
                    }
                    final value = v.trim().toLowerCase();
                    if (!value.endsWith('@gmail.com')) {
                      return 'Please use a valid @gmail.com address';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 18),

                _buildLabel('Address'),
                const SizedBox(height: 8),
                _buildTextField(
                  context,
                  controller: _addressController,
                  hint: 'House/Unit No., Street, City, Province',
                  icon: Icons.home_outlined,
                  maxLines: 2,
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Address is required'
                      : null,
                ),

                // --- Client-only fields: client type, business name, document ---
                if (_role == UserRole.client) ...[
                  const SizedBox(height: 18),
                  _buildLabel('Client Type'),
                  const SizedBox(height: 8),
                  _buildClientTypeSelector(context),

                  if (_clientType == ClientType.business) ...[
                    const SizedBox(height: 18),
                    _buildLabel('Business Name (optional)'),
                    const SizedBox(height: 8),
                    _buildTextField(
                      context,
                      controller: _businessNameController,
                      hint: 'Enter your business name',
                      icon: Icons.storefront_outlined,
                    ),
                  ],

                  const SizedBox(height: 18),
                  _buildLabel('Upload Valid ID or Business Document'),
                  const SizedBox(height: 8),
                  _buildFileUploadField(
                    context,
                    file: _clientDocumentFile,
                    error: _clientDocumentError,
                    placeholder: 'Tap to upload a document',
                    onTap: _pickClientDocument,
                    onRemove: _removeClientDocument,
                  ),
                ],

                // --- Operator-only fields: resume + appointment date ---
                if (_role == UserRole.operator) ...[
                  const SizedBox(height: 18),
                  _buildLabel('Resume (PDF or Word)'),
                  const SizedBox(height: 8),
                  _buildFileUploadField(
                    context,
                    file: _resumeFile,
                    error: _resumeError,
                    placeholder: 'Tap to upload your resume',
                    onTap: _pickResume,
                    onRemove: _removeResume,
                  ),

                  const SizedBox(height: 18),
                  _buildLabel('Preferred Appointment Date'),
                  const SizedBox(height: 8),
                  _buildAppointmentDatePicker(context),
                ],

                const SizedBox(height: 26),

                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _handleRegister,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kGold,
                      disabledBackgroundColor: kGold.withOpacity(0.6),
                      foregroundColor: kBlack,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 0,
                    ),
                    child: _isSubmitting
                        ? SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        valueColor:
                        AlwaysStoppedAnimation<Color>(kBlack),
                      ),
                    )
                        : const Text(
                      'SIGN UP',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRoleSelector(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _buildRoleOption(
            context,
            role: UserRole.client,
            label: 'Client',
            icon: Icons.person_outline,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildRoleOption(
            context,
            role: UserRole.operator,
            label: 'Operator',
            icon: Icons.engineering_outlined,
          ),
        ),
      ],
    );
  }

  Widget _buildRoleOption(
      BuildContext context, {
        required UserRole role,
        required String label,
        required IconData icon,
      }) {
    final isSelected = _role == role;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => setState(() => _role = role),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? kGold.withOpacity(0.15) : context.surfaceColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? kGold : kGold.withOpacity(0.25),
            width: isSelected ? 1.6 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? kGold : kGold.withOpacity(0.6),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? kGold : context.mutedTextColor,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClientTypeSelector(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _buildClientTypeOption(
            context,
            type: ClientType.individual,
            label: 'Individual',
            icon: Icons.person_outline,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildClientTypeOption(
            context,
            type: ClientType.business,
            label: 'Business',
            icon: Icons.storefront_outlined,
          ),
        ),
      ],
    );
  }

  Widget _buildClientTypeOption(
      BuildContext context, {
        required ClientType type,
        required String label,
        required IconData icon,
      }) {
    final isSelected = _clientType == type;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => setState(() => _clientType = type),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? kGold.withOpacity(0.15) : context.surfaceColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? kGold : kGold.withOpacity(0.25),
            width: isSelected ? 1.6 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? kGold : kGold.withOpacity(0.6),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? kGold : context.mutedTextColor,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Phone number field with an inline "Send Code" / OTP confirmation flow.
  /// (OTP functionality is currently commented out).
  Widget _buildPhoneVerificationField(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          style: TextStyle(color: context.textColor),
          cursorColor: kGold,
          validator: _phoneFormatValidator,
          decoration: InputDecoration(
            hintText: 'e.g. 09XXXXXXXXX',
            hintStyle: TextStyle(color: context.mutedTextColor),
            prefixIcon: Icon(Icons.phone_outlined, color: kGold.withOpacity(0.8)),
            filled: true,
            fillColor: context.surfaceColor,
            contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
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
        ),
        const SizedBox(height: 6),
        Text(
          'Your temporary password will be sent to this number once your account is created.',
          style: TextStyle(color: context.mutedTextColor, fontSize: 11.5),
        ),
      ],
    );
  }

  /// Generic tappable file-upload row, shared by the resume upload
  /// (operators) and the ID/business document upload (clients).
  Widget _buildFileUploadField(
      BuildContext context, {
        required PlatformFile? file,
        required String? error,
        required String placeholder,
        required VoidCallback onTap,
        required VoidCallback onRemove,
      }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
            decoration: BoxDecoration(
              color: context.surfaceColor,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: error != null
                    ? Colors.redAccent
                    : kGold.withOpacity(0.25),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.upload_file_outlined, color: kGold.withOpacity(0.8)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    file?.name ?? placeholder,
                    style: TextStyle(
                      color: file != null
                          ? context.textColor
                          : context.mutedTextColor,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (file != null)
                  IconButton(
                    icon: Icon(Icons.close, color: kGold.withOpacity(0.7)),
                    onPressed: onRemove,
                  ),
              ],
            ),
          ),
        ),
        if (error != null) ...[
          const SizedBox(height: 6),
          Text(
            error,
            style: const TextStyle(color: Colors.redAccent, fontSize: 12),
          ),
        ],
      ],
    );
  }

  Widget _buildAppointmentDatePicker(BuildContext context) {
    final label = _appointmentDate != null
        ? _formatAppointmentDate(_appointmentDate!)
        : 'Tap to select a date';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: _pickAppointmentDate,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
            decoration: BoxDecoration(
              color: context.surfaceColor,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _appointmentError != null
                    ? Colors.redAccent
                    : kGold.withOpacity(0.25),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_today_outlined,
                    color: kGold.withOpacity(0.8)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: _appointmentDate != null
                          ? context.textColor
                          : context.mutedTextColor,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (_appointmentDate != null)
                  IconButton(
                    icon: Icon(Icons.close, color: kGold.withOpacity(0.7)),
                    onPressed: _clearAppointmentDate,
                  ),
              ],
            ),
          ),
        ),
        if (_appointmentError != null) ...[
          const SizedBox(height: 6),
          Text(
            _appointmentError!,
            style: const TextStyle(color: Colors.redAccent, fontSize: 12),
          ),
        ],
      ],
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
        int maxLines = 1,
        TextInputType? keyboardType,
        Widget? suffixIcon,
        String? Function(String?)? validator,
      }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      maxLines: obscureText ? 1 : maxLines,
      keyboardType: keyboardType,
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
}
