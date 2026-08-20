import 'package:cryptrebalance/data/models/crypto_asset.dart';
import 'package:cryptrebalance/data/models/daily_snapshot.dart';
import 'package:cryptrebalance/data/models/market_rates.dart';
import 'package:cryptrebalance/data/repositories/daily_snapshot_repository.dart';
import 'package:cryptrebalance/data/services/daily_snapshot_csv.dart';
import 'package:cryptrebalance/data/services/rebalance_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

class _MemoryDailySnapshotRepository implements DailySnapshotRepository {
  final List<DailySnapshot> snapshots = [];

  @override
  Future<List<DailySnapshot>> getAll() async => List.of(snapshots);

  @override
  Future<bool> saveIfAbsent(DailySnapshot snapshot) async {
    if (snapshots.any((item) => item.dayKey == snapshot.dayKey)) {
      return false;
    }
    snapshots.add(snapshot);
    return true;
  }

  @override
  Future<bool> deleteByDay(String dayKey) async {
    final before = snapshots.length;
    snapshots.removeWhere((item) => item.dayKey == dayKey);
    return snapshots.length < before;
  }
}

void main() {
  final rates = MarketRates(
    fetchedAt: DateTime(2026, 8, 20, 11),
    pricesUsdt: const {
      CryptoAsset.btc: 100000,
      CryptoAsset.hype: 50,
      CryptoAsset.nexo: 1,
      CryptoAsset.usdt: 1,
    },
  );

  DailySnapshot sample({required DateTime recordedAt}) {
    final rebalance = RebalanceCalculator.calculate(
      holdings: const {
        CryptoAsset.btc: 1,
        CryptoAsset.hype: 0,
        CryptoAsset.nexo: 0,
        CryptoAsset.usdt: 0,
      },
      nxHoldings: const {CryptoAsset.btc: 1},
      rates: rates,
    );
    return DailySnapshot.fromRebalance(
      recordedAt: recordedAt,
      rebalance: rebalance,
    );
  }

  test('uses local calendar day as the unique key', () {
    expect(
      DailySnapshot.dayKeyOf(DateTime(2026, 8, 20, 23, 59, 59)),
      '2026-08-20',
    );
  });

  test('saves the first snapshot of the day and skips later ones', () async {
    final repository = _MemoryDailySnapshotRepository();
    final morning = sample(recordedAt: DateTime(2026, 8, 20, 9));
    final evening = sample(recordedAt: DateTime(2026, 8, 20, 21));
    final nextDay = sample(recordedAt: DateTime(2026, 8, 21, 8));

    expect(await repository.saveIfAbsent(morning), isTrue);
    expect(await repository.saveIfAbsent(evening), isFalse);
    expect(await repository.saveIfAbsent(nextDay), isTrue);
    expect(repository.snapshots, hasLength(2));
  });

  test('builds a CSV with totals and per-asset balance fields', () {
    final snapshot = sample(recordedAt: DateTime(2026, 8, 20, 11, 2, 3));
    final csv = DailySnapshotCsv.build([snapshot]);

    expect(csv, contains('総資産USDT'));
    expect(csv, contains('BTC現在量'));
    expect(csv, contains('HYPE目標比'));
    expect(csv, contains('2026-08-20'));
    expect(csv, contains('100000.0'));
  });

  test('deletes only the requested day', () async {
    final repository = _MemoryDailySnapshotRepository();
    final today = sample(recordedAt: DateTime(2026, 8, 20, 9));
    final yesterday = sample(recordedAt: DateTime(2026, 8, 19, 21));

    await repository.saveIfAbsent(today);
    await repository.saveIfAbsent(yesterday);

    expect(await repository.deleteByDay(today.dayKey), isTrue);
    expect(repository.snapshots, hasLength(1));
    expect(repository.snapshots.single.dayKey, yesterday.dayKey);
    expect(await repository.deleteByDay(today.dayKey), isFalse);
  });
}
