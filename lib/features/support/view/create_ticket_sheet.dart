import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../viewmodel/ticket_viewmodel.dart';

class CreateTicketSheet extends StatefulWidget {
  const CreateTicketSheet({super.key});

  @override
  State<CreateTicketSheet> createState() => _CreateTicketSheetState();
}

class _CreateTicketSheetState extends State<CreateTicketSheet> {
  final _formKey = GlobalKey<FormState>();
  final _subjectCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  String _selectedCategory = 'order';
  bool _submitting = false;

  static const _categories = [
    ('order', 'Order Issue', Icons.receipt_long_rounded, AppColors.primary),
    ('payment', 'Payment Issue', Icons.payment_rounded, AppColors.success),
    ('refund', 'Refund Request', Icons.currency_exchange_rounded, AppColors.purple),
    ('delivery', 'Delivery Issue', Icons.delivery_dining_rounded, AppColors.info),
    ('app', 'App / Technical', Icons.phone_android_rounded, AppColors.error),
    ('other', 'Other', Icons.help_outline_rounded, AppColors.textHint),
  ];

  @override
  void dispose() {
    _subjectCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
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
                    Icons.add_circle_outline_rounded,
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
                        'Raise New Ticket',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        'Describe your issue and we\'ll get back to you',
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
              padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottomInset),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Category
                    const _FieldLabel(label: 'Category'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _categories.map((cat) {
                        final isSelected = _selectedCategory == cat.$1;
                        final color = cat.$4;
                        return GestureDetector(
                          onTap: () =>
                              setState(() => _selectedCategory = cat.$1),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? color.withAlpha(15)
                                  : AppColors.background,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isSelected
                                    ? color.withAlpha(80)
                                    : AppColors.borderLight,
                                width: isSelected ? 1.5 : 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  cat.$3,
                                  size: 16,
                                  color: isSelected
                                      ? color
                                      : AppColors.textHint,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  cat.$2,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: isSelected
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: isSelected
                                        ? color
                                        : AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),

                    // Subject
                    const _FieldLabel(label: 'Subject'),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _subjectCtrl,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: _inputDecoration(
                        hint: 'e.g. Payment not received for order #1234',
                        prefix: Icons.subject_rounded,
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),

                    // Description
                    const _FieldLabel(label: 'Description'),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _descCtrl,
                      textCapitalization: TextCapitalization.sentences,
                      maxLines: 5,
                      minLines: 4,
                      decoration: _inputDecoration(
                        hint:
                            'Describe your issue in detail so we can help you faster...',
                        prefix: Icons.description_outlined,
                        alignTop: true,
                      ),
                      validator: (v) => (v == null || v.trim().length < 10)
                          ? 'Please describe your issue (min 10 chars)'
                          : null,
                    ),
                    const SizedBox(height: 28),

                    // Submit
                    SizedBox(
                      width: double.infinity,
                      height: AppSizes.buttonHeight,
                      child: ElevatedButton(
                        onPressed: _submitting ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor:
                              AppColors.primary.withAlpha(120),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(AppSizes.buttonRadius),
                          ),
                        ),
                        child: _submitting
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Submit Ticket',
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

  InputDecoration _inputDecoration({
    required String hint,
    required IconData prefix,
    bool alignTop = false,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 14, color: AppColors.textHint),
      prefixIcon: Padding(
        padding: alignTop
            ? const EdgeInsets.only(bottom: 60)
            : EdgeInsets.zero,
        child: Icon(prefix, size: 18, color: AppColors.textHint),
      ),
      filled: true,
      fillColor: AppColors.background,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
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
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _submitting = true);

    final success = await context.read<TicketViewModel>().createTicket(
          subject: _subjectCtrl.text.trim(),
          description: _descCtrl.text.trim(),
          category: _selectedCategory,
        );

    if (!mounted) return;

    setState(() => _submitting = false);

    if (success) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ticket submitted successfully!'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.success,
        ),
      );
    } else {
      final error =
          context.read<TicketViewModel>().errorMessage ?? 'Failed to submit';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.error,
        ),
      );
    }
  }
}

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
