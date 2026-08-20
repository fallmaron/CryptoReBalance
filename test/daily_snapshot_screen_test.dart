import 'package:cryptrebalance/data/models/crypto_asset.dart';
import 'package:cryptrebalance/data/models/daily_snapshot.dart';
import 'package:cryptrebalance/data/models/market_rates.dart';
import 'package:cryptrebalance/data/repositories/daily_snapshot_repository.dart';
import 'package:cryptrebalance/data/services/rebalance_calculator.dart';
import 'package:cryptrebalance/features/daily/view/daily_snapshot_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _MemoryDailySnapshotRepository implements DailySnapshotRepository {
  _MemoryDailySnapshotRepository(this.snapshots);

  final List<DailySnapshot> snapshots;

  @override
  Future<List<DailySnapshot>> getAll() async => List.of(snapshots);

  @override
  Future<bool> saveIfAbsent(DailySnapshot snapshot) async => false;

  @override
  Future<bool> deleteByDay(String dayKey) async {
    final before = snapshots.length;
    snapshots.removeWhere((item) => item.dayKey == dayKey);
    return snapshots.length < before;
  }
}

void main() {
  DailySnapshot sample(DateTime recordedAt) {
    final rebalance = RebalanceCalculator.calculate(
      holdings: const {
        CryptoAsset.btc: 1,
        CryptoAsset.hype: 0,
        CryptoAsset.nexo: 0,
        CryptoAsset.usdt: 0,
      },
      nxHoldings: const {CryptoAsset.btc: 1},
      rates: MarketRates(
        fetchedAt: recordedAt,
        pricesUsdt: const {
          CryptoAsset.btc: 100000,
          CryptoAsset.hype: 50,
          CryptoAsset.nexo: 1,
          CryptoAsset.usdt: 1,
        },
      ),
    );
    return DailySnapshot.fromRebalance(
      recordedAt: recordedAt,
      rebalance: rebalance,
    );
  }

  testWidgets('deletes only today after confirmation', (tester) async {
    final now = DateTime.now();
    final today = sample(now);
    final yesterday = sample(now.subtract(const Duration(days: 1)));
    final repository = _MemoryDailySnapshotRepository([today, yesterday]);

    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dailySnapshotRepositoryProvider.overrideWithValue(repository),
        ],
        child: const MaterialApp(home: DailySnapshotScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip('当日分を削除'), findsOneWidget);
    expect(find.text(today.dayKey.replaceAll('-', '/')), findsOneWidget);
    expect(find.text(yesterday.dayKey.replaceAll('-', '/')), findsOneWidget);

    await tester.tap(find.byTooltip('当日分を削除'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, '削除'));
    await tester.pumpAndSettle();

    expect(find.text('当日の記録を削除しました'), findsOneWidget);
    expect(find.text(today.dayKey.replaceAll('-', '/')), findsNothing);
    expect(find.text(yesterday.dayKey.replaceAll('-', '/')), findsOneWidget);
    expect(find.byTooltip('当日分を削除'), findsNothing);
  });
}
