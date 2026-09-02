import 'crypto_asset.dart';
import 'rebalance_snapshot.dart';

class DailyAssetSnapshot {
  const DailyAssetSnapshot({
    required this.amount,
    required this.usdt,
    required this.targetAmount,
    required this.currentWeight,
    required this.targetWeight,
  });

  final double amount;
  final double usdt;
  final double targetAmount;
  final double currentWeight;
  final double targetWeight;

  factory DailyAssetSnapshot.fromLine(AssetRebalance line) {
    return DailyAssetSnapshot(
      amount: line.currentAmount,
      usdt: line.currentUsdt,
      targetAmount: line.targetAmount,
      currentWeight: line.currentWeight,
      targetWeight: line.targetWeight,
    );
  }
}

class DailySnapshot {
  const DailySnapshot({
    this.id,
    required this.dayKey,
    required this.recordedAt,
    required this.totalUsdt,
    required this.totalBtc,
    required this.assets,
  });

  final int? id;
  final String dayKey;
  final DateTime recordedAt;
  final double totalUsdt;
  final double totalBtc;
  final Map<CryptoAsset, DailyAssetSnapshot> assets;

  DailyAssetSnapshot assetOf(CryptoAsset asset) {
    final value = assets[asset];
    if (value == null) {
      throw StateError('Daily snapshot missing ${asset.symbol}');
    }
    return value;
  }

  factory DailySnapshot.fromRebalance({
    required DateTime recordedAt,
    required RebalanceSnapshot rebalance,
  }) {
    return DailySnapshot(
      dayKey: dayKeyOf(recordedAt),
      recordedAt: recordedAt,
      totalUsdt: rebalance.totalUsdt,
      totalBtc: rebalance.totalBtc,
      assets: {
        for (final asset in CryptoAsset.values)
          asset: DailyAssetSnapshot.fromLine(rebalance.lineOf(asset)),
      },
    );
  }

  static String dayKeyOf(DateTime value) {
    final local = value.toLocal();
    final year = local.year.toString().padLeft(4, '0');
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  static DailySnapshot? oldestOf(List<DailySnapshot> snapshots) {
    if (snapshots.isEmpty) {
      return null;
    }
    return snapshots.reduce((left, right) {
      final byDay = left.dayKey.compareTo(right.dayKey);
      if (byDay != 0) {
        return byDay < 0 ? left : right;
      }
      return left.recordedAt.isBefore(right.recordedAt) ? left : right;
    });
  }
}
