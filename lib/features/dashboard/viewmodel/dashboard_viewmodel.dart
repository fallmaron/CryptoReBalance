import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/crypto_asset.dart';
import '../../../data/models/daily_snapshot.dart';
import '../../../data/models/holding_record.dart';
import '../../../data/models/market_rates.dart';
import '../../../data/models/rebalance_profit.dart';
import '../../../data/models/rebalance_snapshot.dart';
import '../../../data/models/storage_location.dart';
import '../../../data/repositories/daily_snapshot_repository.dart';
import '../../../data/repositories/holding_repository.dart';
import '../../../data/repositories/rate_repository.dart';
import '../../../data/services/holding_aggregator.dart';
import '../../../data/services/rebalance_calculator.dart';
import '../../../data/services/rebalance_profit_calculator.dart';

class DashboardData {
  const DashboardData({
    required this.holdings,
    required this.latestByLocation,
    required this.totals,
    required this.rates,
    required this.rebalance,
    required this.liveProfits,
    required this.rateChanges,
    required this.lastRebalanceAt,
    required this.rateError,
    required this.isRefreshingRates,
  });

  final List<HoldingRecord> holdings;
  final Map<StorageLocation, HoldingRecord> latestByLocation;
  final Map<CryptoAsset, double> totals;
  final MarketRates? rates;
  final RebalanceSnapshot? rebalance;
  final List<RebalanceProfit> liveProfits;
  final Map<CryptoAsset, double>? rateChanges;
  final DateTime? lastRebalanceAt;
  final String? rateError;
  final bool isRefreshingRates;

  double get liveProfitTotal =>
      liveProfits.fold<double>(0, (sum, item) => sum + item.profitUsdt);

  DashboardData copyWith({
    List<HoldingRecord>? holdings,
    Map<StorageLocation, HoldingRecord>? latestByLocation,
    Map<CryptoAsset, double>? totals,
    MarketRates? rates,
    RebalanceSnapshot? rebalance,
    List<RebalanceProfit>? liveProfits,
    Map<CryptoAsset, double>? rateChanges,
    DateTime? lastRebalanceAt,
    String? rateError,
    bool? isRefreshingRates,
    bool clearRateError = false,
    bool clearRates = false,
    bool clearRebalance = false,
    bool clearRateChanges = false,
    bool clearLastRebalanceAt = false,
  }) {
    return DashboardData(
      holdings: holdings ?? this.holdings,
      latestByLocation: latestByLocation ?? this.latestByLocation,
      totals: totals ?? this.totals,
      rates: clearRates ? null : (rates ?? this.rates),
      rebalance: clearRebalance ? null : (rebalance ?? this.rebalance),
      liveProfits: liveProfits ?? this.liveProfits,
      rateChanges: clearRateChanges ? null : (rateChanges ?? this.rateChanges),
      lastRebalanceAt: clearLastRebalanceAt
          ? null
          : (lastRebalanceAt ?? this.lastRebalanceAt),
      rateError: clearRateError ? null : (rateError ?? this.rateError),
      isRefreshingRates: isRefreshingRates ?? this.isRefreshingRates,
    );
  }
}

final dashboardViewModelProvider =
    AsyncNotifierProvider<DashboardViewModel, DashboardData>(
      DashboardViewModel.new,
    );

class DashboardViewModel extends AsyncNotifier<DashboardData> {
  @override
  Future<DashboardData> build() async {
    final holdings = await ref.read(holdingRepositoryProvider).getAll();
    final latest = HoldingAggregator.latestByLocation(holdings);
    final totals = HoldingAggregator.totals(latest);
    final cachedRates = await ref.read(rateRepositoryProvider).getCached();
    final extras = await _derived(holdings: holdings, rates: cachedRates);

    var data = DashboardData(
      holdings: holdings,
      latestByLocation: latest,
      totals: totals,
      rates: cachedRates,
      rebalance: cachedRates == null
          ? null
          : RebalanceCalculator.calculate(
              holdings: totals,
              rates: cachedRates,
              nxHoldings: latest[StorageLocation.nx]?.amounts ?? const {},
            ),
      liveProfits: extras.liveProfits,
      rateChanges: extras.rateChanges,
      lastRebalanceAt: extras.lastRebalanceAt,
      rateError: null,
      isRefreshingRates: cachedRates == null,
    );

    if (cachedRates == null) {
      data = await _refreshRates(data);
    }
    return data;
  }

  Future<void> reloadHoldings() async {
    final current = state.value;
    if (current == null) {
      state = const AsyncLoading();
      state = await AsyncValue.guard(build);
      return;
    }
    final holdings = await ref.read(holdingRepositoryProvider).getAll();
    final latest = HoldingAggregator.latestByLocation(holdings);
    final totals = HoldingAggregator.totals(latest);
    final extras = await _derived(holdings: holdings, rates: current.rates);
    state = AsyncData(
      current.copyWith(
        holdings: holdings,
        latestByLocation: latest,
        totals: totals,
        rebalance: current.rates == null
            ? null
            : RebalanceCalculator.calculate(
                holdings: totals,
                rates: current.rates!,
                nxHoldings: latest[StorageLocation.nx]?.amounts ?? const {},
              ),
        liveProfits: extras.liveProfits,
        rateChanges: extras.rateChanges,
        lastRebalanceAt: extras.lastRebalanceAt,
        clearRebalance: current.rates == null,
        clearRateChanges: extras.rateChanges == null,
        clearLastRebalanceAt: extras.lastRebalanceAt == null,
      ),
    );
  }

  Future<void> refreshRates() async {
    final current = state.value;
    if (current == null) {
      state = const AsyncLoading();
      state = await AsyncValue.guard(build);
      return;
    }
    state = AsyncData(current.copyWith(isRefreshingRates: true, clearRateError: true));
    final next = await _refreshRates(state.value!);
    state = AsyncData(next);
  }

  Future<DashboardData> _refreshRates(DashboardData current) async {
    try {
      final rates = await ref.read(rateRepositoryProvider).refresh();
      final rebalance = RebalanceCalculator.calculate(
        holdings: current.totals,
        rates: rates,
        nxHoldings:
            current.latestByLocation[StorageLocation.nx]?.amounts ?? const {},
      );
      await ref.read(dailySnapshotRepositoryProvider).saveIfAbsent(
            DailySnapshot.fromRebalance(
              recordedAt: DateTime.now(),
              rebalance: rebalance,
            ),
          );
      ref.invalidate(dailySnapshotsProvider);
      final extras = await _derived(holdings: current.holdings, rates: rates);
      return current.copyWith(
        rates: rates,
        rebalance: rebalance,
        liveProfits: extras.liveProfits,
        rateChanges: extras.rateChanges,
        lastRebalanceAt: extras.lastRebalanceAt,
        isRefreshingRates: false,
        clearRateError: true,
        clearRateChanges: extras.rateChanges == null,
        clearLastRebalanceAt: extras.lastRebalanceAt == null,
      );
    } catch (error) {
      return current.copyWith(
        isRefreshingRates: false,
        rateError: error.toString(),
      );
    }
  }

  Future<({
    List<RebalanceProfit> liveProfits,
    Map<CryptoAsset, double>? rateChanges,
    DateTime? lastRebalanceAt,
  })> _derived({
    required List<HoldingRecord> holdings,
    required MarketRates? rates,
  }) async {
    final lastRebalance = RebalanceProfitCalculator.latestRebalance(holdings);
    final liveProfits = rates == null
        ? const <RebalanceProfit>[]
        : RebalanceProfitCalculator.previewNow(
            records: holdings,
            rates: rates,
            now: DateTime.now(),
          );
    Map<CryptoAsset, double>? rateChanges;
    if (rates != null && lastRebalance != null) {
      final then = await ref
          .read(rateRepositoryProvider)
          .getAtOrBefore(lastRebalance.recordedAt);
      if (then != null) {
        rateChanges = rates.changeRatioFrom(then);
      }
    }
    return (
      liveProfits: liveProfits,
      rateChanges: rateChanges,
      lastRebalanceAt: lastRebalance?.recordedAt,
    );
  }
}
