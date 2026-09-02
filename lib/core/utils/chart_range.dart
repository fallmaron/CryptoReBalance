class ChartYRange {
  const ChartYRange({
    required this.min,
    required this.max,
    required this.interval,
  });

  final double min;
  final double max;
  final double interval;

  /// 変化が見えるよう、データ範囲の外側に余白を取る。0始まりにはしない。
  factory ChartYRange.fromValues(Iterable<double> values) {
    if (values.isEmpty) {
      return const ChartYRange(min: 0, max: 1, interval: 0.25);
    }
    var lo = values.first;
    var hi = values.first;
    for (final value in values) {
      if (value < lo) {
        lo = value;
      }
      if (value > hi) {
        hi = value;
      }
    }
    final span = hi - lo;
    final pad = span == 0
        ? (lo.abs() < 1e-12 ? 0.01 : lo.abs() * 0.02)
        : span * 0.18;
    final min = lo - pad;
    final max = hi + pad;
    final interval = (max - min) / 4;
    return ChartYRange(
      min: min,
      max: max,
      interval: interval == 0 ? 1 : interval,
    );
  }
}
