import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../habits/domain/habit.dart';

class ArchivedHabitsScreen extends ConsumerStatefulWidget {
  const ArchivedHabitsScreen({super.key});

  @override
  ConsumerState<ArchivedHabitsScreen> createState() =>
      _ArchivedHabitsScreenState();
}

class _ArchivedHabitsScreenState extends ConsumerState<ArchivedHabitsScreen> {
  late Future<List<Habit>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Archived habits')),
      body: FutureBuilder<List<Habit>>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final habits = snapshot.data!;
          if (habits.isEmpty) {
            return const Center(child: Text('No archived habits.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            itemCount: habits.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final habit = habits[index];
              return Card(
                child: ListTile(
                  title: Text(habit.name),
                  subtitle: Text(habit.type.name),
                  trailing: FilledButton.tonalIcon(
                    onPressed: () => _restore(habit),
                    icon: const Icon(Icons.restore),
                    label: const Text('Restore'),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<List<Habit>> _load() async {
    final habits = await ref
        .read(habitRepositoryProvider)
        .getAllHabits(includeArchived: true);
    return habits.where((habit) => habit.isArchived).toList();
  }

  Future<void> _restore(Habit habit) async {
    await ref.read(habitRepositoryProvider).restoreHabit(habit.id);
    setState(() => _future = _load());
  }
}
