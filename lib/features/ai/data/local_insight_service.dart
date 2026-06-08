import '../../analytics/domain/analytics_summary.dart';
import '../domain/habit_suggestion.dart';

class LocalInsightService {
  List<HabitSuggestion> suggestions(AnalyticsSummary summary) {
    final suggestions = <HabitSuggestion>[];
    if (summary.weakestHabits.isNotEmpty) {
      suggestions.add(
        HabitSuggestion(
          title: 'Weak consistency pattern',
          body:
              'Try moving ${summary.weakestHabits.first} away from ${summary.mostSkippedDay}.',
        ),
      );
    }
    if (summary.weeklyScore < 60 && summary.completionTrends.isNotEmpty) {
      suggestions.add(
        const HabitSuggestion(
          title: 'Schedule adjustment',
          body:
              'Reduce today-only load or split one hard habit into a smaller target.',
        ),
      );
    }
    if (summary.timeTrends.any((trend) => trend.seconds > 0)) {
      suggestions.add(
        const HabitSuggestion(
          title: 'Better completion time',
          body:
              'Keep timer habits near your strongest focus block and schedule reminders before it.',
        ),
      );
    }
    return suggestions.take(3).toList();
  }
}
