import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../viewmodel/settings_viewmodel.dart';
import '../../../core/services/api_service.dart';

class VendorSettingsScreen extends StatelessWidget {
  const VendorSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final api = context.read<ApiService>();
    return ChangeNotifierProvider(
      create: (_) => SettingsViewModel(apiService: api)..fetchSettings(),
      child: const _SettingsBody(),
    );
  }
}

class _SettingsBody extends StatelessWidget {
  const _SettingsBody();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Notifications & Settings',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
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
      body: Consumer<SettingsViewModel>(
        builder: (context, vm, _) {
          if (vm.isLoading && !vm.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }

          if (vm.hasError && !vm.hasData) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSizes.lg),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.errorLight,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.wifi_off_rounded,
                        size: 36,
                        color: AppColors.error,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      vm.errorMessage ?? 'Failed to load settings',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 44,
                      child: ElevatedButton.icon(
                        onPressed: vm.fetchSettings,
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: const Text(
                          'Retry',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(AppSizes.buttonRadius),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              AppSizes.md,
              AppSizes.md,
              AppSizes.md,
              AppSizes.xl,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Order Alerts ──────────────────────────────────────
                _SectionHeader(
                  icon: Icons.receipt_long_rounded,
                  iconColor: AppColors.primary,
                  iconBg: AppColors.primary.withAlpha(20),
                  title: 'Order Alerts',
                ),
                const SizedBox(height: 10),
                _Card(
                  children: [
                    _ToggleTile(
                      icon: Icons.notification_add_rounded,
                      iconColor: AppColors.primary,
                      label: 'New Order Alerts',
                      description: 'Get notified when you receive orders',
                      value: vm.data.notifyNewOrders,
                      onChanged: (v) =>
                          vm.updateSetting('notify_new_orders', v),
                    ),
                    _ToggleTile(
                      icon: Icons.cancel_rounded,
                      iconColor: AppColors.error,
                      label: 'Order Cancellations',
                      description: 'Alert when orders are cancelled',
                      value: vm.data.notifyOrderCancellations,
                      onChanged: (v) =>
                          vm.updateSetting('notify_order_cancellations', v),
                    ),
                    _ToggleTile(
                      icon: Icons.volume_up_rounded,
                      iconColor: const Color(0xFF6C5CE7),
                      label: 'Sound Alerts',
                      description: 'Play sound for new orders',
                      value: vm.data.playSoundAlerts,
                      isLast: true,
                      onChanged: (v) =>
                          vm.updateSetting('play_sound_alerts', v),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // ── Other Notifications ───────────────────────────────
                _SectionHeader(
                  icon: Icons.notifications_rounded,
                  iconColor: const Color(0xFFF97316),
                  iconBg: const Color(0xFFFFF7ED),
                  title: 'Other Notifications',
                ),
                const SizedBox(height: 10),
                _Card(
                  children: [
                    _ToggleTile(
                      icon: Icons.star_rounded,
                      iconColor: AppColors.ratingStar,
                      label: 'New Reviews',
                      description: 'Get notified about customer reviews',
                      value: vm.data.notifyNewReviews,
                      onChanged: (v) =>
                          vm.updateSetting('notify_new_reviews', v),
                    ),
                    _ToggleTile(
                      icon: Icons.payments_rounded,
                      iconColor: AppColors.success,
                      label: 'Payment Received',
                      description: 'Alert when payment is processed',
                      value: vm.data.notifyPaymentReceived,
                      onChanged: (v) =>
                          vm.updateSetting('notify_payment_received', v),
                    ),
                    _ToggleTile(
                      icon: Icons.mail_rounded,
                      iconColor: AppColors.info,
                      label: 'Marketing Emails',
                      description: 'Receive tips and promotional offers',
                      value: vm.data.notifyMarketing,
                      isLast: true,
                      onChanged: (v) =>
                          vm.updateSetting('notify_marketing', v),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // ── Danger Zone ───────────────────────────────────────
                _SectionHeader(
                  icon: Icons.warning_amber_rounded,
                  iconColor: AppColors.error,
                  iconBg: AppColors.errorLight,
                  title: 'Restaurant Control',
                ),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                    boxShadow: const [
                      BoxShadow(
                        color: AppColors.shadowLight,
                        blurRadius: 10,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: AppColors.error.withAlpha(18),
                              borderRadius: BorderRadius.circular(9),
                            ),
                            child: const Icon(
                              Icons.store_rounded,
                              size: 18,
                              color: AppColors.error,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Deactivate Restaurant',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Temporarily hide from customers',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textHint,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        height: 42,
                        child: OutlinedButton.icon(
                          onPressed: () => _showDeactivateDialog(context, vm),
                          icon: const Icon(Icons.power_settings_new_rounded,
                              size: 18),
                          label: const Text(
                            'Deactivate',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.error,
                            side: BorderSide(
                                color: AppColors.error.withAlpha(100)),
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(AppSizes.radiusSm),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                const SizedBox(height: AppSizes.md),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showDeactivateDialog(BuildContext context, SettingsViewModel vm) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.errorLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.warning_amber_rounded,
                color: AppColors.error,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Deactivate?',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        content: const Text(
          'Your restaurant will be temporarily hidden from customers. You can reactivate it anytime.',
          style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Cancel',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final success = await vm.deactivateRestaurant();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        Icon(
                          success
                              ? Icons.check_circle_rounded
                              : Icons.error_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          success
                              ? 'Restaurant deactivated'
                              : 'Failed to deactivate',
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                    behavior: SnackBarBehavior.floating,
                    backgroundColor:
                        success ? AppColors.success : AppColors.error,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    margin: const EdgeInsets.all(16),
                  ),
                );
              }
            },
            child: const Text(
              'Deactivate',
              style: TextStyle(
                color: AppColors.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  Section Header — icon pill + bold title
// ═══════════════════════════════════════════════════════════════════════════════
class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;

  const _SectionHeader({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: iconBg,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: iconColor),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  Card Wrapper
// ═══════════════════════════════════════════════════════════════════════════════
class _Card extends StatelessWidget {
  final List<Widget> children;
  const _Card({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadowLight,
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: children,
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  Toggle Tile — colored icon pill + switch
// ═══════════════════════════════════════════════════════════════════════════════
class _ToggleTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String description;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool isLast;

  const _ToggleTile({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.description,
    required this.value,
    required this.onChanged,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 13,
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: iconColor.withAlpha(18),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: iconColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      description,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textHint,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 28,
                child: FittedBox(
                  child: Switch.adaptive(
                    value: value,
                    onChanged: onChanged,
                    activeTrackColor: AppColors.success.withAlpha(160),
                    activeThumbColor: AppColors.success,
                    inactiveTrackColor: AppColors.borderLight,
                    inactiveThumbColor: AppColors.textHint,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (!isLast)
          const Divider(
            height: 1,
            indent: 62,
            color: AppColors.borderLight,
          ),
      ],
    );
  }
}
