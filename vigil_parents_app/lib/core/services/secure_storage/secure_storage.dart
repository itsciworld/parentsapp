import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SecureDeviceService {
  static const FlutterSecureStorage _storage = FlutterSecureStorage();
  static final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  // SharedPreferences is the source of truth for session values because the
  // background service isolate cannot reliably read flutter_secure_storage on
  // Android. `SharedPreferencesAsync` reads the platform store directly on
  // every call (no per-isolate cache), so both isolates always see the latest
  // value. Secure storage is kept as a best-effort encrypted copy.
  static final SharedPreferencesAsync _prefs = SharedPreferencesAsync();

  static Future<void> _write(String key, String value) async {
    // Mirror first so a flaky/corrupted secure-storage write can never stop the
    // value from reaching the store the background isolate reads.
    await _prefs.setString(key, value);
    try {
      await _storage.write(key: key, value: value);
    } catch (_) {
      // Secure storage can throw (e.g. BAD_DECRYPT on corrupted data); the
      // mirror above already holds the value.
    }
  }

  /// Reads the SharedPreferences mirror first (reliable across isolates), then
  /// falls back to secure storage.
  static Future<String?> _read(String key) async {
    final mirror = await _prefs.getString(key);
    if (mirror != null && mirror.isNotEmpty) return mirror;
    try {
      return await _storage.read(key: key);
    } catch (_) {
      return null;
    }
  }

  static Future<void> _delete(String key) async {
    await _prefs.remove(key);
    try {
      await _storage.delete(key: key);
    } catch (_) {}
  }

  static const _tokenKey = "token";
  static const _emailKey = "email";
  static const _parentIdKey = "parentId";
  static const _parentNameKey = "parent_name";
  static const _childIdKey = "selected_child_id";
  static const _childDeviceKeyKey = "selected_child_device_key";

  // ───────── AUTH DATA STORAGE ─────────

  static Future<void> saveAuthData({
    required String token,
    required String email,
    String? parentId,
    String? parentName,
  }) async {
    await _write(_tokenKey, token);
    await _write(_emailKey, email);
    if (parentId != null) await _write(_parentIdKey, parentId);
    if (parentName != null) await _write(_parentNameKey, parentName);
  }

  static Future<String?> getToken() async => _read(_tokenKey);
  static Future<String?> getEmail() async => _read(_emailKey);
  static Future<String?> getParentId() async => _read(_parentIdKey);
  static Future<String?> getParentName() async => _read(_parentNameKey);

  // The child currently being monitored — used by SMS and the background
  // polling service so it can run without any UI present.
  static Future<void> saveSelectedChildId(String childId) async =>
      _write(_childIdKey, childId);
  static Future<String?> getSelectedChildId() async => _read(_childIdKey);

  // The selected child's per-device key — sent in the `x-device-key` header
  // of that child's API calls (SMS, device-info, etc.).
  static Future<void> saveSelectedChildDeviceKey(String deviceKey) async =>
      _write(_childDeviceKeyKey, deviceKey);
  static Future<String?> getSelectedChildDeviceKey() async =>
      _read(_childDeviceKeyKey);

  static Future<void> clearAuthData() async {
    await _delete(_tokenKey);
    await _delete(_emailKey);
    await _delete(_parentIdKey);
    await _delete(_parentNameKey);
    await _delete(_childIdKey);
    await _delete(_childDeviceKeyKey);
  }

  /// Mirrors any session values that exist only in secure storage into
  /// SharedPreferences. Call once on app startup so sessions created before the
  /// mirror existed still work in the background isolate (no re-login needed).
  static Future<void> syncMirrorFromSecure() async {
    const keys = [
      _tokenKey,
      _emailKey,
      _parentIdKey,
      _parentNameKey,
      _childIdKey,
      _childDeviceKeyKey,
    ];
    for (final key in keys) {
      try {
        final v = await _storage.read(key: key);
        if (v != null && v.isNotEmpty) await _prefs.setString(key, v);
      } catch (_) {
        // Ignore — nothing to mirror for this key.
      }
    }
  }

  // ───────── DEVICE INFO ─────────

  // static Future<Map<String, dynamic>> getDeviceInfo() async {
  //   Map<String, dynamic> deviceData = {};

  //   // if (Platform.isAndroid) {
  //   //   AndroidDeviceInfo androidInfo = await _deviceInfo.androidInfo;

  //   //   deviceData = {
  //   //     "platform": "android",
  //   //     "deviceId": androidInfo.id,
  //   //     "model": androidInfo.model,
  //   //     "deviceName": androidInfo.name,
  //   //     "systemName": "Android",
  //   //     "brand": androidInfo.brand,
  //   //     "manufacturer": androidInfo.manufacturer,
  //   //     "osVersion": androidInfo.version.release,
  //   //     "sdkInt": androidInfo.version.sdkInt,
  //   //     "isPhysicalDevice": androidInfo.isPhysicalDevice,
  //   //   };
  //   // }

  //   // if (Platform.isIOS) {
  //   //   IosDeviceInfo iosInfo = await _deviceInfo.iosInfo;

  //   //   deviceData = {
  //   //     "platform": "ios",
  //   //     "deviceId": iosInfo.identifierForVendor,
  //   //     "model": iosInfo.model,
  //   //     "deviceName": iosInfo.name,
  //   //     "systemName": iosInfo.systemName,
  //   //     "brand": "Apple",
  //   //     "manufacturer": "Apple",
  //   //     "osVersion": iosInfo.systemVersion,
  //   //     "sdkInt": null,
  //   //     "isPhysicalDevice": iosInfo.isPhysicalDevice,
  //   //   };
  //   // }

  //   return deviceData;
  // }
}
