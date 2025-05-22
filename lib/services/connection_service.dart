import 'dart:async';
import 'package:flutter/foundation.dart';

abstract class IConnectionService {
  bool get isConnected;
  Future<bool> connect();
  void disconnect();
  Stream<String> get dataStream;
}

class MockConnectionService implements IConnectionService {
  static final MockConnectionService _instance = MockConnectionService._internal();
  factory MockConnectionService() => _instance;

  MockConnectionService._internal() {
    _isConnected = false;
  }

  bool _isConnected = false;
  Timer? _mockDataTimer;
  final StreamController<String> _dataStreamController = StreamController<String>.broadcast();

  @override
  bool get isConnected => _isConnected;

  @override
  Stream<String> get dataStream => _dataStreamController.stream;

  @override
  Future<bool> connect() async {
    if (_isConnected) return true;

    await Future.delayed(const Duration(seconds: 1));

    _startMockDataGeneration();
    _isConnected = true;
    debugPrint("MOCK: Sensör bağlantısı kuruldu (simülasyon)");
    return true;
  }

  @override
  void disconnect() {
    _stopMockDataGeneration();
    _isConnected = false;
    debugPrint("MOCK: Sensör bağlantısı kapatıldı (simülasyon)");
  }

  void _startMockDataGeneration() {
    _mockDataTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!_isConnected) {
        timer.cancel();
        return;
      }

      List<int> values = [];

      values.add((3000 - DateTime.now().millisecondsSinceEpoch % 3000).clamp(0, 3000));

      for (int i = 1; i < 7; i++) {
        int base = 500 * i;
        int variation = (DateTime.now().millisecondsSinceEpoch % 1000).toInt();
        values.add((base + variation).clamp(0, 8190));
      }

      String dataString = values.join(' ');
      _dataStreamController.add(dataString);
    });
  }

  void _stopMockDataGeneration() {
    _mockDataTimer?.cancel();
    _mockDataTimer = null;
  }

  void dispose() {
    disconnect();
    _dataStreamController.close();
  }
}

class BluetoothConnectionService implements IConnectionService {
  static BluetoothConnectionService? _instance;

  static BluetoothConnectionService get instance {
    _instance ??= BluetoothConnectionService._();
    return _instance!;
  }

  BluetoothConnectionService._();

  @override
  bool get isConnected => false;

  @override
  Future<bool> connect() async => false;

  @override
  void disconnect() {}

  @override
  Stream<String> get dataStream => Stream.empty();
}

class ConnectionServiceFactory {
  static bool _useMock = true;

  static void setMockMode(bool useMock) {
    _useMock = useMock;
  }

  static bool get isMockMode => _useMock;

  static IConnectionService create() {
    if (_useMock) {
      debugPrint("UYARI: Mock sensör bağlantı modu aktif!");
      return MockConnectionService();
    }
    return BluetoothConnectionService.instance;
  }
}