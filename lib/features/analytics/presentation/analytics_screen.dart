import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/utils/duration_format.dart';
import '../../ai/domain/habit_suggestion.dart';
import '../domain/analytics_summary.dart';

class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen> {
  AnalyticsWindow _window = AnalyticsWindow.daily;

  @override
  Widget build(BuildContext context) {
    final summaryAsync = ref.watch(analyticsSummaryProvider(_window));
    return Scaffold(
      appBar: AppBar(title: const Text('Analytics')),
      body: summaryAsync.when(
        data: (summary) {
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(analyticsSummaryProvider(_window)),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              children: <Widget>[
                SegmentedButton<AnalyticsWindow>(
                  segments: const <ButtonSegment<AnalyticsWindow>>[
                    ButtonSegment(
                      value: AnalyticsWindow.daily,
                      label: Text('Day'),
                    ),
                    ButtonSegment(
                      value: AnalyticsWindow.weekly,
                      label: Text('Week'),
                    ),
                    ButtonSegment(
                      value: AnalyticsWindow.monthly,
                      label: Text('Month'),
                    ),
                  ],
                  selected: <AnalyticsWindow>{_window},
                  onSelectionChanged: (value) {
                    setState(() => _window = value.first);
                  },
                ),
                const SizedBox(height: 14),
                _CompletionCard(summary: summary),
                const SizedBox(height: 10),
                _ScoreGrid(summary: summary),
                if (summary.window != AnalyticsWindow.daily) ...<Widget>[
                  const SizedBox(height: 10),
                  _TrendCard(summary: summary),
                ],
                const SizedBox(height: 10),
                _TimeCard(summary: summary),
                const SizedBox(height: 10),
                _InsightCard(
                  summary: summary,
                  suggestions: ref
                          .watch(appSettingsControllerProvider)
                          .settings
                          .smartNotificationsEnabled
                      ? ref
                            .read(localInsightServiceProvider)
                            .suggestions(summary)
                      : const <HabitSuggestion>[],
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(
          child: Text('Error loading analytics: $err'),
        ),
      ),
    );
  }
}

class _CompletionCard extends StatelessWidget {
  const _CompletionCard({required this.summary});

  final AnalyticsSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final completed = summary.completedCount;
    final remaining = (summary.scheduledCount - completed).clamp(0, 9999);
    final chartCompleted = summary.scheduledCount == 0
        ? 0.0
        : completed.toDouble();
    final chartRemaining = summary.scheduledCount == 0
        ? 1.0
        : remaining.toDouble();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: <Widget>[
            SizedBox.square(
              dimension: 118,
              child: PieChart(
                PieChartData(
                  centerSpaceRadius: 38,
                  sectionsSpace: 2,
                  sections: <PieChartSectionData>[
                    PieChartSectionData(
                      value: chartCompleted,
                      title: '',
                      radius: 15,
                      color: theme.colorScheme.primary,
                    ),
                    PieChartSectionData(
                      value: chartRemaining,
                      title: '',
                      radius: 15,
                      color: theme.colorScheme.surfaceContainerHighest,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    '${_windowLabel(summary.window)} completion',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$completed of ${summary.scheduledCount} habits',
                    style: theme.textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${(summary.completionPercent * 100).round()}% complete',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _windowLabel(AnalyticsWindow window) {
    return switch (window) {
      AnalyticsWindow.daily => 'Daily',
      AnalyticsWindow.weekly => 'Weekly',
      AnalyticsWindow.monthly => 'Monthly',
    };
  }
}

class _ScoreGrid extends StatelessWidget {
  const _ScoreGrid({required this.summary});

  final AnalyticsSummary summary;

  @override
  Widget build(BuildContext context) {
    final scoreTiles = <Widget>[
      _MetricTile(
        label: _scoreLabel(summary.window),
        value: '${summary.dailyScore}',
      ),
      if (summary.window == AnalyticsWindow.weekly)
        _MetricTile(label: 'Weekly score', value: '${summary.weeklyScore}'),
      _MetricTile(label: 'Productivity', value: '${summary.productivityScore}'),
      _MetricTile(label: 'Life balance', value: '${summary.lifeBalanceScore}'),
    ];
    return GridView.count(
      crossAxisCount: MediaQuery.sizeOf(context).width > 680 ? 4 : 2,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 2.1,
      children: scoreTiles,
    );
  }

  String _scoreLabel(AnalyticsWindow window) {
    return switch (window) {
      AnalyticsWindow.daily => 'Daily score',
      AnalyticsWindow.weekly => 'Selected score',
      AnalyticsWindow.monthly => 'Monthly score',
    };
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Text(value, style: theme.textTheme.titleLarge),
          ],
        ),
      ),
    );
  }
}

class _TrendCard extends StatelessWidget {
  const _TrendCard({required this.summary});

  final AnalyticsSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxY = summary.completionTrends
        .fold<int>(
          1,
          (max, item) => item.completed > max ? item.completed : max,
        )
        .toDouble();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Daily trend', style: theme.textTheme.titleMedium),
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, constraints) {
                final desiredWidth = summary.window == AnalyticsWindow.monthly
                    ? summary.completionTrends.length * 38.0
                    : constraints.maxWidth;
                final chartWidth = desiredWidth < constraints.maxWidth
                    ? constraints.maxWidth
                    : desiredWidth;
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: chartWidth,
                    height: 180,
                    child: BarChart(
                      BarChartData(
                        maxY: maxY,
                        borderData: FlBorderData(show: false),
                        gridData: const FlGridData(show: false),
                        titlesData: FlTitlesData(
                          leftTitles: const AxisTitles(),
                          topTitles: const AxisTitles(),
                          rightTitles: const AxisTitles(),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (value, meta) {
                                final index = value.toInt();
                                if (index < 0 ||
                                    index >= summary.completionTrends.length) {
                                  return const SizedBox.shrink();
                                }
                                final day = summary.completionTrends[index].day;
                                return Text('${day.month}/${day.day}');
                              },
                            ),
                          ),
                        ),
                        barGroups: <BarChartGroupData>[
                          for (
                            var i = 0;
                            i < summary.completionTrends.length;
                            i++
                          )
                            BarChartGroupData(
                              x: i,
                              barRods: <BarChartRodData>[
                                BarChartRodData(
                                  toY: summary.completionTrends[i].completed
                                      .toDouble(),
                                  color: theme.colorScheme.primary,
                                  borderRadius: BorderRadius.circular(4),
                                  width: 16,
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _TimeCard extends StatelessWidget {
  const _TimeCard({required this.summary});

  final AnalyticsSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxY = summary.timeTrends
        .fold<int>(1, (max, item) => item.seconds > max ? item.seconds : max)
        .toDouble();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Tracked time', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'Selected ${DurationFormat.compact(Duration(seconds: summary.trackedSeconds))}  '
              'Week ${DurationFormat.compact(Duration(seconds: summary.weeklyTrackedSeconds))}  '
              'Month ${DurationFormat.compact(Duration(seconds: summary.monthlyTrackedSeconds))}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 180,
              child: LineChart(
                LineChartData(
                  minY: 0,
                  maxY: maxY,
                  borderData: FlBorderData(show: false),
                  gridData: FlGridData(
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (_) => FlLine(
                      color: theme.colorScheme.outlineVariant,
                      strokeWidth: 1,
                    ),
                  ),
                  titlesData: const FlTitlesData(
                    leftTitles: AxisTitles(),
                    topTitles: AxisTitles(),
                    rightTitles: AxisTitles(),
                    bottomTitles: AxisTitles(),
                  ),
                  lineBarsData: <LineChartBarData>[
                    LineChartBarData(
                      isCurved: true,
                      color: theme.colorScheme.secondary,
                      dotData: const FlDotData(show: false),
                      spots: <FlSpot>[
                        for (var i = 0; i < summary.timeTrends.length; i++)
                          FlSpot(
                            i.toDouble(),
                            summary.timeTrends[i].seconds.toDouble(),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InsightCard extends StatelessWidget {
  const _InsightCard({required this.summary, required this.suggestions});

  final AnalyticsSummary summary;
  final List<HabitSuggestion> suggestions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final weak = summary.weakestHabits.isEmpty
        ? 'No weak patterns yet'
        : summary.weakestHabits.join(', ');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Patterns', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            _InsightRow(
              label: 'Best streak',
              value: summary.bestStreak > 0
                  ? '${summary.bestStreak} 🔥'
                  : '${summary.bestStreak}',
            ),
            _InsightRow(
              label: 'Longest session',
              value: DurationFormat.compact(
                Duration(seconds: summary.longestSessionSeconds),
              ),
            ),
            _InsightRow(label: 'Weakest habits', value: weak),
            _InsightRow(
              label: 'Most skipped day',
              value: summary.mostSkippedDay,
            ),
            for (final suggestion in suggestions) ...<Widget>[
              const Divider(height: 20),
              _SuggestionView(suggestion: suggestion),
            ],
          ],
        ),
      ),
    );
  }
}

class _SuggestionView extends StatelessWidget {
  const _SuggestionView({required this.suggestion});

  final HabitSuggestion suggestion;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          suggestion.title,
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 3),
        Text(suggestion.body, style: theme.textTheme.bodyMedium),
      ],
    );
  }
}

class _InsightRow extends StatelessWidget {
  const _InsightRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
