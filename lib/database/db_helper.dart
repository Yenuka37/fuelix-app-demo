import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import '../models/user_model.dart';
import '../models/vehicle_model.dart';
import '../models/quota_model.dart';
import '../models/topup_model.dart';
import '../models/fuel_log_model.dart';
import '../services/quota_service.dart';

class DbHelper {
  static final DbHelper _instance = DbHelper._internal();
  factory DbHelper() => _instance;
  DbHelper._internal();

  static Database? _database;

  static const String _dbName = 'fuelix.db';
  static const int _dbVersion = 8;
  static const String _usersTable = 'users';
  static const String _vehiclesTable = 'vehicles';
  static const String _quotasTable = 'fuel_quotas';
  static const String _walletTable = 'wallets';
  static const String _topupTable = 'topup_transactions';
  static const String _fuelLogsTable = 'fuel_logs';

  Future<Database> get database async {
    _database ??= await _initDb();
    return _database!;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _dbName);
    return await openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Schema
  // ══════════════════════════════════════════════════════════════════════════
  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $_usersTable (
        id            INTEGER PRIMARY KEY AUTOINCREMENT,
        first_name    TEXT NOT NULL,
        last_name     TEXT NOT NULL,
        nic           TEXT NOT NULL UNIQUE,
        mobile        TEXT NOT NULL DEFAULT '',
        address_line1 TEXT NOT NULL DEFAULT '',
        address_line2 TEXT NOT NULL DEFAULT '',
        address_line3 TEXT NOT NULL DEFAULT '',
        district      TEXT NOT NULL DEFAULT '',
        province      TEXT NOT NULL DEFAULT '',
        postal_code   TEXT NOT NULL DEFAULT '',
        email         TEXT NOT NULL UNIQUE,
        password      TEXT NOT NULL,
        created_at    TEXT NOT NULL
      )
    ''');
    await _createVehiclesTable(db);
    await _createQuotasTable(db);
    await _createWalletTable(db);
    await _createTopupTable(db);
    await _createFuelLogsTable(db);
  }

  Future<void> _createVehiclesTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_vehiclesTable (
        id              INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id         INTEGER NOT NULL,
        type            TEXT NOT NULL,
        make            TEXT NOT NULL,
        model           TEXT NOT NULL,
        year            TEXT NOT NULL,
        registration_no TEXT NOT NULL,
        fuel_type       TEXT NOT NULL,
        engine_cc       TEXT NOT NULL DEFAULT '',
        color           TEXT NOT NULL DEFAULT '',
        fuel_pass_code  TEXT,
        qr_generated_at TEXT,
        created_at      TEXT NOT NULL,
        FOREIGN KEY (user_id) REFERENCES $_usersTable(id) ON DELETE CASCADE
      )
    ''');
  }

  Future<void> _createQuotasTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_quotasTable (
        id            INTEGER PRIMARY KEY AUTOINCREMENT,
        vehicle_id    INTEGER NOT NULL,
        week_start    TEXT NOT NULL,
        week_end      TEXT NOT NULL,
        quota_litres  REAL NOT NULL,
        used_litres   REAL NOT NULL DEFAULT 0.0,
        FOREIGN KEY (vehicle_id) REFERENCES $_vehiclesTable(id) ON DELETE CASCADE
      )
    ''');
  }

  Future<void> _createWalletTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_walletTable (
        user_id    INTEGER PRIMARY KEY,
        balance    REAL    NOT NULL DEFAULT 0.0,
        updated_at TEXT    NOT NULL,
        FOREIGN KEY (user_id) REFERENCES $_usersTable(id) ON DELETE CASCADE
      )
    ''');
  }

  Future<void> _createTopupTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_topupTable (
        id         INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id    INTEGER NOT NULL,
        amount     REAL    NOT NULL,
        method     TEXT    NOT NULL,
        status     TEXT    NOT NULL DEFAULT 'completed',
        reference  TEXT,
        created_at TEXT    NOT NULL,
        FOREIGN KEY (user_id) REFERENCES $_usersTable(id) ON DELETE CASCADE
      )
    ''');
  }

  Future<void> _createFuelLogsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_fuelLogsTable (
        id              INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id         INTEGER NOT NULL,
        vehicle_id      INTEGER NOT NULL,
        litres          REAL    NOT NULL,
        fuel_type       TEXT    NOT NULL,
        fuel_grade      TEXT    NOT NULL DEFAULT '',
        price_per_litre REAL    NOT NULL DEFAULT 0.0,
        total_cost      REAL    NOT NULL DEFAULT 0.0,
        station_name    TEXT    NOT NULL DEFAULT '',
        logged_at       TEXT    NOT NULL,
        FOREIGN KEY (user_id)    REFERENCES $_usersTable(id)    ON DELETE CASCADE,
        FOREIGN KEY (vehicle_id) REFERENCES $_vehiclesTable(id) ON DELETE CASCADE
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute(
        "ALTER TABLE $_usersTable ADD COLUMN mobile        TEXT NOT NULL DEFAULT ''",
      );
      await db.execute(
        "ALTER TABLE $_usersTable ADD COLUMN address_line1 TEXT NOT NULL DEFAULT ''",
      );
    }
    if (oldVersion < 3) {
      try {
        await db.execute(
          "ALTER TABLE $_usersTable ADD COLUMN address_line2 TEXT NOT NULL DEFAULT ''",
        );
        await db.execute(
          "ALTER TABLE $_usersTable ADD COLUMN address_line3 TEXT NOT NULL DEFAULT ''",
        );
        await db.execute(
          "ALTER TABLE $_usersTable ADD COLUMN district      TEXT NOT NULL DEFAULT ''",
        );
        await db.execute(
          "ALTER TABLE $_usersTable ADD COLUMN province      TEXT NOT NULL DEFAULT ''",
        );
        await db.execute(
          "ALTER TABLE $_usersTable ADD COLUMN postal_code   TEXT NOT NULL DEFAULT ''",
        );
      } catch (_) {}
    }
    if (oldVersion < 4) await _createVehiclesTable(db);
    if (oldVersion < 5) {
      try {
        await db.execute(
          "ALTER TABLE $_vehiclesTable ADD COLUMN fuel_pass_code  TEXT",
        );
        await db.execute(
          "ALTER TABLE $_vehiclesTable ADD COLUMN qr_generated_at TEXT",
        );
      } catch (_) {}
    }
    if (oldVersion < 6) await _createQuotasTable(db);
    if (oldVersion < 7) {
      await _createWalletTable(db);
      await _createTopupTable(db);
    }
    if (oldVersion < 8) await _createFuelLogsTable(db);
  }

  // ══════════════════════════════════════════════════════════════════════════
  // USER CRUD
  // ══════════════════════════════════════════════════════════════════════════
  String _hashPassword(String p) => sha256.convert(utf8.encode(p)).toString();

  Future<int> insertUser(UserModel user) async {
    final db = await database;
    try {
      final id = await db.insert(
        _usersTable,
        user.copyWith(password: _hashPassword(user.password)).toMap()
          ..remove('id'),
        conflictAlgorithm: ConflictAlgorithm.fail,
      );
      await db.insert(_walletTable, {
        'user_id': id,
        'balance': 0.0,
        'updated_at': DateTime.now().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
      return id;
    } catch (_) {
      return -1;
    }
  }

  Future<UserModel?> validateLogin(String nic, String password) async {
    final db = await database;
    final r = await db.query(
      _usersTable,
      where: 'nic = ? AND password = ?',
      whereArgs: [nic, _hashPassword(password)],
      limit: 1,
    );
    return r.isNotEmpty ? UserModel.fromMap(r.first) : null;
  }

  Future<bool> nicExists(String nic) async {
    final db = await database;
    return (await db.query(
      _usersTable,
      where: 'nic = ?',
      whereArgs: [nic],
      limit: 1,
    )).isNotEmpty;
  }

  Future<bool> emailExists(String email) async {
    final db = await database;
    return (await db.query(
      _usersTable,
      where: 'email = ?',
      whereArgs: [email],
      limit: 1,
    )).isNotEmpty;
  }

  Future<bool> mobileExists(String mobile) async {
    final db = await database;
    return (await db.query(
      _usersTable,
      where: 'mobile = ?',
      whereArgs: [mobile],
      limit: 1,
    )).isNotEmpty;
  }

  Future<UserModel?> getUserByNic(String nic) async {
    final db = await database;
    final r = await db.query(
      _usersTable,
      where: 'nic = ?',
      whereArgs: [nic],
      limit: 1,
    );
    return r.isNotEmpty ? UserModel.fromMap(r.first) : null;
  }

  Future<int> updateUser(UserModel user) async {
    final db = await database;
    return db.update(
      _usersTable,
      user.toMap(),
      where: 'id = ?',
      whereArgs: [user.id],
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // VEHICLE CRUD
  // ══════════════════════════════════════════════════════════════════════════
  Future<int> insertVehicle(VehicleModel v) async {
    final db = await database;
    try {
      return await db.insert(
        _vehiclesTable,
        v.toMap()..remove('id'),
        conflictAlgorithm: ConflictAlgorithm.fail,
      );
    } catch (_) {
      return -1;
    }
  }

  Future<List<VehicleModel>> getVehiclesByUser(int userId) async {
    final db = await database;
    final r = await db.query(
      _vehiclesTable,
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'created_at DESC',
    );
    return r.map(VehicleModel.fromMap).toList();
  }

  Future<int> updateVehicle(VehicleModel v) async {
    final db = await database;
    return db.update(
      _vehiclesTable,
      v.toMap(),
      where: 'id = ?',
      whereArgs: [v.id],
    );
  }

  Future<int> deleteVehicle(int id) async {
    final db = await database;
    return db.delete(_vehiclesTable, where: 'id = ?', whereArgs: [id]);
  }

  Future<bool> regNoExists(String regNo, int userId, {int? excludeId}) async {
    final db = await database;
    final r = await db.query(
      _vehiclesTable,
      where: excludeId != null
          ? 'registration_no = ? AND user_id = ? AND id != ?'
          : 'registration_no = ? AND user_id = ?',
      whereArgs: excludeId != null
          ? [regNo, userId, excludeId]
          : [regNo, userId],
      limit: 1,
    );
    return r.isNotEmpty;
  }

  Future<bool> fuelPassCodeExists(String code) async {
    final db = await database;
    return (await db.query(
      _vehiclesTable,
      where: 'fuel_pass_code = ?',
      whereArgs: [code],
      limit: 1,
    )).isNotEmpty;
  }

  Future<bool> setFuelPassCode(
    int vehicleId,
    String code,
    String vehicleType,
  ) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    int rows = 0;
    await db.transaction((txn) async {
      rows = await txn.update(
        _vehiclesTable,
        {'fuel_pass_code': code, 'qr_generated_at': now},
        where: 'id = ? AND fuel_pass_code IS NULL',
        whereArgs: [vehicleId],
      );
      if (rows == 1) {
        final q = QuotaService.newWeekQuota(vehicleId, vehicleType);
        await txn.insert(_quotasTable, q.toMap()..remove('id'));
      }
    });
    return rows == 1;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // QUOTA CRUD
  // ══════════════════════════════════════════════════════════════════════════
  Future<FuelQuotaModel?> getCurrentWeekQuota(
    int vehicleId,
    String vehicleType,
  ) async {
    final db = await database;
    final now = DateTime.now();
    final rows = await db.query(
      _quotasTable,
      where: 'vehicle_id = ?',
      whereArgs: [vehicleId],
      orderBy: 'week_start DESC',
      limit: 1,
    );
    if (rows.isNotEmpty) {
      final existing = FuelQuotaModel.fromMap(rows.first);
      if (QuotaService.isCurrentWeek(existing, now)) return existing;
    }
    final fresh = QuotaService.newWeekQuota(vehicleId, vehicleType);
    final id = await db.insert(_quotasTable, fresh.toMap()..remove('id'));
    return fresh.copyWith(id: id);
  }

  Future<List<FuelQuotaModel>> getQuotaHistory(int vehicleId) async {
    final db = await database;
    final r = await db.query(
      _quotasTable,
      where: 'vehicle_id = ?',
      whereArgs: [vehicleId],
      orderBy: 'week_start DESC',
    );
    return r.map(FuelQuotaModel.fromMap).toList();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // WALLET CRUD
  // ══════════════════════════════════════════════════════════════════════════
  Future<WalletModel> getWallet(int userId) async {
    final db = await database;
    final r = await db.query(
      _walletTable,
      where: 'user_id = ?',
      whereArgs: [userId],
      limit: 1,
    );
    if (r.isNotEmpty) return WalletModel.fromMap(r.first);
    final wallet = WalletModel(
      userId: userId,
      balance: 0.0,
      updatedAt: DateTime.now(),
    );
    await db.insert(
      _walletTable,
      wallet.toMap(),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    return wallet;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // TOPUP TRANSACTIONS
  // ══════════════════════════════════════════════════════════════════════════
  Future<TopUpTransactionModel?> processTopUp({
    required int userId,
    required double amount,
    required String method,
    String? reference,
  }) async {
    final db = await database;
    TopUpTransactionModel? result;
    await db.transaction((txn) async {
      final walletRows = await txn.query(
        _walletTable,
        where: 'user_id = ?',
        whereArgs: [userId],
        limit: 1,
      );
      final currentBalance = walletRows.isNotEmpty
          ? (walletRows.first['balance'] as num).toDouble()
          : 0.0;
      final newBalance = currentBalance + amount;
      final now = DateTime.now().toIso8601String();
      if (walletRows.isEmpty) {
        await txn.insert(_walletTable, {
          'user_id': userId,
          'balance': newBalance,
          'updated_at': now,
        });
      } else {
        await txn.update(
          _walletTable,
          {'balance': newBalance, 'updated_at': now},
          where: 'user_id = ?',
          whereArgs: [userId],
        );
      }
      final txn2 = TopUpTransactionModel(
        userId: userId,
        amount: amount,
        method: method,
        status: TopUpStatus.completed,
        reference: reference ?? _generateRef(),
        createdAt: DateTime.now(),
      );
      final id = await txn.insert(_topupTable, txn2.toMap()..remove('id'));
      result = TopUpTransactionModel(
        id: id,
        userId: txn2.userId,
        amount: txn2.amount,
        method: txn2.method,
        status: txn2.status,
        reference: txn2.reference,
        createdAt: txn2.createdAt,
      );
    });
    return result;
  }

  Future<List<TopUpTransactionModel>> getTopUpHistory(int userId) async {
    final db = await database;
    final r = await db.query(
      _topupTable,
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'created_at DESC',
    );
    return r.map(TopUpTransactionModel.fromMap).toList();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // FUEL LOGS — atomic save (quota deduction + wallet deduction)
  // ══════════════════════════════════════════════════════════════════════════

  /// Saves a fuel log inside a single transaction:
  ///   1. Ensures a current-week quota record exists.
  ///   2. Checks litre headroom  → returns -1 if exceeded.
  ///   3. Checks wallet balance  → returns -2 if insufficient.
  ///   4. Deducts litres from quota.
  ///   5. Deducts total_cost from wallet.
  ///   6. Inserts the fuel log row.
  ///
  /// Returns inserted row id (>0) on success, or:
  ///   -1  quota limit exceeded
  ///   -2  wallet balance insufficient
  ///   -3  other db error
  Future<int> saveFuelLog(FuelLogModel log, String vehicleType) async {
    final db = await database;
    int resultId = -3;

    await db.transaction((txn) async {
      // ── 1. Get or create current-week quota ───────────────────────────────
      final quotaRows = await txn.query(
        _quotasTable,
        where: 'vehicle_id = ?',
        whereArgs: [log.vehicleId],
        orderBy: 'week_start DESC',
        limit: 1,
      );

      FuelQuotaModel quota;
      if (quotaRows.isNotEmpty) {
        final existing = FuelQuotaModel.fromMap(quotaRows.first);
        if (QuotaService.isCurrentWeek(existing, DateTime.now())) {
          quota = existing;
        } else {
          final fresh = QuotaService.newWeekQuota(log.vehicleId, vehicleType);
          final newId = await txn.insert(
            _quotasTable,
            fresh.toMap()..remove('id'),
          );
          quota = fresh.copyWith(id: newId);
        }
      } else {
        final fresh = QuotaService.newWeekQuota(log.vehicleId, vehicleType);
        final newId = await txn.insert(
          _quotasTable,
          fresh.toMap()..remove('id'),
        );
        quota = fresh.copyWith(id: newId);
      }

      // ── 2. Validate litre limit ────────────────────────────────────────────
      if (log.litres > quota.remainingLitres + 0.001) {
        resultId = -1;
        return;
      }

      // ── 3. Validate wallet balance ─────────────────────────────────────────
      final walletRows = await txn.query(
        _walletTable,
        where: 'user_id = ?',
        whereArgs: [log.userId],
        limit: 1,
      );
      final currentBalance = walletRows.isNotEmpty
          ? (walletRows.first['balance'] as num).toDouble()
          : 0.0;

      if (log.totalCost > currentBalance + 0.001) {
        resultId = -2;
        return;
      }

      // ── 4. Deduct from quota ───────────────────────────────────────────────
      await txn.update(
        _quotasTable,
        {'used_litres': quota.usedLitres + log.litres},
        where: 'id = ?',
        whereArgs: [quota.id],
      );

      // ── 5. Deduct from wallet ──────────────────────────────────────────────
      final newBalance = currentBalance - log.totalCost;
      final now = DateTime.now().toIso8601String();
      if (walletRows.isEmpty) {
        await txn.insert(_walletTable, {
          'user_id': log.userId,
          'balance': newBalance,
          'updated_at': now,
        });
      } else {
        await txn.update(
          _walletTable,
          {'balance': newBalance, 'updated_at': now},
          where: 'user_id = ?',
          whereArgs: [log.userId],
        );
      }

      // ── 6. Insert fuel log ─────────────────────────────────────────────────
      resultId = await txn.insert(_fuelLogsTable, log.toMap()..remove('id'));
    });

    return resultId;
  }

  /// All fuel logs for a user, newest first.
  Future<List<FuelLogModel>> getFuelLogsByUser(int userId, {int? limit}) async {
    final db = await database;
    final r = await db.query(
      _fuelLogsTable,
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'logged_at DESC',
      limit: limit,
    );
    return r.map(FuelLogModel.fromMap).toList();
  }

  /// Fuel logs for a specific vehicle, newest first.
  Future<List<FuelLogModel>> getFuelLogsByVehicle(
    int vehicleId, {
    int? limit,
  }) async {
    final db = await database;
    final r = await db.query(
      _fuelLogsTable,
      where: 'vehicle_id = ?',
      whereArgs: [vehicleId],
      orderBy: 'logged_at DESC',
      limit: limit,
    );
    return r.map(FuelLogModel.fromMap).toList();
  }

  /// Delete a single fuel log entry.
  Future<int> deleteFuelLog(int id) async {
    final db = await database;
    return db.delete(_fuelLogsTable, where: 'id = ?', whereArgs: [id]);
  }

  /// Aggregate stats for a user: total logs, total litres, total spent.
  Future<Map<String, double>> getFuelLogStats(int userId) async {
    final db = await database;
    final r = await db.rawQuery(
      '''
      SELECT
        COUNT(*)        AS total_logs,
        SUM(litres)     AS total_litres,
        SUM(total_cost) AS total_spent
      FROM $_fuelLogsTable
      WHERE user_id = ?
    ''',
      [userId],
    );
    if (r.isEmpty) {
      return {'total_logs': 0, 'total_litres': 0, 'total_spent': 0};
    }
    final row = r.first;
    return {
      'total_logs': (row['total_logs'] as num?)?.toDouble() ?? 0,
      'total_litres': (row['total_litres'] as num?)?.toDouble() ?? 0,
      'total_spent': (row['total_spent'] as num?)?.toDouble() ?? 0,
    };
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  String _generateRef() {
    final now = DateTime.now();
    return 'FX${now.millisecondsSinceEpoch.toRadixString(36).toUpperCase()}';
  }

  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }
}
