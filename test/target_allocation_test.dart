import 'package:cryptrebalance/data/services/target_allocation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('uses 15% at or below 50 and 10% at or above 100', () {
    expect(TargetAllocation.hypeWeight(50), 0.15);
    expect(TargetAllocation.hypeWeight(10), 0.15);
    expect(TargetAllocation.hypeWeight(100), 0.10);
    expect(TargetAllocation.hypeWeight(200), 0.10);
  });

  test('interpolates in 0.1% steps between 50 and 100', () {
    expect(TargetAllocation.hypeWeight(75), 0.125);
    expect(TargetAllocation.hypeWeight(60), 0.14);
    expect(TargetAllocation.hypeWeight(51), 0.149);
    expect(TargetAllocation.hypeWeight(99), 0.101);
  });

  test('adds the HYPE reduction onto BTC (70% to 75%)', () {
    expect(TargetAllocation.btcWeight(0.15), 0.70);
    expect(TargetAllocation.btcWeight(0.10), 0.75);
    expect(TargetAllocation.btcWeight(0.125), 0.725);
  });
}
