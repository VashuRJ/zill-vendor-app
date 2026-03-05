import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'core/constants/app_strings.dart';
import 'core/routing/app_router.dart';
import 'core/services/api_service.dart';
import 'core/services/push_notification_service.dart';
import 'core/services/storage_service.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/viewmodel/auth_viewmodel.dart';
import 'features/dashboard/viewmodel/dashboard_viewmodel.dart';
import 'features/orders/viewmodel/orders_viewmodel.dart';
import 'features/menu/viewmodel/menu_viewmodel.dart';
import 'features/profile/viewmodel/profile_viewmodel.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

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

  // Initialize Firebase
  await Firebase.initializeApp();

  // Register background message handler (must be top-level function)
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

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

  runApp(
    VendorApp(
      storageService: storageService,
      apiService: apiService,
      pushService: pushService,
      navigatorKey: navigatorKey,
    ),
  );
}

class VendorApp extends StatelessWidget {
  final StorageService storageService;
  final ApiService apiService;
  final PushNotificationService pushService;
  final GlobalKey<NavigatorState> navigatorKey;

  const VendorApp({
    super.key,
    required this.storageService,
    required this.apiService,
    required this.pushService,
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
        // Auth ViewModel
        ChangeNotifierProvider(
          create: (_) => AuthViewModel(
            apiService: apiService,
            storageService: storageService,
            pushService: pushService,
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
      ],
      child: MaterialApp(
        title: AppStrings.appName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        navigatorKey: navigatorKey,
        initialRoute: AppRouter.splash,
        onGenerateRoute: AppRouter.generateRoute,
      ),
    );
  }
}
