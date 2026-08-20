enum CryptoAsset {
  btc('BTC'),
  hype('HYPE'),
  usdt('USDT');

  const CryptoAsset(this.symbol);

  final String symbol;

  static CryptoAsset? fromSymbol(String symbol) {
    for (final asset in CryptoAsset.values) {
      if (asset.symbol == symbol.toUpperCase()) {
        return asset;
      }
    }
    return null;
  }
}
