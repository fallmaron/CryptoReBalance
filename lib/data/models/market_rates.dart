import 'crypto_asset.dart';

class MarketRates {
  const MarketRates({
    required this.fetchedAt,
    required this.pricesUsdt,
  });

  final DateTime fetchedAt;
  final Map<CryptoAsset, double> pricesUsdt;

  double priceOf(CryptoAsset asset) {
    final price = pricesUsdt[asset];
    if (price == null) {
      throw StateError('Rate missing for ${asset.symbol}');
    }
    return price;
  }

  bool get isComplete =>
      CryptoAsset.values.every((asset) => pricesUsdt.containsKey(asset));

  /// HYPE 1枚あたりの BTC 建て価格。
  double get hypePerBtc {
    final btc = priceOf(CryptoAsset.btc);
    if (btc == 0) {
      return 0;
    }
    return priceOf(CryptoAsset.hype) / btc;
  }
}
