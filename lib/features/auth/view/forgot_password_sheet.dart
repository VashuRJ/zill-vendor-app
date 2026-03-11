import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../core/utils/app_logger.dart';
import '../../../core/utils/password_validator.dart';
import '../../../core/widgets/password_strength_indicator.dart';
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

/// Opens the Forgot Password bottom sheet (3-step OTP flow).
///
/// Call from login_screen.dart:
/// ```dart
/// showForgotPasswordSheet(context);
/// ```
void showForgotPasswordSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _ForgotPasswordSheet(),
  );
}

// ─────────────────────────────────────────────────────────────────────
//  Main controller — manages 3 steps
//  Step 1: Email input → request OTP
//  Step 2: OTP verification (6 boxes)
//  Step 3: New password + confirm → reset
// ─────────────────────────────────────────────────────────────────────
enum _ResetStep { email, otp, newPassword }

class _ForgotPasswordSheet extends StatefulWidget {
  const _ForgotPasswordSheet();

  @override
  State<_ForgotPasswordSheet> createState() => _ForgotPasswordSheetState();
}

class _ForgotPasswordSheetState extends State<_ForgotPasswordSheet> {
  final _emailCtrl = TextEditingController();
  final _emailFormKey = GlobalKey<FormState>();

  _ResetStep _step = _ResetStep.email;
  String _email = '';
  String _otp = '';

  // Inline error shown below the email field (SnackBars render behind the sheet)
  String? _sendError;

  @override
  void initState() {
    super.initState();
    // Clear inline error as soon as user edits the email
    _emailCtrl.addListener(() {
      if (_sendError != null) setState(() => _sendError = null);
    });
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
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
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 4),
        ),
      );
  }

  // ── Step 1 → Send OTP ──────────────────────────────────────────────
  Future<void> _handleSendOtp() async {
    FocusScope.of(context).unfocus();
    if (!(_emailFormKey.currentState?.validate() ?? false)) return;

    try {
      final authVM = context.read<AuthViewModel>();
      final result = await authVM.requestPasswordReset(
        email: _emailCtrl.text.trim(),
      );

      if (!mounted) return;

      if (result.success) {
        setState(() {
          _email = _emailCtrl.text.trim();
          _sendError = null;
          _step = _ResetStep.otp;
        });
      } else {
        // Show inline — snack bars render on the login screen Scaffold (behind the sheet)
        setState(() => _sendError = result.message);
      }
    } catch (e) {
      AppLogger.e('_handleSendOtp error: $e');
      if (mounted) setState(() => _sendError = 'Something went wrong. Please try again.');
    }
  }

  // ── Resend OTP (Step 2) — skips form validation, sends to known email ──
  Future<({bool success})> _resendPasswordResetOtp() async {
    try {
      final result = await context.read<AuthViewModel>().requestPasswordReset(
        email: _email,
      );
      if (!mounted) return (success: false);
      if (!result.success) _showSnack(result.message);
      return (success: result.success);
    } catch (e) {
      AppLogger.e('_resendPasswordResetOtp error: $e');
      if (mounted) _showSnack('Something went wrong. Please try again.');
      return (success: false);
    }
  }

  // ── Step 2 → OTP verified, go to new password ─────────────────────
  void _onOtpVerified(String otp) {
    if (!mounted) return;
    setState(() {
      _otp = otp;
      _step = _ResetStep.newPassword;
    });
  }

  // ── Step 3 → Password reset success ───────────────────────────────
  void _onPasswordReset() {
    if (!mounted) return;
    // Show snack BEFORE pop — after pop the context is deactivated and
    // ScaffoldMessenger.maybeOf(context) returns null.
    _showSnack(
      'Password reset successful! Please sign in with your new password.',
      isError: false,
    );
    Navigator.of(context).pop();
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
        child: _buildCurrentStep(),
      ),
    );
  }

  Widget _buildCurrentStep() {
    switch (_step) {
      case _ResetStep.email:
        return _EmailStepView(
          key: const ValueKey('step-email'),
          formKey: _emailFormKey,
          controller: _emailCtrl,
          onSend: _handleSendOtp,
          onClose: () => Navigator.of(context).pop(),
          errorText: _sendError,
        );
      case _ResetStep.otp:
        return _OtpStepView(
          key: const ValueKey('step-otp'),
          email: _email,
          onVerified: _onOtpVerified,
          onBack: () => setState(() => _step = _ResetStep.email),
          onResend: _resendPasswordResetOtp,
          showSnack: _showSnack,
        );
      case _ResetStep.newPassword:
        return _NewPasswordStepView(
          key: const ValueKey('step-password'),
          email: _email,
          otp: _otp,
          onSuccess: _onPasswordReset,
          onBack: () => setState(() => _step = _ResetStep.otp),
          showSnack: _showSnack,
        );
    }
  }
}

// ─────────────────────────────────────────────────────────────────────
//  Step 1 — Email address input
// ─────────────────────────────────────────────────────────────────────
class _EmailStepView extends StatelessWidget {
  const _EmailStepView({
    super.key,
    required this.formKey,
    required this.controller,
    required this.onSend,
    required this.onClose,
    this.errorText,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController controller;
  final VoidCallback onSend;
  final VoidCallback onClose;
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

          // Step indicator
          _StepIndicator(currentStep: 1),
          const SizedBox(height: 20),

          // Title
          Text(
            'Forgot Password',
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: _ink,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "Enter your registered email address and we'll send "
            "a verification code to reset your password.",
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
              if (v == null || v.trim().isEmpty) return 'Email is required';
              final regex = RegExp(
                r'^[\w\.\-\+]+@[\w\-]+\.[\w\-]{2,}$',
                caseSensitive: false,
              );
              if (!regex.hasMatch(v.trim())) {
                return 'Enter a valid email address';
              }
              return null;
            },
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: _ink,
              fontWeight: FontWeight.w500,
            ),
            decoration: _inputDecoration(
              hint: 'you@example.com',
              prefixIcon: Icons.mail_outline_rounded,
            ),
          ),

          // Inline error (SnackBars render on the login Scaffold behind the sheet)
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
              return _GradientButton(
                label: 'Send Verification Code',
                icon: Icons.arrow_forward_rounded,
                isLoading: auth.isResetLoading,
                onPressed: onSend,
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
//  Step 2 — OTP verification (6 separate boxes)
// ─────────────────────────────────────────────────────────────────────
class _OtpStepView extends StatefulWidget {
  const _OtpStepView({
    super.key,
    required this.email,
    required this.onVerified,
    required this.onBack,
    required this.onResend,
    required this.showSnack,
  });

  final String email;
  final void Function(String otp) onVerified;
  final VoidCallback onBack;
  final Future<({bool success})> Function() onResend;
  final void Function(String message, {bool isError}) showSnack;

  @override
  State<_OtpStepView> createState() => _OtpStepViewState();
}

class _OtpStepViewState extends State<_OtpStepView> {
  static const _otpLength = 6;
  late final List<TextEditingController> _controllers;
  late final List<FocusNode> _focusNodes;

  Timer? _resendTimer;
  int _resendSeconds = 30;
  bool get _canResend => _resendSeconds == 0;

  // Inline error — snack bars render behind the sheet
  String? _verifyError;

  @override
  void initState() {
    super.initState();
    _controllers =
        List.generate(_otpLength, (_) => TextEditingController());
    _focusNodes = List.generate(_otpLength, (_) => FocusNode());

    // Clear inline error when user edits any OTP box
    for (final c in _controllers) {
      c.addListener(() {
        if (_verifyError != null) setState(() => _verifyError = null);
      });
    }

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

  void _startResendTimer() {
    _resendSeconds = 30;
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
      setState(() => _verifyError = 'Please enter the complete $_otpLength-digit code.');
      return;
    }

    setState(() => _verifyError = null);

    final result = await context.read<AuthViewModel>().verifyPasswordResetOtp(
      email: widget.email,
      otp: otp,
    );

    if (!mounted) return;

    if (result.success) {
      widget.onVerified(otp);
    } else {
      setState(() => _verifyError = result.message);
    }
  }

  Future<void> _handleResend() async {
    if (!_canResend) return;
    final result = await widget.onResend();
    if (!mounted) return;
    if (result.success) {
      _startResendTimer();
      for (final c in _controllers) {
        c.clear();
      }
      _focusNodes[0].requestFocus();
      widget.showSnack('Verification code resent to ${widget.email}', isError: false);
    }
    // Error snack already shown by _resendPasswordResetOtp.
  }

  @override
  Widget build(BuildContext context) {
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

        // Step indicator
        _StepIndicator(currentStep: 2),
        const SizedBox(height: 20),

        // Title
        Text(
          'Verify Code',
          style: GoogleFonts.poppins(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: _ink,
          ),
        ),
        const SizedBox(height: 6),
        RichText(
          text: TextSpan(
            style:
                GoogleFonts.poppins(fontSize: 13, color: _muted, height: 1.5),
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
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                        color: Color(0xFFEBEDF0), width: 1),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: _brand, width: 2.0),
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
                    _handleVerify(); // async — fire and forget
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
        const SizedBox(height: 20),

        // Inline error
        if (_verifyError != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFDC2626).withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: const Color(0xFFDC2626).withValues(alpha: 0.25),
                  width: 1),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline_rounded,
                    color: Color(0xFFDC2626), size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _verifyError!,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: const Color(0xFFDC2626),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ] else
          const SizedBox(height: 4),

        // Verify button
        Consumer<AuthViewModel>(
          builder: (context, auth, _) => _GradientButton(
            label: 'Verify Code',
            icon: Icons.check_rounded,
            isLoading: auth.isOtpResetVerifyLoading,
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
                _canResend ? 'Resend Code' : 'Resend in ${_resendSeconds}s',
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
//  Step 3 — New password + confirm
// ─────────────────────────────────────────────────────────────────────
class _NewPasswordStepView extends StatefulWidget {
  const _NewPasswordStepView({
    super.key,
    required this.email,
    required this.otp,
    required this.onSuccess,
    required this.onBack,
    required this.showSnack,
  });

  final String email;
  final String otp;
  final VoidCallback onSuccess;
  final VoidCallback onBack;
  final void Function(String message, {bool isError}) showSnack;

  @override
  State<_NewPasswordStepView> createState() => _NewPasswordStepViewState();
}

class _NewPasswordStepViewState extends State<_NewPasswordStepView> {
  final _formKey = GlobalKey<FormState>();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  String? _resetError;

  @override
  void initState() {
    super.initState();
    // Clear inline error when user edits either password field
    _passwordCtrl.addListener(() {
      if (_resetError != null) setState(() => _resetError = null);
    });
    _confirmCtrl.addListener(() {
      if (_resetError != null) setState(() => _resetError = null);
    });
  }

  @override
  void dispose() {
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleResetPassword() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    try {
      final authVM = context.read<AuthViewModel>();
      final result = await authVM.confirmPasswordReset(
        email: widget.email,
        otp: widget.otp,
        newPassword: _passwordCtrl.text,
        confirmPassword: _confirmCtrl.text,
      );

      if (!mounted) return;

      if (result.success) {
        widget.onSuccess();
      } else {
        // Show inline — snack bars render on the login screen Scaffold (behind the sheet)
        setState(() => _resetError = result.message);
      }
    } catch (e) {
      AppLogger.e('_handleResetPassword error: $e');
      if (mounted) setState(() => _resetError = 'Something went wrong. Please try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
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

          // Step indicator
          _StepIndicator(currentStep: 3),
          const SizedBox(height: 20),

          // Title
          Text(
            'Create New Password',
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: _ink,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Your new password must include uppercase, lowercase, number & special character.',
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: _muted,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),

          // New password
          Text(
            'New Password',
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _label,
            ),
          ),
          const SizedBox(height: 7),
          TextFormField(
            controller: _passwordCtrl,
            obscureText: _obscurePassword,
            textInputAction: TextInputAction.next,
            validator: PasswordValidator.validate,
            onChanged: (_) => setState(() {}),
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: _ink,
              fontWeight: FontWeight.w500,
            ),
            decoration: _inputDecoration(
              hint: 'Enter new password',
              prefixIcon: Icons.lock_outline_rounded,
            ).copyWith(
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: _muted,
                  size: 20,
                ),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
          ),
          PasswordStrengthIndicator(password: _passwordCtrl.text),
          const SizedBox(height: 16),

          // Confirm password
          Text(
            'Confirm Password',
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _label,
            ),
          ),
          const SizedBox(height: 7),
          TextFormField(
            controller: _confirmCtrl,
            obscureText: _obscureConfirm,
            textInputAction: TextInputAction.done,
            onEditingComplete: _handleResetPassword,
            validator: (v) {
              if (v == null || v.isEmpty) return 'Please confirm your password';
              if (v != _passwordCtrl.text) return 'Passwords do not match';
              return null;
            },
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: _ink,
              fontWeight: FontWeight.w500,
            ),
            decoration: _inputDecoration(
              hint: 'Re-enter new password',
              prefixIcon: Icons.lock_outline_rounded,
            ).copyWith(
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureConfirm
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: _muted,
                  size: 20,
                ),
                onPressed: () =>
                    setState(() => _obscureConfirm = !_obscureConfirm),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Inline error (snack bars render behind the sheet)
          if (_resetError != null) ...[
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
                      _resetError!,
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
            const SizedBox(height: 16),
          ] else
            const SizedBox(height: 8),

          // Reset button
          Consumer<AuthViewModel>(
            builder: (context, auth, _) {
              return _GradientButton(
                label: 'Reset Password',
                icon: Icons.check_rounded,
                isLoading: auth.isResetLoading,
                onPressed: _handleResetPassword,
              );
            },
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
                'Back',
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
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
//  Step indicator — 3 dots with active/completed states
// ─────────────────────────────────────────────────────────────────────
class _StepIndicator extends StatelessWidget {
  const _StepIndicator({required this.currentStep});

  final int currentStep; // 1, 2, or 3

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (i) {
        final step = i + 1;
        final isActive = step == currentStep;
        final isCompleted = step < currentStep;

        return Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: isActive ? 28 : 10,
              height: 10,
              decoration: BoxDecoration(
                color: isCompleted
                    ? _success
                    : isActive
                        ? _brand
                        : const Color(0xFFDDE0E4),
                borderRadius: BorderRadius.circular(5),
              ),
            ),
            if (i < 2) const SizedBox(width: 8),
          ],
        );
      }),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
//  Shared gradient button
// ─────────────────────────────────────────────────────────────────────
class _GradientButton extends StatelessWidget {
  const _GradientButton({
    required this.label,
    required this.icon,
    required this.isLoading,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
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
                    valueColor:
                        AlwaysStoppedAnimation<Color>(Colors.white),
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

// ─────────────────────────────────────────────────────────────────────
//  Shared input decoration builder
// ─────────────────────────────────────────────────────────────────────
InputDecoration _inputDecoration({
  required String hint,
  required IconData prefixIcon,
}) {
  return InputDecoration(
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
    prefixIconConstraints:
        const BoxConstraints(minWidth: 48, minHeight: 48),
    contentPadding:
        const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
  );
}
