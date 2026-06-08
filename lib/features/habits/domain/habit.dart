import 'dart:convert';

import 'recurrence_rule.dart';

enum HabitType { checkbox, number, timer }

class Habit {
  const Habit({
    required this.id,
    required this.name,
    required this.type,
    required this.schedule,
    required this.createdAt,
    required this.updatedAt,
    this.colorHex = '#4F8A8B',
    this.sortOrder = 0,
    this.archivedAt,
    this.numberTarget,
    this.timerTargetSeconds,
  });

  factory Habit.fromRows({
    required Map<String, Object?> habit,
    required Map<String, Object?> schedule,
    Map<String, Object?>? target,
  }) {
    return Habit(
      id: habit['id'] as String,
      name: habit['name'] as String,
      type: HabitType.values.byName(habit['type'] as String),
      colorHex: habit['color_hex'] as String,
      sortOrder: habit['sort_order'] as int,
      createdAt: DateTime.parse(habit['created_at'] as String),
      updatedAt: DateTime.parse(habit['updated_at'] as String),
      archivedAt: _parseDateTime(habit['archived_at'] as String?),
      schedule: RecurrenceRule.fromMap(schedule),
      numberTarget: target?['number_target'] as int?,
      timerTargetSeconds: target?['timer_target_seconds'] as int?,
    );
  }

  final String id;
  final String name;
  final HabitType type;
  final RecurrenceRule schedule;
  final String colorHex;
  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? archivedAt;
  final int? numberTarget;
  final int? timerTargetSeconds;

  bool get isArchived => archivedAt != null;

  bool isScheduledOn(DateTime day) =>
      !isArchived && schedule.isScheduledOn(day);

  Map<String, Object?> toHabitMap() {
    return <String, Object?>{
      'id': id,
      'name': name,
      'type': type.name,
      'color_hex': colorHex,
      'sort_order': sortOrder,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'archived_at': archivedAt?.toIso8601String(),
    };
  }

  Map<String, Object?> toTargetMap() {
    return <String, Object?>{
      'habit_id': id,
      'number_target': numberTarget,
      'timer_target_seconds': timerTargetSeconds,
    };
  }

  Map<String, Object?> toRevisionMap(String revisionId, DateTime createdAt) {
    return <String, Object?>{
      'id': revisionId,
      'habit_id': id,
      'name': name,
      'type': type.name,
      'schedule_json': jsonEncode(schedule.toJson()),
      'number_target': numberTarget,
      'timer_target_seconds': timerTargetSeconds,
      'created_at': createdAt.toIso8601String(),
    };
  }

  Habit copyWith({
    String? id,
    String? name,
    HabitType? type,
    RecurrenceRule? schedule,
    String? colorHex,
    int? sortOrder,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? archivedAt,
    int? numberTarget,
    int? timerTargetSeconds,
    bool clearArchive = false,
  }) {
    return Habit(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      schedule: schedule ?? this.schedule,
      colorHex: colorHex ?? this.colorHex,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      archivedAt: clearArchive ? null : archivedAt ?? this.archivedAt,
      numberTarget: numberTarget ?? this.numberTarget,
      timerTargetSeconds: timerTargetSeconds ?? this.timerTargetSeconds,
    );
  }

  static DateTime? _parseDateTime(String? value) {
    if (value == null || value.isEmpty) {
      return null;
    }
    return DateTime.parse(value);
  }
}
