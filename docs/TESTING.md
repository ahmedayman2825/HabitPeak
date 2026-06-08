# Testing Strategy

Recommended test coverage:

- Recurrence rules: daily, excluded weekdays, selected weekdays, one-time, monthly, date bounds, and intervals.
- Timer engine: start, pause, resume, stop, target auto-complete, continued tracking after target, and reset-time rollover.
- Analytics: completion percentages, best streak, weakest habits, skipped days, time rollups, and score bounds.
- Backup: JSON export/import round trips and CSV column stability.
- Repository: SQLite migrations, indexes, archiving, restore, delete, and revision preservation.
- UI: home screen habit states, settings persistence, analytics empty states, and responsive layout.

When Flutter is installed:

```bash
flutter analyze
flutter test
flutter test integration_test
```
