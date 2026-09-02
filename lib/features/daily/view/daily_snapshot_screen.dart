import 'dart:io';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/chart_range.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/crypto_asset.dart';
import '../../../data/models/daily_snapshot.dart';
import '../../../data/repositories/daily_snapshot_repository.dart';
import '../../../data/services/daily_snapshot_csv.dart';

class DailySnapshotScreen extends ConsumerWidget {
  const DailySnapshotScreen({super.key});

  static const _assets = DailySnapshotCsv.displayAssets;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncSnapshots = ref.watch(dailySnapshotsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('日次記録'),
        actions: [
          IconButton(
            onPressed: asyncSnapshots.maybeWhen(
              data: (snapshots) => snapshots.isEmpty
                  ? null
                  : () => _exportCsv(context, snapshots),
              orElse: () => null,
            ),
            icon: const Icon(Icons.file_download_outlined),
            tooltip: 'CSV出力',
          ),
        ],
      ),
      body: asyncSnapshots.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text(error.toString())),
        data: (snapshots) {
          if (snapshots.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'まだ日次記録がありません。\n起動時または更新ボタンでレートを取得した日に、1件保存されます。',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            );
          }
          final todayKey = DailySnapshot.dayKeyOf(DateTime.now());
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: _BtcHistoryChart(snapshots: snapshots),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                  itemCount: snapshots.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final snapshot = snapshots[index];
                    return _DailySnapshotCard(
                      snapshot: snapshot,
                      onDeleteToday: snapshot.dayKey == todayKey
                          ? () => _deleteToday(context, ref)
                          : null,
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  static Future<void> _exportCsv(
    BuildContext context,
    List<DailySnapshot> snapshots,
  ) async {
    try {
      final csv = DailySnapshotCsv.build(snapshots);
      final dir = await getTemporaryDirectory();
      final stamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final file = File(p.join(dir.path, 'cryptrebalance_daily_$stamp.csv'));
      await file.writeAsString(csv);
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'text/csv')],
          subject: 'CryptReBalance 日次記録',
        ),
      );
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('CSV出力に失敗しました: $error')),
      );
    }
  }

  static Future<void> _deleteToday(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('当日の記録を削除しますか？'),
          content: const Text(
            '今日の日次記録だけを削除します。過去の記録は残ります。次回のレート更新で再記録できます。',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('キャンセル'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('削除'),
            ),
          ],
        );
      },
    );
    if (confirmed != true) {
      return;
    }

    final dayKey = DailySnapshot.dayKeyOf(DateTime.now());
    final deleted = await ref
        .read(dailySnapshotRepositoryProvider)
        .deleteByDay(dayKey);
    ref.invalidate(dailySnapshotsProvider);
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(deleted ? '当日の記録を削除しました' : '当日の記録はありません'),
      ),
    );
  }
}

class _BtcHistoryChart extends StatelessWidget {
  const _BtcHistoryChart({required this.snapshots});

  final List<DailySnapshot> snapshots;

  @override
  Widget build(BuildContext context) {
    final points = DailySnapshot.chronological(snapshots);
    final values = [for (final item in points) item.totalBtc];
    final range = ChartYRange.fromValues(values);
    final lastIndex = points.length - 1;
    final xInterval = points.length <= 5
        ? 1.0
        : (points.length / 4).ceilToDouble();
    final baseline = points.first.totalBtc;
    final lineColors = [
      for (final point in points) _colorVsOldest(point.totalBtc, baseline),
    ];
    if (lineColors.length == 1) {
      lineColors.add(lineColors.first);
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'BTC換算の推移',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 180,
              child: LineChart(
                LineChartData(
                  minX: lastIndex == 0 ? -0.5 : 0,
                  maxX: lastIndex == 0 ? 0.5 : lastIndex.toDouble(),
                  minY: range.min,
                  maxY: range.max,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: range.interval,
                    getDrawingHorizontalLine: (_) => FlLine(
                      color: AppColors.border,
                      strokeWidth: 1,
                    ),
                  ),
                  borderData: FlBorderData(
                    show: true,
                    border: const Border(
                      left: BorderSide(color: AppColors.border),
                      bottom: BorderSide(color: AppColors.border),
                    ),
                  ),
                  extraLinesData: ExtraLinesData(
                    horizontalLines: [
                      HorizontalLine(
                        y: baseline,
                        color: AppColors.textSecondary,
                        strokeWidth: 1,
                        dashArray: const [6, 4],
                      ),
                    ],
                  ),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 56,
                        interval: range.interval,
                        getTitlesWidget: (value, meta) {
                          return SideTitleWidget(
                            meta: meta,
                            child: Text(
                              value.toStringAsFixed(4),
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 10,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 22,
                        interval: xInterval,
                        getTitlesWidget: (value, meta) {
                          final index = value.round();
                          if (index < 0 || index >= points.length) {
                            return const SizedBox.shrink();
                          }
                          if ((value - index).abs() > 0.01) {
                            return const SizedBox.shrink();
                          }
                          final parts = points[index].dayKey.split('-');
                          final label = parts.length == 3
                              ? '${parts[1]}/${parts[2]}'
                              : points[index].dayKey;
                          return SideTitleWidget(
                            meta: meta,
                            child: Text(
                              label,
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 10,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipColor: (_) => AppColors.surface,
                      getTooltipItems: (touched) {
                        return [
                          for (final spot in touched)
                            LineTooltipItem(
                              '${_tooltipDate(points, spot.x)}\n${Formatters.amount(CryptoAsset.btc, spot.y)} BTC',
                              TextStyle(
                                color: _colorVsOldest(spot.y, baseline),
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                        ];
                      },
                    ),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: [
                        for (var i = 0; i < points.length; i++)
                          FlSpot(i.toDouble(), points[i].totalBtc),
                      ],
                      isCurved: false,
                      gradient: LinearGradient(colors: lineColors),
                      barWidth: 2.5,
                      dotData: FlDotData(
                        getDotPainter: (spot, percent, bar, index) {
                          return FlDotCirclePainter(
                            radius: 3.5,
                            color: _colorVsOldest(spot.y, baseline),
                            strokeWidth: 0,
                          );
                        },
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        color: AppColors.buy.withValues(alpha: 0.18),
                        cutOffY: baseline,
                        applyCutOffY: true,
                      ),
                      aboveBarData: BarAreaData(
                        show: true,
                        color: AppColors.sell.withValues(alpha: 0.18),
                        cutOffY: baseline,
                        applyCutOffY: true,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Color _colorVsOldest(double value, double baseline) {
    if (value > baseline) {
      return AppColors.buy;
    }
    if (value < baseline) {
      return AppColors.sell;
    }
    return AppColors.textSecondary;
  }

  static String _tooltipDate(List<DailySnapshot> points, double x) {
    final index = x.round().clamp(0, points.length - 1);
    return points[index].dayKey.replaceAll('-', '/');
  }
}

class _DailySnapshotCard extends StatelessWidget {
  const _DailySnapshotCard({
    required this.snapshot,
    this.onDeleteToday,
  });

  final DailySnapshot snapshot;
  final VoidCallback? onDeleteToday;

  @override
  Widget build(BuildContext context) {
    const cellStyle = TextStyle(fontWeight: FontWeight.w600, fontSize: 11);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        snapshot.dayKey.replaceAll('-', '/'),
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        Formatters.dateTimeText(snapshot.recordedAt),
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                if (onDeleteToday != null)
                  IconButton(
                    onPressed: onDeleteToday,
                    tooltip: '当日分を削除',
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.delete_outline, color: AppColors.sell),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              '総資産  ${Formatters.usdt(snapshot.totalUsdt)} USDT',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            Text(
              '${Formatters.amount(CryptoAsset.btc, snapshot.totalBtc)} BTC',
              style: const TextStyle(
                color: AppColors.btc,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowHeight: 32,
                dataRowMinHeight: 32,
                dataRowMaxHeight: 36,
                columnSpacing: 12,
                horizontalMargin: 0,
                headingTextStyle: const TextStyle(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                ),
                columns: const [
                  DataColumn(label: Text('')),
                  DataColumn(label: Text('現在量'), numeric: true),
                  DataColumn(label: Text('USDT建'), numeric: true),
                  DataColumn(label: Text('目標量'), numeric: true),
                  DataColumn(label: Text('現在比'), numeric: true),
                  DataColumn(label: Text('目標比'), numeric: true),
                ],
                rows: [
                  for (final asset in DailySnapshotScreen._assets)
                    DataRow(
                      cells: [
                        DataCell(
                          Text(
                            asset.symbol,
                            style: TextStyle(
                              color: AppColors.forAsset(asset),
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        DataCell(
                          Text(
                            Formatters.amount(
                              asset,
                              snapshot.assetOf(asset).amount,
                            ),
                            style: cellStyle,
                          ),
                        ),
                        DataCell(
                          Text(
                            Formatters.usdt(snapshot.assetOf(asset).usdt),
                            style: cellStyle,
                          ),
                        ),
                        DataCell(
                          Text(
                            Formatters.amount(
                              asset,
                              snapshot.assetOf(asset).targetAmount,
                            ),
                            style: cellStyle,
                          ),
                        ),
                        DataCell(
                          Text(
                            Formatters.percent(
                              snapshot.assetOf(asset).currentWeight,
                            ),
                            style: cellStyle,
                          ),
                        ),
                        DataCell(
                          Text(
                            Formatters.percent(
                              snapshot.assetOf(asset).targetWeight,
                            ),
                            style: cellStyle,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
