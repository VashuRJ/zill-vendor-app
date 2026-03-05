import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../viewmodel/promotions_viewmodel.dart';

class AddPromotionSheet extends StatefulWidget {
  const AddPromotionSheet({super.key});

  @override
  State<AddPromotionSheet> createState() => _AddPromotionSheetState();
}

class _AddPromotionSheetState extends State<AddPromotionSheet> {
  final _formKey = GlobalKey<FormState>();
  final _codeCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _discountCtrl = TextEditingController();
  final _maxDiscountCtrl = TextEditingController();
  final _minOrderCtrl = TextEditingController();
  final _usageLimitCtrl = TextEditingController(text: '100');
  DateTime _validFrom = DateTime.now();
  DateTime _validUntil = DateTime.now().add(const Duration(days: 30));

  @override
  void dispose() {
    _codeCtrl.dispose();
    _descCtrl.dispose();
    _discountCtrl.dispose();
    _maxDiscountCtrl.dispose();
    _minOrderCtrl.dispose();
    _usageLimitCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Handle ──────────────────────────────────────────────
          const SizedBox(height: 10),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.borderLight,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),

          // ── Header ──────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withAlpha(18),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.local_offer_rounded,
                    size: 20,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Create New Offer',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        'Set up a promotion for your customers',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textHint,
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.close_rounded,
                      size: 18,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: AppColors.borderLight),

          // ── Form ────────────────────────────────────────────────
          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                20,
                20,
                20,
                20 + bottomInset,
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Promo Code
                    _FieldLabel(label: 'Promo Code'),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _codeCtrl,
                      textCapitalization: TextCapitalization.characters,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'[A-Za-z0-9]'),
                        ),
                        LengthLimitingTextInputFormatter(15),
                      ],
                      decoration: _inputDecoration(
                        hint: 'e.g. FLAT50',
                        prefix: Icons.confirmation_number_outlined,
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),

                    // Description
                    _FieldLabel(label: 'Description'),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _descCtrl,
                      maxLength: 80,
                      decoration: _inputDecoration(
                        hint: 'e.g. 50% off on orders above \u20b9299',
                        prefix: Icons.description_outlined,
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 8),

                    // Discount + Max Discount (row)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _FieldLabel(label: 'Discount %'),
                              const SizedBox(height: 6),
                              TextFormField(
                                controller: _discountCtrl,
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  LengthLimitingTextInputFormatter(2),
                                ],
                                decoration: _inputDecoration(
                                  hint: 'e.g. 50',
                                  prefix: Icons.percent_rounded,
                                ),
                                validator: (v) {
                                  if (v == null || v.isEmpty) return 'Required';
                                  final n = int.tryParse(v);
                                  if (n == null || n < 1 || n > 99) {
                                    return '1-99';
                                  }
                                  return null;
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _FieldLabel(label: 'Max Discount (\u20b9)'),
                              const SizedBox(height: 6),
                              TextFormField(
                                controller: _maxDiscountCtrl,
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                                decoration: _inputDecoration(
                                  hint: 'e.g. 120',
                                  prefix: Icons.savings_outlined,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Min Order + Usage Limit (row)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _FieldLabel(label: 'Min Order (\u20b9)'),
                              const SizedBox(height: 6),
                              TextFormField(
                                controller: _minOrderCtrl,
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                                decoration: _inputDecoration(
                                  hint: 'e.g. 299',
                                  prefix: Icons.shopping_bag_outlined,
                                ),
                                validator: (v) =>
                                    (v == null || v.isEmpty) ? 'Required' : null,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _FieldLabel(label: 'Usage Limit'),
                              const SizedBox(height: 6),
                              TextFormField(
                                controller: _usageLimitCtrl,
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                                decoration: _inputDecoration(
                                  hint: '100',
                                  prefix: Icons.people_outline_rounded,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Date pickers
                    Row(
                      children: [
                        Expanded(
                          child: _DateField(
                            label: 'Valid From',
                            date: _validFrom,
                            onPick: () => _pickDate(isFrom: true),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _DateField(
                            label: 'Valid Until',
                            date: _validUntil,
                            onPick: () => _pickDate(isFrom: false),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),

                    // Submit
                    SizedBox(
                      width: double.infinity,
                      height: AppSizes.buttonHeight,
                      child: ElevatedButton(
                        onPressed: _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              AppSizes.buttonRadius,
                            ),
                          ),
                        ),
                        child: const Text(
                          'Create Promotion',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  InputDecoration _inputDecoration({
    required String hint,
    required IconData prefix,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(
        fontSize: 14,
        color: AppColors.textHint,
      ),
      prefixIcon: Icon(prefix, size: 18, color: AppColors.textHint),
      filled: true,
      fillColor: AppColors.background,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 13,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.borderLight),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.error),
      ),
      counterText: '',
    );
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: isFrom ? _validFrom : _validUntil,
      firstDate: now.subtract(const Duration(days: 7)),
      lastDate: now.add(const Duration(days: 365)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary: AppColors.primary,
            onSurface: AppColors.textPrimary,
          ),
        ),
        child: child!,
      ),
    );
    if (picked == null) return;
    setState(() {
      if (isFrom) {
        _validFrom = picked;
        if (_validUntil.isBefore(_validFrom)) {
          _validUntil = _validFrom.add(const Duration(days: 7));
        }
      } else {
        _validUntil = picked;
      }
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final vm = context.read<PromotionsViewModel>();
    final success = await vm.addPromo(
      code: _codeCtrl.text.trim(),
      description: _descCtrl.text.trim(),
      discountValue: double.parse(_discountCtrl.text),
      maxDiscount: _maxDiscountCtrl.text.isNotEmpty
          ? double.parse(_maxDiscountCtrl.text)
          : null,
      minOrderAmount: double.parse(_minOrderCtrl.text),
      validFrom: _validFrom,
      validUntil: _validUntil,
      usageLimit: _usageLimitCtrl.text.isNotEmpty
          ? int.parse(_usageLimitCtrl.text)
          : null,
    );

    if (!mounted) return;

    if (success) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Promotion created successfully!'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.success,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(vm.errorMessage ?? 'Failed to create promotion'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.error,
        ),
      );
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Small Widgets
// ─────────────────────────────────────────────────────────────────────────────

class _FieldLabel extends StatelessWidget {
  final String label;
  const _FieldLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppColors.textSecondary,
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  final String label;
  final DateTime date;
  final VoidCallback onPick;

  const _DateField({
    required this.label,
    required this.date,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final formatted = '${date.day} ${months[date.month - 1]} ${date.year}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(label: label),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: onPick,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 13,
            ),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.borderLight),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.calendar_today_rounded,
                  size: 15,
                  color: AppColors.textHint,
                ),
                const SizedBox(width: 8),
                Text(
                  formatted,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
