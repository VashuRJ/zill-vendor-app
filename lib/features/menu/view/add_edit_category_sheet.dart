import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../viewmodel/menu_viewmodel.dart';

class AddEditCategorySheet extends StatefulWidget {
  final MenuCategory? category;
  const AddEditCategorySheet({super.key, this.category});

  bool get isEditing => category != null;

  @override
  State<AddEditCategorySheet> createState() => _AddEditCategorySheetState();
}

class _AddEditCategorySheetState extends State<AddEditCategorySheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _descCtrl;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.category?.name ?? '');
    _descCtrl =
        TextEditingController(text: widget.category?.description ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final isEdit = widget.isEditing;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.65,
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
                  child: Icon(
                    isEdit
                        ? Icons.edit_rounded
                        : Icons.add_circle_outline_rounded,
                    size: 20,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isEdit ? 'Edit Category' : 'New Category',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        isEdit
                            ? 'Update the category details'
                            : 'Create a new menu category',
                        style: const TextStyle(
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
                    // Name
                    const Text(
                      'Category Name',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _nameCtrl,
                      textCapitalization: TextCapitalization.words,
                      decoration: _inputDecoration(
                        hint: 'e.g. Starters, Main Course, Beverages',
                        prefix: Icons.category_rounded,
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Category name is required'
                          : null,
                    ),
                    const SizedBox(height: 16),

                    // Description
                    const Text(
                      'Description (optional)',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _descCtrl,
                      textCapitalization: TextCapitalization.sentences,
                      maxLines: 3,
                      minLines: 2,
                      decoration: _inputDecoration(
                        hint: 'Brief description of this category...',
                        prefix: Icons.description_outlined,
                        alignTop: true,
                      ),
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
                            : Text(
                                isEdit ? 'Update Category' : 'Create Category',
                                style: const TextStyle(
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
            ? const EdgeInsets.only(bottom: 36)
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

    final vm = context.read<MenuViewModel>();
    final name = _nameCtrl.text.trim();
    final desc = _descCtrl.text.trim();
    final bool success;

    if (widget.isEditing) {
      success = await vm.updateCategory(
        widget.category!.id,
        name: name,
        description: desc,
      );
    } else {
      success = await vm.createCategory(name: name, description: desc);
    }

    if (!mounted) return;

    setState(() => _submitting = false);

    if (success) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.isEditing
                ? 'Category updated successfully!'
                : 'Category created successfully!',
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.success,
        ),
      );
    } else {
      final error = vm.error ?? 'Something went wrong';
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
