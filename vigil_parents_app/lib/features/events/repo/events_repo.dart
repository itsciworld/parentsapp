import 'package:dio/dio.dart';
import 'package:vigil_parents_app/core/services/child_context/child_context_resolver.dart';
import 'package:vigil_parents_app/network/api_intercptor.dart';

import '../models/event_model.dart';

/// Identifiers needed to query events for a child.
typedef EventsContext = ChildContext;

class EventsRepository {
  EventsRepository({ApiClient? client}) : _apiClient = client ?? ApiClient();

  final ApiClient _apiClient;

  /// See [ChildContextResolver.resolve] — shared across features and
  /// cached, so polling callers no longer re-fetch the children list.
  Future<EventsContext> resolveContext() => ChildContextResolver.resolve();

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
