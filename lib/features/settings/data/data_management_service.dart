import '../../../core/database/app_database.dart';

class DataManagementService {
  DataManagementService(this._database);

  final AppDatabase _database;

  Future<void> resetStatisticsOnly({bool keepArchivedHabits = true}) async {
    final db = await _database.instance;
    await db.transaction((txn) async {
      await txn.delete('habit_entries');
      await txn.delete('timer_sessions');
      if (!keepArchivedHabits) {
        await txn.update('habits', <String, Object?>{'archived_at': null});
      }
    });
  }

  Future<void> clearAllHistory({bool keepArchivedHabits = true}) async {
    final db = await _database.instance;
    await db.transaction((txn) async {
      await txn.delete('habit_entries');
      await txn.delete('timer_sessions');
      await txn.delete('habit_revisions');
      if (!keepArchivedHabits) {
        await txn.delete('habits', where: 'archived_at IS NOT NULL');
      }
    });
  }
}
