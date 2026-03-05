import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
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

const _registerUrl = 'https://zill.co.in/vendor/register.html';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  bool _obscurePass = true;

  late final AnimationController _animCtrl;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    // Set once — not on every rebuild (avoids platform-channel overhead per keystroke)
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
    );
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
  }

  @override
  void dispose() {
    _animCtrl.dispose();
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
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'Dismiss',
            textColor: Colors.white,
            onPressed: () =>
                ScaffoldMessenger.maybeOf(context)?.hideCurrentSnackBar(),
          ),
        ),
      );
  }

  Future<void> _handleLogin() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    try {
      final authVM = context.read<AuthViewModel>();
      authVM.clearError();

      final success = await authVM.login(
        loginId: _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
      );

      if (!mounted) return;

      if (success) {
        ScaffoldMessenger.of(context).clearSnackBars();
        Navigator.of(context).pushReplacementNamed('/home');
      } else {
        _showSnack(authVM.errorMessage ?? 'Login failed. Please try again.');
      }
    } catch (e) {
      AppLogger.e('_handleLogin error: $e');
      if (mounted) {
        _showSnack('Something went wrong. Please try again.');
      }
    }
  }

  Future<void> _openRegistration() async {
    final uri = Uri.parse(_registerUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) _showSnack('Could not open registration page');
    }
  }

  // ── Header ─────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Column(
      children: [
        // Small restaurant icon
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: _brand.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(Icons.storefront_rounded, color: _brand, size: 28),
        ),
        const SizedBox(height: 16),
        // Brand name
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: 'Zi',
                style: GoogleFonts.poppins(
                  fontSize: 42,
                  fontWeight: FontWeight.w800,
                  color: _ink,
                  height: 1.0,
                  letterSpacing: -1.0,
                ),
              ),
              TextSpan(
                text: 'll',
                style: GoogleFonts.poppins(
                  fontSize: 42,
                  fontWeight: FontWeight.w800,
                  color: _brand,
                  height: 1.0,
                  letterSpacing: -1.0,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        // Subtitle
        Text(
          'Vendor Partner App',
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

  // ── Form Card ──────────────────────────────────────────────────────
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
            // Welcome text
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

            // ── Email / Phone field ──
            _ZillField(
              label: 'Email or mobile number',
              hint: 'you@example.com',
              controller: _emailCtrl,
              focusNode: _emailFocus,
              prefixIcon: Icons.mail_outline_rounded,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              onEditingComplete: () =>
                  FocusScope.of(context).requestFocus(_passwordFocus),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Email or phone is required'
                  : null,
            ),
            const SizedBox(height: 16),

            // ── Password field ──
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

            // Forgot password
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

            // ── Sign In button ──
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

  // ── OR divider + OTP ───────────────────────────────────────────────
  Widget _buildOtpSection() {
    return Column(
      children: [
        const SizedBox(height: 24),
        // "or" divider
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
        // OTP button
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

  // ── Registration link (bottom) ─────────────────────────────────────
  Widget _buildRegistration() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        children: [
          // Divider
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

  // ── Build ──────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      body: SafeArea(
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
              borderSide: const BorderSide(color: Color(0xFFEBEDF0), width: 1),
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
//  Primary Sign-In button with gradient + shadow
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
          child: isLoading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Row(
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
    );
  }
}
