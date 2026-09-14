import 'package:flutter/material.dart';
import '../../domain/entities/registration_enums.dart';
import '../../infrastructure/repositories/supabase_user_repository.dart';
import '../shared_widgets/appColor.dart';
import '../shared_widgets/adminDrawer.dart';
import '../shared_widgets/themeToggleButton.dart';

class AddMinerPage extends StatefulWidget {
  const AddMinerPage({super.key});

  @override
  State<AddMinerPage> createState() => _AddMinerPageState();
}

class _AddMinerPageState extends State<AddMinerPage> {
  final _formKey = GlobalKey<FormState>();
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _repository = SupabaseUserRepository();

  final _firstNameController = TextEditingController();
  final _middleNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();

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

    if (_selectedRole == UserRole.miner && _selectedMiningUnitId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an associated mining unit'), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final result = await _repository.addUserByAdmin(
      firstName: _firstNameController.text.trim(),
      middleName: _middleNameController.text.trim(),
      lastName: _lastNameController.text.trim(),
      phone: _phoneController.text.trim(),
      email: _emailController.text.trim(),
      address: _addressController.text.trim(),
      role: _selectedRole,
      miningUnitId: _selectedRole == UserRole.miner ? _selectedMiningUnitId : null,
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
      key: _scaffoldKey,
      backgroundColor: context.bgColor,
      appBar: AppBar(
        backgroundColor: context.surfaceColor,
        elevation: 0,
        leadingWidth: 64,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16),
          child: _buildLogoMark(context),
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
          IconButton(
            icon: const Icon(Icons.menu_rounded, color: kGold),
            onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
          ),
        ],
      ),
      endDrawer: const AdminDrawer(currentMenu: AdminMenu.addMiner),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Register New Miner or Operator',
                style: TextStyle(
                  color: context.textColor,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Add a user directly to the system. They will receive their login details via SMS.',
                style: TextStyle(color: context.mutedTextColor, fontSize: 14),
              ),
              const SizedBox(height: 32),

              _buildLabel('Account Role'),
              const SizedBox(height: 8),
              _buildRoleDropdown(context),
              const SizedBox(height: 20),

              if (_selectedRole == UserRole.miner) ...[
                _buildLabel('Associated Ball Mill / Plant / Tunnel'),
                const SizedBox(height: 8),
                _buildMiningUnitDropdown(context),
                const SizedBox(height: 20),
              ],

              _buildLabel('First Name'),
              const SizedBox(height: 8),
              _buildTextField(
                context,
                controller: _firstNameController,
                hint: 'Enter first name',
                icon: Icons.person_outline,
                validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 20),

              _buildLabel('Middle Name (Optional)'),
              const SizedBox(height: 8),
              _buildTextField(
                context,
                controller: _middleNameController,
                hint: 'Enter middle name',
                icon: Icons.person_outline,
              ),
              const SizedBox(height: 20),

              _buildLabel('Last Name'),
              const SizedBox(height: 8),
              _buildTextField(
                context,
                controller: _lastNameController,
                hint: 'Enter last name',
                icon: Icons.person_outline,
                validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 20),

              _buildLabel('Phone Number'),
              const SizedBox(height: 8),
              _buildTextField(
                context,
                controller: _phoneController,
                hint: 'e.g. 09XXXXXXXXX',
                icon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
                validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 20),

              _buildLabel('Email (Gmail)'),
              const SizedBox(height: 8),
              _buildTextField(
                context,
                controller: _emailController,
                hint: 'example@gmail.com',
                icon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Required';
                  if (!v.contains('@gmail.com')) return 'Must be a @gmail.com address';
                  return null;
                },
              ),
              const SizedBox(height: 20),

              _buildLabel('Home Address'),
              const SizedBox(height: 8),
              _buildTextField(
                context,
                controller: _addressController,
                hint: 'Enter complete address',
                icon: Icons.home_outlined,
                maxLines: 2,
                validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 40),

              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _handleSubmit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kGold,
                    foregroundColor: kBlack,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: kBlack))
                      : Text('REGISTER ${_selectedRole.name.toUpperCase()}', style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
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

  Widget _buildMiningUnitDropdown(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kGold.withOpacity(0.25)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedMiningUnitId,
          isExpanded: true,
          dropdownColor: context.surfaceColor,
          hint: Text(
            _isLoadingUnits ? 'Loading units...' : 'Select associated unit',
            style: TextStyle(color: context.mutedTextColor, fontSize: 14),
          ),
          icon: const Icon(Icons.arrow_drop_down, color: kGold),
          items: _miningUnits.map((unit) {
            return DropdownMenuItem<String>(
              value: unit['id'].toString(),
              child: Text(
                '${unit['name']} (${unit['type']})',
                style: TextStyle(color: context.textColor, fontSize: 14),
              ),
            );
          }).toList(),
          onChanged: _isLoadingUnits ? null : (newValue) {
            setState(() => _selectedMiningUnitId = newValue);
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
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: context.mutedTextColor),
        prefixIcon: Icon(icon, color: kGold.withOpacity(0.8)),
        filled: true,
        fillColor: context.surfaceColor,
        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: kGold.withOpacity(0.25))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: kGold.withOpacity(0.25))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kGold, width: 1.6)),
      ),
    );
  }

  Widget _buildLogoMark(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: kGold, width: 1.6),
        color: context.bgColor,
      ),
      child: const Icon(Icons.settings_input_component_rounded, color: kGold, size: 16),
    );
  }
}
