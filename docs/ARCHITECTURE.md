# Architecture

OpenHabit uses a modular clean architecture:

- Presentation: Flutter screens and reusable widgets.
- Domain: pure models, recurrence rules, timer calculations, and analytics scoring.
- Data: repositories and SQLite persistence.
- Platform services: local notifications, import/export files, and Android widgets.

Riverpod is used mainly for dependency injection and feature boundaries. Feature widgets keep transient screen state locally when that is simpler and easier to test.

## Feature Modules

- `habits`: habit definitions, scheduling, entries, archiving, streaks, and cards.
- `timer`: durable timer sessions that survive app restarts and handle day reset.
- `analytics`: daily, weekly, and monthly rollups from local SQLite data.
- `settings`: reset time, theme preference, analytics toggles, and backup preferences.
- `backup`: JSON backup import/export and CSV reporting.
- `notifications`: reminder, missed habit, and summary notifications.
- `widgets`: Android widget data sync and quick-complete callback handling.

## Future Sync

Cloud sync should be added behind repository interfaces. Domain models already use stable string ids and revision snapshots so a future sync layer can reconcile local and remote changes without rewriting UI screens.
