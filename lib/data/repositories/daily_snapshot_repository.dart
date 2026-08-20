import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/app_database.dart';
import '../models/daily_snapshot.dart';

abstract class DailySnapshotRepository {
  Future<List<DailySnapshot>> getAll();
  Future<bool> saveIfAbsent(DailySnapshot snapshot);
  Future<bool> deleteByDay(String dayKey);
}

class SqliteDailySnapshotRepository implements DailySnapshotRepository {
  SqliteDailySnapshotRepository(this._db);

  final AppDatabase _db;

  @override
  Future<List<DailySnapshot>> getAll() => _db.getDailySnapshots();

  @override
  Future<bool> saveIfAbsent(DailySnapshot snapshot) async {
    final existing = await _db.getDailySnapshotByDay(snapshot.dayKey);
    if (existing != null) {
      return false;
    }
    await _db.insertDailySnapshot(snapshot);
    return true;
  }

  @override
  Future<bool> deleteByDay(String dayKey) async {
    final deleted = await _db.deleteDailySnapshotByDay(dayKey);
    return deleted > 0;
  }
}

final dailySnapshotRepositoryProvider = Provider<DailySnapshotRepository>((
  ref,
) {
  return SqliteDailySnapshotRepository(ref.watch(appDatabaseProvider));
});

final dailySnapshotsProvider = FutureProvider<List<DailySnapshot>>((ref) {
  return ref.watch(dailySnapshotRepositoryProvider).getAll();
});
