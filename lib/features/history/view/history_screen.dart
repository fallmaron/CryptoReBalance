import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/crypto_asset.dart';
import '../../../data/models/holding_record.dart';
import '../../dashboard/viewmodel/dashboard_viewmodel.dart';
import '../viewmodel/history_viewmodel.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncHistory = ref.watch(historyViewModelProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('保有履歴'),
        actions: [
          IconButton(
            onPressed: asyncHistory.maybeWhen(
              data: (records) => records.isEmpty
                  ? null
                  : () => _deleteAll(context, ref),
              orElse: () => null,
            ),
            icon: const Icon(Icons.delete_sweep_outlined),
            tooltip: '全削除',
          ),
        ],
      ),
      body: asyncHistory.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text(error.toString())),
        data: (records) {
          if (records.isEmpty) {
            return const Center(
              child: Text(
                'まだ保有履歴がありません',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            itemCount: records.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final record = records[index];
              return Dismissible(
                key: ValueKey(record.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  decoration: BoxDecoration(
                    color: AppColors.sell.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.delete, color: AppColors.sell),
                ),
                confirmDismiss: (_) => _confirmDelete(context),
                onDismissed: (_) async {
                  final id = record.id;
                  if (id == null) {
                    return;
                  }
                  await ref.read(historyViewModelProvider.notifier).delete(id);
                  await ref
                      .read(dashboardViewModelProvider.notifier)
                      .reloadHoldings();
                },
                child: _HistoryCard(record: record),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _deleteAll(BuildContext context, WidgetRef ref) async {
    final confirmed = await _confirmDeleteAll(context);
    if (!confirmed) {
      return;
    }
    await ref.read(historyViewModelProvider.notifier).deleteAll();
    await ref.read(dashboardViewModelProvider.notifier).reloadHoldings();
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('保有履歴をすべて削除しました')),
    );
  }

  Future<bool> _confirmDelete(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('履歴を削除しますか？'),
          content: const Text('この保有記録を削除します。'),
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
    return result ?? false;
  }

  Future<bool> _confirmDeleteAll(BuildContext context) async {
    final first = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('保有履歴をすべて削除しますか？'),
          content: const Text('すべての保有記録とリバランス収益を削除します。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('キャンセル'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('削除する'),
            ),
          ],
        );
      },
    );
    if (first != true || !context.mounted) {
      return false;
    }
    final second = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('本当にすべて削除しますか？'),
          content: const Text('この操作は取り消せません。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('キャンセル'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: AppColors.sell),
              child: const Text('すべて削除'),
            ),
          ],
        );
      },
    );
    return second ?? false;
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.record});

  final HoldingRecord record;

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
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.accentDim,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    record.location.code,
                    style: const TextStyle(
                      color: AppColors.accent,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Text(
                    record.kind.label,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  Formatters.dateTimeText(record.recordedAt),
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            for (final asset in CryptoAsset.values)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    SizedBox(
                      width: 56,
                      child: Text(
                        asset.symbol,
                        style: TextStyle(
                          color: AppColors.forAsset(asset),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Text(
                      Formatters.amount(asset, record.amountOf(asset)),
                      style: const TextStyle(fontWeight: FontWeight.w600),
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
