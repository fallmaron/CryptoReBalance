import '../../core/constants/app_constants.dart';
import '../models/crypto_asset.dart';
import '../models/market_rates.dart';
import '../models/rebalance_snapshot.dart';

abstract final class RebalanceCalculator {
  static RebalanceSnapshot calculate({
    required Map<CryptoAsset, double> holdings,
    required MarketRates rates,
    Map<CryptoAsset, double> targetWeights = AppConstants.targetWeights,
  }) {
    var totalUsdt = 0.0;
    final currentUsdt = <CryptoAsset, double>{};
    for (final asset in CryptoAsset.values) {
      final amount = holdings[asset] ?? 0;
      final value = amount * rates.priceOf(asset);
      currentUsdt[asset] = value;
      totalUsdt += value;
    }

    final lines = <AssetRebalance>[];
    for (final asset in CryptoAsset.values) {
      final weight = targetWeights[asset] ?? 0;
      final amount = holdings[asset] ?? 0;
      final assetUsdt = currentUsdt[asset]!;
      final price = rates.priceOf(asset);
      final targetUsdt = totalUsdt * weight;
      final targetAmount = price == 0 ? 0.0 : targetUsdt / price;
      lines.add(
        AssetRebalance(
          asset: asset,
          currentAmount: amount,
          currentUsdt: assetUsdt,
          currentWeight: totalUsdt == 0 ? 0 : assetUsdt / totalUsdt,
          targetWeight: weight,
          targetAmount: targetAmount,
          targetUsdt: targetUsdt,
          diffAmount: targetAmount - amount,
          diffUsdt: targetUsdt - assetUsdt,
        ),
      );
    }

    final btcPrice = rates.priceOf(CryptoAsset.btc);
    final totalBtc = btcPrice == 0 ? 0.0 : totalUsdt / btcPrice;

    return RebalanceSnapshot(
      totalUsdt: totalUsdt,
      totalBtc: totalBtc,
      lines: lines,
    );
  }
}
