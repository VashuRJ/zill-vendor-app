import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../viewmodel/profile_viewmodel.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _addressCtrl;
  late final TextEditingController _descriptionCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final data = context.read<ProfileViewModel>().data;
    _nameCtrl = TextEditingController(text: data.storeName);
    _phoneCtrl = TextEditingController(text: data.phone);
    _emailCtrl = TextEditingController(text: data.email);
    _addressCtrl = TextEditingController(text: data.address);
    _descriptionCtrl = TextEditingController(text: data.description);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _addressCtrl.dispose();
    _descriptionCtrl.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final vm = context.read<ProfileViewModel>();
    await vm.fetchProfile();
    final d = vm.data;
    _nameCtrl.text = d.storeName;
    _phoneCtrl.text = d.phone;
    _emailCtrl.text = d.email;
    _addressCtrl.text = d.address;
    _descriptionCtrl.text = d.description;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final vm = context.read<ProfileViewModel>();
    final success = await vm.updateProfile(
      name: _nameCtrl.text.trim(),
      phone: _phoneCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
      address: _addressCtrl.text.trim(),
      description: _descriptionCtrl.text.trim(),
    );

    setState(() => _saving = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'Profile updated successfully!'
                : vm.errorMessage ?? 'Failed to update profile.',
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: success ? AppColors.success : AppColors.error,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
      if (success) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        actions: [
          TextButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.check, color: Colors.white),
            label: Text(
              _saving ? 'Saving...' : 'Save',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        color: AppColors.primary,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppSizes.md),
          child: Form(
            key: _formKey,
            child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionHeader('Basic Information', Icons.store_outlined),
              const SizedBox(height: AppSizes.sm),
              _buildField(
                controller: _nameCtrl,
                label: 'Restaurant Name',
                hint: 'Enter restaurant name',
                icon: Icons.store_outlined,
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Name is required' : null,
              ),
              const SizedBox(height: AppSizes.md),
              _buildField(
                controller: _descriptionCtrl,
                label: 'Description',
                hint: 'Describe your restaurant (cuisine, specialty, etc.)',
                icon: Icons.description_outlined,
                maxLines: 3,
              ),
              const SizedBox(height: AppSizes.lg),
              _sectionHeader(
                'Contact Information',
                Icons.contact_phone_outlined,
              ),
              const SizedBox(height: AppSizes.sm),
              _buildField(
                controller: _phoneCtrl,
                label: 'Phone Number',
                hint: 'e.g. +91 98765 43210',
                icon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Phone is required' : null,
              ),
              const SizedBox(height: AppSizes.md),
              _buildField(
                controller: _emailCtrl,
                label: 'Email',
                hint: 'e.g. restaurant@example.com',
                icon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Email is required';
                  if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(v.trim())) {
                    return 'Enter a valid email';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppSizes.md),
              _buildField(
                controller: _addressCtrl,
                label: 'Address',
                hint: 'Full restaurant address',
                icon: Icons.location_on_outlined,
                maxLines: 2,
                validator: (v) => v == null || v.trim().isEmpty
                    ? 'Address is required'
                    : null,
              ),
              const SizedBox(height: AppSizes.xl),
              SizedBox(
                width: double.infinity,
                height: AppSizes.buttonHeight,
                child: ElevatedButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.save_outlined),
                  label: Text(_saving ? 'Saving...' : 'Save Changes'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        AppSizes.buttonRadius,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSizes.lg),
            ],
          ),
        ),
      ),
      ),
    );
  }

  Widget _sectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: AppColors.primary.withAlpha(20),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: AppColors.primary),
        ),
        const SizedBox(width: 10),
        Text(
          title.toUpperCase(),
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
            color: AppColors.textHint,
          ),
        ),
      ],
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, size: 20),
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          borderSide: const BorderSide(color: AppColors.borderLight),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          borderSide: const BorderSide(color: AppColors.borderLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
    );
  }
}
