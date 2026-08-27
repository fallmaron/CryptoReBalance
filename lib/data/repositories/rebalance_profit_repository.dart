import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/app_database.dart';
import '../models/rebalance_profit.dart';

abstract class RebalanceProfitRepository {
  Future<List<RebalanceProfit>> getAll();
  Future<bool> saveIfAbsent(RebalanceProfit profit);
  Future<void> deleteAll();
}

class SqliteRebalanceProfitRepository implements RebalanceProfitRepository {
  SqliteRebalanceProfitRepository(this._db);

  final AppDatabase _db;

  @override
  Future<List<RebalanceProfit>> getAll() => _db.getRebalanceProfits();

  @override
  Future<bool> saveIfAbsent(RebalanceProfit profit) async {
    final existing = await _db.getRebalanceProfitBySessionEndId(
      profit.sessionEndId,
    );
    if (existing != null) {
      return false;
    }
    await _db.insertRebalanceProfit(profit);
    return true;
  }

  @override
  Future<void> deleteAll() => _db.deleteAllRebalanceProfits();
}

final rebalanceProfitRepositoryProvider = Provider<RebalanceProfitRepository>((
  ref,
) {
  return SqliteRebalanceProfitRepository(ref.watch(appDatabaseProvider));
});

final rebalanceProfitsProvider = FutureProvider<List<RebalanceProfit>>((ref) {
  return ref.watch(rebalanceProfitRepositoryProvider).getAll();
});
