# Contributing

Thanks for considering a contribution to OpenHabit.

## Local Setup

```bash
flutter pub get
flutter analyze
flutter test
```

## Contribution Guidelines

- Keep the app offline-first and local-only by default.
- Do not add an account, remote analytics, ads, or tracking dependency without an accepted design proposal.
- Keep UI minimal and productivity-focused.
- Put domain behavior in testable Dart classes.
- Preserve old habit history when changing edit flows or database migrations.
- Update docs when changing architecture, database tables, backup format, or widget behavior.

## Suggested PR Shape

- Small focused change.
- Clear summary and screenshots for UI work.
- Tests for recurrence, timer, analytics, import/export, or migration changes.
- Migration notes when changing SQLite schema.

## Code Style

- Follow `analysis_options.yaml`.
- Use meaningful names and short comments only where the code benefits from context.
- Keep platform-specific Android code under `android/` and Flutter widget sync under `lib/features/widgets/`.
