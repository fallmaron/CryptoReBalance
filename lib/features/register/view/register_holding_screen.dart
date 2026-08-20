import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/crypto_asset.dart';
import '../../../data/models/holding_record.dart';
import '../../../data/models/storage_location.dart';
import '../../../data/repositories/holding_repository.dart';
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
  final _btcController = TextEditingController();
  final _hypeController = TextEditingController();
  final _usdtController = TextEditingController();

  StorageLocation _location = StorageLocation.nx;
  DateTime _recordedAt = DateTime.now();
  bool _saving = false;
  Map<StorageLocation, HoldingRecord> _latest = {};

  @override
  void initState() {
    super.initState();
    _loadLatest();
  }

  @override
  void dispose() {
    _btcController.dispose();
    _hypeController.dispose();
    _usdtController.dispose();
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
    _btcController.text = record == null
        ? ''
        : Formatters.amount(CryptoAsset.btc, record.amountOf(CryptoAsset.btc));
    _hypeController.text = record == null
        ? ''
        : Formatters.amount(CryptoAsset.hype, record.amountOf(CryptoAsset.hype));
    _usdtController.text = record == null
        ? ''
        : Formatters.amount(CryptoAsset.usdt, record.amountOf(CryptoAsset.usdt));
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _recordedAt,
      firstDate: DateTime(2010),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (date == null || !mounted) {
      return;
    }
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_recordedAt),
    );
    if (time == null || !mounted) {
      return;
    }
    setState(() {
      _recordedAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
        _recordedAt.second,
      );
    });
  }

  Future<void> _useNow() async {
    setState(() {
      _recordedAt = DateTime.now();
    });
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
        recordedAt: _recordedAt,
        location: _location,
        amounts: {
          CryptoAsset.btc: _parseAmount(_btcController.text),
          CryptoAsset.hype: _parseAmount(_hypeController.text),
          CryptoAsset.usdt: _parseAmount(_usdtController.text),
        },
      );
      await ref.read(holdingRepositoryProvider).save(record);
      await ref.read(dashboardViewModelProvider.notifier).reloadHoldings();
      ref.invalidate(historyViewModelProvider);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${_location.code} の保有量を登録しました'),
        ),
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
              '記録日時',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _pickDateTime,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(Formatters.dateTimeText(_recordedAt)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: _useNow,
                  child: const Text('現在'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Text(
                  '秒',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(width: 12),
                DropdownButton<int>(
                  value: _recordedAt.second,
                  dropdownColor: AppColors.surfaceElevated,
                  items: [
                    for (var second = 0; second < 60; second++)
                      DropdownMenuItem(
                        value: second,
                        child: Text(second.toString().padLeft(2, '0')),
                      ),
                  ],
                  onChanged: (value) {
                    if (value == null) {
                      return;
                    }
                    setState(() {
                      _recordedAt = DateTime(
                        _recordedAt.year,
                        _recordedAt.month,
                        _recordedAt.day,
                        _recordedAt.hour,
                        _recordedAt.minute,
                        value,
                      );
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),
            _AmountField(
              label: 'BTC',
              controller: _btcController,
              color: AppColors.btc,
              validator: _amountValidator,
            ),
            const SizedBox(height: 12),
            _AmountField(
              label: 'HYPE',
              controller: _hypeController,
              color: AppColors.hype,
              validator: _amountValidator,
            ),
            const SizedBox(height: 12),
            _AmountField(
              label: 'USDT',
              controller: _usdtController,
              color: AppColors.usdt,
              validator: _amountValidator,
            ),
            const SizedBox(height: 24),
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
