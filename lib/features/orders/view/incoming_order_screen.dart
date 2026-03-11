import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/services/order_alarm_service.dart';
import '../viewmodel/orders_viewmodel.dart';

/// Full-screen "incoming order" UI — inspired by Zomato/Swiggy order alerts.
///
/// Shows a pulsing visual, order details, and large Accept / Reject buttons.
/// The alarm sound is playing via the native [OrderAlarmService] — this screen
/// only handles the UI and the kill-switch (stop alarm on action).
class IncomingOrderScreen extends StatefulWidget {
  final AlarmOrderData orderData;

  const IncomingOrderScreen({super.key, required this.orderData});

  @override
  State<IncomingOrderScreen> createState() => _IncomingOrderScreenState();
}

class _IncomingOrderScreenState extends State<IncomingOrderScreen>
    with TickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final AnimationController _slideController;
  late final Animation<double> _pulseAnimation;
  bool _isProcessing = false;

  // Auto-dismiss timer (matches native 90s timeout)
  Timer? _autoDismissTimer;

  @override
  void initState() {
    super.initState();

    // Lock to portrait and make status bar transparent
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
    );

    // Pulsing ring animation
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.85, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Slide-up entrance for the bottom panel
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();

    // Auto-dismiss after 90 seconds (native alarm also times out)
    _autoDismissTimer = Timer(const Duration(seconds: 90), () {
      if (mounted) _dismiss();
    });
  }

  @override
  void dispose() {
    _autoDismissTimer?.cancel();
    _pulseController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  // ── Actions ─────────────────────────────────────────────────────────

  Future<void> _acceptOrder() async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    // Capture context-dependent objects before any async gap
    final vm = context.read<OrdersViewModel>();
    final nav = Navigator.of(context);
    final scaffold = ScaffoldMessenger.of(context);

    // 1. INSTANTLY stop the alarm
    await OrderAlarmService.stopAlarm();

    // 2. Call backend accept API
    final success = await vm.acceptOrder(widget.orderData.orderId);

    if (!mounted) return;

    if (success) {
      // 3. Navigate back to orders (pop this screen)
      nav.pop('accepted');
    } else {
      setState(() => _isProcessing = false);
      scaffold.showSnackBar(SnackBar(
        content: const Text('Failed to accept order. Please try again.'),
        backgroundColor: Colors.red.shade700,
      ));
    }
  }

  Future<void> _rejectOrder() async {
    if (_isProcessing) return;

    // Show confirmation dialog
    final reason = await _showRejectDialog();
    if (reason == null || !mounted) return;

    setState(() => _isProcessing = true);

    // Capture context-dependent objects before any async gap
    final vm = context.read<OrdersViewModel>();
    final nav = Navigator.of(context);
    final scaffold = ScaffoldMessenger.of(context);

    // 1. INSTANTLY stop the alarm
    await OrderAlarmService.stopAlarm();

    // 2. Call backend reject API
    final success = await vm.rejectOrder(
      widget.orderData.orderId,
      reason: reason,
    );

    if (!mounted) return;

    if (success) {
      nav.pop('rejected');
    } else {
      setState(() => _isProcessing = false);
      scaffold.showSnackBar(SnackBar(
        content: const Text('Failed to reject order. Please try again.'),
        backgroundColor: Colors.red.shade700,
      ));
    }
  }

  void _dismiss() {
    OrderAlarmService.stopAlarm();
    if (mounted) Navigator.of(context).pop('dismissed');
  }

  Future<String?> _showRejectDialog() async {
    String selectedReason = 'Restaurant is busy';
    final reasons = [
      'Restaurant is busy',
      'Item not available',
      'Closing soon',
      'Too many orders',
      'Other',
    ];

    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject Order?'),
        content: StatefulBuilder(
          builder: (ctx2, setDialogState) => RadioGroup<String>(
            groupValue: selectedReason,
            onChanged: (v) => setDialogState(() => selectedReason = v ?? selectedReason),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: reasons.map((r) => RadioListTile<String>(
                title: Text(r, style: const TextStyle(fontSize: 14)),
                value: r,
                dense: true,
              )).toList(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, selectedReason),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }

  // ── Build ───────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final data = widget.orderData;

    return PopScope(
      canPop: false, // Prevent back button from dismissing without stopping alarm
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _dismiss();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF1A1A2E),
        body: SafeArea(
          child: Column(
            children: [
              // ── Top section: pulsing icon + order number ──
              Expanded(
                flex: 3,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Pulsing rings
                      AnimatedBuilder(
                        animation: _pulseAnimation,
                        builder: (_, _) => _buildPulsingIcon(),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'NEW ORDER!',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '#${data.orderNumber}',
                        style: TextStyle(
                          color: Colors.orange.shade300,
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Bottom panel: order details + buttons ──
              SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 1),
                  end: Offset.zero,
                ).animate(CurvedAnimation(
                  parent: _slideController,
                  curve: Curves.easeOutCubic,
                )),
                child: Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                  ),
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Order details card
                      _buildOrderDetails(data),
                      const SizedBox(height: 28),
                      // Action buttons
                      if (_isProcessing)
                        const SizedBox(
                          height: 56,
                          child: Center(
                            child: CircularProgressIndicator(
                              strokeWidth: 3,
                            ),
                          ),
                        )
                      else
                        _buildActionButtons(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPulsingIcon() {
    final scale = _pulseAnimation.value;
    return SizedBox(
      width: 160,
      height: 160,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer ring
          Transform.scale(
            scale: scale,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.orange.withValues(alpha: 0.2),
                  width: 3,
                ),
              ),
            ),
          ),
          // Middle ring
          Transform.scale(
            scale: 0.5 + scale * 0.35,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.orange.withValues(alpha: 0.4),
                  width: 3,
                ),
              ),
            ),
          ),
          // Center icon
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [Colors.orange.shade400, Colors.deepOrange.shade600],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.orange.withValues(alpha: 0.5),
                  blurRadius: 20 * scale,
                  spreadRadius: 5 * scale,
                ),
              ],
            ),
            child: const Icon(
              Icons.restaurant_menu,
              color: Colors.white,
              size: 40,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderDetails(AlarmOrderData data) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          if (data.customerName.isNotEmpty)
            _detailRow(Icons.person_outline, 'Customer', data.customerName),
          if (data.orderItems.isNotEmpty) ...[
            if (data.customerName.isNotEmpty) const Divider(height: 16),
            _detailRow(Icons.fastfood_outlined, 'Items', data.orderItems),
          ],
          if (data.orderAmount.isNotEmpty) ...[
            const Divider(height: 16),
            _detailRow(
              Icons.currency_rupee,
              'Amount',
              data.orderAmount,
              valueBold: true,
            ),
          ],
          if (data.customerName.isEmpty &&
              data.orderItems.isEmpty &&
              data.orderAmount.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Tap Accept to view full order details',
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
            ),
        ],
      ),
    );
  }

  Widget _detailRow(
    IconData icon,
    String label,
    String value, {
    bool valueBold = false,
  }) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey.shade600),
        const SizedBox(width: 10),
        Text(
          '$label: ',
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 14,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: valueBold ? 18 : 14,
              fontWeight: valueBold ? FontWeight.w700 : FontWeight.w500,
              color: Colors.black87,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        // REJECT button
        Expanded(
          child: SizedBox(
            height: 56,
            child: OutlinedButton(
              onPressed: _rejectOrder,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red.shade700,
                side: BorderSide(color: Colors.red.shade300, width: 2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                'REJECT',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        // ACCEPT button (bigger — 2x weight)
        Expanded(
          flex: 2,
          child: SizedBox(
            height: 56,
            child: FilledButton(
              onPressed: _acceptOrder,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF2E7D32),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_outline, size: 22),
                  SizedBox(width: 8),
                  Text(
                    'ACCEPT ORDER',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
