import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../application/dtos/registration_dto.dart';
import '../../application/services/registration_service.dart';
import '../../domain/entities/registration_enums.dart';
import '../../infrastructure/repositories/supabase_registration_repository.dart';
import '../shared_widgets/appColor.dart';

/// A self-contained "Submit your application" form section, meant to be
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
  static const int _maxUploadBytes = 10 * 1024 * 1024;
  final _formKey = GlobalKey<FormState>();

  final _firstNameController = TextEditingController();
  final _middleNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  final _otpController = TextEditingController();

  UserRole _role = UserRole.miner;

  // Phone verification (required for both roles). The phone number must be
  // confirmed via a one-time SMS code before the form can be submitted.
  // Once submitted, the same verified number is where the backend sends the
  // account's temporary password.
  bool _otpSent = false;
  bool _isSendingOtp = false;
  bool _isVerifyingOtp = false;
  bool _isPhoneVerified = false;
  String? _phoneVerificationToken;
  String? _phoneVerifyError;

  // Client-only fields.
  final _miningUnitController = TextEditingController();
  String? _selectedMiningUnitId;
  String? _miningUnitError;
  PlatformFile? _clientDocumentFile;
  String? _clientDocumentError;

  // Operator-only fields.
  PlatformFile? _resumeFile;
  String? _resumeError;
  DateTime? _appointmentDate;
  String? _appointmentError;
  DateTime _viewingDate = DateTime(DateTime.now().year, DateTime.now().month);
  String? _selectedTime;
  String? _selectedStartTime;
  String? _selectedAvailabilityId;

  List<Map<String, String>> _availableSlots = [];
  List<Map<String, dynamic>> _miningUnits = [];
  bool _isLoadingSlots = true;
  bool _isLoadingUnits = true;

  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _fetchAvailableSlots();
    _fetchMiningUnits();
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
    _otpController.dispose();
    _miningUnitController.dispose();
    super.dispose();
  }

  Future<void> _pickResume() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.single;

    setState(() {
      if (file.size > _maxUploadBytes) {
        _resumeFile = null;
        _resumeError = 'File must be 10 MB or smaller';
      } else {
        _resumeFile = file;
        _resumeError = null;
      }
    });
    if (file.size > _maxUploadBytes) {
      _showTopNotification(context, 'File must be 10 MB or smaller', isError: true);
    }
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
    final file = result.files.single;

    setState(() {
      if (file.size > _maxUploadBytes) {
        _clientDocumentFile = null;
        _clientDocumentError = 'File must be 10 MB or smaller';
      } else {
        _clientDocumentFile = file;
        _clientDocumentError = null;
      }
    });
    if (file.size > _maxUploadBytes) {
      _showTopNotification(context, 'File must be 10 MB or smaller', isError: true);
    }
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
    if (!RegExp(r'^\d{11}$').hasMatch(v.trim())) {
      return 'Phone number must be exactly 11 digits';
    }
    return null;
  }

  String? _nameValidator(String? value, String label, {bool required = true}) {
    final name = value?.trim() ?? '';
    if (name.isEmpty) return required ? '$label is required' : null;
    if (!RegExp(r'^[A-Z]').hasMatch(name)) {
      return 'The first letter of $label must be capitalized';
    }
    return null;
  }

  Future<void> _sendOtp() async {
    final formatError = _phoneFormatValidator(_phoneController.text);
    if (formatError != null) {
      setState(() => _phoneVerifyError = formatError);
      _showTopNotification(context, formatError, isError: true);
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
        _showTopNotification(context, failure.message, isError: true);
      },
      (_) {
        setState(() {
          _isSendingOtp = false;
          _otpSent = true;
        });
        _showTopNotification(context, 'Verification code sent to ${_phoneController.text.trim()}', isError: false);
      },
    );
  }

  Future<void> _verifyOtp() async {
    final code = _otpController.text.trim();
    if (code.length != 6) {
      setState(() => _phoneVerifyError = 'Enter the 6-digit code');
      _showTopNotification(context, 'Please enter the 6-digit code', isError: true);
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
        _showTopNotification(context, failure.message, isError: true);
      },
      (token) {
        setState(() {
          _isVerifyingOtp = false;
          _isPhoneVerified = true;
          _phoneVerificationToken = token;
          _otpSent = false;
          _otpController.clear();
        });
        _showTopNotification(context, 'Phone number verified successfully!', isError: false);
      },
    );
  }

  void _resetPhoneVerification() {
    setState(() {
      _isPhoneVerified = false;
      _phoneVerificationToken = null;
      _otpSent = false;
      _otpController.clear();
      _phoneVerifyError = null;
    });
  }

  Future<void> _fetchAvailableSlots() async {
    setState(() => _isLoadingSlots = true);
    final service = RegistrationService(SupabaseRegistrationRepository());
    final result = await service.getAvailableSlots();

    if (!mounted) return;

    result.fold(
      (failure) {
        setState(() => _isLoadingSlots = false);
      },
      (slots) {
        setState(() {
          _availableSlots = [];
          for (final slot in slots) {
            try {
              final start = DateFormat('HH:mm:ss').parse(slot['start_time'].toString());
              final end = DateFormat('HH:mm:ss').parse(slot['end_time'].toString());
              final bookedValue = slot['booked_appointment_times'];
              final bookedTimes = bookedValue is List
                  ? bookedValue.map((value) => value.toString().substring(0, 8)).toSet()
                  : <String>{};

              var cursor = start;
              while (cursor.add(const Duration(hours: 1)).compareTo(end) <= 0) {
                final slotEnd = cursor.add(const Duration(hours: 1));
                final startValue = DateFormat('HH:mm:ss').format(cursor);
                if (!bookedTimes.contains(startValue)) {
                  _availableSlots.add({
                    'availability_id': slot['availability_id']?.toString() ?? '',
                    'date': slot['date'].toString(),
                    'time': '${_displayTime(startValue)} - ${_displayTime(DateFormat('HH:mm:ss').format(slotEnd))}',
                    'start_time': startValue,
                    'address': slot['address'].toString(),
                  });
                }
                cursor = slotEnd;
              }
            } catch (_) {
              // Skip malformed availability rows instead of showing unusable times.
            }
          }
          _isLoadingSlots = false;
        });
      },
    );
  }

  Future<void> _fetchMiningUnits() async {
    setState(() => _isLoadingUnits = true);
    try {
      final repository = SupabaseRegistrationRepository();
      // We will implement this method in the repository
      final result = await repository.getMiningUnits();
      result.fold(
        (failure) => setState(() => _isLoadingUnits = false),
        (units) => setState(() {
          _miningUnits = units;
          _isLoadingUnits = false;
        }),
      );
    } catch (e) {
      setState(() => _isLoadingUnits = false);
    }
  }

  String _displayTime(String timeStr) {
    try {
      // Expecting HH:mm:ss from DB
      final dt = DateFormat('HH:mm:ss').parse(timeStr);
      return DateFormat('hh:mm a').format(dt);
    } catch (e) {
      return timeStr;
    }
  }

  bool _checkFormChecklist() {
    final hasFirstName = _firstNameController.text.trim().isNotEmpty;
    final hasLastName = _lastNameController.text.trim().isNotEmpty;
    final hasPhone = _phoneController.text.trim().isNotEmpty;
    final isPhoneVerified = _isPhoneVerified;
    final hasEmail = _emailController.text.trim().isNotEmpty && _emailController.text.contains('@');
    final hasAddress = _addressController.text.trim().isNotEmpty;

    final hasMiningUnit = _selectedMiningUnitId != null || _miningUnitController.text.trim().isNotEmpty;
    final hasClientDocument = _clientDocumentFile != null;

    final hasResume = _resumeFile != null;
    final hasAppointment = _appointmentDate != null && _selectedTime != null;

    final bool isComplete = _role == UserRole.miner
        ? (hasFirstName && hasLastName && hasPhone && isPhoneVerified && hasEmail && hasAddress && hasMiningUnit && hasClientDocument)
        : (hasFirstName && hasLastName && hasPhone && isPhoneVerified && hasEmail && hasAddress && hasResume && hasAppointment);

    if (!isComplete) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: ctx.surfaceColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.fact_check_outlined, color: kGold),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Form Completion Checklist',
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
                Text(
                  'Please complete all required items before submitting your application:',
                  style: TextStyle(color: ctx.textColor, fontSize: 12),
                ),
                const SizedBox(height: 16),
                _buildChecklistItem(ctx, 'First Name', hasFirstName),
                _buildChecklistItem(ctx, 'Last Name', hasLastName),
                _buildChecklistItem(ctx, 'Phone Number Provided', hasPhone),
                _buildChecklistItem(ctx, 'Phone Number Verified (SMS OTP)', isPhoneVerified),
                _buildChecklistItem(ctx, 'Valid Email Address', hasEmail),
                _buildChecklistItem(ctx, 'Address Details', hasAddress),
                if (_role == UserRole.miner) ...[
                  _buildChecklistItem(ctx, 'Associated Mining Unit', hasMiningUnit),
                  _buildChecklistItem(ctx, 'Valid ID / Business Document', hasClientDocument),
                ] else ...[
                  _buildChecklistItem(ctx, 'Resume Document Uploaded', hasResume),
                  _buildChecklistItem(ctx, 'Interview Date & Time Scheduled', hasAppointment),
                ],
              ],
            ),
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: kGold,
                foregroundColor: kBlack,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Complete Missing Fields', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
      return false;
    }

    return true;
  }

  Widget _buildChecklistItem(BuildContext ctx, String label, bool isDone) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isDone ? Colors.green.withOpacity(0.08) : Colors.red.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDone ? Colors.green.withOpacity(0.3) : Colors.red.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isDone ? Icons.check_circle_rounded : Icons.cancel_rounded,
            color: isDone ? Colors.green : Colors.redAccent,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: ctx.textColor,
                fontSize: 12,
                fontWeight: isDone ? FontWeight.w500 : FontWeight.bold,
              ),
            ),
          ),
          Text(
            isDone ? 'READY' : 'MISSING',
            style: TextStyle(
              color: isDone ? Colors.green : Colors.redAccent,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleRegister() async {
    final formValid = _formKey.currentState!.validate();

    // File uploads and the appointment date aren't Form fields, so we
    // validate them manually alongside the form, scoped to the active role.
    setState(() {
      _resumeError = (_role == UserRole.operator && _resumeFile == null)
          ? (_resumeError ?? 'Please attach your resume')
          : null;
      final today = DateTime.now();
      final todayStart = DateTime(today.year, today.month, today.day);
      final appointmentIsPast = _appointmentDate != null &&
          DateTime(_appointmentDate!.year, _appointmentDate!.month, _appointmentDate!.day)
              .isBefore(todayStart);
      _appointmentError = (_role == UserRole.operator &&
              (_appointmentDate == null || _selectedTime == null || appointmentIsPast))
          ? (appointmentIsPast
              ? 'Please choose an interview date from today onward'
              : 'Please select an interview date and time')
          : null;
      _miningUnitError = 
      (_role == UserRole.miner && _selectedMiningUnitId == null && _miningUnitController.text.trim().isEmpty)
          ? 'Please enter or select an associated unit'
          : null;
      _clientDocumentError =
      (_role == UserRole.miner && _clientDocumentFile == null)
          ? (_clientDocumentError ?? 'Please attach a valid ID or business document')
          : null;
    });

    if (!formValid ||
        !_checkFormChecklist() ||
        _resumeError != null ||
        _appointmentError != null ||
        _miningUnitError != null ||
        _clientDocumentError != null) {
      final String firstError = _resumeError ??
          _appointmentError ??
          _miningUnitError ??
          _clientDocumentError ??
          'Please complete all required fields in the signup form.';
      _showTopNotification(context, firstError, isError: true);
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final repository = SupabaseRegistrationRepository();
      
      // Handle Mining Unit creation if it's a new name
      String? finalMiningUnitId = _selectedMiningUnitId;
      if (_role == UserRole.miner && finalMiningUnitId == null && _miningUnitController.text.isNotEmpty) {
        final createResult = await repository.createMiningUnit(_miningUnitController.text.trim());
        createResult.fold(
          (failure) => throw Exception(failure.message),
          (unitId) => finalMiningUnitId = unitId,
        );
      }

      final service = RegistrationService(repository);
      
      // Store the selected date and the start of its one-hour time slot.
      String? formattedAppointmentDate;
      if (_appointmentDate != null && _selectedStartTime != null) {
        try {
          final selectedTime = DateFormat('HH:mm:ss').parse(_selectedStartTime!);
          final appointmentDateTime = DateTime(
            _appointmentDate!.year,
            _appointmentDate!.month,
            _appointmentDate!.day,
            selectedTime.hour,
            selectedTime.minute,
          );
          formattedAppointmentDate = appointmentDateTime.toIso8601String();
        } catch (e) {
          formattedAppointmentDate = null;
        }
      }
      
      final registrationDto = RegistrationDto(
        firstName: _firstNameController.text.trim(),
        middleName: _middleNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        phone: _phoneController.text.trim(),
        email: _emailController.text.trim(),
        address: _addressController.text.trim(),
        role: _role.name,
        phoneVerificationToken: _phoneVerificationToken,
        miningUnitId: _role == UserRole.miner ? finalMiningUnitId : null,
        clientDocumentBase64: _clientDocumentFile?.bytes != null ? base64Encode(_clientDocumentFile!.bytes!) : null,
        clientDocumentName: _clientDocumentFile?.name,
        resumeBase64: _resumeFile?.bytes != null ? base64Encode(_resumeFile!.bytes!) : null,
        resumeName: _resumeFile?.name,
        appointmentDate: formattedAppointmentDate,
        availabilityId: _selectedAvailabilityId,
      );

      final result = await service.register(registrationDto);

      if (!mounted) return;
      setState(() => _isSubmitting = false);

      result.fold(
        (failure) {
          _showTopNotification(context, failure.message, isError: true);
        },
        (userDto) {
          _showTopNotification(context, 'Registered successfully. Wait for the admin response', isError: false);
          Navigator.of(context).pop();
        },
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      _showTopNotification(context, 'Registration failed: ${e.toString().replaceAll("Exception: ", "")}', isError: true);
    }
  }

  void _showTopNotification(BuildContext context, String message, {bool isError = true}) {
    final overlay = Overlay.of(context);
    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).padding.top + 16,
        left: 16,
        right: 16,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: isError ? const Color(0xFFE53935) : const Color(0xFF2E7D32),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(
                  isError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
                  color: Colors.white,
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    message,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () {
                    if (overlayEntry.mounted) {
                      overlayEntry.remove();
                    }
                  },
                  child: const Icon(Icons.close_rounded, color: Colors.white, size: 18),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    overlay.insert(overlayEntry);

    Future.delayed(const Duration(seconds: 4), () {
      if (overlayEntry.mounted) {
        overlayEntry.remove();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      color: context.surfaceColor.withValues(alpha: 0.4),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'START YOUR APPLICATION',
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
                    color: kGold.withValues(alpha: 0.7),
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
                  textCapitalization: TextCapitalization.words,
                  capitalizeFirstLetter: true,
                  validator: (v) => _nameValidator(v, 'first name'),
                ),
                const SizedBox(height: 18),

                _buildLabel('Middle Name (optional)'),
                const SizedBox(height: 8),
                _buildTextField(
                  context,
                  controller: _middleNameController,
                  hint: 'Enter your middle name',
                  icon: Icons.badge_outlined,
                  textCapitalization: TextCapitalization.words,
                  capitalizeFirstLetter: true,
                  validator: (v) => _nameValidator(
                    v,
                    'middle name',
                    required: false,
                  ),
                ),
                const SizedBox(height: 18),

                _buildLabel('Last Name'),
                const SizedBox(height: 8),
                _buildTextField(
                  context,
                  controller: _lastNameController,
                  hint: 'Enter your last name',
                  icon: Icons.badge_outlined,
                  textCapitalization: TextCapitalization.words,
                  capitalizeFirstLetter: true,
                  validator: (v) => _nameValidator(v, 'last name'),
                ),
                const SizedBox(height: 18),

                _buildLabel('Phone Number'),
                const SizedBox(height: 8),
                _buildPhoneVerificationField(context),
                const SizedBox(height: 18),

                _buildLabel('Email Address'),
                const SizedBox(height: 8),
                _buildTextField(
                  context,
                  controller: _emailController,
                  hint: 'you@example.com',
                  icon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Email address is required';
                    }
                    final value = v.trim();
                    if (!RegExp(
                      r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$',
                    ).hasMatch(value)) {
                      return 'Enter a valid email address';
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

                // --- Miner-only fields: associated unit, business name, document ---
                if (_role == UserRole.miner) ...[
                  const SizedBox(height: 18),
                  _buildLabel('Associated Ball Mill / Processing Plant or Tunnel'),
                  const SizedBox(height: 8),
                  _buildMiningUnitSelector(context),

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

                  const SizedBox(height: 18),
                  _buildLabel('Appointment / Schedule Date'),
                  const SizedBox(height: 8),
                  _isLoadingSlots
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(16.0),
                            child: CircularProgressIndicator(color: kGold),
                          ),
                        )
                      : _buildAppointmentDatePicker(context),
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
                  _buildLabel('Interview Appointment Date'),
                  const SizedBox(height: 8),
                  _isLoadingSlots
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(16.0),
                            child: CircularProgressIndicator(color: kGold),
                          ),
                        )
                      : _buildAppointmentDatePicker(context),
                ],

                const SizedBox(height: 26),

                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _handleRegister,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kGold,
                      disabledBackgroundColor: kGold.withValues(alpha: 0.6),
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
            role: UserRole.miner,
            label: 'Miner',
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
          color: isSelected ? kGold.withValues(alpha: 0.15) : context.surfaceColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? kGold : kGold.withValues(alpha: 0.25),
            width: isSelected ? 1.6 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? kGold : kGold.withValues(alpha: 0.6),
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

  Widget _buildMiningUnitSelector(BuildContext context) {
    // Filter logic for suggestions
    final query = _miningUnitController.text.toLowerCase();
    
    // We check if query is not empty to show recommendations
    final suggestions = query.isEmpty 
        ? [] 
        : _miningUnits.where((u) {
            final name = u['name']?.toString().toLowerCase() ?? '';
            return name.contains(query);
          }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _miningUnitController,
          style: TextStyle(color: context.textColor),
          cursorColor: kGold,
          decoration: InputDecoration(
            hintText: 'Enter mill, plant, or tunnel name',
            hintStyle: TextStyle(color: context.mutedTextColor),
            prefixIcon: Icon(Icons.foundation_outlined, color: kGold.withValues(alpha: 0.8)),
            filled: true,
            fillColor: context.surfaceColor,
            contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: kGold.withValues(alpha: 0.25)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: kGold.withValues(alpha: 0.25)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: kGold, width: 1.6),
            ),
          ),
          onChanged: (val) {
            setState(() {
              _selectedMiningUnitId = null; 
              _miningUnitError = null;
            });
          },
        ),
        if (suggestions.isNotEmpty && _selectedMiningUnitId == null) ...[
          const SizedBox(height: 4),
          Container(
            constraints: const BoxConstraints(maxHeight: 200),
            decoration: BoxDecoration(
              color: context.surfaceColor,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: kGold.withValues(alpha: 0.3)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: ListView.separated(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: suggestions.length,
                separatorBuilder: (_, __) => Divider(height: 1, color: kGold.withOpacity(0.1)),
                itemBuilder: (context, index) {
                  final unit = suggestions[index];
                  return ListTile(
                    dense: true,
                    visualDensity: VisualDensity.compact,
                    title: Text(
                      unit['name'] ?? '', 
                      style: TextStyle(color: context.textColor, fontSize: 13, fontWeight: FontWeight.w600)
                    ),
                    subtitle: Text(
                      unit['type'] ?? 'Mining Unit', 
                      style: TextStyle(color: context.mutedTextColor, fontSize: 11)
                    ),
                    trailing: const Icon(Icons.north_west_rounded, size: 14, color: kGold),
                    onTap: () {
                      setState(() {
                        _miningUnitController.text = unit['name'] ?? '';
                        _selectedMiningUnitId = unit['id']?.toString();
                      });
                      FocusScope.of(context).unfocus();
                    },
                  );
                },
              ),
            ),
          ),
        ],
        if (_miningUnitError != null)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 4),
            child: Text(
              _miningUnitError!,
              style: const TextStyle(color: Colors.redAccent, fontSize: 12),
            ),
          ),
        if (_miningUnitController.text.isNotEmpty && suggestions.isEmpty && _selectedMiningUnitId == null)
          Padding(
            padding: const EdgeInsets.only(top: 8, left: 4),
            child: Row(
              children: [
                const Icon(Icons.add_circle_outline_rounded, size: 14, color: kGold),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'New unit "${_miningUnitController.text}" will be created upon signup.',
                    style: TextStyle(color: kGold.withValues(alpha: 0.8), fontSize: 11, fontStyle: FontStyle.italic),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  /// Phone number field with an inline "Verify" / OTP confirmation flow.
  Widget _buildPhoneVerificationField(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextFormField(
                controller: _phoneController,
                enabled: !_isPhoneVerified,
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(11),
                ],
                style: TextStyle(color: context.textColor),
                cursorColor: kGold,
                validator: (v) {
                  final formatError = _phoneFormatValidator(v);
                  if (formatError != null) return formatError;
                  if (!_isPhoneVerified) {
                    return 'Please verify your phone number';
                  }
                  return null;
                },
                decoration: InputDecoration(
                  hintText: 'e.g. 09XXXXXXXXX',
                  hintStyle: TextStyle(color: context.mutedTextColor),
                  prefixIcon:
                      Icon(Icons.phone_outlined, color: kGold.withValues(alpha: 0.8)),
                  suffixIcon: _isPhoneVerified
                      ? Icon(Icons.verified, color: Colors.green.shade400)
                      : null,
                  filled: true,
                  fillColor: context.surfaceColor,
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: kGold.withValues(alpha: 0.25)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: kGold.withValues(alpha: 0.25)),
                  ),
                  disabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: kGold.withValues(alpha: 0.15)),
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
            ),
            const SizedBox(width: 10),
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed:
                    (_isPhoneVerified || _isSendingOtp) ? null : _sendOtp,
                style: ElevatedButton.styleFrom(
                  backgroundColor: kGold,
                  disabledBackgroundColor: kGold.withValues(alpha: 0.4),
                  foregroundColor: kBlack,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                ),
                child: _isSendingOtp
                    ? SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          valueColor: AlwaysStoppedAnimation<Color>(kBlack),
                        ),
                      )
                    : Text(
                        _isPhoneVerified
                            ? 'Verified'
                            : (_otpSent ? 'Resend' : 'Verify'),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
              ),
            ),
          ],
        ),

          // --- OTP entry, shown after a code has been sent ---
        if (_otpSent && !_isPhoneVerified) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _otpController,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  style: TextStyle(color: context.textColor, letterSpacing: 4),
                  cursorColor: kGold,
                  decoration: InputDecoration(
                    counterText: '',
                    hintText: 'Enter 6-digit code',
                    hintStyle: TextStyle(color: context.mutedTextColor),
                    prefixIcon:
                        Icon(Icons.sms_outlined, color: kGold.withValues(alpha: 0.8)),
                    filled: true,
                    fillColor: context.surfaceColor,
                    contentPadding: const EdgeInsets.symmetric(
                        vertical: 14, horizontal: 16),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: kGold.withValues(alpha: 0.25)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: kGold.withValues(alpha: 0.25)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: kGold, width: 1.6),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: _isVerifyingOtp ? null : _verifyOtp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kGold,
                    disabledBackgroundColor: kGold.withValues(alpha: 0.4),
                    foregroundColor: kBlack,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                  ),
                  child: _isVerifyingOtp
                      ? SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.0,
                            valueColor: AlwaysStoppedAnimation<Color>(kBlack),
                          ),
                        )
                      : const Text(
                          'Confirm',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'This number will also receive your '
            'temporary password once your application is approved — '
            'you\'ll be asked to change the password after logging in.',
            style: TextStyle(color: context.mutedTextColor, fontSize: 11.5),
          ),
        ],

        // --- Verified status ---
        if (_isPhoneVerified) ...[
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.check_circle, size: 14, color: Colors.green.shade400),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                      'Verified. Your temporary password will '
                  'be sent to this number.',
                  style: TextStyle(color: Colors.green.shade400, fontSize: 11.5),
                ),
              ),
              TextButton(
                onPressed: _resetPhoneVerification,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 0),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  'Change',
                  style: TextStyle(
                    color: kGold,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],

        if (_phoneVerifyError != null) ...[
          const SizedBox(height: 6),
          Text(
            _phoneVerifyError!,
            style: const TextStyle(color: Colors.redAccent, fontSize: 12),
          ),
        ],
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
                    : kGold.withValues(alpha: 0.25),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.upload_file_outlined, color: kGold.withValues(alpha: 0.8)),
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
                    icon: Icon(Icons.close, color: kGold.withValues(alpha: 0.7)),
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
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final firstAllowedMonth = DateTime(now.year, now.month);
    // Filter available slots for the chosen month and year
    final List<Map<String, String>> chosenMonthSlots = _availableSlots.where((slot) {
      try {
        final date = DateFormat('yyyy-MM-dd').parse(slot['date']!);
        return !date.isBefore(todayStart) &&
            date.year == _viewingDate.year && date.month == _viewingDate.month;
      } catch (e) {
        return false;
      }
    }).toList();

    // Calendar logic for the chosen month
    final firstDay = DateTime(_viewingDate.year, _viewingDate.month, 1);
    final daysInMonth = DateTime(_viewingDate.year, _viewingDate.month + 1, 0).day;
    final offset = firstDay.weekday % 7; // 0 = Sunday, 1 = Monday...

    final currentYear = now.year;
    final isAtFirstAllowedMonth = _viewingDate.year == firstAllowedMonth.year &&
        _viewingDate.month == firstAllowedMonth.month;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Month and Year Selector Controls
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: context.surfaceColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: kGold.withValues(alpha: 0.25)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: Icon(Icons.chevron_left, color: isAtFirstAllowedMonth ? context.mutedTextColor : kGold),
                onPressed: isAtFirstAllowedMonth ? null : () {
                  setState(() {
                    _viewingDate = DateTime(_viewingDate.year, _viewingDate.month - 1);
                  });
                },
                tooltip: 'Previous Month',
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Month Dropdown
                  DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      value: _viewingDate.month,
                      dropdownColor: context.surfaceColor,
                      icon: const Icon(Icons.arrow_drop_down, color: kGold, size: 20),
                      style: TextStyle(
                        color: context.textColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      items: List.generate(_viewingDate.year == currentYear ? 13 - now.month : 12, (index) {
                        final monthNum = (_viewingDate.year == currentYear ? now.month : 1) + index;
                        final monthName = DateFormat('MMMM').format(DateTime(2025, monthNum));
                        return DropdownMenuItem<int>(
                          value: monthNum,
                          child: Text(
                            monthName,
                            style: TextStyle(color: context.textColor, fontWeight: FontWeight.bold),
                          ),
                        );
                      }),
                      onChanged: (newMonth) {
                        if (newMonth != null) {
                          setState(() {
                            _viewingDate = DateTime(_viewingDate.year, newMonth);
                          });
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Year Dropdown
                  DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      value: _viewingDate.year,
                      dropdownColor: context.surfaceColor,
                      icon: const Icon(Icons.arrow_drop_down, color: kGold, size: 20),
                      style: TextStyle(
                        color: context.textColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      items: List.generate(10, (index) {
                        final yearVal = currentYear + index;
                        return DropdownMenuItem<int>(
                          value: yearVal,
                          child: Text(
                            yearVal.toString(),
                            style: TextStyle(color: context.textColor, fontWeight: FontWeight.bold),
                          ),
                        );
                      }),
                      onChanged: (newYear) {
                        if (newYear != null) {
                          setState(() {
                            _viewingDate = DateTime(newYear, _viewingDate.month);
                          });
                        }
                      },
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right, color: kGold),
                onPressed: () {
                  setState(() {
                    _viewingDate = DateTime(_viewingDate.year, _viewingDate.month + 1);
                  });
                },
                tooltip: 'Next Month',
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Day labels
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: ['S', 'M', 'T', 'W', 'T', 'F', 'S']
              .map((d) => SizedBox(
                    width: 40,
                    child: Text(
                      d,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: kGold.withValues(alpha: 0.5),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ))
              .toList(),
        ),
        const SizedBox(height: 8),
        // Full Calendar Grid for all days of the chosen month
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
          ),
          itemCount: daysInMonth + offset,
          itemBuilder: (context, index) {
            if (index < offset) return const SizedBox.shrink();

            final day = index - offset + 1;
            final currentDate = DateTime(_viewingDate.year, _viewingDate.month, day);
            final dateStr = DateFormat('yyyy-MM-dd').format(currentDate);

            final now = DateTime.now();
            final todayStart = DateTime(now.year, now.month, now.day);
            final isPast = currentDate.isBefore(todayStart);

            final slot = chosenMonthSlots.firstWhere(
              (s) => s['date'] == dateStr,
              orElse: () => {},
            );
            final bool isAvailable = slot.isNotEmpty && !isPast;
            final bool isSelected = _appointmentDate != null &&
                DateFormat('yyyy-MM-dd').format(_appointmentDate!) == dateStr;
            final bool isToday = DateFormat('yyyy-MM-dd').format(now) == dateStr;

            return InkWell(
              onTap: isAvailable
                  ? () => setState(() {
                        _appointmentDate = currentDate;
                        _selectedTime = null;
                        _selectedStartTime = null;
                        _selectedAvailabilityId = null;
                        _appointmentError = null;
                      })
                  : null,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                decoration: BoxDecoration(
                  color: isSelected
                      ? kGold
                      : (isAvailable
                          ? kGold.withValues(alpha: 0.15)
                          : Colors.transparent),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected
                        ? kGold
                        : (isToday
                            ? kGold.withValues(alpha: 0.8)
                            : (isAvailable
                                ? kGold.withValues(alpha: 0.4)
                                : context.textColor.withValues(alpha: 0.08))),
                    width: isToday || isSelected ? 1.5 : 1,
                  ),
                ),
                child: Center(
                  child: Text(
                    day.toString(),
                    style: TextStyle(
                      color: isSelected
                          ? kBlack
                          : (isAvailable
                              ? context.textColor
                              : context.mutedTextColor.withValues(alpha: 0.25)),
                      fontWeight: (isAvailable || isToday) ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        if (chosenMonthSlots.isEmpty) ...[
          const SizedBox(height: 12),
          Center(
            child: Text(
              'No open interview times for ${DateFormat('MMMM yyyy').format(_viewingDate)}.',
              style: TextStyle(color: context.mutedTextColor, fontStyle: FontStyle.italic, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ),
        ],
        const SizedBox(height: 20),
        // Time Slots
        if (_appointmentDate != null &&
            _appointmentDate!.year == _viewingDate.year &&
            _appointmentDate!.month == _viewingDate.month) ...[
          Builder(builder: (context) {
            final dateStr = DateFormat('yyyy-MM-dd').format(_appointmentDate!);
            final daySlots = chosenMonthSlots
                .where((s) => s['date'] == dateStr)
                .toList();

            if (daySlots.isEmpty) return const SizedBox.shrink();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildLabel('Available Time Slots'),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: daySlots.map((slotMap) {
                    final time = slotMap['time']!;
                    final startTime = slotMap['start_time']!;
                    final availId = slotMap['availability_id'];
                    final isSelected = _selectedTime == time;
                    return ChoiceChip(
                      label: Text(
                        time,
                        style: TextStyle(
                          color: isSelected ? kBlack : context.textColor,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          fontSize: 12,
                        ),
                      ),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          _selectedTime = selected ? time : null;
                          _selectedStartTime = selected ? startTime : null;
                          _selectedAvailabilityId = selected ? availId : null;
                          _appointmentError = null;
                        });
                      },
                      selectedColor: kGold,
                      backgroundColor: context.surfaceColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(
                          color: isSelected ? kGold : kGold.withValues(alpha: 0.3),
                        ),
                      ),
                      showCheckmark: false,
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),
              ],
            );
          }),
        ],
        // Selected Date Address Detail Card
        if (_appointmentDate != null && _selectedTime != null) ...[
          Builder(builder: (context) {
            final dateStr = DateFormat('yyyy-MM-dd').format(_appointmentDate!);
            final selectedSlot = chosenMonthSlots.firstWhere(
              (s) => s['date'] == dateStr && s['time'] == _selectedTime,
              orElse: () => {},
            );
            final addressText = selectedSlot['address'] ?? '';

            if (addressText.isEmpty) return const SizedBox.shrink();

            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: kGold.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: kGold.withValues(alpha: 0.3), width: 1.5),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: kGold.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.location_on, color: kGold, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'LOCATION & TIME',
                          style: TextStyle(
                            color: kGold.withValues(alpha: 0.8),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          addressText,
                          style: TextStyle(
                            color: context.textColor,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${DateFormat('EEEE, MMMM d, yyyy').format(_appointmentDate!)} at $_selectedTime',
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
            );
          }),
        ],
        if (_appointmentError != null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.redAccent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              _appointmentError!,
              style: const TextStyle(color: Colors.redAccent, fontSize: 12),
            ),
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
        void Function(String)? onChanged,
        String? Function(String?)? validator,
        TextCapitalization textCapitalization = TextCapitalization.none,
        bool capitalizeFirstLetter = false,
      }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      maxLines: obscureText ? 1 : maxLines,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      validator: validator,
      style: TextStyle(color: context.textColor),
      cursorColor: kGold,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: context.mutedTextColor),
        prefixIcon: Icon(icon, color: kGold.withValues(alpha: 0.8)),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: context.surfaceColor,
        contentPadding:
        const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: kGold.withValues(alpha: 0.25)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: kGold.withValues(alpha: 0.25)),
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
      onChanged: onChanged ??
          (capitalizeFirstLetter
              ? (value) => _capitalizeFirstLetter(controller, value)
              : null),
    );
  }

  void _capitalizeFirstLetter(TextEditingController controller, String value) {
    if (value.isEmpty) return;
    final capitalized = value[0].toUpperCase() + value.substring(1);
    if (capitalized == value) return;

    final selectionOffset = controller.selection.extentOffset;
    controller.value = controller.value.copyWith(
      text: capitalized,
      selection: TextSelection.collapsed(
        offset: selectionOffset.clamp(0, capitalized.length),
      ),
    );
  }
}
