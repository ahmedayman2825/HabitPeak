enum HabitEntryStatus { pending, completed, skipped, missed }

class HabitEntry {
  const HabitEntry({
    required this.id,
    required this.habitId,
    required this.day,
    required this.status,
    required this.numberValue,
    required this.timerSeconds,
    required this.createdAt,
    required this.updatedAt,
    this.habitRevisionId,
    this.completedAt,
    this.notes,
  });

  factory HabitEntry.empty({
    required String id,
    required String habitId,
    required String day,
    String? revisionId,
    DateTime? now,
  }) {
    final timestamp = now ?? DateTime.now();
    return HabitEntry(
      id: id,
      habitId: habitId,
      habitRevisionId: revisionId,
      day: day,
      status: HabitEntryStatus.pending,
      numberValue: 0,
      timerSeconds: 0,
      createdAt: timestamp,
      updatedAt: timestamp,
    );
  }

  factory HabitEntry.fromMap(Map<String, Object?> map) {
    return HabitEntry(
      id: map['id'] as String,
      habitId: map['habit_id'] as String,
      habitRevisionId: map['habit_revision_id'] as String?,
      day: map['day'] as String,
      status: HabitEntryStatus.values.byName(map['status'] as String),
      numberValue: map['number_value'] as int,
      timerSeconds: map['timer_seconds'] as int,
      completedAt: _parseDateTime(map['completed_at'] as String?),
      notes: map['notes'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  final String id;
  final String habitId;
  final String? habitRevisionId;
  final String day;
  final HabitEntryStatus status;
  final int numberValue;
  final int timerSeconds;
  final DateTime? completedAt;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isCompleted => status == HabitEntryStatus.completed;

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'id': id,
      'habit_id': habitId,
      'habit_revision_id': habitRevisionId,
      'day': day,
      'status': status.name,
      'number_value': numberValue,
      'timer_seconds': timerSeconds,
      'completed_at': completedAt?.toIso8601String(),
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  HabitEntry copyWith({
    String? id,
    String? habitId,
    String? habitRevisionId,
    String? day,
    HabitEntryStatus? status,
    int? numberValue,
    int? timerSeconds,
    DateTime? completedAt,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool clearCompletedAt = false,
  }) {
    return HabitEntry(
      id: id ?? this.id,
      habitId: habitId ?? this.habitId,
      habitRevisionId: habitRevisionId ?? this.habitRevisionId,
      day: day ?? this.day,
      status: status ?? this.status,
      numberValue: numberValue ?? this.numberValue,
      timerSeconds: timerSeconds ?? this.timerSeconds,
      completedAt: clearCompletedAt ? null : completedAt ?? this.completedAt,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static DateTime? _parseDateTime(String? value) {
    if (value == null || value.isEmpty) {
      return null;
    }
    return DateTime.parse(value);
  }
}
