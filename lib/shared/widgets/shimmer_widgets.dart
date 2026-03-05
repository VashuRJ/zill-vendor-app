import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';

/// Shimmer loading placeholder for cards
class ShimmerCard extends StatelessWidget {
  final double height;
  final double? width;

  const ShimmerCard({
    super.key,
    this.height = 100,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.shimmerBase,
      highlightColor: AppColors.shimmerHighlight,
      child: Container(
        height: height,
        width: width ?? double.infinity,
        margin: const EdgeInsets.symmetric(
          horizontal: AppSizes.md,
          vertical: AppSizes.sm,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        ),
      ),
    );
  }
}

/// Shimmer loading placeholder for list items
class ShimmerList extends StatelessWidget {
  final int itemCount;
  final double itemHeight;

  const ShimmerList({
    super.key,
    this.itemCount = 5,
    this.itemHeight = 80,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: itemCount,
      itemBuilder: (context, index) => ShimmerCard(height: itemHeight),
    );
  }
}

/// Shimmer grid for stat cards
class ShimmerGrid extends StatelessWidget {
  final int itemCount;
  final double itemHeight;

  const ShimmerGrid({
    super.key,
    this.itemCount = 4,
    this.itemHeight = 120,
  });

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.shimmerBase,
      highlightColor: AppColors.shimmerHighlight,
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSizes.md),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: AppSizes.md,
          crossAxisSpacing: AppSizes.md,
          childAspectRatio: 1.4,
        ),
        itemCount: itemCount,
        itemBuilder: (context, index) => Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          ),
        ),
      ),
    );
  }
}
