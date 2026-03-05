import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_strings.dart';
import '../viewmodel/profile_viewmodel.dart';

/// Full-screen error placeholder with icon, message, and retry button.
///
/// The icon adapts to [errorType] (wifi-off for no-internet, cloud-off for
/// server errors, etc.).
class ProfileErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  final AppErrorType errorType;

  const ProfileErrorView({
    super.key,
    required this.message,
    required this.onRetry,
    this.errorType = AppErrorType.unknown,
  });

  @override
  Widget build(BuildContext context) {
    final (icon, iconColor) = _errorVisuals(errorType);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: iconColor),
            const SizedBox(height: AppSizes.md),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSizes.lg),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text(AppStrings.retry),
            ),
          ],
        ),
      ),
    );
  }

  static (IconData, Color) _errorVisuals(AppErrorType type) {
    return switch (type) {
      AppErrorType.noInternet => (
        Icons.wifi_off_rounded,
        const Color(0xFF78909C),
      ),
      AppErrorType.timeout => (
        Icons.hourglass_bottom_rounded,
        AppColors.warning,
      ),
      AppErrorType.serverError => (Icons.cloud_off_rounded, AppColors.error),
      AppErrorType.unauthorized => (
        Icons.lock_outline_rounded,
        AppColors.purple,
      ),
      AppErrorType.unknown => (Icons.error_outline_rounded, AppColors.textHint),
    };
  }
}
