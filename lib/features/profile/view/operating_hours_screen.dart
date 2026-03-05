import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/services/api_service.dart';
import '../viewmodel/operating_hours_viewmodel.dart';

// ─────────────────────────────────────────────────────────────────────
//  Route entry-point — wraps its own ViewModel
// ─────────────────────────────────────────────────────────────────────
class OperatingHoursScreen extends StatelessWidget {
  const OperatingHoursScreen({super.key, required this.apiService});

  final ApiService apiService;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => OperatingHoursViewModel(apiService: apiService),
      child: const _OperatingHoursView(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
//  Main view
// ─────────────────────────────────────────────────────────────────────
class _OperatingHoursView extends StatefulWidget {
  const _OperatingHoursView();

  @override
  State<_OperatingHoursView> createState() => _OperatingHoursViewState();
}

class _OperatingHoursViewState extends State<_OperatingHoursView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final vm = context.read<OperatingHoursViewModel>();
      vm.addListener(_onVmChange);
      vm.fetchOperatingHours();
    });
  }

  @override
  void dispose() {
    try {
      context.read<OperatingHoursViewModel>().removeListener(_onVmChange);
    } catch (_) {}
    super.dispose();
  }

  /// Show a snackbar for save errors; fetch errors use the full-screen view.
  void _onVmChange() {
    if (!mounted) return;
    final vm = context.read<OperatingHoursViewModel>();
    if (vm.status == HoursStatus.error && !vm.isFetchError) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: Text(
              vm.errorMessage ?? 'Failed to save. Please try again.',
            ),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSizes.radiusMd),
            ),
            margin: const EdgeInsets.all(AppSizes.md),
            duration: const Duration(seconds: 4),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<OperatingHoursViewModel>();

    Widget body;
    if (vm.status == HoursStatus.fetching) {
      body = const _LoadingView();
    } else if (vm.isFetchError) {
      body = _FetchErrorView(
        message: vm.errorMessage ?? 'Could not load operating hours.',
        onRetry: context.read<OperatingHoursViewModel>().fetchOperatingHours,
      );
    } else {
      final openCount = vm.schedule.where((d) => d.isOpen).length;
      body = Column(
        children: [
          // ── Info banner ────────────────────────────────────────────
          _InfoBanner(openCount: openCount),

          // ── Day cards ──────────────────────────────────────────────
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(
                AppSizes.md,
                AppSizes.sm,
                AppSizes.md,
                AppSizes.xl,
              ),
              itemCount: vm.schedule.length,
              itemBuilder: (_, i) =>
                  _DayCard(index: i, day: vm.schedule[i], vm: vm),
            ),
          ),
        ],
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Operating Hours'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.borderLight),
        ),
      ),
      body: body,
      bottomNavigationBar: vm.isFetchError ? null : _SaveBar(vm: vm),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
//  Full-screen shimmer while data loads
// ─────────────────────────────────────────────────────────────────────
class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.shimmerBase,
      highlightColor: AppColors.shimmerHighlight,
      child: ListView.builder(
        padding: const EdgeInsets.all(AppSizes.md),
        itemCount: 7,
        itemBuilder: (_, _) => Container(
          height: 60,
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
//  Full-screen error with retry button
// ─────────────────────────────────────────────────────────────────────
class _FetchErrorView extends StatelessWidget {
  const _FetchErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_outlined,
              size: AppSizes.iconXl,
              color: AppColors.textHint,
            ),
            const SizedBox(height: AppSizes.md),
            Text(
              'Could not load schedule',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSizes.sm),
            Text(
              message,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSizes.lg),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_outlined, size: 17),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
//  Info banner
// ─────────────────────────────────────────────────────────────────────
class _InfoBanner extends StatelessWidget {
  const _InfoBanner({required this.openCount});

  final int openCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.md,
        vertical: AppSizes.sm + 2,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppSizes.radiusSm),
            ),
            child: const Icon(
              Icons.schedule_rounded,
              size: 18,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: AppSizes.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Set when your restaurant is open',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  '$openCount of 7 days open',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
//  Day card
// ─────────────────────────────────────────────────────────────────────
class _DayCard extends StatelessWidget {
  const _DayCard({required this.index, required this.day, required this.vm});

  final int index;
  final DaySchedule day;
  final OperatingHoursViewModel vm;

  @override
  Widget build(BuildContext context) {
    final isOpen = day.isOpen;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: AppSizes.sm + 4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        border: Border.all(
          color: isOpen
              ? AppColors.primary.withValues(alpha: 0.25)
              : AppColors.border,
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── Header: day label + toggle ─────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSizes.md,
              vertical: AppSizes.sm + 4,
            ),
            child: Row(
              children: [
                // Short-day chip
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: isOpen
                        ? AppColors.primary.withValues(alpha: 0.1)
                        : AppColors.background,
                    borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    day.shortDay,
                    style: TextStyle(
                      fontSize: AppSizes.fontXs + 1,
                      fontWeight: FontWeight.w800,
                      color: isOpen
                          ? AppColors.primary
                          : AppColors.textSecondary,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),

                const SizedBox(width: AppSizes.sm + 4),

                // Day name
                Expanded(
                  child: Text(
                    day.day,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),

                // Open/Closed label
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Text(
                    isOpen ? 'Open' : 'Closed',
                    key: ValueKey(isOpen),
                    style: TextStyle(
                      fontSize: AppSizes.fontSm,
                      fontWeight: FontWeight.w600,
                      color: isOpen
                          ? AppColors.success
                          : AppColors.textSecondary,
                    ),
                  ),
                ),

                const SizedBox(width: 4),

                // Toggle
                Switch.adaptive(
                  value: isOpen,
                  activeThumbColor: AppColors.success,
                  activeTrackColor: AppColors.success.withValues(alpha: 0.4),
                  inactiveThumbColor: AppColors.textHint,
                  inactiveTrackColor: AppColors.borderLight,
                  onChanged: (v) => vm.toggleDay(index, v),
                ),
              ],
            ),
          ),

          // ── Time pickers (visible only when open) ─────────────────
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 220),
            crossFadeState: isOpen
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            firstChild: Column(
              children: [
                Divider(
                  height: 1,
                  thickness: 1,
                  color: AppColors.primary.withValues(alpha: 0.12),
                ),
                Padding(
                  padding: const EdgeInsets.all(AppSizes.md),
                  child: Row(
                    children: [
                      // Opens at
                      Expanded(
                        child: _TimePickerButton(
                          icon: Icons.wb_sunny_outlined,
                          label: 'Opens at',
                          timeStr: day.formattedOpen,
                          onTap: () async {
                            final picked = await showTimePicker(
                              context: context,
                              initialTime: day.openTime,
                              helpText: 'Select opening time',
                              builder: (ctx, child) =>
                                  _themedTimePicker(ctx, child),
                            );
                            if (picked != null) {
                              vm.updateOpenTime(index, picked);
                            }
                          },
                        ),
                      ),

                      const SizedBox(width: AppSizes.sm + 2),

                      // Closes at
                      Expanded(
                        child: _TimePickerButton(
                          icon: Icons.nights_stay_outlined,
                          label: 'Closes at',
                          timeStr: day.formattedClose,
                          onTap: () async {
                            final picked = await showTimePicker(
                              context: context,
                              initialTime: day.closeTime,
                              helpText: 'Select closing time',
                              builder: (ctx, child) =>
                                  _themedTimePicker(ctx, child),
                            );
                            if (picked != null) {
                              vm.updateCloseTime(index, picked);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Copy to all days ──────────────────────────────
                Padding(
                  padding: const EdgeInsets.only(
                    left: AppSizes.md,
                    right: AppSizes.md,
                    bottom: AppSizes.sm + 4,
                  ),
                  child: GestureDetector(
                    onTap: () {
                      vm.copyTimesToAll(index);
                      ScaffoldMessenger.of(context)
                        ..clearSnackBars()
                        ..showSnackBar(
                          SnackBar(
                            content: Text(
                              '${day.day} timings applied to all open days',
                            ),
                            behavior: SnackBarBehavior.floating,
                            backgroundColor: AppColors.secondary,
                            duration: const Duration(seconds: 2),
                          ),
                        );
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.copy_all_outlined,
                          size: 13,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Apply these timings to all open days',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            secondChild: const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  /// Tints the system time-picker dialog with the app's primary colour.
  Widget _themedTimePicker(BuildContext ctx, Widget? child) {
    return Theme(
      data: Theme.of(ctx).copyWith(
        colorScheme: Theme.of(ctx).colorScheme.copyWith(
          primary: AppColors.primary,
          onPrimary: Colors.white,
          surface: AppColors.surface,
        ),
      ),
      child: child!,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
//  Time picker button tile
// ─────────────────────────────────────────────────────────────────────
class _TimePickerButton extends StatelessWidget {
  const _TimePickerButton({
    required this.icon,
    required this.label,
    required this.timeStr,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String timeStr;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.background,
      borderRadius: BorderRadius.circular(AppSizes.radiusMd),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSizes.radiusMd),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Label row
              Row(
                children: [
                  Icon(icon, size: 12, color: AppColors.textSecondary),
                  const SizedBox(width: 4),
                  Text(
                    label,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              // Time + edit icon
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    timeStr,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                      fontSize: AppSizes.fontMd,
                    ),
                  ),
                  const Icon(
                    Icons.edit_outlined,
                    size: 13,
                    color: AppColors.primary,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
//  Bottom Save bar
// ─────────────────────────────────────────────────────────────────────
class _SaveBar extends StatelessWidget {
  const _SaveBar({required this.vm});

  final OperatingHoursViewModel vm;

  @override
  Widget build(BuildContext context) {
    final isSaving = vm.isSaving;
    final isSaved = vm.status == HoursStatus.saved;

    return Container(
      color: AppColors.surface,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(height: 1, color: AppColors.borderLight),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSizes.md,
                vertical: AppSizes.sm + 2,
              ),
              child: SizedBox(
                height: 52,
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: (isSaving || isSaved) ? null : vm.saveSchedule,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isSaved
                        ? AppColors.success
                        : AppColors.primary,
                    disabledBackgroundColor: isSaved
                        ? AppColors.success
                        : AppColors.primaryLight,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                    ),
                    elevation: 0,
                  ),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: isSaving
                        ? const SizedBox(
                            key: ValueKey('loading'),
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor: AlwaysStoppedAnimation(Colors.white),
                            ),
                          )
                        : isSaved
                        ? const Row(
                            key: ValueKey('saved'),
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.check_circle_outline, size: 18),
                              SizedBox(width: 8),
                              Text(
                                'Changes Saved',
                                style: TextStyle(
                                  fontSize: AppSizes.fontMd,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          )
                        : const Text(
                            key: ValueKey('idle'),
                            'Save Changes',
                            style: TextStyle(
                              fontSize: AppSizes.fontMd,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
