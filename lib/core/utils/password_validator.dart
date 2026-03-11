/// Password validation matching backend rules (validators.py).
///
/// Rules:
///  - Min 8 characters
///  - At least 1 uppercase letter
///  - At least 1 lowercase letter
///  - At least 1 digit
///  - At least 1 special character
class PasswordValidator {
  PasswordValidator._();

  static const int minLength = 8;

  /// Returns null if valid, or the first error message.
  static String? validate(String? value) {
    if (value == null || value.isEmpty) return 'Password is required';
    if (value.length < minLength) return 'Must be at least $minLength characters';
    if (!RegExp(r'[A-Z]').hasMatch(value)) return 'Must contain an uppercase letter';
    if (!RegExp(r'[a-z]').hasMatch(value)) return 'Must contain a lowercase letter';
    if (!RegExp(r'[0-9]').hasMatch(value)) return 'Must contain a number';
    if (!RegExp(r'''[!@#$%^&*()_+\-=\[\]{}|;:,.<>?]''').hasMatch(value)) {
      return 'Must contain a special character (!@#\$%^&* etc.)';
    }
    return null;
  }

  /// Returns all failing rules (for strength indicator).
  static List<PasswordRule> getRules(String value) {
    return [
      PasswordRule('At least $minLength characters', value.length >= minLength),
      PasswordRule('An uppercase letter (A-Z)', RegExp(r'[A-Z]').hasMatch(value)),
      PasswordRule('A lowercase letter (a-z)', RegExp(r'[a-z]').hasMatch(value)),
      PasswordRule('A number (0-9)', RegExp(r'[0-9]').hasMatch(value)),
      PasswordRule(
        'A special character (!@#\$%^&*)',
        RegExp(r'''[!@#$%^&*()_+\-=\[\]{}|;:,.<>?]''').hasMatch(value),
      ),
    ];
  }

  /// Strength score 0-5 (number of passing rules).
  static int strengthScore(String value) {
    if (value.isEmpty) return 0;
    return getRules(value).where((r) => r.passed).length;
  }
}

class PasswordRule {
  final String label;
  final bool passed;
  const PasswordRule(this.label, this.passed);
}
