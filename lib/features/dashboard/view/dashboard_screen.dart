import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/crypto_asset.dart';
import '../../../data/models/holding_record.dart';
import '../../../data/models/storage_location.dart';
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
        _AllocationCard(data: data),
        const SizedBox(height: 12),
        _RebalanceCard(data: data),
        const SizedBox(height: 12),
        _LocationHoldingsCard(latestByLocation: data.latestByLocation),
      ],
    );
  }
}

class _TotalAssetCard extends StatelessWidget {
  const _TotalAssetCard({required this.data});

  final DashboardData data;

  @override
  Widget build(BuildContext context) {
    final totalUsdt = data.rebalance?.totalUsdt;
    final totalBtc = data.rebalance?.totalBtc;
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
          const SizedBox(height: 8),
          Text(
            '目標配分  BTC 70% / HYPE 15% / USDT 15%',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
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
                    for (final asset in CryptoAsset.values)
                      Expanded(
                        child: _RateTile(
                          label: asset.symbol,
                          color: AppColors.forAsset(asset),
                          value: Formatters.usdt(data.rates!.priceOf(asset)),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 12),
                _RateTile(
                  label: 'HYPE/BTC',
                  color: AppColors.hype,
                  value: Formatters.pairRate(data.rates!.hypePerBtc),
                ),
              ],
            ),
    );
  }
}

class _RateTile extends StatelessWidget {
  const _RateTile({
    required this.label,
    required this.color,
    required this.value,
  });

  final String label;
  final Color color;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(color: color, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
      ],
    );
  }
}

class _AllocationCard extends StatelessWidget {
  const _AllocationCard({required this.data});

  final DashboardData data;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: '保有バランス',
      child: data.rebalance == null
          ? const Text(
              'レート取得後に現在比率と目標比率を表示します',
              style: TextStyle(color: AppColors.textSecondary),
            )
          : Column(
              children: [
                for (final line in data.rebalance!.lines) ...[
                  _AllocationRow(
                    symbol: line.asset.symbol,
                    color: AppColors.forAsset(line.asset),
                    current: line.currentWeight,
                    target: line.targetWeight,
                  ),
                  if (line.asset != CryptoAsset.usdt) const SizedBox(height: 10),
                ],
              ],
            ),
    );
  }
}

class _AllocationRow extends StatelessWidget {
  const _AllocationRow({
    required this.symbol,
    required this.color,
    required this.current,
    required this.target,
  });

  final String symbol;
  final Color color;
  final double current;
  final double target;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SizedBox(
              width: 52,
              child: Text(
                symbol,
                style: TextStyle(color: color, fontWeight: FontWeight.w700),
              ),
            ),
            Text(
              '${Formatters.percent(current)}  /  目標 ${Formatters.percent(target)}',
              style: const TextStyle(fontSize: 13),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            height: 10,
            child: Stack(
              fit: StackFit.expand,
              children: [
                LinearProgressIndicator(
                  value: target.clamp(0, 1),
                  backgroundColor: AppColors.surface,
                  color: color.withValues(alpha: 0.28),
                ),
                LinearProgressIndicator(
                  value: current.clamp(0, 1),
                  backgroundColor: Colors.transparent,
                  color: color,
                ),
              ],
            ),
          ),
        ),
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
          : Column(
              children: [
                for (final line in data.rebalance!.lines) ...[
                  _DiffRow(
                    asset: line.asset.symbol,
                    color: AppColors.forAsset(line.asset),
                    current: Formatters.amount(line.asset, line.currentAmount),
                    target: Formatters.amount(line.asset, line.targetAmount),
                    diffAmount: Formatters.amount(
                      line.asset,
                      line.diffAmount,
                      signed: true,
                    ),
                    diffUsdt: Formatters.usdt(line.diffUsdt, signed: true),
                    isBuy: line.needsBuy,
                    isSell: line.needsSell,
                  ),
                  if (line.asset != CryptoAsset.usdt)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Divider(height: 1),
                    ),
                ],
              ],
            ),
    );
  }
}

class _DiffRow extends StatelessWidget {
  const _DiffRow({
    required this.asset,
    required this.color,
    required this.current,
    required this.target,
    required this.diffAmount,
    required this.diffUsdt,
    required this.isBuy,
    required this.isSell,
  });

  final String asset;
  final Color color;
  final String current;
  final String target;
  final String diffAmount;
  final String diffUsdt;
  final bool isBuy;
  final bool isSell;

  @override
  Widget build(BuildContext context) {
    final actionColor = isBuy
        ? AppColors.buy
        : isSell
        ? AppColors.sell
        : AppColors.textSecondary;
    final actionLabel = isBuy
        ? '不足（購入）'
        : isSell
        ? '過剰（売却）'
        : '目標一致';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              asset,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
            const Spacer(),
            Text(
              actionLabel,
              style: TextStyle(
                color: actionColor,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _kv('現在量', current),
        _kv('目標量', target),
        _kv('差分', diffAmount, valueColor: actionColor),
        _kv('USDT換算', '$diffUsdt USDT', valueColor: actionColor),
      ],
    );
  }

  Widget _kv(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        children: [
          SizedBox(
            width: 88,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: valueColor ?? AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LocationHoldingsCard extends StatelessWidget {
  const _LocationHoldingsCard({required this.latestByLocation});

  final Map<StorageLocation, HoldingRecord> latestByLocation;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: '保管場所別 直近保有',
      child: Column(
        children: [
          for (final location in StorageLocation.values) ...[
            _LocationRow(
              location: location,
              record: latestByLocation[location],
            ),
            if (location != StorageLocation.rk)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Divider(height: 1),
              ),
          ],
        ],
      ),
    );
  }
}

class _LocationRow extends StatelessWidget {
  const _LocationRow({required this.location, required this.record});

  final StorageLocation location;
  final HoldingRecord? record;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.accentDim,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                location.code,
                style: const TextStyle(
                  color: AppColors.accent,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const Spacer(),
            Text(
              record == null ? '未登録' : Formatters.dateTimeText(record!.recordedAt),
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (record == null)
          const Text(
            '保有量がまだ登録されていません',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          )
        else
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              for (final asset in CryptoAsset.values)
                Text(
                  '${asset.symbol} ${Formatters.amount(asset, record!.amountOf(asset))}',
                  style: TextStyle(
                    color: AppColors.forAsset(asset),
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
            ],
          ),
      ],
    );
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
