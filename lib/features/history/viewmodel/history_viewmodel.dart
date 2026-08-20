import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/holding_record.dart';
import '../../../data/repositories/holding_repository.dart';

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
}
