enum AnalyticsWindow { daily, weekly, monthly }

class CompletionTrend {
  const CompletionTrend({
    required this.day,
    required this.completed,
    required this.scheduled,
  });

  final DateTime day;
  final int completed;
  final int scheduled;
}

class TimeTrend {
  const TimeTrend({required this.day, required this.seconds});

  final DateTime day;
  final int seconds;
}

class AnalyticsSummary {
  const AnalyticsSummary({
    required this.window,
    required this.startDay,
    required this.endDay,
    required this.scheduledCount,
    required this.completedCount,
    required this.completionPercent,
    required this.trackedSeconds,
    required this.weeklyTrackedSeconds,
    required this.monthlyTrackedSeconds,
    required this.longestSessionSeconds,
    required this.bestStreak,
    required this.weakestHabits,
    required this.mostSkippedDay,
    required this.productivityScore,
    required this.dailyScore,
    required this.weeklyScore,
    required this.lifeBalanceScore,
    required this.completionTrends,
    required this.timeTrends,
  });

  final AnalyticsWindow window;
  final DateTime startDay;
  final DateTime endDay;
  final int scheduledCount;
  final int completedCount;
  final double completionPercent;
  final int trackedSeconds;
  final int weeklyTrackedSeconds;
  final int monthlyTrackedSeconds;
  final int longestSessionSeconds;
  final int bestStreak;
  final List<String> weakestHabits;
  final String mostSkippedDay;
  final int productivityScore;
  final int dailyScore;
  final int weeklyScore;
  final int lifeBalanceScore;
  final List<CompletionTrend> completionTrends;
  final List<TimeTrend> timeTrends;
}

class HabitAnalyticsSummary {
  const HabitAnalyticsSummary({
    required this.habitName,
    required this.scheduledCount,
    required this.completedCount,
    required this.missedCount,
    required this.skippedCount,
    required this.completionPercent,
    required this.currentStreak,
    required this.totalNumberValue,
    required this.totalTimerSeconds,
    required this.longestSessionSeconds,
    required this.firstDay,
    required this.lastDay,
    required this.completionTrends,
    required this.timeTrends,
    required this.canRestore,
  });

  final String habitName;
  final int scheduledCount;
  final int completedCount;
  final int missedCount;
  final int skippedCount;
  final double completionPercent;
  final int currentStreak;
  final int totalNumberValue;
  final int totalTimerSeconds;
  final int longestSessionSeconds;
  final DateTime firstDay;
  final DateTime lastDay;
  final List<CompletionTrend> completionTrends;
  final List<TimeTrend> timeTrends;
  final bool canRestore;
}
