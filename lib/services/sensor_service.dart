import 'dart:async';
import 'package:flutter/material.dart';

enum SensorState {
  IDLE,
  DETECTED
}

class SensorData {
  final List<int> values;
  final DateTime timestamp;

  SensorData(this.values, this.timestamp);

  bool anySensorBelowThreshold(int threshold) {
    return values.any((value) => value < threshold);
  }

  bool allSensorsAboveThreshold(int threshold) {
    return values.every((value) => value >= threshold);
  }

  List<SensorState> getSensorStates(int threshold) {
    return values.map((value) => value < threshold ? SensorState.DETECTED : SensorState.IDLE).toList();
  }
}

class SensorService extends ChangeNotifier {
  static final SensorService _instance = SensorService._internal();
  factory SensorService() => _instance;

  SensorService._internal();

  bool _isConnected = false;
  final List<SensorState> _sensorStates = List.filled(7, SensorState.IDLE);
  final _controller = StreamController<SensorData>.broadcast();

  bool get isConnected => _isConnected;
  List<SensorState> get sensorStates => _sensorStates;
  Stream<SensorData> get dataStream => _controller.stream;

  Future<bool> connect() async {
    await Future.delayed(Duration(seconds: 1));
    _isConnected = true;
    notifyListeners();

    _startMockDataGeneration();

    return true;
  }

  void disconnect() {
    _isConnected = false;
    notifyListeners();
  }

  void setThreshold(int threshold) {
    print("Eşik değeri: $threshold");
  }

  double calculateJumpHeight(Duration flyTime) {
    double t = flyTime.inMicroseconds / 1000000;
    double g = 9.81;
    double h = 0.5 * g * (t / 2) * (t / 2);
    return h * 100;
  }

  double calculateRSI(Duration flyTime, Duration contactTime) {
    double ftSeconds = flyTime.inMicroseconds / 1000000;
    double ctSeconds = contactTime.inMicroseconds / 1000000;
    return ctSeconds == 0 ? 0 : ftSeconds / ctSeconds;
  }

  double calculatePower(double jumpHeight, Duration flyTime, double weight) {
    if (weight <= 0 || flyTime.inMicroseconds <= 0) return 0;
    double heightInMeters = jumpHeight / 100;
    double power = (weight * 9.81 * heightInMeters) / (flyTime.inMicroseconds / 1000000);
    return power;
  }

  double calculateRhythm(int jumpCount, Duration totalTime) {
    return totalTime.inMicroseconds == 0 ? 0 : jumpCount / (totalTime.inMicroseconds / 1000000);
  }

  void _startMockDataGeneration() {
    Timer.periodic(Duration(milliseconds: 100), (timer) {
      if (!_isConnected) {
        timer.cancel();
        return;
      }

      List<int> values = List.generate(7, (index) => (1000 + (DateTime.now().millisecondsSinceEpoch % 8000)) % 8190);

      _controller.add(SensorData(values, DateTime.now()));
    });
  }

  @override
  void dispose() {
    _controller.close();
    super.dispose();
  }
}