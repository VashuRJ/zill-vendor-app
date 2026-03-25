// ─────────────────────────────────────────
// Zill Restaurant Partner — Vendor App
// Author: Vashu Mogha (@Its-vashu)
// ─────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/utils/app_logger.dart';
import '../viewmodel/auth_viewmodel.dart';
import 'forgot_password_sheet.dart';
import 'otp_login_sheet.dart';

// ── Colour palette ───────────────────────────────────────────────────
const _brand = Color(0xFFFF6B35);
const _brandDark = Color(0xFFE55A2B);
const _ink = Color(0xFF1A1A2E);
const _muted = Color(0xFF6B7280);
const _label = Color(0xFF374151);
const _surface = Color(0xFFF7F7F8);
const _error = Color(0xFFDC2626);
const _success = Color(0xFF059669);

const _registerUrl = 'https://zill.co.in/vendor/register.html';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  bool _obscurePass = true;
  bool _loginSuccess = false;

  // Page enter animation
  late final AnimationController _animCtrl;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  // Success overlay animation
  late final AnimationController _successCtrl;
  late final Animation<double> _overlayFade;
  late final Animation<double> _checkPop;
  late final Animation<double> _textSlide;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
    );

    // Page enter
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic));
    _animCtrl.forward();

    // Success overlay
    _successCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _overlayFade = CurvedAnimation(
      parent: _successCtrl,
      curve: const Interval(0.0, 0.3, curve: Curves.easeOut),
    );
    _checkPop = Tween(begin: 0.0, end: 1.0).animate(CurvedAnimation(
      parent: _successCtrl,
      curve: const Interval(0.2, 0.7, curve: Curves.elasticOut),
    ));
    _textSlide = CurvedAnimation(
      parent: _successCtrl,
      curve: const Interval(0.45, 0.85, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _successCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  void _showSnack(String message, {bool isError = true}) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                isError
                    ? Icons.error_outline_rounded
                    : Icons.info_outline_rounded,
                color: Colors.white,
                size: 19,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: isError ? _error : _brand,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 5),
          dismissDirection: DismissDirection.up,
        ),
      );
  }

  Future<void> _handleLogin() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final messenger = ScaffoldMessenger.maybeOf(context);
    final authVM = context.read<AuthViewModel>();
    authVM.clearError();

    try {
      final success = await authVM.login(
        loginId: _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
      );

      if (!mounted) return;

      if (success) {
        messenger?.clearSnackBars();
        setState(() => _loginSuccess = true);
        _successCtrl.forward();
        await Future.delayed(const Duration(milliseconds: 1400));
        if (!mounted) return;
        Navigator.of(context).pushReplacementNamed(AppRouter.home);
      } else {
        _showSnackWithMessenger(
          messenger,
          authVM.errorMessage ?? 'Login failed. Please try again.',
        );
      }
    } catch (e) {
      AppLogger.e('_handleLogin error: $e');
      _showSnackWithMessenger(
          messenger, 'Something went wrong. Please try again.');
    }
  }

  void _showSnackWithMessenger(
    ScaffoldMessengerState? messenger,
    String message, {
    bool isError = true,
  }) {
    try {
      messenger
        ?..clearSnackBars()
        ..showSnackBar(SnackBar(
          content: Row(
            children: [
              Icon(
                isError
                    ? Icons.error_outline_rounded
                    : Icons.info_outline_rounded,
                color: Colors.white,
                size: 19,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: isError ? _error : _brand,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 5),
          dismissDirection: DismissDirection.up,
        ));
    } catch (_) {}
  }

  Future<void> _openRegistration() async {
    final uri = Uri.parse(_registerUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) _showSnack('Could not open registration page');
    }
  }

  // ── Success overlay (full-screen) ──────────────────────────────────
  Widget _buildSuccessOverlay() {
    return AnimatedBuilder(
      animation: _successCtrl,
      builder: (context, _) {
        return FadeTransition(
          opacity: _overlayFade,
          child: Container(
            color: Colors.white,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Animated check circle
                  ScaleTransition(
                    scale: _checkPop,
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: const BoxDecoration(
                        color: _success,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        size: 44,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // "You're in!" text slides up
                  FadeTransition(
                    opacity: _textSlide,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.3),
                        end: Offset.zero,
                      ).animate(_textSlide),
                      child: Column(
                        children: [
                          Text(
                            'You\'re in!',
                            style: GoogleFonts.poppins(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              color: _ink,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Setting up your dashboard...',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                              color: _muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Image.asset(
          'assets/logo/splash_logo_transparent.png',
          width: 160,
          fit: BoxFit.contain,
        ),
        const SizedBox(height: 8),
        Text(
          'Restaurant Partner',
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: _muted,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }

  Widget _buildFormCard() {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 26, 22, 22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 32,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Welcome back',
              style: GoogleFonts.poppins(
                fontSize: 21,
                fontWeight: FontWeight.w700,
                color: _ink,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              'Sign in to manage your restaurant',
              style: GoogleFonts.poppins(fontSize: 13, color: _muted),
            ),
            const SizedBox(height: 24),
            _ZillField(
              label: 'Email or mobile number',
              hint: 'you@example.com',
              controller: _emailCtrl,
              focusNode: _emailFocus,
              prefixIcon: Icons.mail_outline_rounded,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              inputFormatters: [
                FilteringTextInputFormatter.deny(RegExp(r'\s')),
              ],
              onEditingComplete: () =>
                  FocusScope.of(context).requestFocus(_passwordFocus),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Email or phone is required'
                  : null,
            ),
            const SizedBox(height: 16),
            _ZillField(
              label: 'Password',
              hint: '••••••••',
              controller: _passwordCtrl,
              focusNode: _passwordFocus,
              prefixIcon: Icons.lock_outline_rounded,
              obscureText: _obscurePass,
              textInputAction: TextInputAction.done,
              onEditingComplete: _handleLogin,
              suffixIcon: GestureDetector(
                onTap: () => setState(() => _obscurePass = !_obscurePass),
                child: Icon(
                  _obscurePass
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: _muted,
                  size: 20,
                ),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Password is required';
                if (v.length < 6) return 'Minimum 6 characters';
                return null;
              },
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => showForgotPasswordSheet(context),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.only(top: 8, bottom: 2),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  'Forgot Password?',
                  style: GoogleFonts.poppins(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: _brand,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            // ── Sign In button (simple — loading spinner only) ──
            Consumer<AuthViewModel>(
              builder: (context, auth, _) => _SignInButton(
                isLoading: auth.isLoading,
                onPressed: _handleLogin,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOtpSection() {
    return Column(
      children: [
        const SizedBox(height: 24),
        Row(
          children: [
            const Expanded(
              child: Divider(color: Color(0xFFE5E7EB), thickness: 1),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'or',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: _muted,
                ),
              ),
            ),
            const Expanded(
              child: Divider(color: Color(0xFFE5E7EB), thickness: 1),
            ),
          ],
        ),
        const SizedBox(height: 20),
        OutlinedButton(
          onPressed: () => showOtpLoginSheet(context),
          style: OutlinedButton.styleFrom(
            foregroundColor: _ink,
            side: const BorderSide(color: Color(0xFFDDE0E4), width: 1.4),
            minimumSize: const Size.fromHeight(50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            backgroundColor: Colors.white,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.sms_outlined, size: 20, color: _brand),
              const SizedBox(width: 10),
              Text(
                'Login with OTP',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: _ink,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRegistration() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        children: [
          Row(
            children: [
              const Expanded(
                child: Divider(color: Color(0xFFE5E7EB), thickness: 1),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Text(
                  'RESTAURANT OWNERS',
                  style: GoogleFonts.poppins(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w600,
                    color: _muted,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              const Expanded(
                child: Divider(color: Color(0xFFE5E7EB), thickness: 1),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'New to Zill? ',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: _muted,
                ),
              ),
              GestureDetector(
                onTap: _openRegistration,
                child: Text(
                  'Register your restaurant',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _brand,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      body: Stack(
        children: [
          // Login form
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SlideTransition(
                position: _slideAnim,
                child: CustomScrollView(
                  physics: const ClampingScrollPhysics(),
                  slivers: [
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          children: [
                            const SizedBox(height: 44),
                            _buildHeader(),
                            const Spacer(),
                            _buildFormCard(),
                            _buildOtpSection(),
                            const Spacer(flex: 2),
                            _buildRegistration(),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Full-screen success overlay
          if (_loginSuccess) _buildSuccessOverlay(),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
//  Reusable text field
// ─────────────────────────────────────────────────────────────────────
class _ZillField extends StatelessWidget {
  const _ZillField({
    required this.label,
    required this.hint,
    required this.controller,
    required this.prefixIcon,
    this.focusNode,
    this.keyboardType,
    this.textInputAction,
    this.onEditingComplete,
    this.obscureText = false,
    this.suffixIcon,
    this.validator,
    this.inputFormatters,
  });

  final String label;
  final String hint;
  final TextEditingController controller;
  final IconData prefixIcon;
  final FocusNode? focusNode;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final VoidCallback? onEditingComplete;
  final bool obscureText;
  final Widget? suffixIcon;
  final String? Function(String?)? validator;
  final List<TextInputFormatter>? inputFormatters;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: _label,
          ),
        ),
        const SizedBox(height: 7),
        TextFormField(
          controller: controller,
          focusNode: focusNode,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          onEditingComplete: onEditingComplete,
          obscureText: obscureText,
          validator: validator,
          inputFormatters: inputFormatters,
          style: GoogleFonts.poppins(
            fontSize: 14,
            color: _ink,
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.poppins(
              fontSize: 13.5,
              color: const Color(0xFFBBBDC3),
              fontWeight: FontWeight.w400,
            ),
            filled: true,
            fillColor: _surface,
            prefixIcon: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Icon(prefixIcon, color: _muted, size: 19),
            ),
            prefixIconConstraints: const BoxConstraints(
              minWidth: 48,
              minHeight: 48,
            ),
            suffixIcon: suffixIcon != null
                ? Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: suffixIcon,
                  )
                : null,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide:
                  const BorderSide(color: Color(0xFFEBEDF0), width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: _brand, width: 2.0),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: _error, width: 1.2),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: _error, width: 1.8),
            ),
            errorStyle: GoogleFonts.poppins(
              fontSize: 11,
              color: _error,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
//  Simple Sign-In button — gradient + loading spinner
// ─────────────────────────────────────────────────────────────────────
class _SignInButton extends StatelessWidget {
  const _SignInButton({required this.isLoading, required this.onPressed});

  final bool isLoading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: isLoading
              ? null
              : const LinearGradient(
                  colors: [_brand, _brandDark],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
          color: isLoading ? _brand.withValues(alpha: 0.55) : null,
          borderRadius: BorderRadius.circular(14),
          boxShadow: isLoading
              ? null
              : [
                  BoxShadow(
                    color: _brand.withValues(alpha: 0.30),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
        ),
        child: ElevatedButton(
          onPressed: isLoading ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            disabledBackgroundColor: Colors.transparent,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: isLoading
                ? const SizedBox(
                    key: ValueKey('loading'),
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Row(
                    key: const ValueKey('idle'),
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Sign In',
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_forward_rounded, size: 19),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
