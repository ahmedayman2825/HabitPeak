import 'package:flutter_test/flutter_test.dart';
import 'package:open_habit/core/utils/habit_clock.dart';

void main() {
  test('habit day respects custom reset time', () {
    final beforeReset = DateTime(2026, 5, 24, 3, 59);
    final afterReset = DateTime(2026, 5, 24, 4);

    expect(HabitClock.dayKey(beforeReset, resetMinutes: 4 * 60), '2026-05-23');
    expect(HabitClock.dayKey(afterReset, resetMinutes: 4 * 60), '2026-05-24');
  });

  test('reset boundary after day is correct', () {
    const key = '2026-06-02';
    // resetMinutes is 0 (midnight)
    final boundary0 = HabitClock.resetBoundaryAfterDay(key, 0);
    expect(boundary0, DateTime(2026, 6, 3, 0, 0));

    // resetMinutes is 120 (2:00 AM)
    final boundary120 = HabitClock.resetBoundaryAfterDay(key, 120);
    expect(boundary120, DateTime(2026, 6, 3, 2, 0));
  });
}
