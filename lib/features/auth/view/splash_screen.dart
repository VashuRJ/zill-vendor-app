import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../viewmodel/auth_viewmodel.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeIn,
    );

    _animController.forward();

    // Check auth status after animation settles
    Future.delayed(const Duration(milliseconds: 2000), () {
      _checkAuth();
    });
  }

  Future<void> _checkAuth() async {
    if (_navigated) return;

    final authVM = context.read<AuthViewModel>();
    await authVM.checkAuthStatus();

    if (!mounted || _navigated) return;
    _navigated = true;

    final route = authVM.isAuthenticated ? '/home' : '/login';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Navigator.of(context).pushReplacementNamed(route);
      }
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Image.asset(
            'assets/logo/source_icon.png',
            width: 150,
          ),
        ),
      ),
    );
  }
}
