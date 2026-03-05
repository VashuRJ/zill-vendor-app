import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/services/api_service.dart';
import '../viewmodel/reviews_viewmodel.dart';

// ─────────────────────────────────────────────────────────────────────
//  Route entry-point
// ─────────────────────────────────────────────────────────────────────
class ReviewsScreen extends StatelessWidget {
  const ReviewsScreen({super.key, required this.apiService});

  final ApiService apiService;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ReviewsViewModel(apiService: apiService),
      child: const _ReviewsView(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
//  Main view
// ─────────────────────────────────────────────────────────────────────
class _ReviewsView extends StatefulWidget {
  const _ReviewsView();

  @override
  State<_ReviewsView> createState() => _ReviewsViewState();
}

class _ReviewsViewState extends State<_ReviewsView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<ReviewsViewModel>().fetchReviews();
    });
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ReviewsViewModel>();

    Widget body;
    if (vm.status == ReviewsStatus.fetching) {
      body = const _LoadingView();
    } else if (vm.status == ReviewsStatus.error) {
      body = _ErrorView(
        message: vm.errorMessage ?? 'Could not load reviews.',
        onRetry: context.read<ReviewsViewModel>().fetchReviews,
      );
    } else {
      body = _ContentView(vm: vm);
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Customer Reviews'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.borderLight),
        ),
        actions: [
          if (vm.status == ReviewsStatus.idle)
            IconButton(
              icon: const Icon(Icons.refresh_outlined),
              tooltip: 'Refresh',
              onPressed: context.read<ReviewsViewModel>().refresh,
            ),
        ],
      ),
      body: body,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
//  Loading
// ─────────────────────────────────────────────────────────────────────
class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2.5),
          SizedBox(height: AppSizes.md),
          Text(
            'Loading reviews…',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: AppSizes.fontMd,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
//  Error
// ─────────────────────────────────────────────────────────────────────
class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                color: AppColors.errorLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.rate_review_outlined,
                size: 34,
                color: AppColors.error,
              ),
            ),
            const SizedBox(height: AppSizes.lg),
            const Text(
              'Unable to load reviews',
              style: TextStyle(
                fontSize: AppSizes.fontXl,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSizes.sm),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: AppSizes.fontMd,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSizes.xl),
            SizedBox(
              width: double.infinity,
              height: AppSizes.buttonHeight,
              child: ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.textOnPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSizes.buttonRadius),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
//  Content
// ─────────────────────────────────────────────────────────────────────
class _ContentView extends StatelessWidget {
  const _ContentView({required this.vm});
  final ReviewsViewModel vm;

  @override
  Widget build(BuildContext context) {
    final reviews = vm.reviews;

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: vm.refresh,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          // ── Rating summary card ───────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSizes.md,
                AppSizes.md,
                AppSizes.md,
                0,
              ),
              child: _RatingSummaryCard(stats: vm.stats),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: AppSizes.md)),

          // ── Section header ────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSizes.md),
              child: _SectionHeader(
                title: 'Reviews',
                badge: vm.stats.totalReviews > 0
                    ? '${vm.stats.totalReviews}'
                    : null,
                badgeHighlight: vm.stats.unrepliedCount > 0
                    ? '${vm.stats.unrepliedCount} pending reply'
                    : null,
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: AppSizes.sm)),

          // ── List or empty state ───────────────────────────────────
          if (reviews.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: _EmptyReviewsView(),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                AppSizes.md,
                0,
                AppSizes.md,
                AppSizes.xl,
              ),
              sliver: SliverList.separated(
                itemCount: reviews.length,
                separatorBuilder: (_, _) => const SizedBox(height: AppSizes.sm),
                itemBuilder: (_, i) => _ReviewCard(review: reviews[i], vm: vm),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
//  Rating summary card
// ─────────────────────────────────────────────────────────────────────
class _RatingSummaryCard extends StatelessWidget {
  const _RatingSummaryCard({required this.stats});
  final ReviewStats stats;

  @override
  Widget build(BuildContext context) {
    final avg = stats.averageRating;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSizes.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Top row: score + sub-ratings ─────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Big score
              Column(
                children: [
                  Text(
                    avg.toStringAsFixed(1),
                    style: const TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary,
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  _StarRow(rating: avg.round(), size: 16),
                  const SizedBox(height: 4),
                  Text(
                    '${stats.totalReviews} review${stats.totalReviews == 1 ? '' : 's'}',
                    style: const TextStyle(
                      fontSize: AppSizes.fontXs,
                      color: AppColors.textHint,
                    ),
                  ),
                ],
              ),

              const SizedBox(width: AppSizes.lg),

              // Bar chart
              Expanded(
                child: Column(
                  children: [
                    for (int s = 5; s >= 1; s--)
                      _RatingBar(
                        star: s,
                        count: stats.ratingDistribution[s.toString()] ?? 0,
                        total: stats.totalReviews,
                      ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: AppSizes.md),
          const Divider(height: 1, color: AppColors.borderLight),
          const SizedBox(height: AppSizes.md),

          // ── Sub-ratings row ───────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: _SubRating(
                  icon: Icons.fastfood_outlined,
                  label: 'Food',
                  value: stats.averageFoodRating,
                ),
              ),
              Container(width: 1, height: 36, color: AppColors.borderLight),
              Expanded(
                child: _SubRating(
                  icon: Icons.delivery_dining_outlined,
                  label: 'Delivery',
                  value: stats.averageDeliveryRating,
                ),
              ),
              if (stats.unrepliedCount > 0) ...[
                Container(width: 1, height: 36, color: AppColors.borderLight),
                Expanded(
                  child: _SubRating(
                    icon: Icons.pending_actions_outlined,
                    label: 'Unreplied',
                    value: stats.unrepliedCount.toDouble(),
                    isCount: true,
                    color: AppColors.warning,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _RatingBar extends StatelessWidget {
  const _RatingBar({
    required this.star,
    required this.count,
    required this.total,
  });

  final int star;
  final int count;
  final int total;

  @override
  Widget build(BuildContext context) {
    final fraction = total > 0 ? count / total : 0.0;
    final barColor = star >= 4
        ? AppColors.success
        : star == 3
        ? AppColors.warning
        : AppColors.error;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text(
            '$star',
            style: const TextStyle(
              fontSize: AppSizes.fontXs,
              fontWeight: FontWeight.w600,
              color: AppColors.textHint,
            ),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.star_rounded, size: 10, color: AppColors.ratingStar),
          const SizedBox(width: 6),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppSizes.radiusFull),
              child: LinearProgressIndicator(
                value: fraction.toDouble(),
                minHeight: 6,
                backgroundColor: AppColors.borderLight,
                valueColor: AlwaysStoppedAnimation<Color>(barColor),
              ),
            ),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 20,
            child: Text(
              '$count',
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: AppSizes.fontXs,
                color: AppColors.textHint,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SubRating extends StatelessWidget {
  const _SubRating({
    required this.icon,
    required this.label,
    required this.value,
    this.isCount = false,
    this.color = AppColors.primary,
  });

  final IconData icon;
  final String label;
  final double value;
  final bool isCount;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(height: 4),
        Text(
          isCount ? value.toInt().toString() : value.toStringAsFixed(1),
          style: TextStyle(
            fontSize: AppSizes.fontMd,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: AppSizes.fontXs,
            color: AppColors.textHint,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
//  Section header
// ─────────────────────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.badge, this.badgeHighlight});

  final String title;
  final String? badge;
  final String? badgeHighlight;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title.toUpperCase(),
          style: const TextStyle(
            fontSize: AppSizes.fontXs,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
            color: AppColors.textHint,
          ),
        ),
        if (badge != null) ...[
          const SizedBox(width: AppSizes.xs),
          _Chip(label: badge!, color: AppColors.primary),
        ],
        if (badgeHighlight != null) ...[
          const SizedBox(width: AppSizes.xs),
          _Chip(label: badgeHighlight!, color: AppColors.warning),
        ],
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(AppSizes.radiusFull),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: AppSizes.fontXs,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
//  Review card
// ─────────────────────────────────────────────────────────────────────
class _ReviewCard extends StatefulWidget {
  const _ReviewCard({required this.review, required this.vm});

  final VendorReview review;
  final ReviewsViewModel vm;

  @override
  State<_ReviewCard> createState() => _ReviewCardState();
}

class _ReviewCardState extends State<_ReviewCard> {
  late final TextEditingController _replyCtrl;

  @override
  void initState() {
    super.initState();
    _replyCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _replyCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final success = await widget.vm.submitReply(
      widget.review.id,
      _replyCtrl.text,
    );
    if (success && mounted) _replyCtrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    final review = widget.review;
    final vm = widget.vm;
    final isSubmitting = vm.isSubmitting(review.id);
    final replyError = vm.replyError(review.id);
    final dateStr = _formatDate(review.createdAt);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header: avatar + name + date + star ─────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar initials
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withAlpha(18),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    _initials(review.customerName),
                    style: const TextStyle(
                      fontSize: AppSizes.fontMd,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(width: AppSizes.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        review.customerName,
                        style: const TextStyle(
                          fontSize: AppSizes.fontMd,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          _StarRow(rating: review.rating, size: 13),
                          const SizedBox(width: 6),
                          Text(
                            dateStr,
                            style: const TextStyle(
                              fontSize: AppSizes.fontXs,
                              color: AppColors.textHint,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Rating badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _ratingColor(review.rating).withAlpha(18),
                    borderRadius: BorderRadius.circular(AppSizes.radiusFull),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.star_rounded,
                        size: 13,
                        color: _ratingColor(review.rating),
                      ),
                      const SizedBox(width: 2),
                      Text(
                        '${review.rating}',
                        style: TextStyle(
                          fontSize: AppSizes.fontSm,
                          fontWeight: FontWeight.w800,
                          color: _ratingColor(review.rating),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // ── Order items ──────────────────────────────────────────
            if (review.orderItems.isNotEmpty) ...[
              const SizedBox(height: AppSizes.sm),
              Row(
                children: [
                  const Icon(
                    Icons.receipt_long_outlined,
                    size: 12,
                    color: AppColors.textHint,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      review.orderItems,
                      style: const TextStyle(
                        fontSize: AppSizes.fontXs,
                        color: AppColors.textHint,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],

            // ── Review comment ──────────────────────────────────────
            if (review.comment.isNotEmpty) ...[
              const SizedBox(height: AppSizes.sm),
              Text(
                review.comment,
                style: const TextStyle(
                  fontSize: AppSizes.fontMd,
                  color: AppColors.textPrimary,
                  height: 1.45,
                ),
              ),
            ],

            // ── Photos ───────────────────────────────────────────────
            if (review.photos.isNotEmpty) ...[
              const SizedBox(height: AppSizes.sm),
              SizedBox(
                height: 72,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: review.photos.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(width: AppSizes.xs),
                  itemBuilder: (_, i) => ClipRRect(
                    borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                    child: Image.network(
                      review.photos[i],
                      width: 72,
                      height: 72,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(
                        width: 72,
                        height: 72,
                        color: AppColors.borderLight,
                        child: const Icon(
                          Icons.broken_image_outlined,
                          color: AppColors.textHint,
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],

            const SizedBox(height: AppSizes.sm),
            const Divider(height: 1, color: AppColors.borderLight),
            const SizedBox(height: AppSizes.sm),

            // ── Vendor reply (if exists) ──────────────────────────────
            if (review.hasReply)
              _VendorReplyBox(reply: review.reply, repliedAt: review.repliedAt)
            // ── Reply form (if no reply yet) ──────────────────────────
            else
              _ReplyForm(
                controller: _replyCtrl,
                isSubmitting: isSubmitting,
                errorText: replyError,
                onSubmit: _submit,
              ),
          ],
        ),
      ),
    );
  }

  Color _ratingColor(int rating) {
    if (rating >= 4) return AppColors.success;
    if (rating == 3) return AppColors.warning;
    return AppColors.error;
  }
}

// ─────────────────────────────────────────────────────────────────────
//  Vendor reply box — shown when reply already exists
// ─────────────────────────────────────────────────────────────────────
class _VendorReplyBox extends StatelessWidget {
  const _VendorReplyBox({required this.reply, required this.repliedAt});

  final String reply;
  final String? repliedAt;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSizes.sm),
      decoration: BoxDecoration(
        // Soft warm tint — clearly distinguishes vendor reply from review
        color: AppColors.primary.withAlpha(10),
        borderRadius: BorderRadius.circular(AppSizes.radiusSm),
        border: Border.all(color: AppColors.primary.withAlpha(35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.store_rounded,
                size: 13,
                color: AppColors.primary,
              ),
              const SizedBox(width: 4),
              const Text(
                'Your Reply',
                style: TextStyle(
                  fontSize: AppSizes.fontXs,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
              if (repliedAt != null && repliedAt!.isNotEmpty) ...[
                const SizedBox(width: AppSizes.xs),
                Text(
                  '· ${_formatDate(repliedAt!)}',
                  style: const TextStyle(
                    fontSize: AppSizes.fontXs,
                    color: AppColors.textHint,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Text(
            reply,
            style: const TextStyle(
              fontSize: AppSizes.fontMd,
              color: AppColors.textPrimary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
//  Reply form — shown when no reply yet
// ─────────────────────────────────────────────────────────────────────
class _ReplyForm extends StatelessWidget {
  const _ReplyForm({
    required this.controller,
    required this.isSubmitting,
    required this.errorText,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final bool isSubmitting;
  final String? errorText;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
          enabled: !isSubmitting,
          maxLines: 3,
          minLines: 2,
          textCapitalization: TextCapitalization.sentences,
          style: const TextStyle(
            fontSize: AppSizes.fontMd,
            color: AppColors.textPrimary,
          ),
          decoration: InputDecoration(
            hintText: 'Write a public reply to this review…',
            hintStyle: const TextStyle(
              color: AppColors.textHint,
              fontSize: AppSizes.fontMd,
            ),
            filled: true,
            fillColor: AppColors.background,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSizes.sm,
              vertical: AppSizes.sm,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSizes.radiusSm),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSizes.radiusSm),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSizes.radiusSm),
              borderSide: const BorderSide(
                color: AppColors.primary,
                width: 1.5,
              ),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSizes.radiusSm),
              borderSide: const BorderSide(color: AppColors.borderLight),
            ),
            errorText: errorText,
          ),
        ),
        const SizedBox(height: AppSizes.sm),
        Align(
          alignment: Alignment.centerRight,
          child: SizedBox(
            height: 36,
            child: ElevatedButton(
              onPressed: isSubmitting ? null : onSubmit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.textOnPrimary,
                disabledBackgroundColor: AppColors.primary.withAlpha(100),
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSizes.md,
                  vertical: 0,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                ),
              ),
              child: isSubmitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Submit Reply',
                      style: TextStyle(
                        fontSize: AppSizes.fontSm,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
//  Empty state
// ─────────────────────────────────────────────────────────────────────
class _EmptyReviewsView extends StatelessWidget {
  const _EmptyReviewsView();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSizes.xl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.primary.withAlpha(14),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.rate_review_outlined,
              size: 38,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: AppSizes.lg),
          const Text(
            'No reviews yet',
            style: TextStyle(
              fontSize: AppSizes.fontXl,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSizes.sm),
          const Text(
            'Customer reviews for your restaurant will appear here once orders are delivered and reviewed.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: AppSizes.fontMd,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
//  Helpers
// ─────────────────────────────────────────────────────────────────────

/// Renders up to 5 filled/empty star icons.
class _StarRow extends StatelessWidget {
  const _StarRow({required this.rating, required this.size});

  final int rating;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final filled = i < rating.clamp(0, 5);
        return Icon(
          filled ? Icons.star_rounded : Icons.star_outline_rounded,
          size: size,
          color: filled ? AppColors.ratingStar : AppColors.textHint,
        );
      }),
    );
  }
}

String _initials(String name) {
  if (name.isEmpty) return '?';
  final parts = name.trim().split(RegExp(r'\s+'));
  if (parts.length >= 2) {
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }
  return name[0].toUpperCase();
}

String _formatDate(String iso) {
  if (iso.isEmpty) return '—';
  try {
    final dt = DateTime.parse(iso).toLocal();
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  } catch (_) {
    return iso.length >= 10 ? iso.substring(0, 10) : iso;
  }
}
