import '../models/crypto_asset.dart';
import '../models/holding_entry_kind.dart';
import '../models/holding_record.dart';
import '../models/market_rates.dart';
import '../models/rebalance_profit.dart';
import '../models/storage_location.dart';

/// 保管場所ごとに、直近のリバランス実施有無の差を現在レートで確定する。
///
/// その場所で直近リバランスから今回までの場所移動による増減は除外する。
abstract final class RebalanceProfitCalculator {
  static RebalanceProfit? evaluate({
    required List<HoldingRecord> records,
    required HoldingRecord current,
    required MarketRates rates,
    required DateTime recordedAt,
  }) {
    if (current.kind != HoldingEntryKind.rebalance || current.id == null) {
      return null;
    }

    final atLocation = records
        .where((record) => record.location == current.location)
        .toList()
      ..sort(_compare);

    HoldingRecord? previous;
    for (final record in atLocation.reversed) {
      if (record.id == current.id) {
        continue;
      }
      if (record.kind == HoldingEntryKind.rebalance &&
          _compare(record, current) < 0) {
        previous = record;
        break;
      }
    }
    if (previous == null ||
        previous.id == null ||
        previous.id == current.id) {
      return null;
    }

    HoldingRecord? before;
    for (final record in atLocation.reversed) {
      if (_compare(record, previous) < 0) {
        before = record;
        break;
      }
    }

    final withoutUsdt = before == null ? 0.0 : _usdtValue(before, rates);
    final withUsdt = _usdtValue(previous, rates);
    final beforeId = before?.id ?? previous.id!;

    return RebalanceProfit(
      recordedAt: recordedAt,
      location: current.location,
      holdingId: current.id,
      sessionStartedAt: (before ?? previous).recordedAt,
      sessionEndedAt: previous.recordedAt,
      sessionStartId: beforeId,
      sessionEndId: previous.id!,
      withUsdt: withUsdt,
      withoutUsdt: withoutUsdt,
      profitUsdt: withUsdt - withoutUsdt,
    );
  }

  /// いまリバランス登録した場合に確定する、各保管場所の前回リバランス損益。
  static List<RebalanceProfit> previewNow({
    required List<HoldingRecord> records,
    required MarketRates rates,
    required DateTime now,
  }) {
    final previews = <RebalanceProfit>[];
    for (final location in StorageLocation.values) {
      final atLocation = records
          .where((record) => record.location == location)
          .toList()
        ..sort(_compare);
      HoldingRecord? lastRebalance;
      for (final record in atLocation.reversed) {
        if (record.kind == HoldingEntryKind.rebalance && record.id != null) {
          lastRebalance = record;
          break;
        }
      }
      if (lastRebalance == null) {
        continue;
      }

      HoldingRecord? before;
      for (final record in atLocation.reversed) {
        if (_compare(record, lastRebalance) < 0) {
          before = record;
          break;
        }
      }

      final withoutUsdt = before == null ? 0.0 : _usdtValue(before, rates);
      final withUsdt = _usdtValue(lastRebalance, rates);
      previews.add(
        RebalanceProfit(
          recordedAt: now,
          location: location,
          sessionStartedAt: (before ?? lastRebalance).recordedAt,
          sessionEndedAt: lastRebalance.recordedAt,
          sessionStartId: before?.id ?? lastRebalance.id!,
          sessionEndId: lastRebalance.id!,
          withUsdt: withUsdt,
          withoutUsdt: withoutUsdt,
          profitUsdt: withUsdt - withoutUsdt,
        ),
      );
    }
    return previews;
  }

  static HoldingRecord? latestRebalance(List<HoldingRecord> records) {
    HoldingRecord? latest;
    for (final record in records) {
      if (record.kind != HoldingEntryKind.rebalance) {
        continue;
      }
      if (latest == null || _compare(latest, record) < 0) {
        latest = record;
      }
    }
    return latest;
  }

  static int _compare(HoldingRecord a, HoldingRecord b) {
    final byTime = a.recordedAt.millisecondsSinceEpoch.compareTo(
      b.recordedAt.millisecondsSinceEpoch,
    );
    if (byTime != 0) {
      return byTime;
    }
    return (a.id ?? 0).compareTo(b.id ?? 0);
  }

  static double _usdtValue(HoldingRecord record, MarketRates rates) {
    var total = 0.0;
    for (final asset in CryptoAsset.values) {
      total += record.amountOf(asset) * rates.priceOf(asset);
    }
    return total;
  }
}
