import 'package:intl/intl.dart';

import '../../data/models/crypto_asset.dart';

abstract final class Formatters {
  static final DateFormat dateTime = DateFormat('yyyy/MM/dd HH:mm:ss');
  static final NumberFormat _usdt = NumberFormat('#,##0.00', 'en_US');

  static String dateTimeText(DateTime value) => dateTime.format(value);

  static String usdt(double value, {bool signed = false}) {
    final absText = _usdt.format(value.abs());
    if (!signed) {
      return value.isNegative ? '-$absText' : absText;
    }
    if (value > 0) {
      return '+$absText';
    }
    if (value < 0) {
      return '-$absText';
    }
    return absText;
  }

  static String amount(CryptoAsset asset, double value, {bool signed = false}) {
    final digits = switch (asset) {
      CryptoAsset.btc => 8,
      CryptoAsset.hype => 6,
      CryptoAsset.usdt => 4,
    };
    var text = value.abs().toStringAsFixed(digits);
    text = text.replaceFirst(RegExp(r'0+$'), '');
    text = text.replaceFirst(RegExp(r'\.$'), '');
    if (text.isEmpty) {
      text = '0';
    }
    if (!signed) {
      return value.isNegative ? '-$text' : text;
    }
    if (value > 0) {
      return '+$text';
    }
    if (value < 0) {
      return '-$text';
    }
    return text;
  }

  static String percent(double value) {
    return '${(value * 100).toStringAsFixed(1)}%';
  }

  static String pairRate(double value) {
    var text = value.abs().toStringAsFixed(8);
    text = text.replaceFirst(RegExp(r'0+$'), '');
    text = text.replaceFirst(RegExp(r'\.$'), '');
    if (text.isEmpty) {
      text = '0';
    }
    return value.isNegative ? '-$text' : text;
  }
}
