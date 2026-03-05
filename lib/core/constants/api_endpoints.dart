class ApiEndpoints {
  ApiEndpoints._();

  // ✅ ADB Reverse Tunnel: `adb reverse tcp:8000 tcp:8000`
  //    Then localhost:8000 on emulator → host machine port 8000
  //    No firewall issues, no 10.0.2.2 needed.
  // 🔁 Switch to production URL when deploying:
  static const String baseUrl = 'https://zill.co.in/api';
  //    static const String baseUrl = 'http://localhost:8000/api';

  // Auth  — exact paths matching Django users/urls.py
  static const String login = '/users/login/vendor/'; // POST {login, password}
  static const String register = '/users/register/vendor/';
  static const String logout = '/users/logout/';
  static const String tokenRefresh = '/token/refresh/';
  static const String changePassword = '/users/change-password/';
  static const String passwordResetRequest = '/users/password-reset/request/';
  static const String passwordResetConfirm = '/users/password-reset/confirm/';
  static const String otpSend = '/users/otp/send/'; // POST {phone}
  static const String otpVerify = '/users/otp/verify/'; // POST {email, otp, purpose}
  static const String otpLogin = '/users/otp/login/'; // POST {phone, otp}

  // Profile
  static const String profile = '/vendors/profile/';
  static const String settings = '/vendors/settings/';

  // Dashboard
  static const String dashboard = '/vendors/dashboard/';
  static const String earnings = '/vendors/earnings/';
  static const String analytics = '/vendors/analytics/';

  // Restaurant
  static const String restaurantToggle = '/vendors/toggle-availability/';
  static const String operatingHours = '/vendors/operating-hours/';
  static const String operatingHoursBulk = '/vendors/operating-hours/bulk/';
  static const String deliveryZones = '/vendors/delivery-zones/';

  // Menu  — exact paths from vendors/urls.py
  static const String menuCategories =
      '/vendors/categories/'; // GET → {count, categories:[{…, items:[…]}]}
  static String menuCategoryDetail(int id) =>
      '/vendors/categories/$id/'; // PUT / DELETE
  static const String menuItems = '/vendors/menu-items/'; // GET / POST
  static String menuItemDetail(int id) =>
      '/vendors/menu-items/$id/'; // GET / PUT / DELETE

  // Orders  — GET /api/orders/vendor-orders/?status=pending
  static const String vendorOrders = '/orders/vendor-orders/';
  static String orderAccept(int id) => '/orders/$id/accept/';
  static String orderReject(int id) => '/orders/$id/reject/';
  static String orderStatus(int id) => '/orders/$id/update-status/';
  static String orderDetail(int id) => '/orders/$id/';
  static const String liveTracking = '/vendors/orders/live-tracking/';
  static String orderLiveTracking(int id) =>
      '/vendors/orders/$id/live-tracking/';

  // Reviews
  static const String reviews = '/vendors/reviews/';
  static const String vendorReviews = '/vendors/reviews/';
  static String vendorReviewReply(int id) => '/vendors/reviews/$id/reply/';

  // Performance & Penalties (new — added Feb 19 backend update)
  static const String performance = '/vendors/performance/';
  static const String penalties = '/vendors/penalties/';

  // Payments & Bank Account
  static const String vendorBank = '/payments/vendor/bank/';
  static const String vendorBankRegister = '/payments/vendor/bank/register/';

  // Earnings & Settlements
  static const String vendorEarnings = '/payments/vendor/earnings/';
  static const String settlementHistory = '/payments/settlements/history/';

  // Vendor Payouts (manual withdrawal)
  static const String vendorPayoutRequest = '/payments/vendor/payout/request/';
  static const String vendorPayouts = '/payments/vendor/payouts/';

  // Unified Ledger (date-filtered transaction history)
  static const String vendorLedger = '/payments/ledger/';

  // Notifications
  static const String notifications = '/notifications/';
  static const String notificationsMarkRead = '/notifications/mark-read/';
  static const String notificationsStats = '/notifications/stats/';
  static String notificationDelete(String id) => '/notifications/$id/delete/';

  // Push Notifications — device token management
  static const String registerDevice = '/notifications/devices/register/';
  static const String unregisterDevice =
      '/notifications/devices/'; // + {id}/unregister/

  // Documents / KYC
  static const String documents = '/vendors/documents/';

  // Promotions / Coupons
  static const String coupons = '/vendors/coupons/';
  static String couponDetail(int id) => '/vendors/coupons/$id/';

  // Staff Management
  static const String staff = '/vendors/staff/';
  static String staffDetail(int id) => '/vendors/staff/$id/';

  // Support Tickets
  static const String supportTickets = '/orders/support/tickets/';
  static const String supportTicketCreate = '/orders/support/tickets/create/';
  static String supportTicketDetail(int id) => '/orders/support/tickets/$id/';
  static String supportTicketReply(int id) =>
      '/orders/support/tickets/$id/reply/';
}
