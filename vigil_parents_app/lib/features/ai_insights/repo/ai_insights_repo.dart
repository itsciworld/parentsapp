import 'package:flutter/foundation.dart';
import 'package:vigil_parents_app/features/ai_insights/models/ai_insights_model.dart';
import 'package:vigil_parents_app/network/api_intercptor.dart';

class AiInsightsRepository {
  AiInsightsRepository({ApiClient? client}) : _apiClient = client ?? ApiClient();

  final ApiClient _apiClient;

  /// The `YYYY-MM-DD` date format the AI endpoints expect.
  static String formatDate(DateTime date) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${date.year}-${two(date.month)}-${two(date.day)}';
  }

  /// POST /api/ai/children/{childId}/analyze — runs (or returns the cached)
  /// daily intelligence analysis for [date].
  Future<AiAnalysisResponse> analyze({
    required String childId,
    required String date,
  }) async {
    try {
      final response = await _apiClient.post(
        '/api/ai/children/$childId/analyze',
        data: {'date': date},
      );

      final data = response.data;
      if (data is Map<String, dynamic>) {
        return AiAnalysisResponse.fromJson(data);
      }
      throw Exception('Unexpected response from AI analysis');
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  /// GET /api/ai/children/{childId}/daily/{date}/report — the daily report
  /// as raw PDF bytes.
  Future<Uint8List> downloadDailyReport({
    required String childId,
    required String date,
  }) async {
    try {
      final response = await _apiClient.getBytes(
        '/api/ai/children/$childId/daily/$date/report',
      );

      final bytes = response.data;
      if (bytes == null || bytes.isEmpty) {
        throw Exception('The report is not available yet');
      }
      return Uint8List.fromList(bytes);
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }
}
