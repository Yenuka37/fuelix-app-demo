import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/io.dart';
import '../models/notification_model.dart';
import '../services/notification_service.dart';
import 'api_service.dart';

class QuotaWebSocketService {
  static QuotaWebSocketService? _instance;
  static QuotaWebSocketService get instance {
    _instance ??= QuotaWebSocketService._internal();
    return _instance!;
  }

  QuotaWebSocketService._internal();

  WebSocketChannel? _channel;
  final List<void Function(Map<String, dynamic>)> _listeners = [];
  bool _isConnected = false;

  void connect() {
    if (_isConnected) return;

    try {
      final String wsUrl = ApiService.baseUrl
          .replaceFirst('http', 'ws')
          .replaceFirst('/api', '/ws');

      _channel = IOWebSocketChannel.connect(Uri.parse('$wsUrl/websocket'));

      _channel!.stream.listen(
        (message) {
          _handleMessage(message);
        },
        onError: (error) {
          print('WebSocket error: $error');
          _isConnected = false;
        },
        onDone: () {
          print('WebSocket disconnected');
          _isConnected = false;
          Future.delayed(const Duration(seconds: 5), () {
            if (!_isConnected) connect();
          });
        },
      );

      _isConnected = true;
      print('WebSocket connected successfully');
    } catch (e) {
      print('Failed to connect WebSocket: $e');
      _isConnected = false;
    }
  }

  void disconnect() {
    if (_channel != null) {
      _channel!.sink.close();
      _channel = null;
    }
    _isConnected = false;
  }

  void _handleMessage(dynamic message) {
    try {
      final Map<String, dynamic> data = message is String
          ? _parseJson(message)
          : message as Map<String, dynamic>;

      if (data.containsKey('vehicleType') &&
          data.containsKey('oldQuota') &&
          data.containsKey('newQuota')) {
        final vehicleType = data['vehicleType'] as String;
        final oldQuota = (data['oldQuota'] as num).toDouble();
        final newQuota = (data['newQuota'] as num).toDouble();
        final updatedBy = data['updatedBy'] as String? ?? 'Admin';

        print('Quota update received: $vehicleType -> $newQuota L');

        // Add notification for the user
        NotificationService.addQuotaUpdateNotification(
          vehicleType: vehicleType,
          oldQuota: oldQuota,
          newQuota: newQuota,
          updatedBy: updatedBy,
        );

        // Notify all listeners
        for (var listener in _listeners) {
          listener(data);
        }
      }
    } catch (e) {
      print('Error parsing WebSocket message: $e');
    }
  }

  Map<String, dynamic> _parseJson(String jsonStr) {
    // Simple parsing - in production use proper JSON decoder
    final Map<String, dynamic> result = {};
    final cleaned = jsonStr.replaceAll('{', '').replaceAll('}', '');
    final pairs = cleaned.split(',');
    for (var pair in pairs) {
      final parts = pair.split(':');
      if (parts.length == 2) {
        final key = parts[0].trim().replaceAll('"', '');
        var value = parts[1].trim().replaceAll('"', '');
        if (double.tryParse(value) != null) {
          result[key] = double.parse(value);
        } else {
          result[key] = value;
        }
      }
    }
    return result;
  }

  void addListener(void Function(Map<String, dynamic>) listener) {
    _listeners.add(listener);
  }

  void removeListener(void Function(Map<String, dynamic>) listener) {
    _listeners.remove(listener);
  }

  bool get isConnected => _isConnected;
}
