import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../viewmodel/menu_viewmodel.dart';

// ────────────────────────────────────────────────────────────────────
//  Add / Edit Menu Item Screen
// ────────────────────────────────────────────────────────────────────
class AddEditMenuScreen extends StatefulWidget {
  const AddEditMenuScreen({super.key, this.item});

  /// Pass an existing [MenuItem] to enter Edit mode; null = Add mode.
  final MenuItem? item;

  @override
  State<AddEditMenuScreen> createState() => _AddEditMenuScreenState();
}

class _AddEditMenuScreenState extends State<AddEditMenuScreen> {
  // ── Form ──────────────────────────────────────────────────────────
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _priceCtrl;
  late final TextEditingController _discPriceCtrl;
  late final TextEditingController _prepTimeCtrl;
  late final TextEditingController _servesCtrl;
  late final TextEditingController _caloriesCtrl;

  // ── Dropdowns / selectors ─────────────────────────────────────────
  int? _categoryId;
  String _spiceLevel = 'none';
  bool _isVeg = true;
  bool _isVegan = false;
  bool _isGlutenFree = false;
  bool _isFeatured = false;
  bool _isBestseller = false;
  bool _isNew = false;

  // ── Image ────────────────────────────────────────────────────────
  File? _pickedImage;
  String _existingImageUrl = '';

  // ── State ────────────────────────────────────────────────────────
  bool _submitting = false;

  bool get _isEditing => widget.item != null;

  static const _spiceLevels = [
    ('none', 'None'),
    ('mild', 'Mild'),
    ('medium', 'Medium'),
    ('spicy', 'Spicy'),
  ];

  // ── Lifecycle ────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    final it = widget.item;

    // Pre-fill controllers from existing item (Edit mode)
    _nameCtrl = TextEditingController(text: it?.name ?? '');
    _descCtrl = TextEditingController(text: it?.description ?? '');
    _priceCtrl = TextEditingController(
      text: it != null ? it.price.toStringAsFixed(0) : '',
    );
    _discPriceCtrl = TextEditingController(
      text: it?.discountedPrice != null
          ? it!.discountedPrice!.toStringAsFixed(0)
          : '',
    );
    _prepTimeCtrl = TextEditingController(
      text: it?.preparationTime?.toString() ?? '',
    );
    _servesCtrl = TextEditingController(text: it?.serves?.toString() ?? '');
    _caloriesCtrl = TextEditingController(text: it?.calories?.toString() ?? '');

    if (it != null) {
      _categoryId = it.categoryId;
      _spiceLevel = it.spiceLevel;
      _isVeg = it.isVeg;
      _isVegan = it.isVegan;
      _isGlutenFree = it.isGlutenFree;
      _isFeatured = it.isFeatured;
      _isBestseller = it.isBestseller;
      _isNew = it.isNew;
      _existingImageUrl = it.imageUrl;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _priceCtrl.dispose();
    _discPriceCtrl.dispose();
    _prepTimeCtrl.dispose();
    _servesCtrl.dispose();
    _caloriesCtrl.dispose();
    super.dispose();
  }

  // ── Image picker ──────────────────────────────────────────────────
  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final XFile? picked = await picker.pickImage(
      source: source,
      imageQuality: 80,
      maxWidth: 800,
    );
    if (picked != null) {
      setState(() => _pickedImage = File(picked.path));
    }
  }

  void _showImageSourceSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: AppColors.primaryLight,
                child: Icon(
                  Icons.camera_alt_outlined,
                  color: AppColors.primary,
                ),
              ),
              title: const Text(
                'Take a Photo',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: AppColors.primaryLight,
                child: Icon(
                  Icons.photo_library_outlined,
                  color: AppColors.primary,
                ),
              ),
              title: const Text(
                'Choose from Gallery',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ── Build FormData payload ────────────────────────────────────────
  Future<FormData> _buildFormData() async {
    final fields = <MapEntry<String, dynamic>>[
      MapEntry('name', _nameCtrl.text.trim()),
      MapEntry('description', _descCtrl.text.trim()),
      MapEntry('price', _priceCtrl.text.trim()),
      MapEntry('spice_level', _spiceLevel),
      MapEntry('is_veg', _isVeg.toString()),
      MapEntry('is_vegan', _isVegan.toString()),
      MapEntry('is_gluten_free', _isGlutenFree.toString()),
      MapEntry('is_featured', _isFeatured.toString()),
      MapEntry('is_bestseller', _isBestseller.toString()),
      MapEntry('is_new', _isNew.toString()),
    ];

    if (_categoryId != null) {
      fields.add(MapEntry('category', _categoryId.toString()));
    }
    final disc = _discPriceCtrl.text.trim();
    if (disc.isNotEmpty) fields.add(MapEntry('discounted_price', disc));

    final prep = _prepTimeCtrl.text.trim();
    if (prep.isNotEmpty) fields.add(MapEntry('preparation_time', prep));

    final serves = _servesCtrl.text.trim();
    if (serves.isNotEmpty) fields.add(MapEntry('serves', serves));

    final cal = _caloriesCtrl.text.trim();
    if (cal.isNotEmpty) fields.add(MapEntry('calories', cal));

    final formData = FormData.fromMap(Map.fromEntries(fields));

    // Attach image file if user picked one
    if (_pickedImage != null) {
      formData.files.add(
        MapEntry(
          'image',
          await MultipartFile.fromFile(
            _pickedImage!.path,
            filename: 'item_image.jpg',
          ),
        ),
      );
    }

    return formData;
  }

  // ── Submit ────────────────────────────────────────────────────────
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_submitting) return;

    setState(() => _submitting = true);

    final vm = context.read<MenuViewModel>();
    final formData = await _buildFormData();

    final ok = _isEditing
        ? await vm.updateItem(widget.item!.id, formData)
        : await vm.addItem(formData);

    if (!mounted) return;
    setState(() => _submitting = false);

    if (ok) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isEditing ? 'Item updated!' : 'Item added successfully!',
          ),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      final errMsg = vm.error ?? 'Operation failed. Please try again.';
      vm.clearError();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errMsg),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ── UI ────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final categories = context.select<MenuViewModel, List<MenuCategory>>(
      (vm) => vm.categories,
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        centerTitle: true,
        title: Text(
          _isEditing ? 'Edit Item' : 'Add New Item',
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
        ),
        actions: [
          if (!_submitting)
            TextButton(
              onPressed: _submit,
              child: const Text(
                'Save',
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            )
          else
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Image Picker ─────────────────────────────────────
              _buildImagePicker(),
              const SizedBox(height: 24),

              // ── Basic Info ───────────────────────────────────────
              _sectionLabel('BASIC INFO'),
              const SizedBox(height: 10),
              TextFormField(
                controller: _nameCtrl,
                decoration: _inputDecor('Item Name *'),
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Name is required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descCtrl,
                decoration: _inputDecor('Description'),
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.next,
              ),

              // ── Pricing ──────────────────────────────────────────
              const SizedBox(height: 24),
              _sectionLabel('PRICING'),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _priceCtrl,
                      decoration: _inputDecor('Price (₹) *'),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      textInputAction: TextInputAction.next,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Required';
                        if (double.tryParse(v.trim()) == null) return 'Invalid';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _discPriceCtrl,
                      decoration: _inputDecor('Discounted (₹)'),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      textInputAction: TextInputAction.next,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return null;
                        if (double.tryParse(v.trim()) == null) return 'Invalid';
                        return null;
                      },
                    ),
                  ),
                ],
              ),

              // ── Details ──────────────────────────────────────────
              const SizedBox(height: 24),
              _sectionLabel('DETAILS'),
              const SizedBox(height: 10),

              // Category dropdown
              DropdownButtonFormField<int>(
                initialValue: categories.any((c) => c.id == _categoryId)
                    ? _categoryId
                    : null,
                decoration: _inputDecor('Category'),
                isExpanded: true,
                hint: const Text(
                  'Select a category',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                items: categories
                    .map(
                      (c) => DropdownMenuItem(
                        value: c.id,
                        child: Text(c.name, overflow: TextOverflow.ellipsis),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _categoryId = v),
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _prepTimeCtrl,
                      decoration: _inputDecor('Prep Time (mins)'),
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.next,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return null;
                        final n = int.tryParse(v.trim());
                        if (n == null) return 'Must be a whole number';
                        if (n < 5) return 'Min 5 minutes';
                        if (n > 180) return 'Max 180 minutes';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _servesCtrl,
                      decoration: _inputDecor('Serves'),
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.next,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _caloriesCtrl,
                      decoration: _inputDecor('Calories'),
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.done,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _spiceLevel,
                      decoration: _inputDecor('Spice Level'),
                      items: _spiceLevels
                          .map(
                            (sl) => DropdownMenuItem(
                              value: sl.$1,
                              child: Text(sl.$2),
                            ),
                          )
                          .toList(),
                      onChanged: (v) =>
                          setState(() => _spiceLevel = v ?? 'none'),
                    ),
                  ),
                ],
              ),

              // ── Item Type ─────────────────────────────────────────
              const SizedBox(height: 24),
              _sectionLabel('ITEM TYPE'),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _typeChip(
                      label: '🟩 Vegetarian',
                      active: _isVeg,
                      activeColor: AppColors.success,
                      onTap: () => setState(() => _isVeg = true),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _typeChip(
                      label: '🟥 Non-Veg',
                      active: !_isVeg,
                      activeColor: AppColors.error,
                      onTap: () => setState(() => _isVeg = false),
                    ),
                  ),
                ],
              ),

              // ── Special Tags ──────────────────────────────────────
              const SizedBox(height: 24),
              _sectionLabel('SPECIAL TAGS'),
              _checkRow(
                label: '⭐ Featured',
                value: _isFeatured,
                onChanged: (v) => setState(() => _isFeatured = v ?? false),
              ),
              _checkRow(
                label: '🔥 Bestseller',
                value: _isBestseller,
                onChanged: (v) => setState(() => _isBestseller = v ?? false),
              ),
              _checkRow(
                label: '✨ New Arrival',
                value: _isNew,
                onChanged: (v) => setState(() => _isNew = v ?? false),
              ),
              _checkRow(
                label: '🌱 Vegan',
                value: _isVegan,
                onChanged: (v) => setState(() => _isVegan = v ?? false),
              ),
              _checkRow(
                label: '✅ Gluten Free',
                value: _isGlutenFree,
                onChanged: (v) => setState(() => _isGlutenFree = v ?? false),
              ),

              // ── Submit button ──────────────────────────────────────
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _submitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppColors.primary.withAlpha(128),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
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
                          _isEditing ? 'Save Changes' : 'Add Item',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Image picker widget ───────────────────────────────────────────
  Widget _buildImagePicker() {
    final hasLocal = _pickedImage != null;
    final hasNetwork = _existingImageUrl.isNotEmpty;
    final showPreview = hasLocal || hasNetwork;

    return Center(
      child: Column(
        children: [
          GestureDetector(
            onTap: _showImageSourceSheet,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: showPreview
                      ? AppColors.primary
                      : AppColors.borderLight,
                  width: showPreview ? 2 : 1,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: showPreview
                    ? _buildImagePreview(
                        hasLocal: hasLocal,
                        hasNetwork: hasNetwork,
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.add_a_photo_outlined,
                            size: 40,
                            color: AppColors.textSecondary.withAlpha(153),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Add Photo',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary.withAlpha(153),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
          if (showPreview) ...[
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _showImageSourceSheet,
              icon: const Icon(Icons.edit_outlined, size: 14),
              label: const Text('Change Photo', style: TextStyle(fontSize: 12)),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                minimumSize: Size.zero,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildImagePreview({
    required bool hasLocal,
    required bool hasNetwork,
  }) {
    if (hasLocal) {
      return Image.file(
        _pickedImage!,
        width: 140,
        height: 140,
        fit: BoxFit.cover,
      );
    }
    // Network image (existing item)
    final url = _resolveUrl(_existingImageUrl);
    return CachedNetworkImage(
      imageUrl: url,
      width: 140,
      height: 140,
      fit: BoxFit.cover,
      placeholder: (_, _) => const Center(
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: AppColors.primary,
        ),
      ),
      errorWidget: (_, _, _) => const Center(
        child: Icon(
          Icons.fastfood_outlined,
          size: 48,
          color: AppColors.textHint,
        ),
      ),
    );
  }

  /// Prepend server origin for relative paths from the Django backend.
  static String _resolveUrl(String url) {
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    return 'http://localhost:8000$url';
  }

  // ── Shared helpers ───────────────────────────────────────────────
  static Widget _sectionLabel(String text) => Text(
    text,
    style: const TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w700,
      color: AppColors.textSecondary,
      letterSpacing: 0.8,
    ),
  );

  static InputDecoration _inputDecor(String label) => InputDecoration(
    labelText: label,
    labelStyle: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
    filled: true,
    fillColor: AppColors.surface,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: AppColors.borderLight),
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
      borderSide: const BorderSide(color: AppColors.error, width: 1.5),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: AppColors.error, width: 1.5),
    ),
  );

  static Widget _typeChip({
    required String label,
    required bool active,
    required Color activeColor,
    required VoidCallback onTap,
  }) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: active ? activeColor.withAlpha(25) : AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: active ? activeColor : AppColors.borderLight,
          width: active ? 1.5 : 1,
        ),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: active ? activeColor : AppColors.textSecondary,
        ),
      ),
    ),
  );

  static Widget _checkRow({
    required String label,
    required bool value,
    required void Function(bool?) onChanged,
  }) => CheckboxListTile(
    title: Text(
      label,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: AppColors.textPrimary,
      ),
    ),
    value: value,
    onChanged: onChanged,
    activeColor: AppColors.primary,
    controlAffinity: ListTileControlAffinity.leading,
    contentPadding: EdgeInsets.zero,
    dense: true,
  );
}
