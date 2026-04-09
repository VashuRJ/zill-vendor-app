// ─────────────────────────────────────────
// Zill Restaurant Partner — Vendor App
// Author: Vashu Mogha (@Its-vashu)
// ─────────────────────────────────────────
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../core/utils/app_logger.dart';
import '../viewmodel/auth_viewmodel.dart';
import 'otp_login_sheet.dart';

// ── Colour palette ───────────────────────────────────────────────────
const _brand = Color(0xFFFF6B35);
const _ink = Color(0xFF1A1A2E);
const _muted = Color(0xFF6B7280);
const _label = Color(0xFF374151);
const _surface = Color(0xFFF7F7F8);
const _error = Color(0xFFDC2626);
const _success = Color(0xFF059669);
const _whatsapp = Color(0xFF25D366);

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _phoneCtrl = TextEditingController();
  final _phoneFocus = FocusNode();

  // Cooldown timer for OTP resend throttle
  int _cooldownSeconds = 0;
  Timer? _cooldownTimer;

  // Page enter animation
  late final AnimationController _animCtrl;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

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
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _phoneCtrl.dispose();
    _phoneFocus.dispose();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  void _startCooldown(int seconds) {
    _cooldownTimer?.cancel();
    setState(() => _cooldownSeconds = seconds > 0 ? seconds : 60);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() {
        if (_cooldownSeconds > 0) {
          _cooldownSeconds--;
        } else {
          t.cancel();
        }
      });
    });
  }

  String _fmtCooldown(int seconds) {
    if (seconds <= 0) return '';
    if (seconds < 60) return '${seconds}s';
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return s == 0 ? '${m}m' : '${m}m ${s}s';
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
                    : Icons.check_circle_outline_rounded,
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
          backgroundColor: isError ? _error : _success,
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

  // ── Send OTP via WhatsApp ─────────────────────────────────────────
  Future<void> _handleSendOtp() async {
    if (_cooldownSeconds > 0) return;
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final authVM = context.read<AuthViewModel>();
    authVM.clearError();

    try {
      final result = await authVM.requestWhatsAppOtp(
        phone: _phoneCtrl.text.trim(),
      );

      if (!mounted) return;

      if (result.success) {
        // Open the OTP verification bottom sheet
        showOtpLoginSheet(context, prefillPhone: _phoneCtrl.text.trim());
      } else {
        if (result.waitSeconds > 0) _startCooldown(result.waitSeconds);
        _showSnack(result.message);
      }
    } catch (e) {
      AppLogger.e('_handleSendOtp error: $e');
      if (mounted) _showSnack('Something went wrong. Please try again.');
    }
  }

  // ── Header — Logo + branding ──────────────────────────────────────
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

  // ── Main form card — phone input + send OTP ───────────────────────
  Widget _buildFormCard() {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 28, 22, 24),
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
            // Heading
            Text(
              'Partner Login / Register',
              style: GoogleFonts.poppins(
                fontSize: 21,
                fontWeight: FontWeight.w700,
                color: _ink,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Enter your WhatsApp number to sign in or create an account',
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: _muted,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 26),

            // Phone number field label
            Text(
              'WhatsApp number',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _label,
              ),
            ),
            const SizedBox(height: 7),

            // Phone number input
            TextFormField(
              controller: _phoneCtrl,
              focusNode: _phoneFocus,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.done,
              maxLength: 10,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onEditingComplete: _handleSendOtp,
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Phone number is required';
                }
                if (!RegExp(r'^[6-9]\d{9}$').hasMatch(v.trim())) {
                  return 'Enter a valid 10-digit number starting with 6-9';
                }
                return null;
              },
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: _ink,
                fontWeight: FontWeight.w500,
              ),
              decoration: InputDecoration(
                hintText: '98765 43210',
                counterText: '',
                hintStyle: GoogleFonts.poppins(
                  fontSize: 13.5,
                  color: const Color(0xFFBBBDC3),
                  fontWeight: FontWeight.w400,
                ),
                filled: true,
                fillColor: _surface,
                prefixIcon: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const FaIcon(FontAwesomeIcons.whatsapp, size: 18, color: _whatsapp),
                      const SizedBox(width: 8),
                      Text(
                        '+91',
                        style: GoogleFonts.poppins(
                          fontSize: 13.5,
                          color: _ink,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(width: 1, height: 18, color: const Color(0xFFDDE0E4)),
                    ],
                  ),
                ),
                prefixIconConstraints: const BoxConstraints(
                  minWidth: 80,
                  minHeight: 48,
                ),
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

            const SizedBox(height: 20),

            // ── Send OTP button ─────────────────────────────────
            Consumer<AuthViewModel>(
              builder: (context, auth, _) {
                final loading = auth.isWaOtpSendLoading;
                final onCooldown = _cooldownSeconds > 0;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      height: 52,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: (loading || onCooldown)
                              ? _ink.withValues(alpha: 0.55)
                              : _ink,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: (loading || onCooldown)
                              ? null
                              : [
                                  BoxShadow(
                                    color: _ink.withValues(alpha: 0.25),
                                    blurRadius: 16,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                        ),
                        child: ElevatedButton(
                          onPressed: (loading || onCooldown) ? null : _handleSendOtp,
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
                            child: loading
                                ? const SizedBox(
                                    key: ValueKey('loading'),
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  )
                                : Row(
                                    key: const ValueKey('idle'),
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const FaIcon(
                                        FontAwesomeIcons.whatsapp,
                                        size: 18,
                                        color: Colors.white,
                                      ),
                                      const SizedBox(width: 10),
                                      Text(
                                        'Send OTP via WhatsApp',
                                        style: GoogleFonts.poppins(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 0.3,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ),
                    ),

                    // Cooldown text
                    if (onCooldown) ...[
                      const SizedBox(height: 10),
                      Center(
                        child: Text(
                          'Try again in ${_fmtCooldown(_cooldownSeconds)}',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: _muted,
                          ),
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // ── Secure badge row ──────────────────────────────────────────────
  Widget _buildSecureBadge() {
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.lock_outline_rounded, size: 14, color: _muted.withValues(alpha: 0.6)),
          const SizedBox(width: 6),
          Text(
            'Secured with end-to-end encryption',
            style: GoogleFonts.poppins(
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
              color: _muted.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }

  // ── Footer ────────────────────────────────────────────────────────
  Widget _buildFooter() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
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
                  'RESTAURANT PARTNERS',
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
          const SizedBox(height: 14),
          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: GoogleFonts.poppins(
                fontSize: 12.5,
                color: _muted,
                fontWeight: FontWeight.w400,
              ),
              children: [
                const TextSpan(text: 'By continuing, you agree to our '),
                TextSpan(
                  text: 'Terms of Service',
                  style: GoogleFonts.poppins(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: _brand,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

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
                        _buildSecureBadge(),
                        const Spacer(flex: 2),
                        _buildFooter(),
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
