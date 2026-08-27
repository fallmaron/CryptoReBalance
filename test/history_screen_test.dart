import 'package:cryptrebalance/data/models/crypto_asset.dart';
import 'package:cryptrebalance/data/models/holding_entry_kind.dart';
import 'package:cryptrebalance/data/models/holding_record.dart';
import 'package:cryptrebalance/data/models/market_rates.dart';
import 'package:cryptrebalance/data/models/rebalance_profit.dart';
import 'package:cryptrebalance/data/models/storage_location.dart';
import 'package:cryptrebalance/data/repositories/holding_repository.dart';
import 'package:cryptrebalance/data/repositories/rate_repository.dart';
import 'package:cryptrebalance/data/repositories/rebalance_profit_repository.dart';
import 'package:cryptrebalance/features/history/view/history_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _MemoryHoldingRepository implements HoldingRepository {
  _MemoryHoldingRepository(this.records);

  final List<HoldingRecord> records;

  @override
  Future<void> delete(int id) async {
    records.removeWhere((record) => record.id == id);
  }

  @override
  Future<void> deleteAll() async {
    records.clear();
  }

  @override
  Future<List<HoldingRecord>> getAll() async => List.of(records);

  @override
  Future<Map<StorageLocation, HoldingRecord>> getLatestByLocation() async {
    return {for (final record in records) record.location: record};
  }

  @override
  Future<HoldingRecord> save(HoldingRecord record) async {
    final saved = record.copyWith(id: records.length + 1);
    records.add(saved);
    return saved;
  }
}

class _MemoryProfitRepository implements RebalanceProfitRepository {
  _MemoryProfitRepository(this.profits);

  final List<RebalanceProfit> profits;

  @override
  Future<void> deleteAll() async {
    profits.clear();
  }

  @override
  Future<List<RebalanceProfit>> getAll() async => List.of(profits);

  @override
  Future<bool> saveIfAbsent(RebalanceProfit profit) async => false;
}

class _FakeRateRepository implements RateRepository {
  @override
  Future<MarketRates?> getCached() async {
    return MarketRates(
      fetchedAt: DateTime(2026, 8, 20),
      pricesUsdt: const {
        CryptoAsset.btc: 100000,
        CryptoAsset.hype: 50,
        CryptoAsset.nexo: 1,
        CryptoAsset.usdt: 1,
      },
    );
  }

  @override
  Future<MarketRates> refresh() async {
    throw UnsupportedError('unused');
  }
}

void main() {
  HoldingRecord holding({
    required int id,
    required HoldingEntryKind kind,
  }) {
    return HoldingRecord(
      id: id,
      recordedAt: DateTime(2026, 8, 20, 10, id),
      location: StorageLocation.nx,
      kind: kind,
      amounts: const {
        CryptoAsset.btc: 1,
        CryptoAsset.hype: 0,
        CryptoAsset.nexo: 0,
        CryptoAsset.usdt: 0,
      },
    );
  }

  testWidgets('shows rebalance profit on the matching history card', (
    tester,
  ) async {
    final records = [
      holding(id: 2, kind: HoldingEntryKind.rebalance),
      holding(id: 1, kind: HoldingEntryKind.rebalance),
    ];
    final profits = [
      RebalanceProfit(
        recordedAt: DateTime(2026, 8, 20, 10, 2),
        location: StorageLocation.nx,
        holdingId: 2,
        sessionStartedAt: DateTime(2026, 7, 1),
        sessionEndedAt: DateTime(2026, 7, 10),
        sessionStartId: 1,
        sessionEndId: 1,
        withUsdt: 170000,
        withoutUsdt: 200000,
        profitUsdt: -30000,
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          holdingRepositoryProvider.overrideWithValue(
            _MemoryHoldingRepository(records),
          ),
          rebalanceProfitRepositoryProvider.overrideWithValue(
            _MemoryProfitRepository(profits),
          ),
          rateRepositoryProvider.overrideWithValue(_FakeRateRepository()),
        ],
        child: const MaterialApp(home: HistoryScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('リバランス収益  -30,000.00 USDT'), findsOneWidget);
    expect(find.text('実施 170,000.00 / 未実施 200,000.00'), findsOneWidget);
  });

  testWidgets('deletes all history after two confirmations', (tester) async {
    final records = [
      holding(id: 1, kind: HoldingEntryKind.locationMove),
    ];
    final repository = _MemoryHoldingRepository(records);
    final profits = _MemoryProfitRepository([]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          holdingRepositoryProvider.overrideWithValue(repository),
          rebalanceProfitRepositoryProvider.overrideWithValue(profits),
          rateRepositoryProvider.overrideWithValue(_FakeRateRepository()),
        ],
        child: const MaterialApp(home: HistoryScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('全削除'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, '削除する'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'すべて削除'));
    await tester.pumpAndSettle();

    expect(repository.records, isEmpty);
    expect(find.text('まだ保有履歴がありません'), findsOneWidget);
    expect(find.text('保有履歴をすべて削除しました'), findsOneWidget);
  });
}
