import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../analytics/presentation/habit_analytics_screen.dart';
import '../../habits/domain/habit.dart';
import '../../habits/domain/recurrence_rule.dart';
import '../../habits/presentation/habit_form_screen.dart';

class AllHabitsScreen extends ConsumerStatefulWidget {
  const AllHabitsScreen({super.key});

  @override
  ConsumerState<AllHabitsScreen> createState() => _AllHabitsScreenState();
}

class _AllHabitsScreenState extends ConsumerState<AllHabitsScreen> {
  late Future<List<Habit>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('All habits')),
      body: FutureBuilder<List<Habit>>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final habits = snapshot.data!;
          if (habits.isEmpty) {
            return const Center(child: Text('No habits yet.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            itemBuilder: (context, index) {
              final habit = habits[index];
              return Card(
                child: ListTile(
                  leading: Icon(_iconFor(habit.type)),
                  title: Text(
                    habit.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(_scheduleLabel(habit)),
                  trailing: PopupMenuButton<_HabitManagerAction>(
                    tooltip: 'Habit actions',
                    onSelected: (action) => _handleAction(habit, action),
                    itemBuilder: (context) =>
                        <PopupMenuEntry<_HabitManagerAction>>[
                          const PopupMenuItem(
                            value: _HabitManagerAction.analytics,
                            child: Text('Analytics'),
                          ),
                          const PopupMenuItem(
                            value: _HabitManagerAction.edit,
                            child: Text('Edit'),
                          ),
                          PopupMenuItem(
                            value: habit.isArchived
                                ? _HabitManagerAction.restore
                                : _HabitManagerAction.archive,
                            child: Text(
                              habit.isArchived ? 'Restore' : 'Archive',
                            ),
                          ),
                          const PopupMenuItem(
                            value: _HabitManagerAction.delete,
                            child: Text('Delete'),
                          ),
                        ],
                  ),
                  onTap: () => _openAnalytics(habit),
                ),
              );
            },
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemCount: habits.length,
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createHabit,
        icon: const Icon(Icons.add),
        label: const Text('Habit'),
      ),
    );
  }

  Future<List<Habit>> _load() async {
    return ref
        .read(habitRepositoryProvider)
        .getAllHabits(includeArchived: true);
  }

  Future<void> _createHabit() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const HabitFormScreen()),
    );
    _refresh();
  }

  Future<void> _editHabit(Habit habit) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => HabitFormScreen(existing: habit)),
    );
    _refresh();
  }

  Future<void> _openAnalytics(Habit habit) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => HabitAnalyticsScreen(habit: habit),
      ),
    );
    _refresh();
  }

  Future<void> _handleAction(Habit habit, _HabitManagerAction action) async {
    switch (action) {
      case _HabitManagerAction.analytics:
        await _openAnalytics(habit);
        break;
      case _HabitManagerAction.edit:
        await _editHabit(habit);
        break;
      case _HabitManagerAction.archive:
        await ref.read(habitRepositoryProvider).archiveHabit(habit.id);
        _refresh();
        break;
      case _HabitManagerAction.restore:
        await ref.read(habitRepositoryProvider).restoreHabit(habit.id);
        _refresh();
        break;
      case _HabitManagerAction.delete:
        await _deleteHabit(habit);
        break;
    }
  }

  Future<void> _deleteHabit(Habit habit) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete habit?'),
        content: Text('This removes "${habit.name}" and all local history.'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed ?? false) {
      await ref.read(habitRepositoryProvider).deleteHabit(habit.id);
      _refresh();
    }
  }

  void _refresh() {
    if (!mounted) {
      return;
    }
    setState(() => _future = _load());
  }

  IconData _iconFor(HabitType type) {
    switch (type) {
      case HabitType.checkbox:
        return Icons.check_circle_outline;
      case HabitType.number:
        return Icons.add_chart_outlined;
      case HabitType.timer:
        return Icons.timer_outlined;
    }
  }

  String _scheduleLabel(Habit habit) {
    final archive = habit.isArchived ? 'Archived - ' : '';
    final rule = habit.schedule;
    final dateRange = _dateRange(rule);
    final typeLabel = switch (rule.type) {
      RecurrenceType.daily => 'Daily',
      RecurrenceType.dailyBetweenDates => 'Daily between dates',
      RecurrenceType.oneTime => 'One-time',
      RecurrenceType.weekly => 'Weekly ${_weekdays(rule.selectedWeekdays)}',
      RecurrenceType.monthly => 'Monthly ${rule.monthDays.join(', ')}',
      RecurrenceType.custom =>
        'Every ${rule.intervalDays ?? 1} day${(rule.intervalDays ?? 1) == 1 ? '' : 's'}',
    };
    final exclusions = rule.excludedWeekdays.isEmpty
        ? ''
        : ' except ${_weekdays(rule.excludedWeekdays)}';
    return '$archive$typeLabel$exclusions$dateRange';
  }

  String _dateRange(RecurrenceRule rule) {
    final start = rule.startDate == null ? null : _shortDate(rule.startDate!);
    final end = rule.endDate == null ? null : _shortDate(rule.endDate!);
    if (start == null && end == null) {
      return '';
    }
    if (end == null) {
      return ' from $start';
    }
    if (start == null) {
      return ' until $end';
    }
    return ' from $start to $end';
  }

  String _shortDate(DateTime date) => '${date.month}/${date.day}/${date.year}';

  String _weekdays(List<int> weekdays) {
    if (weekdays.isEmpty) {
      return 'any day';
    }
    const names = <int, String>{
      1: 'Mon',
      2: 'Tue',
      3: 'Wed',
      4: 'Thu',
      5: 'Fri',
      6: 'Sat',
      7: 'Sun',
    };
    return weekdays.map((weekday) => names[weekday] ?? '$weekday').join(', ');
  }
}

enum _HabitManagerAction { analytics, edit, archive, restore, delete }
