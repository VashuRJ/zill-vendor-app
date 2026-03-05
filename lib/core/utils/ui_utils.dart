import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// Centralised UI helpers for consistent snackbars and dialogs.
class UIUtils {
  UIUtils._();

  /// Show a premium floating snackbar with an optional leading icon.
  ///
  /// By default uses [AppColors.success] background; pass [isError] = true
  /// for [AppColors.error].
  static void showSnackBar(
    BuildContext context, {
    required String message,
    bool isError = false,
    IconData? icon,
    Duration duration = const Duration(seconds: 2),
  }) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              if (icon != null) ...[
                Icon(icon, color: Colors.white, size: 18),
                const SizedBox(width: 8),
              ],
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
          backgroundColor: isError ? AppColors.error : AppColors.success,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          margin: const EdgeInsets.all(16),
          duration: duration,
        ),
      );
  }
}
