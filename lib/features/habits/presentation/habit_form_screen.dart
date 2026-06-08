import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../app/providers.dart';
import '../domain/habit.dart';
import '../domain/recurrence_rule.dart';

class HabitFormScreen extends ConsumerStatefulWidget {
  const HabitFormScreen({super.key, this.existing});

  final Habit? existing;

  @override
  ConsumerState<HabitFormScreen> createState() => _HabitFormScreenState();
}

class _HabitFormScreenState extends ConsumerState<HabitFormScreen> {
  final _nameController = TextEditingController();
  final _numberTargetController = TextEditingController(text: '8');
  final _timerTargetController = TextEditingController(text: '60');
  final _intervalDaysController = TextEditingController(text: '3');
  final _uuid = const Uuid();

  HabitType _type = HabitType.checkbox;
  RecurrenceType _recurrence = RecurrenceType.daily;
  DateTime? _startDate;
  DateTime? _endDate;
  Set<int> _selectedWeekdays = <int>{DateTime.monday};
  Set<int> _excludedWeekdays = <int>{};
  Set<int> _monthDays = <int>{DateTime.now().day};
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing != null) {
      _nameController.text = existing.name;
      _type = existing.type;
      _recurrence = existing.schedule.type;
      _startDate = existing.schedule.startDate;
      _endDate = existing.schedule.endDate;
      _selectedWeekdays = existing.schedule.selectedWeekdays.toSet();
      _excludedWeekdays = existing.schedule.excludedWeekdays.toSet();
      _monthDays = existing.schedule.monthDays.toSet();
      _numberTargetController.text = (existing.numberTarget ?? 8).toString();
      _timerTargetController.text =
          ((existing.timerTargetSeconds ?? 3600) ~/ 60).toString();
      _intervalDaysController.text = (existing.schedule.intervalDays ?? 3)
          .toString();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _numberTargetController.dispose();
    _timerTargetController.dispose();
    _intervalDaysController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existing != null;
    return Scaffold(
      appBar: AppBar(title: Text(isEditing ? 'Edit habit' : 'New habit')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 112),
        children: <Widget>[
          TextField(
            controller: _nameController,
            autofocus: !isEditing,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Habit name',
              hintText: 'Read 20 pages',
            ),
          ),
          const SizedBox(height: 18),
          Text('Type', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          SegmentedButton<HabitType>(
            segments: const <ButtonSegment<HabitType>>[
              ButtonSegment(
                value: HabitType.checkbox,
                icon: Icon(Icons.check),
                label: Text('Check'),
              ),
              ButtonSegment(
                value: HabitType.number,
                icon: Icon(Icons.add),
                label: Text('Number'),
              ),
              ButtonSegment(
                value: HabitType.timer,
                icon: Icon(Icons.timer_outlined),
                label: Text('Timer'),
              ),
            ],
            selected: <HabitType>{_type},
            onSelectionChanged: (value) => setState(() => _type = value.first),
          ),
          const SizedBox(height: 18),
          if (_type == HabitType.number)
            TextField(
              controller: _numberTargetController,
              keyboardType: TextInputType.number,
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.digitsOnly,
              ],
              decoration: const InputDecoration(labelText: 'Daily target'),
            ),
          if (_type == HabitType.timer)
            TextField(
              controller: _timerTargetController,
              keyboardType: TextInputType.number,
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.digitsOnly,
              ],
              decoration: const InputDecoration(
                labelText: 'Target minutes',
                hintText: '120',
              ),
            ),
          const SizedBox(height: 18),
          Text('Schedule', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          DropdownButtonFormField<RecurrenceType>(
            initialValue: _recurrence,
            decoration: const InputDecoration(labelText: 'Recurrence'),
            items: const <DropdownMenuItem<RecurrenceType>>[
              DropdownMenuItem(
                value: RecurrenceType.daily,
                child: Text('Daily'),
              ),
              DropdownMenuItem(
                value: RecurrenceType.dailyBetweenDates,
                child: Text('Daily between dates'),
              ),
              DropdownMenuItem(
                value: RecurrenceType.oneTime,
                child: Text('One-time'),
              ),
              DropdownMenuItem(
                value: RecurrenceType.weekly,
                child: Text('Weekly'),
              ),
              DropdownMenuItem(
                value: RecurrenceType.monthly,
                child: Text('Monthly'),
              ),
              DropdownMenuItem(
                value: RecurrenceType.custom,
                child: Text('Custom'),
              ),
            ],
            onChanged: (value) => setState(() => _recurrence = value!),
          ),
          const SizedBox(height: 12),
          if (_usesDates)
            _DateFields(
              recurrence: _recurrence,
              startDate: _startDate,
              endDate: _endDate,
              onPickStart: () async => _pickDate(isStart: true),
              onPickEnd: () async => _pickDate(isStart: false),
              onClearEnd: () => setState(() => _endDate = null),
            ),
          if (_recurrence == RecurrenceType.custom) ...<Widget>[
            const SizedBox(height: 14),
            TextField(
              controller: _intervalDaysController,
              keyboardType: TextInputType.number,
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.digitsOnly,
              ],
              decoration: const InputDecoration(
                labelText: 'Repeat every',
                suffixText: 'days',
                hintText: '3',
              ),
            ),
          ],
          if (_recurrence == RecurrenceType.weekly ||
              _recurrence == RecurrenceType.custom) ...<Widget>[
            const SizedBox(height: 14),
            _WeekdayPicker(
              title: 'Selected weekdays',
              values: _selectedWeekdays,
              onChanged: (values) => setState(() => _selectedWeekdays = values),
            ),
          ],
          if (_recurrence == RecurrenceType.daily ||
              _recurrence == RecurrenceType.dailyBetweenDates ||
              _recurrence == RecurrenceType.custom) ...<Widget>[
            const SizedBox(height: 14),
            _WeekdayPicker(
              title: 'Excluded weekdays',
              values: _excludedWeekdays,
              onChanged: (values) => setState(() => _excludedWeekdays = values),
            ),
          ],
          if (_recurrence == RecurrenceType.monthly ||
              _recurrence == RecurrenceType.custom) ...<Widget>[
            const SizedBox(height: 14),
            _MonthDayPicker(
              values: _monthDays,
              onChanged: (values) => setState(() => _monthDays = values),
            ),
          ],
        ],
      ),
      bottomSheet: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check),
              label: Text(isEditing ? 'Save changes' : 'Create habit'),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickDate({required bool isStart}) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDate ?? now : _endDate ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 10),
    );
    if (picked == null) {
      return;
    }
    setState(() {
      if (isStart) {
        _startDate = picked;
      } else {
        _endDate = picked;
      }
    });
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Add a habit name.')));
      return;
    }
    if (!_validateSchedule()) {
      return;
    }
    setState(() => _saving = true);
    final now = DateTime.now();
    final existing = widget.existing;
    final habit = Habit(
      id: existing?.id ?? _uuid.v7(),
      name: name,
      type: _type,
      schedule: _buildSchedule(),
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
      archivedAt: existing?.archivedAt,
      colorHex: existing?.colorHex ?? '#4F8A8B',
      sortOrder: existing?.sortOrder ?? 0,
      numberTarget: _type == HabitType.number
          ? int.tryParse(_numberTargetController.text).clampMinimum(1)
          : null,
      timerTargetSeconds: _type == HabitType.timer
          ? int.tryParse(_timerTargetController.text).clampMinimum(1) * 60
          : null,
    );
    await ref.read(habitRepositoryProvider).saveHabit(habit);
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop();
  }

  RecurrenceRule _buildSchedule() {
    final today = DateTime.now();
    return RecurrenceRule(
      type: _recurrence,
      startDate:
          _startDate ??
          (_recurrence == RecurrenceType.oneTime ||
                  _recurrence == RecurrenceType.dailyBetweenDates ||
                  _recurrence == RecurrenceType.custom
              ? DateTime(today.year, today.month, today.day)
              : null),
      endDate: _endDate,
      selectedWeekdays: _selectedWeekdays.toList()..sort(),
      excludedWeekdays: _excludedWeekdays.toList()..sort(),
      monthDays: _monthDays.toList()..sort(),
      intervalDays: _recurrence == RecurrenceType.custom
          ? int.tryParse(_intervalDaysController.text).clampMinimum(1)
          : null,
    );
  }

  bool get _usesDates {
    return _recurrence == RecurrenceType.dailyBetweenDates ||
        _recurrence == RecurrenceType.oneTime ||
        _recurrence == RecurrenceType.custom;
  }

  bool _validateSchedule() {
    if (_recurrence == RecurrenceType.dailyBetweenDates &&
        (_startDate == null || _endDate == null)) {
      _showScheduleError('Choose a start date and end date.');
      return false;
    }
    if (_recurrence == RecurrenceType.oneTime && _startDate == null) {
      _showScheduleError('Choose the date for this one-time habit.');
      return false;
    }
    if (_recurrence == RecurrenceType.custom &&
        int.tryParse(_intervalDaysController.text).clampMinimum(1) < 1) {
      _showScheduleError('Repeat interval must be at least 1 day.');
      return false;
    }
    if (_startDate != null &&
        _endDate != null &&
        _endDate!.isBefore(_startDate!)) {
      _showScheduleError('End date must be after the start date.');
      return false;
    }
    return true;
  }

  void _showScheduleError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _DateFields extends StatelessWidget {
  const _DateFields({
    required this.recurrence,
    required this.startDate,
    required this.endDate,
    required this.onPickStart,
    required this.onPickEnd,
    required this.onClearEnd,
  });

  final RecurrenceType recurrence;
  final DateTime? startDate;
  final DateTime? endDate;
  final VoidCallback onPickStart;
  final VoidCallback onPickEnd;
  final VoidCallback onClearEnd;

  @override
  Widget build(BuildContext context) {
    final showEnd = recurrence != RecurrenceType.oneTime;
    return Column(
      children: <Widget>[
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.event),
          title: Text(
            recurrence == RecurrenceType.oneTime ? 'Habit date' : 'Start date',
          ),
          subtitle: Text(_label(startDate)),
          trailing: const Icon(Icons.chevron_right),
          onTap: onPickStart,
        ),
        if (showEnd)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.event_busy),
            title: const Text('End date'),
            subtitle: Text(_label(endDate, empty: 'No end date')),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (endDate != null)
                  IconButton(
                    tooltip: 'Clear end date',
                    onPressed: onClearEnd,
                    icon: const Icon(Icons.close),
                  ),
                const Icon(Icons.chevron_right),
              ],
            ),
            onTap: onPickEnd,
          ),
      ],
    );
  }

  String _label(DateTime? date, {String empty = 'Choose date'}) {
    if (date == null) {
      return empty;
    }
    return '${date.month}/${date.day}/${date.year}';
  }
}

class _WeekdayPicker extends StatelessWidget {
  const _WeekdayPicker({
    required this.title,
    required this.values,
    required this.onChanged,
  });

  static const List<String> labels = <String>[
    'M',
    'T',
    'W',
    'T',
    'F',
    'S',
    'S',
  ];

  final String title;
  final Set<int> values;
  final ValueChanged<Set<int>> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(title, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: List<Widget>.generate(7, (index) {
            final weekday = index + 1;
            return FilterChip(
              label: Text(labels[index]),
              selected: values.contains(weekday),
              onSelected: (selected) {
                final next = Set<int>.from(values);
                selected ? next.add(weekday) : next.remove(weekday);
                onChanged(next);
              },
            );
          }),
        ),
      ],
    );
  }
}

class _MonthDayPicker extends StatelessWidget {
  const _MonthDayPicker({required this.values, required this.onChanged});

  final Set<int> values;
  final ValueChanged<Set<int>> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('Month days', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: List<Widget>.generate(31, (index) {
            final day = index + 1;
            return FilterChip(
              label: Text('$day'),
              selected: values.contains(day),
              onSelected: (selected) {
                final next = Set<int>.from(values);
                selected ? next.add(day) : next.remove(day);
                onChanged(next);
              },
            );
          }),
        ),
      ],
    );
  }
}

extension on int? {
  int clampMinimum(int minimum) {
    final value = this ?? minimum;
    return value < minimum ? minimum : value;
  }
}
