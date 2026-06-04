import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:vigil_parents_app/features/device_info/models/device_info_model.dart';
import 'package:vigil_parents_app/features/device_info/repo/device_info_repo.dart';

/// Loads the device info for a single child. Call [load] whenever the
/// selected child changes.
class DeviceInfoViewModel extends ChangeNotifier {
  DeviceInfoViewModel(this._repository);

  final DeviceInfoRepository _repository;

  DeviceInfoResponse? info;
  bool loading = false;
  String? error;

  /// The child the current [info] belongs to.
  String? _childId;
  String? get childId => _childId;

  Future<void> load(String childId) async {
    _childId = childId;
    loading = true;
    error = null;
    notifyListeners();

    try {
      final res = await _repository.fetchDeviceInfo(childId);
      // Ignore a stale response if the selection changed while in flight.
      if (_childId != childId) return;
      info = res;
      error = null;
    } catch (e) {
      if (_childId != childId) return;
      info = null;
      error = e.toString().replaceAll('Exception: ', '');
    } finally {
      if (_childId == childId) {
        loading = false;
        notifyListeners();
      }
    }
  }
}

final deviceInfoRepositoryProvider = Provider<DeviceInfoRepository>((ref) {
  return DeviceInfoRepository();
});

final deviceInfoViewModelProvider =
    ChangeNotifierProvider<DeviceInfoViewModel>((ref) {
      return DeviceInfoViewModel(ref.read(deviceInfoRepositoryProvider));
    });
