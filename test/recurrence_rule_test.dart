import 'package:flutter_test/flutter_test.dart';
import 'package:open_habit/features/habits/domain/recurrence_rule.dart';

void main() {
  test('daily recurrence supports excluded weekdays', () {
    final rule = RecurrenceRule.daily(
      excludedWeekdays: const <int>[DateTime.friday],
    );

    expect(rule.isScheduledOn(DateTime(2026, 5, 21)), isTrue);
    expect(rule.isScheduledOn(DateTime(2026, 5, 22)), isFalse);
  });

  test('weekly recurrence supports custom selected weekdays', () {
    const rule = RecurrenceRule(
      type: RecurrenceType.weekly,
      selectedWeekdays: <int>[DateTime.monday, DateTime.wednesday],
    );

    expect(rule.isScheduledOn(DateTime(2026, 5, 25)), isTrue);
    expect(rule.isScheduledOn(DateTime(2026, 5, 26)), isFalse);
  });

  test('monthly recurrence supports selected month days', () {
    const rule = RecurrenceRule(
      type: RecurrenceType.monthly,
      monthDays: <int>[1, 15],
    );

    expect(rule.isScheduledOn(DateTime(2026, 6, 1)), isTrue);
    expect(rule.isScheduledOn(DateTime(2026, 6, 2)), isFalse);
  });
}
