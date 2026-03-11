import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../utils/password_validator.dart';

/// Real-time password strength indicator with rule checklist.
class PasswordStrengthIndicator extends StatelessWidget {
  final String password;
  const PasswordStrengthIndicator({super.key, required this.password});

  @override
  Widget build(BuildContext context) {
    if (password.isEmpty) return const SizedBox.shrink();

    final rules = PasswordValidator.getRules(password);
    final score = rules.where((r) => r.passed).length;
    final total = rules.length;

    final Color barColor;
    final String label;
    if (score <= 2) {
      barColor = Colors.red;
      label = 'Weak';
    } else if (score <= 3) {
      barColor = Colors.orange;
      label = 'Fair';
    } else if (score <= 4) {
      barColor = const Color(0xFFFFA726);
      label = 'Good';
    } else {
      barColor = const Color(0xFF4CAF50);
      label = 'Strong';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 10),
        // Strength bar
        Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: score / total,
                  minHeight: 5,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation(barColor),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: barColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Rule checklist
        ...rules.map(
          (r) => Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: Row(
              children: [
                Icon(
                  r.passed ? Icons.check_circle : Icons.circle_outlined,
                  size: 14,
                  color: r.passed ? const Color(0xFF4CAF50) : Colors.grey.shade400,
                ),
                const SizedBox(width: 6),
                Text(
                  r.label,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: r.passed ? const Color(0xFF4CAF50) : Colors.grey.shade500,
                    fontWeight: r.passed ? FontWeight.w500 : FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
