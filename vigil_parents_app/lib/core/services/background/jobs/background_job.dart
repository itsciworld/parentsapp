import 'package:flutter_background_service/flutter_background_service.dart';

/// A recurring unit of background work. Implement this and register the job in
/// `background_service.dart`'s `_jobs` list to have it run automatically.
abstract class BackgroundJob {
  /// Unique key used to track this job's last run time.
  String get name;

  /// How often this job should run.
  Duration get interval;

  /// The work itself. Keep it short on iOS (≤ ~15s).
  Future<void> run(ServiceInstance service);
}
