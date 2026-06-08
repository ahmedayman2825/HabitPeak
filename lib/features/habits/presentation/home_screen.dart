import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/utils/duration_format.dart';
import '../../../core/utils/habit_clock.dart';
import '../../analytics/presentation/habit_analytics_screen.dart';
import '../domain/habit.dart';
import '../domain/habit_with_entry.dart';
import 'habit_card.dart';
import 'habit_form_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  List<HabitWithEntry> _items = const <HabitWithEntry>[];
  bool _loading = true;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_items.any((item) => item.timerIsRunning && !item.timerIsPaused)) {
        _load(showSpinner: false);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Today'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Create habit',
            onPressed: _createHabit,
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _load(showSpinner: false),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _items.isEmpty
            ? _EmptyToday(onCreate: _createHabit)
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                itemBuilder: (context, index) {
                  final item = _items[index];
                  return HabitCard(
                    item: item,
                    onToggle: () => _toggleCheckbox(item),
                    onIncrement: () => _adjustNumber(item, 1),
                    onDecrement: () => _adjustNumber(item, -1),
                    onTimerPrimary: () => _toggleTimer(item),
                    onTimerStop: () => _stopTimer(item),
                    onEdit: () => _editHabit(item.habit),
                    onRename: () => _renameHabit(item.habit),
                    onArchive: () => _archiveHabit(item.habit),
                    onDelete: () => _deleteHabit(item.habit),
                    onOpenAnalysis: () => _openHabitAnalysis(item.habit),
                  );
                },
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 10),
                itemCount: _items.length,
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createHabit,
        icon: const Icon(Icons.add),
        label: const Text('Habit'),
      ),
    );
  }

  Future<void> _load({bool showSpinner = true}) async {
    if (showSpinner && mounted) {
      setState(() => _loading = true);
    }
    final settings = ref.read(appSettingsControllerProvider).settings;
    await ref.read(timerEngineProvider).reconcileActiveSessions(settings);
    final items = await ref
        .read(habitRepositoryProvider)
        .getTodayHabits(DateTime.now(), settings);
    await ref
        .read(habitWidgetServiceProvider)
        .updateTodayWidget(items, settings);
    final completed = items.where((item) => item.isComplete).length;
    final missed = items.length - completed;
    final todayKey = HabitClock.dayKey(DateTime.now(), resetMinutes: settings.resetMinutes);
    final resetTime = HabitClock.resetBoundaryAfterDay(todayKey, settings.resetMinutes);
    await ref.read(notificationServiceProvider).scheduleResetSummary(
      completed: completed,
      missed: missed,
      resetTime: resetTime,
    );

    if (!mounted) {
      return;
    }
    setState(() {
      _items = items;
      _loading = false;
    });
  }

  Future<void> _createHabit() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const HabitFormScreen()),
    );
    await _load();
  }

  Future<void> _editHabit(Habit habit) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => HabitFormScreen(existing: habit)),
    );
    await _load();
  }

  Future<void> _openHabitAnalysis(Habit habit) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => HabitAnalyticsScreen(habit: habit),
      ),
    );
    await _load(showSpinner: false);
  }

  Future<void> _renameHabit(Habit habit) async {
    final controller = TextEditingController(text: habit.name);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename habit'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Name'),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.isEmpty) {
      return;
    }
    await ref
        .read(habitRepositoryProvider)
        .saveHabit(habit.copyWith(name: name, updatedAt: DateTime.now()));
    await _load();
  }

  Future<void> _toggleCheckbox(HabitWithEntry item) async {
    final day = _todayKey();
    await ref.read(habitRepositoryProvider).toggleCheckbox(item.habit, day);
    await _load(showSpinner: false);
  }



  Future<void> _adjustNumber(HabitWithEntry item, int delta) async {
    await ref
        .read(habitRepositoryProvider)
        .adjustNumber(item.habit, _todayKey(), delta);
    await _load(showSpinner: false);
  }

  Future<void> _toggleTimer(HabitWithEntry item) async {
    final settings = ref.read(appSettingsControllerProvider).settings;
    final engine = ref.read(timerEngineProvider);
    final session = await ref
        .read(habitRepositoryProvider)
        .getActiveTimerSession(item.habit.id);
    if (session == null) {
      await engine.start(item.habit, settings);
    } else if (session.isPaused) {
      await engine.resume(session, settings);
    } else {
      await engine.pause(session);
    }
    await _load(showSpinner: false);
  }

  Future<void> _stopTimer(HabitWithEntry item) async {
    final session = await ref
        .read(habitRepositoryProvider)
        .getActiveTimerSession(item.habit.id);
    if (session == null) {
      return;
    }
    final stopped = await ref.read(timerEngineProvider).stopAndReset(session);
    await _load(showSpinner: false);
    final saveToDay = await _confirmTimerStop(stopped.elapsedSeconds);
    if (saveToDay ?? false) {
      await ref
          .read(timerEngineProvider)
          .saveStoppedTimeToDay(stopped.stoppedSession, stopped.elapsedSeconds);
      await _load(showSpinner: false);
    }
  }

  Future<bool?> _confirmTimerStop(int seconds) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Stop timer?'),
        content: Text(
          'Save ${DurationFormat.compact(Duration(seconds: seconds))} to today, or discard this session and reset it?',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Yes'),
          ),
        ],
      ),
    );
  }

  Future<void> _archiveHabit(Habit habit) async {
    await ref.read(habitRepositoryProvider).archiveHabit(habit.id);
    await _load();
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
      await _load();
    }
  }

  String _todayKey() {
    final settings = ref.read(appSettingsControllerProvider).settings;
    return HabitClock.dayKey(
      DateTime.now(),
      resetMinutes: settings.resetMinutes,
    );
  }
}

class _EmptyToday extends StatelessWidget {
  const _EmptyToday({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(32),
      children: <Widget>[
        const SizedBox(height: 80),
        Icon(
          Icons.check_circle_outline,
          size: 56,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(height: 18),
        Text(
          'No habits scheduled today',
          textAlign: TextAlign.center,
          style: theme.textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Text(
          'Create a simple habit and keep the day focused.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 24),
        Center(
          child: FilledButton.icon(
            onPressed: onCreate,
            icon: const Icon(Icons.add),
            label: const Text('Create habit'),
          ),
        ),
      ],
    );
  }
}
