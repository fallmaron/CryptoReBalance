import 'dart:convert';

import 'package:cryptrebalance/core/constants/app_constants.dart';
import 'package:cryptrebalance/data/models/crypto_asset.dart';
import 'package:cryptrebalance/data/services/coinmarketcap_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('parses BTC HYPE USDT prices from listings latest', () async {
    final client = CoinMarketCapClient(
      httpClient: MockClient((request) async {
        expect(request.url.path, '/v1/cryptocurrency/listings/latest');
        expect(request.url.queryParameters['convert'], 'USDT');
        expect(
          request.headers['X-CMC_PRO_API_KEY'],
          AppConstants.cmcApiKey,
        );
        return http.Response(
          jsonEncode({
            'status': {'error_code': 0},
            'data': [
              {
                'symbol': 'BTC',
                'cmc_rank': 1,
                'quote': {
                  'USDT': {'price': 110000.5},
                },
              },
              {
                'symbol': 'HYPE',
                'cmc_rank': 12,
                'quote': {
                  'USDT': {'price': 42.1},
                },
              },
              {
                'symbol': 'USDT',
                'cmc_rank': 3,
                'quote': {
                  'USDT': {'price': 1.0},
                },
              },
              {
                'symbol': 'NEXO',
                'cmc_rank': 90,
                'quote': {
                  'USDT': {'price': 1.25},
                },
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    final rates = await client.fetchLatestRates();

    expect(rates.priceOf(CryptoAsset.btc), 110000.5);
    expect(rates.priceOf(CryptoAsset.hype), 42.1);
    expect(rates.priceOf(CryptoAsset.usdt), 1.0);
    expect(rates.priceOf(CryptoAsset.nexo), 1.25);
  });

  test('keeps the better ranked duplicate symbol', () async {
    final client = CoinMarketCapClient(
      httpClient: MockClient((request) async {
        return http.Response(
          jsonEncode({
            'status': {'error_code': 0},
            'data': [
              {
                'symbol': 'HYPE',
                'cmc_rank': 400,
                'quote': {
                  'USDT': {'price': 0.01},
                },
              },
              {
                'symbol': 'HYPE',
                'cmc_rank': 11,
                'quote': {
                  'USDT': {'price': 40},
                },
              },
              {
                'symbol': 'BTC',
                'cmc_rank': 1,
                'quote': {
                  'USDT': {'price': 1},
                },
              },
              {
                'symbol': 'USDT',
                'cmc_rank': 3,
                'quote': {
                  'USDT': {'price': 1},
                },
              },
              {
                'symbol': 'NEXO',
                'cmc_rank': 90,
                'quote': {
                  'USDT': {'price': 1.1},
                },
              },
            ],
          }),
          200,
        );
      }),
    );

    final rates = await client.fetchLatestRates();
    expect(rates.priceOf(CryptoAsset.hype), 40);
  });

  test('throws when a required symbol is missing', () async {
    final client = CoinMarketCapClient(
      httpClient: MockClient((request) async {
        return http.Response(
          jsonEncode({
            'status': {'error_code': 0},
            'data': [
              {
                'symbol': 'BTC',
                'cmc_rank': 1,
                'quote': {
                  'USDT': {'price': 1},
                },
              },
              {
                'symbol': 'USDT',
                'cmc_rank': 3,
                'quote': {
                  'USDT': {'price': 1},
                },
              },
            ],
          }),
          200,
        );
      }),
    );

    expect(
      client.fetchLatestRates(),
      throwsA(
        isA<CoinMarketCapException>().having(
          (error) => error.message,
          'message',
          contains('HYPE'),
        ),
      ),
    );
  });
}
