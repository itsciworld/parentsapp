import 'package:dio/dio.dart';
import 'package:vigil_parents_app/core/services/child_context/child_context_resolver.dart';
import 'package:vigil_parents_app/features/contact/models/contacts_model.dart';
import 'package:vigil_parents_app/network/api_intercptor.dart';

/// Identifiers needed to query contacts for a child.
typedef ContactsContext = ChildContext;

class ContactsRepository {
  ContactsRepository({ApiClient? client}) : _apiClient = client ?? ApiClient();

  final ApiClient _apiClient;

  /// See [ChildContextResolver.resolve] — shared across features and
  /// cached, so polling callers no longer re-fetch the children list.
  Future<ContactsContext> resolveContext() => ChildContextResolver.resolve();

  /// GET /api/contacts/get_contacts — paginated. `x-device-key` (selected
  /// child's device key) is attached automatically by ApiInterceptor.
  Future<ContactsResponse> getContacts({
    required String childId,
    required String parentId,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final response = await _apiClient.get(
        '/api/contacts/get_contacts',
        query: {
          'child_id': childId,
          'parent_id': parentId,
          'page': page,
          'limit': limit,
        },
      );

      final data = response.data;
      if (data is Map<String, dynamic>) {
        return ContactsResponse.fromJson(data);
      }
      return const ContactsResponse(
        status: 200,
        total: 0,
        page: 1,
        limit: 20,
        pages: 0,
        contacts: [],
      );
    } on DioException catch (e) {
      throw Exception(e.error.toString());
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }
}
