import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/api_service.dart';
import '../viewmodel/transactions_viewmodel.dart';

// ─────────────────────────────────────────────────────────────────────
//  Route entry-point
// ─────────────────────────────────────────────────────────────────────

class TransactionsScreen extends StatelessWidget {
  const TransactionsScreen({super.key, required this.apiService});

  final ApiService apiService;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => TransactionsViewModel(apiService: apiService),
      child: const _TransactionsBody(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
//  Body
// ─────────────────────────────────────────────────────────────────────

class _TransactionsBody extends StatefulWidget {
  const _TransactionsBody();

  @override
  State<_TransactionsBody> createState() => _TransactionsBodyState();
}

class _TransactionsBodyState extends State<_TransactionsBody> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<TransactionsViewModel>().loadAll();
    });
  }

  void _openFilterSheet(TransactionsViewModel vm) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TransactionFilterSheet(
        currentFilter: vm.filter,
        onApply: (f) => vm.setFilter(f),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<TransactionsViewModel>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Transaction History',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        centerTitle: true,
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        actions: [
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.filter_list_rounded),
                tooltip: 'Filter',
                onPressed: () => _openFilterSheet(vm),
              ),
              if (vm.hasActiveFilters)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: _buildBody(vm),
    );
  }

  Widget _buildBody(TransactionsViewModel vm) {
    if (vm.status == TransactionsStatus.loading) {
      return const _ShimmerList();
    }

    if (vm.status == TransactionsStatus.error) {
      return _ErrorView(
        message: vm.errorMessage ?? 'Something went wrong.',
        onRetry: vm.loadAll,
      );
    }

    return Column(
      children: [
        // ── Active filter chips ──────────────────────────────────────
        if (vm.hasActiveFilters) _ActiveFilterBar(vm: vm),

        // ── Summary strip ────────────────────────────────────────────
        _SummaryStrip(
          total: vm.totalCount,
          filtered: vm.filteredCount,
          hasFilter: vm.hasActiveFilters,
        ),

        // ── Transaction list ─────────────────────────────────────────
        Expanded(
          child: vm.transactions.isEmpty
              ? const _EmptyState()
              : RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: vm.refresh,
                  child: ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    itemCount: vm.transactions.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 8),
                    itemBuilder: (_, i) =>
                        _TransactionCard(txn: vm.transactions[i]),
                  ),
                ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
//  Summary Strip
// ─────────────────────────────────────────────────────────────────────

class _SummaryStrip extends StatelessWidget {
  const _SummaryStrip({
    required this.total,
    required this.filtered,
    required this.hasFilter,
  });

  final int total;
  final int filtered;
  final bool hasFilter;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: AppColors.surface,
      child: Text(
        hasFilter
            ? 'Showing $filtered of $total transactions'
            : '$total transactions',
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
//  Active Filter Bar (chips)
// ─────────────────────────────────────────────────────────────────────

class _ActiveFilterBar extends StatelessWidget {
  const _ActiveFilterBar({required this.vm});

  final TransactionsViewModel vm;

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[];

    for (final t in vm.filter.types) {
      String label;
      switch (t) {
        case TransactionType.orderEarning:
          label = 'Orders';
          break;
        case TransactionType.payout:
          label = 'Payouts';
          break;
        case TransactionType.settlement:
          label = 'Settlements';
          break;
      }
      chips.add(_FilterChip(label: label));
    }

    for (final s in vm.filter.statuses) {
      chips.add(_FilterChip(label: s[0].toUpperCase() + s.substring(1)));
    }

    if (vm.filter.dateRange != null) {
      final fmt = DateFormat('dd MMM');
      final r = vm.filter.dateRange!;
      chips.add(
        _FilterChip(label: '${fmt.format(r.start)} – ${fmt.format(r.end)}'),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: AppColors.primary.withValues(alpha: 0.06),
      child: Row(
        children: [
          Expanded(child: Wrap(spacing: 6, runSpacing: 4, children: chips)),
          GestureDetector(
            onTap: vm.clearFilters,
            child: const Padding(
              padding: EdgeInsets.only(left: 8),
              child: Text(
                'Clear',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppColors.primaryDark,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
//  Transaction Card — Premium
// ─────────────────────────────────────────────────────────────────────

class _TransactionCard extends StatelessWidget {
  const _TransactionCard({required this.txn});

  final UnifiedTransaction txn;

  @override
  Widget build(BuildContext context) {
    final currFmt = NumberFormat.currency(symbol: '\u20B9', decimalDigits: 2);
    final dateFmt = DateFormat('dd MMM yyyy, hh:mm a');

    final Color amountColor;
    final String prefix;
    if (txn.isCredit) {
      amountColor = AppColors.success;
      prefix = '+';
    } else {
      amountColor = AppColors.error;
      prefix = '-';
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── Top Row: icon + description + amount ─────────────────
          Row(
            children: [
              // Type icon
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _iconBgColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(txn.typeIcon, size: 20, color: _iconColor),
              ),
              const SizedBox(width: 12),

              // Description + date
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      txn.description,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      dateFmt.format(txn.date),
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textHint,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Amount + status
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$prefix${currFmt.format(txn.netAmount)}',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: amountColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  _StatusBadge(
                    status: txn.normalizedStatus,
                    label: txn.statusLabel,
                  ),
                ],
              ),
            ],
          ),

          // ── Bottom Row: type label + reference ID ───────────────
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Text(
                  txn.typeLabel,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: _iconColor,
                  ),
                ),
                const Spacer(),
                Text(
                  txn.referenceId,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color get _iconBgColor {
    switch (txn.type) {
      case TransactionType.orderEarning:
        return AppColors.successLight;
      case TransactionType.payout:
        return AppColors.infoLight;
      case TransactionType.settlement:
        return AppColors.warningLight;
    }
  }

  Color get _iconColor {
    switch (txn.type) {
      case TransactionType.orderEarning:
        return AppColors.success;
      case TransactionType.payout:
        return AppColors.info;
      case TransactionType.settlement:
        return AppColors.warning;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────
//  Status Badge
// ─────────────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status, required this.label});

  final String status;
  final String label;

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;

    switch (status) {
      case 'success':
        bg = AppColors.successLight;
        fg = AppColors.success;
        break;
      case 'pending':
        bg = AppColors.warningLight;
        fg = AppColors.warning;
        break;
      case 'failed':
        bg = AppColors.errorLight;
        fg = AppColors.error;
        break;
      default:
        bg = AppColors.background;
        fg = AppColors.textSecondary;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: fg,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
//  Empty State
// ─────────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.receipt_long_rounded,
                size: 36,
                color: AppColors.textHint,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'No transactions found',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Your earnings, payouts, and settlements\nwill appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textHint,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
//  Error View
// ─────────────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.errorLight,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                size: 32,
                color: AppColors.error,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
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
//  Shimmer Loading
// ─────────────────────────────────────────────────────────────────────

class _ShimmerList extends StatelessWidget {
  const _ShimmerList();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 8,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) => const _ShimmerCard(),
    );
  }
}

class _ShimmerCard extends StatefulWidget {
  const _ShimmerCard();

  @override
  State<_ShimmerCard> createState() => _ShimmerCardState();
}

class _ShimmerCardState extends State<_ShimmerCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, child) {
        final opacity = 0.3 + (_anim.value * 0.4);
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.borderLight),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.shimmerBase.withValues(alpha: opacity),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 120,
                      height: 12,
                      decoration: BoxDecoration(
                        color: AppColors.shimmerBase.withValues(alpha: opacity),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: 80,
                      height: 10,
                      decoration: BoxDecoration(
                        color: AppColors.shimmerBase.withValues(alpha: opacity),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    width: 60,
                    height: 12,
                    decoration: BoxDecoration(
                      color: AppColors.shimmerBase.withValues(alpha: opacity),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: 48,
                    height: 16,
                    decoration: BoxDecoration(
                      color: AppColors.shimmerBase.withValues(alpha: opacity),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
//  AnimatedBuilder workaround for AnimatedWidget in StatefulWidget
// ─────────────────────────────────────────────────────────────────────
class AnimatedBuilder extends AnimatedWidget {
  const AnimatedBuilder({
    super.key,
    required Animation<double> animation,
    required this.builder,
  }) : super(listenable: animation);

  final Widget Function(BuildContext, Widget?) builder;

  @override
  Widget build(BuildContext context) => builder(context, null);
}

// ═════════════════════════════════════════════════════════════════════
//  FILTER BOTTOM SHEET
// ═════════════════════════════════════════════════════════════════════

class TransactionFilterSheet extends StatefulWidget {
  const TransactionFilterSheet({
    super.key,
    required this.currentFilter,
    required this.onApply,
  });

  final TransactionFilter currentFilter;
  final ValueChanged<TransactionFilter> onApply;

  @override
  State<TransactionFilterSheet> createState() => _TransactionFilterSheetState();
}

class _TransactionFilterSheetState extends State<TransactionFilterSheet> {
  late Set<TransactionType> _types;
  late Set<String> _statuses;
  DateTimeRange? _dateRange;

  @override
  void initState() {
    super.initState();
    _types = Set.from(widget.currentFilter.types);
    _statuses = Set.from(widget.currentFilter.statuses);
    _dateRange = widget.currentFilter.dateRange;
  }

  void _toggleType(TransactionType t) {
    setState(() {
      if (_types.contains(t)) {
        _types.remove(t);
      } else {
        _types.add(t);
      }
    });
  }

  void _toggleStatus(String s) {
    setState(() {
      if (_statuses.contains(s)) {
        _statuses.remove(s);
      } else {
        _statuses.add(s);
      }
    });
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 2),
      lastDate: now,
      initialDateRange:
          _dateRange ??
          DateTimeRange(
            start: now.subtract(const Duration(days: 30)),
            end: now,
          ),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: Theme.of(ctx).colorScheme.copyWith(
            primary: AppColors.primary,
            onPrimary: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _dateRange = picked);
    }
  }

  void _apply() {
    widget.onApply(
      TransactionFilter(
        types: _types,
        statuses: _statuses,
        dateRange: _dateRange,
      ),
    );
    Navigator.pop(context);
  }

  void _reset() {
    setState(() {
      _types.clear();
      _statuses.clear();
      _dateRange = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(20, 0, 20, 16 + bottomPad),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Handle ───────────────────────────────────────────────
          const SizedBox(height: 10),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.divider,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),

          // ── Header ───────────────────────────────────────────────
          Row(
            children: [
              const Text(
                'Filter Transactions',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: _reset,
                child: const Text(
                  'Reset',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── Transaction Type ─────────────────────────────────────
          _SectionLabel(label: 'TYPE'),
          const SizedBox(height: 8),
          Row(
            children: [
              _ChoiceChipCustom(
                label: 'Orders',
                icon: Icons.shopping_bag_rounded,
                selected: _types.contains(TransactionType.orderEarning),
                onTap: () => _toggleType(TransactionType.orderEarning),
              ),
              const SizedBox(width: 8),
              _ChoiceChipCustom(
                label: 'Payouts',
                icon: Icons.account_balance_rounded,
                selected: _types.contains(TransactionType.payout),
                onTap: () => _toggleType(TransactionType.payout),
              ),
              const SizedBox(width: 8),
              _ChoiceChipCustom(
                label: 'Settlements',
                icon: Icons.receipt_long_rounded,
                selected: _types.contains(TransactionType.settlement),
                onTap: () => _toggleType(TransactionType.settlement),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ── Status ───────────────────────────────────────────────
          _SectionLabel(label: 'STATUS'),
          const SizedBox(height: 8),
          Row(
            children: [
              _ChoiceChipCustom(
                label: 'Success',
                icon: Icons.check_circle_outline_rounded,
                selected: _statuses.contains('success'),
                onTap: () => _toggleStatus('success'),
                color: AppColors.success,
              ),
              const SizedBox(width: 8),
              _ChoiceChipCustom(
                label: 'Pending',
                icon: Icons.schedule_rounded,
                selected: _statuses.contains('pending'),
                onTap: () => _toggleStatus('pending'),
                color: AppColors.warning,
              ),
              const SizedBox(width: 8),
              _ChoiceChipCustom(
                label: 'Failed',
                icon: Icons.cancel_outlined,
                selected: _statuses.contains('failed'),
                onTap: () => _toggleStatus('failed'),
                color: AppColors.error,
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ── Date Range ───────────────────────────────────────────
          _SectionLabel(label: 'DATE RANGE'),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: _pickDateRange,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: _dateRange != null
                    ? AppColors.primary.withValues(alpha: 0.06)
                    : AppColors.background,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _dateRange != null
                      ? AppColors.primary.withValues(alpha: 0.3)
                      : AppColors.borderLight,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.calendar_today_rounded,
                    size: 16,
                    color: _dateRange != null
                        ? AppColors.primary
                        : AppColors.textHint,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _dateRange != null
                          ? '${DateFormat('dd MMM yyyy').format(_dateRange!.start)} – ${DateFormat('dd MMM yyyy').format(_dateRange!.end)}'
                          : 'Select date range',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: _dateRange != null
                            ? AppColors.textPrimary
                            : AppColors.textHint,
                      ),
                    ),
                  ),
                  if (_dateRange != null)
                    GestureDetector(
                      onTap: () => setState(() => _dateRange = null),
                      child: const Icon(
                        Icons.close_rounded,
                        size: 16,
                        color: AppColors.textHint,
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // ── Apply Button ─────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _apply,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Apply Filters',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
//  Shared Filter Sheet Widgets
// ─────────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: AppColors.textHint,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _ChoiceChipCustom extends StatelessWidget {
  const _ChoiceChipCustom({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.color,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final activeColor = color ?? AppColors.primary;

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? activeColor.withValues(alpha: 0.1)
                : AppColors.background,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected
                  ? activeColor.withValues(alpha: 0.4)
                  : AppColors.borderLight,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: 18,
                color: selected ? activeColor : AppColors.textHint,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? activeColor : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
