import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/services/api_service.dart';
import '../../../core/utils/ui_utils.dart';
import '../viewmodel/profile_viewmodel.dart';
import '../widgets/error_view.dart';
import '../widgets/info_card.dart';
import '../widgets/kyc_warning_banner.dart';
import '../widgets/logout_button.dart';
import '../widgets/menu_card.dart';
import '../widgets/profile_header_card.dart';
import '../widgets/section_header.dart';
import 'bank_account_screen.dart';
import 'change_password_screen.dart';
import 'edit_profile_screen.dart';
import 'operating_hours_screen.dart';
import '../../earnings/view/earnings_screen.dart';
import '../../reviews/view/reviews_screen.dart';
import 'store_settings_screen.dart';
import 'vendor_settings_screen.dart';
import '../../analytics/view/analytics_screen.dart';
import '../../promotions/view/promotions_screen.dart';
import '../../staff/view/staff_screen.dart';
import '../../subscription/view/my_subscription_screen.dart';
import '../../support/view/help_support_screen.dart';
import '../../../core/routing/app_router.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final ProfileViewModel _vm;

  @override
  void initState() {
    super.initState();
    _vm = context.read<ProfileViewModel>();
    _vm.addListener(_onProfileChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _vm.fetchProfile();
    });
  }

  @override
  void dispose() {
    _vm.removeListener(_onProfileChanged);
    super.dispose();
  }

  /// Show a non-blocking snackbar when a background refresh fails
  /// but stale data is still visible on screen.
  void _onProfileChanged() {
    if (_vm.status == ProfileStatus.error && _vm.hasData && mounted) {
      UIUtils.showSnackBar(
        context,
        message: _vm.errorMessage ?? AppStrings.somethingWentWrong,
        isError: true,
        icon: Icons.cloud_off_rounded,
      );
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  Build
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Selector<ProfileViewModel, ({ProfileStatus status, bool hasData})>(
        selector: (_, vm) => (status: vm.status, hasData: vm.hasData),
        builder: (context, state, child) {
          if (state.status == ProfileStatus.error && !state.hasData) {
            final vm = context.read<ProfileViewModel>();
            return ProfileErrorView(
              message: vm.errorMessage ?? AppStrings.somethingWentWrong,
              errorType: vm.errorType,
              onRetry: vm.fetchProfile,
            );
          }
          return child!;
        },
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () => context.read<ProfileViewModel>().fetchProfile(),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header (fully dynamic) ───────────────────────────
                Consumer<ProfileViewModel>(
                  builder: (context, vm, _) => ProfileHeaderCard(vm: vm),
                ),

                // ── KYC Banner (animated fade + size) ────────────────
                Selector<ProfileViewModel, bool>(
                  selector: (_, vm) => vm.hasData && !vm.data.isVerified,
                  builder: (_, show, child) => AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    transitionBuilder: (child, anim) => SizeTransition(
                      sizeFactor: anim,
                      child: FadeTransition(opacity: anim, child: child),
                    ),
                    child: show
                        ? KycWarningBanner(
                            key: const ValueKey('kyc'),
                            onTap: () => Navigator.pushNamed(
                              context,
                              AppRouter.kycDocuments,
                            ),
                          )
                        : const SizedBox.shrink(key: ValueKey('no-kyc')),
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSizes.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Business Details + Licences (data-dependent) ─
                      _buildDataSections(),
                      const SizedBox(height: 24),

                      // ── Subscription (premium placement) ─────────────
                      _buildSubscriptionSection(),
                      const SizedBox(height: 24),

                      // ── Menus (static — disabled while loading) ──────
                      Selector<ProfileViewModel, bool>(
                        selector: (_, vm) => vm.isLoading,
                        builder: (_, isLoading, child) => IgnorePointer(
                          ignoring: isLoading,
                          child: AnimatedOpacity(
                            opacity: isLoading ? 0.5 : 1.0,
                            duration: const Duration(milliseconds: 200),
                            child: child,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSettingsSection(),
                            const SizedBox(height: 24),
                            _buildAccountSection(),
                            const SizedBox(height: 24),
                            _buildActivitySection(),
                            const SizedBox(height: 24),
                            const LogoutButton(),
                            const SizedBox(height: AppSizes.xl),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  Data-dependent sections (Business Details + Licences)
  //  Wrapped in a single Selector so only they rebuild when profile loads.
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildDataSections() {
    return Selector<
      ProfileViewModel,
      ({bool hasData, bool isLoading, ProfileData data})
    >(
      selector: (_, vm) =>
          (hasData: vm.hasData, isLoading: vm.isLoading, data: vm.data),
      builder: (context, s, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Business Details ──────────────────────────────────
            Row(
              children: [
                SectionHeader(
                  icon: Icons.storefront_rounded,
                  iconColor: AppColors.orange,
                  iconBg: AppColors.orangeLight,
                  title: AppStrings.businessDetails,
                ),
                const Spacer(),
                if (s.hasData)
                  GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const EditProfileScreen(),
                      ),
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withAlpha(15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.edit_rounded,
                            size: 13,
                            color: AppColors.primary,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Edit',
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
            if (!s.hasData)
              const InfoCard(isLoading: true, tiles: [])
            else
              InfoCard(
                isLoading: s.isLoading,
                tiles: [
                  InfoTile(
                    icon: Icons.store_rounded,
                    iconColor: AppColors.orange,
                    label: AppStrings.restaurantName,
                    value: s.data.storeName,
                  ),
                  InfoTile(
                    icon: Icons.person_rounded,
                    iconColor: AppColors.purple,
                    label: AppStrings.ownerName,
                    value: s.data.ownerName,
                  ),
                  InfoTile(
                    icon: Icons.email_rounded,
                    iconColor: AppColors.info,
                    label: AppStrings.email,
                    value: s.data.email,
                    copyable: true,
                  ),
                  InfoTile(
                    icon: Icons.phone_rounded,
                    iconColor: AppColors.success,
                    label: AppStrings.phone,
                    value: s.data.phone,
                    copyable: true,
                  ),
                  InfoTile(
                    icon: Icons.location_on_rounded,
                    iconColor: AppColors.error,
                    label: AppStrings.address,
                    value: s.data.address,
                    multiline: true,
                  ),
                ],
              ),

            const SizedBox(height: 24),

            // ── Licences & Compliance ────────────────────────────
            SectionHeader(
              icon: Icons.verified_user_rounded,
              iconColor: AppColors.success,
              iconBg: AppColors.successLight,
              title: AppStrings.licencesCompliance,
            ),
            const SizedBox(height: 10),
            if (!s.hasData)
              const InfoCard(isLoading: true, tiles: [])
            else
              InfoCard(
                isLoading: s.isLoading,
                tiles: [
                  InfoTile(
                    icon: Icons.verified_rounded,
                    iconColor: AppColors.success,
                    label: 'FSSAI License',
                    value: s.data.fssaiNumber,
                    placeholder: AppStrings.notProvided,
                    copyable: s.data.fssaiNumber.isNotEmpty,
                  ),
                  InfoTile(
                    icon: Icons.receipt_long_rounded,
                    iconColor: AppColors.purple,
                    label: 'GST Number',
                    value: s.data.gstNumber,
                    placeholder: AppStrings.notProvided,
                    copyable: s.data.gstNumber.isNotEmpty,
                  ),
                  InfoTile(
                    icon: Icons.badge_rounded,
                    iconColor: AppColors.info,
                    label: 'PAN Number',
                    value: s.data.panNumber,
                    placeholder: AppStrings.notProvided,
                    copyable: s.data.panNumber.isNotEmpty,
                  ),
                ],
              ),
          ],
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  Static menu sections (no VM subscription — never rebuilt)
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildSubscriptionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          icon: Icons.workspace_premium_rounded,
          iconColor: AppColors.warning,
          iconBg: AppColors.warningLight,
          title: 'Subscription',
        ),
        const SizedBox(height: 10),
        MenuCard(
          items: [
            MenuItem(
              icon: Icons.workspace_premium_rounded,
              iconColor: AppColors.warning,
              title: 'Manage Subscription',
              subtitle: 'Plans, billing & payment history',
              isLast: true,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const MySubscriptionScreen(),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSettingsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          icon: Icons.tune_rounded,
          iconColor: AppColors.purple,
          iconBg: AppColors.purpleLight,
          title: AppStrings.settings,
        ),
        const SizedBox(height: 10),
        MenuCard(
          items: [
            MenuItem(
              icon: Icons.store_rounded,
              iconColor: AppColors.primary,
              title: AppStrings.storeSettings,
              subtitle: 'Delivery zones, order settings',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const StoreSettingsScreen()),
              ),
            ),
            MenuItem(
              icon: Icons.local_offer_rounded,
              iconColor: AppColors.orange,
              title: 'Promotions & Offers',
              subtitle: 'Create & manage discount coupons',
              onTap: () {
                final api = context.read<ApiService>();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PromotionsScreen(apiService: api),
                  ),
                );
              },
            ),
            MenuItem(
              icon: Icons.playlist_add_rounded,
              iconColor: AppColors.purple,
              title: 'Addon Groups',
              subtitle: 'Manage toppings, extras & sides',
              onTap: () => Navigator.pushNamed(
                context,
                AppRouter.addonGroups,
              ),
            ),
            MenuItem(
              icon: Icons.people_alt_rounded,
              iconColor: AppColors.info,
              title: 'Staff Management',
              subtitle: 'Manage your team & roles',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const StaffScreen()),
              ),
            ),
            MenuItem(
              icon: Icons.access_time_filled_rounded,
              iconColor: AppColors.purple,
              title: AppStrings.operatingHours,
              subtitle: 'Set your daily open/close timings',
              onTap: () {
                final api = context.read<ApiService>();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => OperatingHoursScreen(apiService: api),
                  ),
                );
              },
            ),
            MenuItem(
              icon: Icons.account_balance_rounded,
              iconColor: AppColors.success,
              title: AppStrings.bankDetailsPayouts,
              subtitle: 'Manage your payout bank account',
              onTap: () {
                final api = context.read<ApiService>();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => BankAccountScreen(apiService: api),
                  ),
                );
              },
            ),
            MenuItem(
              icon: Icons.description_rounded,
              iconColor: AppColors.warning,
              title: AppStrings.documentsKyc,
              subtitle: 'Upload & verify business documents',
              isLast: true,
              onTap: () => Navigator.pushNamed(
                context,
                AppRouter.kycDocuments,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAccountSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          icon: Icons.shield_rounded,
          iconColor: AppColors.info,
          iconBg: AppColors.infoLight,
          title: AppStrings.accountSecurity,
        ),
        const SizedBox(height: 10),
        MenuCard(
          items: [
            MenuItem(
              icon: Icons.lock_rounded,
              iconColor: AppColors.error,
              title: AppStrings.changePassword,
              subtitle: 'Update your password',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ChangePasswordScreen()),
              ),
            ),
            MenuItem(
              icon: Icons.notifications_rounded,
              iconColor: AppColors.orange,
              title: AppStrings.notificationsSettings,
              subtitle: 'Alerts, sounds & restaurant control',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const VendorSettingsScreen()),
              ),
            ),
            MenuItem(
              icon: Icons.help_outline_rounded,
              iconColor: AppColors.teal,
              title: AppStrings.helpSupport,
              subtitle: 'FAQs, contact support & more',
              isLast: true,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const HelpSupportScreen()),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActivitySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          icon: Icons.insights_rounded,
          iconColor: AppColors.warning,
          iconBg: AppColors.warningLight,
          title: AppStrings.activity,
        ),
        const SizedBox(height: 10),
        MenuCard(
          items: [
            MenuItem(
              icon: Icons.star_rounded,
              iconColor: AppColors.ratingStar,
              title: AppStrings.customerReviews,
              subtitle: 'Read and reply to customer reviews',
              onTap: () {
                final api = context.read<ApiService>();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ReviewsScreen(apiService: api),
                  ),
                );
              },
            ),
            MenuItem(
              icon: Icons.account_balance_wallet_rounded,
              iconColor: AppColors.success,
              title: AppStrings.earningsPayouts,
              subtitle: 'Settlements, revenue & wallet',
              onTap: () {
                final api = context.read<ApiService>();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => EarningsScreen(apiService: api),
                  ),
                );
              },
            ),
            MenuItem(
              icon: Icons.analytics_rounded,
              iconColor: AppColors.info,
              title: AppStrings.analytics,
              subtitle: 'Revenue trends, top items & insights',
              isLast: true,
              onTap: () {
                final api = context.read<ApiService>();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AnalyticsScreen(apiService: api),
                  ),
                );
              },
            ),
          ],
        ),
      ],
    );
  }

}
