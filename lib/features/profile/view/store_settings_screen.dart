import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/routing/app_router.dart';
import '../viewmodel/profile_viewmodel.dart';

class StoreSettingsScreen extends StatefulWidget {
  const StoreSettingsScreen({super.key});

  @override
  State<StoreSettingsScreen> createState() => _StoreSettingsScreenState();
}

class _StoreSettingsScreenState extends State<StoreSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _deliveryFeeCtrl;
  late final TextEditingController _minOrderCtrl;
  late final TextEditingController _freeDeliveryAboveCtrl;
  late final TextEditingController _radiusCtrl;

  bool _populated = false;

  @override
  void initState() {
    super.initState();
    _deliveryFeeCtrl = TextEditingController();
    _minOrderCtrl = TextEditingController();
    _freeDeliveryAboveCtrl = TextEditingController();
    _radiusCtrl = TextEditingController();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProfileViewModel>().fetchStoreSettings();
    });
  }

  @override
  void dispose() {
    _deliveryFeeCtrl.dispose();
    _minOrderCtrl.dispose();
    _freeDeliveryAboveCtrl.dispose();
    _radiusCtrl.dispose();
    super.dispose();
  }

  void _populate(StoreSettingsData s) {
    if (_populated) return;
    _deliveryFeeCtrl.text = s.deliveryFee.toStringAsFixed(0);
    _minOrderCtrl.text = s.minimumOrderAmount.toStringAsFixed(0);
    _freeDeliveryAboveCtrl.text =
        s.freeDeliveryAbove != null && s.freeDeliveryAbove! > 0
            ? s.freeDeliveryAbove!.toStringAsFixed(0)
            : '';
    _radiusCtrl.text = s.deliveryRadiusKm.toStringAsFixed(1);
    _populated = true;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final vm = context.read<ProfileViewModel>();

    final success = await vm.updateStoreSettings(
      deliveryFee: double.parse(_deliveryFeeCtrl.text.trim()),
      minimumOrderAmount: double.parse(_minOrderCtrl.text.trim()),
      freeDeliveryAbove: _freeDeliveryAboveCtrl.text.trim().isEmpty
          ? null
          : double.parse(_freeDeliveryAboveCtrl.text.trim()),
      deliveryRadiusKm: double.parse(_radiusCtrl.text.trim()),
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                success ? Icons.check_circle_rounded : Icons.error_rounded,
                color: Colors.white,
                size: 18,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  success
                      ? 'Settings saved successfully!'
                      : vm.settingsError ?? 'Failed to save settings.',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: success ? AppColors.success : AppColors.error,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          margin: const EdgeInsets.all(AppSizes.md),
        ),
      );
      if (success) {
        _populated = false; // allow re-populate with fresh server data
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Store Settings',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20),
        ),
        centerTitle: true,
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.arrow_back_ios_new_rounded, size: 16),
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Consumer<ProfileViewModel>(
          builder: (context, vm, _) {
            if (vm.settingsStatus == SettingsStatus.loaded ||
                vm.settingsStatus == SettingsStatus.saving) {
              _populate(vm.settings);
            }

            return Column(
              children: [
                // Loading indicator
                if (vm.isSettingsLoading)
                  LinearProgressIndicator(
                    minHeight: 2,
                    backgroundColor: Colors.transparent,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      AppColors.primary,
                    ),
                  ),

                // Error banner
                if (vm.settingsStatus == SettingsStatus.error)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.symmetric(
                      horizontal: AppSizes.md,
                      vertical: AppSizes.sm,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.errorLight,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AppColors.error.withAlpha(40),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.wifi_off_rounded,
                          size: 16,
                          color: AppColors.error,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            vm.settingsError ?? 'Could not load settings.',
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: AppColors.error,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: vm.fetchStoreSettings,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.error.withAlpha(20),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'Retry',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.error,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Main content
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(
                      AppSizes.md,
                      AppSizes.sm,
                      AppSizes.md,
                      AppSizes.xl,
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── Quick Stats ──────────────────────
                          if (_populated) ...[
                            _QuickStats(settings: vm.settings),
                            const SizedBox(height: 24),
                          ],

                          // ── Delivery Pricing ─────────────────
                          _SectionHeader(
                            icon: Icons.delivery_dining_rounded,
                            iconColor: AppColors.primary,
                            iconBg: AppColors.primary.withAlpha(20),
                            title: 'Delivery Pricing',
                          ),
                          const SizedBox(height: 10),
                          _Card(
                            children: [
                              _FieldTile(
                                icon: Icons.currency_rupee_rounded,
                                iconColor: AppColors.success,
                                label: 'Base Delivery Fee',
                                description: 'Flat delivery charge per order',
                                child: _StyledField(
                                  controller: _deliveryFeeCtrl,
                                  hint: 'e.g. 30',
                                  prefix: '₹',
                                  validator: _requiredAmount,
                                ),
                              ),
                              _FieldTile(
                                icon: Icons.shopping_bag_rounded,
                                iconColor: const Color(0xFF6C5CE7),
                                label: 'Minimum Order',
                                description:
                                    'Minimum amount to place an order',
                                child: _StyledField(
                                  controller: _minOrderCtrl,
                                  hint: 'e.g. 100',
                                  prefix: '₹',
                                  validator: _requiredAmount,
                                ),
                              ),
                              _FieldTile(
                                icon: Icons.local_offer_rounded,
                                iconColor: AppColors.warning,
                                label: 'Free Delivery Above',
                                description: 'Waive fee for large orders',
                                isLast: true,
                                child: _StyledField(
                                  controller: _freeDeliveryAboveCtrl,
                                  hint: 'Leave empty to disable',
                                  prefix: '₹',
                                  validator: _optionalAmount,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 24),

                          // ── Delivery Zone ────────────────────
                          _SectionHeader(
                            icon: Icons.radar_rounded,
                            iconColor: AppColors.info,
                            iconBg: AppColors.info.withAlpha(20),
                            title: 'Delivery Zone',
                          ),
                          const SizedBox(height: 10),
                          _Card(
                            children: [
                              _FieldTile(
                                icon: Icons.my_location_rounded,
                                iconColor: AppColors.info,
                                label: 'Delivery Radius',
                                description:
                                    'Maximum distance for delivery',
                                isLast: true,
                                child: _StyledField(
                                  controller: _radiusCtrl,
                                  hint: 'e.g. 5',
                                  suffix: 'km',
                                  validator: _requiredPositive,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 16),

                          // ── Manage Delivery Zones Link ────────
                          GestureDetector(
                            onTap: () => Navigator.pushNamed(
                              context,
                              AppRouter.deliveryZones,
                            ),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(
                                  AppSizes.radiusMd,
                                ),
                                boxShadow: const [
                                  BoxShadow(
                                    color: AppColors.shadowLight,
                                    blurRadius: 10,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: AppColors.info.withAlpha(20),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(
                                      Icons.layers_rounded,
                                      size: 20,
                                      color: AppColors.info,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  const Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Manage Delivery Zones',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                        SizedBox(height: 2),
                                        Text(
                                          'Set up distance-based zones with custom fees & ETAs',
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(
                                    Icons.chevron_right_rounded,
                                    color: AppColors.textHint,
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 32),

                          // ── Save Button ──────────────────────
                          SizedBox(
                            width: double.infinity,
                            height: AppSizes.buttonHeight,
                            child: ElevatedButton(
                              onPressed:
                                  vm.isSettingsSaving ? null : _save,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                disabledBackgroundColor:
                                    AppColors.primary.withAlpha(120),
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    AppSizes.buttonRadius,
                                  ),
                                ),
                              ),
                              child: vm.isSettingsSaving
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.save_rounded,
                                          size: 20,
                                        ),
                                        SizedBox(width: 8),
                                        Text(
                                          'Save Settings',
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                          ),

                          const SizedBox(height: 16),

                          // ── Hint ─────────────────────────────
                          Center(
                            child: Text(
                              'Changes reflect instantly for new orders',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textHint,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // ── Validators ──────────────────────────────────────────────────────
  String? _requiredAmount(String? v) {
    if (v == null || v.trim().isEmpty) return 'Required';
    if (double.tryParse(v.trim()) == null) return 'Invalid amount';
    if (double.parse(v.trim()) < 0) return 'Must be 0 or more';
    return null;
  }

  String? _optionalAmount(String? v) {
    if (v == null || v.trim().isEmpty) return null;
    if (double.tryParse(v.trim()) == null) return 'Invalid amount';
    if (double.parse(v.trim()) <= 0) return 'Must be greater than 0';
    return null;
  }

  String? _requiredPositive(String? v) {
    if (v == null || v.trim().isEmpty) return 'Required';
    if (double.tryParse(v.trim()) == null) return 'Invalid value';
    if (double.parse(v.trim()) <= 0) return 'Must be greater than 0';
    return null;
  }
}

// ═══════════════════════════════════════════════════════════════════════
//  Quick Stats Row
// ═══════════════════════════════════════════════════════════════════════

class _QuickStats extends StatelessWidget {
  final StoreSettingsData settings;
  const _QuickStats({required this.settings});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _StatChip(
          icon: Icons.delivery_dining_rounded,
          color: AppColors.primary,
          label: 'Fee',
          value: '₹${settings.deliveryFee.toStringAsFixed(0)}',
        ),
        const SizedBox(width: 10),
        _StatChip(
          icon: Icons.shopping_bag_rounded,
          color: const Color(0xFF6C5CE7),
          label: 'Min Order',
          value: '₹${settings.minimumOrderAmount.toStringAsFixed(0)}',
        ),
        const SizedBox(width: 10),
        _StatChip(
          icon: Icons.radar_rounded,
          color: AppColors.info,
          label: 'Radius',
          value: '${settings.deliveryRadiusKm.toStringAsFixed(1)} km',
        ),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;

  const _StatChip({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          boxShadow: const [
            BoxShadow(
              color: AppColors.shadowLight,
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withAlpha(20),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textHint,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
//  Section Header
// ═══════════════════════════════════════════════════════════════════════

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;

  const _SectionHeader({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: iconBg,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: iconColor),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
//  Card Wrapper
// ═══════════════════════════════════════════════════════════════════════

class _Card extends StatelessWidget {
  final List<Widget> children;
  const _Card({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadowLight,
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: children,
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
//  Field Tile — icon + label + description + form field
// ═══════════════════════════════════════════════════════════════════════

class _FieldTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String description;
  final Widget child;
  final bool isLast;

  const _FieldTile({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.description,
    required this.child,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Label row with icon
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: iconColor.withAlpha(18),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, size: 16, color: iconColor),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          description,
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: AppColors.textHint,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Form field
              child,
            ],
          ),
        ),
        if (!isLast)
          const Divider(height: 1, thickness: 1, color: AppColors.borderLight),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
//  Styled Text Field
// ═══════════════════════════════════════════════════════════════════════

class _StyledField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final String? prefix;
  final String? suffix;
  final FormFieldValidator<String>? validator;

  const _StyledField({
    required this.controller,
    required this.hint,
    this.prefix,
    this.suffix,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      textInputAction: TextInputAction.next,
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
      ],
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          color: AppColors.textHint.withAlpha(150),
          fontWeight: FontWeight.w400,
          fontSize: 14,
        ),
        prefixText: prefix != null ? '$prefix ' : null,
        prefixStyle: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: AppColors.textSecondary,
        ),
        suffixText: suffix,
        suffixStyle: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.textHint,
        ),
        filled: true,
        fillColor: AppColors.background,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.error, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.error, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 13,
        ),
        errorStyle: const TextStyle(fontSize: 11),
      ),
      validator: validator,
    );
  }
}
