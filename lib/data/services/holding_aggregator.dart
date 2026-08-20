import '../models/crypto_asset.dart';
import '../models/holding_record.dart';
import '../models/market_rates.dart';
import '../models/storage_location.dart';

abstract final class HoldingAggregator {
  /// 保管場所ごとに、記録日時が最も新しい保有量を返す。
  static Map<StorageLocation, HoldingRecord> latestByLocation(
    List<HoldingRecord> records,
  ) {
    final latest = <StorageLocation, HoldingRecord>{};
    for (final record in records) {
      final current = latest[record.location];
      if (current == null || record.recordedAt.isAfter(current.recordedAt)) {
        latest[record.location] = record;
      }
    }
    return latest;
  }

  static Map<CryptoAsset, double> totals(
    Map<StorageLocation, HoldingRecord> latest,
  ) {
    final totals = {for (final asset in CryptoAsset.values) asset: 0.0};
    for (final record in latest.values) {
      for (final asset in CryptoAsset.values) {
        totals[asset] = totals[asset]! + record.amountOf(asset);
      }
    }
    return totals;
  }

  static double usdtValue(HoldingRecord record, MarketRates rates) {
    var total = 0.0;
    for (final asset in CryptoAsset.values) {
      total += record.amountOf(asset) * rates.priceOf(asset);
    }
    return total;
  }

  static double locationShare({
    required HoldingRecord? record,
    required MarketRates rates,
    required double totalUsdt,
  }) {
    if (record == null || totalUsdt == 0) {
      return 0;
    }
    return usdtValue(record, rates) / totalUsdt;
  }
}
