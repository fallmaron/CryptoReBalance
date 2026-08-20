import 'package:cryptrebalance/data/models/crypto_asset.dart';
import 'package:cryptrebalance/data/models/holding_record.dart';
import 'package:cryptrebalance/data/models/storage_location.dart';
import 'package:cryptrebalance/data/services/holding_aggregator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  HoldingRecord record({
    required StorageLocation location,
    required DateTime recordedAt,
    double btc = 0,
    double hype = 0,
    double usdt = 0,
  }) {
    return HoldingRecord(
      recordedAt: recordedAt,
      location: location,
      amounts: {
        CryptoAsset.btc: btc,
        CryptoAsset.hype: hype,
        CryptoAsset.usdt: usdt,
      },
    );
  }

  test('keeps the newest record per location', () {
    final older = record(
      location: StorageLocation.nx,
      recordedAt: DateTime(2026, 8, 1, 10),
      btc: 1,
    );
    final newer = record(
      location: StorageLocation.nx,
      recordedAt: DateTime(2026, 8, 20, 11, 1, 2),
      btc: 2,
    );
    final le = record(
      location: StorageLocation.le,
      recordedAt: DateTime(2026, 8, 19),
      hype: 10,
    );

    final latest = HoldingAggregator.latestByLocation([older, le, newer]);

    expect(latest[StorageLocation.nx]!.amountOf(CryptoAsset.btc), 2);
    expect(latest[StorageLocation.le]!.amountOf(CryptoAsset.hype), 10);
    expect(latest.containsKey(StorageLocation.tr), isFalse);
  });

  test('sums latest holdings across locations', () {
    final latest = {
      StorageLocation.nx: record(
        location: StorageLocation.nx,
        recordedAt: DateTime(2026, 8, 20),
        btc: 0.5,
        usdt: 100,
      ),
      StorageLocation.rk: record(
        location: StorageLocation.rk,
        recordedAt: DateTime(2026, 8, 20),
        btc: 0.25,
        hype: 8,
      ),
    };

    final totals = HoldingAggregator.totals(latest);

    expect(totals[CryptoAsset.btc], 0.75);
    expect(totals[CryptoAsset.hype], 8);
    expect(totals[CryptoAsset.usdt], 100);
  });
}
