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
  static const int _dbVersion = 1;
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
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        first_name TEXT NOT NULL,
        last_name TEXT NOT NULL,
        nic TEXT NOT NULL UNIQUE,
        email TEXT NOT NULL UNIQUE,
        password TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Handle future migrations here
  }

  // Hash password using SHA-256
  String _hashPassword(String password) {
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  // Insert new user
  Future<int> insertUser(UserModel user) async {
    final db = await database;
    final hashedUser = user.copyWith(password: _hashPassword(user.password));
    try {
      return await db.insert(
        _usersTable,
        hashedUser.toMap()..remove('id'),
        conflictAlgorithm: ConflictAlgorithm.fail,
      );
    } catch (e) {
      return -1;
    }
  }

  // Validate login by NIC and password
  Future<UserModel?> validateLogin(String nic, String password) async {
    final db = await database;
    final hashedPassword = _hashPassword(password);

    final results = await db.query(
      _usersTable,
      where: 'nic = ? AND password = ?',
      whereArgs: [nic, hashedPassword],
      limit: 1,
    );

    if (results.isNotEmpty) {
      return UserModel.fromMap(results.first);
    }
    return null;
  }

  // Check if NIC already exists
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

  // Check if email already exists
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

  // Get user by NIC
  Future<UserModel?> getUserByNic(String nic) async {
    final db = await database;
    final results = await db.query(
      _usersTable,
      where: 'nic = ?',
      whereArgs: [nic],
      limit: 1,
    );
    if (results.isNotEmpty) {
      return UserModel.fromMap(results.first);
    }
    return null;
  }

  // Close database
  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }
}
