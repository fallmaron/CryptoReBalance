import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/crypto_asset.dart';
import '../../../data/models/holding_record.dart';
import '../../../data/models/market_rates.dart';
import '../../../data/models/rebalance_snapshot.dart';
import '../../../data/models/storage_location.dart';
import '../../../data/repositories/holding_repository.dart';
import '../../../data/repositories/rate_repository.dart';
import '../../../data/services/holding_aggregator.dart';
import '../../../data/services/rebalance_calculator.dart';

class DashboardData {
  const DashboardData({
    required this.latestByLocation,
    required this.totals,
    required this.rates,
    required this.rebalance,
    required this.rateError,
    required this.isRefreshingRates,
  });

  final Map<StorageLocation, HoldingRecord> latestByLocation;
  final Map<CryptoAsset, double> totals;
  final MarketRates? rates;
  final RebalanceSnapshot? rebalance;
  final String? rateError;
  final bool isRefreshingRates;

  DashboardData copyWith({
    Map<StorageLocation, HoldingRecord>? latestByLocation,
    Map<CryptoAsset, double>? totals,
    MarketRates? rates,
    RebalanceSnapshot? rebalance,
    String? rateError,
    bool? isRefreshingRates,
    bool clearRateError = false,
    bool clearRates = false,
    bool clearRebalance = false,
  }) {
    return DashboardData(
      latestByLocation: latestByLocation ?? this.latestByLocation,
      totals: totals ?? this.totals,
      rates: clearRates ? null : (rates ?? this.rates),
      rebalance: clearRebalance ? null : (rebalance ?? this.rebalance),
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

    var data = DashboardData(
      latestByLocation: latest,
      totals: totals,
      rates: cachedRates,
      rebalance: cachedRates == null
          ? null
          : RebalanceCalculator.calculate(
              holdings: totals,
              rates: cachedRates,
            ),
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
    state = AsyncData(
      current.copyWith(
        latestByLocation: latest,
        totals: totals,
        rebalance: current.rates == null
            ? null
            : RebalanceCalculator.calculate(
                holdings: totals,
                rates: current.rates!,
              ),
        clearRebalance: current.rates == null,
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
      return current.copyWith(
        rates: rates,
        rebalance: RebalanceCalculator.calculate(
          holdings: current.totals,
          rates: rates,
        ),
        isRefreshingRates: false,
        clearRateError: true,
      );
    } catch (error) {
      return current.copyWith(
        isRefreshingRates: false,
        rateError: error.toString(),
      );
    }
  }
}
