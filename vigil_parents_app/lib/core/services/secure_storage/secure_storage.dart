import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:device_info_plus/device_info_plus.dart';

class SecureDeviceService {
  static const FlutterSecureStorage _storage = FlutterSecureStorage();
  static final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  static const _tokenKey = "token";
  static const _emailKey = "email";
  static const _parentIdKey = "parentId";
  static const _parentNameKey = "parent_name";
  static const _childIdKey = "selected_child_id";

  // ───────── AUTH DATA STORAGE ─────────

  static Future<void> saveAuthData({
    required String token,
    required String email,
    String? parentId,
    String? parentName,
  }) async {
    await _storage.write(key: _tokenKey, value: token);
    await _storage.write(key: _emailKey, value: email);
    if (parentId != null) {
      await _storage.write(key: _parentIdKey, value: parentId);
    }
    if (parentName != null) {
      await _storage.write(key: _parentNameKey, value: parentName);
    }
  }

  static Future<String?> getToken() async =>
      await _storage.read(key: _tokenKey);
  static Future<String?> getEmail() async =>
      await _storage.read(key: _emailKey);
  static Future<String?> getParentId() async =>
      await _storage.read(key: _parentIdKey);
  static Future<String?> getParentName() async =>
      await _storage.read(key: _parentNameKey);

  // The child currently being monitored — used by SMS and the background
  // polling service so it can run without any UI present.
  static Future<void> saveSelectedChildId(String childId) async =>
      await _storage.write(key: _childIdKey, value: childId);
  static Future<String?> getSelectedChildId() async =>
      await _storage.read(key: _childIdKey);

  static Future<void> clearAuthData() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _emailKey);
    await _storage.delete(key: _parentIdKey);
    await _storage.delete(key: _parentNameKey);
    await _storage.delete(key: _childIdKey);
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
