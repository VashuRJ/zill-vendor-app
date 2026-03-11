// Data models for Vendor Subscriptions & Payments.
// Maps exactly to the Django backend: SubscriptionPlan, VendorSubscription,
// SubscriptionInvoice (payments/models.py).

class SubscriptionPlan {
  final int id; // Django integer PK — needed for subscribe endpoint
  final String planId;
  final String name;
  final String description;
  final Map<String, dynamic> features;
  final int? maxMenuItems;
  final double commissionDiscount;
  final bool featuredListing;
  final bool prioritySupport;
  final String analyticsAccess; // basic, advanced, premium
  final int trialDays;
  final int sortOrder;

  // Monthly pricing (always present)
  final double monthlyBase;
  final double monthlyGst;
  final double monthlyTotal;

  // Annual pricing (from plans listing endpoint)
  final double? annualBase;
  final double? annualGst;
  final double? annualTotal;
  final double? annualMonthlyEquivalent;
  final int? savingsPercent;

  const SubscriptionPlan({
    required this.id,
    required this.planId,
    required this.name,
    this.description = '',
    this.features = const {},
    this.maxMenuItems,
    this.commissionDiscount = 0,
    this.featuredListing = false,
    this.prioritySupport = false,
    this.analyticsAccess = 'basic',
    this.trialDays = 0,
    this.sortOrder = 0,
    required this.monthlyBase,
    this.monthlyGst = 0,
    required this.monthlyTotal,
    this.annualBase,
    this.annualGst,
    this.annualTotal,
    this.annualMonthlyEquivalent,
    this.savingsPercent,
  });

  factory SubscriptionPlan.fromJson(Map<String, dynamic> json) {
    // Backend nests pricing under pricing.monthly / pricing.annual
    final pricing = json['pricing'] as Map<String, dynamic>? ?? {};
    final monthly = pricing['monthly'] as Map<String, dynamic>? ?? {};
    final annual = pricing['annual'] as Map<String, dynamic>?;

    return SubscriptionPlan(
      id: (json['id'] as num?)?.toInt() ?? 0,
      planId: json['plan_id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      features: json['features'] is Map<String, dynamic>
          ? json['features'] as Map<String, dynamic>
          : const {},
      maxMenuItems: (json['max_menu_items'] as num?)?.toInt(),
      commissionDiscount: _toDouble(json['commission_discount']),
      featuredListing: json['featured_listing'] as bool? ?? false,
      prioritySupport: json['priority_support'] as bool? ?? false,
      analyticsAccess: json['analytics_access'] as String? ?? 'basic',
      trialDays: (json['trial_days'] as num?)?.toInt() ?? 0,
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
      monthlyBase: _toDouble(monthly['base']),
      monthlyGst: _toDouble(monthly['gst']),
      monthlyTotal: _toDouble(monthly['total']),
      annualBase: annual != null ? _toDouble(annual['base']) : null,
      annualGst: annual != null ? _toDouble(annual['gst']) : null,
      annualTotal: annual != null ? _toDouble(annual['total']) : null,
      annualMonthlyEquivalent: annual != null
          ? _toDouble(annual['monthly_equivalent'])
          : null,
      savingsPercent: annual != null
          ? (annual['savings_percent'] as num?)?.toInt()
          : null,
    );
  }

  /// Friendly list of feature strings for UI display.
  List<String> get featureList {
    final list = <String>[];
    if (maxMenuItems != null) {
      list.add('Up to $maxMenuItems menu items');
    } else {
      list.add('Unlimited menu items');
    }
    if (commissionDiscount > 0) {
      list.add('${commissionDiscount.toStringAsFixed(0)}% commission discount');
    }
    if (featuredListing) list.add('Featured listing');
    if (prioritySupport) list.add('Priority support');
    if (analyticsAccess == 'advanced') {
      list.add('Advanced analytics');
    } else if (analyticsAccess == 'premium') {
      list.add('Premium analytics');
    } else {
      list.add('Basic analytics');
    }
    // Include any custom feature flags
    features.forEach((key, value) {
      if (value == true) {
        list.add(key.replaceAll('_', ' '));
      }
    });
    return list;
  }
}

// ---------------------------------------------------------------------------

class VendorSubscription {
  final String subscriptionId;
  final String planId;
  final String planName;
  final String status; // trial, active, grace_period, past_due, suspended, cancelled, expired, paused
  final String billingCycle;
  final double currentPrice;
  final double currentGst;
  final double currentTotal;
  final DateTime? startDate;
  final DateTime? endDate;
  final DateTime? trialEndDate;
  final DateTime? nextBillingDate;
  final DateTime? lastPaymentDate;
  final DateTime? gracePeriodEnd;
  final DateTime? cancelledAt;
  final String cancelReason;
  final bool cancelAtPeriodEnd;
  final bool autoRenew;
  final String paymentMethod;
  final int retryCount;
  final SubscriptionPlan? plan;

  const VendorSubscription({
    required this.subscriptionId,
    this.planId = '',
    this.planName = '',
    required this.status,
    this.billingCycle = 'monthly',
    this.currentPrice = 0,
    this.currentGst = 0,
    this.currentTotal = 0,
    this.startDate,
    this.endDate,
    this.trialEndDate,
    this.nextBillingDate,
    this.lastPaymentDate,
    this.gracePeriodEnd,
    this.cancelledAt,
    this.cancelReason = '',
    this.cancelAtPeriodEnd = false,
    this.autoRenew = true,
    this.paymentMethod = 'razorpay',
    this.retryCount = 0,
    this.plan,
  });

  factory VendorSubscription.fromJson(Map<String, dynamic> json) {
    return VendorSubscription(
      subscriptionId: json['subscription_id'] as String? ?? '',
      planId: json['plan_id'] as String? ?? json['plan']?.toString() ?? '',
      planName: json['plan_name'] as String? ?? '',
      status: json['status'] as String? ?? 'expired',
      billingCycle: json['billing_cycle'] as String? ?? 'monthly',
      currentPrice: _toDouble(json['current_price']),
      currentGst: _toDouble(json['current_gst']),
      currentTotal: _toDouble(json['current_total']),
      startDate: _parseDate(json['start_date']),
      endDate: _parseDate(json['end_date']),
      trialEndDate: _parseDate(json['trial_end_date']),
      nextBillingDate: _parseDate(json['next_billing_date']),
      lastPaymentDate: _parseDate(json['last_payment_date']),
      gracePeriodEnd: _parseDate(json['grace_period_end']),
      cancelledAt: _parseDateTime(json['cancelled_at']),
      cancelReason: json['cancel_reason'] as String? ?? '',
      cancelAtPeriodEnd: json['cancel_at_period_end'] as bool? ?? false,
      autoRenew: json['auto_renew'] as bool? ?? true,
      paymentMethod: json['payment_method'] as String? ?? 'razorpay',
      retryCount: (json['retry_count'] as num?)?.toInt() ?? 0,
      plan: json['plan'] is Map<String, dynamic>
          ? SubscriptionPlan.fromJson(json['plan'] as Map<String, dynamic>)
          : null,
    );
  }

  bool get isActiveOrTrial =>
      status == 'active' || status == 'trial' || status == 'grace_period';

  bool get isTrial => status == 'trial';

  int get daysRemaining {
    if (endDate == null) return 0;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final end = DateTime(endDate!.year, endDate!.month, endDate!.day);
    final diff = end.difference(today).inDays;
    return diff < 0 ? 0 : diff;
  }

  int get totalDays {
    if (startDate == null || endDate == null) return 1;
    final start = DateTime(startDate!.year, startDate!.month, startDate!.day);
    final end = DateTime(endDate!.year, endDate!.month, endDate!.day);
    final diff = end.difference(start).inDays;
    return diff < 1 ? 1 : diff;
  }

  double get progressFraction {
    final total = totalDays;
    final remaining = daysRemaining;
    if (total <= 0) return 0;
    return 1.0 - (remaining / total);
  }

  String get statusLabel {
    switch (status) {
      case 'trial':
        return 'Trial';
      case 'active':
        return 'Active';
      case 'grace_period':
        return 'Grace Period';
      case 'past_due':
        return 'Past Due';
      case 'suspended':
        return 'Suspended';
      case 'cancelled':
        return 'Cancelled';
      case 'expired':
        return 'Expired';
      case 'paused':
        return 'Paused';
      default:
        return status;
    }
  }
}

// ---------------------------------------------------------------------------

class SubscriptionInvoice {
  final String invoiceId;
  final String invoiceNumber;
  final String planName;
  final String billingCycle;
  final DateTime? periodStart;
  final DateTime? periodEnd;
  final double baseAmount;
  final double discountAmount;
  final double lateFee;
  final double gstAmount;
  final double totalAmount;
  final String status; // pending, paid, failed, cancelled, refunded, waived
  final String paymentMethod;
  final DateTime? dueDate;
  final String razorpayOrderId;
  final String razorpayPaymentId;
  final DateTime? paidAt;
  final int retryCount;
  final String failureReason;
  final DateTime? createdAt;

  const SubscriptionInvoice({
    required this.invoiceId,
    this.invoiceNumber = '',
    this.planName = '',
    this.billingCycle = '',
    this.periodStart,
    this.periodEnd,
    this.baseAmount = 0,
    this.discountAmount = 0,
    this.lateFee = 0,
    this.gstAmount = 0,
    this.totalAmount = 0,
    this.status = 'pending',
    this.paymentMethod = '',
    this.dueDate,
    this.razorpayOrderId = '',
    this.razorpayPaymentId = '',
    this.paidAt,
    this.retryCount = 0,
    this.failureReason = '',
    this.createdAt,
  });

  factory SubscriptionInvoice.fromJson(Map<String, dynamic> json) {
    return SubscriptionInvoice(
      invoiceId: json['invoice_id'] as String? ?? '',
      invoiceNumber: json['invoice_number'] as String? ?? '',
      planName: json['plan_name'] as String? ?? '',
      billingCycle: json['billing_cycle'] as String? ?? '',
      periodStart: _parseDate(json['period_start']),
      periodEnd: _parseDate(json['period_end']),
      baseAmount: _toDouble(json['base_amount']),
      discountAmount: _toDouble(json['discount_amount']),
      lateFee: _toDouble(json['late_fee']),
      gstAmount: _toDouble(json['gst_amount']),
      totalAmount: _toDouble(json['total_amount']),
      status: json['status'] as String? ?? 'pending',
      paymentMethod: json['payment_method'] as String? ?? '',
      dueDate: _parseDate(json['due_date']),
      razorpayOrderId: json['razorpay_order_id'] as String? ?? '',
      razorpayPaymentId: json['razorpay_payment_id'] as String? ?? '',
      paidAt: _parseDateTime(json['paid_at']),
      retryCount: (json['retry_count'] as num?)?.toInt() ?? 0,
      failureReason: json['failure_reason'] as String? ?? '',
      createdAt: _parseDateTime(json['created_at']),
    );
  }

  bool get isPaid => status == 'paid';
  bool get isFailed => status == 'failed';
  bool get isPending => status == 'pending';
  bool get canRetry => status == 'failed';

  String get statusLabel {
    switch (status) {
      case 'paid':
        return 'Paid';
      case 'pending':
        return 'Pending';
      case 'failed':
        return 'Failed';
      case 'cancelled':
        return 'Cancelled';
      case 'refunded':
        return 'Refunded';
      case 'waived':
        return 'Waived';
      default:
        return status;
    }
  }
}

// ---------------------------------------------------------------------------
// Razorpay order data returned after subscribe / pay-advance.
// ---------------------------------------------------------------------------

class RazorpayOrderData {
  final String orderId;
  final int amountPaise;
  final String currency;
  final String invoiceId;
  final String planName;
  final String keyId; // Razorpay API key returned by backend

  const RazorpayOrderData({
    required this.orderId,
    required this.amountPaise,
    this.currency = 'INR',
    this.invoiceId = '',
    this.planName = '',
    this.keyId = '',
  });

  factory RazorpayOrderData.fromJson(Map<String, dynamic> json) {
    // Backend returns flat: razorpay_order_id, amount, currency, key_id, invoice_id
    return RazorpayOrderData(
      orderId: json['razorpay_order_id'] as String? ?? '',
      amountPaise: (json['amount'] as num?)?.toInt() ?? 0,
      currency: json['currency'] as String? ?? 'INR',
      invoiceId: json['invoice_id'] as String? ?? '',
      planName: json['plan_name'] as String? ?? '',
      keyId: json['key_id'] as String? ?? '',
    );
  }
}

// ---------------------------------------------------------------------------
// Safe parsing helpers
// ---------------------------------------------------------------------------

double _toDouble(dynamic value) {
  if (value == null) return 0;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString()) ?? 0;
}

DateTime? _parseDate(dynamic value) {
  if (value == null) return null;
  try {
    return DateTime.parse(value.toString());
  } catch (_) {
    return null;
  }
}

DateTime? _parseDateTime(dynamic value) {
  if (value == null) return null;
  try {
    return DateTime.parse(value.toString());
  } catch (_) {
    return null;
  }
}
