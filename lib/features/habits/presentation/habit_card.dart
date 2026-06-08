import 'package:flutter/material.dart';

import '../../../core/utils/duration_format.dart';
import '../domain/habit.dart';
import '../domain/habit_with_entry.dart';

class HabitCard extends StatelessWidget {
  const HabitCard({
    required this.item,
    required this.onToggle,
    required this.onIncrement,
    required this.onDecrement,
    required this.onTimerPrimary,
    required this.onTimerStop,
    required this.onEdit,
    required this.onRename,
    required this.onArchive,
    required this.onDelete,
    required this.onOpenAnalysis,
    super.key,
  });

  final HabitWithEntry item;
  final VoidCallback onToggle;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final VoidCallback onTimerPrimary;
  final VoidCallback onTimerStop;
  final VoidCallback onEdit;
  final VoidCallback onRename;
  final VoidCallback onArchive;
  final VoidCallback onDelete;
  final VoidCallback onOpenAnalysis;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final percent = (item.progress * 100).round();
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpenAnalysis,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  _LeadingAction(item: item, onToggle: onToggle),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          item.habit.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: <Widget>[
                            Text(
                              'Streak ${item.streak}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(width: 4),
                            AnimatedFireEmoji(isComplete: item.isComplete),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (item.habit.type != HabitType.checkbox)
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Text(
                        '$percent%',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                  _HabitMenu(
                    onEdit: onEdit,
                    onRename: onRename,
                    onArchive: onArchive,
                    onDelete: onDelete,
                  ),
                ],
              ),
              if (item.habit.type != HabitType.checkbox) ...<Widget>[
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    minHeight: 6,
                    value: item.progress,
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  ),
                ),
                const SizedBox(height: 10),
                _ProgressControls(
                  item: item,
                  onIncrement: onIncrement,
                  onDecrement: onDecrement,
                  onTimerPrimary: onTimerPrimary,
                  onTimerStop: onTimerStop,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _LeadingAction extends StatelessWidget {
  const _LeadingAction({required this.item, required this.onToggle});

  final HabitWithEntry item;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    if (item.habit.type != HabitType.checkbox) {
      return Icon(
        item.habit.type == HabitType.timer
            ? Icons.timer_outlined
            : Icons.add_chart_outlined,
        color: Theme.of(context).colorScheme.primary,
      );
    }
    return Checkbox(
      value: item.isComplete,
      onChanged: (_) => onToggle(),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
    );
  }
}

class _ProgressControls extends StatelessWidget {
  const _ProgressControls({
    required this.item,
    required this.onIncrement,
    required this.onDecrement,
    required this.onTimerPrimary,
    required this.onTimerStop,
  });

  final HabitWithEntry item;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final VoidCallback onTimerPrimary;
  final VoidCallback onTimerStop;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (item.habit.type == HabitType.number) {
      return Row(
        children: <Widget>[
          IconButton.filledTonal(
            tooltip: 'Decrease',
            onPressed: onDecrement,
            icon: const Icon(Icons.remove),
          ),
          const SizedBox(width: 10),
          Text(
            '${item.value} / ${item.target}',
            style: theme.textTheme.titleSmall,
          ),
          const Spacer(),
          IconButton.filled(
            tooltip: 'Increase',
            onPressed: onIncrement,
            icon: const Icon(Icons.add),
          ),
        ],
      );
    }

    final running = item.timerIsRunning && !item.timerIsPaused;
    return Row(
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                '${DurationFormat.digital(Duration(seconds: item.value))} / '
                '${DurationFormat.compact(Duration(seconds: item.target))}',
                style: theme.textTheme.titleSmall,
              ),
              if (item.savedTimerSeconds > 0)
                Text(
                  'Today ${DurationFormat.compact(Duration(seconds: item.savedTimerSeconds))}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
        IconButton.filledTonal(
          tooltip: running ? 'Pause' : 'Start',
          onPressed: onTimerPrimary,
          icon: Icon(running ? Icons.pause : Icons.play_arrow),
        ),
        const SizedBox(width: 8),
        IconButton(
          tooltip: 'Stop',
          onPressed: item.timerIsRunning ? onTimerStop : null,
          icon: const Icon(Icons.stop),
        ),
      ],
    );
  }
}

class _HabitMenu extends StatelessWidget {
  const _HabitMenu({
    required this.onEdit,
    required this.onRename,
    required this.onArchive,
    required this.onDelete,
  });

  final VoidCallback onEdit;
  final VoidCallback onRename;
  final VoidCallback onArchive;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_HabitAction>(
      tooltip: 'Habit menu',
      onSelected: (action) {
        switch (action) {
          case _HabitAction.edit:
          case _HabitAction.schedule:
          case _HabitAction.target:
            onEdit();
            break;
          case _HabitAction.rename:
            onRename();
            break;
          case _HabitAction.archive:
            onArchive();
            break;
          case _HabitAction.delete:
            onDelete();
            break;
        }
      },
      itemBuilder: (context) => const <PopupMenuEntry<_HabitAction>>[
        PopupMenuItem(value: _HabitAction.edit, child: Text('Edit')),
        PopupMenuItem(value: _HabitAction.rename, child: Text('Rename')),
        PopupMenuItem(
          value: _HabitAction.schedule,
          child: Text('Change schedule'),
        ),
        PopupMenuItem(
          value: _HabitAction.target,
          child: Text('Change targets'),
        ),
        PopupMenuItem(value: _HabitAction.archive, child: Text('Archive')),
        PopupMenuItem(value: _HabitAction.delete, child: Text('Delete')),
      ],
    );
  }
}

enum _HabitAction { edit, rename, schedule, target, archive, delete }

class AnimatedFireEmoji extends StatefulWidget {
  const AnimatedFireEmoji({required this.isComplete, super.key});

  final bool isComplete;

  @override
  State<AnimatedFireEmoji> createState() => _AnimatedFireEmojiState();
}

class _AnimatedFireEmojiState extends State<AnimatedFireEmoji>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    if (widget.isComplete) {
      _controller.repeat(reverse: true);
    } else {
      _controller.value = 0.5;
    }
  }

  @override
  void didUpdateWidget(covariant AnimatedFireEmoji oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isComplete != oldWidget.isComplete) {
      if (widget.isComplete) {
        _controller.repeat(reverse: true);
      } else {
        _controller.stop();
        _controller.value = 0.5;
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const emoji = Text('🔥', style: TextStyle(fontSize: 14));
    if (widget.isComplete) {
      return ScaleTransition(
        scale: Tween<double>(begin: 0.85, end: 1.15).animate(
          CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
        ),
        child: emoji,
      );
    } else {
      return const ColorFiltered(
        colorFilter: ColorFilter.matrix(<double>[
          0.2126, 0.7152, 0.0722, 0, 0,
          0.2126, 0.7152, 0.0722, 0, 0,
          0.2126, 0.7152, 0.0722, 0, 0,
          0,      0,      0,      1, 0,
        ]),
        child: emoji,
      );
    }
  }
}
