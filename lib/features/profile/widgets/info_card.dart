import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/ui_utils.dart';

/// Shadow-wrapped card containing a list of [InfoTile] rows.
class InfoCard extends StatelessWidget {
  final bool isLoading;
  final List<InfoTile> tiles;
  const InfoCard({super.key, required this.isLoading, required this.tiles});

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
        children: [
          for (int i = 0; i < tiles.length; i++) ...[
            if (isLoading) const TileShimmer() else tiles[i],
            if (i < tiles.length - 1)
              const Divider(
                height: 1,
                indent: 54,
                color: AppColors.borderLight,
              ),
          ],
        ],
      ),
    );
  }
}

/// Single icon + label + value row for [InfoCard].
class InfoTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final String placeholder;
  final bool copyable;
  final bool multiline;

  const InfoTile({
    super.key,
    required this.icon,
    required this.label,
    this.iconColor = AppColors.primary,
    this.value = '',
    this.placeholder = '—',
    this.copyable = false,
    this.multiline = false,
  });

  @override
  Widget build(BuildContext context) {
    final display = value.isNotEmpty ? value : placeholder;
    final isEmpty = value.isEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        crossAxisAlignment: multiline
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.center,
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: iconColor.withAlpha(18),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 17, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textHint,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  display,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: isEmpty ? AppColors.textHint : AppColors.textPrimary,
                  ),
                  maxLines: multiline ? 3 : 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (copyable && value.isNotEmpty)
            GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: value));
                UIUtils.showSnackBar(
                  context,
                  message: '$label ${AppStrings.copied}',
                  icon: Icons.check_circle,
                  duration: const Duration(seconds: 1),
                );
              },
              child: const Padding(
                padding: EdgeInsets.only(left: 8),
                child: Icon(
                  Icons.copy_rounded,
                  size: 15,
                  color: AppColors.textHint,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Shimmer placeholder matching [InfoTile] layout.
class TileShimmer extends StatelessWidget {
  const TileShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppColors.borderLight,
              borderRadius: BorderRadius.circular(9),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 80,
                  height: 11,
                  decoration: BoxDecoration(
                    color: AppColors.borderLight,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 5),
                Container(
                  width: 160,
                  height: 14,
                  decoration: BoxDecoration(
                    color: AppColors.borderLight,
                    borderRadius: BorderRadius.circular(4),
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
