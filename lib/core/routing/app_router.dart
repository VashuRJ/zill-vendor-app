import 'package:flutter/material.dart';
import '../../features/auth/view/splash_screen.dart';
import '../../features/auth/view/login_screen.dart';
import '../../features/home/view/app_shell.dart';
import '../../features/notifications/view/notifications_screen.dart';
import '../../features/subscription/view/subscription_plans_screen.dart';
import '../../features/subscription/view/my_subscription_screen.dart';
import '../../features/subscription/view/invoice_history_screen.dart';
import '../../features/orders/view/incoming_order_screen.dart';
import '../../features/kyc/view/kyc_documents_screen.dart';
import '../../features/support/view/chat_screen.dart';
import '../../features/support/view/ticket_detail_screen.dart';
import '../../features/delivery_zones/view/delivery_zones_screen.dart';
import '../../features/addons/view/addon_groups_screen.dart';
import '../services/order_alarm_service.dart';

class AppRouter {
  static const String splash = '/';
  static const String login = '/login';
  static const String home = '/home';
  static const String notifications = '/notifications';
  static const String subscriptionPlans = '/subscription/plans';
  static const String mySubscription = '/subscription/my';
  static const String invoiceHistory = '/subscription/invoices';
  static const String kycDocuments = '/kyc/documents';
  static const String chatSupport = '/support/chat';
  static const String ticketDetail = '/support/ticket';
  static const String incomingOrder = '/orders/incoming';
  static const String deliveryZones = '/delivery-zones';
  static const String addonGroups = '/addon-groups';

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case splash:
        return _fadeRoute(const SplashScreen(), settings);
      case login:
        return _fadeRoute(const LoginScreen(), settings);
      case home:
        return _fadeRoute(const AppShell(), settings);
      case notifications:
        return _fadeRoute(const NotificationsScreen(), settings);
      case subscriptionPlans:
        return _fadeRoute(const SubscriptionPlansScreen(), settings);
      case mySubscription:
        return _fadeRoute(const MySubscriptionScreen(), settings);
      case invoiceHistory:
        return _fadeRoute(const InvoiceHistoryScreen(), settings);
      case kycDocuments:
        return _fadeRoute(const KycDocumentsScreen(), settings);
      case chatSupport:
        return _fadeRoute(const ChatScreen(), settings);
      case ticketDetail:
        final args = settings.arguments as Map<String, dynamic>;
        return _fadeRoute(
          TicketDetailScreen(
            ticketId: args['ticketId'] as int,
            ticketNumber: args['ticketNumber'] as String,
          ),
          settings,
        );
      case deliveryZones:
        return _fadeRoute(const DeliveryZonesScreen(), settings);
      case addonGroups:
        return _fadeRoute(const AddonGroupsScreen(), settings);
      case incomingOrder:
        final orderData = settings.arguments as AlarmOrderData;
        return _fadeRoute(
          IncomingOrderScreen(orderData: orderData),
          settings,
        );
      default:
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            body: Center(
              child: Text('No route defined for ${settings.name}'),
            ),
          ),
        );
    }
  }

  static PageRouteBuilder _fadeRoute(Widget page, RouteSettings settings) {
    return PageRouteBuilder(
      settings: settings,
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(opacity: animation, child: child);
      },
      transitionDuration: const Duration(milliseconds: 300),
    );
  }
}
