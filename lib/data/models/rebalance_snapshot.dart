import 'crypto_asset.dart';

class AssetRebalance {
  const AssetRebalance({
    required this.asset,
    required this.currentAmount,
    required this.currentUsdt,
    required this.currentWeight,
    required this.targetWeight,
    required this.targetAmount,
    required this.targetUsdt,
    required this.diffAmount,
    required this.diffUsdt,
  });

  final CryptoAsset asset;
  final double currentAmount;
  final double currentUsdt;
  final double currentWeight;
  final double targetWeight;
  final double targetAmount;
  final double targetUsdt;
  final double diffAmount;
  final double diffUsdt;

  bool get needsBuy => diffAmount > 0;
  bool get needsSell => diffAmount < 0;
}

class RebalanceSnapshot {
  const RebalanceSnapshot({
    required this.totalUsdt,
    required this.totalBtc,
    required this.lines,
  });

  final double totalUsdt;
  final double totalBtc;
  final List<AssetRebalance> lines;

  AssetRebalance lineOf(CryptoAsset asset) {
    return lines.firstWhere((line) => line.asset == asset);
  }
}
