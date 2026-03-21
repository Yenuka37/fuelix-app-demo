import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import '../models/user_model.dart';
import '../models/vehicle_model.dart';

class DbHelper {
  static final DbHelper _instance = DbHelper._internal();
  factory DbHelper() => _instance;
  DbHelper._internal();

  static Database? _database;

  static const String _dbName = 'fuelix.db';
  static const int _dbVersion = 4;
  static const String _usersTable = 'users';
  static const String _vehiclesTable = 'vehicles';

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

  // ── Schema ─────────────────────────────────────────────────────────────────
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
        created_at      TEXT NOT NULL,
        FOREIGN KEY (user_id) REFERENCES $_usersTable(id) ON DELETE CASCADE
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
  }

  // ── Password helper ────────────────────────────────────────────────────────
  String _hashPassword(String password) {
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // USER CRUD
  // ══════════════════════════════════════════════════════════════════════════
  Future<int> insertUser(UserModel user) async {
    final db = await database;
    final hashedUser = user.copyWith(password: _hashPassword(user.password));
    try {
      return await db.insert(
        _usersTable,
        hashedUser.toMap()..remove('id'),
        conflictAlgorithm: ConflictAlgorithm.fail,
      );
    } catch (_) {
      return -1;
    }
  }

  Future<UserModel?> validateLogin(String nic, String password) async {
    final db = await database;
    final hashedPassword = _hashPassword(password);
    final results = await db.query(
      _usersTable,
      where: 'nic = ? AND password = ?',
      whereArgs: [nic, hashedPassword],
      limit: 1,
    );
    return results.isNotEmpty ? UserModel.fromMap(results.first) : null;
  }

  Future<bool> nicExists(String nic) async {
    final db = await database;
    final results = await db.query(
      _usersTable,
      where: 'nic = ?',
      whereArgs: [nic],
      limit: 1,
    );
    return results.isNotEmpty;
  }

  Future<bool> emailExists(String email) async {
    final db = await database;
    final results = await db.query(
      _usersTable,
      where: 'email = ?',
      whereArgs: [email],
      limit: 1,
    );
    return results.isNotEmpty;
  }

  Future<bool> mobileExists(String mobile) async {
    final db = await database;
    final results = await db.query(
      _usersTable,
      where: 'mobile = ?',
      whereArgs: [mobile],
      limit: 1,
    );
    return results.isNotEmpty;
  }

  Future<UserModel?> getUserByNic(String nic) async {
    final db = await database;
    final results = await db.query(
      _usersTable,
      where: 'nic = ?',
      whereArgs: [nic],
      limit: 1,
    );
    return results.isNotEmpty ? UserModel.fromMap(results.first) : null;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // VEHICLE CRUD
  // ══════════════════════════════════════════════════════════════════════════

  /// Insert a new vehicle. Returns the new row id or -1 on failure.
  Future<int> insertVehicle(VehicleModel vehicle) async {
    final db = await database;
    try {
      return await db.insert(
        _vehiclesTable,
        vehicle.toMap()..remove('id'),
        conflictAlgorithm: ConflictAlgorithm.fail,
      );
    } catch (_) {
      return -1;
    }
  }

  /// Return all vehicles belonging to [userId].
  Future<List<VehicleModel>> getVehiclesByUser(int userId) async {
    final db = await database;
    final results = await db.query(
      _vehiclesTable,
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'created_at DESC',
    );
    return results.map(VehicleModel.fromMap).toList();
  }

  /// Update an existing vehicle record.
  Future<int> updateVehicle(VehicleModel vehicle) async {
    final db = await database;
    return await db.update(
      _vehiclesTable,
      vehicle.toMap(),
      where: 'id = ?',
      whereArgs: [vehicle.id],
    );
  }

  /// Delete a vehicle by id.
  Future<int> deleteVehicle(int vehicleId) async {
    final db = await database;
    return await db.delete(
      _vehiclesTable,
      where: 'id = ?',
      whereArgs: [vehicleId],
    );
  }

  /// Check if a registration number is already registered for this user.
  Future<bool> regNoExists(String regNo, int userId, {int? excludeId}) async {
    final db = await database;
    final results = await db.query(
      _vehiclesTable,
      where: excludeId != null
          ? 'registration_no = ? AND user_id = ? AND id != ?'
          : 'registration_no = ? AND user_id = ?',
      whereArgs: excludeId != null
          ? [regNo, userId, excludeId]
          : [regNo, userId],
      limit: 1,
    );
    return results.isNotEmpty;
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
