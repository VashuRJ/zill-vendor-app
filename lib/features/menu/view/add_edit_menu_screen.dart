import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../viewmodel/menu_viewmodel.dart';
import '../../addons/viewmodel/addon_viewmodel.dart';

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

  // Variants
  List<_VariantEntry> _variants = [];

  // Addon Groups
  List<AddonGroup> _allAddonGroups = [];
  Set<int> _linkedAddonGroupIds = {};
  bool _loadingAddons = false;

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

      // Pre-fill variants from the item
      _variants = it.variants
          .map((v) => _VariantEntry(
                id: v.id,
                nameCtrl: TextEditingController(text: v.name),
                priceCtrl: TextEditingController(
                  text: v.price.toStringAsFixed(0),
                ),
                isDefault: v.isDefault,
                isAvailable: v.isAvailable,
              ))
          .toList();

      // Load linked addon groups after the first frame to avoid
      // notifyListeners() firing during the build phase.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _loadAddonData(it.id);
      });
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _loadAllAddonGroups();
      });
    }
  }

  Future<void> _loadAddonData(int itemId) async {
    setState(() => _loadingAddons = true);
    try {
      final addonVm = context.read<AddonViewModel>();
      await addonVm.fetchGroups();
      final linkedIds = await addonVm.getLinkedGroupIds(itemId);
      if (mounted) {
        setState(() {
          _allAddonGroups = addonVm.groups;
          _linkedAddonGroupIds = linkedIds.toSet();
          _loadingAddons = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingAddons = false);
    }
  }

  Future<void> _loadAllAddonGroups() async {
    setState(() => _loadingAddons = true);
    try {
      final addonVm = context.read<AddonViewModel>();
      await addonVm.fetchGroups();
      if (mounted) {
        setState(() {
          _allAddonGroups = addonVm.groups;
          _loadingAddons = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingAddons = false);
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
    for (final v in _variants) {
      v.nameCtrl.dispose();
      v.priceCtrl.dispose();
    }
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
    final addonVm = context.read<AddonViewModel>();
    final nav = Navigator.of(context);
    final scaffold = ScaffoldMessenger.of(context);
    final formData = await _buildFormData();

    final ok = _isEditing
        ? await vm.updateItem(widget.item!.id, formData)
        : await vm.addItem(formData);

    if (!mounted) return;

    if (ok) {
      // Determine the item ID for variant/addon operations
      final itemId = _isEditing ? widget.item!.id : _findNewItemId(vm);

      if (itemId != null) {
        // Save variants
        await _saveVariants(vm, itemId);

        // Save addon group links
        await _saveAddonLinks(addonVm, itemId);
      }

      // Re-fetch to get fresh data with variants
      await vm.fetchMenu();

      if (!mounted) return;
      setState(() => _submitting = false);

      nav.pop();
      scaffold.showSnackBar(
        SnackBar(
          content: Text(
            _isEditing ? 'Item updated!' : 'Item added successfully!',
          ),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      setState(() => _submitting = false);

      final errMsg = vm.error ?? 'Operation failed. Please try again.';
      vm.clearError();
      scaffold.showSnackBar(
        SnackBar(
          content: Text(errMsg),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  /// Find the newly created item's ID by matching name in the refreshed menu.
  int? _findNewItemId(MenuViewModel vm) {
    final name = _nameCtrl.text.trim().toLowerCase();
    for (final cat in vm.categories) {
      for (final item in cat.items) {
        if (item.name.toLowerCase() == name) {
          return item.id;
        }
      }
    }
    return null;
  }

  /// Sync variants: delete removed, update existing, create new.
  Future<void> _saveVariants(MenuViewModel vm, int itemId) async {
    if (_variants.isEmpty && (!_isEditing || widget.item!.variants.isEmpty)) {
      return; // Nothing to do
    }

    // In edit mode, delete variants that were removed
    if (_isEditing) {
      final currentIds = _variants
          .where((v) => v.id != null)
          .map((v) => v.id!)
          .toSet();
      for (final existingVariant in widget.item!.variants) {
        if (existingVariant.id != null &&
            !currentIds.contains(existingVariant.id)) {
          await vm.deleteVariant(itemId, existingVariant.id!);
        }
      }
    }

    // Create/update variants
    for (int i = 0; i < _variants.length; i++) {
      final entry = _variants[i];
      final variant = MenuItemVariant(
        id: entry.id,
        name: entry.nameCtrl.text.trim(),
        price: double.tryParse(entry.priceCtrl.text.trim()) ?? 0,
        isDefault: entry.isDefault,
        isAvailable: entry.isAvailable,
        displayOrder: i,
      );

      if (entry.id != null) {
        await vm.updateVariant(itemId, entry.id!, variant);
      } else {
        await vm.createVariant(itemId, variant);
      }
    }
  }

  /// Sync addon group links: link newly selected, unlink removed.
  Future<void> _saveAddonLinks(AddonViewModel addonVm, int itemId) async {
    if (_isEditing) {
      // Get current links from server
      final serverLinks = await addonVm.getLinkedGroupIds(itemId);
      final serverSet = serverLinks.toSet();

      // Unlink removed groups
      for (final gid in serverSet) {
        if (!_linkedAddonGroupIds.contains(gid)) {
          await addonVm.unlinkFromMenuItem(itemId, gid);
        }
      }

      // Link newly added groups
      for (final gid in _linkedAddonGroupIds) {
        if (!serverSet.contains(gid)) {
          await addonVm.linkToMenuItem(itemId, gid);
        }
      }
    } else {
      // New item — link all selected groups
      for (final gid in _linkedAddonGroupIds) {
        await addonVm.linkToMenuItem(itemId, gid);
      }
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
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
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
                keyboardType: TextInputType.name,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Name is required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descCtrl,
                decoration: _inputDecor('Description'),
                keyboardType: TextInputType.multiline,
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.newline,
                onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
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
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d*')),
                      ],
                      textInputAction: TextInputAction.next,
                      onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
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
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d*')),
                      ],
                      textInputAction: TextInputAction.next,
                      onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
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
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      textInputAction: TextInputAction.next,
                      onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
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
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      textInputAction: TextInputAction.next,
                      onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
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
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      textInputAction: TextInputAction.done,
                      onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
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

              // ── Variants ──────────────────────────────────────────
              const SizedBox(height: 24),
              _buildVariantsSection(),

              // ── Addon Groups ──────────────────────────────────────
              const SizedBox(height: 24),
              _buildAddonGroupsSection(),

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
      ),
    );
  }

  // ── Image picker widget ───────────────────────────────────────────
  Widget _buildImagePicker() {
    final hasLocal = _pickedImage != null;
    final hasNetwork = _isValidImageUrl(_existingImageUrl);
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

  /// Returns true only if [url] looks like a usable image path.
  static bool _isValidImageUrl(String url) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return false;
    // Django sometimes stores literal "None" or placeholder paths
    if (trimmed == 'None' || trimmed == 'null' || trimmed == '/media/None') {
      return false;
    }
    return true;
  }

  /// Prepend server origin for relative paths from the Django backend.
  static String _resolveUrl(String url) {
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    const base = String.fromEnvironment('SERVER_ORIGIN',
        defaultValue: 'https://zill.co.in');
    return '$base$url';
  }

  // ── Variants Section ─────────────────────────────────────────────
  Widget _buildVariantsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _sectionLabel('VARIANTS (SIZES / PORTIONS)'),
            const Spacer(),
            GestureDetector(
              onTap: _addVariant,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.primary.withAlpha(15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add_rounded, size: 16, color: AppColors.primary),
                    SizedBox(width: 4),
                    Text(
                      'Add',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_variants.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.borderLight),
            ),
            child: const Text(
              'No variants. Add sizes like Small, Medium, Large with different prices.',
              style: TextStyle(fontSize: 12.5, color: AppColors.textHint),
              textAlign: TextAlign.center,
            ),
          )
        else
          ...List.generate(_variants.length, (i) {
            final v = _variants[i];
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.borderLight),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Default indicator
                  GestureDetector(
                    onTap: () => _setDefaultVariant(i),
                    child: Container(
                      margin: const EdgeInsets.only(top: 10),
                      width: 20, height: 20,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: v.isDefault
                            ? AppColors.primary
                            : Colors.transparent,
                        border: Border.all(
                          color: v.isDefault
                              ? AppColors.primary
                              : AppColors.textHint,
                          width: 2,
                        ),
                      ),
                      child: v.isDefault
                          ? const Icon(
                              Icons.check, size: 12, color: Colors.white,
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Name
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      controller: v.nameCtrl,
                      textCapitalization: TextCapitalization.words,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                      decoration: _variantInput('Name (e.g. Small)'),
                      validator: (val) => (val == null || val.trim().isEmpty)
                          ? 'Required'
                          : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Price
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: v.priceCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                      ],
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                      decoration: _variantInput('₹ Price'),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return 'Required';
                        if (double.tryParse(val.trim()) == null) return 'Invalid';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 6),
                  // Remove
                  GestureDetector(
                    onTap: () => _removeVariant(i),
                    child: Container(
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.error.withAlpha(12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        size: 14,
                        color: AppColors.error,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        if (_variants.isNotEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text(
              'Tap the circle to set default variant. Prices override the base price.',
              style: TextStyle(fontSize: 11, color: AppColors.textHint),
            ),
          ),
      ],
    );
  }

  void _addVariant() {
    setState(() {
      _variants.add(_VariantEntry(
        nameCtrl: TextEditingController(),
        priceCtrl: TextEditingController(),
        isDefault: _variants.isEmpty, // first variant is default
      ));
    });
  }

  void _removeVariant(int index) {
    setState(() {
      _variants[index].nameCtrl.dispose();
      _variants[index].priceCtrl.dispose();
      _variants.removeAt(index);
      // Ensure at least one default if variants remain
      if (_variants.isNotEmpty && !_variants.any((v) => v.isDefault)) {
        _variants.first.isDefault = true;
      }
    });
  }

  void _setDefaultVariant(int index) {
    setState(() {
      for (int i = 0; i < _variants.length; i++) {
        _variants[i].isDefault = i == index;
      }
    });
  }

  static InputDecoration _variantInput(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(
      color: AppColors.textHint.withAlpha(150),
      fontWeight: FontWeight.w400,
      fontSize: 12,
    ),
    isDense: true,
    filled: true,
    fillColor: AppColors.background,
    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: AppColors.error),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: AppColors.error, width: 1.5),
    ),
    errorStyle: const TextStyle(fontSize: 10),
  );

  // ── Addon Groups Section ────────────────────────────────────────
  Widget _buildAddonGroupsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('LINKED ADDON GROUPS'),
        const SizedBox(height: 8),
        if (_loadingAddons)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: SizedBox(
                width: 20, height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2, color: AppColors.primary,
                ),
              ),
            ),
          )
        else if (_allAddonGroups.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.borderLight),
            ),
            child: const Text(
              'No addon groups created yet. Create addon groups from the menu to link them here.',
              style: TextStyle(fontSize: 12.5, color: AppColors.textHint),
              textAlign: TextAlign.center,
            ),
          )
        else
          ..._allAddonGroups.map((group) {
            final isLinked = _linkedAddonGroupIds.contains(group.id);
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isLinked
                      ? AppColors.primary.withAlpha(60)
                      : AppColors.borderLight,
                ),
              ),
              child: CheckboxListTile(
                value: isLinked,
                onChanged: (val) {
                  setState(() {
                    if (val == true) {
                      _linkedAddonGroupIds.add(group.id);
                    } else {
                      _linkedAddonGroupIds.remove(group.id);
                    }
                  });
                },
                activeColor: AppColors.primary,
                controlAffinity: ListTileControlAffinity.trailing,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 2,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                title: Text(
                  group.name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                subtitle: Text(
                  '${group.items.length} items · ${group.selectionType == 'single' ? 'Single' : 'Multi'} select${group.isRequired ? ' · Required' : ''}',
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: AppColors.textSecondary,
                  ),
                ),
                secondary: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.purple.withAlpha(15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.playlist_add_rounded,
                    size: 18,
                    color: AppColors.purple,
                  ),
                ),
              ),
            );
          }),
        if (!_isEditing && _allAddonGroups.isNotEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text(
              'Addon groups will be linked after the item is saved.',
              style: TextStyle(fontSize: 11, color: AppColors.textHint),
            ),
          ),
      ],
    );
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

class _VariantEntry {
  final int? id;
  final TextEditingController nameCtrl;
  final TextEditingController priceCtrl;
  bool isDefault;
  bool isAvailable;

  _VariantEntry({
    this.id,
    required this.nameCtrl,
    required this.priceCtrl,
    this.isDefault = false,
    this.isAvailable = true,
  });
}
