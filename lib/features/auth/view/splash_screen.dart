import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/update_service.dart';
import '../../../shared/widgets/update_dialog.dart';
import '../viewmodel/auth_viewmodel.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  bool _navigated = false;

  late final AnimationController _logoCtrl;
  late final Animation<double> _logoScale;
  late final Animation<double> _logoFade;

  late final AnimationController _textCtrl;
  late final Animation<double> _taglineFade;

  late final AnimationController _exitCtrl;
  late final Animation<double> _exitFade;

  @override
  void initState() {
    super.initState();

    // Remove native splash as soon as Flutter's first frame is drawn
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FlutterNativeSplash.remove();
    });

    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
    );

    _logoCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _logoScale = Tween(
      begin: 0.6,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _logoCtrl, curve: Curves.easeOutBack));
    _logoFade = CurvedAnimation(
      parent: _logoCtrl,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    );

    _textCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _taglineFade = CurvedAnimation(
      parent: _textCtrl,
      curve: const Interval(0.3, 1.0, curve: Curves.easeOut),
    );

    _exitCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _exitFade = Tween(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(parent: _exitCtrl, curve: Curves.easeIn));

    _runSequence();
  }

  Future<void> _runSequence() async {
    await Future.delayed(const Duration(milliseconds: 150));
    if (!mounted) return;
    _logoCtrl.forward();

    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    _textCtrl.forward();

    // Request notification permissions
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    try {
      await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      await Permission.notification.request();
    } catch (_) {}

    if (!mounted) return;
    await _checkAuth();
  }

  Future<void> _checkAuth() async {
    if (_navigated) return;

    final updateResult = await UpdateService.instance.checkForUpdate();
    debugPrint(
      '[Splash] Update check result: hasUpdate=${updateResult.hasUpdate} isForce=${updateResult.isForceUpdate} version=${updateResult.latestVersion}',
    );
    if (!mounted) return;
    if (updateResult.hasUpdate) {
      debugPrint('[Splash] Showing update dialog...');
      await showUpdateDialog(context, updateResult);
      if (!mounted) return;
    } else {
      debugPrint('[Splash] No update needed, proceeding to auth check');
    }

    final authVM = context.read<AuthViewModel>();
    await authVM.checkAuthStatus();
    if (!mounted || _navigated) return;

    var targetRoute = '/login';
    if (authVM.isAuthenticated) {
      final requiresSetup = await authVM.requiresSetupOnboarding();
      if (!mounted || _navigated) return;
      // Re-check `isAuthenticated` AFTER the onboarding API call —
      // if any of those requests returned 401, the auth interceptor
      // would have fired its `onSessionExpired` stream and flipped
      // the view-model to unauthenticated. Without this re-check we
      // would race past it and push /home with a dead session,
      // leaving the vendor stuck on a "Cannot reach server" banner.
      if (!authVM.isAuthenticated) {
        targetRoute = '/login';
      } else {
        targetRoute = requiresSetup ? '/setup-onboarding' : '/home';
      }
    }

    _navigated = true;

    await _exitCtrl.forward();
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed(targetRoute);
  }

  @override
  void dispose() {
    _logoCtrl.dispose();
    _textCtrl.dispose();
    _exitCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: FadeTransition(
        opacity: _exitFade,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ScaleTransition(
                scale: _logoScale,
                child: FadeTransition(
                  opacity: _logoFade,
                  child: Image.asset(
                    'assets/logo/splash_logo.png',
                    width: 220,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              FadeTransition(
                opacity: _taglineFade,
                child: Text(
                  'Restaurant Partner',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
