import 'package:flutter/material.dart';
import '../../features/auth/view/splash_screen.dart';
import '../../features/auth/view/login_screen.dart';
import '../../features/home/view/app_shell.dart';
import '../../features/notifications/view/notifications_screen.dart';

class AppRouter {
  static const String splash = '/';
  static const String login = '/login';
  static const String home = '/home';
  static const String notifications = '/notifications';

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
