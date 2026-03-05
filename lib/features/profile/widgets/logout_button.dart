import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_strings.dart';
import '../../auth/viewmodel/auth_viewmodel.dart';
import 'package:provider/provider.dart';

/// Full-width outlined logout button with confirmation dialog.
class LogoutButton extends StatelessWidget {
  const LogoutButton({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: AppSizes.buttonHeight,
      child: OutlinedButton.icon(
        onPressed: () => _confirmLogout(context),
        icon: const Icon(Icons.logout, color: AppColors.error),
        label: const Text(
          AppStrings.logout,
          style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w600),
        ),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: AppColors.error),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.buttonRadius),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(AppStrings.logout),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(AppStrings.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              AppStrings.logout,
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );

    if (confirm == true && context.mounted) {
      await context.read<AuthViewModel>().logout();
      if (context.mounted) {
        Navigator.of(context).pushReplacementNamed('/login');
      }
    }
  }
}
