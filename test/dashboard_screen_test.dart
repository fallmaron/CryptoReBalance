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
import 'package:flutter/services.dart';
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
  _FakeDailySnapshotRepository([this._snapshots = const []]);

  final List<DailySnapshot> _snapshots;

  @override
  Future<List<DailySnapshot>> getAll() async => List.of(_snapshots);

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
  Future<MarketRates?> getAtOrBefore(DateTime time) async {
    if (_rates.fetchedAt.millisecondsSinceEpoch <=
        time.millisecondsSinceEpoch) {
      return _rates;
    }
    return null;
  }

  @override
  Future<void> saveSnapshot(MarketRates rates) async {}

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

    tester.view.physicalSize = const Size(800, 2800);
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

    expect(find.text('リバランスした場合の収益'), findsNothing);
    expect(find.text('リバランス収益'), findsNothing);
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
    expect(find.byKey(const ValueKey('rebalance-nexo-BTC')), findsOneWidget);
    expect(find.byKey(const ValueKey('rebalance-nexo-HYPE')), findsOneWidget);
    expect(find.byKey(const ValueKey('rebalance-nexo-NEXO')), findsOneWidget);
    expect(find.byKey(const ValueKey('rebalance-nexo-USDT')), findsNothing);

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
    expect(
      Formatters.btcProfitLine(profitBtc: 0.01, btcPriceUsdt: 77000.9),
      '+0.01BTC(770USDT)',
    );
    expect(
      Formatters.btcProfitLine(profitBtc: -0.01, btcPriceUsdt: 77000.9),
      '-0.01BTC(770USDT)',
    );
    expect(
      DailySnapshot.oldestOf([
        DailySnapshot(
          dayKey: '2026-08-20',
          recordedAt: DateTime(2026, 8, 20),
          totalUsdt: 100000,
          totalBtc: 1,
          assets: const {},
        ),
        DailySnapshot(
          dayKey: '2026-08-01',
          recordedAt: DateTime(2026, 8, 1),
          totalUsdt: 99000,
          totalBtc: 0.99,
          assets: const {},
        ),
      ])?.totalBtc,
      0.99,
    );
    expect(Formatters.pairRate(0.0005), '0.0005');
    expect(Formatters.percent(0.021, signed: true), '+2.1%');
    expect(Formatters.percent(-0.05, signed: true), '-5.0%');
    expect(
      Formatters.rebalanceClipboardText(
        asset: CryptoAsset.btc,
        diffAmount: -0.3,
        diffUsdt: -30000,
      ),
      '0.3',
    );
    expect(
      Formatters.rebalanceClipboardText(
        asset: CryptoAsset.hype,
        diffAmount: 300,
        diffUsdt: 15000,
      ),
      '15,000',
    );
    expect(
      Formatters.rebalanceClipboardText(
        asset: CryptoAsset.hype,
        diffAmount: -12.349,
        diffUsdt: -600,
      ),
      '12.34',
    );
    expect(
      Formatters.rebalanceClipboardText(
        asset: CryptoAsset.nexo,
        diffAmount: -11.9,
        diffUsdt: -11.9,
      ),
      '11',
    );
    expect(
      Formatters.rebalanceClipboardText(
        asset: CryptoAsset.usdt,
        diffAmount: -100.9,
        diffUsdt: -100.9,
      ),
      '100',
    );
    expect(
      Formatters.rebalanceClipboardText(
        asset: CryptoAsset.btc,
        diffAmount: -0.12345678,
        diffUsdt: -12345.678,
      ),
      '0.12345678',
    );
    expect(
      Formatters.rebalanceClipboardText(
        asset: CryptoAsset.usdt,
        diffAmount: 0,
        diffUsdt: 0,
      ),
      isNull,
    );
  });

  test('maps Nexo spot URLs except USDT', () {
    expect(
      CryptoAsset.btc.nexoSpotUrl,
      'https://platform.nexo.com/spot?pair=BTC_USDT',
    );
    expect(
      CryptoAsset.hype.nexoSpotUrl,
      'https://platform.nexo.com/spot?pair=HYPE_USDT',
    );
    expect(
      CryptoAsset.nexo.nexoSpotUrl,
      'https://platform.nexo.com/spot?pair=NEXO_USDT',
    );
    expect(CryptoAsset.usdt.nexoSpotUrl, isNull);
  });

  testWidgets('copies unsigned sell amount and buy USDT from rebalance diffs', (
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

    tester.view.physicalSize = const Size(800, 2800);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.reset();
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      );
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          holdingRepositoryProvider.overrideWithValue(
            _MemoryHoldingRepository(holdings),
          ),
          rateRepositoryProvider.overrideWithValue(_FakeRateRepository(rates)),
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

    String? clipboardText;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (methodCall) async {
        if (methodCall.method == 'Clipboard.setData') {
          clipboardText = (methodCall.arguments as Map)['text'] as String?;
        }
        return null;
      },
    );

    await tester.tap(find.byKey(const ValueKey('rebalance-copy-BTC')));
    await tester.pump();
    expect(clipboardText, '0.3');
    expect(find.text('0.3 をコピーしました'), findsOneWidget);

    ScaffoldMessenger.of(
      tester.element(find.byType(DashboardScreen)),
    ).clearSnackBars();
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('rebalance-copy-HYPE')));
    await tester.pump();
    expect(clipboardText, '15,000');
    expect(find.text('15,000 をコピーしました'), findsOneWidget);
  });

  testWidgets('shows BTC profit against the oldest daily snapshot', (
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

    tester.view.physicalSize = const Size(800, 2800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          holdingRepositoryProvider.overrideWithValue(
            _MemoryHoldingRepository(holdings),
          ),
          rateRepositoryProvider.overrideWithValue(_FakeRateRepository(rates)),
          dailySnapshotRepositoryProvider.overrideWithValue(
            _FakeDailySnapshotRepository([
              DailySnapshot(
                dayKey: '2026-08-20',
                recordedAt: DateTime(2026, 8, 20),
                totalUsdt: 100000,
                totalBtc: 1,
                assets: const {},
              ),
              DailySnapshot(
                dayKey: '2026-08-01',
                recordedAt: DateTime(2026, 8, 1),
                totalUsdt: 99000,
                totalBtc: 0.99,
                assets: const {},
              ),
            ]),
          ),
          rebalanceProfitRepositoryProvider.overrideWithValue(
            _FakeRebalanceProfitRepository(),
          ),
        ],
        child: const MaterialApp(home: DashboardScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('1 BTC'), findsOneWidget);
    expect(find.text('+0.01BTC(1000USDT)'), findsOneWidget);
  });
}
