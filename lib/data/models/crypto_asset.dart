enum CryptoAsset {
  btc('BTC'),
  hype('HYPE'),
  nexo('NEXO'),
  usdt('USDT');

  const CryptoAsset(this.symbol);

  final String symbol;

  static const _nexoSpotBase = 'https://platform.nexo.com/spot';

  String? get nexoSpotUrl => switch (this) {
    CryptoAsset.btc => '$_nexoSpotBase?pair=BTC_USDT',
    CryptoAsset.hype => '$_nexoSpotBase?pair=HYPE_USDT',
    CryptoAsset.nexo => '$_nexoSpotBase?pair=NEXO_USDT',
    CryptoAsset.usdt => null,
  };

  static CryptoAsset? fromSymbol(String symbol) {
    for (final asset in CryptoAsset.values) {
      if (asset.symbol == symbol.toUpperCase()) {
        return asset;
      }
    }
    return null;
  }
}
