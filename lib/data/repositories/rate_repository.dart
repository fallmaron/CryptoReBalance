import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/app_database.dart';
import '../models/market_rates.dart';
import '../services/coinmarketcap_client.dart';

abstract class RateRepository {
  Future<MarketRates?> getCached();
  Future<MarketRates> refresh();
}

class CoinMarketCapRateRepository implements RateRepository {
  CoinMarketCapRateRepository({
    required this.database,
    required this.client,
  });

  final AppDatabase database;
  final CoinMarketCapClient client;

  @override
  Future<MarketRates?> getCached() => database.getLatestRates();

  @override
  Future<MarketRates> refresh() async {
    final rates = await client.fetchLatestRates();
    await database.saveRates(rates);
    return rates;
  }
}

final coinMarketCapClientProvider = Provider<CoinMarketCapClient>((ref) {
  return CoinMarketCapClient();
});

final rateRepositoryProvider = Provider<RateRepository>((ref) {
  return CoinMarketCapRateRepository(
    database: ref.watch(appDatabaseProvider),
    client: ref.watch(coinMarketCapClientProvider),
  );
});
