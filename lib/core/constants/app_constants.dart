import '../../data/models/crypto_asset.dart';
import 'api_keys.dart';

abstract final class AppConstants {
  static const appName = 'CryptReBalance';

  static const cmcListingsUrl =
      'https://pro-api.coinmarketcap.com/v1/cryptocurrency/listings/latest';
  static const cmcApiKey = ApiKeys.coinMarketCap;
  static const cmcPageSize = 200;
  static const cmcMaxStart = 1000;

  static const Map<CryptoAsset, double> targetWeights = {
    CryptoAsset.btc: 0.70,
    CryptoAsset.hype: 0.15,
    CryptoAsset.usdt: 0.15,
  };
}
