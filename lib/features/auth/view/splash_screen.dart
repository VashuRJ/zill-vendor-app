import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../viewmodel/auth_viewmodel.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  bool _navigated = false;

  // Phase 1: Logo entrance (scale + fade)
  late final AnimationController _logoCtrl;
  late final Animation<double> _logoScale;
  late final Animation<double> _logoFade;

  // Phase 2: Text entrance (slide up + fade)
  late final AnimationController _textCtrl;
  late final Animation<double> _textFade;
  late final Animation<Offset> _textSlide;
  late final Animation<double> _taglineFade;

  // Phase 3: Exit (whole screen fades out)
  late final AnimationController _exitCtrl;
  late final Animation<double> _exitFade;

  @override
  void initState() {
    super.initState();

    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
    );

    // Phase 1: Logo — scale from 0.6 → 1.0 with overshoot
    _logoCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _logoScale = Tween(begin: 0.6, end: 1.0).animate(CurvedAnimation(
      parent: _logoCtrl,
      curve: Curves.easeOutBack,
    ));
    _logoFade = CurvedAnimation(
      parent: _logoCtrl,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    );

    // Phase 2: Brand text slides up
    _textCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _textFade = CurvedAnimation(
      parent: _textCtrl,
      curve: const Interval(0.0, 0.7, curve: Curves.easeOut),
    );
    _textSlide = Tween<Offset>(
      begin: const Offset(0, 0.4),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _textCtrl,
      curve: Curves.easeOutCubic,
    ));
    _taglineFade = CurvedAnimation(
      parent: _textCtrl,
      curve: const Interval(0.3, 1.0, curve: Curves.easeOut),
    );

    // Phase 3: Exit fade
    _exitCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _exitFade = Tween(begin: 1.0, end: 0.0).animate(CurvedAnimation(
      parent: _exitCtrl,
      curve: Curves.easeIn,
    ));

    _runSequence();
  }

  Future<void> _runSequence() async {
    // Phase 1: Logo entrance
    await Future.delayed(const Duration(milliseconds: 150));
    if (!mounted) return;
    _logoCtrl.forward();

    // Phase 2: Text after logo settles
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    _textCtrl.forward();

    // Request notification permission early — like Swiggy/Zomato do on first launch
    // Both Firebase-level (iOS) and Android 13+ system permission
    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;
    try {
      await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      await Permission.notification.request();
    } catch (_) {
      // User denied or error — non-fatal, app continues without push
    }

    // Check auth after permission dialog
    if (!mounted) return;
    await _checkAuth();
  }

  Future<void> _checkAuth() async {
    if (_navigated) return;

    final authVM = context.read<AuthViewModel>();
    await authVM.checkAuthStatus();

    if (!mounted || _navigated) return;
    _navigated = true;

    // Phase 3: Fade out then navigate
    await _exitCtrl.forward();
    if (!mounted) return;

    final route = authVM.isAuthenticated ? '/home' : '/login';
    Navigator.of(context).pushReplacementNamed(route);
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
      backgroundColor: AppColors.primary,
      body: FadeTransition(
        opacity: _exitFade,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Logo with scale + fade ──
              ScaleTransition(
                scale: _logoScale,
                child: FadeTransition(
                  opacity: _logoFade,
                  child: Container(
                    width: 110,
                    height: 110,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 30,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Image.asset(
                      'assets/logo/source_icon.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 28),

              // ── Brand name ──
              FadeTransition(
                opacity: _textFade,
                child: SlideTransition(
                  position: _textSlide,
                  child: RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: 'Zi',
                          style: GoogleFonts.poppins(
                            fontSize: 38,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            height: 1.0,
                            letterSpacing: -0.5,
                          ),
                        ),
                        TextSpan(
                          text: 'll',
                          style: GoogleFonts.poppins(
                            fontSize: 38,
                            fontWeight: FontWeight.w800,
                            color: Colors.white.withValues(alpha: 0.7),
                            height: 1.0,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 6),

              // ── Tagline ──
              FadeTransition(
                opacity: _taglineFade,
                child: Text(
                  'Restaurant Partner',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withValues(alpha: 0.75),
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
