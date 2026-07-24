/// Shared form validators so every screen surfaces the same wording for the
/// same problem.
class Validators {
  Validators._();

  static const int minFullNameLength = 2;
  static const int maxFullNameLength = 100;

  /// A name is letters (any script) plus the punctuation real names actually
  /// use: spaces, apostrophes, hyphens and full stops. It must *start* with a
  /// letter, which alone rejects `' OR 1=1 --` and `<script>alert(1)</script>`.
  ///
  /// Because the class is built from `\p{L}`/`\p{M}` rather than `A-Za-z`,
  /// `José` and `李雷` pass while emoji (symbols, not letters) do not.
  static final RegExp _fullNameRegExp = RegExp(
    "^[\\p{L}\\p{M}][\\p{L}\\p{M} .'‘’‐-]*\$",
    unicode: true,
  );

  /// Returns `null` when [value] is a usable full name.
  ///
  /// Leading/trailing spaces are ignored, so `" Anand"` and `"Anand "` are both
  /// accepted — the caller is expected to persist the trimmed value.
  static String? fullName(String? value) {
    final raw = value ?? '';

    if (raw.isEmpty) return 'Full name is required.';

    final name = raw.trim();
    if (name.isEmpty) return 'Full name cannot be empty.';

    // Both bounds count code points, so an accented or CJK name isn't
    // penalised for the extra UTF-16 units it happens to occupy.
    if (name.runes.length < minFullNameLength) {
      return 'Full name must be at least $minFullNameLength characters.';
    }
    if (name.runes.length > maxFullNameLength) {
      return 'Full name cannot exceed $maxFullNameLength characters.';
    }

    if (!_fullNameRegExp.hasMatch(name)) {
      return 'Full name contains invalid characters.';
    }

    return null;
  }

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
  static const int maxPasswordLength = 128;

  /// Printable ASCII excluding the space (0x20). Anything else — emoji, other
  /// scripts, control characters — is not something we want in a credential,
  /// and the exclusion of the space is what catches `' OR 1=1 --`.
  static final RegExp _passwordCharset = RegExp(r'^[\x21-\x7E]+$');

  /// Angle brackets are inside the printable range but are the signature of
  /// markup/script payloads such as `<script>alert()</script>`.
  static final RegExp _passwordBlocked = RegExp(r'[<>]');

  /// Policy check for screens where a password is being *set* (reset / signup).
  /// Reports one failed rule at a time, strongest-signal first, so the field
  /// never shows a wall of text.
  static String? newPassword(String? value) {
    final password = value ?? '';

    if (password.isEmpty) return 'Password is required.';

    if (password.runes.length > maxPasswordLength) {
      return 'Password cannot exceed $maxPasswordLength characters.';
    }

    // Runs before the composition rules below: an injection or emoji payload
    // should be called out as such, not as "needs a lowercase letter".
    if (!_passwordCharset.hasMatch(password) ||
        _passwordBlocked.hasMatch(password)) {
      return 'Password contains invalid characters.';
    }

    if (password.length < minPasswordLength) {
      return 'Password must be at least $minPasswordLength characters.';
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
