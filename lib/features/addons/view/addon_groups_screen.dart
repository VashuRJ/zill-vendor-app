import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../viewmodel/addon_viewmodel.dart';

class AddonGroupsScreen extends StatefulWidget {
  const AddonGroupsScreen({super.key});

  @override
  State<AddonGroupsScreen> createState() => _AddonGroupsScreenState();
}

class _AddonGroupsScreenState extends State<AddonGroupsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AddonViewModel>().fetchGroups();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Addon Groups',
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(context),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        icon: const Icon(Icons.add_rounded, size: 20),
        label: const Text(
          'New Group',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        ),
      ),
      body: Consumer<AddonViewModel>(
        builder: (context, vm, _) {
          if (vm.status == AddonStatus.loading && vm.groups.isEmpty) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }

          if (vm.status == AddonStatus.error && vm.groups.isEmpty) {
            return _ErrorView(
              message: vm.error ?? 'Could not load addon groups.',
              onRetry: vm.fetchGroups,
            );
          }

          if (vm.groups.isEmpty) {
            return _EmptyView(onAdd: () => _openEditor(context));
          }

          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: vm.fetchGroups,
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(
                AppSizes.md, AppSizes.sm, AppSizes.md, 80,
              ),
              itemCount: vm.groups.length,
              itemBuilder: (context, index) {
                final group = vm.groups[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _AddonGroupCard(
                    group: group,
                    isDeleting: vm.isDeleting(group.id),
                    onEdit: () => _openEditor(context, group: group),
                    onDelete: () => _confirmDelete(context, group),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  void _openEditor(BuildContext context, {AddonGroup? group}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider.value(
          value: context.read<AddonViewModel>(),
          child: _AddonGroupEditorScreen(group: group),
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, AddonGroup group) {
    final vm = context.read<AddonViewModel>();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text(
          'Delete Addon Group',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
        ),
        content: Text(
          'Delete "${group.name}" and all its items? This cannot be undone.',
          style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final ok = await vm.deleteGroup(group.id);
              if (!ok && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(vm.error ?? 'Failed to delete group.'),
                    backgroundColor: AppColors.error,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            child: const Text(
              'Delete',
              style: TextStyle(
                color: AppColors.error,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
//  Addon Group Card
// ═══════════════════════════════════════════════════════════════════════

class _AddonGroupCard extends StatelessWidget {
  final AddonGroup group;
  final bool isDeleting;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _AddonGroupCard({
    required this.group,
    required this.isDeleting,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: isDeleting ? 0.5 : 1.0,
      duration: const Duration(milliseconds: 200),
      child: Container(
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
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppSizes.radiusMd),
            onTap: onEdit,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.purple.withAlpha(20),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.playlist_add_rounded,
                          size: 20,
                          color: AppColors.purple,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              group.name,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            if (group.description.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                group.description,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                      // Actions
                      _ActionBtn(
                        icon: Icons.edit_outlined,
                        color: AppColors.info,
                        onTap: onEdit,
                      ),
                      const SizedBox(width: 6),
                      _ActionBtn(
                        icon: Icons.delete_outline_rounded,
                        color: AppColors.error,
                        onTap: isDeleting ? null : onDelete,
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Info chips
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _Chip(
                        icon: group.selectionType == 'single'
                            ? Icons.radio_button_checked
                            : Icons.check_box_outlined,
                        label: group.selectionType == 'single'
                            ? 'Single Select'
                            : 'Multi Select',
                        color: AppColors.info,
                      ),
                      _Chip(
                        icon: group.isRequired
                            ? Icons.star_rounded
                            : Icons.star_border_rounded,
                        label: group.isRequired ? 'Required' : 'Optional',
                        color: group.isRequired
                            ? AppColors.warning
                            : AppColors.textHint,
                      ),
                      _Chip(
                        icon: Icons.restaurant_menu_rounded,
                        label: '${group.items.length} items',
                        color: AppColors.success,
                      ),
                      if (group.selectionType == 'multiple' &&
                          group.maxSelections > 0)
                        _Chip(
                          icon: Icons.format_list_numbered_rounded,
                          label: 'Max ${group.maxSelections}',
                          color: AppColors.purple,
                        ),
                    ],
                  ),

                  // Item preview
                  if (group.items.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    const Divider(height: 1, color: AppColors.borderLight),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: group.items.take(5).map((item) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 8, height: 8,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: item.isVeg
                                      ? AppColors.success
                                      : AppColors.error,
                                ),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                item.name,
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '₹${item.price.toStringAsFixed(0)}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                    if (group.items.length > 5)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          '+${group.items.length - 5} more',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textHint,
                          ),
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _Chip({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  const _ActionBtn({required this.icon, required this.color, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: color.withAlpha(12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 16, color: color),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
//  Empty & Error Views
// ═══════════════════════════════════════════════════════════════════════

class _EmptyView extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyView({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.purple.withAlpha(15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.playlist_add_rounded,
                size: 48,
                color: AppColors.purple,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'No Addon Groups Yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Create addon groups like Extra Cheese,\nSauces, or Beverages and link them\nto your menu items.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.5,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text(
                'Create First Group',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24, vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_rounded, size: 48, color: AppColors.error,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14, color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Retry'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
//  Addon Group Editor (Full Screen)
// ═══════════════════════════════════════════════════════════════════════

class _AddonGroupEditorScreen extends StatefulWidget {
  final AddonGroup? group;
  const _AddonGroupEditorScreen({this.group});

  @override
  State<_AddonGroupEditorScreen> createState() =>
      _AddonGroupEditorScreenState();
}

class _AddonGroupEditorScreenState extends State<_AddonGroupEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _maxSelectCtrl;
  late String _selectionType;
  late bool _isRequired;
  late List<_AddonItemEntry> _items;

  bool get _isEditing => widget.group != null;

  @override
  void initState() {
    super.initState();
    final g = widget.group;
    _nameCtrl = TextEditingController(text: g?.name ?? '');
    _descCtrl = TextEditingController(text: g?.description ?? '');
    _maxSelectCtrl = TextEditingController(
      text: g?.maxSelections.toString() ?? '5',
    );
    _selectionType = g?.selectionType ?? 'multiple';
    _isRequired = g?.isRequired ?? false;
    _items = g?.items
            .map((i) => _AddonItemEntry(
                  id: i.id,
                  nameCtrl: TextEditingController(text: i.name),
                  priceCtrl: TextEditingController(
                    text: i.price.toStringAsFixed(0),
                  ),
                  isVeg: i.isVeg,
                  isAvailable: i.isAvailable,
                ))
            .toList() ??
        [];
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _maxSelectCtrl.dispose();
    for (final item in _items) {
      item.nameCtrl.dispose();
      item.priceCtrl.dispose();
    }
    super.dispose();
  }

  void _addItem() {
    setState(() {
      _items.add(_AddonItemEntry(
        nameCtrl: TextEditingController(),
        priceCtrl: TextEditingController(),
      ));
    });
  }

  void _removeItem(int index) {
    setState(() {
      _items[index].nameCtrl.dispose();
      _items[index].priceCtrl.dispose();
      _items.removeAt(index);
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add at least one addon item.'),
          backgroundColor: AppColors.warning,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final vm = context.read<AddonViewModel>();
    final group = AddonGroup(
      id: widget.group?.id ?? 0,
      name: _nameCtrl.text.trim(),
      description: _descCtrl.text.trim(),
      selectionType: _selectionType,
      isRequired: _isRequired,
      minSelections: _isRequired ? 1 : 0,
      maxSelections: int.tryParse(_maxSelectCtrl.text.trim()) ?? 5,
      items: _items
          .map((e) => AddonItem(
                id: e.id,
                name: e.nameCtrl.text.trim(),
                price: double.tryParse(e.priceCtrl.text.trim()) ?? 0,
                isVeg: e.isVeg,
                isAvailable: e.isAvailable,
                displayOrder: _items.indexOf(e),
              ))
          .toList(),
    );

    final ok = _isEditing
        ? await vm.updateGroup(widget.group!.id, group)
        : await vm.createGroup(group);

    if (!mounted) return;

    if (ok) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isEditing ? 'Group updated!' : 'Group created!'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(vm.error ?? 'Failed to save group.'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          _isEditing ? 'Edit Addon Group' : 'New Addon Group',
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
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
        actions: [
          Consumer<AddonViewModel>(
            builder: (context, vm, _) => vm.isSaving
                ? const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Center(
                      child: SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.primary,
                        ),
                      ),
                    ),
                  )
                : TextButton(
                    onPressed: _save,
                    child: const Text(
                      'Save',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                  ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
          children: [
            // ── Group Details ────────────────────────────────────
            _SectionLabel('GROUP DETAILS'),
            const SizedBox(height: 10),
            _field(
              controller: _nameCtrl,
              label: 'Group Name *',
              hint: 'e.g. Extra Toppings',
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            _field(
              controller: _descCtrl,
              label: 'Description',
              hint: 'e.g. Choose your favourite toppings',
            ),

            const SizedBox(height: 24),

            // ── Selection Type ────────────────────────────────────
            _SectionLabel('SELECTION TYPE'),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _SelectionChip(
                    label: 'Single Select',
                    subtitle: 'Pick one option',
                    icon: Icons.radio_button_checked,
                    active: _selectionType == 'single',
                    onTap: () =>
                        setState(() => _selectionType = 'single'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _SelectionChip(
                    label: 'Multi Select',
                    subtitle: 'Pick multiple',
                    icon: Icons.check_box_outlined,
                    active: _selectionType == 'multiple',
                    onTap: () =>
                        setState(() => _selectionType = 'multiple'),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Required toggle & max selections
            Row(
              children: [
                Expanded(
                  child: _RequiredChip(
                    isRequired: _isRequired,
                    onTap: () =>
                        setState(() => _isRequired = !_isRequired),
                  ),
                ),
                if (_selectionType == 'multiple') ...[
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 120,
                    child: _field(
                      controller: _maxSelectCtrl,
                      label: 'Max Picks',
                      hint: '5',
                      isNumber: true,
                    ),
                  ),
                ],
              ],
            ),

            const SizedBox(height: 24),

            // ── Addon Items ────────────────────────────────────
            Row(
              children: [
                const _SectionLabel('ADDON ITEMS'),
                const Spacer(),
                GestureDetector(
                  onTap: _addItem,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5,
                    ),
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
                          'Add Item',
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
            const SizedBox(height: 10),

            if (_items.isEmpty)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.borderLight,
                    style: BorderStyle.solid,
                  ),
                ),
                child: const Center(
                  child: Text(
                    'No items yet. Tap "Add Item" to start.',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textHint,
                    ),
                  ),
                ),
              )
            else
              ...List.generate(_items.length, (i) {
                return _AddonItemRow(
                  key: ValueKey(_items[i].hashCode),
                  entry: _items[i],
                  index: i + 1,
                  onRemove: () => _removeItem(i),
                  onVegToggle: () => setState(
                    () => _items[i].isVeg = !_items[i].isVeg,
                  ),
                  onAvailToggle: () => setState(
                    () => _items[i].isAvailable = !_items[i].isAvailable,
                  ),
                );
              }),

            const SizedBox(height: 32),

            // ── Save Button ────────────────────────────────────
            Consumer<AddonViewModel>(
              builder: (context, vm, _) => SizedBox(
                width: double.infinity,
                height: AppSizes.buttonHeight,
                child: ElevatedButton(
                  onPressed: vm.isSaving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppColors.primary.withAlpha(120),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppSizes.buttonRadius),
                    ),
                  ),
                  child: vm.isSaving
                      ? const SizedBox(
                          width: 22, height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5, color: Colors.white,
                          ),
                        )
                      : Text(
                          _isEditing ? 'Save Changes' : 'Create Group',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required String hint,
    bool isNumber = false,
    FormFieldValidator<String>? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: isNumber
          ? const TextInputType.numberWithOptions(decimal: false)
          : TextInputType.text,
      textCapitalization:
          isNumber ? TextCapitalization.none : TextCapitalization.sentences,
      inputFormatters: isNumber
          ? [FilteringTextInputFormatter.digitsOnly]
          : null,
      textInputAction: TextInputAction.next,
      style: const TextStyle(
        fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: const TextStyle(
          fontSize: 13, color: AppColors.textSecondary,
        ),
        hintStyle: TextStyle(
          color: AppColors.textHint.withAlpha(150),
          fontWeight: FontWeight.w400,
        ),
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14, vertical: 12,
        ),
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
          borderSide: const BorderSide(color: AppColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.error, width: 1.5),
        ),
        errorStyle: const TextStyle(fontSize: 11),
      ),
      validator: validator,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
//  Supporting Widgets
// ═══════════════════════════════════════════════════════════════════════

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: AppColors.textSecondary,
        letterSpacing: 0.8,
      ),
    );
  }
}

class _SelectionChip extends StatelessWidget {
  final String label;
  final String subtitle;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  const _SelectionChip({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: active
              ? AppColors.primary.withAlpha(10)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: active ? AppColors.primary : AppColors.borderLight,
            width: active ? 1.5 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 24,
              color: active ? AppColors.primary : AppColors.textHint,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: active ? AppColors.primary : AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 11,
                color: active ? AppColors.primary : AppColors.textHint,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RequiredChip extends StatelessWidget {
  final bool isRequired;
  final VoidCallback onTap;
  const _RequiredChip({required this.isRequired, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isRequired
              ? AppColors.warning.withAlpha(15)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isRequired ? AppColors.warning : AppColors.borderLight,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isRequired ? Icons.star_rounded : Icons.star_border_rounded,
              size: 18,
              color: isRequired ? AppColors.warning : AppColors.textHint,
            ),
            const SizedBox(width: 8),
            Text(
              isRequired ? 'Required' : 'Optional',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isRequired ? AppColors.warning : AppColors.textHint,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddonItemEntry {
  final int? id;
  final TextEditingController nameCtrl;
  final TextEditingController priceCtrl;
  bool isVeg;
  bool isAvailable;

  _AddonItemEntry({
    this.id,
    required this.nameCtrl,
    required this.priceCtrl,
    this.isVeg = true,
    this.isAvailable = true,
  });
}

class _AddonItemRow extends StatelessWidget {
  final _AddonItemEntry entry;
  final int index;
  final VoidCallback onRemove;
  final VoidCallback onVegToggle;
  final VoidCallback onAvailToggle;

  const _AddonItemRow({
    super.key,
    required this.entry,
    required this.index,
    required this.onRemove,
    required this.onVegToggle,
    required this.onAvailToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        children: [
          // Name + Price row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Index badge
              Container(
                width: 24, height: 24,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.primary.withAlpha(15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '$index',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Name
              Expanded(
                flex: 3,
                child: TextFormField(
                  controller: entry.nameCtrl,
                  textCapitalization: TextCapitalization.words,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                  decoration: _miniInput('Item Name *'),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
              ),
              const SizedBox(width: 10),
              // Price
              Expanded(
                flex: 2,
                child: TextFormField(
                  controller: entry.priceCtrl,
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
                  decoration: _miniInput('Price (₹) *'),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Required';
                    if (double.tryParse(v.trim()) == null) return 'Invalid';
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 6),
              // Remove
              GestureDetector(
                onTap: onRemove,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.error.withAlpha(12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.close_rounded, size: 16, color: AppColors.error,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Veg/Non-Veg + Available toggles
          Row(
            children: [
              const SizedBox(width: 34), // align with name field
              GestureDetector(
                onTap: onVegToggle,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: entry.isVeg
                        ? AppColors.success.withAlpha(15)
                        : AppColors.error.withAlpha(15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8, height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: entry.isVeg
                              ? AppColors.success
                              : AppColors.error,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        entry.isVeg ? 'Veg' : 'Non-Veg',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: entry.isVeg
                              ? AppColors.success
                              : AppColors.error,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: onAvailToggle,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: entry.isAvailable
                        ? AppColors.info.withAlpha(15)
                        : AppColors.textHint.withAlpha(15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        entry.isAvailable
                            ? Icons.check_circle_outline
                            : Icons.cancel_outlined,
                        size: 12,
                        color: entry.isAvailable
                            ? AppColors.info
                            : AppColors.textHint,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        entry.isAvailable ? 'Available' : 'Unavailable',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: entry.isAvailable
                              ? AppColors.info
                              : AppColors.textHint,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static InputDecoration _miniInput(String label) => InputDecoration(
    labelText: label,
    labelStyle: const TextStyle(fontSize: 11, color: AppColors.textHint),
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
}
