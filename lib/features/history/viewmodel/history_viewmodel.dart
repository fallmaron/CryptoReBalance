import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/holding_record.dart';
import '../../../data/repositories/holding_repository.dart';
import '../../../data/repositories/rebalance_profit_repository.dart';

final historyViewModelProvider =
    AsyncNotifierProvider<HistoryViewModel, List<HoldingRecord>>(
      HistoryViewModel.new,
    );

class HistoryViewModel extends AsyncNotifier<List<HoldingRecord>> {
  @override
  Future<List<HoldingRecord>> build() {
    return ref.read(holdingRepositoryProvider).getAll();
  }

  Future<void> delete(int id) async {
    await ref.read(holdingRepositoryProvider).delete(id);
    state = await AsyncValue.guard(build);
  }

  Future<void> deleteAll() async {
    await ref.read(holdingRepositoryProvider).deleteAll();
    await ref.read(rebalanceProfitRepositoryProvider).deleteAll();
    ref.invalidate(rebalanceProfitsProvider);
    state = await AsyncValue.guard(build);
  }
}
