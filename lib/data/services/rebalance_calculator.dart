import '../../core/constants/app_constants.dart';
import '../models/crypto_asset.dart';
import '../models/market_rates.dart';
import '../models/rebalance_snapshot.dart';

abstract final class RebalanceCalculator {
  static RebalanceSnapshot calculate({
    required Map<CryptoAsset, double> holdings,
    required MarketRates rates,
    Map<CryptoAsset, double> nxHoldings = const {},
  }) {
    var totalUsdt = 0.0;
    final currentUsdt = <CryptoAsset, double>{};
    for (final asset in CryptoAsset.values) {
      final amount = holdings[asset] ?? 0;
      final value = amount * rates.priceOf(asset);
      currentUsdt[asset] = value;
      totalUsdt += value;
    }

    var nxTotalUsdt = 0.0;
    for (final asset in CryptoAsset.values) {
      nxTotalUsdt += (nxHoldings[asset] ?? 0) * rates.priceOf(asset);
    }

    final targetUsdtByAsset = _targetUsdt(
      totalUsdt: totalUsdt,
      nxTotalUsdt: nxTotalUsdt,
    );

    final lines = <AssetRebalance>[];
    for (final asset in CryptoAsset.values) {
      final amount = holdings[asset] ?? 0;
      final assetUsdt = currentUsdt[asset]!;
      final price = rates.priceOf(asset);
      final targetUsdt = targetUsdtByAsset[asset]!;
      final targetAmount = price == 0 ? 0.0 : targetUsdt / price;
      lines.add(
        AssetRebalance(
          asset: asset,
          currentAmount: amount,
          currentUsdt: assetUsdt,
          currentWeight: totalUsdt == 0 ? 0 : assetUsdt / totalUsdt,
          targetWeight: totalUsdt == 0 ? 0 : targetUsdt / totalUsdt,
          targetAmount: targetAmount,
          targetUsdt: targetUsdt,
          diffAmount: targetAmount - amount,
          diffUsdt: targetUsdt - assetUsdt,
        ),
      );
    }

    final btcPrice = rates.priceOf(CryptoAsset.btc);
    final totalBtc = btcPrice == 0 ? 0.0 : totalUsdt / btcPrice;
    final usdtNexoCurrent =
        currentUsdt[CryptoAsset.usdt]! + currentUsdt[CryptoAsset.nexo]!;

    return RebalanceSnapshot(
      totalUsdt: totalUsdt,
      totalBtc: totalBtc,
      nxTotalUsdt: nxTotalUsdt,
      usdtNexoCurrentWeight: totalUsdt == 0 ? 0 : usdtNexoCurrent / totalUsdt,
      usdtNexoTargetWeight: totalUsdt == 0 ? 0 : AppConstants.usdtNexoWeight,
      nexoShareOfNxCurrent: nxTotalUsdt == 0
          ? 0
          : currentUsdt[CryptoAsset.nexo]! / nxTotalUsdt,
      nexoShareOfNxTarget: AppConstants.nexoShareOfNx,
      lines: lines,
    );
  }

  static Map<CryptoAsset, double> _targetUsdt({
    required double totalUsdt,
    required double nxTotalUsdt,
  }) {
    final nexoTarget = nxTotalUsdt * AppConstants.nexoShareOfNx;
    final usdtNexoTarget = totalUsdt * AppConstants.usdtNexoWeight;
    return {
      CryptoAsset.btc: totalUsdt * AppConstants.targetWeights[CryptoAsset.btc]!,
      CryptoAsset.hype:
          totalUsdt * AppConstants.targetWeights[CryptoAsset.hype]!,
      CryptoAsset.nexo: nexoTarget,
      CryptoAsset.usdt: usdtNexoTarget - nexoTarget,
    };
  }
}
