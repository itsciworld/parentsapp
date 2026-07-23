/// Shared form validators so every screen surfaces the same wording for the
/// same problem.
class Validators {
  Validators._();

  /// Deliberately stricter than the usual "something@something.something":
  ///  - exactly one `@` (rejects `user@@gmail.com`)
  ///  - a non-empty local part (rejects `@gmail.com`) built from dot-separated
  ///    chunks, so leading/trailing/consecutive dots are impossible
  ///    (rejects `user..test@gmail.com`)
  ///  - a domain of hyphen-safe labels ending in an alphabetic TLD of 2+
  ///    (rejects `user@`, `userexample.com`)
  ///  - a restricted character set, which also rules out injection-style input
  ///    such as `' OR 1=1 --` or `<script>alert(1)</script>`
  static final RegExp _emailRegExp = RegExp(
    r"^[A-Za-z0-9!#$%&'*+/=?^_`{|}~-]+"
    r"(\.[A-Za-z0-9!#$%&'*+/=?^_`{|}~-]+)*"
    r'@'
    r'([A-Za-z0-9]([A-Za-z0-9-]*[A-Za-z0-9])?\.)+'
    r'[A-Za-z]{2,}$',
  );

  /// Returns `null` when [value] is a well-formed email address.
  static String? email(String? value) {
    final email = value?.trim() ?? '';

    if (email.isEmpty) return 'Email address is required.';

    // RFC 5321 length caps — a value past these is invalid no matter how it
    // is shaped, and keeps the regex away from pathological input.
    final atIndex = email.indexOf('@');
    if (email.length > 254 || (atIndex > 64)) {
      return 'Please enter a valid email address.';
    }

    if (!_emailRegExp.hasMatch(email)) {
      return 'Please enter a valid email address.';
    }

    return null;
  }

  /// Presence-only check — the login screen must not leak the password policy.
  static String? password(String? value) {
    if (value == null || value.isEmpty) return 'Password is required.';
    return null;
  }

  static const int minPasswordLength = 8;
  static const int maxPasswordLength = 64;

  /// Policy check for screens where a password is being *set* (reset / signup).
  /// Reports one failed rule at a time, strongest-signal first, so the field
  /// never shows a wall of text.
  static String? newPassword(String? value) {
    final password = value ?? '';

    if (password.isEmpty) return 'Password is required.';

    if (password.length < minPasswordLength) {
      return 'Password must be at least $minPasswordLength characters.';
    }
    if (password.length > maxPasswordLength) {
      return 'Password must not exceed $maxPasswordLength characters.';
    }
    if (!password.contains(RegExp(r'[A-Z]'))) {
      return 'Password must contain at least one uppercase letter.';
    }
    if (!password.contains(RegExp(r'[a-z]'))) {
      return 'Password must contain at least one lowercase letter.';
    }
    if (!password.contains(RegExp(r'[0-9]'))) {
      return 'Password must contain at least one number.';
    }
    if (!password.contains(RegExp(r'[^A-Za-z0-9]'))) {
      return 'Password must contain at least one special character.';
    }
    if (password.contains(RegExp(r'\s'))) {
      return 'Password must not contain spaces.';
    }

    return null;
  }

  /// Confirmation field. [original] is read at validation time so it always
  /// reflects what's currently in the password field.
  static String? confirmPassword(String? value, String original) {
    final confirm = value ?? '';

    if (confirm.isEmpty) return 'Confirm password is required.';
    if (confirm != original) return 'Passwords do not match.';

    return null;
  }
}
