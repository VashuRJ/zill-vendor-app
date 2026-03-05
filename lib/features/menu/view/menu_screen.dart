import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';

import '../../../core/constants/app_colors.dart';
import '../viewmodel/menu_viewmodel.dart';
import 'add_edit_menu_screen.dart';
import 'manage_categories_screen.dart';

// ────────────────────────────────────────────────────────────────────
//  Menu Screen
// ────────────────────────────────────────────────────────────────────
class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> with TickerProviderStateMixin {
  TabController? _tabController;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MenuViewModel>().fetchMenu();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController?.dispose();
    super.dispose();
  }

  void _rebuildTabs(int length) {
    if (_tabController?.length == length) return;
    _tabController?.dispose();
    _tabController = TabController(length: length, vsync: this);
  }

  Future<void> _refresh() => context.read<MenuViewModel>().fetchMenu();

  @override
  Widget build(BuildContext context) {
    return Consumer<MenuViewModel>(
      builder: (context, vm, _) {
        // Show error snack (once)
        if (vm.error != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            ScaffoldMessenger.of(context)
              ..clearSnackBars()
              ..showSnackBar(
                SnackBar(
                  content: Text(vm.error!),
                  backgroundColor: AppColors.error,
                  behavior: SnackBarBehavior.floating,
                  action: SnackBarAction(
                    label: 'Retry',
                    textColor: Colors.white,
                    onPressed: _refresh,
                  ),
                ),
              );
            vm.clearError();
          });
        }

        // ── Loading shimmer ──────────────────────────────────────────
        if (vm.status == MenuStatus.loading) {
          return _buildShimmer();
        }

        // ── Error / empty without data ──────────────────────────────
        if (vm.status == MenuStatus.error && vm.categories.isEmpty) {
          return _buildErrorState(context);
        }

        // ── Empty (loaded but no categories) ────────────────────────
        if (vm.status == MenuStatus.loaded && vm.categories.isEmpty) {
          return _buildEmptyState(context);
        }

        // ── Loaded ───────────────────────────────────────────────────
        final cats = vm.categories;
        final isSearch = vm.isSearchActive;
        _rebuildTabs(cats.length + 1);

        final inSelect = vm.selectionMode;

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: inSelect
              ? _buildSelectionAppBar(vm)
              : _buildNormalAppBar(vm, cats),
          floatingActionButton: inSelect
              ? null
              : FloatingActionButton(
                  onPressed: () => _goToAddEdit(),
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  tooltip: 'Add Item',
                  child: const Icon(Icons.add),
                ),
          bottomNavigationBar:
              inSelect ? _BulkActionBar(vm: vm) : null,
          body: Column(
            children: [
              _MenuStatsRow(vm: vm),
              if (!inSelect)
                _MenuSearchBar(controller: _searchController, vm: vm),
              if (!isSearch && !inSelect && _tabController != null)
                _CategoryChipsRow(
                  tabController: _tabController!,
                  categories: cats,
                  vm: vm,
                ),
              if (!inSelect) _FilterChips(vm: vm),
              Expanded(
                child: isSearch && !inSelect
                    ? _FlatSearchResults(
                        vm: vm,
                        onRefresh: _refresh,
                        onEditItem: (item) => _goToAddEdit(item: item),
                      )
                    : TabBarView(
                        controller: _tabController,
                        children: [
                          _AllTabBody(
                            vm: vm,
                            onRefresh: _refresh,
                            onEditItem: (item) => _goToAddEdit(item: item),
                          ),
                          ...cats.map(
                            (cat) => _CategoryTabBody(
                              category: cat,
                              filteredItems: vm.filteredItemsForCategory(
                                cat.id,
                              ),
                              onRefresh: _refresh,
                              onEditItem: (item) => _goToAddEdit(item: item),
                            ),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Add / Edit screen launcher ────────────────────────────────────
  void _goToAddEdit({MenuItem? item}) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AddEditMenuScreen(item: item)),
    ).then((_) {
      if (mounted) context.read<MenuViewModel>().fetchMenu();
    });
  }

  // ── Normal AppBar ──────────────────────────────────────────────────
  AppBar _buildNormalAppBar(MenuViewModel vm, List<MenuCategory> cats) {
    return AppBar(
      backgroundColor: AppColors.surface,
      foregroundColor: AppColors.textPrimary,
      elevation: 0,
      centerTitle: true,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Text(
            'Menu',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
          ),
          Text(
            '${vm.totalItemCount} items · ${cats.length} categories',
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.normal,
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          tooltip: 'Bulk Select',
          icon: const Icon(Icons.checklist_rounded, size: 22),
          onPressed: vm.toggleSelectionMode,
        ),
        IconButton(
          tooltip: 'Manage Categories',
          icon: const Icon(Icons.category_outlined, size: 22),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const ManageCategoriesScreen(),
            ),
          ),
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  // ── Selection Mode AppBar ─────────────────────────────────────────
  AppBar _buildSelectionAppBar(MenuViewModel vm) {
    return AppBar(
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.close_rounded),
        onPressed: vm.exitSelectionMode,
      ),
      title: Text(
        '${vm.selectedCount} selected',
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 17,
          color: Colors.white,
        ),
      ),
      actions: [
        TextButton(
          onPressed: vm.selectedCount == vm.totalItemCount
              ? vm.clearSelection
              : vm.selectAll,
          child: Text(
            vm.selectedCount == vm.totalItemCount
                ? 'Deselect All'
                : 'Select All',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  // ── Shimmer ──────────────────────────────────────────────────────
  Widget _buildShimmer() {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Menu'),
        centerTitle: true,
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: Shimmer.fromColors(
        baseColor: AppColors.shimmerBase,
        highlightColor: AppColors.shimmerHighlight,
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: 6,
          itemBuilder: (_, _) => const _ShimmerCard(),
        ),
      ),
    );
  }

  // ── Error ────────────────────────────────────────────────────────
  Widget _buildErrorState(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Menu'),
        centerTitle: true,
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _goToAddEdit(),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        tooltip: 'Add Item',
        child: const Icon(Icons.add),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.wifi_off_rounded,
                size: 72,
                color: AppColors.textSecondary.withAlpha(102),
              ),
              const SizedBox(height: 20),
              const Text(
                'Could not load menu',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Check your connection and try again',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              ElevatedButton.icon(
                onPressed: _refresh,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Empty ─────────────────────────────────────────────────────────
  Widget _buildEmptyState(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Menu'),
        centerTitle: true,
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _goToAddEdit(),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        tooltip: 'Add Item',
        child: const Icon(Icons.add),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.restaurant_menu_outlined,
                size: 72,
                color: AppColors.textSecondary.withAlpha(102),
              ),
              const SizedBox(height: 20),
              const Text(
                'No menu items yet',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Tap the ➕ button below to add your first menu item.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              OutlinedButton.icon(
                onPressed: _refresh,
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────
//  Web-style Category Chips Row
// ────────────────────────────────────────────────────────────────────
class _CategoryChipsRow extends StatelessWidget {
  const _CategoryChipsRow({
    required this.tabController,
    required this.categories,
    required this.vm,
  });

  final TabController tabController;
  final List<MenuCategory> categories;
  final MenuViewModel vm;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: tabController,
      builder: (context, _) {
        final sel = tabController.index;
        // "All" count = all items across categories with active filters
        final allCount = vm.flatSearchResults.length;
        return Container(
          color: AppColors.surface,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: Row(
                  children: [
                    _WebChip(
                      label: 'All',
                      count: allCount,
                      isSelected: sel == 0,
                      isAll: true,
                      onTap: () => tabController.animateTo(0),
                    ),
                    ...List.generate(categories.length, (i) {
                      final cat = categories[i];
                      return Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: _WebChip(
                          label: cat.name,
                          count: vm.filteredItemsForCategory(cat.id).length,
                          isSelected: sel == i + 1,
                          onTap: () => tabController.animateTo(i + 1),
                        ),
                      );
                    }),
                  ],
                ),
              ),
              Divider(height: 1, thickness: 1, color: AppColors.borderLight),
            ],
          ),
        );
      },
    );
  }
}

// ────────────────────────────────────────────────────────────────────
//  Single web-style pill chip
// ────────────────────────────────────────────────────────────────────
class _WebChip extends StatelessWidget {
  const _WebChip({
    required this.label,
    required this.count,
    required this.isSelected,
    required this.onTap,
    this.isAll = false,
  });

  final String label;
  final int count;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isAll;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isAll)
              Padding(
                padding: const EdgeInsets.only(right: 5),
                child: Icon(
                  Icons.grid_view_rounded,
                  size: 13,
                  color: isSelected ? Colors.white : AppColors.textSecondary,
                ),
              ),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : AppColors.textPrimary,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white.withAlpha(60)
                    : AppColors.background,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? Colors.white : AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────
//  All-items Tab Body (index 0)
// ────────────────────────────────────────────────────────────────────
class _AllTabBody extends StatelessWidget {
  const _AllTabBody({
    required this.vm,
    required this.onRefresh,
    this.onEditItem,
  });

  final MenuViewModel vm;
  final Future<void> Function() onRefresh;
  final void Function(MenuItem)? onEditItem;

  @override
  Widget build(BuildContext context) {
    final items =
        vm.flatSearchResults; // no search query when not in search mode
    if (items.isEmpty) {
      final hasFilter = context.select<MenuViewModel, bool>(
        (vm) => vm.vegOnly || vm.nonVegOnly || vm.availableOnly,
      );
      return RefreshIndicator(
        onRefresh: onRefresh,
        color: AppColors.primary,
        child: ListView(
          children: [
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.5,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.no_food_outlined,
                      size: 52,
                      color: AppColors.textHint,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      hasFilter
                          ? 'No items match the active filters'
                          : 'No menu items yet',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: onRefresh,
      color: AppColors.primary,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
        itemCount: items.length,
        itemBuilder: (ctx, i) => _MenuItemCard(
          item: items[i],
          onEdit: () => onEditItem?.call(items[i]),
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────
//  Category Tab Body
// ────────────────────────────────────────────────────────────────────
class _CategoryTabBody extends StatelessWidget {
  const _CategoryTabBody({
    required this.category,
    required this.filteredItems,
    required this.onRefresh,
    this.onEditItem,
  });

  final MenuCategory category;
  final List<MenuItem> filteredItems;
  final Future<void> Function() onRefresh;
  final void Function(MenuItem)? onEditItem;

  @override
  Widget build(BuildContext context) {
    final hasActiveFilter = context.select<MenuViewModel, bool>(
      (vm) => vm.vegOnly || vm.availableOnly,
    );

    if (filteredItems.isEmpty) {
      final msg = hasActiveFilter
          ? 'No items match the active filters'
          : 'No items in this category';
      return RefreshIndicator(
        onRefresh: onRefresh,
        color: AppColors.primary,
        child: ListView(
          children: [
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.5,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.no_food_outlined,
                      size: 52,
                      color: AppColors.textHint,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      msg,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      color: AppColors.primary,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
        itemCount: filteredItems.length,
        itemBuilder: (ctx, i) => _MenuItemCard(
          item: filteredItems[i],
          onEdit: () => onEditItem?.call(filteredItems[i]),
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────
//  Menu Item Card
// ────────────────────────────────────────────────────────────────────
class _MenuItemCard extends StatelessWidget {
  const _MenuItemCard({required this.item, this.onEdit});

  final MenuItem item;
  final VoidCallback? onEdit;

  Future<void> _confirmDelete(BuildContext ctx) async {
    final vm = ctx.read<MenuViewModel>();
    final confirmed = await showDialog<bool>(
      context: ctx,
      builder: (_) => AlertDialog(
        title: const Text('Delete item?'),
        content: Text('"${item.name}" will be permanently removed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true && ctx.mounted) {
      final ok = await vm.deleteItem(item.id);
      if (!ok && ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(
            content: Text(vm.error ?? 'Delete failed'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
        vm.clearError();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.read<MenuViewModel>();
    final toggling = context.select<MenuViewModel, bool>(
      (v) => v.isToggling(item.id),
    );
    final deleting = context.select<MenuViewModel, bool>(
      (v) => v.isDeleting(item.id),
    );
    final inSelect = context.select<MenuViewModel, bool>(
      (v) => v.selectionMode,
    );
    final selected = context.select<MenuViewModel, bool>(
      (v) => v.isSelected(item.id),
    );
    final currFmt = NumberFormat.currency(symbol: '₹', decimalDigits: 0);
    final hasDiscount =
        item.discountedPrice != null && item.discountedPrice! < item.price;

    if (deleting) {
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Row(
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.error,
              ),
            ),
            SizedBox(width: 12),
            Text(
              'Deleting…',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return GestureDetector(
      onTap: inSelect ? () => vm.toggleItemSelection(item.id) : null,
      onLongPress: !inSelect
          ? () {
              vm.toggleSelectionMode();
              vm.toggleItemSelection(item.id);
            }
          : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary.withAlpha(8) : AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: selected
              ? Border.all(color: AppColors.primary.withAlpha(80), width: 1.5)
              : null,
          boxShadow: selected
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withAlpha(15),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Main row: checkbox + image + info + toggle ────────
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (inSelect) ...[
                    Padding(
                      padding: const EdgeInsets.only(top: 8, right: 8),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: selected
                              ? AppColors.primary
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: selected
                                ? AppColors.primary
                                : AppColors.borderLight,
                            width: 2,
                          ),
                        ),
                        child: selected
                            ? const Icon(
                                Icons.check_rounded,
                                size: 16,
                                color: Colors.white,
                              )
                            : null,
                      ),
                    ),
                  ],
                  _ItemImage(imageUrl: item.imageUrl),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Name row + veg indicator
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _VegIndicator(isVeg: item.isVeg),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                item.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                  color: AppColors.textPrimary,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        if (item.description.isNotEmpty)
                          Text(
                            item.description,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                              height: 1.4,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        // ── Meta: prep time · serves · calories · spice ──
                        _ItemMeta(item: item),
                        const SizedBox(height: 8),
                        // Pricing
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              currFmt.format(item.effectivePrice),
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                                color: hasDiscount
                                    ? AppColors.success
                                    : AppColors.textPrimary,
                              ),
                            ),
                            if (hasDiscount) ...[
                              const SizedBox(width: 6),
                              Text(
                                currFmt.format(item.price),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textHint,
                                  decoration: TextDecoration.lineThrough,
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 6),
                        _BadgeRow(item: item),
                      ],
                    ),
                  ),
                  if (!inSelect) ...[
                    const SizedBox(width: 4),
                    _AvailabilityToggle(
                      item: item,
                      toggling: toggling,
                      onChanged: (val) =>
                          vm.toggleAvailability(item.id, newValue: val),
                    ),
                  ],
                ],
              ),
            ),
            // ── Actions row (hidden in selection mode) ───────────
            if (!inSelect) ...[
              Container(
                decoration: const BoxDecoration(
                  border: Border(
                    top: BorderSide(color: AppColors.borderLight, width: 1),
                  ),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: onEdit,
                      icon: const Icon(Icons.edit_outlined, size: 14),
                      label:
                          const Text('Edit', style: TextStyle(fontSize: 12)),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        minimumSize: Size.zero,
                      ),
                    ),
                    const SizedBox(width: 4),
                    TextButton.icon(
                      onPressed: () => _confirmDelete(context),
                      icon: const Icon(Icons.delete_outline, size: 14),
                      label: const Text('Delete',
                          style: TextStyle(fontSize: 12)),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.error,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        minimumSize: Size.zero,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            // ── Unavailable banner ──────────────────────────────────
            if (!item.isAvailable)
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: const BoxDecoration(
                  color: Color(0xFFFFF3F3),
                  borderRadius: BorderRadius.vertical(
                    bottom: Radius.circular(14),
                  ),
                ),
                child: const Text(
                  'Currently unavailable',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.error,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────
//  Item meta: prep time, serves, calories, spice, gluten-free
// ────────────────────────────────────────────────────────────────────
class _ItemMeta extends StatelessWidget {
  const _ItemMeta({required this.item});
  final MenuItem item;

  @override
  Widget build(BuildContext context) {
    final parts = <Widget>[];

    if (item.preparationTime != null) {
      parts.add(_metaChip(Icons.timer_outlined, '${item.preparationTime} min'));
    }
    if (item.serves != null) {
      parts.add(_metaChip(Icons.people_outline, 'Serves ${item.serves}'));
    }
    if (item.calories != null) {
      parts.add(
        _metaChip(Icons.local_fire_department_outlined, '${item.calories} cal'),
      );
    }
    if (item.spiceLevel != 'none' && item.spiceLevel.isNotEmpty) {
      parts.add(
        _metaChip(Icons.whatshot_outlined, _capitalise(item.spiceLevel)),
      );
    }
    if (item.isGlutenFree) {
      parts.add(
        _metaChip(Icons.check_circle_outline, 'GF', color: AppColors.success),
      );
    }

    if (parts.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 5),
      child: Wrap(spacing: 10, runSpacing: 3, children: parts),
    );
  }

  Widget _metaChip(
    IconData icon,
    String label, {
    Color color = AppColors.textHint,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 11, color: color),
        const SizedBox(width: 3),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: color,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  static String _capitalise(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

// ────────────────────────────────────────────────────────────────────
//  Search bar
// ────────────────────────────────────────────────────────────────────
class _MenuSearchBar extends StatelessWidget {
  const _MenuSearchBar({required this.controller, required this.vm});
  final TextEditingController controller;
  final MenuViewModel vm;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: TextField(
        controller: controller,
        onChanged: vm.setSearch,
        textInputAction: TextInputAction.search,
        style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
        decoration: InputDecoration(
          hintText: 'Search menu items…',
          hintStyle: const TextStyle(fontSize: 13, color: AppColors.textHint),
          prefixIcon: const Icon(
            Icons.search,
            size: 20,
            color: AppColors.textHint,
          ),
          suffixIcon: vm.isSearchActive
              ? IconButton(
                  icon: const Icon(
                    Icons.close,
                    size: 18,
                    color: AppColors.textSecondary,
                  ),
                  onPressed: () {
                    controller.clear();
                    vm.setSearch('');
                  },
                )
              : null,
          filled: true,
          fillColor: AppColors.background,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 10,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(
              color: AppColors.borderLight,
              width: 1,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
          ),
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────
//  Filter chips: Veg only · Available only
// ────────────────────────────────────────────────────────────────────
class _FilterChips extends StatelessWidget {
  const _FilterChips({required this.vm});
  final MenuViewModel vm;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Row(
        children: [
          _chip(
            label: '🌱 Veg only',
            active: vm.vegOnly,
            onTap: () => context.read<MenuViewModel>().toggleVegOnly(),
          ),
          const SizedBox(width: 8),
          _chip(
            label: '🍗 Non-Veg',
            active: vm.nonVegOnly,
            onTap: () => context.read<MenuViewModel>().toggleNonVegOnly(),
          ),
          const SizedBox(width: 8),
          _chip(
            label: '✅ Available',
            active: vm.availableOnly,
            onTap: () => context.read<MenuViewModel>().toggleAvailableOnly(),
          ),
          if (vm.vegOnly || vm.nonVegOnly || vm.availableOnly) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => context.read<MenuViewModel>().clearFilters(),
              child: const Text(
                'Clear all',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _chip({
    required String label,
    required bool active,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? AppColors.primary : AppColors.background,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: active ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────
//  Flat search results (cross-category)
// ────────────────────────────────────────────────────────────────────
class _FlatSearchResults extends StatelessWidget {
  const _FlatSearchResults({
    required this.vm,
    required this.onRefresh,
    this.onEditItem,
  });
  final MenuViewModel vm;
  final Future<void> Function() onRefresh;
  final void Function(MenuItem)? onEditItem;

  @override
  Widget build(BuildContext context) {
    final results = vm.flatSearchResults;
    if (results.isEmpty) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        color: AppColors.primary,
        child: ListView(
          children: [
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.4,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.search_off,
                      size: 56,
                      color: AppColors.textHint,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No items found for "${vm.searchQuery}"',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: onRefresh,
      color: AppColors.primary,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
        itemCount: results.length,
        itemBuilder: (ctx, i) => _MenuItemCard(
          item: results[i],
          onEdit: () => onEditItem?.call(results[i]),
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────
//  Item Image
// ────────────────────────────────────────────────────────────────────
class _ItemImage extends StatelessWidget {
  const _ItemImage({required this.imageUrl});

  final String imageUrl;

  /// Returns a fully-qualified URL.
  /// If [imageUrl] is relative (starts with '/'), prepend the server origin.
  static String _resolve(String url) {
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    // Strip '/api' suffix from baseUrl to get the server root
    const base = 'http://localhost:8000';
    return '$base$url';
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: CachedNetworkImage(
        imageUrl: _resolve(imageUrl),
        width: 80,
        height: 80,
        fit: BoxFit.cover,
        placeholder: (_, _) => Container(
          width: 80,
          height: 80,
          color: AppColors.shimmerBase,
          child: const Icon(
            Icons.fastfood_outlined,
            color: AppColors.textHint,
            size: 32,
          ),
        ),
        errorWidget: (_, _, _) => Container(
          width: 80,
          height: 80,
          color: AppColors.background,
          child: const Icon(
            Icons.fastfood_outlined,
            color: AppColors.textHint,
            size: 32,
          ),
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────
//  Veg indicator (FSSAI-style: bordered square + filled circle)
// ────────────────────────────────────────────────────────────────────
class _VegIndicator extends StatelessWidget {
  const _VegIndicator({required this.isVeg});

  final bool isVeg;

  @override
  Widget build(BuildContext context) {
    final color = isVeg ? AppColors.success : AppColors.error;
    return Container(
      width: 16,
      height: 16,
      margin: const EdgeInsets.only(top: 1),
      decoration: BoxDecoration(
        border: Border.all(color: color, width: 1.5),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Center(
        child: Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────
//  Badge row: Bestseller / Featured / New / Vegan
// ────────────────────────────────────────────────────────────────────
class _BadgeRow extends StatelessWidget {
  const _BadgeRow({required this.item});

  final MenuItem item;

  @override
  Widget build(BuildContext context) {
    final badges = <Widget>[];
    if (item.isBestseller) {
      badges.add(
        const _SmallBadge(
          label: '🔥 Bestseller',
          bg: Color(0xFFFFF3CD),
          fg: Color(0xFF856404),
        ),
      );
    }
    if (item.isFeatured) {
      badges.add(
        const _SmallBadge(
          label: '⭐ Featured',
          bg: Color(0xFFE8F4FF),
          fg: Color(0xFF0A68DA),
        ),
      );
    }
    if (item.isNew) {
      badges.add(
        const _SmallBadge(
          label: '✨ New',
          bg: AppColors.successLight,
          fg: AppColors.success,
        ),
      );
    }
    if (item.isVegan) {
      badges.add(
        const _SmallBadge(
          label: '🌱 Vegan',
          bg: AppColors.successLight,
          fg: AppColors.success,
        ),
      );
    }
    if (badges.isEmpty) return const SizedBox.shrink();
    return Wrap(spacing: 6, runSpacing: 4, children: badges);
  }
}

class _SmallBadge extends StatelessWidget {
  const _SmallBadge({required this.label, required this.bg, required this.fg});

  final String label;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: fg),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────
//  Availability toggle — spinner while toggling
// ────────────────────────────────────────────────────────────────────
class _AvailabilityToggle extends StatelessWidget {
  const _AvailabilityToggle({
    required this.item,
    required this.toggling,
    required this.onChanged,
  });

  final MenuItem item;
  final bool toggling;
  final void Function(bool) onChanged;

  @override
  Widget build(BuildContext context) {
    final available = item.isAvailable;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (toggling)
          const SizedBox(
            width: 42,
            height: 26,
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
          )
        else
          SizedBox(
            height: 26,
            child: FittedBox(
              child: CupertinoSwitch(
                value: available,
                onChanged: onChanged,
                activeTrackColor: AppColors.success,
              ),
            ),
          ),
        const SizedBox(height: 4),
        Text(
          available ? 'In Stock' : 'Out of Stock',
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
            color: available ? AppColors.success : AppColors.textHint,
          ),
        ),
      ],
    );
  }
}

// ────────────────────────────────────────────────────────────────────
//  Shimmer placeholder card
// ────────────────────────────────────────────────────────────────────
class _ShimmerCard extends StatelessWidget {
  const _ShimmerCard();

  Widget _box({double w = double.infinity, double h = 14, double r = 6}) =>
      Container(
        width: w,
        height: h,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(r),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _box(w: 80, h: 80, r: 10),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _box(w: 130, h: 14),
                const SizedBox(height: 7),
                _box(h: 11),
                const SizedBox(height: 4),
                _box(w: 180, h: 11),
                const SizedBox(height: 10),
                _box(w: 60, h: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
//  Menu Stats Row  — compact 3-badge strip beneath the AppBar
// ─────────────────────────────────────────────────────────────────────
class _MenuStatsRow extends StatelessWidget {
  const _MenuStatsRow({required this.vm});
  final MenuViewModel vm;

  @override
  Widget build(BuildContext context) {
    final total = vm.totalItemCount;
    final available = vm.availableItemsCount;
    final outOfStock = vm.outOfStockItemsCount;

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          bottom: BorderSide(color: AppColors.borderLight, width: 1),
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: IntrinsicHeight(
        child: Row(
          children: [
            _StatBadge(
              count: total,
              label: 'Total',
              dotColor: AppColors.primary,
            ),
            const VerticalDivider(
              width: 1,
              thickness: 1,
              color: AppColors.borderLight,
              indent: 6,
              endIndent: 6,
            ),
            _StatBadge(
              count: available,
              label: 'Active',
              dotColor: AppColors.success,
            ),
            const VerticalDivider(
              width: 1,
              thickness: 1,
              color: AppColors.borderLight,
              indent: 6,
              endIndent: 6,
            ),
            _StatBadge(
              count: outOfStock,
              label: 'Out of Stock',
              dotColor: const Color(0xFFFF7675),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatBadge extends StatelessWidget {
  const _StatBadge({
    required this.count,
    required this.label,
    required this.dotColor,
  });

  final int count;
  final String label;
  final Color dotColor;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: dotColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 5),
              Text(
                '$count',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  height: 1.1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────
//  Bulk Action Bar — sticky bottom bar in selection mode
// ────────────────────────────────────────────────────────────────────
class _BulkActionBar extends StatelessWidget {
  const _BulkActionBar({required this.vm});
  final MenuViewModel vm;

  @override
  Widget build(BuildContext context) {
    final hasSelection = vm.selectedCount > 0;
    final updating = vm.bulkUpdating;

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(10),
              blurRadius: 10,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (updating)
              const Padding(
                padding: EdgeInsets.only(bottom: 10),
                child: LinearProgressIndicator(
                  color: AppColors.primary,
                  backgroundColor: AppColors.borderLight,
                ),
              ),
            Text(
              hasSelection
                  ? '${vm.selectedCount} item${vm.selectedCount == 1 ? '' : 's'} selected'
                  : 'Tap items to select',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: hasSelection
                    ? AppColors.textPrimary
                    : AppColors.textHint,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 46,
                    child: ElevatedButton.icon(
                      onPressed: hasSelection && !updating
                          ? () => _bulkAction(context, available: true)
                          : null,
                      icon: const Icon(Icons.check_circle_outline, size: 18),
                      label: const Text(
                        'Mark In-Stock',
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w700),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: AppColors.success.withAlpha(60),
                        disabledForegroundColor: Colors.white60,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 46,
                    child: ElevatedButton.icon(
                      onPressed: hasSelection && !updating
                          ? () => _bulkAction(context, available: false)
                          : null,
                      icon: const Icon(Icons.remove_circle_outline, size: 18),
                      label: const Text(
                        'Mark Out-of-Stock',
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w700),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.error,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: AppColors.error.withAlpha(60),
                        disabledForegroundColor: Colors.white60,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _bulkAction(
    BuildContext context, {
    required bool available,
  }) async {
    final count = vm.selectedCount;
    final label = available ? 'In-Stock' : 'Out-of-Stock';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Mark $label?'),
        content: Text(
          'Update $count item${count == 1 ? '' : 's'} to $label?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(
              foregroundColor:
                  available ? AppColors.success : AppColors.error,
            ),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    final successCount =
        await vm.bulkUpdateAvailability(available: available);

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$successCount item${successCount == 1 ? '' : 's'} updated to $label'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: available ? AppColors.success : AppColors.textSecondary,
      ),
    );
  }
}
