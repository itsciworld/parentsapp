import 'package:flutter_riverpod/legacy.dart';

/// Bottom-nav tab indexes, shared so screens can recognise their own tab.
class ShellTabs {
  const ShellTabs._();

  static const int home = 0;
  static const int child = 1;
  static const int aiInsights = 2;
  static const int profile = 3;
}

/// Index of the tab currently on screen.
///
/// The shell keeps every visited tab alive inside an `IndexedStack`, so a page
/// that is switched away from is never disposed and its `initState` never runs
/// again. Screens listen to this to notice they have become visible again and
/// re-fetch their data, instead of showing stale content until the user pulls
/// to refresh.
final visibleTabProvider = StateProvider<int>((ref) => ShellTabs.home);
