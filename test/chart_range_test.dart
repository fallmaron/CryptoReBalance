import 'package:cryptrebalance/core/utils/chart_range.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('pads around a narrow range so changes stay visible', () {
    final range = ChartYRange.fromValues(const [1.00, 1.02, 1.01]);
    expect(range.min, lessThan(1.00));
    expect(range.max, greaterThan(1.02));
    expect(range.max - range.min, closeTo(0.02 * 1.36, 0.0001));
  });

  test('does not force the axis to start at zero', () {
    final range = ChartYRange.fromValues(const [0.99, 1.01]);
    expect(range.min, greaterThan(0.5));
  });

  test('adds relative padding when all values are equal', () {
    final range = ChartYRange.fromValues(const [1.0, 1.0, 1.0]);
    expect(range.min, closeTo(0.98, 0.0000001));
    expect(range.max, closeTo(1.02, 0.0000001));
  });
}
