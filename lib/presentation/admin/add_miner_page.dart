import 'package:flutter/material.dart';
import '../../domain/entities/registration_enums.dart';
import '../../infrastructure/repositories/supabase_registration_repository.dart';
import '../../infrastructure/repositories/supabase_user_repository.dart';
import '../shared_widgets/appColor.dart';
import '../shared_widgets/themeToggleButton.dart';

class AddMinerPage extends StatefulWidget {
  const AddMinerPage({super.key});

  @override
  State<AddMinerPage> createState() => _AddMinerPageState();
}

class _AddMinerPageState extends State<AddMinerPage> {
  final _formKey = GlobalKey<FormState>();
  final _repository = SupabaseUserRepository();
  final _registrationRepository = SupabaseRegistrationRepository();

  final _firstNameController = TextEditingController();
  final _middleNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  final _miningUnitController = TextEditingController();

  UserRole _selectedRole = UserRole.miner;
  String? _selectedMiningUnitId;
  List<Map<String, dynamic>> _miningUnits = [];
  bool _isLoadingUnits = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _fetchMiningUnits();
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _middleNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _miningUnitController.dispose();
    super.dispose();
  }

  Future<void> _fetchMiningUnits() async {
    setState(() => _isLoadingUnits = true);
    final result = await _repository.getMiningUnits();
    result.fold(
      (failure) => setState(() => _isLoadingUnits = false),
      (units) => setState(() {
        _miningUnits = units;
        _isLoadingUnits = false;
      }),
    );
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedRole == UserRole.miner &&
        _miningUnitController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter an associated ball mill, plant, or tunnel'), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    String? miningUnitId = _selectedMiningUnitId;
    if (_selectedRole == UserRole.miner && miningUnitId == null) {
      final createResult = await _registrationRepository.createMiningUnit(
        _miningUnitController.text.trim(),
      );
      final createFailure = createResult.fold((failure) => failure, (_) => null);
      if (createFailure != null) {
        if (!mounted) return;
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not create associated unit: ${createFailure.message}'),
            backgroundColor: Colors.redAccent,
          ),
        );
        return;
      }
      miningUnitId = createResult.fold((_) => null, (id) => id);
    }

    final result = await _repository.addUserByAdmin(
      firstName: _firstNameController.text.trim(),
      middleName: _middleNameController.text.trim(),
      lastName: _lastNameController.text.trim(),
      phone: _phoneController.text.trim(),
      email: _emailController.text.trim(),
      address: _addressController.text.trim(),
      role: _selectedRole,
      miningUnitId: _selectedRole == UserRole.miner ? miningUnitId : null,
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    result.fold(
      (failure) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add user: ${failure.message}'),
            backgroundColor: Colors.redAccent,
          ),
        );
      },
      (_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${_selectedRole.name.toUpperCase()} added successfully! SMS sent with login details.'),
            backgroundColor: Colors.green,
          ),
        );
        _formKey.currentState!.reset();
        _firstNameController.clear();
        _middleNameController.clear();
        _lastNameController.clear();
        _phoneController.clear();
        _emailController.clear();
        _addressController.clear();
        _miningUnitController.clear();
        setState(() {
          _selectedRole = UserRole.miner;
          _selectedMiningUnitId = null;
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bgColor,
      appBar: AppBar(
        backgroundColor: context.surfaceColor,
        elevation: 0,
        leading: IconButton(
          tooltip: 'Back to user directory',
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back_rounded, color: kGold),
        ),
        title: const Text(
          'ADD MINER & OPERATOR',
          style: TextStyle(
            color: kGold,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
            fontSize: 16,
          ),
        ),
        iconTheme: const IconThemeData(color: kGold),
        actions: [
          const ThemeToggleButton(),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          kGold.withValues(alpha: 0.2),
                          context.surfaceColor,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: kGold.withValues(alpha: 0.28)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 54,
                          height: 54,
                          decoration: BoxDecoration(
                            color: kGold.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(Icons.person_add_alt_1_rounded, color: kGold, size: 28),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Add a team member',
                                style: TextStyle(
                                  color: context.textColor,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                'Create a miner or operator account. Login details will be sent by SMS.',
                                style: TextStyle(color: context.mutedTextColor, fontSize: 13, height: 1.4),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: context.surfaceColor,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: context.textColor.withValues(alpha: 0.08)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 24,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildSectionHeading(context, 'Account details', Icons.badge_outlined),
                        const SizedBox(height: 18),
                        _buildLabel('Account Role'),
                        const SizedBox(height: 8),
                        _buildRoleDropdown(context),
                        if (_selectedRole == UserRole.miner) ...[
                          const SizedBox(height: 20),
                          _buildLabel('Associated Ball Mill / Plant / Tunnel'),
                          const SizedBox(height: 8),
                          _buildMiningUnitSelector(context),
                        ],
                        const SizedBox(height: 24),
                        _buildSectionHeading(context, 'Personal information', Icons.person_outline_rounded),
                        const SizedBox(height: 18),
                        _buildLabel('First Name'),
                        const SizedBox(height: 8),
                        _buildTextField(
                          context,
                          controller: _firstNameController,
                          hint: 'Enter first name',
                          icon: Icons.person_outline,
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                        ),
                        const SizedBox(height: 18),
                        _buildLabel('Middle Name (Optional)'),
                        const SizedBox(height: 8),
                        _buildTextField(
                          context,
                          controller: _middleNameController,
                          hint: 'Enter middle name',
                          icon: Icons.person_outline,
                        ),
                        const SizedBox(height: 18),
                        _buildLabel('Last Name'),
                        const SizedBox(height: 8),
                        _buildTextField(
                          context,
                          controller: _lastNameController,
                          hint: 'Enter last name',
                          icon: Icons.person_outline,
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
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
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                        ),
                        const SizedBox(height: 18),
                        _buildLabel('Email (Gmail)'),
                        const SizedBox(height: 8),
                        _buildTextField(
                          context,
                          controller: _emailController,
                          hint: 'example@gmail.com',
                          icon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return 'Required';
                            if (!v.trim().toLowerCase().endsWith('@gmail.com')) {
                              return 'Must be a @gmail.com address';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 18),
                        _buildLabel('Home Address'),
                        const SizedBox(height: 8),
                        _buildTextField(
                          context,
                          controller: _addressController,
                          hint: 'Enter complete address',
                          icon: Icons.home_outlined,
                          maxLines: 2,
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                        ),
                        const SizedBox(height: 28),
                        SizedBox(
                          height: 54,
                          child: ElevatedButton.icon(
                            onPressed: _isSubmitting ? null : _handleSubmit,
                            icon: _isSubmitting
                                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: kBlack))
                                : const Icon(Icons.person_add_alt_1_rounded),
                            label: Text(
                              _isSubmitting ? 'Creating account...' : 'REGISTER ${_selectedRole.name.toUpperCase()}',
                              style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.8),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: kGold,
                              foregroundColor: kBlack,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeading(BuildContext context, String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: kGold, size: 19),
        const SizedBox(width: 9),
        Text(
          title,
          style: TextStyle(color: context.textColor, fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }

  Widget _buildMiningUnitSelector(BuildContext context) {
    final query = _miningUnitController.text.trim().toLowerCase();
    final suggestions = query.isEmpty || _selectedMiningUnitId != null
        ? <Map<String, dynamic>>[]
        : _miningUnits.where((unit) {
            final name = unit['name']?.toString().toLowerCase() ?? '';
            return name.contains(query);
          }).take(6).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          controller: _miningUnitController,
          enabled: !_isLoadingUnits && !_isSubmitting,
          style: TextStyle(color: context.textColor),
          cursorColor: kGold,
          textCapitalization: TextCapitalization.words,
          decoration: _fieldDecoration(
            context,
            hint: _isLoadingUnits ? 'Loading associated units...' : 'Type a mill, plant, or tunnel name',
            icon: Icons.factory_outlined,
          ),
          validator: (value) => _selectedRole == UserRole.miner &&
                  (value == null || value.trim().isEmpty)
              ? 'Enter or select an associated unit'
              : null,
          onChanged: (_) => setState(() => _selectedMiningUnitId = null),
        ),
        if (suggestions.isNotEmpty) ...[
          const SizedBox(height: 6),
          Container(
            constraints: const BoxConstraints(maxHeight: 220),
            decoration: BoxDecoration(
              color: context.surfaceColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: kGold.withValues(alpha: 0.3)),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 14, offset: const Offset(0, 5)),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: ListView.separated(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: suggestions.length,
                separatorBuilder: (_, __) => Divider(height: 1, color: kGold.withValues(alpha: 0.12)),
                itemBuilder: (context, index) {
                  final unit = suggestions[index];
                  return ListTile(
                    dense: true,
                    leading: const Icon(Icons.factory_outlined, color: kGold, size: 20),
                    title: Text(unit['name']?.toString() ?? '', style: TextStyle(color: context.textColor, fontWeight: FontWeight.w600)),
                    subtitle: Text(unit['type']?.toString() ?? 'Ball Mill', style: TextStyle(color: context.mutedTextColor, fontSize: 12)),
                    trailing: const Icon(Icons.north_west_rounded, color: kGold, size: 16),
                    onTap: () {
                      setState(() {
                        _miningUnitController.text = unit['name']?.toString() ?? '';
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
        if (query.isNotEmpty && suggestions.isEmpty && _selectedMiningUnitId == null)
          Padding(
            padding: const EdgeInsets.only(top: 9, left: 4),
            child: Row(
              children: [
                const Icon(Icons.add_circle_outline_rounded, color: kGold, size: 16),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    '"${_miningUnitController.text.trim()}" will be added as a new associated ball mill.',
                    style: TextStyle(color: context.mutedTextColor, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  InputDecoration _fieldDecoration(
    BuildContext context, {
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: context.mutedTextColor, fontSize: 13),
      prefixIcon: Icon(icon, color: kGold.withValues(alpha: 0.85), size: 20),
      filled: true,
      fillColor: context.bgColor.withValues(alpha: 0.5),
      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: kGold.withValues(alpha: 0.2))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: kGold.withValues(alpha: 0.2))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kGold, width: 1.5)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.redAccent)),
      focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.redAccent, width: 1.5)),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(color: kGold, fontSize: 13, fontWeight: FontWeight.w600),
    );
  }

  Widget _buildRoleDropdown(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kGold.withOpacity(0.25)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<UserRole>(
          value: _selectedRole,
          isExpanded: true,
          dropdownColor: context.surfaceColor,
          icon: const Icon(Icons.arrow_drop_down, color: kGold),
          items: [UserRole.miner, UserRole.operator].map((role) {
            return DropdownMenuItem(
              value: role,
              child: Text(
                role == UserRole.miner ? 'Miner / Client' : 'Operator',
                style: TextStyle(color: context.textColor, fontSize: 14),
              ),
            );
          }).toList(),
          onChanged: (v) {
            if (v != null) setState(() => _selectedRole = v);
          },
        ),
      ),
    );
  }

  Widget _buildTextField(
    BuildContext context, {
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      maxLines: maxLines,
      style: TextStyle(color: context.textColor),
      cursorColor: kGold,
      decoration: _fieldDecoration(context, hint: hint, icon: icon),
    );
  }

}
