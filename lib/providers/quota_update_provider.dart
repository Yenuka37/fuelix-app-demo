import 'package:flutter/material.dart';
import '../models/quota_model.dart';
import '../services/quota_websocket_service.dart';
import '../services/api_service.dart';

class QuotaUpdateProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();
  final QuotaWebSocketService _webSocket = QuotaWebSocketService.instance;

  Map<String, double> _quotaLimits = {};
  bool _isConnected = false;
  String? _lastUpdateMessage;

  QuotaUpdateProvider() {
    _initialize();
  }

  void _initialize() {
    // Connect to WebSocket
    _webSocket.connect();
    _webSocket.addListener(_onQuotaUpdate);

    // Load initial quota limits
    _loadQuotaLimits();
  }

  Future<void> _loadQuotaLimits() async {
    try {
      final result = await _apiService.getAllQuotaLimits();
      if (result['success']) {
        final List<dynamic> limits = result['data'];
        for (var limit in limits) {
          _quotaLimits[limit['vehicleType']] = limit['quotaLitres'];
        }
        notifyListeners();
      }
    } catch (e) {
      print('Error loading quota limits: $e');
    }
  }

  void _onQuotaUpdate(Map<String, dynamic> update) {
    final vehicleType = update['vehicleType'] as String;
    final newQuota = update['newQuota'] as double;

    // Update local cache
    _quotaLimits[vehicleType] = newQuota;
    _lastUpdateMessage =
        '${update['updatedBy']} updated ${vehicleType} quota to ${newQuota} L';

    notifyListeners();
  }

  double getQuotaForVehicleType(String vehicleType) {
    return _quotaLimits[vehicleType] ?? 0.0;
  }

  String? get lastUpdateMessage => _lastUpdateMessage;

  void clearLastUpdateMessage() {
    _lastUpdateMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _webSocket.removeListener(_onQuotaUpdate);
    _webSocket.disconnect();
    super.dispose();
  }
}
