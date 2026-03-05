import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';

/// Primary filled button
class AppButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isOutlined;
  final IconData? icon;
  final Color? backgroundColor;
  final Color? textColor;
  final double? width;
  final double? height;

  const AppButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.isOutlined = false,
    this.icon,
    this.backgroundColor,
    this.textColor,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final btnStyle = isOutlined
        ? OutlinedButton.styleFrom(
            foregroundColor: textColor ?? AppColors.primary,
            side: BorderSide(
              color: backgroundColor ?? AppColors.primary,
              width: 1.5,
            ),
            minimumSize: Size(
              width ?? double.infinity,
              height ?? AppSizes.buttonHeight,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSizes.buttonRadius),
            ),
          )
        : ElevatedButton.styleFrom(
            backgroundColor: backgroundColor ?? AppColors.primary,
            foregroundColor: textColor ?? AppColors.textOnPrimary,
            minimumSize: Size(
              width ?? double.infinity,
              height ?? AppSizes.buttonHeight,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSizes.buttonRadius),
            ),
          );

    final child = isLoading
        ? const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: AppSizes.buttonIconSize),
                const SizedBox(width: AppSizes.sm),
              ],
              Text(text),
            ],
          );

    if (isOutlined) {
      return OutlinedButton(
        onPressed: isLoading ? null : onPressed,
        style: btnStyle,
        child: child,
      );
    }

    return ElevatedButton(
      onPressed: isLoading ? null : onPressed,
      style: btnStyle,
      child: child,
    );
  }
}

/// Small action button (Accept / Reject / Ready)
class AppActionButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final Color color;
  final IconData? icon;
  final bool isLoading;

  const AppActionButton({
    super.key,
    required this.text,
    this.onPressed,
    this.color = AppColors.primary,
    this.icon,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: AppSizes.md),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.radiusSm),
          ),
          elevation: 0,
        ),
        child: isLoading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 16),
                    const SizedBox(width: 4),
                  ],
                  Text(
                    text,
                    style: const TextStyle(
                      fontSize: AppSizes.fontSm,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
