import 'dart:convert';
import 'dart:io';

import 'package:csv/csv.dart' as csv_lib;
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../../../core/database/app_database.dart';
import '../../settings/data/settings_repository.dart';
import '../../settings/domain/app_settings.dart';

class BackupService {
  BackupService(this._database);

  static const int schemaVersion = 1;
  static const List<String> _tables = <String>[
    'habits',
    'habit_schedules',
    'habit_targets',
    'habit_revisions',
    'habit_entries',
    'timer_sessions',
    'notification_rules',
    'settings',
  ];

  final AppDatabase _database;

  Future<File> exportJson() async {
    final db = await _database.instance;
    final payload = <String, Object?>{
      'schemaVersion': schemaVersion,
      'exportedAt': DateTime.now().toIso8601String(),
      'appSettings': (await SettingsRepository().load()).toJson(),
      'tables': <String, Object?>{},
    };
    final tables = payload['tables']! as Map<String, Object?>;
    for (final table in _tables) {
      tables[table] = await db.query(table);
    }
    final file = await _backupFile('openhabit-backup', 'json');
    return file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(payload),
    );
  }

  Future<File> exportCsv() async {
    final db = await _database.instance;
    final rows = await db.rawQuery('''
      SELECT h.name, h.type, e.day, e.status, e.number_value, e.timer_seconds, e.completed_at
      FROM habit_entries e
      JOIN habits h ON h.id = e.habit_id
      ORDER BY e.day DESC, h.sort_order ASC
    ''');
    final csvRows = <List<Object?>>[
      <Object?>[
        'habit',
        'type',
        'day',
        'status',
        'number_value',
        'timer_seconds',
        'completed_at',
      ],
      ...rows.map(
        (row) => <Object?>[
          row['name'],
          row['type'],
          row['day'],
          row['status'],
          row['number_value'],
          row['timer_seconds'],
          row['completed_at'],
        ],
      ),
    ];
    final file = await _backupFile('openhabit-entries', 'csv');
    return file.writeAsString(csv_lib.csv.encode(csvRows));
  }

  Future<void> importJson(File file) async {
    final payload =
        jsonDecode(await file.readAsString()) as Map<String, Object?>;
    if (payload['schemaVersion'] != schemaVersion) {
      throw const FormatException('Unsupported backup schema version.');
    }
    final tables = payload['tables'] as Map<String, Object?>;
    final settings = payload['appSettings'];
    final db = await _database.instance;
    await db.transaction((txn) async {
      for (final table in _tables) {
        final rows = tables[table] as List? ?? const <Object?>[];
        for (final row in rows.cast<Map>()) {
          await txn.insert(
            table,
            row.cast<String, Object?>(),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }
    });
    if (settings is Map) {
      await SettingsRepository().save(
        AppSettings.fromJson(settings.cast<String, Object?>()),
      );
    }
  }

  Future<Directory> localBackupDirectory() async {
    final documents = await getApplicationDocumentsDirectory();
    final directory = Directory(p.join(documents.path, 'openhabit_backups'));
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory;
  }

  Future<File> _backupFile(String prefix, String extension) async {
    final directory = await localBackupDirectory();
    final stamp = DateFormat('yyyyMMdd-HHmmss').format(DateTime.now());
    return File(p.join(directory.path, '$prefix-$stamp.$extension'));
  }
}
