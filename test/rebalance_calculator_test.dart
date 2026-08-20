import 'package:cryptrebalance/data/models/crypto_asset.dart';
import 'package:cryptrebalance/data/models/market_rates.dart';
import 'package:cryptrebalance/data/services/rebalance_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final rates = MarketRates(
    fetchedAt: DateTime(2026, 8, 20, 11),
    pricesUsdt: const {
      CryptoAsset.btc: 100000,
      CryptoAsset.hype: 50,
      CryptoAsset.usdt: 1,
    },
  );

  test('calculates target amounts and USDT diffs from 70/15/15 weights', () {
    final snapshot = RebalanceCalculator.calculate(
      holdings: const {
        CryptoAsset.btc: 1,
        CryptoAsset.hype: 0,
        CryptoAsset.usdt: 0,
      },
      rates: rates,
    );

    expect(snapshot.totalUsdt, 100000);
    expect(snapshot.totalBtc, 1);

    final btc = snapshot.lineOf(CryptoAsset.btc);
    expect(btc.targetUsdt, 70000);
    expect(btc.targetAmount, closeTo(0.7, 0.0000001));
    expect(btc.diffAmount, closeTo(-0.3, 0.0000001));
    expect(btc.diffUsdt, closeTo(-30000, 0.0000001));
    expect(btc.needsSell, isTrue);

    final hype = snapshot.lineOf(CryptoAsset.hype);
    expect(hype.targetUsdt, 15000);
    expect(hype.targetAmount, closeTo(300, 0.0000001));
    expect(hype.diffAmount, closeTo(300, 0.0000001));
    expect(hype.diffUsdt, 15000);
    expect(hype.needsBuy, isTrue);

    final usdt = snapshot.lineOf(CryptoAsset.usdt);
    expect(usdt.targetAmount, 15000);
    expect(usdt.diffAmount, 15000);
    expect(usdt.diffUsdt, 15000);
  });

  test('returns zero weights when there are no holdings', () {
    final snapshot = RebalanceCalculator.calculate(
      holdings: const {
        CryptoAsset.btc: 0,
        CryptoAsset.hype: 0,
        CryptoAsset.usdt: 0,
      },
      rates: rates,
    );

    expect(snapshot.totalUsdt, 0);
    expect(snapshot.totalBtc, 0);
    for (final line in snapshot.lines) {
      expect(line.currentWeight, 0);
      expect(line.targetAmount, 0);
      expect(line.diffAmount, 0);
    }
  });
}
