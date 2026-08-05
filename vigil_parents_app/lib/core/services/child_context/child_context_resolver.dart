import 'package:vigil_parents_app/core/services/secure_storage/secure_storage.dart';
import 'package:vigil_parents_app/features/child/models/child_model.dart';
import 'package:vigil_parents_app/features/child/repo/child_repo.dart';

/// The identifiers every child-scoped endpoint needs: which parent is asking,
/// and about which child.
class ChildContext {
  final String parentId;
  final String childId;

  /// True when a parent session exists, whether or not a child has been linked
  /// yet. [isValid] can't answer this on its own: it needs *both* ids, so a
  /// signed-in parent with nothing linked looks identical to a signed-out one.
  /// Callers that report status to the user need to tell those two apart.
  final bool hasSession;

  const ChildContext({
    required this.parentId,
    required this.childId,
    this.hasSession = false,
  });

  /// Signed out — no parent, no child.
  static const empty = ChildContext(parentId: '', childId: '');

  bool get isValid => parentId.isNotEmpty && childId.isNotEmpty;
}

/// Resolves (and caches) the parent + child ids that every feature repository
/// needs before it can call a child-scoped endpoint.
///
/// This used to live as a near-identical `resolveContext()` in seven
/// repositories, four of which re-fetched the whole children list on *every*
/// call. Because the SMS and gallery screens poll every 5–10 seconds, that
/// turned each poll tick into two requests — a `/api/children` round trip just
/// to re-confirm a device key that changes at most once per session.
///
/// The list is now fetched at most once per [_ttl], and is invalidated
/// immediately whenever the selection actually changes (child switch,
/// pull-to-refresh, sign-out), so nothing observable goes stale.
///
/// State is static and therefore per-isolate: the background service gets its
/// own cache, which is what we want — it runs headless and can't see the UI
/// isolate's selection changes anyway.
class ChildContextResolver {
  ChildContextResolver._();

  /// How long a resolved context stays usable before the children list is
  /// re-fetched. Only guards against server-side changes (a child linked from
  /// another device); local changes invalidate explicitly.
  static const Duration _ttl = Duration(minutes: 5);

  static ChildContext? _cached;
  static DateTime? _cachedAt;
  static Future<ChildContext>? _inFlight;

  static bool get _isFresh {
    final at = _cachedAt;
    return at != null && DateTime.now().difference(at) < _ttl;
  }

  /// Resolves the current context, reusing the cached one when it is still
  /// fresh. Concurrent callers share a single in-flight resolution.
  static Future<ChildContext> resolve({bool forceRefresh = false}) async {
    // No session → nothing to resolve, and no API call (this is what keeps the
    // background isolate from spraying 401s before the user has signed in).
    // Never cached: it's a cheap local read, and caching it would leave the app
    // blind for [_ttl] immediately after sign-in.
    final token = await SecureDeviceService.getToken() ?? '';
    if (token.isEmpty) {
      invalidate();
      return ChildContext.empty;
    }

    if (!forceRefresh && _cached != null && _isFresh) return _cached!;

    return _inFlight ??= _resolve().whenComplete(() => _inFlight = null);
  }

  /// Drops the cache. Call when the selection may have changed underneath us —
  /// sign-out, or a child added/removed.
  static void invalidate() {
    _cached = null;
    _cachedAt = null;
  }

  /// Seeds the cache from a selection the caller has *already* resolved (the
  /// child screens fetch the list themselves), so the next repository call
  /// doesn't repeat the `/api/children` round trip.
  static Future<void> prime({required String childId}) async {
    if (childId.isEmpty) {
      invalidate();
      return;
    }
    final parentId = await SecureDeviceService.getParentId() ?? '';
    _store(
      ChildContext(parentId: parentId, childId: childId, hasSession: true),
    );
  }

  static Future<ChildContext> _resolve() async {
    final parentId = await SecureDeviceService.getParentId() ?? '';
    final storedChildId = await SecureDeviceService.getSelectedChildId() ?? '';

    final List<ChildModel> children;
    try {
      children = await ChildRepository().fetchChildren();
    } catch (_) {
      // Network hiccup: fall back to whatever is stored rather than blanking
      // the UI. Deliberately not cached, so the next call retries.
      return ChildContext(
        parentId: parentId,
        childId: storedChildId,
        hasSession: true,
      );
    }

    // Signed in with nothing linked yet. Cached like any other result — a
    // parent mid-setup would otherwise re-fetch the list on every poll tick.
    if (children.isEmpty) {
      return _store(
        ChildContext(parentId: parentId, childId: '', hasSession: true),
      );
    }

    // Prefer the stored selection; fall back to the first child when it is
    // unset or points at a child that no longer exists.
    ChildModel? selected;
    for (final child in children) {
      if (child.id == storedChildId) {
        selected = child;
        break;
      }
    }
    final child = selected ?? children.first;

    // Re-persist both, so `x-device-key` stays correct even if the backend
    // rotated it or we just fell back to a different child.
    await SecureDeviceService.saveSelectedChildId(child.id);
    await SecureDeviceService.saveSelectedChildDeviceKey(child.deviceKey);

    return _store(
      ChildContext(parentId: parentId, childId: child.id, hasSession: true),
    );
  }

  static ChildContext _store(ChildContext ctx) {
    _cached = ctx;
    _cachedAt = DateTime.now();
    return ctx;
  }
}
