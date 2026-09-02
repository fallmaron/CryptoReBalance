import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/external_link.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/crypto_asset.dart';
import '../../../data/models/holding_record.dart';
import '../../../data/models/market_rates.dart';
import '../../../data/models/rebalance_snapshot.dart';
import '../../../data/models/daily_snapshot.dart';
import '../../../data/models/storage_location.dart';
import '../../../data/repositories/daily_snapshot_repository.dart';
import '../../../data/services/holding_aggregator.dart';
import '../../../data/services/target_allocation.dart';
import '../viewmodel/dashboard_viewmodel.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncData = ref.watch(dashboardViewModelProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppConstants.appName),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton.icon(
              onPressed: asyncData.isLoading
                  ? null
                  : () => ref.read(dashboardViewModelProvider.notifier).refreshRates(),
              icon: const Icon(Icons.sync, size: 18),
              label: const Text('更新'),
            ),
          ),
        ],
      ),
      body: asyncData.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _ErrorView(message: error.toString()),
        data: (data) => _DashboardBody(data: data),
      ),
    );
  }
}

class _DashboardBody extends StatelessWidget {
  const _DashboardBody({required this.data});

  final DashboardData data;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        if (data.isRefreshingRates) const LinearProgressIndicator(minHeight: 2),
        if (data.rateError != null) ...[
          _MessageBanner(
            text: data.rateError!,
            color: AppColors.sell,
          ),
          const SizedBox(height: 12),
        ],
        _TotalAssetCard(data: data),
        const SizedBox(height: 12),
        _RatesCard(data: data),
        const SizedBox(height: 12),
        _RebalanceCard(data: data),
        const SizedBox(height: 12),
        _AllocationCard(data: data),
        const SizedBox(height: 12),
        _LocationHoldingsCard(data: data),
        const SizedBox(height: 12),
        _TargetAllocationCard(data: data),
      ],
    );
  }
}

class _TotalAssetCard extends ConsumerWidget {
  const _TotalAssetCard({required this.data});

  final DashboardData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final totalUsdt = data.rebalance?.totalUsdt;
    final totalBtc = data.rebalance?.totalBtc;
    final snapshots = ref.watch(dailySnapshotsProvider);
    final oldest = snapshots.maybeWhen(
      data: DailySnapshot.oldestOf,
      orElse: () => null,
    );
    final profitBtc = totalBtc == null || oldest == null
        ? null
        : totalBtc - oldest.totalBtc;
    final btcPrice = data.rates?.priceOf(CryptoAsset.btc);
    final profitLine = profitBtc == null || btcPrice == null
        ? null
        : Formatters.btcProfitLine(
            profitBtc: profitBtc,
            btcPriceUsdt: btcPrice,
          );
    return _SectionCard(
      title: '総資産',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            totalUsdt == null ? '—' : '${Formatters.usdt(totalUsdt)} USDT',
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.6,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            totalBtc == null
                ? '—'
                : '${Formatters.amount(CryptoAsset.btc, totalBtc)} BTC',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
              color: AppColors.btc,
            ),
          ),
          if (profitLine != null) ...[
            const SizedBox(height: 4),
            Text(
              profitLine,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: profitBtc! >= 0 ? AppColors.buy : AppColors.sell,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RatesCard extends StatelessWidget {
  const _RatesCard({required this.data});

  final DashboardData data;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'レート',
      trailing: data.rates == null
          ? null
          : Text(
              Formatters.dateTimeText(data.rates!.fetchedAt),
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
      child: data.rates == null
          ? const Text(
              '更新ボタンでCoinMarketCapから取得します',
              style: TextStyle(color: AppColors.textSecondary),
            )
          : Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _RateTile(
                        label: 'BTC',
                        color: AppColors.btc,
                        value: Formatters.usdt(
                          data.rates!.priceOf(CryptoAsset.btc),
                        ),
                        change: _changeText(data, CryptoAsset.btc),
                      ),
                    ),
                    Expanded(
                      child: _RateTile(
                        label: 'HYPE/BTC',
                        color: AppColors.hype,
                        value: Formatters.pairRate(data.rates!.hypePerBtc),
                        change: _pairChangeText(data),
                      ),
                    ),
                    Expanded(
                      child: _RateTile(
                        label: 'HYPE',
                        color: AppColors.hype,
                        value: Formatters.usdt(
                          data.rates!.priceOf(CryptoAsset.hype),
                        ),
                        change: _changeText(data, CryptoAsset.hype),
                      ),
                    ),
                    Expanded(
                      child: _RateTile(
                        label: 'NEXO',
                        color: AppColors.nexo,
                        value: Formatters.usdt(
                          data.rates!.priceOf(CryptoAsset.nexo),
                        ),
                        change: _changeText(data, CryptoAsset.nexo),
                      ),
                    ),
                  ],
                ),
                if (data.lastRebalanceAt != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    data.rateChanges == null
                        ? '前回リバランス時点のレートがないため、変化率は表示できません'
                        : '前回リバランス後の変化  ${Formatters.dateTimeText(data.lastRebalanceAt!)}',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
    );
  }

  static String? _changeText(DashboardData data, CryptoAsset asset) {
    final changes = data.rateChanges;
    if (changes == null) {
      return null;
    }
    return Formatters.percent(changes[asset] ?? 0, signed: true);
  }

  static String? _pairChangeText(DashboardData data) {
    final changes = data.rateChanges;
    final rates = data.rates;
    if (changes == null || rates == null) {
      return null;
    }
    final btcChange = changes[CryptoAsset.btc] ?? 0;
    final hypeChange = changes[CryptoAsset.hype] ?? 0;
    if (btcChange <= -1) {
      return null;
    }
    final thenBtc = rates.priceOf(CryptoAsset.btc) / (1 + btcChange);
    final thenHype = rates.priceOf(CryptoAsset.hype) / (1 + hypeChange);
    if (thenBtc == 0) {
      return null;
    }
    final thenPair = thenHype / thenBtc;
    if (thenPair == 0) {
      return null;
    }
    return Formatters.percent(
      (rates.hypePerBtc - thenPair) / thenPair,
      signed: true,
    );
  }
}

class _RateTile extends StatelessWidget {
  const _RateTile({
    required this.label,
    required this.color,
    required this.value,
    this.change,
  });

  final String label;
  final Color color;
  final String value;
  final String? change;

  @override
  Widget build(BuildContext context) {
    final changeColor = change == null
        ? AppColors.textSecondary
        : change!.startsWith('+')
        ? AppColors.buy
        : change!.startsWith('-')
        ? AppColors.sell
        : AppColors.textSecondary;
    final size = Theme.of(context).textTheme.bodyMedium?.fontSize;
    return Column(
      children: [
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w700,
            fontSize: size,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: size,
          ),
        ),
        if (change != null) ...[
          const SizedBox(height: 2),
          Text(
            change!,
            style: TextStyle(
              color: changeColor,
              fontWeight: FontWeight.w700,
              fontSize: size,
            ),
          ),
        ],
      ],
    );
  }
}

class _AllocationCard extends StatelessWidget {
  const _AllocationCard({required this.data});

  final DashboardData data;

  @override
  Widget build(BuildContext context) {
    final snapshot = data.rebalance;
    return _SectionCard(
      title: '保有バランス',
      child: snapshot == null
          ? const Text(
              'レート取得後に現在比率と目標比率を表示します',
              style: TextStyle(color: AppColors.textSecondary),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowHeight: 36,
                    dataRowMinHeight: 36,
                    dataRowMaxHeight: 42,
                    columnSpacing: 14,
                    horizontalMargin: 8,
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
                      _assetRow(snapshot.lineOf(CryptoAsset.btc)),
                      _assetRow(snapshot.lineOf(CryptoAsset.hype)),
                      _summaryRow(
                        label: 'UT+NE',
                        color: AppColors.usdt,
                        currentAmount: Formatters.usdt(
                          snapshot.lineOf(CryptoAsset.usdt).currentUsdt +
                              snapshot.lineOf(CryptoAsset.nexo).currentUsdt,
                        ),
                        currentAmountUsdt: Formatters.usdt(
                          snapshot.lineOf(CryptoAsset.usdt).currentUsdt +
                              snapshot.lineOf(CryptoAsset.nexo).currentUsdt,
                        ),
                        targetAmount: Formatters.usdt(
                          snapshot.lineOf(CryptoAsset.usdt).targetUsdt +
                              snapshot.lineOf(CryptoAsset.nexo).targetUsdt,
                        ),
                        currentWeight: snapshot.usdtNexoCurrentWeight,
                        targetWeight: snapshot.usdtNexoTargetWeight,
                      ),
                      _assetRow(snapshot.lineOf(CryptoAsset.usdt)),
                      _assetRow(snapshot.lineOf(CryptoAsset.nexo)),
                      _summaryRow(
                        label: 'NE/NX',
                        color: AppColors.nexo,
                        currentAmount: Formatters.amount(
                          CryptoAsset.nexo,
                          snapshot.lineOf(CryptoAsset.nexo).currentAmount,
                        ),
                        currentAmountUsdt: Formatters.usdt(
                          snapshot.lineOf(CryptoAsset.nexo).currentUsdt,
                        ),
                        targetAmount: Formatters.amount(
                          CryptoAsset.nexo,
                          snapshot.lineOf(CryptoAsset.nexo).targetAmount,
                        ),
                        currentWeight: snapshot.nexoShareOfNxCurrent,
                        targetWeight: snapshot.nexoShareOfNxTarget,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'NX総資産 ${Formatters.usdt(snapshot.nxTotalUsdt)} USDT の '
                  '${Formatters.percent(snapshot.nexoShareOfNxTarget)} が NEXO 目標',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
    );
  }

  static DataRow _assetRow(AssetRebalance line) {
    return _summaryRow(
      label: line.asset.symbol,
      color: AppColors.forAsset(line.asset),
      currentAmount: Formatters.amount(line.asset, line.currentAmount),
      currentAmountUsdt: Formatters.usdt(line.currentUsdt),
      targetAmount: Formatters.amount(line.asset, line.targetAmount),
      currentWeight: line.currentWeight,
      targetWeight: line.targetWeight,
    );
  }

  static DataRow _summaryRow({
    required String label,
    required Color color,
    required String currentAmount,
    required String currentAmountUsdt,
    required String targetAmount,
    required double currentWeight,
    required double targetWeight,
  }) {
    const cellStyle = TextStyle(fontWeight: FontWeight.w600, fontSize: 11);
    return DataRow(
      cells: [
        DataCell(
          Text(
            label,
            style: TextStyle(color: color, fontWeight: FontWeight.w800),
          ),
        ),
        DataCell(Text(currentAmount, style: cellStyle)),
        DataCell(Text(currentAmountUsdt, style: cellStyle)),
        DataCell(Text(targetAmount, style: cellStyle)),
        DataCell(Text(Formatters.percent(currentWeight), style: cellStyle)),
        DataCell(Text(Formatters.percent(targetWeight), style: cellStyle)),
      ],
    );
  }
}

class _RebalanceCard extends StatelessWidget {
  const _RebalanceCard({required this.data});

  final DashboardData data;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'リバランス差分',
      child: data.rebalance == null
          ? const Text(
              '直近保有量とレートから、目標保有量との差分を計算します',
              style: TextStyle(color: AppColors.textSecondary),
            )
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowHeight: 36,
                dataRowMinHeight: 40,
                dataRowMaxHeight: 48,
                columnSpacing: 14,
                horizontalMargin: 8,
                headingTextStyle: const TextStyle(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                ),
                columns: const [
                  DataColumn(label: Text('')),
                  DataColumn(label: Text('差分'), numeric: true),
                  DataColumn(label: Text('USDT換算'), numeric: true),
                  DataColumn(label: Text('状態')),
                  DataColumn(label: Text('')),
                ],
                rows: [
                  for (final asset in [
                    CryptoAsset.btc,
                    CryptoAsset.hype,
                    CryptoAsset.usdt,
                    CryptoAsset.nexo,
                  ])
                    _rebalanceRow(context, data.rebalance!.lineOf(asset)),
                ],
              ),
            ),
    );
  }

  DataRow _rebalanceRow(BuildContext context, AssetRebalance line) {
    final actionColor = line.needsBuy
        ? AppColors.buy
        : line.needsSell
        ? AppColors.sell
        : AppColors.textSecondary;
    final actionLabel = line.needsBuy
        ? '不足（購入）'
        : line.needsSell
        ? '過剰（売却）'
        : '目標一致';
    const cellStyle = TextStyle(fontWeight: FontWeight.w600);
    final copyText = Formatters.rebalanceClipboardText(
      asset: line.asset,
      diffAmount: line.diffAmount,
      diffUsdt: line.diffUsdt,
    );
    final nexoSpotUrl = line.asset.nexoSpotUrl;
    return DataRow(
      cells: [
        DataCell(
          Text(
            line.asset.symbol,
            style: TextStyle(
              color: AppColors.forAsset(line.asset),
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        DataCell(
          Text(
            Formatters.amount(line.asset, line.diffAmount, signed: true),
            style: cellStyle.copyWith(color: actionColor),
          ),
        ),
        DataCell(
          Text(
            Formatters.usdt(line.diffUsdt, signed: true),
            style: cellStyle.copyWith(color: actionColor),
          ),
        ),
        DataCell(
          Text(
            actionLabel,
            style: TextStyle(
              color: actionColor,
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
        ),
        DataCell(
          SizedBox(
            width: nexoSpotUrl == null ? 40 : 80,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  key: ValueKey('rebalance-copy-${line.asset.symbol}'),
                  tooltip: 'コピー',
                  visualDensity: VisualDensity.compact,
                  iconSize: 18,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(
                    width: 40,
                    height: 40,
                  ),
                  onPressed: copyText == null
                      ? null
                      : () => _copyRebalanceValue(context, copyText),
                  icon: const Icon(Icons.copy),
                ),
                if (nexoSpotUrl != null)
                  IconButton(
                    key: ValueKey('rebalance-nexo-${line.asset.symbol}'),
                    tooltip: 'Nexoで取引',
                    visualDensity: VisualDensity.compact,
                    iconSize: 18,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints.tightFor(
                      width: 40,
                      height: 40,
                    ),
                    onPressed: () => _openNexoSpot(context, nexoSpotUrl),
                    icon: const Icon(Icons.open_in_new),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _copyRebalanceValue(BuildContext context, String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$text をコピーしました')),
    );
  }

  Future<void> _openNexoSpot(BuildContext context, String url) async {
    final opened = await openExternalLink(url);
    if (opened || !context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('ページを開けませんでした')),
    );
  }
}

class _LocationHoldingsCard extends StatelessWidget {
  const _LocationHoldingsCard({required this.data});

  final DashboardData data;

  static const _amountColumns = [
    CryptoAsset.btc,
    CryptoAsset.hype,
    CryptoAsset.usdt,
    CryptoAsset.nexo,
  ];

  @override
  Widget build(BuildContext context) {
    final rates = data.rates;
    final totalUsdt = data.rebalance?.totalUsdt ?? 0;
    const headerStyle = TextStyle(
      color: AppColors.textSecondary,
      fontWeight: FontWeight.w700,
      fontSize: 11,
    );
    const cellStyle = TextStyle(fontWeight: FontWeight.w600, fontSize: 11);

    return _SectionCard(
      title: '保管場所別 直近保有',
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowHeight: 36,
          dataRowMinHeight: 36,
          dataRowMaxHeight: 42,
          columnSpacing: 14,
          horizontalMargin: 8,
          headingTextStyle: headerStyle,
          columns: [
            const DataColumn(label: Text('')),
            for (final asset in _amountColumns)
              DataColumn(
                label: Text(
                  asset.symbol,
                  style: TextStyle(color: AppColors.forAsset(asset)),
                ),
              ),
            const DataColumn(label: Text('比率'), numeric: true),
            const DataColumn(label: Text('最終更新')),
          ],
          rows: [
            for (final location in StorageLocation.values)
              _row(
                location: location,
                record: data.latestByLocation[location],
                rates: rates,
                totalUsdt: totalUsdt,
                cellStyle: cellStyle,
              ),
          ],
        ),
      ),
    );
  }

  DataRow _row({
    required StorageLocation location,
    required HoldingRecord? record,
    required MarketRates? rates,
    required double totalUsdt,
    required TextStyle cellStyle,
  }) {
    final share = rates == null
        ? null
        : HoldingAggregator.locationShare(
            record: record,
            rates: rates,
            totalUsdt: totalUsdt,
          );
    return DataRow(
      cells: [
        DataCell(
          Text(
            location.code,
            style: const TextStyle(
              color: AppColors.accent,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        for (final asset in _amountColumns)
          DataCell(
            Text(
              Formatters.amount(asset, record?.amountOf(asset) ?? 0),
              style: cellStyle.copyWith(color: AppColors.forAsset(asset)),
            ),
          ),
        DataCell(
          Text(
            share == null ? '—' : Formatters.percent(share),
            style: cellStyle,
          ),
        ),
        DataCell(
          Text(
            record == null
                ? '未登録'
                : Formatters.dateTimeShortText(record.recordedAt),
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
            ),
          ),
        ),
      ],
    );
  }
}

class _TargetAllocationCard extends StatelessWidget {
  const _TargetAllocationCard({required this.data});

  final DashboardData data;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: '目標配分',
      child: Text(
        _summary(data),
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 13,
          height: 1.5,
        ),
      ),
    );
  }

  static String _summary(DashboardData data) {
    if (data.rates == null) {
      return 'BTC 70.0〜75.0% / HYPE 10.0〜15.0% / USDT+NEXO 15.0%\n'
          'HYPE はレート連動（50以下=15.0%、100以上=10.0%、0.1%刻み）。減った分は BTC へ。\n'
          'NEXO は NX 総資産の 11.5%';
    }
    final hypeWeight = TargetAllocation.hypeWeight(
      data.rates!.priceOf(CryptoAsset.hype),
    );
    final btcWeight = TargetAllocation.btcWeight(hypeWeight);
    return 'BTC ${Formatters.percent(btcWeight)} / '
        'HYPE ${Formatters.percent(hypeWeight)} / USDT+NEXO 15.0%\n'
        'HYPE はレート連動（50以下=15.0%、100以上=10.0%、0.1%刻み）。減った分は BTC へ。\n'
        'NEXO は NX 総資産の 11.5%';
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.child,
    this.trailing,
  });

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                ?trailing,
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _MessageBanner extends StatelessWidget {
  const _MessageBanner({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(text, style: TextStyle(color: color, fontSize: 13)),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(message, textAlign: TextAlign.center),
      ),
    );
  }
}
