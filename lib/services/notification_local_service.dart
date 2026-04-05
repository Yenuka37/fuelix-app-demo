import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/notification_model.dart';

class NotificationLocalService {
  static final NotificationLocalService _instance =
      NotificationLocalService._internal();
  factory NotificationLocalService() => _instance;
  NotificationLocalService._internal();

  static Database? _database;
  static const String _dbName = 'fuelix_notifications.db';
  static const int _dbVersion = 1;
  static const String _tableName = 'notification_read_status';

  Future<Database> get database async {
    _database ??= await _initDb();
    return _database!;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _dbName);

    return await openDatabase(path, version: _dbVersion, onCreate: _onCreate);
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $_tableName (
        notification_id INTEGER PRIMARY KEY,
        is_read INTEGER NOT NULL DEFAULT 0,
        updated_at TEXT NOT NULL
      )
    ''');
  }

  // Get read status for a specific notification
  Future<bool> isNotificationRead(int notificationId) async {
    final db = await database;
    final result = await db.query(
      _tableName,
      where: 'notification_id = ?',
      whereArgs: [notificationId],
    );

    if (result.isNotEmpty) {
      return (result.first['is_read'] as int) == 1;
    }
    return false;
  }

  // Get read status for multiple notifications
  Future<Map<int, bool>> getReadStatus(List<int> notificationIds) async {
    if (notificationIds.isEmpty) return {};

    final db = await database;
    final placeholders = notificationIds.map((_) => '?').join(',');
    final result = await db.query(
      _tableName,
      where: 'notification_id IN ($placeholders)',
      whereArgs: notificationIds,
    );

    final Map<int, bool> statusMap = {};
    for (var row in result) {
      statusMap[row['notification_id'] as int] = (row['is_read'] as int) == 1;
    }
    return statusMap;
  }

  // Mark a notification as read
  Future<void> markAsRead(int notificationId) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();

    await db.insert(_tableName, {
      'notification_id': notificationId,
      'is_read': 1,
      'updated_at': now,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // Mark multiple notifications as read
  Future<void> markMultipleAsRead(List<int> notificationIds) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();

    for (var id in notificationIds) {
      await db.insert(_tableName, {
        'notification_id': id,
        'is_read': 1,
        'updated_at': now,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  // Mark all notifications as read
  Future<void> markAllAsRead(List<int> notificationIds) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();

    for (var id in notificationIds) {
      await db.insert(_tableName, {
        'notification_id': id,
        'is_read': 1,
        'updated_at': now,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  // Clear read status for a notification (mark as unread)
  Future<void> markAsUnread(int notificationId) async {
    final db = await database;
    await db.delete(
      _tableName,
      where: 'notification_id = ?',
      whereArgs: [notificationId],
    );
  }

  // Clear all read statuses
  Future<void> clearAllReadStatus() async {
    final db = await database;
    await db.delete(_tableName);
  }

  // Get all read notification IDs
  Future<List<int>> getAllReadNotificationIds() async {
    final db = await database;
    final result = await db.query(_tableName, where: 'is_read = 1');
    return result.map((row) => row['notification_id'] as int).toList();
  }
}
