// ─────────────────────────────────────────
// Zill Restaurant Partner — Vendor App
// Author: Vashu Mogha (@Its-vashu)
// ─────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../viewmodel/profile_viewmodel.dart';
import 'location_picker_screen.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameCtrl;
  late final TextEditingController _ownerNameCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _addressCtrl;
  late final TextEditingController _descriptionCtrl;
  late final TextEditingController _cuisineCtrl;
  late final TextEditingController _prepTimeCtrl;
  late final TextEditingController _costForTwoCtrl;

  TimeOfDay? _openingTime;
  TimeOfDay? _closingTime;
  bool _isPureVeg = false;
  String _restaurantType = '';
  double? _latitude;
  double? _longitude;
  bool _saving = false;

  static const _restaurantTypes = [
    '',
    'restaurant',
    'cafe',
    'bakery',
    'cloud_kitchen',
    'dhaba',
    'food_truck',
    'sweet_shop',
    'bar',
    'pub',
    'fine_dining',
    'casual_dining',
    'fast_food',
    'qsr',
  ];

  @override
  void initState() {
    super.initState();
    final d = context.read<ProfileViewModel>().data;
    _nameCtrl = TextEditingController(text: d.storeName);
    _ownerNameCtrl = TextEditingController(text: d.ownerName);
    // Strip +91 prefix for display — we show it as a fixed prefix
    _phoneCtrl = TextEditingController(text: _stripCountryCode(d.phone));
    _emailCtrl = TextEditingController(text: d.email);
    _addressCtrl = TextEditingController(text: d.address);
    _descriptionCtrl = TextEditingController(text: d.description);
    _cuisineCtrl = TextEditingController(text: d.cuisineTypes);
    _prepTimeCtrl = TextEditingController(
      text: d.averagePrepTime > 0 ? d.averagePrepTime.toString() : '',
    );
    _costForTwoCtrl = TextEditingController(
      text: d.costForTwo > 0 ? d.costForTwo.toStringAsFixed(0) : '',
    );
    _openingTime = _parseTimeOfDay(d.openingTime);
    _closingTime = _parseTimeOfDay(d.closingTime);
    _isPureVeg = d.isPureVeg;
    _restaurantType = d.restaurantType;
    _latitude = d.latitude;
    _longitude = d.longitude;
  }

  /// Strip leading "+91" or "91" so the field only shows the 10-digit number.
  static String _stripCountryCode(String phone) {
    var p = phone.trim();
    if (p.startsWith('+91')) p = p.substring(3);
    if (p.startsWith('91') && p.length > 10) p = p.substring(2);
    return p.trim();
  }

  /// Prepend +91 if not already present.
  static String _withCountryCode(String phone) {
    final p = phone.trim();
    if (p.startsWith('+91')) return p;
    if (p.startsWith('91') && p.length > 10) return '+$p';
    return '+91$p';
  }

  TimeOfDay? _parseTimeOfDay(String time) {
    if (time.isEmpty) return null;
    try {
      final parts = time.split(':');
      return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    } catch (_) {
      return null;
    }
  }

  String _formatTimeOfDay(TimeOfDay t) {
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }

  String _displayTime(TimeOfDay t) {
    final hour = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final minute = t.minute.toString().padLeft(2, '0');
    final period = t.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  String _formatType(String type) {
    if (type.isEmpty) return 'Select Type';
    return type
        .replaceAll('_', ' ')
        .split(' ')
        .map((w) =>
            w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '')
        .join(' ');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _ownerNameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _addressCtrl.dispose();
    _descriptionCtrl.dispose();
    _cuisineCtrl.dispose();
    _prepTimeCtrl.dispose();
    _costForTwoCtrl.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final vm = context.read<ProfileViewModel>();
    await vm.fetchProfile();
    final d = vm.data;
    _nameCtrl.text = d.storeName;
    _ownerNameCtrl.text = d.ownerName;
    _phoneCtrl.text = _stripCountryCode(d.phone);
    _emailCtrl.text = d.email;
    _addressCtrl.text = d.address;
    _descriptionCtrl.text = d.description;
    _cuisineCtrl.text = d.cuisineTypes;
    _prepTimeCtrl.text =
        d.averagePrepTime > 0 ? d.averagePrepTime.toString() : '';
    _costForTwoCtrl.text =
        d.costForTwo > 0 ? d.costForTwo.toStringAsFixed(0) : '';
    setState(() {
      _openingTime = _parseTimeOfDay(d.openingTime);
      _closingTime = _parseTimeOfDay(d.closingTime);
      _isPureVeg = d.isPureVeg;
      _restaurantType = d.restaurantType;
      _latitude = d.latitude;
      _longitude = d.longitude;
    });
  }

  Future<void> _pickTime({required bool isOpening}) async {
    final initial = isOpening
        ? (_openingTime ?? const TimeOfDay(hour: 9, minute: 0))
        : (_closingTime ?? const TimeOfDay(hour: 22, minute: 0));
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme:
              Theme.of(context).colorScheme.copyWith(primary: AppColors.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        if (isOpening) {
          _openingTime = picked;
        } else {
          _closingTime = picked;
        }
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final vm = context.read<ProfileViewModel>();
    final success = await vm.updateProfile(
      name: _nameCtrl.text.trim(),
      ownerName: _ownerNameCtrl.text.trim(),
      phone: _withCountryCode(_phoneCtrl.text.trim()),
      email: _emailCtrl.text.trim(),
      address: _addressCtrl.text.trim(),
      description: _descriptionCtrl.text.trim(),
      cuisineTypes: _cuisineCtrl.text.trim(),
      averagePrepTime: int.tryParse(_prepTimeCtrl.text.trim()),
      openingTime:
          _openingTime != null ? _formatTimeOfDay(_openingTime!) : null,
      closingTime:
          _closingTime != null ? _formatTimeOfDay(_closingTime!) : null,
      restaurantType: _restaurantType,
      costForTwo: double.tryParse(_costForTwoCtrl.text.trim()),
      isPureVeg: _isPureVeg,
      latitude: _latitude,
      longitude: _longitude,
    );

    if (!mounted) return;
    setState(() => _saving = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'Profile updated successfully!'
              : vm.errorMessage ?? 'Failed to update profile.',
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: success ? AppColors.success : AppColors.error,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
    if (success) Navigator.pop(context);
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
                        strokeWidth: 2, color: Colors.white),
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
                // ── Basic Information ──────────────────────────────
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
                  controller: _ownerNameCtrl,
                  label: 'Owner / Merchant Name',
                  hint: 'Enter owner name',
                  icon: Icons.person_outline,
                ),
                const SizedBox(height: AppSizes.md),
                _buildField(
                  controller: _descriptionCtrl,
                  label: 'Description',
                  hint: 'Describe your restaurant',
                  icon: Icons.description_outlined,
                  maxLines: 3,
                ),
                const SizedBox(height: AppSizes.md),
                _buildDropdown(),
                const SizedBox(height: AppSizes.md),
                _buildField(
                  controller: _cuisineCtrl,
                  label: 'Cuisine Types',
                  hint: 'e.g. North Indian, Chinese, Italian',
                  icon: Icons.restaurant_outlined,
                ),
                const SizedBox(height: AppSizes.md),
                _buildField(
                  controller: _costForTwoCtrl,
                  label: 'Cost for Two (\u20B9)',
                  hint: 'e.g. 500',
                  icon: Icons.currency_rupee_outlined,
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: AppSizes.md),
                _buildSwitch(
                  'Pure Vegetarian',
                  Icons.eco_outlined,
                  _isPureVeg,
                  (v) => setState(() => _isPureVeg = v),
                ),

                // ── Contact Information ───────────────────────────
                const SizedBox(height: AppSizes.lg),
                _sectionHeader(
                    'Contact Information', Icons.contact_phone_outlined),
                const SizedBox(height: AppSizes.sm),
                _buildPhoneField(),
                const SizedBox(height: AppSizes.md),
                _buildField(
                  controller: _emailCtrl,
                  label: 'Email (optional)',
                  hint: 'e.g. restaurant@example.com',
                  icon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) {
                    if (v != null && v.trim().isNotEmpty) {
                      if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(v.trim())) {
                        return 'Enter a valid email';
                      }
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
                  maxLines: 4,
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'Address is required'
                      : null,
                ),
                const SizedBox(height: AppSizes.md),

                // ── Exact Map Location ──────────────────────────
                _buildMapLocationBlock(),

                // ── Operating Hours ───────────────────────────────
                const SizedBox(height: AppSizes.lg),
                _sectionHeader('Operating Hours', Icons.schedule_outlined),
                const SizedBox(height: AppSizes.sm),
                Row(
                  children: [
                    Expanded(
                      child: _buildTimePicker(
                        label: 'Opening Time',
                        value: _openingTime,
                        onTap: () => _pickTime(isOpening: true),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildTimePicker(
                        label: 'Closing Time',
                        value: _closingTime,
                        onTap: () => _pickTime(isOpening: false),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSizes.md),
                _buildField(
                  controller: _prepTimeCtrl,
                  label: 'Avg. Prep Time (minutes)',
                  hint: 'e.g. 30',
                  icon: Icons.timer_outlined,
                  keyboardType: TextInputType.number,
                ),

                // ── Save Button ───────────────────────────────────
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
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.save_outlined),
                    label: Text(_saving ? 'Saving...' : 'Save Changes'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppSizes.buttonRadius),
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
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  Widget _buildPhoneField() {
    return TextFormField(
      controller: _phoneCtrl,
      keyboardType: TextInputType.phone,
      maxLength: 10,
      validator: (v) {
        if (v == null || v.trim().isEmpty) return 'Phone is required';
        if (v.trim().length != 10) return 'Enter 10-digit number';
        return null;
      },
      decoration: InputDecoration(
        labelText: 'Phone Number',
        hintText: '98765 43210',
        counterText: '',
        prefixIcon: const Icon(Icons.phone_outlined, size: 20),
        prefixText: '+91 ',
        prefixStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
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
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  Widget _buildTimePicker({
    required String label,
    required TimeOfDay? value,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.access_time, size: 20),
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
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        child: Text(
          value != null ? _displayTime(value) : 'Tap to set',
          style: TextStyle(
            fontSize: 14,
            color: value != null ? AppColors.textPrimary : AppColors.textHint,
          ),
        ),
      ),
    );
  }

  Widget _buildDropdown() {
    return DropdownButtonFormField<String>(
      initialValue:
          _restaurantTypes.contains(_restaurantType) ? _restaurantType : '',
      onChanged: (v) => setState(() => _restaurantType = v ?? ''),
      decoration: InputDecoration(
        labelText: 'Restaurant Type',
        prefixIcon: const Icon(Icons.category_outlined, size: 20),
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
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      items: _restaurantTypes
          .map((t) => DropdownMenuItem(
                value: t,
                child: Text(_formatType(t)),
              ))
          .toList(),
    );
  }

  Future<void> _openMapPicker() async {
    final LatLng? initial = (_latitude != null && _longitude != null)
        ? LatLng(_latitude!, _longitude!)
        : null;

    final result = await Navigator.push<LatLng>(
      context,
      MaterialPageRoute(
        builder: (_) => LocationPickerScreen(initialPosition: initial),
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _latitude = result.latitude;
        _longitude = result.longitude;
      });
    }
  }

  Widget _buildMapLocationBlock() {
    final hasCoords = _latitude != null && _longitude != null;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primary.withAlpha(8),
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        border: Border.all(
          color: AppColors.primary.withAlpha(40),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.map_outlined, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              const Text(
                'Exact Map Location',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            hasCoords
                ? '${_latitude!.toStringAsFixed(6)}, ${_longitude!.toStringAsFixed(6)}'
                : 'Location not set — tap below to pin on map',
            style: TextStyle(
              fontSize: 12,
              color: hasCoords ? AppColors.textSecondary : AppColors.textHint,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _openMapPicker,
              icon: Icon(
                hasCoords ? Icons.edit_location_alt_outlined : Icons.add_location_alt_outlined,
                size: 18,
              ),
              label: Text(hasCoords ? 'Change on Map' : 'Set on Map'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSwitch(
      String label, IconData icon, bool value, ValueChanged<bool> onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: value ? const Color(0xFFF0FFF4) : AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        border: Border.all(
          color: value ? AppColors.success.withAlpha(80) : AppColors.borderLight,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: value
                  ? AppColors.success.withAlpha(25)
                  : AppColors.textHint.withAlpha(20),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              size: 18,
              color: value ? AppColors.success : AppColors.textHint,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: value ? AppColors.success : AppColors.textPrimary,
              ),
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeTrackColor: AppColors.success.withAlpha(180),
            activeThumbColor: AppColors.success,
          ),
        ],
      ),
    );
  }
}
