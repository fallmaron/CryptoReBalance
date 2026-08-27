import 'package:cryptrebalance/data/models/crypto_asset.dart';
import 'package:cryptrebalance/data/models/holding_entry_kind.dart';
import 'package:cryptrebalance/data/models/holding_record.dart';
import 'package:cryptrebalance/data/models/market_rates.dart';
import 'package:cryptrebalance/data/models/storage_location.dart';
import 'package:cryptrebalance/data/services/rebalance_profit_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 8, 26, 10);
  final ratesNow = MarketRates(
    fetchedAt: now,
    pricesUsdt: const {
      CryptoAsset.btc: 200000,
      CryptoAsset.hype: 80,
      CryptoAsset.nexo: 1,
      CryptoAsset.usdt: 1,
    },
  );

  HoldingRecord record({
    required int id,
    required DateTime at,
    required StorageLocation location,
    required HoldingEntryKind kind,
    double btc = 0,
    double hype = 0,
    double nexo = 0,
    double usdt = 0,
  }) {
    return HoldingRecord(
      id: id,
      recordedAt: at,
      location: location,
      kind: kind,
      amounts: {
        CryptoAsset.btc: btc,
        CryptoAsset.hype: hype,
        CryptoAsset.nexo: nexo,
        CryptoAsset.usdt: usdt,
      },
    );
  }

  test('returns null when the location has no previous rebalance', () {
    final current = record(
      id: 2,
      at: DateTime(2026, 8, 20),
      location: StorageLocation.nx,
      kind: HoldingEntryKind.rebalance,
      btc: 0.7,
      usdt: 30000,
    );
    final records = [
      record(
        id: 1,
        at: DateTime(2026, 8, 1),
        location: StorageLocation.nx,
        kind: HoldingEntryKind.locationMove,
        btc: 1,
      ),
      current,
    ];

    expect(
      RebalanceProfitCalculator.evaluate(
        records: records,
        current: current,
        rates: ratesNow,
        recordedAt: now,
      ),
      isNull,
    );
  });

  test('does not treat the current save as the previous rebalance', () {
    final savedAt = DateTime(2026, 8, 20, 10, 0, 0, 123, 456);
    final current = record(
      id: 2,
      at: savedAt,
      location: StorageLocation.nx,
      kind: HoldingEntryKind.rebalance,
      btc: 0.7,
      usdt: 30000,
    );
    final fromDb = record(
      id: 2,
      at: DateTime.fromMillisecondsSinceEpoch(savedAt.millisecondsSinceEpoch),
      location: StorageLocation.nx,
      kind: HoldingEntryKind.rebalance,
      btc: 0.7,
      usdt: 30000,
    );
    final records = [
      record(
        id: 1,
        at: DateTime(2026, 8, 1),
        location: StorageLocation.nx,
        kind: HoldingEntryKind.locationMove,
        btc: 1,
      ),
      fromDb,
    ];

    expect(
      RebalanceProfitCalculator.evaluate(
        records: records,
        current: current,
        rates: ratesNow,
        recordedAt: savedAt,
      ),
      isNull,
    );
  });

  test('uses current prices for that location last rebalance vs not', () {
    final current = record(
      id: 3,
      at: DateTime(2026, 8, 20),
      location: StorageLocation.nx,
      kind: HoldingEntryKind.rebalance,
      btc: 0.6,
      usdt: 50000,
    );
    final records = [
      record(
        id: 1,
        at: DateTime(2026, 7, 1),
        location: StorageLocation.nx,
        kind: HoldingEntryKind.locationMove,
        btc: 1,
      ),
      record(
        id: 2,
        at: DateTime(2026, 7, 10),
        location: StorageLocation.nx,
        kind: HoldingEntryKind.rebalance,
        btc: 0.7,
        usdt: 30000,
      ),
      current,
    ];

    final profit = RebalanceProfitCalculator.evaluate(
      records: records,
      current: current,
      rates: ratesNow,
      recordedAt: now,
    );

    // with: 0.7 * 200000 + 30000 = 170000
    // without: 1.0 * 200000 = 200000
    expect(profit, isNotNull);
    expect(profit!.location, StorageLocation.nx);
    expect(profit.withUsdt, 170000);
    expect(profit.withoutUsdt, 200000);
    expect(profit.profitUsdt, -30000);
    expect(profit.sessionEndId, 2);
    expect(profit.holdingId, 3);
  });

  test('excludes location-move quantity changes between rebalances', () {
    final current = record(
      id: 5,
      at: DateTime(2026, 8, 20),
      location: StorageLocation.nx,
      kind: HoldingEntryKind.rebalance,
      btc: 0.5,
      usdt: 80000,
    );
    final records = [
      record(
        id: 1,
        at: DateTime(2026, 7, 1),
        location: StorageLocation.nx,
        kind: HoldingEntryKind.locationMove,
        btc: 1,
      ),
      record(
        id: 2,
        at: DateTime(2026, 7, 10),
        location: StorageLocation.nx,
        kind: HoldingEntryKind.rebalance,
        btc: 0.7,
        usdt: 30000,
      ),
      record(
        id: 3,
        at: DateTime(2026, 8, 1),
        location: StorageLocation.nx,
        kind: HoldingEntryKind.locationMove,
        btc: 0.7,
        usdt: 40000,
      ),
      record(
        id: 4,
        at: DateTime(2026, 8, 2),
        location: StorageLocation.le,
        kind: HoldingEntryKind.locationMove,
        btc: 0.1,
      ),
      current,
    ];

    final profit = RebalanceProfitCalculator.evaluate(
      records: records,
      current: current,
      rates: ratesNow,
      recordedAt: now,
    );

    expect(profit, isNotNull);
    expect(profit!.profitUsdt, -30000);
  });

  test('calculates each location independently', () {
    final nxCurrent = record(
      id: 4,
      at: DateTime(2026, 8, 20),
      location: StorageLocation.nx,
      kind: HoldingEntryKind.rebalance,
      btc: 0.5,
      usdt: 40000,
    );
    final leCurrent = record(
      id: 5,
      at: DateTime(2026, 8, 21),
      location: StorageLocation.le,
      kind: HoldingEntryKind.rebalance,
      hype: 50,
    );
    final records = [
      record(
        id: 1,
        at: DateTime(2026, 7, 1),
        location: StorageLocation.nx,
        kind: HoldingEntryKind.locationMove,
        btc: 1,
      ),
      record(
        id: 2,
        at: DateTime(2026, 7, 10),
        location: StorageLocation.nx,
        kind: HoldingEntryKind.rebalance,
        btc: 0.7,
        usdt: 30000,
      ),
      record(
        id: 3,
        at: DateTime(2026, 7, 10, 11),
        location: StorageLocation.le,
        kind: HoldingEntryKind.rebalance,
        hype: 100,
      ),
      nxCurrent,
      leCurrent,
    ];

    final nxProfit = RebalanceProfitCalculator.evaluate(
      records: records,
      current: nxCurrent,
      rates: ratesNow,
      recordedAt: now,
    );
    final leProfit = RebalanceProfitCalculator.evaluate(
      records: records,
      current: leCurrent,
      rates: ratesNow,
      recordedAt: now,
    );

    expect(nxProfit!.profitUsdt, -30000);
    expect(nxProfit.location, StorageLocation.nx);
    // LE previous rebalance 100 HYPE vs nothing before it
    expect(leProfit!.withUsdt, 8000);
    expect(leProfit.withoutUsdt, 0);
    expect(leProfit.profitUsdt, 8000);
    expect(leProfit.location, StorageLocation.le);
  });

  test('previews current rebalance profit per location', () {
    final records = [
      record(
        id: 1,
        at: DateTime(2026, 7, 1),
        location: StorageLocation.nx,
        kind: HoldingEntryKind.locationMove,
        btc: 1,
      ),
      record(
        id: 2,
        at: DateTime(2026, 7, 10),
        location: StorageLocation.nx,
        kind: HoldingEntryKind.rebalance,
        btc: 0.7,
        usdt: 30000,
      ),
    ];

    final previews = RebalanceProfitCalculator.previewNow(
      records: records,
      rates: ratesNow,
      now: now,
    );

    expect(previews, hasLength(1));
    expect(previews.single.location, StorageLocation.nx);
    expect(previews.single.profitUsdt, -30000);
  });
}
