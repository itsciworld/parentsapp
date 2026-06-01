import 'package:dio/dio.dart';
import 'package:vigil_parents_app/features/child/models/child_model.dart';
import 'package:vigil_parents_app/network/api_intercptor.dart';

class ChildRepository {
  ChildRepository({ApiClient? client}) : _apiClient = client ?? ApiClient();

  final ApiClient _apiClient;

  Future<List<ChildModel>> fetchChildren() async {
    try {
      final response = await _apiClient.get('/api/children');
      final data = response.data;

      if (data is List) {
        return data
            .whereType<Map<String, dynamic>>()
            .map(ChildModel.fromJson)
            .toList();
      }

      if (data is Map<String, dynamic> && data['children'] is List) {
        return (data['children'] as List)
            .whereType<Map<String, dynamic>>()
            .map(ChildModel.fromJson)
            .toList();
      }

      return const [];
    } on DioException catch (e) {
      throw Exception(e.error.toString());
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<ChildModel> updateChildName(String childId, String name) async {
    try {
      final response = await _apiClient.put(
        '/api/children/$childId/update-name',
        data: {'name': name},
      );
      final data = response.data;

      // API returns the updated child object (optionally wrapped).
      if (data is Map<String, dynamic> && data['child'] is Map) {
        return ChildModel.fromJson(
          Map<String, dynamic>.from(data['child'] as Map),
        );
      }
      if (data is Map<String, dynamic>) {
        return ChildModel.fromJson(data);
      }

      throw Exception('Invalid update response');
    } on DioException catch (e) {
      throw Exception(e.error.toString());
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<String> deleteChild(String childId) async {
    try {
      final response = await _apiClient.delete('/api/children/$childId');
      final data = response.data;
      if (data is Map && data['msg'] != null) {
        return data['msg'].toString();
      }
      return 'Child deleted successfully';
    } on DioException catch (e) {
      throw Exception(e.error.toString());
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }
}
