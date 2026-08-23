import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

/// The credentials kept behind the biometric lock, replayed against
/// `/api/auth/login` once the fingerprint / face scan succeeds.
class BiometricCredentials {
  const BiometricCredentials({required this.email, required this.password});

  final String email;
  final String password;
}

/// The sensor this device offers, so screens can name it and pick an icon
/// without depending on `local_auth` themselves.
enum BiometricKind { face, fingerprint, iris, generic }

extension BiometricKindLabel on BiometricKind {
  String get label {
    final isApple =
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;
    switch (this) {
      case BiometricKind.face:
        return isApple ? 'Face ID' : 'Face Unlock';
      case BiometricKind.fingerprint:
        return isApple ? 'Touch ID' : 'Fingerprint';
      case BiometricKind.iris:
        return 'Iris Unlock';
      case BiometricKind.generic:
        return 'Biometrics';
    }
  }
}

/// Why a biometric prompt ended the way it did. Only [success] should lead to a
/// login attempt; [cancelled] is the user backing out and must stay silent.
enum BiometricPromptStatus { success, cancelled, unavailable, lockedOut, error }

class BiometricPromptResult {
  const BiometricPromptResult(this.status, [this.message]);

  final BiometricPromptStatus status;

  /// User-facing sentence for the non-silent failures. Null on success/cancel.
  final String? message;

  bool get isSuccess => status == BiometricPromptStatus.success;
  bool get isCancelled => status == BiometricPromptStatus.cancelled;
}

/// Biometric ("unlock with your fingerprint / face") sign-in.
///
/// The backend has no biometric endpoint — the only way in is `/api/auth/login`
/// — so enrolling stores the parent's credentials and a successful scan replays
/// them. Those credentials therefore live in **flutter_secure_storage only**
/// (Keystore/Keychain-backed), never in the SharedPreferences mirror that
/// `SecureDeviceService` keeps for the background isolate: that mirror is
/// plaintext, and a password has no business being in it.
///
/// The vault also survives logout on purpose — clearing it there would defeat
/// the whole feature, since biometric login is exactly what happens *after* a
/// logout. It is dropped when biometrics are switched off, when a different
/// account signs in, or when the stored password stops working.
class BiometricAuthService {
  BiometricAuthService._();

  static const FlutterSecureStorage _vault = FlutterSecureStorage();
  static final LocalAuthentication _localAuth = LocalAuthentication();

  static const _enabledKey = 'biometric_login_enabled';
  static const _emailKey = 'biometric_login_email';
  static const _passwordKey = 'biometric_login_password';

  /// The password of the session that is currently signed in, held in memory
  /// for this app run only. It is what lets Profile turn biometrics on without
  /// asking the parent to retype anything — see [cachedPasswordFor].
  static String? _sessionEmail;
  static String? _sessionPassword;

  // ───────── device capability ─────────

  /// True when the hardware exists *and* the user has enrolled at least one
  /// fingerprint/face. Both halves matter: a phone with a sensor but nothing
  /// enrolled can never satisfy a biometric-only prompt.
  static Future<bool> isAvailable() async {
    try {
      if (!await _localAuth.isDeviceSupported()) return false;
      if (!await _localAuth.canCheckBiometrics) return false;
      final enrolled = await _localAuth.getAvailableBiometrics();
      return enrolled.isNotEmpty;
    } catch (e) {
      if (kDebugMode) debugPrint('Biometric availability check failed => $e');
      return false;
    }
  }

  /// Which sensor the UI should name and draw. Falls back to [BiometricKind
  /// .generic] whenever the platform won't say, so the screens still have
  /// something sensible to render.
  static Future<BiometricKind> kind() async {
    try {
      final types = await _localAuth.getAvailableBiometrics();
      if (types.contains(BiometricType.face)) return BiometricKind.face;
      if (types.contains(BiometricType.fingerprint)) {
        return BiometricKind.fingerprint;
      }
      if (types.contains(BiometricType.iris)) return BiometricKind.iris;
    } catch (_) {
      // Fall through to the neutral kind.
    }
    return BiometricKind.generic;
  }

  /// What to call the sensor in the UI — "Face ID" on an iPhone with Face ID,
  /// "Fingerprint" on most Android phones, and a neutral fallback otherwise.
  static Future<String> label() async => (await kind()).label;

  // ───────── enrolment state ─────────

  static Future<bool> isEnabled() async {
    final flag = await _read(_enabledKey);
    if (flag != 'true') return false;
    // A flag with no credentials behind it (a half-finished enrolment, or a
    // wiped Keychain) is not "enabled" — treat it as off.
    final password = await _read(_passwordKey);
    return password != null && password.isNotEmpty;
  }

  /// The account biometrics are enrolled for, shown on the toggle so the parent
  /// can see *whose* login the scan unlocks.
  static Future<String?> enrolledEmail() => _read(_emailKey);

  /// True when biometrics are enrolled and the device can actually run a scan.
  /// The login screen uses this to decide whether to offer the shortcut at all.
  static Future<bool> canLogInWithBiometrics() async {
    if (!await isEnabled()) return false;
    return isAvailable();
  }

  // ───────── prompt ─────────

  /// Runs the system biometric sheet. [biometricOnly] stays true so the device
  /// PIN/pattern can't stand in for the parent's fingerprint — a child who
  /// knows the unlock code must not be able to open the monitoring app.
  static Future<BiometricPromptResult> prompt(String reason) async {
    try {
      final ok = await _localAuth.authenticate(
        localizedReason: reason,
        biometricOnly: true,
      );
      return ok
          ? const BiometricPromptResult(BiometricPromptStatus.success)
          : const BiometricPromptResult(
              BiometricPromptStatus.error,
              'Not recognised. Please try again.',
            );
    } on LocalAuthException catch (e) {
      return _mapException(e);
    } catch (e) {
      if (kDebugMode) debugPrint('Biometric prompt failed => $e');
      return const BiometricPromptResult(
        BiometricPromptStatus.error,
        'Biometric authentication failed. Please try again.',
      );
    }
  }

  static BiometricPromptResult _mapException(LocalAuthException e) {
    switch (e.code) {
      // The parent backed out, or the system pulled the sheet away. Nothing
      // went wrong, so these must not raise an error toast.
      case LocalAuthExceptionCode.userCanceled:
      case LocalAuthExceptionCode.systemCanceled:
      case LocalAuthExceptionCode.timeout:
      case LocalAuthExceptionCode.authInProgress:
      case LocalAuthExceptionCode.userRequestedFallback:
        return const BiometricPromptResult(BiometricPromptStatus.cancelled);

      case LocalAuthExceptionCode.noBiometricsEnrolled:
        return const BiometricPromptResult(
          BiometricPromptStatus.unavailable,
          'No fingerprint or face is set up on this device. Add one in your '
              'device settings first.',
        );

      case LocalAuthExceptionCode.noCredentialsSet:
        return const BiometricPromptResult(
          BiometricPromptStatus.unavailable,
          'This device has no screen lock set up. Add one in your device '
              'settings first.',
        );

      case LocalAuthExceptionCode.noBiometricHardware:
      case LocalAuthExceptionCode.biometricHardwareTemporarilyUnavailable:
      case LocalAuthExceptionCode.uiUnavailable:
        return const BiometricPromptResult(
          BiometricPromptStatus.unavailable,
          'Biometric authentication is not available on this device right now.',
        );

      case LocalAuthExceptionCode.temporaryLockout:
      case LocalAuthExceptionCode.biometricLockout:
        return const BiometricPromptResult(
          BiometricPromptStatus.lockedOut,
          'Too many failed attempts. Unlock your device, then try again.',
        );

      case LocalAuthExceptionCode.deviceError:
      case LocalAuthExceptionCode.unknownError:
        final detail = e.description?.trim() ?? '';
        return BiometricPromptResult(
          BiometricPromptStatus.error,
          detail.isEmpty
              ? 'Biometric authentication failed. Please try again.'
              : detail,
        );
    }
  }

  // ───────── vault ─────────

  /// Turns biometric login on for [email]. The caller is responsible for having
  /// verified [password] first — a wrong one would only surface later, as a
  /// biometric login that keeps bouncing.
  static Future<void> enable({
    required String email,
    required String password,
  }) async {
    await _write(_emailKey, email);
    await _write(_passwordKey, password);
    await _write(_enabledKey, 'true');
  }

  static Future<void> disable() async {
    await _delete(_enabledKey);
    await _delete(_emailKey);
    await _delete(_passwordKey);
  }

  /// The stored credentials. Call only after [prompt] has succeeded — nothing
  /// here re-checks the scan.
  static Future<BiometricCredentials?> readCredentials() async {
    final email = await _read(_emailKey);
    final password = await _read(_passwordKey);
    if (email == null || email.isEmpty) return null;
    if (password == null || password.isEmpty) return null;
    return BiometricCredentials(email: email, password: password);
  }

  // ───────── session bookkeeping ─────────

  /// Records the credentials of a just-completed password login so Profile can
  /// enable biometrics without a second password entry, and keeps an existing
  /// enrolment in step with a changed password.
  ///
  /// Signing in as a *different* parent wipes the vault: the previous account's
  /// credentials must not stay unlockable on a device that has changed hands.
  static Future<void> onPasswordLogin(String email, String password) async {
    _sessionEmail = email;
    _sessionPassword = password;

    final enrolled = await enrolledEmail();
    if (enrolled == null) return;

    if (_sameAccount(enrolled, email)) {
      // Same parent — refresh the stored password, which is how a password
      // reset stops silently breaking biometric login.
      if (await isEnabled()) await _write(_passwordKey, password);
    } else {
      await disable();
    }
  }

  /// The in-memory password for [email], if this app run is the one that signed
  /// them in. Null after a cold start, where the parent has to confirm their
  /// password once to enrol.
  static String? cachedPasswordFor(String email) {
    if (_sessionEmail == null || _sessionPassword == null) return null;
    return _sameAccount(_sessionEmail!, email) ? _sessionPassword : null;
  }

  /// Drops the in-memory copy. Called on logout; the vault itself is untouched.
  static void clearSession() {
    _sessionEmail = null;
    _sessionPassword = null;
  }

  static bool _sameAccount(String a, String b) =>
      a.trim().toLowerCase() == b.trim().toLowerCase();

  // ───────── storage plumbing ─────────
  // Every call is guarded: secure storage can throw (a corrupted entry reads
  // back as BAD_DECRYPT), and a failure here must degrade to "biometrics off"
  // rather than crash a screen.

  static Future<String?> _read(String key) async {
    try {
      return await _vault.read(key: key);
    } catch (e) {
      if (kDebugMode) debugPrint('Biometric vault read failed => $e');
      return null;
    }
  }

  static Future<void> _write(String key, String value) async {
    try {
      await _vault.write(key: key, value: value);
    } catch (e) {
      if (kDebugMode) debugPrint('Biometric vault write failed => $e');
    }
  }

  static Future<void> _delete(String key) async {
    try {
      await _vault.delete(key: key);
    } catch (e) {
      if (kDebugMode) debugPrint('Biometric vault delete failed => $e');
    }
  }
}
