class TimerSession {
  const TimerSession({
    required this.id,
    required this.habitId,
    required this.day,
    required this.startedAt,
    required this.accumulatedSeconds,
    required this.isActive,
    required this.isPaused,
    this.lastResumedAt,
    this.pausedAt,
    this.endedAt,
    this.targetReachedAt,
  });

  factory TimerSession.fromMap(Map<String, Object?> map) {
    return TimerSession(
      id: map['id'] as String,
      habitId: map['habit_id'] as String,
      day: map['day'] as String,
      startedAt: DateTime.parse(map['started_at'] as String),
      lastResumedAt: _parseDateTime(map['last_resumed_at'] as String?),
      pausedAt: _parseDateTime(map['paused_at'] as String?),
      endedAt: _parseDateTime(map['ended_at'] as String?),
      accumulatedSeconds: map['accumulated_seconds'] as int,
      targetReachedAt: _parseDateTime(map['target_reached_at'] as String?),
      isActive: (map['is_active'] as int) == 1,
      isPaused: (map['is_paused'] as int) == 1,
    );
  }

  final String id;
  final String habitId;
  final String day;
  final DateTime startedAt;
  final DateTime? lastResumedAt;
  final DateTime? pausedAt;
  final DateTime? endedAt;
  final int accumulatedSeconds;
  final DateTime? targetReachedAt;
  final bool isActive;
  final bool isPaused;

  int elapsedSecondsAt(DateTime now) {
    if (!isActive || isPaused || lastResumedAt == null) {
      return accumulatedSeconds;
    }
    return accumulatedSeconds + now.difference(lastResumedAt!).inSeconds;
  }

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'id': id,
      'habit_id': habitId,
      'day': day,
      'started_at': startedAt.toIso8601String(),
      'last_resumed_at': lastResumedAt?.toIso8601String(),
      'paused_at': pausedAt?.toIso8601String(),
      'ended_at': endedAt?.toIso8601String(),
      'accumulated_seconds': accumulatedSeconds,
      'target_reached_at': targetReachedAt?.toIso8601String(),
      'is_active': isActive ? 1 : 0,
      'is_paused': isPaused ? 1 : 0,
    };
  }

  TimerSession copyWith({
    DateTime? lastResumedAt,
    DateTime? pausedAt,
    DateTime? endedAt,
    int? accumulatedSeconds,
    DateTime? targetReachedAt,
    bool? isActive,
    bool? isPaused,
    bool clearLastResumed = false,
    bool clearPausedAt = false,
  }) {
    return TimerSession(
      id: id,
      habitId: habitId,
      day: day,
      startedAt: startedAt,
      lastResumedAt: clearLastResumed
          ? null
          : lastResumedAt ?? this.lastResumedAt,
      pausedAt: clearPausedAt ? null : pausedAt ?? this.pausedAt,
      endedAt: endedAt ?? this.endedAt,
      accumulatedSeconds: accumulatedSeconds ?? this.accumulatedSeconds,
      targetReachedAt: targetReachedAt ?? this.targetReachedAt,
      isActive: isActive ?? this.isActive,
      isPaused: isPaused ?? this.isPaused,
    );
  }

  static DateTime? _parseDateTime(String? value) {
    if (value == null || value.isEmpty) {
      return null;
    }
    return DateTime.parse(value);
  }
}
