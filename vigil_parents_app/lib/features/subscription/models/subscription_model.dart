import 'package:flutter/material.dart';

/// The set of monitoring capabilities a plan can unlock. The backend sends
/// these as a `feature_flags` map; we keep the raw map (so unknown/new flags
/// are never lost) and expose typed getters + display metadata for the ones
/// the UI actually renders.
class PlanFeatures {
  /// Raw flags exactly as received, e.g. {"smsMonitoring": true, ...}.
  final Map<String, bool> raw;

  const PlanFeatures(this.raw);

  factory PlanFeatures.fromJson(Map? json) {
    final map = <String, bool>{};
    if (json != null) {
      json.forEach((key, value) {
        map[key.toString()] = value == true;
      });
    }
    return PlanFeatures(map);
  }

  bool _anyTrue(List<String> keys) => keys.any((k) => raw[k] == true);

  bool get sms => _anyTrue(const ['smsMonitoring']);
  bool get calls => _anyTrue(const ['callLogs']);
  bool get location => _anyTrue(const ['liveLocation']);
  bool get media => _anyTrue(const ['mediaMonitoring']);
  bool get social => _anyTrue(const ['socialMonitoring']);
  bool get ai => _anyTrue(const ['aiAlerts']);

  /// The single source of truth for the app's monitoring capabilities. Each
  /// entry lists the backend flag key(s) it can match (the API sends more flags
  /// than the original six — contacts, events and notification keys vary a
  /// little by version, so we accept a few aliases), plus a detailed label for
  /// the plans screen and a short label for the home chips.
  static const List<_KnownFeature> _known = [
    _KnownFeature(
      ['smsMonitoring'],
      'SMS Monitoring',
      'SMS',
      Icons.sms_rounded,
    ),
    _KnownFeature(['callLogs'], 'Call Logs', 'Calls', Icons.call_rounded),
    _KnownFeature(
      ['liveLocation'],
      'Live Location',
      'Location',
      Icons.location_on_rounded,
    ),
    _KnownFeature(
      ['mediaMonitoring'],
      'Gallery / Media',
      'Gallery',
      Icons.photo_library_rounded,
    ),
    _KnownFeature(
      ['contactsMonitoring', 'contactMonitoring', 'contacts'],
      'Contacts',
      'Contacts',
      Icons.contacts_rounded,
      // Included in every plan (trial + paid), regardless of the backend flag.
      alwaysOn: true,
    ),
    _KnownFeature(
      ['eventsMonitoring', 'eventMonitoring', 'calendarMonitoring', 'events'],
      'Calendar Events',
      'Events',
      Icons.event_rounded,
      // Included in every plan (trial + paid), regardless of the backend flag.
      alwaysOn: true,
    ),
    _KnownFeature(
      ['socialMonitoring'],
      'Social Apps',
      'Social',
      Icons.chat_bubble_rounded,
    ),
    _KnownFeature(
      ['socialNotifications', 'notificationMonitoring', 'appNotifications'],
      'Social Notifications',
      'Notifications',
      Icons.notifications_active_rounded,
      // Included in every plan (trial + paid), regardless of the backend flag.
      alwaysOn: true,
    ),
    _KnownFeature(
      ['aiAlerts'],
      'AI Alerts',
      'AI Alerts',
      Icons.auto_awesome_rounded,
    ),
  ];

  bool _hasAny(List<String> keys) => keys.any((k) => raw.containsKey(k));

  /// Detailed feature list for a plan card. Shows every known capability marked
  /// included/locked based on this plan's flags, so the plans screen advertises
  /// the full set (SMS … Social Notifications) rather than only what's enabled.
  List<PlanFeatureItem> get detailedItems {
    return [
      for (final f in _known)
        PlanFeatureItem(
          key: f.keys.first,
          label: f.label,
          icon: f.icon,
          enabled: f.alwaysOn || _anyTrue(f.keys),
        ),
    ];
  }

  /// Like [detailedItems] but limited to the flags the backend actually sent
  /// for this plan — used where showing phantom "locked" rows would be wrong.
  List<PlanFeatureItem> get presentItems {
    return [
      for (final f in _known)
        if (f.alwaysOn || _hasAny(f.keys))
          PlanFeatureItem(
            key: f.keys.first,
            label: f.label,
            icon: f.icon,
            enabled: f.alwaysOn || _anyTrue(f.keys),
          ),
    ];
  }

  /// Short-label catalogue for the home upgrade chips: the full known set,
  /// marked enabled per [enabledIn].
  static List<PlanFeatureItem> catalogue({PlanFeatures? enabledIn}) {
    return [
      for (final f in _known)
        PlanFeatureItem(
          key: f.keys.first,
          label: f.shortLabel,
          icon: f.icon,
          enabled:
              f.alwaysOn ||
              (enabledIn != null &&
                  f.keys.any((k) => enabledIn.raw[k] == true)),
        ),
    ];
  }
}

class _KnownFeature {
  final List<String> keys;
  final String label;
  final String shortLabel;
  final IconData icon;

  /// When true the feature is treated as included in every plan, so it always
  /// renders as enabled no matter what (or whether) the backend flag says.
  final bool alwaysOn;

  const _KnownFeature(
    this.keys,
    this.label,
    this.shortLabel,
    this.icon, {
    this.alwaysOn = false,
  });
}

/// A single feature line for display: what it is and whether this plan has it.
class PlanFeatureItem {
  final String key;
  final String label;
  final IconData icon;
  final bool enabled;

  const PlanFeatureItem({
    required this.key,
    required this.label,
    required this.icon,
    required this.enabled,
  });
}

/// A purchasable plan from `GET /api/subscriptions/plans`.
class SubscriptionPlan {
  final String id;
  final String name;
  final String type; // "trial" | "family" | ...
  final double price;
  final String currency; // flat "USD" for now
  final int durationDays;
  final int maxChildren;
  final PlanFeatures features;
  final bool isActive;
  final String description;

  const SubscriptionPlan({
    required this.id,
    required this.name,
    required this.type,
    required this.price,
    required this.currency,
    required this.durationDays,
    required this.maxChildren,
    required this.features,
    required this.isActive,
    required this.description,
  });

  bool get isFree => price <= 0;
  bool get isTrial => type.toLowerCase() == 'trial';

  factory SubscriptionPlan.fromJson(Map<String, dynamic> json) {
    return SubscriptionPlan(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      type: (json['type'] ?? '').toString(),
      price: _toDouble(json['price']),
      currency: (json['currency'] ?? 'USD').toString(),
      durationDays: _toInt(json['duration_days']),
      maxChildren: _toInt(json['max_children']),
      features: PlanFeatures.fromJson(json['feature_flags'] as Map?),
      isActive: json['is_active'] != false,
      description: (json['description'] ?? '').toString(),
    );
  }
}

/// The parent's current subscription state from `GET /api/subscriptions/my`.
class MySubscription {
  final bool hasSubscription;

  /// The active plan's id (`subscription.plan_id`). Preferred over the name for
  /// matching against the catalogue, since names can differ subtly.
  final String planId;

  /// The active plan's type (e.g. "enterprise"). A stable secondary key used to
  /// match the catalogue when no id is returned and the display names differ.
  final String planType;
  final String planName;
  final String status; // "trial" | "active" | ...
  final DateTime? expiryDate;
  final int daysRemaining;
  final bool inTrial;
  final int trialDaysRemaining;

  /// Feature flags of the *current* plan, so the UI can show what's still
  /// locked. Null when there is no active subscription.
  final PlanFeatures? currentFeatures;

  const MySubscription({
    required this.hasSubscription,
    required this.planId,
    required this.planType,
    required this.planName,
    required this.status,
    required this.expiryDate,
    required this.daysRemaining,
    required this.inTrial,
    required this.trialDaysRemaining,
    required this.currentFeatures,
  });

  /// The empty/no-subscription state.
  static const none = MySubscription(
    hasSubscription: false,
    planId: '',
    planType: '',
    planName: '',
    status: '',
    expiryDate: null,
    daysRemaining: 0,
    inTrial: false,
    trialDaysRemaining: 0,
    currentFeatures: null,
  );

  /// True once the parent is on a paid (non-trial) plan — nothing left to
  /// upsell, so the home upgrade card can step aside.
  bool get isPaid => hasSubscription && !inTrial && status != 'trial';

  factory MySubscription.fromJson(Map<String, dynamic> json) {
    final sub = json['subscription'];
    final plan = json['plan'];

    String planId = '';
    String planType = '';
    String planName = '';
    DateTime? expiry;
    String status = '';
    if (sub is Map) {
      planId = (sub['plan_id'] ?? '').toString();
      planType = (sub['plan_type'] ?? '').toString();
      planName = (sub['plan_name'] ?? '').toString();
      status = (sub['status'] ?? '').toString();
      expiry = _toDate(sub['expiry_date']);
    }
    if (planId.isEmpty && plan is Map) {
      planId = (plan['_id'] ?? plan['id'] ?? '').toString();
    }
    if (planType.isEmpty && plan is Map) {
      planType = (plan['type'] ?? '').toString();
    }
    if (planName.isEmpty && plan is Map) {
      planName = (plan['name'] ?? '').toString();
    }

    return MySubscription(
      hasSubscription: json['hasSubscription'] == true,
      planId: planId,
      planType: planType,
      planName: planName,
      status: status,
      expiryDate: expiry,
      daysRemaining: _toInt(json['daysRemaining']),
      inTrial: json['inTrial'] == true,
      trialDaysRemaining: _toInt(json['trialDaysRemaining']),
      currentFeatures: plan is Map
          ? PlanFeatures.fromJson(plan['feature_flags'] as Map?)
          : null,
    );
  }
}

/// Result of `POST /api/payments/initiate` — the Stripe Checkout session to
/// open in the WebView.
class CheckoutSession {
  final String sessionId;
  final String url;
  final String paymentId;

  const CheckoutSession({
    required this.sessionId,
    required this.url,
    required this.paymentId,
  });

  factory CheckoutSession.fromJson(Map<String, dynamic> json) {
    return CheckoutSession(
      sessionId: (json['sessionId'] ?? '').toString(),
      url: (json['url'] ?? '').toString(),
      paymentId: (json['paymentId'] ?? '').toString(),
    );
  }
}

double _toDouble(dynamic v) {
  if (v is num) return v.toDouble();
  return double.tryParse(v?.toString() ?? '') ?? 0;
}

int _toInt(dynamic v) {
  if (v is num) return v.toInt();
  return int.tryParse(v?.toString() ?? '') ?? 0;
}

DateTime? _toDate(dynamic v) {
  if (v == null) return null;
  return DateTime.tryParse(v.toString())?.toLocal();
}
