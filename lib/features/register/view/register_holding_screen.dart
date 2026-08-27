import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/crypto_asset.dart';
import '../../../data/models/holding_entry_kind.dart';
import '../../../data/models/holding_record.dart';
import '../../../data/models/market_rates.dart';
import '../../../data/models/storage_location.dart';
import '../../../data/repositories/holding_repository.dart';
import '../../../data/repositories/rate_repository.dart';
import '../../../data/repositories/rebalance_profit_repository.dart';
import '../../../data/services/rebalance_profit_calculator.dart';
import '../../dashboard/viewmodel/dashboard_viewmodel.dart';
import '../../history/viewmodel/history_viewmodel.dart';

class RegisterHoldingScreen extends ConsumerStatefulWidget {
  const RegisterHoldingScreen({super.key});

  @override
  ConsumerState<RegisterHoldingScreen> createState() =>
      _RegisterHoldingScreenState();
}

class _RegisterHoldingScreenState extends ConsumerState<RegisterHoldingScreen> {
  final _formKey = GlobalKey<FormState>();
  late final Map<CryptoAsset, TextEditingController> _controllers;

  StorageLocation _location = StorageLocation.nx;
  HoldingEntryKind _kind = HoldingEntryKind.rebalance;
  bool _saving = false;
  Map<StorageLocation, HoldingRecord> _latest = {};

  @override
  void initState() {
    super.initState();
    _controllers = {
      for (final asset in CryptoAsset.values) asset: TextEditingController(),
    };
    _loadLatest();
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadLatest() async {
    final latest = await ref.read(holdingRepositoryProvider).getLatestByLocation();
    if (!mounted) {
      return;
    }
    setState(() {
      _latest = latest;
    });
    _prefillFromLatest();
  }

  void _prefillFromLatest() {
    final record = _latest[_location];
    for (final asset in CryptoAsset.values) {
      _controllers[asset]!.text = record == null
          ? ''
          : Formatters.amount(asset, record.amountOf(asset));
    }
  }

  double _parseAmount(String raw) {
    final text = raw.trim();
    if (text.isEmpty) {
      return 0;
    }
    return double.parse(text.replaceAll(',', ''));
  }

  String? _amountValidator(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) {
      return null;
    }
    final parsed = double.tryParse(text.replaceAll(',', ''));
    if (parsed == null) {
      return '数値を入力してください';
    }
    if (parsed < 0) {
      return '0以上を入力してください';
    }
    return null;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() {
      _saving = true;
    });
    try {
      final record = HoldingRecord(
        recordedAt: DateTime.now(),
        location: _location,
        kind: _kind,
        amounts: {
          for (final asset in CryptoAsset.values)
            asset: _parseAmount(_controllers[asset]!.text),
        },
      );
      final saved = await ref.read(holdingRepositoryProvider).save(record);
      await ref.read(dashboardViewModelProvider.notifier).reloadHoldings();
      ref.invalidate(historyViewModelProvider);
      final message = await _saveProfitIfNeeded(saved);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
      await _loadLatest();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('保存に失敗しました: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  Future<String> _saveProfitIfNeeded(HoldingRecord saved) async {
    if (_kind != HoldingEntryKind.rebalance) {
      return '${_location.code} を場所移動として登録しました';
    }

    final rates = await ref.read(rateRepositoryProvider).getCached();
    if (rates != null) {
      await ref.read(rateRepositoryProvider).saveSnapshot(
            MarketRates(
              fetchedAt: saved.recordedAt,
              pricesUsdt: rates.pricesUsdt,
            ),
          );
    }
    if (rates == null) {
      return '${_location.code} をリバランスとして登録しました。レート未取得のため収益は記録していません';
    }

    final records = await ref.read(holdingRepositoryProvider).getAll();
    final profit = RebalanceProfitCalculator.evaluate(
      records: records,
      current: saved,
      rates: rates,
      recordedAt: saved.recordedAt,
    );
    if (profit == null) {
      return '${_location.code} をリバランスとして登録しました。前回のリバランスがないため収益は未記録です';
    }

    final recorded = await ref
        .read(rebalanceProfitRepositoryProvider)
        .saveIfAbsent(profit);
    ref.invalidate(rebalanceProfitsProvider);
    if (!recorded) {
      return '${_location.code} をリバランスとして登録しました';
    }
    return '${_location.code} をリバランスとして登録し、収益 ${Formatters.usdt(profit.profitUsdt, signed: true)} USDT を記録しました';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('保有量を登録')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            const Text(
              '保管場所',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final location in StorageLocation.values)
                  ChoiceChip(
                    label: Text(location.code),
                    selected: _location == location,
                    selectedColor: AppColors.accent,
                    labelStyle: TextStyle(
                      color: _location == location
                          ? AppColors.background
                          : AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                    onSelected: (_) {
                      setState(() {
                        _location = location;
                      });
                      _prefillFromLatest();
                    },
                  ),
              ],
            ),
            const SizedBox(height: 20),
            const Text(
              '登録種別',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final kind in HoldingEntryKind.values)
                  ChoiceChip(
                    label: Text(kind.label),
                    selected: _kind == kind,
                    selectedColor: AppColors.accent,
                    labelStyle: TextStyle(
                      color: _kind == kind
                          ? AppColors.background
                          : AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                    onSelected: (_) {
                      setState(() {
                        _kind = kind;
                      });
                    },
                  ),
              ],
            ),
            if (_kind == HoldingEntryKind.rebalance) ...[
              const SizedBox(height: 8),
              const Text(
                'この保管場所について、直近のリバランスを実施した場合と実施しなかった場合の差を、現在レートで確定します。直近リバランスから今回までの場所移動による増減は除外します。',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
            ],
            const SizedBox(height: 20),
            for (final asset in CryptoAsset.values) ...[
              _AmountField(
                label: asset.symbol,
                controller: _controllers[asset]!,
                color: AppColors.forAsset(asset),
                validator: _amountValidator,
              ),
              const SizedBox(height: 12),
            ],
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(_saving ? '保存中...' : '履歴として保存'),
            ),
            const SizedBox(height: 12),
            const Text(
              '保管場所ごとの保有量は履歴として残ります。直近の記録がダッシュボードの計算に使われます。',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _AmountField extends StatelessWidget {
  const _AmountField({
    required this.label,
    required this.controller,
    required this.color,
    required this.validator,
  });

  final String label;
  final TextEditingController controller;
  final Color color;
  final FormFieldValidator<String> validator;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      validator: validator,
      decoration: InputDecoration(
        labelText: '$label 保有量',
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 12, right: 4),
          child: Text(
            label,
            style: TextStyle(color: color, fontWeight: FontWeight.w800),
          ),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
      ),
    );
  }
}
