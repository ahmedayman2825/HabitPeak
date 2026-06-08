import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  AppDatabase({this.databaseName = 'open_habit.db'});

  final String databaseName;
  Database? _database;

  Future<Database> get instance async {
    if (_database != null) {
      return _database!;
    }
    final dbPath = p.join(await getDatabasesPath(), databaseName);
    _database = await openDatabase(
      dbPath,
      version: 2,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _create,
      onUpgrade: _upgrade,
    );
    return _database!;
  }

  Future<void> close() async {
    await _database?.close();
    _database = null;
  }

  Future<void> _create(Database db, int version) async {
    await db.execute('''
      CREATE TABLE habits (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        type TEXT NOT NULL CHECK(type IN ('checkbox', 'number', 'timer')),
        color_hex TEXT NOT NULL DEFAULT '#4F8A8B',
        sort_order INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        archived_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE habit_schedules (
        habit_id TEXT PRIMARY KEY,
        recurrence_type TEXT NOT NULL,
        start_date TEXT,
        end_date TEXT,
        selected_weekdays TEXT NOT NULL DEFAULT '[]',
        excluded_weekdays TEXT NOT NULL DEFAULT '[]',
        month_days TEXT NOT NULL DEFAULT '[]',
        interval_days INTEGER,
        FOREIGN KEY(habit_id) REFERENCES habits(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE habit_targets (
        habit_id TEXT PRIMARY KEY,
        number_target INTEGER,
        timer_target_seconds INTEGER,
        FOREIGN KEY(habit_id) REFERENCES habits(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE habit_revisions (
        id TEXT PRIMARY KEY,
        habit_id TEXT NOT NULL,
        name TEXT NOT NULL,
        type TEXT NOT NULL,
        schedule_json TEXT NOT NULL,
        number_target INTEGER,
        timer_target_seconds INTEGER,
        created_at TEXT NOT NULL,
        FOREIGN KEY(habit_id) REFERENCES habits(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE habit_entries (
        id TEXT PRIMARY KEY,
        habit_id TEXT NOT NULL,
        habit_revision_id TEXT,
        day TEXT NOT NULL,
        status TEXT NOT NULL CHECK(status IN ('pending', 'completed', 'skipped', 'missed')),
        number_value INTEGER NOT NULL DEFAULT 0,
        timer_seconds INTEGER NOT NULL DEFAULT 0,
        completed_at TEXT,
        notes TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        UNIQUE(habit_id, day),
        FOREIGN KEY(habit_id) REFERENCES habits(id) ON DELETE CASCADE,
        FOREIGN KEY(habit_revision_id) REFERENCES habit_revisions(id) ON DELETE SET NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE timer_sessions (
        id TEXT PRIMARY KEY,
        habit_id TEXT NOT NULL,
        day TEXT NOT NULL,
        started_at TEXT NOT NULL,
        last_resumed_at TEXT,
        paused_at TEXT,
        ended_at TEXT,
        accumulated_seconds INTEGER NOT NULL DEFAULT 0,
        target_reached_at TEXT,
        is_active INTEGER NOT NULL DEFAULT 1,
        is_paused INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY(habit_id) REFERENCES habits(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE notification_rules (
        id TEXT PRIMARY KEY,
        habit_id TEXT,
        type TEXT NOT NULL,
        minute_of_day INTEGER NOT NULL,
        enabled INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY(habit_id) REFERENCES habits(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute(
      'CREATE INDEX idx_habit_entries_habit_day ON habit_entries(habit_id, day)',
    );
    await db.execute(
      'CREATE INDEX idx_habit_entries_day_status ON habit_entries(day, status)',
    );
    await db.execute(
      'CREATE INDEX idx_timer_sessions_habit_day ON timer_sessions(habit_id, day)',
    );
    await db.execute(
      'CREATE INDEX idx_timer_sessions_active ON timer_sessions(is_active, is_paused)',
    );

    await db.execute('''
      CREATE TABLE streak_restorations (
        habit_id TEXT NOT NULL,
        restored_day TEXT NOT NULL,
        restored_at TEXT NOT NULL,
        PRIMARY KEY (habit_id, restored_day),
        FOREIGN KEY(habit_id) REFERENCES habits(id) ON DELETE CASCADE
      )
    ''');
  }

  Future<void> _upgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS streak_restorations (
          habit_id TEXT NOT NULL,
          restored_day TEXT NOT NULL,
          restored_at TEXT NOT NULL,
          PRIMARY KEY (habit_id, restored_day),
          FOREIGN KEY(habit_id) REFERENCES habits(id) ON DELETE CASCADE
        )
      ''');
    }
  }
}
