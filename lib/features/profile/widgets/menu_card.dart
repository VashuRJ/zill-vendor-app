import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';

/// A grouped container with shadow, wrapping a list of [MenuItem] entries.
class MenuCard extends StatelessWidget {
  final List<MenuItem> items;
  const MenuCard({super.key, required this.items});

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
      child: Column(children: items),
    );
  }
}

/// Single row inside a [MenuCard] — icon, title/subtitle, chevron.
class MenuItem extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool isExternal;
  final bool isLast;

  const MenuItem({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.isExternal = false,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: isLast
              ? const BorderRadius.vertical(bottom: Radius.circular(12))
              : BorderRadius.zero,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: iconColor.withAlpha(18),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(icon, size: 18, color: iconColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textHint,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  isExternal
                      ? Icons.open_in_new_rounded
                      : Icons.chevron_right_rounded,
                  color: AppColors.textHint,
                  size: isExternal ? 18 : 22,
                ),
              ],
            ),
          ),
        ),
        if (!isLast)
          const Divider(height: 1, indent: 62, color: AppColors.borderLight),
      ],
    );
  }
}
