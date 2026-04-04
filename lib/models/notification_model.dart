import 'dart:convert';

class NotificationModel {
  final int id;
  final String title;
  final String message;
  final String notificationType;
  final DateTime createdAt;
  final bool isRead;
  final Map<String, dynamic>? data;

  NotificationModel({
    required this.id,
    required this.title,
    required this.message,
    required this.notificationType,
    required this.createdAt,
    required this.isRead,
    this.data,
  });

  String get formattedDate {
    final now = DateTime.now();
    final diff = now.difference(createdAt);
    if (diff.inDays > 0) {
      return '${diff.inDays} day${diff.inDays == 1 ? '' : 's'} ago';
    } else if (diff.inHours > 0) {
      return '${diff.inHours} hour${diff.inHours == 1 ? '' : 's'} ago';
    } else if (diff.inMinutes > 0) {
      return '${diff.inMinutes} minute${diff.inMinutes == 1 ? '' : 's'} ago';
    } else {
      return 'Just now';
    }
  }

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    // Handle isRead - could be bool, int, or String from backend
    bool isReadValue = false;

    if (json['isRead'] != null) {
      if (json['isRead'] is bool) {
        isReadValue = json['isRead'] as bool;
      } else if (json['isRead'] is int) {
        isReadValue = (json['isRead'] as int) == 1;
      } else if (json['isRead'] is String) {
        final str = (json['isRead'] as String).toLowerCase();
        isReadValue = str == 'true' || str == '1';
      } else if (json['isRead'] is num) {
        isReadValue = (json['isRead'] as num) == 1;
      }
    }

    print(
      '🔍 Notification ${json['id']} - isRead raw: ${json['isRead']} (${json['isRead'].runtimeType}) -> parsed: $isReadValue',
    );

    // Parse data field - it might be a String (JSON) or already a Map
    Map<String, dynamic>? parsedData;

    if (json['data'] != null) {
      if (json['data'] is Map<String, dynamic>) {
        parsedData = json['data'] as Map<String, dynamic>;
      } else if (json['data'] is String) {
        try {
          final decoded = jsonDecode(json['data'] as String);
          if (decoded is Map<String, dynamic>) {
            parsedData = decoded;
          }
        } catch (e) {
          print('Error parsing data JSON: $e');
          parsedData = null;
        }
      }
    }

    return NotificationModel(
      id: json['id'] as int,
      title: json['title'] as String,
      message: json['message'] as String,
      notificationType: json['notificationType'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      isRead: isReadValue,
      data: parsedData,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'message': message,
    'notificationType': notificationType,
    'createdAt': createdAt.toIso8601String(),
    'isRead': isRead,
    'data': data != null ? jsonEncode(data) : null,
  };

  NotificationModel copyWith({bool? isRead}) {
    return NotificationModel(
      id: id,
      title: title,
      message: message,
      notificationType: notificationType,
      createdAt: createdAt,
      isRead: isRead ?? this.isRead,
      data: data,
    );
  }
}
