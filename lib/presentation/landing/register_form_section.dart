import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../shared_widgets/appColor.dart';

/// The two kinds of accounts this system supports.
enum UserRole { client, operator }

/// The kind of client account, only relevant when [UserRole.client] is
/// selected.
enum ClientType { individual, business }

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
  final _usernameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  final _businessNameController = TextEditingController();

  UserRole _role = UserRole.client;

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
  void dispose() {
    _firstNameController.dispose();
    _middleNameController.dispose();
    _lastNameController.dispose();
    _usernameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _businessNameController.dispose();
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

    // TODO: wire up to your real sign-up flow, e.g.:
    // final authService = AuthService(SupabaseAuthRepository());
    // final result = await authService.register(
    //   RegisterRequestDto(
    //     firstName: _firstNameController.text.trim(),
    //     middleName: _middleNameController.text.trim(),
    //     lastName: _lastNameController.text.trim(),
    //     username: _usernameController.text.trim(),
    //     phone: _phoneController.text.trim(),
    //     email: _emailController.text.trim(),
    //     address: _addressController.text.trim(),
    //     role: _role,
    //     clientType: _role == UserRole.client ? _clientType : null,
    //     businessName: _businessNameController.text.trim(),
    //     clientDocumentBytes: _clientDocumentFile?.bytes,
    //     clientDocumentFileName: _clientDocumentFile?.name,
    //     resumeBytes: _resumeFile?.bytes,
    //     resumeFileName: _resumeFile?.name,
    //     appointmentDate: _appointmentDate,
    //   ),
    // );
    await Future.delayed(const Duration(seconds: 1));

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_circle_outline, color: Colors.white),
            SizedBox(width: 12),
            Expanded(child: Text('Account created. You can now log in.')),
          ],
        ),
        backgroundColor: Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
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

                _buildLabel('Username'),
                const SizedBox(height: 8),
                _buildTextField(
                  context,
                  controller: _usernameController,
                  hint: 'Choose a username',
                  icon: Icons.alternate_email,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Username is required';
                    }
                    if (v.trim().length < 3) {
                      return 'Use at least 3 characters';
                    }
                    if (v.contains(' ')) {
                      return 'No spaces allowed';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 18),

                _buildLabel('Phone Number'),
                const SizedBox(height: 8),
                _buildTextField(
                  context,
                  controller: _phoneController,
                  hint: 'e.g. 09XXXXXXXXX',
                  icon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Phone number is required';
                    }
                    final digitsOnly = v.replaceAll(RegExp(r'[^0-9]'), '');
                    if (digitsOnly.length < 7) {
                      return 'Enter a valid phone number';
                    }
                    return null;
                  },
                ),
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