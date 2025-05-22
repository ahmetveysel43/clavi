
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'connection_service.dart';

class BluetoothConnectionService implements IConnectionService {
  static final BluetoothConnectionService _instance = BluetoothConnectionService._();
  static BluetoothConnectionService get instance => _instance;

  BluetoothConnectionService._();

  BluetoothDevice? _device;
  BluetoothCharacteristic? _characteristic;
  bool _isConnected = false;
  final _dataStreamController = StreamController<String>.broadcast();
  StreamSubscription? _subscription;

  @override
  bool get isConnected => _isConnected;

  @override
  Stream<String> get dataStream => _dataStreamController.stream;

  Future<List<BluetoothDevice>> scanForDevices() async {
    if (!await _checkPermissions()) throw Exception("Bluetooth ve konum izinleri verilmedi.");
    final adapterState = await FlutterBluePlus.adapterState.first;
    if (adapterState == BluetoothAdapterState.off) {
      await FlutterBluePlus.turnOn();
      await Future.delayed(const Duration(seconds: 2));
    }
    if (await FlutterBluePlus.isScanning.first) await FlutterBluePlus.stopScan();

    final devices = <BluetoothDevice>{};
    final connectedDevices = await FlutterBluePlus.connectedSystemDevices;
    for (var device in connectedDevices) {
      if (device.platformName.toLowerCase() == "izsel") devices.add(device);
    }
    final bondedDevices = await FlutterBluePlus.bondedDevices;
    for (var device in bondedDevices) {
      if (device.platformName.toLowerCase() == "izsel" && !devices.contains(device)) devices.add(device);
    }

    final results = <ScanResult>[];
    final subscription = FlutterBluePlus.scanResults.listen((r) => results.addAll(r));
    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 15), androidScanMode: AndroidScanMode.lowLatency);
    await FlutterBluePlus.stopScan();
    await subscription.cancel();

    for (var result in results) {
      if (result.device.platformName.toLowerCase().contains("izsel") && !devices.contains(result.device)) {
        devices.add(result.device);
      } else if (!devices.contains(result.device)) {
        devices.add(result.device);
      }
    }
    return devices.toList();
  }

  Future<bool> connectToDevice(BluetoothDevice device) async {
    final state = await device.connectionState.first;
    if (state == BluetoothConnectionState.connected) {
      _device = device;
      return _setupCharacteristics(device, await device.discoverServices());
    }

    try {
      await device.connect(timeout: const Duration(seconds: 15));
    } catch (e) {
      if (!e.toString().contains("already connected")) {
        try {
          await device.disconnect();
          await Future.delayed(const Duration(seconds: 1));
          await device.connect(timeout: const Duration(seconds: 15));
        } catch (e2) {
          await device.disconnect();
          return false;
        }
      }
    }

    _device = device;
    return _setupCharacteristics(device, await device.discoverServices());
  }

  Future<bool> _setupCharacteristics(BluetoothDevice device, List<BluetoothService> services) async {
    const targetServiceUUID = "4fafc201-1fb5-459e-8fcc-c5c9c331914b";
    const targetCharacteristicUUID = "beb5483e-36e1-4688-b7f5-ea07361b26a8";

    for (var service in services) {
      if (service.uuid.toString().toLowerCase().contains(targetServiceUUID)) {
        for (var c in service.characteristics) {
          if (c.uuid.toString().toLowerCase().contains(targetCharacteristicUUID)) {
            return await _tryNotify(device, c);
          }
        }
      }
    }

    for (var service in services) {
      for (var c in service.characteristics) {
        if (c.properties.notify || c.properties.indicate) {
          return await _tryNotify(device, c);
        }
      }
    }

    await device.disconnect();
    _device = null;
    return false;
  }

  Future<bool> _tryNotify(BluetoothDevice device, BluetoothCharacteristic c) async {
    try {
      await c.setNotifyValue(true);
      _subscription?.cancel();
      _subscription = c.onValueReceived.listen((value) {
        if (value.length == 10) {
          final sensorValues = <int>[];
          for (var i = 0; i < 5; i++) {
            sensorValues.add(value[i * 2] | (value[i * 2 + 1] << 8));
          }
          _dataStreamController.add(sensorValues.join(' '));
        } else {
          final data = String.fromCharCodes(value).trim();
          if (data != "IZSEL" && data.contains(" ")) _dataStreamController.add(data);
        }
      });
      _characteristic = c;
      _isConnected = true;
      return true;
    } catch (e) {
      await device.disconnect();
      _device = null;
      return false;
    }
  }

  @override
  Future<bool> connect() async {
    if (_isConnected) return true;
    final devices = await scanForDevices();
    if (devices.isEmpty) return false;
    return await connectToDevice(devices.first);
  }

  Future<bool> connectWithDeviceSelection(BuildContext context) async {
    if (_isConnected) return true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        title: Text('Bluetooth Cihazları Aranıyor'),
        content: SizedBox(
          height: 100,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [CircularProgressIndicator(), SizedBox(height: 20), Text('Lütfen bekleyin...')],
          ),
        ),
      ),
    );

    final devices = await scanForDevices();
    Navigator.of(context, rootNavigator: true).pop();

    if (devices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Hiçbir Bluetooth cihazı bulunamadı.'), duration: Duration(seconds: 5)),
      );
      return false;
    }

    final selectedDevice = await showDialog<BluetoothDevice>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Bluetooth Cihazı Seç'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: devices.length,
            itemBuilder: (_, index) {
              final device = devices[index];
              final name = device.platformName.isNotEmpty ? device.platformName : "Adsız Cihaz";
              return ListTile(
                leading: const Icon(Icons.bluetooth),
                title: Text(name),
                subtitle: Text(device.remoteId.toString()),
                tileColor: name.toLowerCase() == "izsel" ? Colors.green.shade100 : null,
                onTap: () => Navigator.pop(context, device),
              );
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('İptal')),
          TextButton(onPressed: () => connectWithDeviceSelection(context), child: const Text('Yeniden Tara')),
        ],
      ),
    );

    if (selectedDevice == null) return false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: Text('$selectedDevice.platformName Bağlanılıyor'),
        content: const SizedBox(
          height: 100,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [CircularProgressIndicator(), SizedBox(height: 20), Text('Lütfen bekleyin...')],
          ),
        ),
      ),
    );

    final connected = await connectToDevice(selectedDevice);
    Navigator.of(context, rootNavigator: true).pop();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(connected ? '$selectedDevice.platformName cihazına bağlandı!' : 'Bağlantı başarısız.'),
        backgroundColor: connected ? Colors.green : Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );

    return connected;
  }

  @override
  void disconnect() {
    if (!_isConnected) return;
    _subscription?.cancel();
    _device?.disconnect();
    _device = null;
    _characteristic = null;
    _isConnected = false;
  }

  Future<bool> sendCommand(String command) async {
    if (!_isConnected || _characteristic == null) return false;
    try {
      await _characteristic!.write(utf8.encode("$command\r\n"), withoutResponse: false);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> _checkPermissions() async {
    final permissions = [Permission.bluetooth, Permission.bluetoothScan, Permission.bluetoothConnect, Permission.location];
    final statuses = await permissions.request();
    final allGranted = statuses.values.every((status) => status.isGranted);
    if (!allGranted) await openAppSettings();
    return allGranted;
  }

  void dispose() {
    disconnect();
    _dataStreamController.close();
  }
}