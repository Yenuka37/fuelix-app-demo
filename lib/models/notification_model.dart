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

  factory NotificationModel.fromJson(
    Map<String, dynamic> json, {
    bool? isReadOverride,
  }) {
    // Parse data field
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
      isRead: isReadOverride ?? false,
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
