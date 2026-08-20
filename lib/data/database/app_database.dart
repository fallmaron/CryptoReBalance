import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/crypto_asset.dart';
import '../models/holding_record.dart';
import '../models/market_rates.dart';
import '../models/storage_location.dart';

class AppDatabase {
  AppDatabase({Database? database}) : _injected = database;

  final Database? _injected;
  Database? _db;

  Future<Database> get database async {
    if (_injected != null) {
      return _injected;
    }
    _db ??= await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final dbPath = await getDatabasesPath();
    return openDatabase(
      p.join(dbPath, 'cryptrebalance.db'),
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE holdings (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            recorded_at INTEGER NOT NULL,
            location TEXT NOT NULL,
            btc REAL NOT NULL,
            hype REAL NOT NULL,
            usdt REAL NOT NULL
          )
        ''');
        await db.execute('''
          CREATE INDEX idx_holdings_location_time
          ON holdings(location, recorded_at DESC)
        ''');
        await db.execute('''
          CREATE TABLE rate_snapshots (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            fetched_at INTEGER NOT NULL,
            btc REAL NOT NULL,
            hype REAL NOT NULL,
            usdt REAL NOT NULL
          )
        ''');
      },
    );
  }

  Future<int> insertHolding(HoldingRecord record) async {
    final db = await database;
    return db.insert('holdings', _holdingToMap(record));
  }

  Future<List<HoldingRecord>> getHoldings() async {
    final db = await database;
    final rows = await db.query('holdings', orderBy: 'recorded_at DESC, id DESC');
    return rows.map(_holdingFromMap).toList();
  }

  Future<void> deleteHolding(int id) async {
    final db = await database;
    await db.delete('holdings', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> saveRates(MarketRates rates) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('rate_snapshots');
      await txn.insert('rate_snapshots', {
        'fetched_at': rates.fetchedAt.millisecondsSinceEpoch,
        'btc': rates.priceOf(CryptoAsset.btc),
        'hype': rates.priceOf(CryptoAsset.hype),
        'usdt': rates.priceOf(CryptoAsset.usdt),
      });
    });
  }

  Future<MarketRates?> getLatestRates() async {
    final db = await database;
    final rows = await db.query(
      'rate_snapshots',
      orderBy: 'fetched_at DESC, id DESC',
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    final row = rows.first;
    return MarketRates(
      fetchedAt: DateTime.fromMillisecondsSinceEpoch(row['fetched_at']! as int),
      pricesUsdt: {
        CryptoAsset.btc: (row['btc']! as num).toDouble(),
        CryptoAsset.hype: (row['hype']! as num).toDouble(),
        CryptoAsset.usdt: (row['usdt']! as num).toDouble(),
      },
    );
  }

  Map<String, Object?> _holdingToMap(HoldingRecord record) {
    return {
      if (record.id != null) 'id': record.id,
      'recorded_at': record.recordedAt.millisecondsSinceEpoch,
      'location': record.location.code,
      'btc': record.amountOf(CryptoAsset.btc),
      'hype': record.amountOf(CryptoAsset.hype),
      'usdt': record.amountOf(CryptoAsset.usdt),
    };
  }

  HoldingRecord _holdingFromMap(Map<String, Object?> row) {
    return HoldingRecord(
      id: row['id']! as int,
      recordedAt: DateTime.fromMillisecondsSinceEpoch(row['recorded_at']! as int),
      location: StorageLocation.fromCode(row['location']! as String),
      amounts: {
        CryptoAsset.btc: (row['btc']! as num).toDouble(),
        CryptoAsset.hype: (row['hype']! as num).toDouble(),
        CryptoAsset.usdt: (row['usdt']! as num).toDouble(),
      },
    );
  }
}

final appDatabaseProvider = Provider<AppDatabase>((ref) => AppDatabase());
