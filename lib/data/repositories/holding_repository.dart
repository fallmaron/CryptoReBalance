import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/app_database.dart';
import '../models/holding_record.dart';
import '../models/storage_location.dart';
import '../services/holding_aggregator.dart';

abstract class HoldingRepository {
  Future<List<HoldingRecord>> getAll();
  Future<Map<StorageLocation, HoldingRecord>> getLatestByLocation();
  Future<HoldingRecord> save(HoldingRecord record);
  Future<void> delete(int id);
}

class SqliteHoldingRepository implements HoldingRepository {
  SqliteHoldingRepository(this._db);

  final AppDatabase _db;

  @override
  Future<List<HoldingRecord>> getAll() => _db.getHoldings();

  @override
  Future<Map<StorageLocation, HoldingRecord>> getLatestByLocation() async {
    final records = await _db.getHoldings();
    return HoldingAggregator.latestByLocation(records);
  }

  @override
  Future<HoldingRecord> save(HoldingRecord record) async {
    final id = await _db.insertHolding(record);
    return record.copyWith(id: id);
  }

  @override
  Future<void> delete(int id) => _db.deleteHolding(id);
}

final holdingRepositoryProvider = Provider<HoldingRepository>((ref) {
  return SqliteHoldingRepository(ref.watch(appDatabaseProvider));
});
