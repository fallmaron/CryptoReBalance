import '../models/crypto_asset.dart';
import '../models/daily_snapshot.dart';

abstract final class DailySnapshotCsv {
  static const displayAssets = [
    CryptoAsset.btc,
    CryptoAsset.hype,
    CryptoAsset.usdt,
    CryptoAsset.nexo,
  ];

  static String build(List<DailySnapshot> snapshots) {
    final header = [
      '日付',
      '記録日時',
      '総資産USDT',
      '総資産BTC',
      for (final asset in displayAssets) ...[
        '${asset.symbol}現在量',
        '${asset.symbol}USDT建',
        '${asset.symbol}目標量',
        '${asset.symbol}現在比',
        '${asset.symbol}目標比',
      ],
    ];
    final rows = [
      header,
      for (final snapshot in snapshots)
        [
          snapshot.dayKey,
          snapshot.recordedAt.toIso8601String(),
          '${snapshot.totalUsdt}',
          '${snapshot.totalBtc}',
          for (final asset in displayAssets) ...[
            '${snapshot.assetOf(asset).amount}',
            '${snapshot.assetOf(asset).usdt}',
            '${snapshot.assetOf(asset).targetAmount}',
            '${snapshot.assetOf(asset).currentWeight}',
            '${snapshot.assetOf(asset).targetWeight}',
          ],
        ],
    ];
    return '\uFEFF${rows.map(_csvLine).join('\n')}\n';
  }

  static String _csvLine(List<String> fields) {
    return fields.map(_escape).join(',');
  }

  static String _escape(String value) {
    if (value.contains(',') ||
        value.contains('"') ||
        value.contains('\n') ||
        value.contains('\r')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }
}
