import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/utils/app_logger.dart';
import '../viewmodel/auth_viewmodel.dart';

// ── Colour palette (matches login_screen.dart) ──────────────────────
const _brand = Color(0xFFFF6B35);
const _brandDark = Color(0xFFE55A2B);
const _ink = Color(0xFF1A1A2E);
const _muted = Color(0xFF6B7280);
const _label = Color(0xFF374151);
const _surface = Color(0xFFF7F7F8);
const _error = Color(0xFFDC2626);
const _success = Color(0xFF059669);

String _fmtCooldown(int seconds) {
  if (seconds <= 0) return '';
  if (seconds < 60) return '${seconds}s';
  final m = seconds ~/ 60;
  final s = seconds % 60;
  return s == 0 ? '${m}m' : '${m}m ${s}s';
}

/// Opens the WhatsApp OTP Login bottom sheet.
/// If [prefillPhone] is provided, skips the phone-input step and goes
/// straight to OTP verification.
void showOtpLoginSheet(BuildContext context, {String? prefillPhone}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _WaOtpLoginSheet(prefillPhone: prefillPhone),
  );
}

// ─────────────────────────────────────────────────────────────────────
//  3-step flow:
//   Step.phone  → phone number input → send WhatsApp OTP
//   Step.otp    → 6-box OTP verify   → login or register_required
//   Step.name   → restaurant name    → complete registration
// ─────────────────────────────────────────────────────────────────────
enum _Step { phone, otp, name }

class _WaOtpLoginSheet extends StatefulWidget {
  const _WaOtpLoginSheet({this.prefillPhone});

  final String? prefillPhone;

  @override
  State<_WaOtpLoginSheet> createState() => _WaOtpLoginSheetState();
}

class _WaOtpLoginSheetState extends State<_WaOtpLoginSheet> {
  late _Step _step;

  // Step phone
  final _phoneCtrl = TextEditingController();
  final _phoneFormKey = GlobalKey<FormState>();
  String? _phoneError;

  // Step otp
  String _phone = '';
  String _enteredOtp = '';         // kept for the name-step second call
  int _cooldownSeconds = 0;
  Timer? _cooldownTimer;

  // Step name
  final _nameCtrl = TextEditingController();
  String? _nameError;

  @override
  void initState() {
    super.initState();

    // If phone was pre-filled from login screen, skip to OTP step
    if (widget.prefillPhone != null && widget.prefillPhone!.isNotEmpty) {
      _phone = widget.prefillPhone!;
      _phoneCtrl.text = widget.prefillPhone!;
      _step = _Step.otp;
    } else {
      _step = _Step.phone;
    }

    _phoneCtrl.addListener(() {
      if (_phoneError != null) setState(() => _phoneError = null);
    });
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _nameCtrl.dispose();
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
          duration: const Duration(seconds: 4),
        ),
      );
  }

  // ── Send OTP ──────────────────────────────────────────────────────
  Future<void> _handleSendOtp() async {
    if (_cooldownSeconds > 0) return;
    FocusScope.of(context).unfocus();
    if (!(_phoneFormKey.currentState?.validate() ?? false)) return;

    try {
      final authVM = context.read<AuthViewModel>();
      final result = await authVM.requestWhatsAppOtp(
        phone: _phoneCtrl.text.trim(),
      );

      if (!mounted) return;

      if (result.success) {
        setState(() {
          _phone = _phoneCtrl.text.trim();
          _phoneError = null;
          _step = _Step.otp;
        });
      } else {
        if (result.waitSeconds > 0) _startCooldown(result.waitSeconds);
        setState(() => _phoneError = result.message);
      }
    } catch (e) {
      AppLogger.e('_handleSendOtp error: $e');
      if (mounted) setState(() => _phoneError = 'Something went wrong. Please try again.');
    }
  }

  // ── Resend OTP ────────────────────────────────────────────────────
  Future<({bool success, int waitSeconds})> _resendOtp() async {
    try {
      final result = await context.read<AuthViewModel>().requestWhatsAppOtp(
        phone: _phone,
      );
      if (!mounted) return (success: false, waitSeconds: 0);
      if (!result.success) _showSnack(result.message);
      return (success: result.success, waitSeconds: result.waitSeconds);
    } catch (e) {
      AppLogger.e('_resendOtp error: $e');
      if (mounted) _showSnack('Something went wrong. Please try again.');
      return (success: false, waitSeconds: 0);
    }
  }

  // ── OTP verified → navigate or go to name step ───────────────────
  void _onOtpVerified(String otp, String action) {
    if (!mounted) return;
    _enteredOtp = otp;

    if (action == 'register_required') {
      setState(() => _step = _Step.name);
      return;
    }

    Navigator.of(context).pushNamedAndRemoveUntil(AppRouter.home, (route) => false);
  }

  // ── Submit restaurant name (new vendor) ───────────────────────────
  Future<void> _handleRegister() async {
    FocusScope.of(context).unfocus();
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _nameError = 'Restaurant name is required');
      return;
    }
    if (name.length < 2) {
      setState(() => _nameError = 'Name must be at least 2 characters');
      return;
    }

    try {
      final authVM = context.read<AuthViewModel>();
      final result = await authVM.verifyWhatsAppOtp(
        phone: _phone,
        otp: _enteredOtp,
        restaurantName: name,
      );

      if (!mounted) return;

      if (result.success) {
        Navigator.of(context).pushNamedAndRemoveUntil(AppRouter.home, (route) => false);
      } else {
        setState(() => _nameError = result.message);
      }
    } catch (e) {
      AppLogger.e('_handleRegister error: $e');
      if (mounted) setState(() => _nameError = 'Something went wrong. Please try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(24, 12, 24, 24 + bottomInset),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 350),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        child: switch (_step) {
          _Step.phone => _PhoneInputView(
              key: const ValueKey('phone'),
              formKey: _phoneFormKey,
              controller: _phoneCtrl,
              onSend: _handleSendOtp,
              onClose: () => Navigator.of(context).pop(),
              cooldownSeconds: _cooldownSeconds,
              errorText: _phoneError,
            ),
          _Step.otp => _OtpVerifyView(
              key: const ValueKey('otp'),
              phone: _phone,
              onVerified: _onOtpVerified,
              onBack: () => setState(() => _step = _Step.phone),
              onResend: _resendOtp,
              showSnack: _showSnack,
            ),
          _Step.name => _RestaurantNameView(
              key: const ValueKey('name'),
              controller: _nameCtrl,
              onSubmit: _handleRegister,
              onBack: () => setState(() => _step = _Step.phone),
              errorText: _nameError,
            ),
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
//  Step 1 — Phone number input
// ─────────────────────────────────────────────────────────────────────
class _PhoneInputView extends StatelessWidget {
  const _PhoneInputView({
    super.key,
    required this.formKey,
    required this.controller,
    required this.onSend,
    required this.onClose,
    this.cooldownSeconds = 0,
    this.errorText,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController controller;
  final VoidCallback onSend;
  final VoidCallback onClose;
  final int cooldownSeconds;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFDDE0E4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Title
          Text(
            'Login with WhatsApp OTP',
            style: GoogleFonts.poppins(
              fontSize: 21,
              fontWeight: FontWeight.w700,
              color: _ink,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "Enter your registered mobile number. We'll send a one-time code via WhatsApp.",
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: _muted,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),

          // Phone field
          Text(
            'Mobile number',
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _label,
            ),
          ),
          const SizedBox(height: 7),
          TextFormField(
            controller: controller,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.done,
            onEditingComplete: onSend,
            maxLength: 10,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Mobile number is required';
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
                    const Icon(Icons.phone_android_rounded, color: _muted, size: 19),
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
              prefixIconConstraints: const BoxConstraints(minWidth: 80, minHeight: 48),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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

          // Inline error
          if (errorText != null) ...[
            const SizedBox(height: 10),
            _ErrorBanner(message: errorText!),
          ],
          const SizedBox(height: 16),

          // Send OTP button
          Consumer<AuthViewModel>(
            builder: (context, auth, _) {
              final loading = auth.isWaOtpSendLoading;
              final onCooldown = cooldownSeconds > 0;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _GradientButton(
                    label: 'Send OTP via WhatsApp',
                    iconWidget: const FaIcon(FontAwesomeIcons.whatsapp, size: 18, color: Colors.white),
                    isLoading: loading,
                    onPressed: onSend,
                    disabled: onCooldown,
                  ),
                  if (onCooldown) ...[
                    const SizedBox(height: 8),
                    Center(
                      child: Text(
                        'Try again in ${_fmtCooldown(cooldownSeconds)}',
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
          const SizedBox(height: 12),

          Center(
            child: TextButton(
              onPressed: onClose,
              style: TextButton.styleFrom(tapTargetSize: MaterialTapTargetSize.shrinkWrap),
              child: Text(
                'Cancel',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _muted,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
//  Step 2 — OTP verification (6 separate boxes)
// ─────────────────────────────────────────────────────────────────────
class _OtpVerifyView extends StatefulWidget {
  const _OtpVerifyView({
    super.key,
    required this.phone,
    required this.onVerified,
    required this.onBack,
    required this.onResend,
    required this.showSnack,
  });

  final String phone;
  final void Function(String otp, String action) onVerified;
  final VoidCallback onBack;
  final Future<({bool success, int waitSeconds})> Function() onResend;
  final void Function(String message, {bool isError}) showSnack;

  @override
  State<_OtpVerifyView> createState() => _OtpVerifyViewState();
}

class _OtpVerifyViewState extends State<_OtpVerifyView> {
  static const _otpLength = 6;
  late final List<TextEditingController> _controllers;
  late final List<FocusNode> _focusNodes;

  Timer? _resendTimer;
  int _resendSeconds = 60;
  bool get _canResend => _resendSeconds == 0;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(_otpLength, (_) => TextEditingController());
    _focusNodes = List.generate(_otpLength, (_) => FocusNode());
    _startResendTimer();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNodes[0].requestFocus();
    });
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  void _startResendTimer([int seconds = 60]) {
    _resendSeconds = seconds > 0 ? seconds : 60;
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) { timer.cancel(); return; }
      if (_resendSeconds == 0) {
        timer.cancel();
      } else {
        setState(() => _resendSeconds--);
      }
    });
  }

  String get _otpValue => _controllers.map((c) => c.text).join();

  Future<void> _handleVerify() async {
    FocusScope.of(context).unfocus();
    final otp = _otpValue;
    if (otp.length < _otpLength) {
      widget.showSnack('Please enter the complete $_otpLength-digit code');
      return;
    }

    try {
      final authVM = context.read<AuthViewModel>();
      final result = await authVM.verifyWhatsAppOtp(
        phone: widget.phone,
        otp: otp,
      );

      if (!mounted) return;

      if (result.success) {
        widget.onVerified(otp, result.action);
      } else {
        widget.showSnack(result.message);
        for (final c in _controllers) {
          c.clear();
        }
        _focusNodes[0].requestFocus();
      }
    } catch (e) {
      AppLogger.e('_handleVerify error: $e');
      if (mounted) widget.showSnack('Something went wrong. Please try again.');
    }
  }

  Future<void> _handleResend() async {
    if (!_canResend) return;
    final result = await widget.onResend();
    if (!mounted) return;
    if (result.success) {
      _startResendTimer();
      widget.showSnack(
        'OTP resent to ${widget.phone.substring(0, 2)}****${widget.phone.substring(6)}',
        isError: false,
      );
    } else if (result.waitSeconds > 0) {
      _startResendTimer(result.waitSeconds);
    }
  }

  @override
  Widget build(BuildContext context) {
    final masked = widget.phone.length >= 10
        ? '+91 ${widget.phone.substring(0, 2)}****${widget.phone.substring(6)}'
        : widget.phone;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Drag handle
        Center(
          child: Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFDDE0E4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        const SizedBox(height: 24),

        Text(
          'Verify OTP',
          style: GoogleFonts.poppins(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: _ink,
          ),
        ),
        const SizedBox(height: 6),
        RichText(
          text: TextSpan(
            style: GoogleFonts.poppins(fontSize: 13, color: _muted, height: 1.5),
            children: [
              const TextSpan(text: 'Enter the 6-digit code sent via WhatsApp to '),
              TextSpan(
                text: masked,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _ink,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),

        // OTP boxes
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(_otpLength, (i) {
            return Container(
              width: 46,
              height: 54,
              margin: EdgeInsets.only(right: i < _otpLength - 1 ? 10 : 0),
              child: TextFormField(
                controller: _controllers[i],
                focusNode: _focusNodes[i],
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                maxLength: 1,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: _ink,
                ),
                decoration: InputDecoration(
                  counterText: '',
                  filled: true,
                  fillColor: _surface,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFEBEDF0), width: 1),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _brand, width: 2.0),
                  ),
                ),
                onChanged: (value) {
                  if (value.isNotEmpty && i < _otpLength - 1) {
                    _focusNodes[i + 1].requestFocus();
                  } else if (value.isEmpty && i > 0) {
                    _focusNodes[i - 1].requestFocus();
                  }
                  if (_otpValue.length == _otpLength) _handleVerify();
                },
                onEditingComplete: () {
                  if (i < _otpLength - 1) {
                    _focusNodes[i + 1].requestFocus();
                  } else {
                    _handleVerify();
                  }
                },
              ),
            );
          }),
        ),
        const SizedBox(height: 24),

        Consumer<AuthViewModel>(
          builder: (context, auth, _) => _GradientButton(
            label: 'Verify & Login',
            icon: Icons.check_rounded,
            isLoading: auth.isWaOtpVerifyLoading,
            onPressed: _handleVerify,
          ),
        ),
        const SizedBox(height: 16),

        // Resend row
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "Didn't receive the code? ",
              style: GoogleFonts.poppins(fontSize: 12.5, color: _muted),
            ),
            GestureDetector(
              onTap: _canResend ? _handleResend : null,
              child: Text(
                _canResend ? 'Resend OTP' : 'Resend in ${_resendSeconds}s',
                style: GoogleFonts.poppins(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: _canResend ? _brand : _muted,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        Center(
          child: TextButton(
            onPressed: widget.onBack,
            style: TextButton.styleFrom(tapTargetSize: MaterialTapTargetSize.shrinkWrap),
            child: Text(
              'Change number',
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _muted,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
//  Step 3 — Restaurant name (new vendor registration only)
// ─────────────────────────────────────────────────────────────────────
class _RestaurantNameView extends StatelessWidget {
  const _RestaurantNameView({
    super.key,
    required this.controller,
    required this.onSubmit,
    required this.onBack,
    this.errorText,
  });

  final TextEditingController controller;
  final VoidCallback onSubmit;
  final VoidCallback onBack;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFDDE0E4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        const SizedBox(height: 24),

        Text(
          'Welcome to Zill!',
          style: GoogleFonts.poppins(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: _ink,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          "One last step — enter your restaurant name to create your account.",
          style: GoogleFonts.poppins(fontSize: 13, color: _muted, height: 1.5),
        ),
        const SizedBox(height: 24),

        Text(
          'Restaurant name',
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: _label,
          ),
        ),
        const SizedBox(height: 7),
        TextField(
          controller: controller,
          keyboardType: TextInputType.name,
          textInputAction: TextInputAction.done,
          textCapitalization: TextCapitalization.words,
          onEditingComplete: onSubmit,
          style: GoogleFonts.poppins(
            fontSize: 14,
            color: _ink,
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            hintText: 'e.g. Sharma Ji Ka Dhaba',
            hintStyle: GoogleFonts.poppins(
              fontSize: 13.5,
              color: const Color(0xFFBBBDC3),
              fontWeight: FontWeight.w400,
            ),
            filled: true,
            fillColor: _surface,
            prefixIcon: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 14),
              child: Icon(Icons.store_rounded, color: _muted, size: 19),
            ),
            prefixIconConstraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
          ),
        ),

        if (errorText != null) ...[
          const SizedBox(height: 10),
          _ErrorBanner(message: errorText!),
        ],
        const SizedBox(height: 16),

        Consumer<AuthViewModel>(
          builder: (context, auth, _) => _GradientButton(
            label: 'Create Account',
            icon: Icons.store_rounded,
            isLoading: auth.isWaOtpVerifyLoading,
            onPressed: onSubmit,
          ),
        ),
        const SizedBox(height: 12),

        Center(
          child: TextButton(
            onPressed: onBack,
            style: TextButton.styleFrom(tapTargetSize: MaterialTapTargetSize.shrinkWrap),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _muted,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
//  Reusable error banner
// ─────────────────────────────────────────────────────────────────────
class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _error.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _error.withValues(alpha: 0.25), width: 1),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: _error, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: _error,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
//  Shared gradient button
// ─────────────────────────────────────────────────────────────────────
class _GradientButton extends StatelessWidget {
  const _GradientButton({
    required this.label,
    required this.isLoading,
    required this.onPressed,
    this.icon,
    this.iconWidget,
    this.disabled = false,
    this.iconColor,
  });

  final String label;
  final IconData? icon;
  final Widget? iconWidget;
  final bool isLoading;
  final VoidCallback onPressed;
  final bool disabled;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: (isLoading || disabled)
              ? null
              : const LinearGradient(
                  colors: [_brand, _brandDark],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
          color: (isLoading || disabled) ? _brand.withValues(alpha: 0.55) : null,
          borderRadius: BorderRadius.circular(14),
          boxShadow: (isLoading || disabled)
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
          onPressed: (isLoading || disabled) ? null : onPressed,
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
                      label,
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (iconWidget != null)
                      iconWidget!
                    else if (icon != null)
                      Icon(icon, size: 19, color: iconColor),
                  ],
                ),
        ),
      ),
    );
  }
}
