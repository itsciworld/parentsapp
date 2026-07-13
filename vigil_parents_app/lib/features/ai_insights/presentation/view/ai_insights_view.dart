import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';
import 'package:vigil_parents_app/components/app_header.dart';
import 'package:vigil_parents_app/core/appColor/app_color.dart';
import 'package:vigil_parents_app/features/ai_insights/models/ai_insights_model.dart';
import 'package:vigil_parents_app/features/ai_insights/presentation/view/ai_report_view.dart';
import 'package:vigil_parents_app/features/ai_insights/presentation/view_model/ai_insights_viewmodel.dart';
import 'package:vigil_parents_app/features/child/presentation/view_model/selected_child_viewmodel.dart';
import 'package:vigil_parents_app/features/child/presentation/widgets/child_selector_dropdown.dart';
import 'package:vigil_parents_app/features/child/presentation/widgets/no_child_linked_view.dart';

/// AI Insights tab: runs the daily-intelligence analysis for the selected
/// child on open (no background service) and renders the result — wellness
/// gauge, emotion chart, findings, recommendations and the downloadable PDF
/// report. Header matches the other screens (VIGIL logo + child selector).
class AiInsightsView extends ConsumerStatefulWidget {
  const AiInsightsView({super.key});

  @override
  ConsumerState<AiInsightsView> createState() => _AiInsightsViewState();
}

class _AiInsightsViewState extends ConsumerState<AiInsightsView> {
  void _onChildSelected(String childId) {
    ref.read(aiInsightsViewModelProvider).load(childId);
  }

  @override
  Widget build(BuildContext context) {
    final vm = ref.watch(aiInsightsViewModelProvider);
    final selectedChild = ref.watch(selectedChildProvider);

    return Scaffold(
      backgroundColor: AppColors.scaffold,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // VIGIL logo header (same as SMS / App Usage views).
            const AppHeader(showBack: false),
            _TitleBar(
              date: vm.date,
              onChildSelected: _onChildSelected,
              onReportTap: vm.intelligence == null ? null : _openReport,
            ),
            Expanded(
              child: RefreshIndicator(
                color: AppColors.primary,
                onRefresh: () =>
                    ref.read(aiInsightsViewModelProvider).refresh(),
                child: _buildContent(vm, selectedChild),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openReport() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AiReportView()),
    );
  }

  Widget _buildContent(
    AiInsightsViewModel vm,
    SelectedChildViewModel selectedChild,
  ) {
    // No child linked at all → same call-to-action as the Home screen.
    if (selectedChild.initialized && selectedChild.children.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          NoChildLinkedView(
            refreshing: selectedChild.loading,
            onRefresh: () =>
                ref.read(selectedChildProvider).load(force: true),
          ),
        ],
      );
    }

    if (vm.loading && vm.data == null) return const _ShimmerView();

    if (vm.error != null && vm.data == null) {
      return _MessageView(
        icon: Icons.cloud_off_rounded,
        iconColor: AppColors.alert,
        title: 'Unable to load AI insights',
        message: vm.error!,
        actionLabel: 'Try Again',
        onAction: () => vm.refresh(showLoader: true),
      );
    }

    final data = vm.data;
    if (data == null) {
      // Tab opened before a child was resolved — nothing loaded yet.
      return const _ShimmerView();
    }

    final intel = data.intelligence;
    if (!data.analyzed || intel == null) {
      return _MessageView(
        icon: Icons.hourglass_top_rounded,
        iconColor: AppColors.warning,
        title: 'Analysis not ready yet',
        message:
            'Today\'s AI analysis for this child isn\'t available yet. '
            'It appears once enough activity has been collected '
            '(${data.smsCount} SMS · ${data.callCount} calls so far).',
        actionLabel: 'Check Again',
        onAction: () => vm.refresh(showLoader: true),
      );
    }

    return _LoadedView(data: data, intel: intel, onReportTap: _openReport);
  }
}

/// ----------------------------------------------------------------------------
/// Title bar — "AI Insights" + child selector (mirrors the App Usage screen).
/// ----------------------------------------------------------------------------
class _TitleBar extends StatelessWidget {
  final String date;
  final ValueChanged<String> onChildSelected;
  final VoidCallback? onReportTap;

  const _TitleBar({
    required this.date,
    required this.onChildSelected,
    required this.onReportTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 2, 14, 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'AI Insights',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Daily intelligence · ${_friendlyDate(date)}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (onReportTap != null) ...[
            IconButton(
              onPressed: onReportTap,
              tooltip: 'Daily report (PDF)',
              icon: const Icon(
                Icons.picture_as_pdf_rounded,
                color: AppColors.alert,
              ),
            ),
            const SizedBox(width: 2),
          ],
          // Bounded, or the dropdown's full-width shimmer placeholder gets
          // infinite width inside this Row and blows up layout.
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 170),
            child: ChildSelectorDropdown(onChanged: onChildSelected),
          ),
        ],
      ),
    );
  }
}

String _friendlyDate(String yyyyMmDd) {
  final parts = yyyyMmDd.split('-');
  if (parts.length != 3) return yyyyMmDd;
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  final month = int.tryParse(parts[1]);
  final day = int.tryParse(parts[2]);
  if (month == null || day == null || month < 1 || month > 12) return yyyyMmDd;
  return '$day ${months[month - 1]} ${parts[0]}';
}

/// ----------------------------------------------------------------------------
/// Loaded content
/// ----------------------------------------------------------------------------
class _LoadedView extends StatelessWidget {
  final AiAnalysisResponse data;
  final DailyIntelligence intel;
  final VoidCallback onReportTap;

  const _LoadedView({
    required this.data,
    required this.intel,
    required this.onReportTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      children: [
        _WellnessCard(intel: intel),
        const SizedBox(height: 14),
        _StatsRow(data: data, intel: intel),
        const SizedBox(height: 14),
        _SummaryCard(intel: intel),
        if (intel.hasEmotionData) ...[
          const SizedBox(height: 14),
          _EmotionChartCard(emotions: intel.emotionBreakdown),
        ],
        if (intel.parentTakeaways.isNotEmpty) ...[
          const SizedBox(height: 14),
          _BulletCard(
            title: 'Key Takeaways',
            icon: Icons.lightbulb_outline_rounded,
            iconColor: AppColors.blueIcon,
            items: intel.parentTakeaways,
          ),
        ],
        if (intel.concerningFindings.isNotEmpty) ...[
          const SizedBox(height: 14),
          _FindingsCard(
            title: 'Needs Attention',
            icon: Icons.error_outline_rounded,
            color: AppColors.warning,
            findings: intel.concerningFindings,
          ),
        ],
        if (intel.positiveFindings.isNotEmpty) ...[
          const SizedBox(height: 14),
          _FindingsCard(
            title: 'Positive Signals',
            icon: Icons.thumb_up_alt_outlined,
            color: AppColors.primary,
            findings: intel.positiveFindings,
          ),
        ],
        if (intel.recommendations.isNotEmpty) ...[
          const SizedBox(height: 14),
          _FindingsCard(
            title: 'Recommendations',
            icon: Icons.tips_and_updates_outlined,
            color: AppColors.indigoIcon,
            findings: intel.recommendations,
          ),
        ],
        if (intel.topPriorities.isNotEmpty) ...[
          const SizedBox(height: 14),
          _BulletCard(
            title: 'Top Priorities',
            icon: Icons.flag_outlined,
            iconColor: AppColors.purpleIcon,
            items: intel.topPriorities,
          ),
        ],
        if (intel.conversations.isNotEmpty) ...[
          const SizedBox(height: 14),
          _ConversationsCard(conversations: intel.conversations),
        ],
        if (intel.relationships.isNotEmpty) ...[
          const SizedBox(height: 14),
          _RelationshipsCard(relationships: intel.relationships),
        ],
        if (intel.longitudinalNarrative.isNotEmpty) ...[
          const SizedBox(height: 14),
          _NoteCard(
            icon: Icons.timeline_rounded,
            text: intel.longitudinalNarrative,
          ),
        ],
        const SizedBox(height: 20),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          onPressed: onReportTap,
          icon: const Icon(Icons.picture_as_pdf_rounded, size: 20),
          label: const Text(
            'View Daily Report (PDF)',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          ),
        ),
      ],
    );
  }
}

/// ----------------------------------------------------------------------------
/// Wellness gauge — headline number of the day.
/// ----------------------------------------------------------------------------
class _WellnessCard extends StatelessWidget {
  final DailyIntelligence intel;

  const _WellnessCard({required this.intel});

  Color get _bandColor {
    switch (intel.wellnessBand.toLowerCase()) {
      case 'good':
      case 'excellent':
        return AppColors.primary;
      case 'fair':
      case 'moderate':
        return AppColors.warning;
      default:
        return intel.wellnessScore >= 70
            ? AppColors.primary
            : AppColors.alert;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _bandColor;
    final score = intel.wellnessScore.clamp(0, 100);

    return _Card(
      child: Row(
        children: [
          // Radial gauge with the score in the middle.
          SizedBox(
            width: 120,
            height: 120,
            child: Stack(
              alignment: Alignment.center,
              children: [
                PieChart(
                  PieChartData(
                    startDegreeOffset: 270,
                    sectionsSpace: 0,
                    centerSpaceRadius: 44,
                    sections: [
                      PieChartSectionData(
                        value: score.toDouble(),
                        color: color,
                        radius: 12,
                        showTitle: false,
                      ),
                      PieChartSectionData(
                        value: (100 - score).toDouble(),
                        color: AppColors.cardBorder,
                        radius: 12,
                        showTitle: false,
                      ),
                    ],
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$score',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary,
                        height: 1,
                      ),
                    ),
                    const Text(
                      '/ 100',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Wellness Score',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _Chip(
                      label: intel.wellnessBand.isEmpty
                          ? '—'
                          : _capitalize(intel.wellnessBand),
                      color: color,
                    ),
                    if (intel.overallEmotionalState.isNotEmpty)
                      _Chip(
                        label:
                            'Mood: ${_capitalize(intel.overallEmotionalState)}',
                        color: AppColors.blueIcon,
                      ),
                    if (intel.confidenceBand.isNotEmpty)
                      _Chip(
                        label:
                            '${_capitalize(intel.confidenceBand)} confidence',
                        color: AppColors.textSecondary,
                      ),
                  ],
                ),
                if (intel.llmOverallAssessment.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    intel.llmOverallAssessment,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// ----------------------------------------------------------------------------
/// Small stat tiles: conversations / contacts / SMS / calls.
/// ----------------------------------------------------------------------------
class _StatsRow extends StatelessWidget {
  final AiAnalysisResponse data;
  final DailyIntelligence intel;

  const _StatsRow({required this.data, required this.intel});

  @override
  Widget build(BuildContext context) {
    final stats = [
      (Icons.forum_outlined, '${intel.conversationCount}', 'Chats'),
      (Icons.group_outlined, '${intel.contactCount}', 'Contacts'),
      (Icons.sms_outlined, '${data.smsCount}', 'SMS'),
      (Icons.call_outlined, '${data.callCount}', 'Calls'),
    ];

    return Row(
      children: [
        for (var i = 0; i < stats.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: Column(
                children: [
                  Icon(stats[i].$1, size: 18, color: AppColors.blueIcon),
                  const SizedBox(height: 6),
                  Text(
                    stats[i].$2,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    stats[i].$3,
                    style: const TextStyle(
                      fontSize: 10.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// ----------------------------------------------------------------------------
/// Executive summary + data-sufficiency note.
/// ----------------------------------------------------------------------------
class _SummaryCard extends StatelessWidget {
  final DailyIntelligence intel;

  const _SummaryCard({required this.intel});

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CardTitle(
            icon: Icons.auto_awesome_rounded,
            iconColor: AppColors.indigoIcon,
            title: 'Today\'s Summary',
          ),
          const SizedBox(height: 10),
          Text(
            intel.executiveSummary.isEmpty
                ? 'No summary available for today.'
                : intel.executiveSummary,
            style: const TextStyle(
              fontSize: 13.5,
              color: AppColors.textPrimary,
              height: 1.5,
            ),
          ),
          if (intel.dataSufficiencyNote.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.blueSoft,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    size: 15,
                    color: AppColors.blueIcon,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      intel.dataSufficiencyNote,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// ----------------------------------------------------------------------------
/// Emotion breakdown bar chart (single hue — magnitude, not identity).
/// ----------------------------------------------------------------------------
class _EmotionChartCard extends StatelessWidget {
  final Map<String, double> emotions;

  const _EmotionChartCard({required this.emotions});

  static const _order = [
    'joy', 'neutral', 'surprise', 'sadness', 'fear', 'anger', 'disgust',
  ];
  static const _labels = {
    'joy': 'Joy',
    'neutral': 'Neutral',
    'surprise': 'Surprise',
    'sadness': 'Sad',
    'fear': 'Fear',
    'anger': 'Anger',
    'disgust': 'Disgust',
  };

  @override
  Widget build(BuildContext context) {
    final keys = _order.where(emotions.containsKey).toList()
      ..addAll(emotions.keys.where((k) => !_order.contains(k)));
    final maxValue = emotions.values.fold<double>(0, (m, v) => v > m ? v : m);

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CardTitle(
            icon: Icons.mood_rounded,
            iconColor: AppColors.blueIcon,
            title: 'Emotion Breakdown',
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 160,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxValue <= 0 ? 1 : maxValue * 1.2,
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipItem: (group, _, rod, _) => BarTooltipItem(
                      rod.toY.toStringAsFixed(1),
                      const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(),
                  rightTitles: const AxisTitles(),
                  topTitles: const AxisTitles(),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 24,
                      getTitlesWidget: (value, meta) {
                        final i = value.toInt();
                        if (i < 0 || i >= keys.length) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            _labels[keys[i]] ?? _capitalize(keys[i]),
                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                barGroups: [
                  for (var i = 0; i < keys.length; i++)
                    BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: emotions[keys[i]] ?? 0,
                          width: 14,
                          color: AppColors.blueIcon,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(4),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// ----------------------------------------------------------------------------
/// Generic bullet-list card (takeaways / priorities).
/// ----------------------------------------------------------------------------
class _BulletCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color iconColor;
  final List<String> items;

  const _BulletCard({
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardTitle(icon: icon, iconColor: iconColor, title: title),
          const SizedBox(height: 10),
          for (var i = 0; i < items.length; i++)
            Padding(
              padding:
                  EdgeInsets.only(bottom: i == items.length - 1 ? 0 : 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    margin: const EdgeInsets.only(top: 6),
                    decoration: BoxDecoration(
                      color: iconColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      items[i],
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textPrimary,
                        height: 1.45,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// ----------------------------------------------------------------------------
/// Findings / recommendations card.
/// ----------------------------------------------------------------------------
class _FindingsCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final List<AiFinding> findings;

  const _FindingsCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.findings,
  });

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardTitle(icon: icon, iconColor: color, title: title),
          const SizedBox(height: 10),
          for (var i = 0; i < findings.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            _FindingTile(finding: findings[i], color: color),
          ],
        ],
      ),
    );
  }
}

class _FindingTile extends StatelessWidget {
  final AiFinding finding;
  final Color color;

  const _FindingTile({required this.finding, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  finding.displayLabel.isEmpty
                      ? _capitalize(finding.category.replaceAll('_', ' '))
                      : finding.displayLabel,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              if (finding.confidenceBand.isNotEmpty)
                _Chip(
                  label: '${_capitalize(finding.confidenceBand)} confidence',
                  color: AppColors.textSecondary,
                ),
            ],
          ),
          if (finding.statement.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              finding.statement,
              style: const TextStyle(
                fontSize: 12.5,
                color: AppColors.textPrimary,
                height: 1.45,
              ),
            ),
          ],
          if (finding.alternativeInterpretation.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              finding.alternativeInterpretation,
              style: const TextStyle(
                fontSize: 11.5,
                fontStyle: FontStyle.italic,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// ----------------------------------------------------------------------------
/// Conversations list.
/// ----------------------------------------------------------------------------
class _ConversationsCard extends StatelessWidget {
  final List<ConversationInsight> conversations;

  const _ConversationsCard({required this.conversations});

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardTitle(
            icon: Icons.forum_outlined,
            iconColor: AppColors.purpleIcon,
            title: 'Conversations (${conversations.length})',
          ),
          const SizedBox(height: 6),
          for (var i = 0; i < conversations.length; i++) ...[
            if (i > 0) const Divider(height: 18, color: AppColors.cardBorder),
            _ConversationTile(conversation: conversations[i]),
          ],
        ],
      ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  final ConversationInsight conversation;

  const _ConversationTile({required this.conversation});

  @override
  Widget build(BuildContext context) {
    final isCall = conversation.platform == 'call_log';
    final important = conversation.isImportant;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: isCall ? AppColors.greenSoft : AppColors.blueSoft,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            isCall ? Icons.call_outlined : Icons.chat_bubble_outline_rounded,
            size: 17,
            color: isCall ? AppColors.greenIcon : AppColors.blueIcon,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                conversation.summary,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: AppColors.textPrimary,
                  height: 1.4,
                ),
              ),
              if (important && conversation.priorityReasons.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  conversation.priorityReasons.join(' · '),
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.warning,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (important) ...[
          const SizedBox(width: 8),
          _Chip(
            label: _capitalize(conversation.priority),
            color: AppColors.warning,
          ),
        ],
      ],
    );
  }
}

/// ----------------------------------------------------------------------------
/// Relationships list with a strength meter.
/// ----------------------------------------------------------------------------
class _RelationshipsCard extends StatelessWidget {
  final List<RelationshipInsight> relationships;

  const _RelationshipsCard({required this.relationships});

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardTitle(
            icon: Icons.diversity_1_outlined,
            iconColor: AppColors.orangeIcon,
            title: 'Relationships (${relationships.length})',
          ),
          const SizedBox(height: 10),
          for (var i = 0; i < relationships.length; i++) ...[
            if (i > 0) const SizedBox(height: 12),
            _RelationshipTile(relationship: relationships[i]),
          ],
        ],
      ),
    );
  }
}

class _RelationshipTile extends StatelessWidget {
  final RelationshipInsight relationship;

  const _RelationshipTile({required this.relationship});

  @override
  Widget build(BuildContext context) {
    final r = relationship;
    final strength = r.strength.clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                r.contactDisplay.isEmpty ? 'Unknown' : r.contactDisplay,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            _Chip(
              label: r.roleDisplay.isEmpty ? 'Unknown' : r.roleDisplay,
              color: r.protective ? AppColors.primary : AppColors.textSecondary,
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: strength,
                  minHeight: 6,
                  backgroundColor: AppColors.cardBorder,
                  color: AppColors.blueIcon,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              '${r.communicationFrequency} interaction'
              '${r.communicationFrequency == 1 ? '' : 's'}',
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// ----------------------------------------------------------------------------
/// Shared bits
/// ----------------------------------------------------------------------------
class _Card extends StatelessWidget {
  final Widget child;

  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _CardTitle extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;

  const _CardTitle({
    required this.icon,
    required this.iconColor,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(icon, size: 17, color: iconColor),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;

  const _Chip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _NoteCard extends StatelessWidget {
  final IconData icon;
  final String text;

  const _NoteCard({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.indigoSoft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppColors.indigoIcon),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _capitalize(String s) =>
    s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

/// ----------------------------------------------------------------------------
/// Shimmer loading placeholder — mirrors the loaded layout.
/// ----------------------------------------------------------------------------
class _ShimmerView extends StatelessWidget {
  const _ShimmerView();

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          _box(height: 148, radius: 16),
          const SizedBox(height: 14),
          Row(
            children: [
              for (var i = 0; i < 4; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(child: _box(height: 78, radius: 14)),
              ],
            ],
          ),
          const SizedBox(height: 14),
          _box(height: 120, radius: 16),
          const SizedBox(height: 14),
          _box(height: 200, radius: 16),
          const SizedBox(height: 14),
          _box(height: 140, radius: 16),
        ],
      ),
    );
  }

  Widget _box({required double height, required double radius}) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

/// ----------------------------------------------------------------------------
/// Error / not-ready states (scrollable so pull-to-refresh keeps working).
/// ----------------------------------------------------------------------------
class _MessageView extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  const _MessageView({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.12),
        Icon(icon, size: 56, color: iconColor),
        const SizedBox(height: 14),
        Center(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 36),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.45,
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),
        Center(
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            onPressed: onAction,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: Text(actionLabel),
          ),
        ),
      ],
    );
  }
}
