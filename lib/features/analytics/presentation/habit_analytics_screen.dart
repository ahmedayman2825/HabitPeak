import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/utils/duration_format.dart';
import '../../habits/domain/habit.dart';
import '../domain/analytics_summary.dart';

class HabitAnalyticsScreen extends ConsumerWidget {
  const HabitAnalyticsScreen({required this.habit, super.key});

  final Habit habit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(habitAnalyticsSummaryProvider(habit));
    return Scaffold(
      appBar: AppBar(title: Text(habit.name)),
      body: summaryAsync.when(
        data: (summary) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: <Widget>[
              if (summary.canRestore && summary.currentStreak == 0) ...<Widget>[
                _RestoreStreakCard(habit: habit, summary: summary),
                const SizedBox(height: 14),
              ],
              _HabitCompletionCard(summary: summary),
              const SizedBox(height: 10),
              _HabitMetricGrid(summary: summary, habit: habit),
              const SizedBox(height: 10),
              _HabitTrendCard(summary: summary),
              if (habit.type == HabitType.timer) ...<Widget>[
                const SizedBox(height: 10),
                _HabitTimeTrendCard(summary: summary),
              ],
            ],
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

class _RestoreStreakCard extends StatelessWidget {
  const _RestoreStreakCard({required this.habit, required this.summary});

  final Habit habit;
  final HabitAnalyticsSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      color: theme.colorScheme.errorContainer.withValues(alpha: 0.15),
      shape: RoundedRectangleBorder(
        side: BorderSide(color: theme.colorScheme.errorContainer, width: 1.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.errorContainer.withValues(alpha: 0.4),
                    shape: BoxShape.circle,
                  ),
                  child: const Text('🔥', style: TextStyle(fontSize: 22)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Streak Lost',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onErrorContainer,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'You missed your target. Restore it now to keep your streak!',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Consumer(
              builder: (context, ref, _) {
                return FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: theme.colorScheme.error,
                    foregroundColor: theme.colorScheme.onError,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () async {
                    final settings = ref.read(appSettingsControllerProvider).settings;
                    await ref
                        .read(habitRepositoryProvider)
                        .restoreStreak(habit.id, DateTime.now(), settings);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Streak restored successfully! 🔥'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.restore),
                  label: const Text(
                    'Restore Streak',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
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

class _HabitCompletionCard extends StatelessWidget {
  const _HabitCompletionCard({required this.summary});

  final HabitAnalyticsSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final remaining = (summary.scheduledCount - summary.completedCount).clamp(
      0,
      999999,
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: <Widget>[
            SizedBox.square(
              dimension: 112,
              child: PieChart(
                PieChartData(
                  centerSpaceRadius: 36,
                  sectionsSpace: 2,
                  sections: <PieChartSectionData>[
                    PieChartSectionData(
                      value: summary.completedCount == 0
                          ? 0.0
                          : summary.completedCount.toDouble(),
                      title: '',
                      radius: 15,
                      color: theme.colorScheme.primary,
                    ),
                    PieChartSectionData(
                      value: summary.scheduledCount == 0
                          ? 1.0
                          : remaining.toDouble(),
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
                  Text('Habit completion', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                    '${summary.completedCount} done',
                    style: theme.textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${summary.missedCount} missed of ${summary.scheduledCount} scheduled',
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
}

class _HabitMetricGrid extends StatelessWidget {
  const _HabitMetricGrid({required this.summary, required this.habit});

  final HabitAnalyticsSummary summary;
  final Habit habit;

  @override
  Widget build(BuildContext context) {
    final extraLabel = habit.type == HabitType.timer
        ? 'Tracked'
        : 'Total value';
    final extraValue = habit.type == HabitType.timer
        ? DurationFormat.compact(Duration(seconds: summary.totalTimerSeconds))
        : '${summary.totalNumberValue}';
    return GridView.count(
      crossAxisCount: MediaQuery.sizeOf(context).width > 680 ? 4 : 2,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 2.1,
      children: <Widget>[
        _MetricTile(
          label: 'Completion',
          value: '${(summary.completionPercent * 100).round()}%',
        ),
        _MetricTile(
          label: 'Current streak',
          value: summary.currentStreak > 0
              ? '${summary.currentStreak} 🔥'
              : '${summary.currentStreak}',
        ),
        _MetricTile(label: 'Skipped', value: '${summary.skippedCount}'),
        _MetricTile(label: extraLabel, value: extraValue),
        if (habit.type == HabitType.timer)
          _MetricTile(
            label: 'Longest session',
            value: DurationFormat.compact(
              Duration(seconds: summary.longestSessionSeconds),
            ),
          ),
      ],
    );
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

class _HabitTrendCard extends StatelessWidget {
  const _HabitTrendCard({required this.summary});

  final HabitAnalyticsSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Last 30 days', style: theme.textTheme.titleMedium),
            const SizedBox(height: 14),
            SizedBox(
              height: 160,
              child: BarChart(
                BarChartData(
                  maxY: 1,
                  borderData: FlBorderData(show: false),
                  gridData: const FlGridData(show: false),
                  titlesData: const FlTitlesData(
                    leftTitles: AxisTitles(),
                    topTitles: AxisTitles(),
                    rightTitles: AxisTitles(),
                    bottomTitles: AxisTitles(),
                  ),
                  barGroups: <BarChartGroupData>[
                    for (var i = 0; i < summary.completionTrends.length; i++)
                      BarChartGroupData(
                        x: i,
                        barRods: <BarChartRodData>[
                          BarChartRodData(
                            toY: summary.completionTrends[i].completed
                                .toDouble(),
                            width: 5,
                            borderRadius: BorderRadius.circular(3),
                            color: summary.completionTrends[i].scheduled == 0
                                ? theme.colorScheme.outlineVariant
                                : theme.colorScheme.primary,
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

class _HabitTimeTrendCard extends StatelessWidget {
  const _HabitTimeTrendCard({required this.summary});

  final HabitAnalyticsSummary summary;

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
            Text('Time trend', style: theme.textTheme.titleMedium),
            const SizedBox(height: 14),
            SizedBox(
              height: 160,
              child: LineChart(
                LineChartData(
                  minY: 0,
                  maxY: maxY,
                  borderData: FlBorderData(show: false),
                  gridData: const FlGridData(drawVerticalLine: false),
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
