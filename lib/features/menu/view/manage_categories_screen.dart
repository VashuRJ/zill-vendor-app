import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../viewmodel/menu_viewmodel.dart';
import 'add_edit_category_sheet.dart';

// ────────────────────────────────────────────────────────────────────
//  Manage Categories Screen
// ────────────────────────────────────────────────────────────────────
class ManageCategoriesScreen extends StatelessWidget {
  const ManageCategoriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Manage Categories',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
      ),
      body: Consumer<MenuViewModel>(
        builder: (context, vm, _) {
          // Filter out the synthetic "Uncategorized" bucket (id == -1)
          final cats =
              vm.categories.where((c) => c.id != -1).toList();

          if (vm.status == MenuStatus.loading && cats.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (cats.isEmpty) {
            return _buildEmpty(context);
          }

          return Column(
            children: [
              // ── Stats bar ─────────────────────────────────────────
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                color: AppColors.surface,
                child: Row(
                  children: [
                    _StatChip(
                      icon: Icons.category_rounded,
                      label: '${cats.length}',
                      sub: 'Categories',
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 12),
                    _StatChip(
                      icon: Icons.restaurant_menu_rounded,
                      label: '${vm.totalItemCount}',
                      sub: 'Total Items',
                      color: AppColors.info,
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: AppColors.borderLight),

              // ── List ──────────────────────────────────────────────
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () => vm.fetchMenu(),
                  color: AppColors.primary,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                    itemCount: cats.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final cat = cats[index];
                      return _CategoryCard(category: cat);
                    },
                  ),
                ),
              ),
            ],
          );
        },
      ),

      // ── Sticky bottom button ─────────────────────────────────────
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(8),
                blurRadius: 8,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: SizedBox(
            height: 50,
            child: ElevatedButton.icon(
              onPressed: () => _openSheet(context),
              icon: const Icon(Icons.add_rounded, size: 20),
              label: const Text(
                'Add Category',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.primary.withAlpha(15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.category_outlined,
                size: 48,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'No Categories Yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Create your first menu category\nto organize your items.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _openSheet(context),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Create Category'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
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

  void _openSheet(BuildContext context, {MenuCategory? category}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddEditCategorySheet(category: category),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
//  Category Card
// ─────────────────────────────────────────────────────────────────────

class _CategoryCard extends StatelessWidget {
  final MenuCategory category;
  const _CategoryCard({required this.category});

  @override
  Widget build(BuildContext context) {
    final itemCount = category.items.length;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            // ── Icon ────────────────────────────────────────
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.primary.withAlpha(15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  category.name.isNotEmpty
                      ? category.name[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),

            // ── Name + meta ─────────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    category.name,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '$itemCount item${itemCount == 1 ? '' : 's'} · Order #${category.displayOrder}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  if (category.description.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      category.description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textHint,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // ── Actions ─────────────────────────────────────
            _ActionIcon(
              icon: Icons.edit_outlined,
              color: AppColors.info,
              onTap: () => _edit(context),
            ),
            const SizedBox(width: 4),
            _ActionIcon(
              icon: Icons.delete_outline_rounded,
              color: AppColors.error,
              onTap: () => _confirmDelete(context),
            ),
          ],
        ),
      ),
    );
  }

  void _edit(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddEditCategorySheet(category: category),
    );
  }

  void _confirmDelete(BuildContext context) {
    final itemCount = category.items.length;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Category'),
        content: Text(
          itemCount > 0
              ? 'This will deactivate "${category.name}" and its $itemCount item${itemCount == 1 ? '' : 's'} will become uncategorized.\n\nContinue?'
              : 'Delete "${category.name}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<MenuViewModel>().deleteCategory(category.id);
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────

class _ActionIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionIcon({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withAlpha(12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 18, color: color),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sub;
  final Color color;

  const _StatChip({
    required this.icon,
    required this.label,
    required this.sub,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: color.withAlpha(10),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withAlpha(30)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
                Text(
                  sub,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
