import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_strings.dart';

/// Amber banner shown when the vendor's KYC is incomplete.
///
/// Fades/slides in via [AnimatedSwitcher] in the parent.
class KycWarningBanner extends StatelessWidget {
  final VoidCallback onTap;
  const KycWarningBanner({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(
          horizontal: AppSizes.md,
          vertical: 8,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFFF3E0), Color(0xFFFFECB3)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFFFB74D), width: 1),
          boxShadow: const [
            BoxShadow(
              color: AppColors.shadowLight,
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.warning.withAlpha(30),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.warning_amber_rounded,
                size: 20,
                color: AppColors.warning,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppStrings.kycIncomplete,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.deepOrange,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    AppStrings.kycDescription,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                      color: AppColors.deepOrange.withAlpha(180),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.open_in_new_rounded,
              size: 18,
              color: AppColors.deepOrange,
            ),
          ],
        ),
      ),
    );
  }
}
