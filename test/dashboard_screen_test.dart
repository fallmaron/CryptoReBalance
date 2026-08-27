import 'package:cryptrebalance/core/utils/formatters.dart';
import 'package:cryptrebalance/data/models/crypto_asset.dart';
import 'package:cryptrebalance/data/models/daily_snapshot.dart';
import 'package:cryptrebalance/data/models/holding_record.dart';
import 'package:cryptrebalance/data/models/market_rates.dart';
import 'package:cryptrebalance/data/models/rebalance_profit.dart';
import 'package:cryptrebalance/data/models/storage_location.dart';
import 'package:cryptrebalance/data/repositories/daily_snapshot_repository.dart';
import 'package:cryptrebalance/data/repositories/holding_repository.dart';
import 'package:cryptrebalance/data/repositories/rate_repository.dart';
import 'package:cryptrebalance/data/repositories/rebalance_profit_repository.dart';
import 'package:cryptrebalance/features/dashboard/view/dashboard_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _MemoryHoldingRepository implements HoldingRepository {
  _MemoryHoldingRepository(this._records);

  final List<HoldingRecord> _records;

  @override
  Future<void> delete(int id) async {
    _records.removeWhere((record) => record.id == id);
  }

  @override
  Future<List<HoldingRecord>> getAll() async => List.of(_records);

  @override
  Future<Map<StorageLocation, HoldingRecord>> getLatestByLocation() async {
    return {
      for (final record in _records) record.location: record,
    };
  }

  @override
  Future<HoldingRecord> save(HoldingRecord record) async {
    final saved = record.copyWith(id: _records.length + 1);
    _records.add(saved);
    return saved;
  }

  @override
  Future<void> deleteAll() async {
    _records.clear();
  }
}

class _FakeRebalanceProfitRepository implements RebalanceProfitRepository {
  @override
  Future<List<RebalanceProfit>> getAll() async => [];

  @override
  Future<bool> saveIfAbsent(RebalanceProfit profit) async => false;

  @override
  Future<void> deleteAll() async {}
}

class _FakeDailySnapshotRepository implements DailySnapshotRepository {
  @override
  Future<List<DailySnapshot>> getAll() async => [];

  @override
  Future<bool> saveIfAbsent(DailySnapshot snapshot) async => true;

  @override
  Future<bool> deleteByDay(String dayKey) async => false;
}

class _FakeRateRepository implements RateRepository {
  _FakeRateRepository(this._rates);

  final MarketRates _rates;
  int refreshCount = 0;

  @override
  Future<MarketRates?> getCached() async => _rates;

  @override
  Future<MarketRates> refresh() async {
    refreshCount += 1;
    return _rates;
  }
}

void main() {
  testWidgets('dashboard shows holdings, rates, and rebalance diffs', (
    tester,
  ) async {
    final rates = MarketRates(
      fetchedAt: DateTime(2026, 8, 20, 11, 2, 3),
      pricesUsdt: const {
        CryptoAsset.btc: 100000,
        CryptoAsset.hype: 50,
        CryptoAsset.nexo: 1,
        CryptoAsset.usdt: 1,
      },
    );
    final holdings = [
      HoldingRecord(
        id: 1,
        recordedAt: DateTime(2026, 8, 20, 10, 0, 0),
        location: StorageLocation.nx,
        amounts: const {
          CryptoAsset.btc: 1,
          CryptoAsset.hype: 0,
          CryptoAsset.nexo: 0,
          CryptoAsset.usdt: 0,
        },
      ),
    ];
    final rateRepository = _FakeRateRepository(rates);

    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          holdingRepositoryProvider.overrideWithValue(
            _MemoryHoldingRepository(holdings),
          ),
          rateRepositoryProvider.overrideWithValue(rateRepository),
          dailySnapshotRepositoryProvider.overrideWithValue(
            _FakeDailySnapshotRepository(),
          ),
          rebalanceProfitRepositoryProvider.overrideWithValue(
            _FakeRebalanceProfitRepository(),
          ),
        ],
        child: const MaterialApp(home: DashboardScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('更新'), findsOneWidget);
    expect(find.text('リバランス収益'), findsOneWidget);
    expect(find.text('100,000.00 USDT'), findsOneWidget);
    expect(find.text('1 BTC'), findsOneWidget);
    expect(find.text('HYPE/BTC'), findsOneWidget);
    expect(find.text('0.0005'), findsOneWidget);
    expect(find.text('目標配分'), findsOneWidget);
    expect(find.text('100.0%'), findsWidgets);
    expect(find.text('LE'), findsOneWidget);
    expect(find.text('TR'), findsOneWidget);
    expect(find.text('RK'), findsOneWidget);
    expect(find.textContaining('不足（購入）'), findsWidgets);
    expect(find.textContaining('過剰（売却）'), findsOneWidget);
    expect(find.text('NX'), findsOneWidget);

    await tester.tap(find.text('更新'));
    await tester.pumpAndSettle();
    expect(rateRepository.refreshCount, 1);
  });

  test('formats signed USDT and datetime with seconds', () {
    expect(Formatters.usdt(1234.5, signed: true), '+1,234.50');
    expect(Formatters.usdt(-20, signed: true), '-20.00');
    expect(
      Formatters.dateTimeText(DateTime(2026, 8, 20, 11, 2, 3)),
      '2026/08/20 11:02:03',
    );
    expect(Formatters.amount(CryptoAsset.btc, 0.70000000), '0.7');
    expect(Formatters.pairRate(0.0005), '0.0005');
  });
}
