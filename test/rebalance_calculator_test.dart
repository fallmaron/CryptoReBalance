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
      CryptoAsset.nexo: 1,
      CryptoAsset.usdt: 1,
    },
  );

  test('uses USDT+NEXO as 15% and NEXO as 11% of NX total', () {
    final snapshot = RebalanceCalculator.calculate(
      holdings: const {
        CryptoAsset.btc: 1,
        CryptoAsset.hype: 0,
        CryptoAsset.nexo: 0,
        CryptoAsset.usdt: 0,
      },
      nxHoldings: const {
        CryptoAsset.btc: 1,
        CryptoAsset.hype: 0,
        CryptoAsset.nexo: 0,
        CryptoAsset.usdt: 0,
      },
      rates: rates,
    );

    expect(snapshot.totalUsdt, 100000);
    expect(snapshot.totalBtc, 1);
    expect(snapshot.nxTotalUsdt, 100000);
    expect(snapshot.usdtNexoTargetWeight, 0.15);
    expect(snapshot.nexoShareOfNxTarget, 0.11);

    final btc = snapshot.lineOf(CryptoAsset.btc);
    expect(btc.targetUsdt, 70000);
    expect(btc.diffAmount, closeTo(-0.3, 0.0000001));
    expect(btc.needsSell, isTrue);

    final hype = snapshot.lineOf(CryptoAsset.hype);
    expect(hype.targetUsdt, 15000);
    expect(hype.targetAmount, closeTo(300, 0.0000001));
    expect(hype.needsBuy, isTrue);

    final nexo = snapshot.lineOf(CryptoAsset.nexo);
    expect(nexo.targetUsdt, 11000);
    expect(nexo.targetAmount, 11000);
    expect(nexo.needsBuy, isTrue);

    final usdt = snapshot.lineOf(CryptoAsset.usdt);
    expect(usdt.targetUsdt, 4000);
    expect(usdt.targetAmount, 4000);
    expect(usdt.needsBuy, isTrue);
  });

  test('reduces NEXO target when NX is only part of the portfolio', () {
    final snapshot = RebalanceCalculator.calculate(
      holdings: const {
        CryptoAsset.btc: 1,
        CryptoAsset.hype: 0,
        CryptoAsset.nexo: 0,
        CryptoAsset.usdt: 0,
      },
      nxHoldings: const {
        CryptoAsset.btc: 0.5,
      },
      rates: rates,
    );

    expect(snapshot.nxTotalUsdt, 50000);
    expect(snapshot.lineOf(CryptoAsset.nexo).targetUsdt, 5500);
    expect(snapshot.lineOf(CryptoAsset.usdt).targetUsdt, 9500);
  });

  test('returns zero weights when there are no holdings', () {
    final snapshot = RebalanceCalculator.calculate(
      holdings: const {
        CryptoAsset.btc: 0,
        CryptoAsset.hype: 0,
        CryptoAsset.nexo: 0,
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
