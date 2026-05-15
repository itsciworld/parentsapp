import 'package:flutter/material.dart';

/// ============================================================================
/// MODELS
/// ----------------------------------------------------------------------------
/// Plain immutable data classes. When the real API is wired in later, only the
/// repository's `fromJson` mapping needs to change — the UI and ViewModel stay
/// untouched.
/// ============================================================================

/// The parent currently logged in (shown in the app bar).
class ParentProfile {
  final String name;
  final String initials;

  const ParentProfile({required this.name, required this.initials});
}

/// The child device being monitored (header card).
class ChildProfile {
  final String name;
  final String avatarUrl;
  final bool isOnline;
  final String deviceModel;
  final String osVersion;
  final String lastSync;

  const ChildProfile({
    required this.name,
    required this.avatarUrl,
    required this.isOnline,
    required this.deviceModel,
    required this.osVersion,
    required this.lastSync,
  });
}

/// One of the three small status chips under the child header.
class StatusIndicator {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;

  const StatusIndicator({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
  });
}

/// A feature tile in the 4x2 grid (Messages, SMS, Gallery, ...).
class FeatureTile {
  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final int? badgeCount;
  final List<IconData>? clusterIcons;
  final bool isLocked; // 👈 add

  const FeatureTile({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    this.badgeCount,
    this.clusterIcons,
    this.isLocked = false, // 👈 default false
  });
}

/// Live location card data.
class LiveLocation {
  final String label;
  final String address;
  final String accuracy;
  final bool isLive;

  const LiveLocation({
    required this.label,
    required this.address,
    required this.accuracy,
    required this.isLive,
  });
}

/// "Today's Activity Summary" dark panel.
class ActivitySummary {
  final String screenTime;
  final double screenTimeDeltaPercent; // +ve = up vs yesterday
  final int alertCount;

  /// Normalized 0..1 points for the little sparkline.
  final List<double> sparkline;

  const ActivitySummary({
    required this.screenTime,
    required this.screenTimeDeltaPercent,
    required this.alertCount,
    required this.sparkline,
  });
}

/// AI insight banner.
class AiInsight {
  final String title;
  final String message;
  final bool isNew;

  const AiInsight({
    required this.title,
    required this.message,
    required this.isNew,
  });
}

/// Foundation / CSR footer card.
class FoundationInfo {
  final String name;
  final String tagline;
  final String description;
  final String childrenImpacted;
  final String awarenessSessions;
  final String communitySupporters;

  const FoundationInfo({
    required this.name,
    required this.tagline,
    required this.description,
    required this.childrenImpacted,
    required this.awarenessSessions,
    required this.communitySupporters,
  });
}

/// Aggregate root passed to the home screen.
class HomeDashboardData {
  final ParentProfile parent;
  final ChildProfile child;
  final List<StatusIndicator> statusIndicators;
  final List<FeatureTile> features;
  final LiveLocation location;
  final ActivitySummary activity;
  final AiInsight aiInsight;
  final FoundationInfo foundation;
  final int notificationCount;

  const HomeDashboardData({
    required this.parent,
    required this.child,
    required this.statusIndicators,
    required this.features,
    required this.location,
    required this.activity,
    required this.aiInsight,
    required this.foundation,
    required this.notificationCount,
  });
}
