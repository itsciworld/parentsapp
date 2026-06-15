import 'package:dio/dio.dart';
import 'package:vigil_parents_app/core/services/secure_storage/secure_storage.dart';
import 'package:vigil_parents_app/features/child/repo/child_repo.dart';
import 'package:vigil_parents_app/network/api_intercptor.dart';

import '../models/event_model.dart';

/// Identifiers needed to query events for a child.
class EventsContext {
  final String parentId;
  final String childId;
  const EventsContext({required this.parentId, required this.childId});

  bool get isValid => parentId.isNotEmpty && childId.isNotEmpty;
}

class EventsRepository {
  EventsRepository({ApiClient? client, ChildRepository? childRepository})
    : _apiClient = client ?? ApiClient(),
      _childRepository = childRepository ?? ChildRepository();

  final ApiClient _apiClient;
  final ChildRepository _childRepository;

  /// Resolves the parent + child ids from storage. If no child is selected
  /// yet, it fetches the children list, picks the first, and remembers it
  /// (id + device key) so the background service can run headless.
  Future<EventsContext> resolveContext() async {
    // No session → don't hit the API (avoids 401 spam from the background
    // isolate before the user has signed in).
    final token = await SecureDeviceService.getToken() ?? '';
    if (token.isEmpty) {
      return const EventsContext(parentId: '', childId: '');
    }

    final parentId = await SecureDeviceService.getParentId() ?? '';
    var childId = await SecureDeviceService.getSelectedChildId() ?? '';

    if (childId.isEmpty) {
      try {
        final children = await _childRepository.fetchChildren();
        if (children.isNotEmpty) {
          final first = children.first;
          childId = first.id;
          await SecureDeviceService.saveSelectedChildId(first.id);
          await SecureDeviceService.saveSelectedChildDeviceKey(first.deviceKey);
        }
      } catch (_) {
        // Leave childId empty; caller handles the invalid context.
      }
    }

    return EventsContext(parentId: parentId, childId: childId);
  }

  /// GET /api/events/get_events — paginated. `x-device-key` (selected child's
  /// device key) is attached automatically by ApiInterceptor.
  Future<EventsResponse> getEvents({
    required String childId,
    required String parentId,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final response = await _apiClient.get(
        '/api/events/get_events',
        query: {
          'child_id': childId,
          'parent_id': parentId,
          'page': page,
          'limit': limit,
        },
      );

      final data = response.data;
      if (data is Map<String, dynamic>) {
        return EventsResponse.fromJson(data);
      }
      return const EventsResponse(
        status: 200,
        total: 0,
        page: 1,
        limit: 20,
        pages: 0,
        events: [],
      );
    } on DioException catch (e) {
      throw Exception(e.error.toString());
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  /// Pulls every page of events for a child and returns the merged list.
  ///
  /// The endpoint is paginated, but the calendar + list need the full picture,
  /// so we walk the pages sequentially. [maxPages] caps the walk so an unusually
  /// large dataset can never spin forever — adjust if you need a higher ceiling.
  Future<List<EventModel>> fetchAllEvents({
    required String childId,
    required String parentId,
    int pageSize = 200,
    int maxPages = 40,
  }) async {
    final all = <EventModel>[];

    final first = await getEvents(
      childId: childId,
      parentId: parentId,
      page: 1,
      limit: pageSize,
    );
    all.addAll(first.events);

    final totalPages = first.pages > 0 ? first.pages : 1;
    final lastPage = totalPages > maxPages ? maxPages : totalPages;

    for (var page = 2; page <= lastPage; page++) {
      final res = await getEvents(
        childId: childId,
        parentId: parentId,
        page: page,
        limit: pageSize,
      );
      if (res.events.isEmpty) break;
      all.addAll(res.events);
    }

    return all;
  }
}
