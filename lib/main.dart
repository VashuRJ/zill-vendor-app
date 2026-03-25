// ─────────────────────────────────────────
// Zill Restaurant Partner — Vendor App
// Author: Vashu Mogha (@Its-vashu)
// ─────────────────────────────────────────
import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'package:flutter_native_splash/flutter_native_splash.dart';

import 'core/constants/app_strings.dart';
import 'core/routing/app_router.dart';
import 'core/services/api_service.dart';
import 'core/services/order_alarm_service.dart';
import 'core/services/push_notification_service.dart';
import 'core/services/storage_service.dart';
import 'core/services/websocket_service.dart';
import 'core/theme/app_theme.dart';
import 'core/utils/app_logger.dart';
import 'features/auth/viewmodel/auth_viewmodel.dart';
import 'features/dashboard/viewmodel/dashboard_viewmodel.dart';
import 'features/orders/viewmodel/orders_viewmodel.dart';
import 'features/menu/viewmodel/menu_viewmodel.dart';
import 'features/profile/viewmodel/profile_viewmodel.dart';
import 'features/subscription/viewmodel/subscription_viewmodel.dart';
import 'features/kyc/viewmodel/kyc_viewmodel.dart';
import 'features/support/viewmodel/support_viewmodel.dart';
import 'features/delivery_zones/viewmodel/delivery_zone_viewmodel.dart';
import 'features/addons/viewmodel/addon_viewmodel.dart';

void main() {
  runZonedGuarded(
    () async {
      final binding = WidgetsFlutterBinding.ensureInitialized();
      FlutterNativeSplash.preserve(widgetsBinding: binding);

      // Make ALL rendering errors visible (red card instead of blank white screen)
      ErrorWidget.builder = (FlutterErrorDetails details) {
        return Container(
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF0F0),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFFF5252)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.error_outline, color: Color(0xFFFF5252), size: 20),
                  SizedBox(width: 8),
                  Text(
                    'RENDER ERROR',
                    style: TextStyle(
                      color: Color(0xFFFF5252),
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '${details.exception}',
                style: const TextStyle(fontSize: 11, color: Color(0xFF880000)),
                maxLines: 5,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        );
      };

      // Use bundled Poppins fonts — no runtime network downloads (prevents ANR)
      GoogleFonts.config.allowRuntimeFetching = false;

      // Initialize Firebase (skip if already init'd — hot restart safe)
      final isFirstInit = Firebase.apps.isEmpty;
      if (isFirstInit) {
        await Firebase.initializeApp();
      }

      // Catch Flutter framework errors (layout, rendering, gestures).
      // MUST be after Firebase.initializeApp() — Crashlytics.instance throws if
      // Firebase is not yet initialized when the callback is first invoked.
      FlutterError.onError = (FlutterErrorDetails details) {
        AppLogger.e('[FlutterError] ${details.exception}', details.exception, details.stack);
        FirebaseCrashlytics.instance.recordFlutterFatalError(details);
      };

      // Register background handler only on cold start. On hot restart the native
      // isolate is already running — re-registering triggers "duplicate background
      // isolate" which blocks the UI thread for minutes (ANR).
      if (isFirstInit) {
        FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
      }

      // Lock orientation to portrait
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);

      // Set status bar style
      SystemChrome.setSystemUIOverlayStyle(
        const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
        ),
      );

      // Initialize services
      final storageService = StorageService();
      final navigatorKey = GlobalKey<NavigatorState>();
      final apiService = ApiService(
        storageService: storageService,
        navigatorKey: navigatorKey,
      );
      final pushService = PushNotificationService(
        apiService: apiService,
        storageService: storageService,
      );

      final wsService = WebSocketService(storageService: storageService);

      // Initialize the order alarm method channel bridge
      OrderAlarmService.init();

      // Wire up alarm listener — navigate to IncomingOrderScreen when alarm fires
      OrderAlarmService.onAlarmOrderReceived = (data) {
        navigatorKey.currentState?.pushNamed(
          AppRouter.incomingOrder,
          arguments: data,
        );
      };

      // Check if app was cold-launched from an alarm notification
      _checkAlarmLaunch(navigatorKey);

      runApp(
        VendorApp(
          storageService: storageService,
          apiService: apiService,
          pushService: pushService,
          wsService: wsService,
          navigatorKey: navigatorKey,
        ),
      );
    },
    (Object error, StackTrace stack) {
      AppLogger.e('[Unhandled] $error', error, stack);
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    },
  );
}

/// If the app was cold-launched from an alarm notification, navigate to
/// the IncomingOrderScreen once the navigator is ready.
Future<void> _checkAlarmLaunch(GlobalKey<NavigatorState> navigatorKey) async {
  // Small delay to let the navigator initialize after runApp
  await Future.delayed(const Duration(milliseconds: 500));
  final data = await OrderAlarmService.getAlarmOrderData();
  if (data != null && data.orderId > 0) {
    navigatorKey.currentState?.pushNamed(
      AppRouter.incomingOrder,
      arguments: data,
    );
  }
}

class VendorApp extends StatelessWidget {
  final StorageService storageService;
  final ApiService apiService;
  final PushNotificationService pushService;
  final WebSocketService wsService;
  final GlobalKey<NavigatorState> navigatorKey;

  const VendorApp({
    super.key,
    required this.storageService,
    required this.apiService,
    required this.pushService,
    required this.wsService,
    required this.navigatorKey,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // ApiService — exposed for on-demand ViewModel construction
        Provider<ApiService>.value(value: apiService),
        // PushNotificationService — accessible anywhere for wiring callbacks
        Provider<PushNotificationService>.value(value: pushService),
        // WebSocketService — real-time order updates & notifications
        Provider<WebSocketService>.value(value: wsService),
        // Auth ViewModel
        ChangeNotifierProvider(
          create: (_) => AuthViewModel(
            apiService: apiService,
            storageService: storageService,
            pushService: pushService,
            wsService: wsService,
          ),
        ),
        // Dashboard ViewModel
        ChangeNotifierProvider(
          create: (_) => DashboardViewModel(apiService: apiService),
        ),
        // Orders ViewModel
        ChangeNotifierProvider(
          create: (_) => OrdersViewModel(apiService: apiService),
        ),
        // Menu ViewModel
        ChangeNotifierProvider(
          create: (_) => MenuViewModel(apiService: apiService),
        ),
        // Profile ViewModel
        ChangeNotifierProvider(
          create: (_) => ProfileViewModel(apiService: apiService),
        ),
        // Subscription ViewModel
        ChangeNotifierProvider(
          create: (_) => SubscriptionViewModel(apiService: apiService),
        ),
        // KYC ViewModel
        ChangeNotifierProvider(
          create: (_) => KycViewModel(apiService: apiService),
        ),
        // Support ViewModel (Chat + Ticket Detail)
        ChangeNotifierProvider(
          create: (_) => SupportViewModel(apiService: apiService),
        ),
        // Delivery Zone ViewModel
        ChangeNotifierProvider(
          create: (_) => DeliveryZoneViewModel(apiService: apiService),
        ),
        // Addon ViewModel
        ChangeNotifierProvider(
          create: (_) => AddonViewModel(apiService: apiService),
        ),
      ],
      child: MaterialApp(
        title: AppStrings.appName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        navigatorKey: navigatorKey,
        initialRoute: AppRouter.splash,
        onGenerateRoute: AppRouter.generateRoute,
        // Lock text scale to 1.0 — prevents system font size (accessibility)
        // from breaking fixed-height buttons, cards, and rows on any device.
        builder: (context, child) {
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.noScaling,
            ),
            child: child!,
          );
        },
      ),
    );
  }
}
