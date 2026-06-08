# Database Schema

The SQLite database is versioned in `lib/core/database/app_database.dart`.

## Tables

- `habits`: current habit metadata, type, archive state, sort order, and timestamps.
- `habit_schedules`: recurrence data, selected weekdays, excluded weekdays, date bounds, and custom interval.
- `habit_targets`: number or timer targets.
- `habit_revisions`: immutable snapshots written on habit create/edit so old history remains untouched.
- `habit_entries`: per-habit day records for checkbox, number, and timer completion.
- `timer_sessions`: durable timer sessions with accumulated time, active/paused state, and target-reached timestamp.
- `notification_rules`: local reminder metadata.
- `settings`: database-backed feature flags reserved for future migrations.

## Important Indexes

- `habit_entries(habit_id, day)`
- `habit_entries(day, status)`
- `timer_sessions(habit_id, day)`
- `timer_sessions(is_active, is_paused)`

## Backup Format

JSON exports contain `schemaVersion`, `exportedAt`, `appSettings`, and a table dump for all local data tables. Imports are idempotent upserts by primary key.
