import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/crypto_asset.dart';
import '../models/daily_snapshot.dart';
import '../models/holding_entry_kind.dart';
import '../models/holding_record.dart';
import '../models/market_rates.dart';
import '../models/rebalance_profit.dart';
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
      version: 6,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE holdings (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            recorded_at INTEGER NOT NULL,
            location TEXT NOT NULL,
            btc REAL NOT NULL,
            hype REAL NOT NULL,
            nexo REAL NOT NULL,
            usdt REAL NOT NULL,
            entry_kind TEXT NOT NULL
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
            nexo REAL NOT NULL,
            usdt REAL NOT NULL
          )
        ''');
        await _createDailySnapshotsTable(db);
        await _createRebalanceProfitsTable(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute(
            'ALTER TABLE holdings ADD COLUMN nexo REAL NOT NULL DEFAULT 0',
          );
          await db.execute(
            'ALTER TABLE rate_snapshots ADD COLUMN nexo REAL NOT NULL DEFAULT 0',
          );
          await db.delete('rate_snapshots');
        }
        if (oldVersion < 3) {
          await _createDailySnapshotsTable(db);
        }
        if (oldVersion < 4) {
          await db.execute(
            "ALTER TABLE holdings ADD COLUMN entry_kind TEXT NOT NULL DEFAULT 'location_move'",
          );
          await db.execute('ALTER TABLE holdings ADD COLUMN event_id TEXT');
          await _createRebalanceProfitsTable(db);
        }
        if (oldVersion < 5 && oldVersion >= 4) {
          await db.execute(
            "ALTER TABLE rebalance_profits ADD COLUMN location TEXT NOT NULL DEFAULT 'NX'",
          );
        }
        if (oldVersion < 6 && oldVersion >= 4) {
          await db.execute(
            'ALTER TABLE rebalance_profits ADD COLUMN holding_id INTEGER',
          );
        }
      },
    );
  }

  static Future<void> _createDailySnapshotsTable(Database db) async {
    await db.execute('''
      CREATE TABLE daily_snapshots (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        day_key TEXT NOT NULL UNIQUE,
        recorded_at INTEGER NOT NULL,
        total_usdt REAL NOT NULL,
        total_btc REAL NOT NULL,
        btc_amount REAL NOT NULL,
        btc_usdt REAL NOT NULL,
        btc_target_amount REAL NOT NULL,
        btc_current_weight REAL NOT NULL,
        btc_target_weight REAL NOT NULL,
        hype_amount REAL NOT NULL,
        hype_usdt REAL NOT NULL,
        hype_target_amount REAL NOT NULL,
        hype_current_weight REAL NOT NULL,
        hype_target_weight REAL NOT NULL,
        usdt_amount REAL NOT NULL,
        usdt_usdt REAL NOT NULL,
        usdt_target_amount REAL NOT NULL,
        usdt_current_weight REAL NOT NULL,
        usdt_target_weight REAL NOT NULL,
        nexo_amount REAL NOT NULL,
        nexo_usdt REAL NOT NULL,
        nexo_target_amount REAL NOT NULL,
        nexo_current_weight REAL NOT NULL,
        nexo_target_weight REAL NOT NULL
      )
    ''');
  }

  static Future<void> _createRebalanceProfitsTable(Database db) async {
    await db.execute('''
      CREATE TABLE rebalance_profits (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        recorded_at INTEGER NOT NULL,
        session_started_at INTEGER NOT NULL,
        session_ended_at INTEGER NOT NULL,
        session_start_id INTEGER NOT NULL,
        session_end_id INTEGER NOT NULL UNIQUE,
        location TEXT NOT NULL,
        holding_id INTEGER,
        with_usdt REAL NOT NULL,
        without_usdt REAL NOT NULL,
        profit_usdt REAL NOT NULL
      )
    ''');
  }

  Future<int> insertHolding(HoldingRecord record) async {
    final db = await database;
    return db.insert('holdings', _holdingToMap(record));
  }

  Future<List<HoldingRecord>> getHoldings() async {
    final db = await database;
    final rows = await db.query(
      'holdings',
      orderBy: 'recorded_at DESC, id DESC',
    );
    return rows.map(_holdingFromMap).toList();
  }

  Future<void> deleteHolding(int id) async {
    final db = await database;
    await db.delete('holdings', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteAllHoldings() async {
    final db = await database;
    await db.delete('holdings');
  }

  Future<void> saveRates(MarketRates rates) async {
    final db = await database;
    await db.insert('rate_snapshots', {
      'fetched_at': rates.fetchedAt.millisecondsSinceEpoch,
      'btc': rates.priceOf(CryptoAsset.btc),
      'hype': rates.priceOf(CryptoAsset.hype),
      'nexo': rates.priceOf(CryptoAsset.nexo),
      'usdt': rates.priceOf(CryptoAsset.usdt),
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
    return _ratesFromRow(rows.first);
  }

  Future<MarketRates?> getRatesAtOrBefore(DateTime time) async {
    final db = await database;
    final rows = await db.query(
      'rate_snapshots',
      where: 'fetched_at <= ?',
      whereArgs: [time.millisecondsSinceEpoch],
      orderBy: 'fetched_at DESC, id DESC',
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return _ratesFromRow(rows.first);
  }

  MarketRates? _ratesFromRow(Map<String, Object?> row) {
    final prices = {
      CryptoAsset.btc: _asDouble(row['btc']),
      CryptoAsset.hype: _asDouble(row['hype']),
      CryptoAsset.nexo: _asDouble(row['nexo']),
      CryptoAsset.usdt: _asDouble(row['usdt']),
    };
    if (prices.values.any((price) => price <= 0)) {
      return null;
    }
    return MarketRates(
      fetchedAt: DateTime.fromMillisecondsSinceEpoch(row['fetched_at']! as int),
      pricesUsdt: prices,
    );
  }

  Future<DailySnapshot?> getDailySnapshotByDay(String dayKey) async {
    final db = await database;
    final rows = await db.query(
      'daily_snapshots',
      where: 'day_key = ?',
      whereArgs: [dayKey],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return _dailySnapshotFromMap(rows.first);
  }

  Future<List<DailySnapshot>> getDailySnapshots() async {
    final db = await database;
    final rows = await db.query(
      'daily_snapshots',
      orderBy: 'day_key DESC, id DESC',
    );
    return rows.map(_dailySnapshotFromMap).toList();
  }

  Future<int> insertDailySnapshot(DailySnapshot snapshot) async {
    final db = await database;
    return db.insert('daily_snapshots', _dailySnapshotToMap(snapshot));
  }

  Future<int> deleteDailySnapshotByDay(String dayKey) async {
    final db = await database;
    return db.delete(
      'daily_snapshots',
      where: 'day_key = ?',
      whereArgs: [dayKey],
    );
  }

  Future<List<RebalanceProfit>> getRebalanceProfits() async {
    final db = await database;
    final rows = await db.query(
      'rebalance_profits',
      orderBy: 'recorded_at DESC, id DESC',
    );
    return rows.map(_rebalanceProfitFromMap).toList();
  }

  Future<RebalanceProfit?> getRebalanceProfitBySessionEndId(
    int sessionEndId,
  ) async {
    final db = await database;
    final rows = await db.query(
      'rebalance_profits',
      where: 'session_end_id = ?',
      whereArgs: [sessionEndId],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return _rebalanceProfitFromMap(rows.first);
  }

  Future<int> insertRebalanceProfit(RebalanceProfit profit) async {
    final db = await database;
    return db.insert('rebalance_profits', _rebalanceProfitToMap(profit));
  }

  Future<void> deleteAllRebalanceProfits() async {
    final db = await database;
    await db.delete('rebalance_profits');
  }

  Map<String, Object?> _holdingToMap(HoldingRecord record) {
    return {
      if (record.id != null) 'id': record.id,
      'recorded_at': record.recordedAt.millisecondsSinceEpoch,
      'location': record.location.code,
      'btc': record.amountOf(CryptoAsset.btc),
      'hype': record.amountOf(CryptoAsset.hype),
      'nexo': record.amountOf(CryptoAsset.nexo),
      'usdt': record.amountOf(CryptoAsset.usdt),
      'entry_kind': record.kind.code,
    };
  }

  HoldingRecord _holdingFromMap(Map<String, Object?> row) {
    return HoldingRecord(
      id: row['id']! as int,
      recordedAt: DateTime.fromMillisecondsSinceEpoch(
        row['recorded_at']! as int,
      ),
      location: StorageLocation.fromCode(row['location']! as String),
      amounts: {
        CryptoAsset.btc: _asDouble(row['btc']),
        CryptoAsset.hype: _asDouble(row['hype']),
        CryptoAsset.nexo: _asDouble(row['nexo']),
        CryptoAsset.usdt: _asDouble(row['usdt']),
      },
      kind: HoldingEntryKind.fromCode(row['entry_kind'] as String?),
    );
  }

  static double _asDouble(Object? value) {
    if (value is num) {
      return value.toDouble();
    }
    return 0;
  }

  Map<String, Object?> _dailySnapshotToMap(DailySnapshot snapshot) {
    Map<String, Object?> assetColumns(String prefix, CryptoAsset asset) {
      final item = snapshot.assetOf(asset);
      return {
        '${prefix}_amount': item.amount,
        '${prefix}_usdt': item.usdt,
        '${prefix}_target_amount': item.targetAmount,
        '${prefix}_current_weight': item.currentWeight,
        '${prefix}_target_weight': item.targetWeight,
      };
    }

    return {
      if (snapshot.id != null) 'id': snapshot.id,
      'day_key': snapshot.dayKey,
      'recorded_at': snapshot.recordedAt.millisecondsSinceEpoch,
      'total_usdt': snapshot.totalUsdt,
      'total_btc': snapshot.totalBtc,
      ...assetColumns('btc', CryptoAsset.btc),
      ...assetColumns('hype', CryptoAsset.hype),
      ...assetColumns('usdt', CryptoAsset.usdt),
      ...assetColumns('nexo', CryptoAsset.nexo),
    };
  }

  DailySnapshot _dailySnapshotFromMap(Map<String, Object?> row) {
    DailyAssetSnapshot assetOf(String prefix) {
      return DailyAssetSnapshot(
        amount: _asDouble(row['${prefix}_amount']),
        usdt: _asDouble(row['${prefix}_usdt']),
        targetAmount: _asDouble(row['${prefix}_target_amount']),
        currentWeight: _asDouble(row['${prefix}_current_weight']),
        targetWeight: _asDouble(row['${prefix}_target_weight']),
      );
    }

    return DailySnapshot(
      id: row['id']! as int,
      dayKey: row['day_key']! as String,
      recordedAt: DateTime.fromMillisecondsSinceEpoch(
        row['recorded_at']! as int,
      ),
      totalUsdt: _asDouble(row['total_usdt']),
      totalBtc: _asDouble(row['total_btc']),
      assets: {
        CryptoAsset.btc: assetOf('btc'),
        CryptoAsset.hype: assetOf('hype'),
        CryptoAsset.usdt: assetOf('usdt'),
        CryptoAsset.nexo: assetOf('nexo'),
      },
    );
  }

  Map<String, Object?> _rebalanceProfitToMap(RebalanceProfit profit) {
    return {
      if (profit.id != null) 'id': profit.id,
      'recorded_at': profit.recordedAt.millisecondsSinceEpoch,
      'session_started_at': profit.sessionStartedAt.millisecondsSinceEpoch,
      'session_ended_at': profit.sessionEndedAt.millisecondsSinceEpoch,
      'session_start_id': profit.sessionStartId,
      'session_end_id': profit.sessionEndId,
      'location': profit.location.code,
      'holding_id': profit.holdingId,
      'with_usdt': profit.withUsdt,
      'without_usdt': profit.withoutUsdt,
      'profit_usdt': profit.profitUsdt,
    };
  }

  RebalanceProfit _rebalanceProfitFromMap(Map<String, Object?> row) {
    return RebalanceProfit(
      id: row['id']! as int,
      recordedAt: DateTime.fromMillisecondsSinceEpoch(
        row['recorded_at']! as int,
      ),
      sessionStartedAt: DateTime.fromMillisecondsSinceEpoch(
        row['session_started_at']! as int,
      ),
      sessionEndedAt: DateTime.fromMillisecondsSinceEpoch(
        row['session_ended_at']! as int,
      ),
      sessionStartId: row['session_start_id']! as int,
      sessionEndId: row['session_end_id']! as int,
      location: StorageLocation.fromCode(
        (row['location'] as String?) ?? StorageLocation.nx.code,
      ),
      holdingId: row['holding_id'] as int?,
      withUsdt: _asDouble(row['with_usdt']),
      withoutUsdt: _asDouble(row['without_usdt']),
      profitUsdt: _asDouble(row['profit_usdt']),
    );
  }
}

final appDatabaseProvider = Provider<AppDatabase>((ref) => AppDatabase());
