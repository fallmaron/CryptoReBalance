import 'package:intl/intl.dart';

import '../../data/models/crypto_asset.dart';

abstract final class Formatters {
  static final DateFormat dateTime = DateFormat('yyyy/MM/dd HH:mm:ss');
  static final DateFormat dateTimeShort = DateFormat('MM/dd HH:mm:ss');
  static final NumberFormat _usdt = NumberFormat('#,##0.00', 'en_US');

  static String dateTimeText(DateTime value) => dateTime.format(value);

  static String dateTimeShortText(DateTime value) => dateTimeShort.format(value);

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
      CryptoAsset.nexo => 4,
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

  static String percent(double value, {bool signed = false}) {
    final text = '${(value.abs() * 100).toStringAsFixed(1)}%';
    if (signed && value > 0) {
      return '+$text';
    }
    if (value < 0) {
      return '-$text';
    }
    return text;
  }

  static String btcProfitLine({
    required double profitBtc,
    required double btcPriceUsdt,
  }) {
    final profitUsdt = (profitBtc * btcPriceUsdt).abs();
    final usdtText = _truncateTowardZero(profitUsdt, 0);
    return '${amount(CryptoAsset.btc, profitBtc, signed: true)}BTC(${usdtText}USDT)';
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

  /// 過剰（売却）は数量、不足（購入）は USDT 換算。符号なし絶対値。
  /// コピー時は切り捨て: BTCは丸めなし、HYPEは小数2桁、NEXO/USDTは整数。
  static String? rebalanceClipboardText({
    required CryptoAsset asset,
    required double diffAmount,
    required double diffUsdt,
  }) {
    if (diffAmount < 0) {
      return clipboardQuantity(asset, diffAmount.abs());
    }
    if (diffAmount > 0) {
      return clipboardQuantity(CryptoAsset.usdt, diffUsdt.abs());
    }
    return null;
  }

  static String clipboardQuantity(CryptoAsset asset, double value) {
    final abs = value.abs();
    return switch (asset) {
      CryptoAsset.btc => amount(asset, abs),
      CryptoAsset.hype => _truncateTowardZero(abs, 2),
      CryptoAsset.nexo => _truncateTowardZero(abs, 0),
      CryptoAsset.usdt => NumberFormat('#,##0', 'en_US').format(
        int.parse(_truncateTowardZero(abs, 0)),
      ),
    };
  }

  static String _truncateTowardZero(double value, int fractionDigits) {
    var text = value.abs().toString();
    if (text.contains('e') || text.contains('E')) {
      text = value.abs().toStringAsFixed(16);
    }
    final dot = text.indexOf('.');
    if (dot == -1) {
      return text;
    }
    if (fractionDigits == 0) {
      final whole = text.substring(0, dot);
      return whole.isEmpty ? '0' : whole;
    }
    final end = (dot + 1 + fractionDigits).clamp(0, text.length);
    var truncated = text.substring(0, end);
    truncated = truncated.replaceFirst(RegExp(r'0+$'), '');
    truncated = truncated.replaceFirst(RegExp(r'\.$'), '');
    if (truncated.isEmpty) {
      return '0';
    }
    return truncated;
  }
}
