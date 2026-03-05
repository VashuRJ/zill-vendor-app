import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/services/api_service.dart';
import '../viewmodel/ticket_viewmodel.dart';
import 'create_ticket_sheet.dart';

class TicketsScreen extends StatelessWidget {
  const TicketsScreen({super.key, required this.apiService});

  final ApiService apiService;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => TicketViewModel(apiService: apiService),
      child: const _TicketsBody(),
    );
  }
}

class _TicketsBody extends StatefulWidget {
  const _TicketsBody();

  @override
  State<_TicketsBody> createState() => _TicketsBodyState();
}

class _TicketsBodyState extends State<_TicketsBody> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TicketViewModel>().fetchTickets();
    });
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text(
            'Support Tickets',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
          ),
          centerTitle: true,
          backgroundColor: AppColors.surface,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(10),
              ),
              child:
                  const Icon(Icons.arrow_back_ios_new_rounded, size: 16),
            ),
            onPressed: () => Navigator.pop(context),
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(46),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: AppSizes.md),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(10),
              ),
              child: TabBar(
                labelColor: AppColors.surface,
                unselectedLabelColor: AppColors.textSecondary,
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                ),
                indicator: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(8),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                splashBorderRadius: BorderRadius.circular(8),
                padding: const EdgeInsets.all(3),
                tabs: [
                  Tab(
                    child: Consumer<TicketViewModel>(
                      builder: (_, vm, _) =>
                          Text('Open (${vm.openCount})'),
                    ),
                  ),
                  Tab(
                    child: Consumer<TicketViewModel>(
                      builder: (_, vm, _) =>
                          Text('Resolved (${vm.resolvedCount})'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        body: Consumer<TicketViewModel>(
          builder: (context, vm, _) {
            // ── Loading ─────────────────────────────────────────
            if (vm.status == TicketsStatus.fetching && !vm.hasData) {
              return const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              );
            }
            // ── Error ───────────────────────────────────────────
            if (vm.status == TicketsStatus.error && !vm.hasData) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.cloud_off_rounded,
                        size: 52,
                        color: AppColors.textHint.withAlpha(100),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        vm.errorMessage ?? 'Something went wrong',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: vm.fetchTickets,
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: const Text('Retry'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }
            // ── Data ────────────────────────────────────────────
            return Column(
              children: [
                const SizedBox(height: AppSizes.md),
                // Stats Row
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSizes.md,
                  ),
                  child: _StatsRow(
                    total: vm.all.length,
                    open: vm.openCount,
                    resolved: vm.resolvedCount,
                  ),
                ),
                const SizedBox(height: AppSizes.md),
                // Tab Views
                Expanded(
                  child: TabBarView(
                    children: [
                      _TicketList(type: _TicketTabType.open),
                      _TicketList(type: _TicketTabType.resolved),
                    ],
                  ),
                ),
                // ── Sticky Bottom Button ──────────────────────────
                Container(
                  padding: EdgeInsets.fromLTRB(
                    AppSizes.md,
                    12,
                    AppSizes.md,
                    MediaQuery.of(context).padding.bottom + 12,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(12),
                        blurRadius: 10,
                        offset: const Offset(0, -3),
                      ),
                    ],
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    height: AppSizes.buttonHeight,
                    child: ElevatedButton.icon(
                      onPressed: () => _showCreateSheet(context),
                      icon: const Icon(
                        Icons.add_circle_outline_rounded,
                        size: 20,
                      ),
                      label: const Text(
                        'Raise New Ticket',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppSizes.buttonRadius,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _showCreateSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ChangeNotifierProvider.value(
        value: context.read<TicketViewModel>(),
        child: const CreateTicketSheet(),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Stats Row
// ─────────────────────────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  final int total;
  final int open;
  final int resolved;

  const _StatsRow({
    required this.total,
    required this.open,
    required this.resolved,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _StatChip(
          icon: Icons.confirmation_num_rounded,
          color: AppColors.info,
          label: 'Total',
          value: '$total',
        ),
        const SizedBox(width: 10),
        _StatChip(
          icon: Icons.pending_actions_rounded,
          color: AppColors.warning,
          label: 'Open',
          value: '$open',
        ),
        const SizedBox(width: 10),
        _StatChip(
          icon: Icons.check_circle_rounded,
          color: AppColors.success,
          label: 'Resolved',
          value: '$resolved',
        ),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;

  const _StatChip({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          boxShadow: const [
            BoxShadow(
              color: AppColors.shadowLight,
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color.withAlpha(20),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 16, color: color),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: color,
                    ),
                  ),
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textHint,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Ticket List (Open / Resolved tabs)
// ─────────────────────────────────────────────────────────────────────────────

enum _TicketTabType { open, resolved }

class _TicketList extends StatelessWidget {
  final _TicketTabType type;
  const _TicketList({required this.type});

  @override
  Widget build(BuildContext context) {
    return Consumer<TicketViewModel>(
      builder: (context, vm, _) {
        final list =
            type == _TicketTabType.open ? vm.open : vm.resolved;
        if (list.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  type == _TicketTabType.open
                      ? Icons.inbox_rounded
                      : Icons.task_alt_rounded,
                  size: 56,
                  color: AppColors.textHint.withAlpha(80),
                ),
                const SizedBox(height: 12),
                Text(
                  type == _TicketTabType.open
                      ? 'No open tickets'
                      : 'No resolved tickets',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textHint,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  type == _TicketTabType.open
                      ? 'Raise a ticket if you need help'
                      : 'Your resolved tickets will appear here',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textHint.withAlpha(160),
                  ),
                ),
              ],
            ),
          );
        }
        return RefreshIndicator(
          color: AppColors.primary,
          onRefresh: vm.fetchTickets,
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(
              AppSizes.md,
              0,
              AppSizes.md,
              AppSizes.md,
            ),
            itemCount: list.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (_, i) => _TicketCard(ticket: list[i]),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Ticket Card
// ─────────────────────────────────────────────────────────────────────────────

const _categoryIcons = {
  'order': Icons.receipt_long_rounded,
  'payment': Icons.payment_rounded,
  'delivery': Icons.delivery_dining_rounded,
  'refund': Icons.currency_exchange_rounded,
  'account': Icons.person_rounded,
  'vendor': Icons.store_rounded,
  'app': Icons.phone_android_rounded,
  'feedback': Icons.rate_review_rounded,
  'other': Icons.help_outline_rounded,
};

const _categoryColors = {
  'order': AppColors.primary,
  'payment': AppColors.success,
  'delivery': AppColors.info,
  'refund': AppColors.purple,
  'account': AppColors.orange,
  'vendor': AppColors.teal,
  'app': AppColors.error,
  'feedback': AppColors.warning,
  'other': AppColors.textHint,
};

Color _statusColor(String status) {
  switch (status) {
    case 'open':
      return AppColors.info;
    case 'in_progress':
      return AppColors.warning;
    case 'waiting_customer':
    case 'waiting_vendor':
      return AppColors.orange;
    case 'resolved':
      return AppColors.success;
    case 'closed':
      return AppColors.textHint;
    default:
      return AppColors.textHint;
  }
}

class _TicketCard extends StatelessWidget {
  final SupportTicket ticket;

  const _TicketCard({required this.ticket});

  @override
  Widget build(BuildContext context) {
    final catColor = _categoryColors[ticket.category] ?? AppColors.textHint;
    final catIcon = _categoryIcons[ticket.category] ?? Icons.help_outline_rounded;
    final sColor = _statusColor(ticket.status);
    final dateStr = DateFormat('dd MMM yyyy').format(ticket.createdAt);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadowLight,
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Top row: Ticket # + Status badge ──────────────────
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: catColor.withAlpha(20),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(catIcon, size: 20, color: catColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ticket.ticketNumber,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: catColor,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      ticket.subject,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: sColor.withAlpha(15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: sColor.withAlpha(40)),
                ),
                child: Text(
                  ticket.statusDisplay,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: sColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // ── Bottom row: Category + Priority + Date ────────────
          Row(
            children: [
              // Category chip
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: catColor.withAlpha(12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  ticket.categoryDisplay,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: catColor,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Priority chip
              _PriorityChip(priority: ticket.priority),
              const Spacer(),
              // Date
              Icon(
                Icons.schedule_rounded,
                size: 13,
                color: AppColors.textHint.withAlpha(140),
              ),
              const SizedBox(width: 3),
              Text(
                dateStr,
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.textHint.withAlpha(180),
                ),
              ),
              // Unread indicator
              if (ticket.hasUnreadResponse) ...[
                const SizedBox(width: 8),
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
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

class _PriorityChip extends StatelessWidget {
  final String priority;
  const _PriorityChip({required this.priority});

  @override
  Widget build(BuildContext context) {
    final Color color;
    final String label;
    switch (priority) {
      case 'urgent':
        color = AppColors.error;
        label = 'Urgent';
      case 'high':
        color = AppColors.orange;
        label = 'High';
      case 'medium':
        color = AppColors.warning;
        label = 'Medium';
      default:
        color = AppColors.textHint;
        label = 'Low';
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: color,
          ),
        ),
      ],
    );
  }
}
