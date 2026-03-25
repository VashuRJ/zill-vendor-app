// ─────────────────────────────────────────
// Zill Restaurant Partner — Vendor App
// Author: Vashu Mogha (@Its-vashu)
// ─────────────────────────────────────────
// lib/features/orders/view/order_detail_screen.dart
// Full-page Order Detail Screen for Vendor App
// ─────────────────────────────────────────────────────────────────────────────

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/services/websocket_service.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/services/api_service.dart';
import '../viewmodel/orders_viewmodel.dart';
import '../viewmodel/tracking_viewmodel.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Entry point
// ─────────────────────────────────────────────────────────────────────────────

class OrderDetailScreen extends StatefulWidget {
  const OrderDetailScreen({super.key, required this.order, required this.vm});

  final VendorOrder order;
  final OrdersViewModel vm;

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

// ─────────────────────────────────────────────────────────────────────────────
//  State
// ─────────────────────────────────────────────────────────────────────────────

class _OrderDetailScreenState extends State<OrderDetailScreen>
    with SingleTickerProviderStateMixin {
  VendorOrderDetail? _detail;
  bool _loadingDetail = true;
  String? _detailError;

  // Local copy of the base order (updated after actions)
  late VendorOrder _order;

  // Prep time input for accept dialog
  final _prepTimeController = TextEditingController(text: '30');

  // Reject reason state
  String _rejectReason = 'restaurant_busy';
  final _rejectReasonController = TextEditingController();

  final _currFmt = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 2,
  );

  // Tracking VM — fetches rider details for active delivery orders
  TrackingViewModel? _trackingVm;
  WebSocketService? _wsService; // cached for dispose
  int? _trackingOrderId; // WS connection key for cleanup

  // Animation controller for pulsing NEW badge on pending orders
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _order = widget.order;
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(
      begin: 0.6,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
    _fetchDetail();
    _initTrackingIfNeeded();
  }

  @override
  void dispose() {
    _prepTimeController.dispose();
    _rejectReasonController.dispose();
    _pulseCtrl.dispose();
    _trackingVm?.removeListener(_onTrackingUpdate);
    _trackingVm?.stopTracking();
    _trackingVm?.dispose();
    if (_trackingOrderId != null) {
      _wsService?.disconnectOrderTracking(_trackingOrderId!);
    }
    super.dispose();
  }

  void _initTrackingIfNeeded() {
    final s = _order.status;
    if (s == 'ready' || s == 'picked' || s == 'on_the_way') {
      _trackingVm = TrackingViewModel(apiService: context.read<ApiService>());
      _trackingVm!.addListener(_onTrackingUpdate);
      _trackingVm!.startTracking(_order.id);
      // Wire WebSocket for real-time tracking
      _trackingOrderId = _order.id;
      _wsService = context.read<WebSocketService>();
      _wsService!.connectOrderTracking(_order.id);
      _trackingVm!.listenToWebSocket(_wsService!.onOrderTracking);
    }
  }

  void _onTrackingUpdate() {
    if (mounted) setState(() {});
  }

  // ── Data fetch ────────────────────────────────────────────────────────────

  Future<void> _fetchDetail() async {
    if (!mounted) return;
    setState(() {
      _loadingDetail = true;
      _detailError = null;
    });
    try {
      final detail = await widget.vm.fetchOrderDetail(_order.id);
      if (!mounted) return;
      if (detail != null) {
        setState(() {
          _detail = detail;
          _order = detail.order; // refresh base order from fresh data
          _loadingDetail = false;
        });
      } else {
        setState(() {
          _loadingDetail = false;
          _detailError = 'Could not load order details.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingDetail = false;
        _detailError = 'Failed to load details. Tap to retry.';
      });
    }
  }

  // ── Actions ───────────────────────────────────────────────────────────────

  Future<void> _accept() async {
    final prepTime = int.tryParse(_prepTimeController.text.trim()) ?? 30;
    final confirmed = await _showAcceptDialog();
    if (!confirmed || !mounted) return;

    await widget.vm.acceptOrder(_order.id, estimatedPrepTime: prepTime);
    if (!mounted) return;
    _showSnack('Order accepted! Prep time: $prepTime min', success: true);
    await _fetchDetail();
  }

  Future<void> _reject() async {
    final confirmed = await _showRejectDialog();
    if (!confirmed || !mounted) return;

    await widget.vm.rejectOrder(
      _order.id,
      reason: _rejectReasonController.text.trim().isEmpty
          ? _rejectReason
          : _rejectReasonController.text.trim(),
      cancellationReason: _rejectReason,
    );
    if (!mounted) return;
    _showSnack('Order has been rejected.', success: false);
    await _fetchDetail();
  }

  Future<void> _startPreparing() async {
    await widget.vm.startPreparing(_order.id);
    if (!mounted) return;
    _showSnack('Started preparing!', success: true);
    await _fetchDetail();
  }

  Future<void> _markReady() async {
    await widget.vm.markReady(_order.id);
    if (!mounted) return;
    _showSnack('Order marked as Ready!', success: true);
    await _fetchDetail();
  }

  void _showTrackingSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TrackingSheet(orderId: _order.id),
    );
  }

  void _showSnack(String msg, {required bool success}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              success ? Icons.check_circle_rounded : Icons.error_rounded,
              color: success ? AppColors.success : AppColors.error,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                msg,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        behavior: SnackBarBehavior.floating,
        elevation: 6,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: success
                ? AppColors.success.withAlpha(100)
                : AppColors.error.withAlpha(100),
          ),
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // ── Dialog: Accept ────────────────────────────────────────────────────────

  Future<bool> _showAcceptDialog() async {
    _prepTimeController.text = '30';
    final formKey = GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          scrollable: true,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.radiusLg),
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.successLight,
                      borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                    ),
                    child: const Icon(
                      Icons.check_circle,
                      color: AppColors.success,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Accept Order',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          _order.orderNumber,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              // Brief items list
              if (_order.items.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                  ),
                  child: Column(
                    children: _order.items
                        .map(
                          (it) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Row(
                              children: [
                                Text(
                                  '${it.quantity} x ',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    it.itemName,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textPrimary,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Text(
                                  _currFmt.format(it.subtotal),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ],
          ),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Estimated Preparation Time',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _prepTimeController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                  decoration: InputDecoration(
                    suffixText: 'minutes',
                    suffixStyle: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                      borderSide: const BorderSide(
                        color: AppColors.primary,
                        width: 2,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                  validator: (v) {
                    final n = int.tryParse(v ?? '');
                    if (n == null || n < 5 || n > 180) {
                      return 'Enter a time between 5 and 180 minutes';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 4),
                const Text(
                  'Customer will see this as expected wait time.',
                  style: TextStyle(fontSize: 11, color: AppColors.textHint),
                ),
              ],
            ),
          ),
          actionsPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
          actions: [
            OutlinedButton(
              onPressed: () => Navigator.pop(ctx, false),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.border),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                ),
              ),
              child: const Text(
                'Cancel',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.success,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                ),
              ),
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.pop(ctx, true);
                }
              },
              child: const Text('Accept Order'),
            ),
          ],
        ),
      ),
    );
    return confirmed ?? false;
  }

  // ── Dialog: Reject ────────────────────────────────────────────────────────

  Future<bool> _showRejectDialog() async {
    _rejectReason = 'restaurant_busy';
    _rejectReasonController.clear();

    const reasons = [
      ('restaurant_busy', 'Restaurant too busy', Icons.hourglass_top),
      ('item_unavailable', 'Item(s) unavailable', Icons.no_food),
      ('restaurant_closed', 'Restaurant closed', Icons.store_outlined),
      ('other', 'Other reason', Icons.more_horiz),
    ];

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.radiusLg),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.errorLight,
                  borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                ),
                child: const Icon(
                  Icons.cancel_outlined,
                  color: AppColors.error,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Reject Order',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Warning banner
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3CD),
                  borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                  border: Border.all(color: const Color(0xFFFFCA2C)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      size: 18,
                      color: Color(0xFF856404),
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Frequent rejections may affect your restaurant rating.',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF856404),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Select reason:',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              ...reasons.map((r) {
                final (value, label, icon) = r;
                final selected = _rejectReason == value;
                return GestureDetector(
                  onTap: () => setDialogState(() => _rejectReason = value),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.errorLight
                          : AppColors.background,
                      borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                      border: Border.all(
                        color: selected
                            ? AppColors.error
                            : AppColors.borderLight,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          icon,
                          size: 17,
                          color: selected
                              ? AppColors.error
                              : AppColors.textSecondary,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          label,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: selected
                                ? FontWeight.w600
                                : FontWeight.w400,
                            color: selected
                                ? AppColors.error
                                : AppColors.textPrimary,
                          ),
                        ),
                        const Spacer(),
                        if (selected)
                          const Icon(
                            Icons.check_circle,
                            size: 16,
                            color: AppColors.error,
                          ),
                      ],
                    ),
                  ),
                );
              }),
              if (_rejectReason == 'other') ...[
                const SizedBox(height: 8),
                TextField(
                  controller: _rejectReasonController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: 'Please describe the reason…',
                    hintStyle: const TextStyle(
                      color: AppColors.textHint,
                      fontSize: 13,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                      borderSide: const BorderSide(
                        color: AppColors.error,
                        width: 2,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                ),
              ],
            ],
          ),
          actionsPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
          actions: [
            OutlinedButton(
              onPressed: () => Navigator.pop(ctx, false),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.border),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                ),
              ),
              child: const Text(
                'Cancel',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.error,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                ),
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Reject Order'),
            ),
          ],
        ),
      ),
    );
    return confirmed ?? false;
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  Build
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isLoading = widget.vm.isActionLoading(_order.id);

    return ListenableBuilder(
      listenable: widget.vm,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: _buildAppBar(),
          body: _buildBody(),
          bottomNavigationBar: _buildActionBar(isLoading),
        );
      },
    );
  }

  // ── AppBar ────────────────────────────────────────────────────────────────

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppColors.surface,
      elevation: 0,
      scrolledUnderElevation: 1,
      shadowColor: AppColors.shadow.withAlpha(80),
      leadingWidth: 48,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
        color: AppColors.textPrimary,
        onPressed: () => Navigator.pop(context),
      ),
      title: GestureDetector(
        onTap: () {
          Clipboard.setData(ClipboardData(text: _order.orderNumber));
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.copy, color: Colors.white, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Order ID copied: ${_order.orderNumber}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSizes.radiusMd),
              ),
            ),
          );
        },
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                _order.orderNumber,
                style: const TextStyle(
                  fontSize: AppSizes.fontLg,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  letterSpacing: 0.3,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.copy_outlined,
              size: 14,
              color: AppColors.textHint,
            ),
          ],
        ),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 14),
          child: _StatusChip(status: _order.status),
        ),
      ],
    );
  }

  // ── Body ──────────────────────────────────────────────────────────────────

  Widget _buildBody() {
    if (_loadingDetail) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: AppColors.primary),
            SizedBox(height: 14),
            Text(
              'Loading order details…',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          ],
        ),
      );
    }

    if (_detailError != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 52, color: AppColors.error),
            const SizedBox(height: 12),
            Text(
              _detailError!,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _fetchDetail,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildTimeStrip(),
          if (_order.instructions.isNotEmpty) _buildCustomerNotesBox(),
          // ── Rider info (for active delivery orders) ──
          if (_trackingVm != null) _buildRiderSection(),
          _buildCustomerSection(),
          if (_order.orderType == 'delivery') _buildAddressSection(),
          _buildPaymentSection(),
          _buildItemsSection(),
          _buildPriceSummary(),
          if (_order.estimatedPrepTime != null ||
              _order.estimatedDeliveryTime != null)
            _buildEtaSection(),
          if (_order.isScheduled && _order.scheduledFor != null)
            _buildScheduledSection(),
          if (_order.status == 'cancelled' || _order.status == 'refunded')
            _buildCancellationSection(),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  // ── Time strip ────────────────────────────────────────────────────────────

  Widget _buildTimeStrip() {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      child: Row(
        children: [
          // Pulsing dot for new/pending orders
          if (_order.status == 'pending')
            AnimatedBuilder(
              animation: _pulseAnim,
              builder: (animContext, _) => Opacity(
                opacity: _pulseAnim.value,
                child: Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: const BoxDecoration(
                    color: Color(0xFFDC3545),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          const Icon(Icons.schedule, size: 14, color: AppColors.textSecondary),
          const SizedBox(width: 5),
          Text(
            _timeAgo(_order.createdAt),
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          _OrderTypeBadge(orderType: _order.orderType),
          if (_order.isScheduled) ...[
            const SizedBox(width: 6),
            _ScheduledChip(scheduledFor: _order.scheduledFor),
          ],
        ],
      ),
    );
  }

  // ── Customer notes (special instructions) ────────────────────────────────

  Widget _buildCustomerNotesBox() {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 12, 14, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        border: Border.all(color: const Color(0xFFFFE082), width: 1.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 1),
            child: Icon(
              Icons.warning_amber_rounded,
              size: 18,
              color: Color(0xFFE65100),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'CUSTOMER NOTE',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFFE65100),
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _order.instructions,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF6D4C00),
                    fontWeight: FontWeight.w500,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Customer section ──────────────────────────────────────────────────────

  Widget _buildCustomerSection() {
    // Determine if there's a different recipient
    final hasRecipient = _order.recipientName != null &&
        _order.recipientName!.isNotEmpty &&
        _order.recipientName != _order.customerName;
    final callPhone = hasRecipient && _order.recipientPhone != null && _order.recipientPhone!.isNotEmpty
        ? _order.recipientPhone!
        : _order.customerPhone;

    return _DetailSection(
      icon: Icons.person_outline_rounded,
      title: 'Customer',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _order.customerName,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (_order.customerPhone.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        _order.customerPhone,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (callPhone.isNotEmpty) ...[
                _ActionIconBtn(
                  icon: Icons.phone,
                  color: AppColors.success,
                  bgColor: AppColors.successLight,
                  tooltip: hasRecipient ? 'Call recipient' : 'Call customer',
                  onTap: () async {
                    final uri = Uri.parse('tel:$callPhone');
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri);
                    } else {
                      Clipboard.setData(ClipboardData(text: callPhone));
                      if (mounted) {
                        _showSnack(
                          'Phone copied (dial not supported)',
                          success: true,
                        );
                      }
                    }
                  },
                ),
                const SizedBox(width: 8),
                _ActionIconBtn(
                  icon: Icons.copy_rounded,
                  color: AppColors.textSecondary,
                  bgColor: AppColors.border.withAlpha(90),
                  tooltip: 'Copy number',
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: callPhone));
                    _showSnack('Phone number copied', success: true);
                  },
                ),
              ],
            ],
          ),
          // Recipient info (if different from customer)
          if (hasRecipient) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF0F4FF),
                borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                border: Border.all(color: const Color(0xFFB8D0FF)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.card_giftcard_rounded, size: 16, color: Color(0xFF3366CC)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Deliver to Recipient',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF3366CC),
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${_order.recipientName}'
                          '${_order.recipientPhone != null && _order.recipientPhone!.isNotEmpty ? '  •  ${_order.recipientPhone}' : ''}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Address section ───────────────────────────────────────────────────────

  Widget _buildAddressSection() {
    final deliveryInstructions = _detail?.deliveryInstructions;
    return _DetailSection(
      icon: Icons.location_on_outlined,
      title: 'Delivery Address',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _order.deliveryAddress,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textPrimary,
              height: 1.5,
            ),
          ),
          if (deliveryInstructions != null &&
              deliveryInstructions.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primaryLight.withAlpha(40),
                borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                border: Border.all(color: AppColors.primary.withAlpha(60)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.directions,
                    size: 14,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      deliveryInstructions,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w500,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Payment section ───────────────────────────────────────────────────────

  Widget _buildPaymentSection() {
    final (IconData icon, String label, Color color) = switch (_order
        .paymentMethod
        .toLowerCase()) {
      'cod' => (
        Icons.money_rounded,
        'Cash on Delivery',
        const Color(0xFF2E7D32),
      ),
      'upi' => (Icons.phone_android, 'UPI', const Color(0xFF6A1B9A)),
      'card' => (Icons.credit_card, 'Card', const Color(0xFF1565C0)),
      'online' ||
      'razorpay' => (Icons.payment, 'Online Payment', const Color(0xFF283593)),
      _ => (Icons.payment, _order.paymentMethod, AppColors.textSecondary),
    };

    final isPaid =
        _order.paymentStatus.toLowerCase() == 'paid' ||
        _order.paymentStatus.toLowerCase() == 'completed';
    final isPending = _order.paymentStatus.toLowerCase() == 'pending';

    return _DetailSection(
      icon: Icons.receipt_outlined,
      title: 'Payment',
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withAlpha(20),
              borderRadius: BorderRadius.circular(AppSizes.radiusSm),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
                Text(
                  _order.paymentStatus.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textHint,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isPaid
                  ? AppColors.successLight
                  : isPending
                  ? const Color(0xFFFFF3CD)
                  : AppColors.errorLight,
              borderRadius: BorderRadius.circular(AppSizes.radiusFull),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isPaid ? Icons.check_circle : Icons.pending_outlined,
                  size: 12,
                  color: isPaid
                      ? AppColors.success
                      : isPending
                      ? const Color(0xFF856404)
                      : AppColors.error,
                ),
                const SizedBox(width: 4),
                Text(
                  _order.paymentStatus.toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isPaid
                        ? AppColors.success
                        : isPending
                        ? const Color(0xFF856404)
                        : AppColors.error,
                  ),
                ),
                // Payment verified badge
                if (_order.isPaymentVerified) ...[
                  const SizedBox(width: 6),
                  const Icon(Icons.verified, size: 14, color: AppColors.success),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Items section ─────────────────────────────────────────────────────────

  Widget _buildItemsSection() {
    return _DetailSection(
      icon: Icons.shopping_bag_outlined,
      title: 'Order Items (${_order.itemsCount})',
      child: Column(
        children: _order.items.asMap().entries.map((entry) {
          final isLast = entry.key == _order.items.length - 1;
          return Column(
            children: [
              _buildItemRow(entry.value),
              if (!isLast)
                Divider(
                  height: 16,
                  color: AppColors.borderLight,
                  thickness: 0.5,
                ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildItemRow(OrderLineItem item) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Item name row with qty circle
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Quantity x
            Text(
              '${item.quantity} x ',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.itemName,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (item.variantName != null &&
                      item.variantName!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      item.variantName!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _currFmt.format(item.subtotal),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        // Add-ons
        if (item.selectedAddons.isNotEmpty) ...[
          const SizedBox(height: 6),
          ...item.selectedAddons.map(
            (addon) => Padding(
              padding: const EdgeInsets.only(left: 38, bottom: 2),
              child: Row(
                children: [
                  const Icon(Icons.add, size: 10, color: AppColors.textHint),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      addon.addonName,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  Text(
                    '+${_currFmt.format(addon.addonPrice)}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        // Per-item special note
        if (item.specialInstructions.isNotEmpty) ...[
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 28),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.edit_note, size: 13, color: Color(0xFF6D4C00)),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    item.specialInstructions,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF6D4C00),
                      fontStyle: FontStyle.italic,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        // Unit price breakdown if addons present
        if (item.selectedAddons.isNotEmpty) ...[
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 28),
            child: Text(
              '${_currFmt.format(item.unitPrice)} × ${item.quantity}'
              '${item.addonsPrice > 0 ? ' + ${_currFmt.format(item.addonsPrice)} add-ons' : ''}',
              style: const TextStyle(fontSize: 11, color: AppColors.textHint),
            ),
          ),
        ],
      ],
    );
  }

  // ── Price summary ─────────────────────────────────────────────────────────

  Widget _buildPriceSummary() {
    final detail = _detail;

    return _DetailSection(
      icon: Icons.calculate_outlined,
      title: 'Price Breakdown',
      child: Column(
        children: [
          // Row: Item total (from base order items or detail subtotal)
          _PriceRow(
            label: 'Item Total',
            value:
                detail?.subtotal ??
                _order.items.fold(0.0, (sum, it) => sum + it.subtotal),
            currFmt: _currFmt,
          ),
          if (detail != null && detail.deliveryCharge > 0)
            _PriceRow(
              label: 'Delivery Charge',
              value: detail.deliveryCharge,
              currFmt: _currFmt,
            ),
          if (detail != null && detail.taxAmount > 0)
            _PriceRow(
              label: 'Taxes & Fees',
              value: detail.taxAmount,
              currFmt: _currFmt,
            ),
          if (detail != null && detail.discountAmount > 0)
            _PriceRow(
              label: 'Discount',
              value: detail.discountAmount,
              currFmt: _currFmt,
              isDiscount: true,
            ),
          if (detail != null && detail.couponCode.isNotEmpty) ...[
            _PriceRow(
              label: 'Coupon (${detail.couponCode})',
              value: detail.couponDiscount,
              currFmt: _currFmt,
              isDiscount: true,
            ),
            if (detail.isPlatformFundedCoupon)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F5E9),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: const Color(0xFFA5D6A7)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.verified_outlined, size: 12, color: Color(0xFF2E7D32)),
                          SizedBox(width: 4),
                          Text(
                            'Platform Funded',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF2E7D32),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
          const SizedBox(height: 8),
          const Divider(height: 1, color: AppColors.borderLight),
          const SizedBox(height: 10),
          // Grand total
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Grand Total',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                _currFmt.format(_order.totalAmount),
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Rider / Delivery Tracking section ─────────────────────────────────────

  Widget _buildRiderSection() {
    final vm = _trackingVm!;
    final partner = vm.partner;
    final ts = vm.trackingStatus;
    final eta = vm.eta;

    // Still loading
    if (vm.isLoading && !vm.hasData) {
      return _DetailSection(
        icon: Icons.delivery_dining,
        title: 'Delivery Partner',
        child: Row(
          children: [
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Finding rider info…',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          ],
        ),
      );
    }

    // Error and no data
    if (vm.status == TrackingViewStatus.error && !vm.hasData) {
      return const SizedBox.shrink();
    }

    // No partner assigned yet
    if (partner == null) {
      return _DetailSection(
        icon: Icons.delivery_dining,
        title: 'Delivery Partner',
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF3CD),
            borderRadius: BorderRadius.circular(AppSizes.radiusMd),
            border: Border.all(color: const Color(0xFFFFCA2C)),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.hourglass_top,
                size: 18,
                color: Color(0xFF856404),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Not Assigned Yet',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF856404),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'A delivery partner will be assigned shortly',
                      style: TextStyle(
                        fontSize: 11,
                        color: const Color(0xFF856404).withAlpha(180),
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

    // Partner assigned — show full rider card
    return _DetailSection(
      icon: Icons.delivery_dining,
      title: 'Delivery Partner',
      child: Column(
        children: [
          // ── Rider info card ──
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(AppSizes.radiusMd),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    // Avatar
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: AppColors.primary.withAlpha(30),
                      backgroundImage: partner.profilePhoto != null
                          ? CachedNetworkImageProvider(partner.profilePhoto!)
                          : null,
                      onBackgroundImageError: (_, _) {},
                      child: partner.profilePhoto == null
                          ? const Icon(
                              Icons.person,
                              color: AppColors.primary,
                              size: 22,
                            )
                          : null,
                    ),
                    const SizedBox(width: 12),
                    // Name + vehicle
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            partner.name,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              if (partner.vehicleDisplay.isNotEmpty) ...[
                                Icon(
                                  Icons.two_wheeler,
                                  size: 13,
                                  color: AppColors.textSecondary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  partner.vehicleDisplay,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                              if (partner.vehicleNumber.isNotEmpty) ...[
                                const SizedBox(width: 8),
                                Text(
                                  partner.vehicleNumber,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Rating
                    if (partner.rating > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.success.withAlpha(25),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.star,
                              size: 13,
                              color: AppColors.success,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              partner.rating.toStringAsFixed(1),
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.success,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                // Call button
                if (partner.phone.isNotEmpty)
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        final uri = Uri(scheme: 'tel', path: partner.phone);
                        launchUrl(uri);
                      },
                      icon: const Icon(Icons.call, size: 16),
                      label: Text('Call ${partner.name.split(' ').first}'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.success,
                        side: BorderSide(
                          color: AppColors.success.withAlpha(100),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          // ── Status + ETA row ──
          Row(
            children: [
              // Status badge
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: switch (ts?.status) {
                      'heading_to_restaurant' => const Color(0xFFCFE2FF),
                      'at_restaurant' => const Color(0xFFD4EDDA),
                      'out_for_delivery' => const Color(0xFFCFE2FF),
                      'near_customer' => const Color(0xFFD4EDDA),
                      'delivered' => const Color(0xFFD4EDDA),
                      _ => const Color(0xFFFFF3CD),
                    },
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        switch (ts?.status) {
                          'heading_to_restaurant' => Icons.directions_bike,
                          'at_restaurant' => Icons.store,
                          'out_for_delivery' => Icons.delivery_dining,
                          'near_customer' => Icons.pin_drop,
                          'delivered' => Icons.check_circle,
                          _ => Icons.schedule,
                        },
                        size: 14,
                        color: switch (ts?.status) {
                          'heading_to_restaurant' => const Color(0xFF0A58CA),
                          'at_restaurant' => const Color(0xFF155724),
                          'out_for_delivery' => const Color(0xFF0A58CA),
                          'near_customer' => const Color(0xFF155724),
                          'delivered' => const Color(0xFF155724),
                          _ => const Color(0xFF856404),
                        },
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          ts?.statusDisplay ?? 'Tracking…',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: switch (ts?.status) {
                              'heading_to_restaurant' => const Color(
                                0xFF0A58CA,
                              ),
                              'at_restaurant' => const Color(0xFF155724),
                              'out_for_delivery' => const Color(0xFF0A58CA),
                              'near_customer' => const Color(0xFF155724),
                              'delivered' => const Color(0xFF155724),
                              _ => const Color(0xFF856404),
                            },
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Pickup ETA
              if (eta != null && eta.pickupMinutes != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withAlpha(15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.primary.withAlpha(40)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.timer,
                        size: 14,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        eta.pickupDisplay,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // ── ETA section ───────────────────────────────────────────────────────────

  Widget _buildEtaSection() {
    return _DetailSection(
      icon: Icons.timer_outlined,
      title: 'Preparation & Delivery',
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          if (_order.estimatedPrepTime != null)
            _EtaBadge(
              icon: Icons.restaurant,
              label: 'PREP TIME',
              value: '${_order.estimatedPrepTime} min',
              color: AppColors.primary,
            ),
          if (_order.estimatedDeliveryTime != null)
            _EtaBadge(
              icon: Icons.delivery_dining,
              label: 'Expected Delivery',
              value: DateFormat(
                'hh:mm a',
              ).format(_order.estimatedDeliveryTime!.toLocal()),
              color: AppColors.success,
            ),
        ],
      ),
    );
  }

  // ── Scheduled section ─────────────────────────────────────────────────────

  Widget _buildScheduledSection() {
    return _DetailSection(
      icon: Icons.event_outlined,
      title: 'Scheduled Order',
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF3CD),
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          border: Border.all(color: const Color(0xFFFFCA2C)),
        ),
        child: Row(
          children: [
            const Icon(Icons.schedule, size: 18, color: Color(0xFF856404)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Delivery Scheduled For',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF856404),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    DateFormat(
                      'EEEE, d MMMM · hh:mm a',
                    ).format(_order.scheduledFor!.toLocal()),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF6D4C00),
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

  // ── Cancellation section ──────────────────────────────────────────────────

  Widget _buildCancellationSection() {
    final cancellationNote = _detail?.cancellationNote;
    final cancellationReason = _detail?.cancellationReason;
    if ((cancellationNote == null || cancellationNote.isEmpty) &&
        (cancellationReason == null || cancellationReason.isEmpty)) {
      return const SizedBox.shrink();
    }
    return _DetailSection(
      icon: Icons.cancel_outlined,
      title: 'Cancellation Info',
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.errorLight,
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          border: Border.all(color: AppColors.error.withAlpha(80)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (cancellationReason != null &&
                cancellationReason.isNotEmpty) ...[
              Text(
                cancellationReason.replaceAll('_', ' ').toUpperCase(),
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.error,
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(height: 4),
            ],
            if (cancellationNote != null && cancellationNote.isNotEmpty)
              Text(
                cancellationNote,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.error,
                  height: 1.4,
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── Bottom action bar ─────────────────────────────────────────────────────

  Widget? _buildActionBar(bool isLoading) {
    final status = _order.status.toLowerCase();
    if (!['pending', 'confirmed', 'preparing', 'ready'].contains(status)) {
      return null;
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow.withAlpha(40),
            offset: const Offset(0, -3),
            blurRadius: 12,
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: switch (status) {
            'pending' => Row(
              children: [
                // Reject button
                Expanded(
                  flex: 2,
                  child: OutlinedButton(
                    onPressed: isLoading ? null : () => _reject(),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(
                        double.infinity,
                        AppSizes.buttonHeight,
                      ),
                      side: BorderSide(
                        color: isLoading
                            ? AppColors.borderLight
                            : AppColors.error,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          AppSizes.buttonRadius,
                        ),
                      ),
                    ),
                    child: isLoading
                        ? _btnSpinner(color: AppColors.error)
                        : const Text(
                            'Reject',
                            style: TextStyle(
                              color: AppColors.error,
                              fontWeight: FontWeight.w700,
                              fontSize: AppSizes.fontLg,
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 10),
                // Accept button
                Expanded(
                  flex: 3,
                  child: FilledButton(
                    onPressed: isLoading ? null : () => _accept(),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.success,
                      minimumSize: const Size(
                        double.infinity,
                        AppSizes.buttonHeight,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          AppSizes.buttonRadius,
                        ),
                      ),
                    ),
                    child: isLoading
                        ? _btnSpinner(color: Colors.white)
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.check_circle_outline,
                                size: 18,
                                color: Colors.white,
                              ),
                              SizedBox(width: 6),
                              Text(
                                'Accept Order',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: AppSizes.fontLg,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ],
            ),
            'confirmed' => SizedBox(
              width: double.infinity,
              height: AppSizes.buttonHeight,
              child: FilledButton(
                onPressed: isLoading ? null : () => _startPreparing(),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF8E24AA),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSizes.buttonRadius),
                  ),
                ),
                child: isLoading
                    ? _btnSpinner(color: Colors.white)
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.restaurant_menu,
                            size: 20,
                            color: Colors.white,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Start Preparing',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: AppSizes.fontXl,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            'preparing' => SizedBox(
              width: double.infinity,
              height: AppSizes.buttonHeight,
              child: FilledButton(
                onPressed: isLoading ? null : () => _markReady(),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.success,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSizes.buttonRadius),
                  ),
                ),
                child: isLoading
                    ? _btnSpinner(color: Colors.white)
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.done_all, size: 20, color: Colors.white),
                          SizedBox(width: 8),
                          Text(
                            'Mark as Ready',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: AppSizes.fontXl,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            'ready' || 'picked' || 'on_the_way' => Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Container(
                    height: AppSizes.buttonHeight,
                    decoration: BoxDecoration(
                      color: switch (_order.status) {
                        'picked' => const Color(0xFFD4EDDA),
                        'on_the_way' => const Color(0xFFCFE2FF),
                        _ => Colors.grey.shade100,
                      },
                      borderRadius: BorderRadius.circular(
                        AppSizes.buttonRadius,
                      ),
                      border: Border.all(
                        color: switch (_order.status) {
                          'picked' => const Color(0xFF155724).withAlpha(60),
                          'on_the_way' => const Color(0xFF0A58CA).withAlpha(60),
                          _ => Colors.grey.shade300,
                        },
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          switch (_order.status) {
                            'picked' => Icons.check_circle_outline,
                            'on_the_way' => Icons.delivery_dining,
                            _ => Icons.hourglass_top_rounded,
                          },
                          size: 15,
                          color: switch (_order.status) {
                            'picked' => const Color(0xFF155724),
                            'on_the_way' => const Color(0xFF0A58CA),
                            _ => Colors.grey.shade500,
                          },
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            switch (_order.status) {
                              'picked' => 'Picked Up',
                              'on_the_way' => 'Out for Delivery',
                              _ => 'Waiting for Pickup',
                            },
                            style: TextStyle(
                              color: switch (_order.status) {
                                'picked' => const Color(0xFF155724),
                                'on_the_way' => const Color(0xFF0A58CA),
                                _ => Colors.grey.shade600,
                              },
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    onPressed: () => _showTrackingSheet(),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF1565C0),
                      minimumSize: Size(double.infinity, AppSizes.buttonHeight),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          AppSizes.buttonRadius,
                        ),
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.location_on, size: 18, color: Colors.white),
                        SizedBox(width: 6),
                        Text(
                          'Track',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: AppSizes.fontLg,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            _ => const SizedBox.shrink(),
          },
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Helper: Loading spinner inside button
// ─────────────────────────────────────────────────────────────────────────────

Widget _btnSpinner({required Color color}) {
  return SizedBox(
    width: 18,
    height: 18,
    child: CircularProgressIndicator(
      strokeWidth: 2.5,
      valueColor: AlwaysStoppedAnimation<Color>(color),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  TimeAgo helper
// ─────────────────────────────────────────────────────────────────────────────

String _timeAgo(DateTime dt) {
  final diff = DateTime.now().difference(dt.toLocal());
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
  if (diff.inHours < 24) return '${diff.inHours} hr ago';
  return DateFormat('d MMM, hh:mm a').format(dt.toLocal());
}

// ─────────────────────────────────────────────────────────────────────────────
//  Section container
// ─────────────────────────────────────────────────────────────────────────────

class _DetailSection extends StatelessWidget {
  const _DetailSection({
    required this.icon,
    required this.title,
    required this.child,
  });

  final IconData icon;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 12, 14, 0),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Row(
              children: [
                Icon(icon, size: 15, color: AppColors.primary),
                const SizedBox(width: 7),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                    letterSpacing: 0.6,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.borderLight),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: child,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Status chip
// ─────────────────────────────────────────────────────────────────────────────

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color fg, String label) = switch (status.toLowerCase()) {
      'pending' => (
        const Color(0xFFFFF3CD),
        const Color(0xFF856404),
        'Pending',
      ),
      'confirmed' => (
        const Color(0xFFCFE2FF),
        const Color(0xFF0A58CA),
        'Confirmed',
      ),
      'preparing' => (
        const Color(0xFFE2D9F3),
        const Color(0xFF6F42C1),
        'Preparing',
      ),
      'ready' => (const Color(0xFFD1ECF1), const Color(0xFF0C5460), 'Ready'),
      'picked' => (const Color(0xFFD4EDDA), const Color(0xFF155724), 'Picked'),
      'on_the_way' => (
        const Color(0xFFD4EDDA),
        const Color(0xFF155724),
        'On the Way',
      ),
      'delivered' => (
        const Color(0xFFD4EDDA),
        const Color(0xFF155724),
        'Delivered',
      ),
      'cancelled' => (
        const Color(0xFFF8D7DA),
        const Color(0xFF721C24),
        'Cancelled',
      ),
      'refunded' => (
        const Color(0xFFE9ECEF),
        const Color(0xFF495057),
        'Refunded',
      ),
      _ => (const Color(0xFFE9ECEF), const Color(0xFF495057), status),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppSizes.radiusFull),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Order type badge
// ─────────────────────────────────────────────────────────────────────────────

class _OrderTypeBadge extends StatelessWidget {
  const _OrderTypeBadge({required this.orderType});

  final String orderType;

  @override
  Widget build(BuildContext context) {
    final type = orderType.toLowerCase();
    final (IconData icon, String label, Color bg, Color fg) = switch (type) {
      'takeaway' || 'take_away' => (
        Icons.directions_walk,
        'Takeaway',
        const Color(0xFFE8F5E9),
        const Color(0xFF2E7D32),
      ),
      'dine_in' || 'dine-in' => (
        Icons.restaurant,
        'Dine In',
        const Color(0xFFEDE7F6),
        const Color(0xFF512DA8),
      ),
      _ => (
        Icons.delivery_dining,
        'Delivery',
        const Color(0xFFE3F2FD),
        const Color(0xFF1565C0),
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppSizes.radiusFull),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: fg),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Scheduled chip
// ─────────────────────────────────────────────────────────────────────────────

class _ScheduledChip extends StatelessWidget {
  const _ScheduledChip({this.scheduledFor});

  final DateTime? scheduledFor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3CD),
        borderRadius: BorderRadius.circular(AppSizes.radiusFull),
        border: Border.all(color: const Color(0xFFFFCA2C)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.schedule, size: 11, color: Color(0xFF856404)),
          const SizedBox(width: 4),
          Text(
            scheduledFor != null
                ? 'Scheduled · ${DateFormat('hh:mm a').format(scheduledFor!.toLocal())}'
                : 'Scheduled',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF856404),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Price row
// ─────────────────────────────────────────────────────────────────────────────

class _PriceRow extends StatelessWidget {
  const _PriceRow({
    required this.label,
    required this.value,
    required this.currFmt,
    this.isDiscount = false,
  });

  final String label;
  final double value;
  final NumberFormat currFmt;
  final bool isDiscount;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          Text(
            isDiscount
                ? '−${currFmt.format(value.abs())}'
                : currFmt.format(value),
            style: TextStyle(
              fontSize: 13,
              color: isDiscount ? AppColors.success : AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  ETA Badge
// ─────────────────────────────────────────────────────────────────────────────

class _EtaBadge extends StatelessWidget {
  const _EtaBadge({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        border: Border.all(color: color.withAlpha(80)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: color,
                  letterSpacing: 0.5,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Icon button helper (call / copy)
// ─────────────────────────────────────────────────────────────────────────────

class _ActionIconBtn extends StatelessWidget {
  const _ActionIconBtn({
    required this.icon,
    required this.color,
    required this.bgColor,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final Color bgColor;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
          child: Icon(icon, size: 18, color: color),
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
//  Live Tracking Bottom Sheet  (animated, real API — TrackingViewModel)
// ────────────────────────────────────────────────────────────────────────────
class _TrackingSheet extends StatefulWidget {
  const _TrackingSheet({required this.orderId});

  final int orderId;

  @override
  State<_TrackingSheet> createState() => _TrackingSheetState();
}

class _TrackingSheetState extends State<_TrackingSheet>
    with SingleTickerProviderStateMixin {
  late final TrackingViewModel _vm;
  late final WebSocketService _wsService;
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _wsService = context.read<WebSocketService>();
    _vm = TrackingViewModel(apiService: context.read<ApiService>());
    _vm.startTracking(widget.orderId);
    // Wire WebSocket for real-time tracking updates
    _wsService.connectOrderTracking(widget.orderId);
    _vm.listenToWebSocket(_wsService.onOrderTracking);
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(
      begin: 0.4,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _vm.stopTracking();
    _vm.dispose();
    _wsService.disconnectOrderTracking(widget.orderId);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<TrackingViewModel>.value(
      value: _vm,
      child: Consumer<TrackingViewModel>(
        builder: (_, vm, _) => _buildSheet(vm),
      ),
    );
  }

  // ── Sheet scaffold ────────────────────────────────────────────────────
  Widget _buildSheet(TrackingViewModel vm) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppColors.borderLight,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          if (vm.isLoading)
            _buildLoader()
          else if (vm.status == TrackingViewStatus.error && !vm.hasData)
            _buildError(vm)
          else if (vm.hasData)
            Flexible(child: _buildLoaded(vm)),
        ],
      ),
    );
  }

  // ── Loading ───────────────────────────────────────────────────────────
  Widget _buildLoader() {
    return SizedBox(
      height: 220,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 44,
            height: 44,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: AppColors.info,
              backgroundColor: AppColors.info.withAlpha(30),
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Fetching rider info…',
            style: TextStyle(
              color: AppColors.info,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  // ── Error ────────────────────────────────────────────────────────────
  Widget _buildError(TrackingViewModel vm) {
    return SizedBox(
      height: 220,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.wifi_off_rounded,
            size: 44,
            color: AppColors.textHint,
          ),
          const SizedBox(height: 12),
          Text(
            vm.errorMessage ?? 'Failed to load tracking info.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: vm.refresh,
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Retry'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.info,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Loaded ───────────────────────────────────────────────────────────
  Widget _buildLoaded(TrackingViewModel vm) {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildStatusBanner(vm),
          const SizedBox(height: 14),
          _buildETADashboard(vm),
          const SizedBox(height: 14),
          vm.partner != null
              ? _buildPartnerCard(vm.partner!)
              : _buildNoPartner(),
          const SizedBox(height: 14),
          _buildDeliveryInfo(vm),
          const SizedBox(height: 14),
          _buildLiveTimeline(vm),
          const SizedBox(height: 10),
          _buildLiveFooter(vm),
        ],
      ),
    );
  }

  // ── Animated Status Banner ──────────────────────────────────────────
  Widget _buildStatusBanner(TrackingViewModel vm) {
    final ts = vm.trackingStatus;
    final statusText = ts?.statusDisplay ?? 'Tracking…';
    final rawEta = vm.eta?.pickupDisplay ?? 'Calculating…';
    final bool showArrivingPrefix =
        !(ts?.isOutForDelivery ?? false) &&
        !(ts?.isNearCustomer ?? false) &&
        !(ts?.isDelivered ?? false) &&
        RegExp(r'\d').hasMatch(rawEta);
    final etaText = showArrivingPrefix ? 'Arriving in $rawEta' : rawEta;

    final Color bgColor;
    final Color borderColor;
    final Color textColor;
    final IconData icon;

    if (ts == null || ts.isAwaitingAssignment) {
      bgColor = AppColors.warningLight;
      borderColor = AppColors.warning.withAlpha(80);
      textColor = const Color(0xFFE65100);
      icon = Icons.search_rounded;
    } else if (ts.isAtRestaurant) {
      bgColor = AppColors.successLight;
      borderColor = AppColors.success.withAlpha(80);
      textColor = const Color(0xFF1B5E20);
      icon = Icons.storefront_rounded;
    } else if (ts.isOutForDelivery || ts.isNearCustomer) {
      bgColor = AppColors.successLight;
      borderColor = AppColors.success.withAlpha(80);
      textColor = const Color(0xFF1B5E20);
      icon = Icons.delivery_dining_rounded;
    } else {
      bgColor = AppColors.infoLight;
      borderColor = AppColors.info.withAlpha(80);
      textColor = const Color(0xFF0D47A1);
      icon = Icons.moped_rounded;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Icon(icon, color: textColor, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  statusText,
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                FadeTransition(
                  opacity: _pulseAnim,
                  child: Text(
                    etaText,
                    style: TextStyle(
                      color: textColor.withAlpha(200),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          AnimatedBuilder(
            animation: _pulseAnim,
            builder: (_, _) => Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: textColor.withAlpha((_pulseAnim.value * 255).toInt()),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Rider Card (Zomato-style) ───────────────────────────────────────
  Widget _buildPartnerCard(TrackingPartner partner) {
    final initial = partner.name.isNotEmpty
        ? partner.name[0].toUpperCase()
        : '?';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        border: Border.all(color: AppColors.borderLight),
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
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.info.withAlpha(24),
              border: Border.all(color: AppColors.info.withAlpha(60), width: 2),
            ),
            child: ClipOval(
              child:
                  (partner.profilePhoto != null &&
                      partner.profilePhoto!.isNotEmpty)
                  ? CachedNetworkImage(
                      imageUrl: partner.profilePhoto!,
                      width: 56,
                      height: 56,
                      fit: BoxFit.cover,
                      errorWidget: (_, _, _) => Center(
                        child: Text(
                          initial,
                          style: const TextStyle(
                            color: AppColors.info,
                            fontWeight: FontWeight.bold,
                            fontSize: 22,
                          ),
                        ),
                      ),
                    )
                  : Center(
                      child: Text(
                        initial,
                        style: const TextStyle(
                          color: AppColors.info,
                          fontWeight: FontWeight.bold,
                          fontSize: 22,
                        ),
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  partner.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(
                      Icons.two_wheeler_rounded,
                      size: 14,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        partner.vehicleDisplay.isNotEmpty
                            ? '${partner.vehicleDisplay} · ${partner.vehicleNumber}'
                            : partner.vehicleNumber,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                if (partner.rating > 0) ...[
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      const Icon(
                        Icons.star_rounded,
                        size: 14,
                        color: AppColors.ratingStar,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        '${partner.rating.toStringAsFixed(1)} · ${partner.totalDeliveries} deliveries',
                        style: const TextStyle(
                          color: AppColors.textHint,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: AppColors.success.withAlpha(20),
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.success.withAlpha(60)),
            ),
            child: IconButton(
              icon: const Icon(Icons.phone_rounded, color: AppColors.success),
              onPressed: partner.phone.isNotEmpty
                  ? () async {
                      final uri = Uri.parse('tel:${partner.phone}');
                      if (await canLaunchUrl(uri)) await launchUrl(uri);
                    }
                  : null,
              tooltip: 'Call rider',
            ),
          ),
        ],
      ),
    );
  }

  // ── No Partner Placeholder ──────────────────────────────────────────
  Widget _buildNoPartner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(
        color: AppColors.warningLight,
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        border: Border.all(color: AppColors.warning.withAlpha(60)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FadeTransition(
            opacity: _pulseAnim,
            child: const Icon(
              Icons.person_search_rounded,
              size: 20,
              color: AppColors.warning,
            ),
          ),
          const SizedBox(width: 10),
          const Text(
            'Finding a delivery partner nearby…',
            style: TextStyle(
              color: Color(0xFFE65100),
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  // ── ETA Dashboard (two-column: Pickup + Delivery) ──────────────────
  Widget _buildETADashboard(TrackingViewModel vm) {
    final eta = vm.eta;
    final ts = vm.trackingStatus;

    final bool pickupDone =
        ts?.isOutForDelivery == true ||
        ts?.isNearCustomer == true ||
        ts?.isDelivered == true;

    return Row(
      children: [
        Expanded(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: pickupDone ? AppColors.successLight : AppColors.infoLight,
              borderRadius: BorderRadius.circular(AppSizes.radiusMd),
              border: Border.all(
                color: pickupDone
                    ? AppColors.success.withAlpha(60)
                    : AppColors.info.withAlpha(60),
              ),
            ),
            child: Column(
              children: [
                Icon(
                  pickupDone
                      ? Icons.check_circle_rounded
                      : Icons.storefront_rounded,
                  size: 20,
                  color: pickupDone ? AppColors.success : AppColors.info,
                ),
                const SizedBox(height: 6),
                Text(
                  pickupDone ? 'Picked Up' : 'Pickup By',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: pickupDone
                        ? const Color(0xFF1B5E20)
                        : const Color(0xFF0D47A1),
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                if (!pickupDone && eta != null && eta.pickupMinutes != null)
                  Text(
                    '${eta.pickupMinutes} min',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      height: 1.1,
                    ),
                  )
                else
                  Text(
                    pickupDone ? 'Done' : eta?.pickupDisplay ?? '—',
                    style: TextStyle(
                      fontSize: pickupDone ? 16 : 14,
                      fontWeight: FontWeight.w700,
                      color: pickupDone
                          ? AppColors.success
                          : AppColors.textSecondary,
                    ),
                  ),
                const SizedBox(height: 2),
                Text(
                  pickupDone ? 'Order with rider' : 'Rider → Restaurant',
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.textHint,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: ts?.isDelivered == true
                  ? AppColors.successLight
                  : AppColors.surface,
              borderRadius: BorderRadius.circular(AppSizes.radiusMd),
              border: Border.all(
                color: ts?.isDelivered == true
                    ? AppColors.success.withAlpha(60)
                    : AppColors.borderLight,
              ),
            ),
            child: Column(
              children: [
                Icon(
                  ts?.isDelivered == true
                      ? Icons.check_circle_rounded
                      : Icons.location_on_rounded,
                  size: 20,
                  color: ts?.isDelivered == true
                      ? AppColors.success
                      : (pickupDone ? AppColors.primary : AppColors.textHint),
                ),
                const SizedBox(height: 6),
                Text(
                  ts?.isDelivered == true ? 'Delivered' : 'Delivery By',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: ts?.isDelivered == true
                        ? const Color(0xFF1B5E20)
                        : (pickupDone
                              ? AppColors.textPrimary
                              : AppColors.textHint),
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                if (ts?.isDelivered == true)
                  const Text(
                    'Done',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.success,
                    ),
                  )
                else if (eta != null && eta.deliveryMinutes != null)
                  Text(
                    '${eta.deliveryMinutes} min',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: pickupDone
                          ? AppColors.textPrimary
                          : AppColors.textHint,
                      height: 1.1,
                    ),
                  )
                else
                  Text(
                    eta?.deliveryDisplay ?? '—',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textHint,
                    ),
                  ),
                const SizedBox(height: 2),
                Text(
                  ts?.isDelivered == true ? 'Completed' : 'Rider → Customer',
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.textHint,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Delivery Info Card (customer + address) ───────────────────────
  Widget _buildDeliveryInfo(TrackingViewModel vm) {
    final info = vm.orderInfo;
    if (info == null) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'DELIVERING TO',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppColors.textHint,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(
                Icons.person_rounded,
                size: 15,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  info.customerName,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (info.deliveryAddress.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 1),
                  child: Icon(
                    Icons.location_on_outlined,
                    size: 15,
                    color: AppColors.textHint,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    info.deliveryAddress,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color:
                      info.paymentMethod.toLowerCase().contains('cod') ||
                          info.paymentMethod.toLowerCase().contains('cash')
                      ? AppColors.warningLight
                      : AppColors.successLight,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  info.paymentMethod.isNotEmpty
                      ? info.paymentMethod.toUpperCase()
                      : 'PREPAID',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color:
                        info.paymentMethod.toLowerCase().contains('cod') ||
                            info.paymentMethod.toLowerCase().contains('cash')
                        ? const Color(0xFFE65100)
                        : const Color(0xFF1B5E20),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                info.orderNumber,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textHint,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              Text(
                '₹${info.grandTotal.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Live Update Footer ────────────────────────────────────────────
  Widget _buildLiveFooter(TrackingViewModel vm) {
    final isLive = vm.trackingStatus?.isLiveTracking ?? false;
    final lastUpdated = vm.data?.lastUpdated;
    String agoText = '';
    if (lastUpdated != null) {
      final diff = DateTime.now().difference(lastUpdated).inSeconds;
      if (diff < 5) {
        agoText = 'Just now';
      } else if (diff < 60) {
        agoText = '${diff}s ago';
      } else {
        agoText = '${(diff ~/ 60)}m ago';
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (isLive || vm.isTracking)
            AnimatedBuilder(
              animation: _pulseAnim,
              builder: (_, _) => Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.success.withAlpha(
                    (_pulseAnim.value * 255).toInt(),
                  ),
                ),
              ),
            ),
          if (isLive || vm.isTracking) const SizedBox(width: 5),
          Text(
            isLive ? 'LIVE' : 'AUTO-REFRESH',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              color: isLive ? AppColors.success : AppColors.info,
              letterSpacing: 1,
            ),
          ),
          if (agoText.isNotEmpty) ...[
            const Text(
              '  ·  ',
              style: TextStyle(fontSize: 9, color: AppColors.textHint),
            ),
            Text(
              'Updated $agoText',
              style: const TextStyle(fontSize: 10, color: AppColors.textHint),
            ),
          ],
          const Text(
            '  ·  ',
            style: TextStyle(fontSize: 9, color: AppColors.textHint),
          ),
          const Text(
            '10s polling',
            style: TextStyle(fontSize: 10, color: AppColors.textHint),
          ),
        ],
      ),
    );
  }

  // ── Helper: extract timestamp from backend timeline events ──────────
  String? _timeFromEvent(List<TrackingTimelineEvent> events, String key) {
    for (final e in events) {
      if (e.event == key && e.timestamp != null) {
        final t = e.timestamp!.toLocal();
        final h = t.hour > 12 ? t.hour - 12 : (t.hour == 0 ? 12 : t.hour);
        final m = t.minute.toString().padLeft(2, '0');
        final ampm = t.hour >= 12 ? 'PM' : 'AM';
        return '$h:$m $ampm';
      }
    }
    return null;
  }

  // ── Live 5-Step Timeline ────────────────────────────────────────────
  Widget _buildLiveTimeline(TrackingViewModel vm) {
    final orderStatus = vm.orderInfo?.status ?? 'pending';
    final events = vm.timeline;

    // 7-step order lifecycle matching the Web App
    const statusOrder = [
      'pending',
      'confirmed',
      'preparing',
      'ready',
      'picked',
      'on_the_way',
      'delivered',
    ];

    final rawIndex = statusOrder.indexOf(orderStatus);
    final activeIndex = rawIndex >= 0 ? rawIndex : 0;
    final isDelivered = orderStatus == 'delivered';

    // 0=pending, 1=active (pulsing), 2=completed (green check)
    int stepState(int i) {
      if (isDelivered) return 2; // terminal — all steps completed
      if (i < activeIndex) return 2;
      if (i == activeIndex) return 1;
      return 0;
    }

    // Format a DateTime as "h:mm AM/PM"
    String fmtTime(DateTime dt) {
      final t = dt.toLocal();
      final h = t.hour > 12 ? t.hour - 12 : (t.hour == 0 ? 12 : t.hour);
      final m = t.minute.toString().padLeft(2, '0');
      final ampm = t.hour >= 12 ? 'PM' : 'AM';
      return '$h:$m $ampm';
    }

    // Extract timestamps from backend timeline events where available
    final pickedTime = _timeFromEvent(events, 'order_picked');
    final deliveredTime = _timeFromEvent(events, 'order_delivered');
    final placedTime = vm.orderInfo?.createdAt != null
        ? fmtTime(vm.orderInfo!.createdAt!)
        : null;

    // Step definitions: label, icon, subtitle
    final steps = <(String, IconData, String?)>[
      ('Order Placed', Icons.receipt_long_rounded, placedTime),
      ('Confirmed', Icons.thumb_up_alt_rounded, null),
      ('Preparing', Icons.restaurant_rounded, null),
      ('Ready', Icons.check_box_rounded, null),
      ('Picked Up', Icons.inventory_2_rounded, pickedTime),
      ('On the Way', Icons.delivery_dining_rounded, null),
      ('Delivered', Icons.check_circle_rounded, deliveredTime),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ORDER TIMELINE',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppColors.textHint,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 14),
          for (int i = 0; i < steps.length; i++)
            _TimelineStep(
              state: stepState(i),
              label: steps[i].$1,
              subtitle: stepState(i) != 0 ? steps[i].$3 : null,
              icon: steps[i].$2,
              isLast: i == steps.length - 1,
              pulseAnimation: stepState(i) == 1 ? _pulseAnim : null,
            ),
        ],
      ),
    );
  }
}

// ── Single Timeline Step Widget ──────────────────────────────────────
class _TimelineStep extends StatelessWidget {
  final int state; // 0=inactive, 1=active, 2=completed
  final String label;
  final String? subtitle;
  final IconData icon;
  final bool isLast;
  final Animation<double>? pulseAnimation;

  const _TimelineStep({
    required this.state,
    required this.label,
    required this.icon,
    required this.isLast,
    this.subtitle,
    this.pulseAnimation,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = state == 1;
    final isCompleted = state == 2;

    final Color lineColor = isCompleted
        ? AppColors.success
        : AppColors.borderLight;

    final Color textColor = isCompleted || isActive
        ? AppColors.textPrimary
        : AppColors.textHint;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 32,
            child: Column(
              children: [
                isActive && pulseAnimation != null
                    ? AnimatedBuilder(
                        animation: pulseAnimation!,
                        builder: (_, _) => Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.primary.withAlpha(
                              (pulseAnimation!.value * 40).toInt(),
                            ),
                          ),
                          child: Center(
                            child: Container(
                              width: 18,
                              height: 18,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.primary,
                              ),
                              child: Icon(icon, size: 11, color: Colors.white),
                            ),
                          ),
                        ),
                      )
                    : Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isCompleted
                              ? AppColors.success
                              : AppColors.borderLight,
                        ),
                        child: Icon(
                          isCompleted ? Icons.check_rounded : icon,
                          size: 14,
                          color: isCompleted
                              ? Colors.white
                              : AppColors.textHint,
                        ),
                      ),
                if (!isLast) Container(width: 2, height: 24, color: lineColor),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
                      fontSize: isActive ? 14 : 13,
                      color: textColor,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: TextStyle(
                        fontSize: 12,
                        color: isActive
                            ? AppColors.primary
                            : AppColors.textHint,
                        fontWeight: isActive
                            ? FontWeight.w500
                            : FontWeight.normal,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
