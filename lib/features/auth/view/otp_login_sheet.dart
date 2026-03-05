import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
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

/// Opens the OTP Login bottom sheet.
void showOtpLoginSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _OtpLoginSheet(),
  );
}

// ─────────────────────────────────────────────────────────────────────
//  Main OTP bottom sheet — manages Step A ↔ Step B
// ─────────────────────────────────────────────────────────────────────
class _OtpLoginSheet extends StatefulWidget {
  const _OtpLoginSheet();

  @override
  State<_OtpLoginSheet> createState() => _OtpLoginSheetState();
}

class _OtpLoginSheetState extends State<_OtpLoginSheet> {
  final _emailCtrl = TextEditingController();
  final _emailFormKey = GlobalKey<FormState>();

  // Step A = email input, Step B = OTP verification
  bool _otpSent = false;
  String _email = '';

  // Rate-limit cooldown (seconds remaining until user can send OTP again)
  int _cooldownSeconds = 0;
  Timer? _cooldownTimer;

  // Inline error shown below the email field (SnackBars render behind the sheet)
  String? _sendError;

  @override
  void initState() {
    super.initState();
    _emailCtrl.addListener(() {
      if (_sendError != null) setState(() => _sendError = null);
    });
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  void _startCooldown(int seconds) {
    _cooldownTimer?.cancel();
    setState(() => _cooldownSeconds = seconds);
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
    // Use maybeOf so we don't crash if the sheet is being dismissed while
    // an async OTP call is still in-flight and returns after deactivation.
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
    if (!(_emailFormKey.currentState?.validate() ?? false)) return;

    try {
      final authVM = context.read<AuthViewModel>();
      final result = await authVM.requestOtp(email: _emailCtrl.text.trim());

      if (!mounted) return;

      if (result.success) {
        setState(() {
          _email = _emailCtrl.text.trim();
          _sendError = null;
          _otpSent = true;
        });
      } else {
        if (result.waitSeconds > 0) _startCooldown(result.waitSeconds);
        // Show inline — snack bars render on the login screen Scaffold (behind the sheet)
        setState(() => _sendError = result.message);
      }
    } catch (e) {
      AppLogger.e('_handleSendOtp error: $e');
      if (mounted) setState(() => _sendError = 'Something went wrong. Please try again.');
    }
  }

  // ── Resend OTP (Step B) — skips form validation, sends to known email ──
  Future<({bool success, int waitSeconds})> _resendOtp() async {
    try {
      final result = await context.read<AuthViewModel>().requestOtp(
        email: _email,
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

  // ── OTP verified → navigate ───────────────────────────────────────
  void _onOtpVerified() {
    if (!mounted) return;
    // pushNamedAndRemoveUntil clears the entire route stack (bottom sheet
    // + login screen) in a single atomic operation, avoiding the race
    // condition where pop() invalidates the context before the second
    // Navigator call can execute.
    Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
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
        child: _otpSent
            ? _OtpVerifyView(
                key: const ValueKey('verify'),
                email: _email,
                onVerified: _onOtpVerified,
                onBack: () => setState(() => _otpSent = false),
                onResend: _resendOtp,
                showSnack: _showSnack,
              )
            : _EmailInputView(
                key: const ValueKey('email'),
                formKey: _emailFormKey,
                controller: _emailCtrl,
                onSend: _handleSendOtp,
                onClose: () => Navigator.of(context).pop(),
                cooldownSeconds: _cooldownSeconds,
                errorText: _sendError,
              ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
//  Step A — Email address input
// ─────────────────────────────────────────────────────────────────────
class _EmailInputView extends StatelessWidget {
  const _EmailInputView({
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
            'Login with OTP',
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: _ink,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "Enter your registered email address and we'll send a one-time code.",
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: _muted,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),

          // Email field
          Text(
            'Email address',
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _label,
            ),
          ),
          const SizedBox(height: 7),
          TextFormField(
            controller: controller,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            onEditingComplete: onSend,
            validator: (v) {
              if (v == null || v.trim().isEmpty) {
                return 'Email is required';
              }
              final emailRegex = RegExp(
                r'^[\w\.\-\+]+@[\w\-]+\.[\w\-]{2,}$',
                caseSensitive: false,
              );
              if (!emailRegex.hasMatch(v.trim())) {
                return 'Enter a valid email address';
              }
              return null;
            },
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: _ink,
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              hintText: 'you@example.com',
              hintStyle: GoogleFonts.poppins(
                fontSize: 13.5,
                color: const Color(0xFFBBBDC3),
                fontWeight: FontWeight.w400,
              ),
              filled: true,
              fillColor: _surface,
              prefixIcon: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 14),
                child: Icon(
                  Icons.mail_outline_rounded,
                  color: _muted,
                  size: 19,
                ),
              ),
              prefixIconConstraints: const BoxConstraints(
                minWidth: 48,
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
                borderSide: const BorderSide(
                  color: Color(0xFFEBEDF0),
                  width: 1,
                ),
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

          // Inline error (SnackBars render on the login screen Scaffold, behind the sheet)
          if (errorText != null) ...[
            const SizedBox(height: 10),
            Container(
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
                      errorText!,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: _error,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),

          // Send OTP button
          Consumer<AuthViewModel>(
            builder: (context, auth, _) {
              final loading = auth.isOtpSendLoading;
              final onCooldown = cooldownSeconds > 0;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _GradientButton(
                    label: 'Send OTP',
                    icon: Icons.arrow_forward_rounded,
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

          // Back
          Center(
            child: TextButton(
              onPressed: onClose,
              style: TextButton.styleFrom(
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                'Back to Sign In',
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
//  Step B — OTP verification (6 separate boxes)
// ─────────────────────────────────────────────────────────────────────
class _OtpVerifyView extends StatefulWidget {
  const _OtpVerifyView({
    super.key,
    required this.email,
    required this.onVerified,
    required this.onBack,
    required this.onResend,
    required this.showSnack,
  });

  final String email;
  final VoidCallback onVerified;
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
  int _resendSeconds = 30;
  bool get _canResend => _resendSeconds == 0;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(_otpLength, (_) => TextEditingController());
    _focusNodes = List.generate(_otpLength, (_) => FocusNode());
    _startResendTimer();

    // Focus first box on open
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

  void _startResendTimer([int seconds = 30]) {
    _resendSeconds = seconds > 0 ? seconds : 30;
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
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
      final result = await authVM.verifyOtpAndLogin(
        email: widget.email,
        otp: otp,
      );

      if (!mounted) return;

      if (result.success) {
        widget.onVerified();
      } else {
        widget.showSnack(result.message);
        for (final c in _controllers) {
          c.clear();
        }
        _focusNodes[0].requestFocus();
      }
    } catch (e) {
      AppLogger.e('_handleVerify error: $e');
      if (mounted) {
        widget.showSnack('Something went wrong. Please try again.');
      }
    }
  }

  Future<void> _handleResend() async {
    if (!_canResend) return;
    final result = await widget.onResend();
    if (!mounted) return;
    if (result.success) {
      _startResendTimer();
      widget.showSnack('OTP resent to ${widget.email}', isError: false);
    } else if (result.waitSeconds > 0) {
      // Use server-side wait time so the countdown matches the backend limit.
      _startResendTimer(result.waitSeconds);
    }
    // Error snack already shown by _resendOtp().
  }

  @override
  Widget build(BuildContext context) {
    // Mask email: show first 2 chars + *** + @domain
    final email = widget.email;
    final atIndex = email.indexOf('@');
    final masked = atIndex > 2
        ? '${email.substring(0, 2)}${'*' * (atIndex - 2)}${email.substring(atIndex)}'
        : email;

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

        // Title
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
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: _muted,
              height: 1.5,
            ),
            children: [
              const TextSpan(text: 'Enter the 6-digit code sent to '),
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

        // ── OTP boxes ──
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
                    borderSide: const BorderSide(
                      color: Color(0xFFEBEDF0),
                      width: 1,
                    ),
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
                  // Auto-submit when all filled
                  if (_otpValue.length == _otpLength) {
                    _handleVerify();
                  }
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

        // ── Verify button ──
        Consumer<AuthViewModel>(
          builder: (context, auth, _) {
            final loading = auth.isOtpVerifyLoading;
            return _GradientButton(
              label: 'Verify & Login',
              icon: Icons.check_rounded,
              isLoading: loading,
              onPressed: _handleVerify,
            );
          },
        ),
        const SizedBox(height: 16),

        // ── Resend row ──
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

        // Back
        Center(
          child: TextButton(
            onPressed: widget.onBack,
            style: TextButton.styleFrom(
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              'Change email address',
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
//  Shared gradient button (reused in both steps)
// ─────────────────────────────────────────────────────────────────────
class _GradientButton extends StatelessWidget {
  const _GradientButton({
    required this.label,
    required this.icon,
    required this.isLoading,
    required this.onPressed,
    this.disabled = false,
  });

  final String label;
  final IconData icon;
  final bool isLoading;
  final VoidCallback onPressed;
  final bool disabled;

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
                    Icon(icon, size: 19),
                  ],
                ),
        ),
      ),
    );
  }
}
