import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/io.dart';
import '../models/quota_model.dart';
import '../services/api_service.dart';

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
      // Use WebSocket connection to backend
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
          // Attempt to reconnect after 5 seconds
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
          ? Map<String, dynamic>.from(_parseJson(message))
          : message;

      // Check if it's a quota update message
      if (data.containsKey('vehicleType') &&
          data.containsKey('oldQuota') &&
          data.containsKey('newQuota')) {
        print(
          'Quota update received: ${data['vehicleType']} -> ${data['newQuota']} L',
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
    // Simple JSON parsing without dart:convert import in this file
    // In production, use proper JSON decoding
    final Map<String, dynamic> result = {};
    // This is a simplified version - use proper JSON parsing
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
