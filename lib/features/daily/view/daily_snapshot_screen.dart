import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/theme/app_colors.dart';
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
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
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
