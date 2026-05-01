// ─────────────────────────────────────────
// Zill Restaurant Partner — Vendor App
// ─────────────────────────────────────────
//
// Smart "Complete your profile" bottom sheet shared by:
//   • Profile header progress bar (tap to open)
//   • Dashboard "Complete your Setup" banner (tap to open)
//
// Computes a list of *missing* setup tasks by combining:
//   • Backend `profile_completion.sections` from /vendors/dashboard/
//     (the same six fields that drive the percentage)
//   • Local checks for KYC verification status, bank account, and a
//     few high-value optional fields (description, cost-for-two,
//     restaurant type) that the backend doesn't track but vendors
//     should still fill in for a polished storefront.
//
// Each missing task renders as a tappable tile that closes the sheet
// and routes the vendor straight to the right screen — no hunting
// through menus.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/services/api_service.dart';
import '../../home/view/app_shell.dart';
import '../../menu/view/manage_categories_screen.dart';
import '../view/bank_account_screen.dart';
import '../view/edit_profile_screen.dart';
import '../view/operating_hours_screen.dart';
import '../viewmodel/profile_viewmodel.dart';

/// Public entry point — call from anywhere with a [BuildContext] that
/// has [ProfileViewModel] in its provider tree.
void showCompleteProfileSheet(BuildContext context) {
  // Bind a tab-switch closure to the *calling* context so the sheet
  // can route to the Menu tab. Bottom sheets render in a separate
  // Overlay route; their builder context is a sibling of AppShell,
  // not a descendant, so `AppShell.switchTab(sheetCtx, ...)` from
  // inside the sheet silently no-ops. This was why "Add menu items"
  // looked dead on tap — the sheet popped, but the tab never moved.
  void switchTab(int index) => AppShell.switchTab(context, index);

  showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _CompleteProfileSheet(onSwitchTab: switchTab),
  );
}

// ────────────────────────────────────────────────────────────────────
//  Task model
// ────────────────────────────────────────────────────────────────────

enum _TaskPriority { required_, recommended }

class _ProfileTask {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final _TaskPriority priority;
  final void Function(BuildContext) onTap;

  const _ProfileTask({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.priority,
    required this.onTap,
  });
}

// ────────────────────────────────────────────────────────────────────
//  Sheet body
// ────────────────────────────────────────────────────────────────────

class _CompleteProfileSheet extends StatelessWidget {
  /// Closure bound to the parent (AppShell-descendant) context.
  /// Required for the "Add menu items" tile — see the comment at
  /// [showCompleteProfileSheet] for why we can't call
  /// `AppShell.switchTab` with the sheet's own builder context.
  final void Function(int index) onSwitchTab;

  const _CompleteProfileSheet({required this.onSwitchTab});

  // ── Helpers to push specific screens, then refresh the profile ──
  void _go(BuildContext context, Widget page) {
    Navigator.of(context).pop(); // close the sheet
    final root = Navigator.of(context, rootNavigator: false);
    final messenger = ScaffoldMessenger.maybeOf(context);
    final vm = context.read<ProfileViewModel>();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await root.push<void>(MaterialPageRoute(builder: (_) => page));
      // Refresh profile state when the user returns from any task
      // screen — keeps the percentage + missing-task list in sync.
      try {
        await vm.fetchProfile();
      } catch (_) {
        // Best-effort; surface nothing if it fails.
      }
      messenger?.hideCurrentSnackBar();
    });
  }

  void _goNamed(BuildContext context, String routeName) {
    Navigator.of(context).pop();
    final nav = Navigator.of(context);
    final vm = context.read<ProfileViewModel>();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await nav.pushNamed(routeName);
      try {
        await vm.fetchProfile();
      } catch (_) {}
    });
  }

  /// Build the missing-task list from backend sections + local checks.
  List<_ProfileTask> _missingTasks(BuildContext context, ProfileViewModel vm) {
    final data = vm.data;
    final sections = vm.profileCompletionSections;
    final tasks = <_ProfileTask>[];

    // ── Backend section #1: basic_info (name + phone + address) ──
    if (sections['basic_info'] != true) {
      tasks.add(
        _ProfileTask(
          icon: Icons.store_rounded,
          iconColor: AppColors.primary,
          title: 'Add basic restaurant info',
          subtitle: 'Name, phone and address — required to go live',
          priority: _TaskPriority.required_,
          onTap: (ctx) => _go(ctx, const EditProfileScreen()),
        ),
      );
    }

    // ── Backend section #2: images ──
    if (sections['images'] != true) {
      tasks.add(
        _ProfileTask(
          icon: Icons.add_a_photo_rounded,
          iconColor: AppColors.info,
          title: 'Upload restaurant photo',
          subtitle: 'A logo or storefront photo customers will see',
          priority: _TaskPriority.required_,
          onTap: (ctx) async {
            // Close the sheet first, then directly trigger the same
            // picker the profile-screen avatar tap uses. No matter
            // which tab the user opened the sheet from, this works.
            final messenger = ScaffoldMessenger.maybeOf(ctx);
            Navigator.of(ctx).pop();
            try {
              await vm.pickProfileImage();
              if (vm.localProfileImage == null) return;
              final ok = await vm.uploadProfileImage();
              messenger?.showSnackBar(
                SnackBar(
                  content: Text(
                    ok
                        ? 'Photo updated!'
                        : vm.errorMessage ?? 'Upload failed',
                  ),
                  backgroundColor:
                      ok ? AppColors.success : AppColors.error,
                  behavior: SnackBarBehavior.floating,
                ),
              );
              if (ok) await vm.fetchProfile();
            } catch (_) {
              messenger?.showSnackBar(
                const SnackBar(
                  content: Text('Could not upload photo. Try again.'),
                  backgroundColor: AppColors.error,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          },
        ),
      );
    }

    // ── Backend section #3: operating_hours ──
    if (sections['operating_hours'] != true) {
      tasks.add(
        _ProfileTask(
          icon: Icons.access_time_filled_rounded,
          iconColor: AppColors.purple,
          title: 'Set operating hours',
          subtitle: 'Tell customers when you\'re open',
          priority: _TaskPriority.required_,
          onTap: (ctx) => _go(
            ctx,
            OperatingHoursScreen(apiService: ctx.read<ApiService>()),
          ),
        ),
      );
    }

    // ── Backend section #4: delivery_zones ──
    if (sections['delivery_zones'] != true) {
      tasks.add(
        _ProfileTask(
          icon: Icons.radar_rounded,
          iconColor: AppColors.teal,
          title: 'Set delivery zones',
          subtitle: 'Choose where you\'ll deliver',
          priority: _TaskPriority.required_,
          onTap: (ctx) => _goNamed(ctx, AppRouter.deliveryZones),
        ),
      );
    }

    // ── Backend section #5: categories ──
    if (sections['categories'] != true) {
      tasks.add(
        _ProfileTask(
          icon: Icons.category_rounded,
          iconColor: AppColors.amber,
          title: 'Create menu categories',
          subtitle: 'Group your dishes — e.g. Starters, Mains, Desserts',
          priority: _TaskPriority.required_,
          onTap: (ctx) => _go(ctx, const ManageCategoriesScreen()),
        ),
      );
    }

    // ── Backend section #6: menu_items ──
    if (sections['menu_items'] != true) {
      tasks.add(
        _ProfileTask(
          icon: Icons.restaurant_menu_rounded,
          iconColor: AppColors.success,
          title: 'Add menu items',
          subtitle: 'At least one item is required to start orders',
          priority: _TaskPriority.required_,
          // Switch to the Menu tab inside AppShell — pushing
          // MenuScreen() as a new MaterialPageRoute would create
          // a duplicate scaffold without the bottom nav bar.
          // `onSwitchTab` is bound to the parent context (where
          // AppShell IS reachable). Calling switchTab with the
          // sheet's builder context would silently no-op because
          // the modal route is a sibling of AppShell, not a child.
          onTap: (ctx) {
            Navigator.of(ctx).pop();
            onSwitchTab(2);
          },
        ),
      );
    }

    // ── KYC verification (not in backend sections, but blocks orders) ──
    if (!data.verificationStatus.isApproved) {
      tasks.add(
        _ProfileTask(
          icon: Icons.verified_user_rounded,
          iconColor: AppColors.warning,
          title: 'Upload KYC documents',
          subtitle: 'FSSAI, PAN and Bank docs for verification',
          priority: _TaskPriority.required_,
          onTap: (ctx) => _goNamed(ctx, AppRouter.kycDocuments),
        ),
      );
    }

    // ── Bank account for payouts ──
    if (!data.hasBankAccount) {
      tasks.add(
        _ProfileTask(
          icon: Icons.account_balance_rounded,
          iconColor: AppColors.success,
          title: 'Add bank account',
          subtitle: 'Required to receive payouts from your orders',
          priority: _TaskPriority.required_,
          onTap: (ctx) => _go(
            ctx,
            BankAccountScreen(apiService: ctx.read<ApiService>()),
          ),
        ),
      );
    }

    // ── Recommended (not enforced by backend, but high-value) ──
    if (data.description.isEmpty) {
      tasks.add(
        _ProfileTask(
          icon: Icons.description_rounded,
          iconColor: AppColors.info,
          title: 'Add a description',
          subtitle: 'Tell customers what makes your food special',
          priority: _TaskPriority.recommended,
          onTap: (ctx) => _go(ctx, const EditProfileScreen()),
        ),
      );
    }

    if (data.restaurantType.isEmpty) {
      tasks.add(
        _ProfileTask(
          icon: Icons.label_outline_rounded,
          iconColor: AppColors.purple,
          title: 'Pick a restaurant type',
          subtitle: 'e.g. Cafe, Cloud Kitchen, Fine Dining',
          priority: _TaskPriority.recommended,
          onTap: (ctx) => _go(ctx, const EditProfileScreen()),
        ),
      );
    }

    if (data.costForTwo == 0) {
      tasks.add(
        _ProfileTask(
          icon: Icons.currency_rupee_rounded,
          iconColor: AppColors.amber,
          title: 'Set "cost for two"',
          subtitle: 'Helps customers understand your pricing',
          priority: _TaskPriority.recommended,
          onTap: (ctx) => _go(ctx, const EditProfileScreen()),
        ),
      );
    }

    return tasks;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ProfileViewModel>(
      builder: (context, vm, _) {
        final tasks = _missingTasks(context, vm);
        final percentage = vm.profileCompletionPercentage ?? 0;
        final required = tasks
            .where((t) => t.priority == _TaskPriority.required_)
            .toList();
        final recommended = tasks
            .where((t) => t.priority == _TaskPriority.recommended)
            .toList();

        return SafeArea(
          top: false,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.78,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Drag handle ──
                Container(
                  margin: const EdgeInsets.only(top: 10, bottom: 6),
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                // ── Header (title + percentage progress bar) ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withAlpha(28),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.assignment_turned_in_rounded,
                              color: AppColors.primary,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Complete your profile',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withAlpha(28),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '$percentage%',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: percentage / 100,
                          minHeight: 6,
                          backgroundColor: AppColors.borderLight,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            percentage < 50
                                ? AppColors.warning
                                : percentage < 80
                                    ? AppColors.primary
                                    : AppColors.success,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        tasks.isEmpty
                            ? 'Everything looks good — you\'re ready to go!'
                            : 'Finish ${required.length} '
                                'required step${required.length == 1 ? '' : 's'} '
                                'to start receiving orders',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),

                const Divider(height: 1, color: AppColors.borderLight),

                // ── Task list ──
                Flexible(
                  child: tasks.isEmpty
                      ? _EmptyAllDone()
                      : ListView(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          children: [
                            if (required.isNotEmpty) ...[
                              _SectionLabel(
                                label: 'Required to go live',
                                color: AppColors.error,
                              ),
                              for (final t in required) _TaskTile(task: t),
                            ],
                            if (recommended.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              _SectionLabel(
                                label: 'Recommended',
                                color: AppColors.info,
                              ),
                              for (final t in recommended)
                                _TaskTile(task: t),
                            ],
                            const SizedBox(height: 8),
                          ],
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ────────────────────────────────────────────────────────────────────
//  Sub-widgets
// ────────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  final Color color;
  const _SectionLabel({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 6),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }
}

class _TaskTile extends StatelessWidget {
  final _ProfileTask task;
  const _TaskTile({required this.task});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => task.onTap(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: task.iconColor.withAlpha(28),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(task.icon, color: task.iconColor, size: 21),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    task.subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textHint,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textHint,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyAllDone extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSizes.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.success.withAlpha(28),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle_rounded,
              color: AppColors.success,
              size: 36,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'All set!',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Your profile is complete and you\'re ready to receive orders.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12.5,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                'Done',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
