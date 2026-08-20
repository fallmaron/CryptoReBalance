import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/constants/app_constants.dart';
import '../models/crypto_asset.dart';
import '../models/market_rates.dart';

class CoinMarketCapException implements Exception {
  const CoinMarketCapException(this.message);

  final String message;

  @override
  String toString() => message;
}

class CoinMarketCapClient {
  CoinMarketCapClient({http.Client? httpClient})
    : _httpClient = httpClient ?? http.Client();

  final http.Client _httpClient;

  Future<MarketRates> fetchLatestRates() async {
    final found = <CryptoAsset, _QuoteCandidate>{};
    final needed = CryptoAsset.values.toSet();

    for (var start = 1; start <= AppConstants.cmcMaxStart; start += AppConstants.cmcPageSize) {
      final page = await _fetchPage(start);
      for (final item in page) {
        final symbol = item['symbol'];
        if (symbol is! String) {
          continue;
        }
        final asset = CryptoAsset.fromSymbol(symbol);
        if (asset == null || !needed.contains(asset)) {
          continue;
        }
        final rank = _asInt(item['cmc_rank']) ?? 1 << 30;
        final price = _extractPrice(item);
        if (price == null) {
          continue;
        }
        final current = found[asset];
        if (current == null || rank < current.rank) {
          found[asset] = _QuoteCandidate(rank: rank, price: price);
        }
      }
      if (found.length == needed.length) {
        break;
      }
    }

    final missing = needed.where((asset) => !found.containsKey(asset)).toList();
    if (missing.isNotEmpty) {
      throw CoinMarketCapException(
        'レートを取得できませんでした: ${missing.map((asset) => asset.symbol).join(', ')}',
      );
    }

    return MarketRates(
      fetchedAt: DateTime.now(),
      pricesUsdt: {
        for (final entry in found.entries) entry.key: entry.value.price,
      },
    );
  }

  Future<List<dynamic>> _fetchPage(int start) async {
    final uri = Uri.parse(AppConstants.cmcListingsUrl).replace(
      queryParameters: {
        'start': '$start',
        'limit': '${AppConstants.cmcPageSize}',
        'convert': 'USDT',
      },
    );
    final response = await _httpClient
        .get(
          uri,
          headers: {
            'Accept': 'application/json',
            'X-CMC_PRO_API_KEY': AppConstants.cmcApiKey,
          },
        )
        .timeout(const Duration(seconds: 20));

    if (response.statusCode != 200) {
      throw CoinMarketCapException(
        'CoinMarketCap APIエラー (${response.statusCode})',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const CoinMarketCapException('CoinMarketCapの応答形式が不正です');
    }

    final status = decoded['status'];
    if (status is Map<String, dynamic>) {
      final errorCode = _asInt(status['error_code']) ?? 0;
      if (errorCode != 0) {
        final message = status['error_message']?.toString() ?? 'unknown error';
        throw CoinMarketCapException('CoinMarketCap APIエラー: $message');
      }
    }

    final data = decoded['data'];
    if (data is! List) {
      throw const CoinMarketCapException('CoinMarketCapのレート一覧が空です');
    }
    return data;
  }

  static double? _extractPrice(dynamic item) {
    if (item is! Map<String, dynamic>) {
      return null;
    }
    final quote = item['quote'];
    if (quote is! Map<String, dynamic>) {
      return null;
    }
    for (final key in ['USDT', 'USD']) {
      final market = quote[key];
      if (market is Map<String, dynamic>) {
        final price = market['price'];
        if (price is num) {
          return price.toDouble();
        }
      }
    }
    return null;
  }

  static int? _asInt(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return null;
  }
}

class _QuoteCandidate {
  const _QuoteCandidate({required this.rank, required this.price});

  final int rank;
  final double price;
}
