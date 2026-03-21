import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import '../models/user_model.dart';
import '../models/vehicle_model.dart';
import '../models/quota_model.dart';
import '../services/quota_service.dart';

class DbHelper {
  static final DbHelper _instance = DbHelper._internal();
  factory DbHelper() => _instance;
  DbHelper._internal();

  static Database? _database;

  static const String _dbName = 'fuelix.db';
  static const int _dbVersion = 6;
  static const String _usersTable = 'users';
  static const String _vehiclesTable = 'vehicles';
  static const String _quotasTable = 'fuel_quotas';

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
    if (oldVersion < 4) {
      await _createVehiclesTable(db);
    }
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
    if (oldVersion < 6) {
      await _createQuotasTable(db);
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // USER CRUD
  // ══════════════════════════════════════════════════════════════════════════
  String _hashPassword(String p) => sha256.convert(utf8.encode(p)).toString();

  Future<int> insertUser(UserModel user) async {
    final db = await database;
    try {
      return await db.insert(
        _usersTable,
        user.copyWith(password: _hashPassword(user.password)).toMap()
          ..remove('id'),
        conflictAlgorithm: ConflictAlgorithm.fail,
      );
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

  /// Stamp QR code + create first week quota atomically.
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
        // Create first week quota immediately
        final q = QuotaService.newWeekQuota(vehicleId, vehicleType);
        await txn.insert(_quotasTable, q.toMap()..remove('id'));
      }
    });
    return rows == 1;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // QUOTA CRUD
  // ══════════════════════════════════════════════════════════════════════════

  /// Get the current week's quota for [vehicleId].
  /// If the stored record belongs to a past week → create a fresh one (reset).
  /// Balance does NOT carry over (per requirements).
  Future<FuelQuotaModel?> getCurrentWeekQuota(
    int vehicleId,
    String vehicleType,
  ) async {
    final db = await database;
    final now = DateTime.now();

    // Fetch the latest record for this vehicle
    final rows = await db.query(
      _quotasTable,
      where: 'vehicle_id = ?',
      whereArgs: [vehicleId],
      orderBy: 'week_start DESC',
      limit: 1,
    );

    if (rows.isNotEmpty) {
      final existing = FuelQuotaModel.fromMap(rows.first);
      // Still in the same week → return as-is
      if (QuotaService.isCurrentWeek(existing, now)) return existing;
    }

    // Either no record yet, or a past week → insert fresh quota (reset)
    final fresh = QuotaService.newWeekQuota(vehicleId, vehicleType);
    final id = await db.insert(_quotasTable, fresh.toMap()..remove('id'));
    return fresh.copyWith(id: id);
  }

  /// All quota records for a vehicle (history), newest first.
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

  /// Record fuel usage against the current week's quota.
  /// Returns the updated [FuelQuotaModel] or null on failure.
  Future<FuelQuotaModel?> recordFuelUsage(
    int vehicleId,
    String vehicleType,
    double litres,
  ) async {
    final db = await database;
    final quota = await getCurrentWeekQuota(vehicleId, vehicleType);
    if (quota == null || quota.id == null) return null;

    final newUsed = (quota.usedLitres + litres).clamp(0.0, quota.quotaLitres);
    await db.update(
      _quotasTable,
      {'used_litres': newUsed},
      where: 'id = ?',
      whereArgs: [quota.id],
    );
    return quota.copyWith(usedLitres: newUsed);
  }

  // ── Close ──────────────────────────────────────────────────────────────────
  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }
}
