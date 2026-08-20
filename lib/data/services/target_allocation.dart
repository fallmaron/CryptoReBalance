import '../../core/constants/app_constants.dart';

abstract final class TargetAllocation {
  static const hypeWeightAtOrBelow50 = 0.15;
  static const hypeWeightAtOrAbove100 = 0.10;
  static const hypeLowRate = 50.0;
  static const hypeHighRate = 100.0;

  /// HYPE/USDT レートから目標保有率を返す。0.1% 単位。
  static double hypeWeight(double hypeUsdtRate) {
    if (hypeUsdtRate >= hypeHighRate) {
      return hypeWeightAtOrAbove100;
    }
    if (hypeUsdtRate <= hypeLowRate) {
      return hypeWeightAtOrBelow50;
    }
    final progress =
        (hypeUsdtRate - hypeLowRate) / (hypeHighRate - hypeLowRate);
    final raw =
        hypeWeightAtOrBelow50 -
        progress * (hypeWeightAtOrBelow50 - hypeWeightAtOrAbove100);
    return _roundToTenthPercent(raw);
  }

  /// HYPE から減らした分を BTC に足す。70%〜75%。
  static double btcWeight(double hypeWeight) {
    return 1.0 - AppConstants.usdtNexoWeight - hypeWeight;
  }

  static double _roundToTenthPercent(double weight) {
    return (weight * 1000).round() / 1000;
  }
}
