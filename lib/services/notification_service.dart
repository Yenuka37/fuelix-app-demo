import 'package:shared_preferences/shared_preferences.dart';
import '../models/notification_model.dart';

class NotificationService {
  static const String _notificationsKey = 'notifications';
  static const String _nextIdKey = 'next_notification_id';

  static Future<List<NotificationModel>> getNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    final notificationsJson = prefs.getStringList(_notificationsKey) ?? [];

    return notificationsJson
        .map((json) => NotificationModel.fromMap(_parseJson(json)))
        .toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  static Future<void> addNotification(NotificationModel notification) async {
    final prefs = await SharedPreferences.getInstance();
    final notifications = await getNotifications();

    notifications.insert(0, notification);

    // Keep only last 50 notifications
    final limitedNotifications = notifications.take(50).toList();

    final notificationsJson = limitedNotifications
        .map((n) => _toJsonString(n.toMap()))
        .toList();

    await prefs.setStringList(_notificationsKey, notificationsJson);
  }

  static Future<void> markAsRead(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final notifications = await getNotifications();

    final updatedNotifications = notifications.map((n) {
      if (n.id == id) {
        return n.copyWith(isRead: true);
      }
      return n;
    }).toList();

    final notificationsJson = updatedNotifications
        .map((n) => _toJsonString(n.toMap()))
        .toList();

    await prefs.setStringList(_notificationsKey, notificationsJson);
  }

  static Future<void> markAllAsRead() async {
    final prefs = await SharedPreferences.getInstance();
    final notifications = await getNotifications();

    final updatedNotifications = notifications
        .map((n) => n.copyWith(isRead: true))
        .toList();

    final notificationsJson = updatedNotifications
        .map((n) => _toJsonString(n.toMap()))
        .toList();

    await prefs.setStringList(_notificationsKey, notificationsJson);
  }

  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_notificationsKey);
  }

  static Future<String> _getNextId() async {
    final prefs = await SharedPreferences.getInstance();
    final nextId = prefs.getInt(_nextIdKey) ?? 1;
    await prefs.setInt(_nextIdKey, nextId + 1);
    return nextId.toString();
  }

  static Future<void> addQuotaUpdateNotification({
    required String vehicleType,
    required double oldQuota,
    required double newQuota,
    required String updatedBy,
  }) async {
    final id = await _getNextId();
    final notification = NotificationModel(
      id: id,
      title: 'Weekly Quota Update',
      message:
          'Your $vehicleType weekly fuel quota will change from ${oldQuota.toStringAsFixed(0)}L to ${newQuota.toStringAsFixed(0)}L starting next Monday.',
      timestamp: DateTime.now(),
      type: NotificationType.quotaUpdate,
      data: {
        'vehicleType': vehicleType,
        'oldQuota': oldQuota,
        'newQuota': newQuota,
        'effectiveDate': _getNextMonday().toIso8601String(),
      },
    );
    await addNotification(notification);
  }

  static DateTime _getNextMonday() {
    final now = DateTime.now();
    final daysUntilMonday = (DateTime.monday - now.weekday + 7) % 7;
    final nextMonday = now.add(Duration(days: daysUntilMonday));
    return DateTime(nextMonday.year, nextMonday.month, nextMonday.day);
  }

  static String _toJsonString(Map<String, dynamic> map) {
    final List<String> parts = [];
    for (var entry in map.entries) {
      parts.add('${entry.key}:${entry.value.toString()}');
    }
    return parts.join('||');
  }

  static Map<String, dynamic> _parseJson(String str) {
    final Map<String, dynamic> result = {};
    final parts = str.split('||');
    for (var part in parts) {
      final colonIndex = part.indexOf(':');
      if (colonIndex != -1) {
        final key = part.substring(0, colonIndex);
        final value = part.substring(colonIndex + 1);
        result[key] = value;
      }
    }
    return result;
  }
}
