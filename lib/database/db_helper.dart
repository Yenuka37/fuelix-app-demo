import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import '../models/user_model.dart';

class DbHelper {
  static final DbHelper _instance = DbHelper._internal();
  factory DbHelper() => _instance;
  DbHelper._internal();

  static Database? _database;

  static const String _dbName = 'fuelix.db';
  static const int _dbVersion = 3; // bumped for address columns
  static const String _usersTable = 'users';

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
      // Rename old single-address column if it exists (best-effort)
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
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  String _hashPassword(String password) {
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  // ── CRUD ───────────────────────────────────────────────────────────────────
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

  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }
}
