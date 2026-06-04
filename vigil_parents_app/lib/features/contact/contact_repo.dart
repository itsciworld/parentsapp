import 'package:dio/dio.dart';
import 'package:vigil_parents_app/core/services/secure_storage/secure_storage.dart';
import 'package:vigil_parents_app/features/child/repo/child_repo.dart';
import 'package:vigil_parents_app/features/contact/models/contacts_model.dart';
import 'package:vigil_parents_app/network/api_intercptor.dart';

/// Identifiers needed to query contacts for a child.
class ContactsContext {
  final String parentId;
  final String childId;
  const ContactsContext({required this.parentId, required this.childId});

  bool get isValid => parentId.isNotEmpty && childId.isNotEmpty;
}

class ContactsRepository {
  ContactsRepository({ApiClient? client, ChildRepository? childRepository})
    : _apiClient = client ?? ApiClient(),
      _childRepository = childRepository ?? ChildRepository();

  final ApiClient _apiClient;
  final ChildRepository _childRepository;

  /// Resolves the parent + child ids from storage. If no child is selected
  /// yet, it fetches the children list, picks the first, and remembers it
  /// (id + device key) so the background service can run headless.
  /// Always refreshes the device key to ensure it's current.
  Future<ContactsContext> resolveContext() async {
    // No session → don't hit the API (avoids 401 spam from the background
    // isolate before the user has signed in).
    final token = await SecureDeviceService.getToken() ?? '';
    if (token.isEmpty) {
      return const ContactsContext(parentId: '', childId: '');
    }

    final parentId = await SecureDeviceService.getParentId() ?? '';
    var childId = await SecureDeviceService.getSelectedChildId() ?? '';

    // Always fetch children to ensure device keys are fresh. If a child is
    // already selected, we verify its device key matches what's on the backend.
    try {
      final children = await _childRepository.fetchChildren();
      if (children.isEmpty) {
        return ContactsContext(parentId: parentId, childId: '');
      }

      // If a child is selected, find it and update its device key.
      if (childId.isNotEmpty) {
        final selected = children.where((c) => c.id == childId).firstOrNull;
        if (selected != null) {
          await SecureDeviceService.saveSelectedChildDeviceKey(
            selected.deviceKey,
          );
        } else {
          // Selected child no longer exists, fall back to first child.
          final first = children.first;
          childId = first.id;
          await SecureDeviceService.saveSelectedChildId(first.id);
          await SecureDeviceService.saveSelectedChildDeviceKey(first.deviceKey);
        }
      } else {
        // No child selected, pick the first one.
        final first = children.first;
        childId = first.id;
        await SecureDeviceService.saveSelectedChildId(first.id);
        await SecureDeviceService.saveSelectedChildDeviceKey(first.deviceKey);
      }
    } catch (_) {
      // If fetch fails, proceed with whatever is stored (might be stale).
      // Caller handles invalid context if childId is empty.
    }

    return ContactsContext(parentId: parentId, childId: childId);
  }

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
