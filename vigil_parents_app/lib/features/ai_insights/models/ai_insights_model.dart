/// Models for the AI daily-intelligence endpoint:
/// POST /api/ai/children/{childId}/analyze  body: {"date": "YYYY-MM-DD"}
///
/// Only the fields the UI actually renders are parsed; everything else in the
/// (large) response is ignored on purpose.
library;

int _toInt(dynamic v) => v is int ? v : (v is num ? v.toInt() : 0);

double _toDouble(dynamic v) => v is double ? v : (v is num ? v.toDouble() : 0);

String _toStr(dynamic v) => v is String ? v : '';

List<String> _toStrList(dynamic v) =>
    v is List ? v.map(_toStr).where((s) => s.isNotEmpty).toList() : const [];

/// Top-level envelope of the analyze call.
class AiAnalysisResponse {
  final bool analyzed;
  final String date;
  final int smsCount;
  final int callCount;
  final DailyIntelligence? intelligence;

  const AiAnalysisResponse({
    required this.analyzed,
    required this.date,
    required this.smsCount,
    required this.callCount,
    required this.intelligence,
  });

  factory AiAnalysisResponse.fromJson(Map<String, dynamic> json) {
    final result = json['result'];
    final di = result is Map<String, dynamic>
        ? result['daily_intelligence']
        : null;
    return AiAnalysisResponse(
      analyzed: json['analyzed'] == true,
      date: _toStr(json['date']),
      smsCount: _toInt(json['smsCount']),
      callCount: _toInt(json['callCount']),
      intelligence: di is Map<String, dynamic>
          ? DailyIntelligence.fromJson(di)
          : null,
    );
  }

  /// True when the backend ran but produced no usable intelligence payload.
  bool get hasIntelligence => intelligence != null;
}

class DailyIntelligence {
  final String executiveSummary;
  final String overallEmotionalState;
  final Map<String, double> emotionBreakdown;
  final SentimentBreakdown sentiment;
  final String overallSentiment;
  final int wellnessScore;
  final String wellnessBand;
  final int conversationCount;
  final int contactCount;
  final double socialDiversity;
  final List<ConversationInsight> conversations;
  final List<AiFinding> positiveFindings;
  final List<AiFinding> concerningFindings;
  final List<RelationshipInsight> relationships;
  final List<AiFinding> recommendations;
  final List<String> parentTakeaways;
  final List<String> topPriorities;
  final String longitudinalNarrative;
  final double overallConfidence;
  final String confidenceBand;
  final String llmOverallAssessment;
  final String dataSufficiencyNote;

  const DailyIntelligence({
    required this.executiveSummary,
    required this.overallEmotionalState,
    required this.emotionBreakdown,
    required this.sentiment,
    required this.overallSentiment,
    required this.wellnessScore,
    required this.wellnessBand,
    required this.conversationCount,
    required this.contactCount,
    required this.socialDiversity,
    required this.conversations,
    required this.positiveFindings,
    required this.concerningFindings,
    required this.relationships,
    required this.recommendations,
    required this.parentTakeaways,
    required this.topPriorities,
    required this.longitudinalNarrative,
    required this.overallConfidence,
    required this.confidenceBand,
    required this.llmOverallAssessment,
    required this.dataSufficiencyNote,
  });

  factory DailyIntelligence.fromJson(Map<String, dynamic> json) {
    final emotions = <String, double>{};
    final rawEmotions = json['emotion_breakdown'];
    if (rawEmotions is Map) {
      rawEmotions.forEach((k, v) => emotions['$k'] = _toDouble(v));
    }

    List<AiFinding> findings(dynamic v) => v is List
        ? v.whereType<Map<String, dynamic>>().map(AiFinding.fromJson).toList()
        : const [];

    final longitudinal = json['longitudinal'];
    final confidence = json['confidence_assessment'];

    return DailyIntelligence(
      executiveSummary: _toStr(json['executive_summary']),
      overallEmotionalState: _toStr(json['overall_emotional_state']),
      emotionBreakdown: emotions,
      sentiment: SentimentBreakdown.fromJson(
        json['sentiment_breakdown'] is Map<String, dynamic>
            ? json['sentiment_breakdown'] as Map<String, dynamic>
            : const {},
      ),
      overallSentiment: _toStr(json['overall_sentiment']),
      wellnessScore: _toInt(json['wellness_score']),
      wellnessBand: _toStr(json['wellness_band']),
      conversationCount: _toInt(json['conversation_count']),
      contactCount: _toInt(json['contact_count']),
      socialDiversity: _toDouble(json['social_diversity']),
      conversations: json['conversations'] is List
          ? (json['conversations'] as List)
                .whereType<Map<String, dynamic>>()
                .map(ConversationInsight.fromJson)
                .toList()
          : const [],
      positiveFindings: findings(json['positive_findings']),
      concerningFindings: findings(json['concerning_findings']),
      relationships: json['relationships'] is List
          ? (json['relationships'] as List)
                .whereType<Map<String, dynamic>>()
                .map(RelationshipInsight.fromJson)
                .toList()
          : const [],
      recommendations: findings(json['recommendations']),
      parentTakeaways: _toStrList(json['parent_takeaways']),
      topPriorities: _toStrList(json['top_priorities']),
      longitudinalNarrative: longitudinal is Map<String, dynamic>
          ? _toStr(longitudinal['narrative'])
          : '',
      overallConfidence: _toDouble(json['overall_confidence']),
      confidenceBand: confidence is Map<String, dynamic>
          ? _toStr(confidence['band'])
          : '',
      llmOverallAssessment: confidence is Map<String, dynamic>
          ? _toStr(confidence['llm_overall_assessment'])
          : '',
      dataSufficiencyNote: _toStr(json['data_sufficiency_note']),
    );
  }

  /// True when at least one emotion has a non-zero value (otherwise the
  /// emotion chart would just be an empty axis).
  bool get hasEmotionData => emotionBreakdown.values.any((v) => v > 0);
}

class SentimentBreakdown {
  final double positivity;
  final double negativity;
  final double volatility;
  final double trendScore;

  const SentimentBreakdown({
    required this.positivity,
    required this.negativity,
    required this.volatility,
    required this.trendScore,
  });

  factory SentimentBreakdown.fromJson(Map<String, dynamic> json) {
    return SentimentBreakdown(
      positivity: _toDouble(json['positivity']),
      negativity: _toDouble(json['negativity']),
      volatility: _toDouble(json['volatility']),
      trendScore: _toDouble(json['trend_score']),
    );
  }
}

/// One observation / finding / recommendation — they share a shape.
class AiFinding {
  final String category;
  final String displayLabel;
  final String statement;
  final double confidence;
  final String confidenceBand;
  final String reasoning;
  final String alternativeInterpretation;

  const AiFinding({
    required this.category,
    required this.displayLabel,
    required this.statement,
    required this.confidence,
    required this.confidenceBand,
    required this.reasoning,
    required this.alternativeInterpretation,
  });

  factory AiFinding.fromJson(Map<String, dynamic> json) {
    return AiFinding(
      category: _toStr(json['category']),
      displayLabel: _toStr(json['display_label']),
      statement: _toStr(json['statement']),
      confidence: _toDouble(json['confidence']),
      confidenceBand: _toStr(json['confidence_band']),
      reasoning: _toStr(json['reasoning']),
      alternativeInterpretation: _toStr(json['alternative_interpretation']),
    );
  }
}

class ConversationInsight {
  final String platform;
  final String relationshipRole;
  final int messageCount;
  final String priority;
  final List<String> priorityReasons;
  final String summary;
  final String startedAt;

  const ConversationInsight({
    required this.platform,
    required this.relationshipRole,
    required this.messageCount,
    required this.priority,
    required this.priorityReasons,
    required this.summary,
    required this.startedAt,
  });

  factory ConversationInsight.fromJson(Map<String, dynamic> json) {
    return ConversationInsight(
      platform: _toStr(json['platform']),
      relationshipRole: _toStr(json['relationship_role']),
      messageCount: _toInt(json['message_count']),
      priority: _toStr(json['priority']),
      priorityReasons: _toStrList(json['priority_reasons']),
      summary: _toStr(json['summary']),
      startedAt: _toStr(json['started_at']),
    );
  }

  bool get isImportant => priority.toLowerCase() != 'normal';
}

class RelationshipInsight {
  final String contactDisplay;
  final String roleDisplay;
  final double strength;
  final bool protective;
  final double trustScore;
  final double conflictScore;
  final int communicationFrequency;

  const RelationshipInsight({
    required this.contactDisplay,
    required this.roleDisplay,
    required this.strength,
    required this.protective,
    required this.trustScore,
    required this.conflictScore,
    required this.communicationFrequency,
  });

  factory RelationshipInsight.fromJson(Map<String, dynamic> json) {
    return RelationshipInsight(
      contactDisplay: _toStr(json['contact_display']),
      roleDisplay: _toStr(json['role_display']),
      strength: _toDouble(json['strength']),
      protective: json['protective'] == true,
      trustScore: _toDouble(json['trust_score']),
      conflictScore: _toDouble(json['conflict_score']),
      communicationFrequency: _toInt(json['communication_frequency']),
    );
  }
}
