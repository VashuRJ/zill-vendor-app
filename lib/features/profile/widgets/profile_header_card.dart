import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/services/api_service.dart';

import '../../home/view/app_shell.dart';
import '../../reviews/view/reviews_screen.dart';
import '../viewmodel/profile_viewmodel.dart';

// ═══════════════════════════════════════════════════════════════════════════════
//  Profile Header — premium cover + overlapping avatar + stats
// ═══════════════════════════════════════════════════════════════════════════════

class ProfileHeaderCard extends StatelessWidget {
  final ProfileViewModel vm;
  const ProfileHeaderCard({super.key, required this.vm});

  static const double _coverBody = 120;
  static const double _avatarR = 46;
  static const double _avatarTotal = (_avatarR + 4) * 2;

  @override
  Widget build(BuildContext context) {
    final data = vm.data;
    final localImg = vm.localProfileImage;
    final networkUrl = data.logoUrl ?? data.imageUrl;
    final hasNetwork = networkUrl != null && networkUrl.isNotEmpty;
    final hasLocal = localImg != null;
    final statusBarH = MediaQuery.of(context).padding.top;
    final coverH = statusBarH + _coverBody;

    return Column(
      children: [
        // ── Cover + overlapping avatar ─────────────────────────────────
        SizedBox(
          height: coverH + _avatarR + 4,
          child: Stack(
            children: [
              // Gradient cover
              Container(
                height: coverH,
                width: double.infinity,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.orange, AppColors.amber],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: SafeArea(
                  bottom: false,
                  child: Align(
                    alignment: Alignment.topRight,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 4, top: 2),
                      child: IconButton(
                        icon: const Icon(
                          Icons.refresh_outlined,
                          color: Colors.white,
                          size: 22,
                        ),
                        tooltip: 'Refresh',
                        onPressed: vm.isLoading ? null : vm.fetchProfile,
                      ),
                    ),
                  ),
                ),
              ),

              // Avatar — centred, straddling cover bottom edge
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Center(
                  child: _AvatarButton(
                    vm: vm,
                    avatarTotal: _avatarTotal,
                    avatarR: _avatarR,
                    hasLocal: hasLocal,
                    localImg: localImg,
                    hasNetwork: hasNetwork,
                    networkUrl: networkUrl,
                  ),
                ),
              ),
            ],
          ),
        ),

        // ── White card: name, badges, stats ────────────────────────────
        Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(horizontal: AppSizes.md),
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                color: AppColors.shadowLight,
                blurRadius: 10,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            children: [
              // Name
              vm.isLoading
                  ? const ShimmerBox(width: 140, height: 18)
                  : Text(
                      data.storeName.isNotEmpty
                          ? data.storeName
                          : 'Your Restaurant',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                      textAlign: TextAlign.center,
                    ),
              // Owner name
              if (!vm.isLoading && data.ownerName.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(
                  'by ${data.ownerName}',
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textHint,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 10),
              // Badges
              if (!vm.isLoading)
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: AppSizes.xs,
                  children: [
                    ProfileBadge(
                      label: data.isVerified ? 'Verified' : 'Unverified',
                      color: data.isVerified
                          ? AppColors.success
                          : AppColors.warning,
                      icon: data.isVerified
                          ? Icons.verified
                          : Icons.warning_amber_rounded,
                    ),
                    ProfileBadge(
                      label: data.isActive ? 'Active' : 'Inactive',
                      color: data.isActive
                          ? AppColors.info
                          : AppColors.textHint,
                      icon: Icons.circle,
                      iconSize: 8,
                    ),
                  ],
                ),
              // Profile completion
              if (!vm.isLoading && !data.isVerified) ...[
                const SizedBox(height: 12),
                ProfileCompletionBar(data: data),
              ],
              const SizedBox(height: 14),
              Container(height: 1, color: AppColors.borderLight),
              const SizedBox(height: 14),
              // Stats row
              if (vm.hasData)
                IntrinsicHeight(
                  child: Row(
                    children: [
                      // Rating
                      Expanded(child: _RatingStat(data: data)),
                      VerticalDivider(
                        width: 1,
                        thickness: 1,
                        color: AppColors.borderLight,
                      ),
                      TappableStat(
                        label: 'ORDERS',
                        value: data.totalOrders.toString(),
                        onTap: () => AppShell.switchTab(context, 1),
                      ),
                      VerticalDivider(
                        width: 1,
                        thickness: 1,
                        color: AppColors.borderLight,
                      ),
                      TappableStat(
                        label: 'MENU',
                        value: data.menuItemsCount.toString(),
                        onTap: () => AppShell.switchTab(context, 2),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSizes.md),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  Avatar with tap-to-upload + badges
// ═══════════════════════════════════════════════════════════════════════════════

class _AvatarButton extends StatelessWidget {
  final ProfileViewModel vm;
  final double avatarTotal;
  final double avatarR;
  final bool hasLocal;
  final File? localImg;
  final bool hasNetwork;
  final String? networkUrl;

  const _AvatarButton({
    required this.vm,
    required this.avatarTotal,
    required this.avatarR,
    required this.hasLocal,
    this.localImg,
    required this.hasNetwork,
    this.networkUrl,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _handleUpload(context),
      child: SizedBox(
        width: avatarTotal,
        height: avatarTotal,
        child: Stack(
          children: [
            Container(
              width: avatarTotal,
              height: avatarTotal,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.surface, width: 4),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(25),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: vm.isLoading
                  ? CircleAvatar(
                      radius: avatarR,
                      backgroundColor: AppColors.borderLight,
                    )
                  : CircleAvatar(
                      // Key changes on each upload → forces Flutter to
                      // destroy + recreate the widget, clearing internal
                      // image state and loading the fresh network image
                      key: ValueKey('avatar_v${vm.uploadVersion}'),
                      radius: avatarR,
                      backgroundColor: AppColors.primary.withAlpha(18),
                      backgroundImage: hasLocal
                          ? FileImage(localImg!)
                          : (hasNetwork
                                ? NetworkImage(
                                    '$networkUrl?v=${vm.uploadVersion}',
                                  ) as ImageProvider
                                : null),
                      onBackgroundImageError:
                          (hasLocal || hasNetwork) ? (e, s) {} : null,
                      child: (!hasLocal && !hasNetwork)
                          ? const Icon(
                              Icons.store,
                              size: 40,
                              color: AppColors.primary,
                            )
                          : null,
                    ),
            ),
            // Camera badge
            if (!vm.isLoading)
              Positioned(
                bottom: 2,
                right: 2,
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.surface, width: 2.5),
                  ),
                  child: vm.isUploadingImage
                      ? const Padding(
                          padding: EdgeInsets.all(5),
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(
                          Icons.camera_alt_rounded,
                          size: 13,
                          color: Colors.white,
                        ),
                ),
              ),
            // Verified badge
            if (vm.data.isVerified)
              Positioned(
                top: 2,
                right: 2,
                child: Container(
                  padding: const EdgeInsets.all(1.5),
                  decoration: const BoxDecoration(
                    color: AppColors.surface,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.verified,
                    size: 18,
                    color: AppColors.success,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleUpload(BuildContext context) async {
    // Capture ScaffoldMessenger BEFORE any async gap — this StatelessWidget's
    // context gets deactivated when notifyListeners() rebuilds the tree.
    final messenger = ScaffoldMessenger.maybeOf(context);

    void showSnack(bool ok, String message) {
      try {
        messenger
          ?..clearSnackBars()
          ..showSnackBar(SnackBar(
            content: Row(
              children: [
                Icon(
                  ok ? Icons.check_circle : Icons.error,
                  color: Colors.white,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    message,
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 13.5,
                    ),
                  ),
                ),
              ],
            ),
            behavior: SnackBarBehavior.floating,
            backgroundColor: ok ? AppColors.success : AppColors.error,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            margin: const EdgeInsets.all(16),
          ));
      } catch (_) {
        // Widget removed from tree during async — safe to ignore
      }
    }

    try {
      await vm.pickProfileImage();
      if (vm.localProfileImage == null) return;

      final ok = await vm.uploadProfileImage();
      showSnack(ok, ok ? AppStrings.photoUpdated : vm.errorMessage ?? AppStrings.uploadFailed);
    } catch (_) {
      showSnack(false, 'Could not update photo. Please try again.');
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  Rating stat (special — shows stars when 0)
// ═══════════════════════════════════════════════════════════════════════════════

class _RatingStat extends StatelessWidget {
  final ProfileData data;
  const _RatingStat({required this.data});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        final api = context.read<ApiService>();
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ReviewsScreen(apiService: api)),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          children: [
            if (data.rating > 0)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    data.rating.toStringAsFixed(1),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 2),
                  const Icon(
                    Icons.star_rounded,
                    size: 16,
                    color: AppColors.ratingStar,
                  ),
                ],
              )
            else
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: List.generate(
                  5,
                  (_) => const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 1),
                    child: Icon(
                      Icons.star_border_rounded,
                      size: 14,
                      color: AppColors.ratingStar,
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 2),
            const Text(
              'RATING',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
                color: AppColors.textHint,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  Reusable stat tile
// ═══════════════════════════════════════════════════════════════════════════════

class TappableStat extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onTap;
  const TappableStat({
    super.key,
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                  color: AppColors.textHint,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  Profile Completion Bar
// ═══════════════════════════════════════════════════════════════════════════════

class ProfileCompletionBar extends StatelessWidget {
  final ProfileData data;
  const ProfileCompletionBar({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    int filled = 0;
    const int total = 11;
    if (data.storeName.isNotEmpty) filled++;
    if (data.ownerName.isNotEmpty) filled++;
    if (data.email.isNotEmpty) filled++;
    if (data.phone.isNotEmpty) filled++;
    if (data.address.isNotEmpty) filled++;
    if (data.description.isNotEmpty) filled++;
    if (data.fssaiNumber.isNotEmpty) filled++;
    if (data.gstNumber.isNotEmpty) filled++;
    if (data.panNumber.isNotEmpty) filled++;
    if (data.logoUrl != null || data.imageUrl != null) filled++;
    if (data.hasBankAccount) filled++;

    final pct = filled / total;
    final pctInt = (pct * 100).round();

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Profile $pctInt% complete',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            Text(
              '$filled/$total',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.textHint,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pct,
            backgroundColor: AppColors.borderLight,
            valueColor: AlwaysStoppedAnimation<Color>(
              pct < 0.5
                  ? AppColors.warning
                  : pct < 0.8
                  ? AppColors.primary
                  : AppColors.success,
            ),
            minHeight: 6,
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  Badge chip
// ═══════════════════════════════════════════════════════════════════════════════

class ProfileBadge extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;
  final double iconSize;
  const ProfileBadge({
    super.key,
    required this.label,
    required this.color,
    required this.icon,
    this.iconSize = 12,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(22),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: iconSize, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  Shimmer placeholder box
// ═══════════════════════════════════════════════════════════════════════════════

class ShimmerBox extends StatelessWidget {
  final double width;
  final double height;
  const ShimmerBox({super.key, required this.width, required this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.borderLight,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}
